import 'dart:math' as math;
import 'dart:ui';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/providers/feedback_provider.dart';
import '../../../../core/providers/interactive_tour_provider.dart';
import '../../../../core/providers/setup_wizard_provider.dart';
import '../../../../core/services/notification_service.dart';

/// Post-login setup wizard — versión mínima (Sprint 2.10).
///
/// Antes: 6 pasos (name → income → cards → goal → notifications → complete).
/// Ahora: 2 pasos (income+payday → complete).
///
/// Las tarjetas/goal/notifs/nombre se piden contextualmente cuando el usuario
/// llega a la pantalla correspondiente (Cuentas/Goals/Settings/Profile),
/// reduciendo el time-to-first-expense de ~180s a ~30-45s.
class SetupWizardPage extends ConsumerStatefulWidget {
  const SetupWizardPage({super.key});

  @override
  ConsumerState<SetupWizardPage> createState() => _SetupWizardPageState();
}

class _SetupWizardPageState extends ConsumerState<SetupWizardPage> {
  final _pageController = PageController();
  int _index = 0;

  final _nameCtrl = TextEditingController();
  final _incomeCtrl = TextEditingController();
  int _payDay = 1;
  bool? _hasCreditCards;
  String? _goal; // save / control / debt / invest
  // Notifs por default ON; el toggle se ofrece en Settings post-onboarding.
  final bool _notifsEnabled = true;

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _incomeCtrl.dispose();
    super.dispose();
  }

  // Pasos visibles del wizard (mínimo): income → complete = 2
  static const int _totalSteps = 2;

  void _next() {
    appHaptic(ref, type: HapticType.light);
    if (_index < _totalSteps - 1) {
      setState(() => _index++);
      _pageController.animateToPage(_index,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic);
    }
  }

  void _prev() {
    if (_index == 0) return;
    appHaptic(ref, type: HapticType.light);
    setState(() => _index--);
    _pageController.animateToPage(_index,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic);
  }

  Future<void> _finish() async {
    appHaptic(ref, type: HapticType.medium);
    final ctrl = ref.read(setupWizardProvider);
    ctrl.userName = _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim();
    ctrl.hasCreditCards = _hasCreditCards;
    ctrl.monthlyIncome = double.tryParse(_incomeCtrl.text.replaceAll(',', '.'));
    ctrl.payDay = _payDay;
    ctrl.financialGoal = _goal;
    ctrl.notificationsEnabled = _notifsEnabled;

    // Persist user profile
    try {
      final db = ref.read(databaseProvider);
      await db.into(db.userProfileTable).insertOnConflictUpdate(
            UserProfileTableCompanion.insert(
              id: const Uuid().v4(),
              name: drift.Value(ctrl.userName ?? ''),
              monthlySalary: drift.Value(ctrl.monthlyIncome ?? 0),
              payDay: drift.Value(ctrl.payDay ?? 1),
              createdAt: drift.Value(DateTime.now()),
            ),
          );
    } catch (_) {}

    // Schedule notifications if user enabled them
    if (_notifsEnabled) {
      try {
        await ref.read(notificationServiceProvider).refreshAll(ref);
      } catch (_) {}
    }

    await ctrl.complete();

    // Enable interactive tour for new users
    final tour = ref.read(interactiveTourProvider);
    if (!tour.isComplete && !tour.isSkipped) {
      await tour.setStep(0);
    }

    if (mounted) context.go('/home');
  }

  Future<void> _skipAll() async {
    appHaptic(ref, type: HapticType.light);
    await ref.read(setupWizardProvider).skip();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Stack(
          children: [
            // Glow background
            Positioned(
              top: -100,
              left: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF6C63FF).withValues(alpha: 0.18),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              right: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF5ECFB1).withValues(alpha: 0.12),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),

            Column(
              children: [
                // Header — progress + skip
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (_index + 1) / _totalSteps,
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            valueColor: const AlwaysStoppedAnimation(
                                Color(0xFF6C63FF)),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _skipAll,
                        child: Text(
                          'Saltar',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      // Sprint 2.10: solo 1 paso obligatorio (income+payday).
                      _StepIncome(
                        incomeCtrl: _incomeCtrl,
                        payDay: _payDay,
                        onPayDayChanged: (d) => setState(() => _payDay = d),
                      ),
                      _StepComplete(name: _nameCtrl.text.trim()),
                    ],
                  ),
                ),

                // Nav buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Row(
                    children: [
                      if (_index > 0)
                        Expanded(
                          child: _NavButton(
                            label: 'Atrás',
                            outlined: true,
                            onTap: _prev,
                          ),
                        ),
                      if (_index > 0) const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _NavButton(
                          label: _index == _totalSteps - 1 ? 'Empezar tour' : 'Listo',
                          onTap: _index == _totalSteps - 1 ? _finish : _next,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Steps ────────────────────────────────────────────

class _StepWelcome extends StatelessWidget {
  final TextEditingController nameCtrl;
  const _StepWelcome({required this.nameCtrl});

  @override
  Widget build(BuildContext context) {
    return _StepFrame(
      emoji: '👋',
      title: '¡Bienvenido a Sencillo!',
      subtitle: 'Vamos a configurar tu experiencia en 1 minuto.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Cómo querés que te llamemos?',
            style: GoogleFonts.inter(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 10),
          _TextField(controller: nameCtrl, hint: 'Tu nombre'),
        ],
      ),
    );
  }
}

class _StepIncome extends StatelessWidget {
  final TextEditingController incomeCtrl;
  final int payDay;
  final ValueChanged<int> onPayDayChanged;
  const _StepIncome(
      {required this.incomeCtrl,
      required this.payDay,
      required this.onPayDayChanged});

  @override
  Widget build(BuildContext context) {
    return _StepFrame(
      emoji: '💰',
      title: 'Tu perfil financiero',
      subtitle: 'Esto nos ayuda a calcular tu presupuesto automáticamente.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ingreso mensual aproximado',
              style: GoogleFonts.inter(
                  fontSize: 13, color: Colors.white.withValues(alpha: 0.6))),
          const SizedBox(height: 10),
          _TextField(
            controller: incomeCtrl,
            hint: 'Ej: 500000',
            keyboardType: TextInputType.number,
            prefix: '\$ ',
          ),
          const SizedBox(height: 24),
          Text('Día de cobro',
              style: GoogleFonts.inter(
                  fontSize: 13, color: Colors.white.withValues(alpha: 0.6))),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: payDay.toDouble(),
                  min: 1,
                  max: 31,
                  divisions: 30,
                  label: 'Día $payDay',
                  activeColor: const Color(0xFF6C63FF),
                  onChanged: (v) => onPayDayChanged(v.round()),
                ),
              ),
              SizedBox(
                width: 44,
                child: Text('$payDay',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ],
          ),
          Text('Podés saltearlo y editarlo después',
              style: GoogleFonts.inter(
                  fontSize: 11, color: Colors.white.withValues(alpha: 0.35))),
        ],
      ),
    );
  }
}

class _StepCreditCards extends StatelessWidget {
  final bool? value;
  final ValueChanged<bool> onChanged;
  const _StepCreditCards({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _StepFrame(
      emoji: '💳',
      title: '¿Usás tarjetas de crédito?',
      subtitle: 'Si sí, te vamos a ayudar a trackear cierres y vencimientos.',
      child: Column(
        children: [
          _ChoiceCard(
            label: 'Sí, uso tarjetas',
            sublabel: 'Voy a agregarlas para ver mis cuotas y cierres',
            selected: value == true,
            onTap: () => onChanged(true),
          ),
          const SizedBox(height: 12),
          _ChoiceCard(
            label: 'No, solo débito/efectivo',
            sublabel: 'Manejo todo con dinero disponible',
            selected: value == false,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _StepGoal extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;
  const _StepGoal({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const opts = [
      ('save', '💪 Ahorrar más', 'Quiero guardar plata cada mes'),
      ('control', '📊 Controlar gastos', 'Saber a dónde se va mi dinero'),
      ('debt', '🎯 Salir de deudas', 'Pagar tarjetas o préstamos'),
      ('invest', '🚀 Invertir', 'Hacer crecer mi plata'),
    ];
    return _StepFrame(
      emoji: '🎯',
      title: '¿Cuál es tu objetivo principal?',
      subtitle: 'Podés cambiarlo cuando quieras.',
      child: Column(
        children: [
          for (final o in opts) ...[
            _ChoiceCard(
              label: o.$2,
              sublabel: o.$3,
              selected: value == o.$1,
              onTap: () => onChanged(o.$1),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _StepNotifications extends ConsumerWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _StepNotifications({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hour = ref.watch(notifDailyReminderHourProvider);
    final minute = ref.watch(notifDailyReminderMinuteProvider);
    final timeLabel =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

    return _StepFrame(
      emoji: '🔔',
      title: 'Recordatorios diarios',
      subtitle:
          'Te avisamos a las $timeLabel para que anotes tus gastos del día.',
      child: Column(
        children: [
          _ChoiceCard(
            label: 'Sí, enviame recordatorios',
            sublabel: 'Check-in diario + cierres de tarjetas',
            selected: value,
            onTap: () => onChanged(true),
          ),
          const SizedBox(height: 12),
          // B3: selector de hora (solo si activó notificaciones)
          if (value)
            GestureDetector(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: hour, minute: minute),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: Color(0xFF6C63FF),
                        onPrimary: Colors.white,
                        surface: Color(0xFF1A1A2E),
                        onSurface: Colors.white,
                      ),
                      dialogTheme: const DialogThemeData(
                          backgroundColor: Color(0xFF1A1A2E)),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  await ref
                      .read(notifDailyReminderHourProvider.notifier)
                      .set(picked.hour);
                  await ref
                      .read(notifDailyReminderMinuteProvider.notifier)
                      .set(picked.minute);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 18, color: Color(0xFF6C63FF)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Hora del recordatorio',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      timeLabel,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          color: const Color(0xFF6C63FF),
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right,
                        size: 18, color: Color(0xFF6C63FF)),
                  ],
                ),
              ),
            ),
          if (value) const SizedBox(height: 12),
          _ChoiceCard(
            label: 'No, por ahora no',
            sublabel: 'Podés activarlo después en Ajustes',
            selected: !value,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _StepComplete extends StatefulWidget {
  final String name;
  const _StepComplete({required this.name});

  @override
  State<_StepComplete> createState() => _StepCompleteState();
}

class _StepCompleteState extends State<_StepComplete>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    _particles = List.generate(30, (i) => _ConfettiParticle.random(rnd));
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final greeting = widget.name.isEmpty ? 'Todo listo' : 'Listo, ${widget.name}';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _StepFrame(
          emoji: '🎉',
          title: '$greeting!',
          subtitle:
              'Ahora te mostramos las funcionalidades clave con un tour rápido.',
          child: Column(
            children: [
              _InfoRow(icon: Icons.tour_rounded, text: 'Tour guiado (30 seg)'),
              const SizedBox(height: 12),
              _InfoRow(
                  icon: Icons.auto_awesome_rounded,
                  text: 'Aprendé a cargar gastos con voz'),
              const SizedBox(height: 12),
              _InfoRow(
                  icon: Icons.lightbulb_outline_rounded,
                  text: 'Tips para presupuestos y metas'),
            ],
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) => CustomPaint(
                painter: _ConfettiPainter(
                  particles: _particles,
                  progress: _ctrl.value,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfettiParticle {
  final double startX; // 0-1
  final double endX; // 0-1
  final double delay; // 0-0.5
  final double size;
  final double rotSpeed;
  final Color color;

  _ConfettiParticle({
    required this.startX,
    required this.endX,
    required this.delay,
    required this.size,
    required this.rotSpeed,
    required this.color,
  });

  factory _ConfettiParticle.random(math.Random rnd) {
    const colors = [
      Color(0xFF6C63FF),
      Color(0xFFFFD166),
      Color(0xFFEF476F),
      Color(0xFF06D6A0),
      Color(0xFF118AB2),
      Color(0xFFFFFFFF),
    ];
    final sx = rnd.nextDouble();
    return _ConfettiParticle(
      startX: sx,
      endX: sx + (rnd.nextDouble() - 0.5) * 0.4,
      delay: rnd.nextDouble() * 0.4,
      size: 5 + rnd.nextDouble() * 6,
      rotSpeed: (rnd.nextDouble() - 0.5) * 10,
      color: colors[rnd.nextInt(colors.length)],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final localProgress = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (localProgress <= 0) continue;

      final x = lerpDouble(p.startX, p.endX, localProgress)! * size.width;
      final y = -20 + (size.height + 40) * localProgress;
      final alpha = localProgress < 0.85
          ? 1.0
          : (1.0 - (localProgress - 0.85) / 0.15).clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(localProgress * p.rotSpeed);
      final paint = Paint()
        ..color = p.color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.4),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

// ─── Shared widgets ──────────────────────────────────

class _StepFrame extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Widget child;
  const _StepFrame(
      {required this.emoji,
      required this.title,
      required this.subtitle,
      required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.quicksand(
                fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.55),
                height: 1.4),
          ),
          const SizedBox(height: 28),
          child,
        ],
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final String? prefix;
  const _TextField(
      {required this.controller,
      required this.hint,
      this.keyboardType,
      this.prefix});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(fontSize: 16, color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: Colors.white38),
          prefixText: prefix,
          prefixStyle: GoogleFonts.inter(color: Colors.white70, fontSize: 16),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceCard({
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6C63FF).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFF6C63FF).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.quicksand(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  const SizedBox(height: 3),
                  Text(sublabel,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5))),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? const Color(0xFF6C63FF) : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF6C63FF)
                      : Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
          ),
          child: Icon(icon, color: const Color(0xFF6C63FF), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.white)),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool outlined;
  const _NavButton(
      {required this.label, required this.onTap, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: outlined
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF5ECFB1)],
                ),
          color: outlined ? Colors.white.withValues(alpha: 0.05) : null,
          borderRadius: BorderRadius.circular(16),
          border: outlined
              ? Border.all(color: Colors.white.withValues(alpha: 0.12))
              : null,
          boxShadow: outlined
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.quicksand(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// Used to avoid import hint for BackdropFilter if unused — kept minimal.
// ignore_for_file: unused_element
class _Blur extends StatelessWidget {
  final Widget child;
  const _Blur({required this.child});
  @override
  Widget build(BuildContext context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: child,
      );
}
