import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/feedback_provider.dart';
import '../../../../core/providers/onboarding_provider.dart';
import '../../../../core/providers/setup_wizard_provider.dart';
import '../../../../core/providers/interactive_tour_provider.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/database/database_seeder.dart';
import '../../../../core/services/cloud_backup_service.dart';
import '../../../../core/widgets/backup_restore_overlay.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with TickerProviderStateMixin {
  bool _loading = false;
  String? _error;

  // Backup restore overlay state
  bool _showRestoreOverlay = false;
  String _restoreMessage = 'Restaurando tu información...';
  bool _restoreSuccess = false;
  bool _restoreError = false;

  late final AnimationController _pulseCtrl;
  late final AnimationController _floatCtrl;
  late final Animation<double> _pulse;
  late final Animation<double> _float;

  // Touch ripple tracking
  final List<_TouchRipple> _ripples = [];
  int _rippleId = 0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _float = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _floatCtrl.dispose();
    for (final r in _ripples) {
      r.controller.dispose();
    }
    super.dispose();
  }

  void _onTouchDown(TapDownDetails details) {
    final ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    final ripple = _TouchRipple(
      id: _rippleId++,
      position: details.localPosition,
      controller: ctrl,
    );
    setState(() => _ripples.add(ripple));
    ctrl.forward().then((_) {
      ctrl.dispose();
      if (mounted) setState(() => _ripples.removeWhere((r) => r.id == ripple.id));
    });
  }

  Future<void> _signIn() async {
    appHaptic(ref, type: HapticType.medium);
    appSound(ref, type: SoundType.tap);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(firebaseAuthServiceProvider);
      final user = await service.signInWithGoogle();
      if (user == null && mounted) {
        setState(() => _loading = false);
        return;
      }
      // After successful sign-in, check for cloud backup
      if (user != null && mounted) {
        await _checkForBackup(user.uid);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Error al iniciar sesión. Intentá de nuevo.';
        });
      }
    }
  }

  Future<void> _checkForBackup(String uid) async {
    if (!mounted) return;
    setState(() => _error = null);

    bool foundBackup = false;
    try {
      final backupService = CloudBackupService(uid: uid);
      final remoteDate = await backupService.remoteBackupDate();
      if (!mounted) return;

      if (remoteDate != null) {
        foundBackup = true;

        // A4: si hay datos locales "significativos" (>=5 txs), preguntar antes de overwritear
        final db = ref.read(databaseProvider);
        final localTxCount = await db
            .customSelect('SELECT COUNT(*) AS c FROM transactions_table')
            .getSingle()
            .then((r) => r.read<int>('c'));

        if (localTxCount >= 5 && mounted) {
          final choice = await _askBackupConflict(
              remoteDate: remoteDate, localTxCount: localTxCount);
          if (choice == null || choice == 'cancel') {
            // Usuario canceló → no hacemos nada, se queda en login
            if (mounted) setState(() => _loading = false);
            return;
          }
          if (choice == 'keep_local') {
            // Subir datos locales (sobreescribir nube)
            try {
              await backupService.uploadBackup();
            } catch (_) {}
            // Marcar setup como done y navegar
            await ref.read(setupWizardProvider).complete();
            await ref.read(interactiveTourProvider).complete();
            if (mounted) context.go('/home');
            return;
          }
          // choice == 'use_remote' → sigue el flow normal de restore
        }

        // Show overlay while we download + reopen DB
        setState(() {
          _showRestoreOverlay = true;
          _restoreMessage = 'Restaurando tu información...';
          _restoreSuccess = false;
          _restoreError = false;
        });

        try {
          await db.close();
          await backupService.downloadBackup();
          ref.invalidate(databaseProvider);

          // Mark setup wizard + tour as complete (returning user)
          await ref.read(setupWizardProvider).complete();
          await ref.read(interactiveTourProvider).complete();

          if (mounted) {
            setState(() {
              _restoreSuccess = true;
              _restoreMessage = '¡Listo! Tus datos se sincronizaron';
            });
            await Future.delayed(const Duration(milliseconds: 1200));
            if (mounted) {
              setState(() => _showRestoreOverlay = false);
              context.go('/home');
            }
          }
          return;
        } catch (e) {
          ref.invalidate(databaseProvider);
          if (mounted) {
            setState(() {
              _restoreError = true;
              _restoreMessage = 'No pudimos restaurar tu backup';
            });
            await Future.delayed(const Duration(milliseconds: 1500));
            if (mounted) setState(() => _showRestoreOverlay = false);
          }
        }
      }
    } catch (_) {
      // Network error — fall through to wizard
    }

    // New user (no backup) or restore failed → run setup wizard
    if (!foundBackup && mounted) {
      final wizard = ref.read(setupWizardProvider);
      if (!wizard.isComplete) {
        context.go('/setup-wizard');
      }
    }
  }

  Future<String?> _askBackupConflict({
    required DateTime remoteDate,
    required int localTxCount,
  }) async {
    final dateStr = '${remoteDate.day}/${remoteDate.month}/${remoteDate.year}';
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          'Ya tenés datos en este dispositivo',
          style: GoogleFonts.quicksand(
              color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'En la nube tenés un backup del $dateStr.\n'
          'En este dispositivo tenés $localTxCount movimientos cargados.\n\n'
          '¿Qué querés hacer?',
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: Text('Cancelar',
                style: GoogleFonts.inter(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'keep_local'),
            child: Text('Usar los de acá',
                style: GoogleFonts.inter(
                    color: const Color(0xFF5ECFB1),
                    fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'use_remote'),
            child: Text('Restaurar nube',
                style: GoogleFonts.inter(
                    color: const Color(0xFF40C4FF),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _startWithoutAccount({required bool loadDemo}) async {
    appHaptic(ref, type: HapticType.medium);
    appSound(ref, type: SoundType.tap);
    setState(() => _loading = true);

    if (loadDemo) {
      final db = ref.read(databaseProvider);
      final seeder = DatabaseSeeder(db);
      await seeder.clearAndSeedMockData();
    }

    // Mark as skipped auth + enable in-app tour for new users
    await ref.read(skipAuthProvider).skip();
    if (!loadDemo) {
      await ref.read(needsInAppTourProvider).enable();
    }

    // Router will now allow navigation — run setup wizard for non-demo users
    if (mounted) {
      setState(() => _loading = false);
      if (!loadDemo && !ref.read(setupWizardProvider).isComplete) {
        context.go('/setup-wizard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return PopScope(
      // Bloquea el back durante el restore para evitar DB corrupta.
      canPop: !_showRestoreOverlay || _restoreError || _restoreSuccess,
      child: Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: GestureDetector(
        onTapDown: _onTouchDown,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // ── Background glow effects ──
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => Stack(
                children: [
                  Positioned(
                    top: -size.height * 0.15,
                    left: -size.width * 0.3,
                    child: Container(
                      width: size.width * 0.8,
                      height: size.width * 0.8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF6C63FF).withValues(alpha: 0.12 * _pulse.value),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -size.height * 0.1,
                    right: -size.width * 0.2,
                    child: Container(
                      width: size.width * 0.7,
                      height: size.width * 0.7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF5ECFB1).withValues(alpha: 0.08 * _pulse.value),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Floating particles (subtle dots like before) ──
            ...List.generate(8, (i) => _FloatingParticle(
              animation: _floatCtrl,
              index: i,
              size: size,
            )),

            // ── Touch ripples ──
            ..._ripples.map((r) => _TouchRippleWidget(ripple: r)),

            // ── Main content ──
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const Spacer(flex: 3),

                    // ── Floating App Icon — painted on dark bg, no transparency leak ──
                    AnimatedBuilder(
                      animation: _float,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(0, _float.value),
                        child: child,
                      ),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
                              blurRadius: 50,
                              spreadRadius: 8,
                            ),
                            BoxShadow(
                              color: const Color(0xFF5ECFB1).withValues(alpha: 0.15),
                              blurRadius: 60,
                              spreadRadius: 10,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: SizedBox(
                            width: 120,
                            height: 120,
                            child: Transform.scale(
                              scale: 1.35,
                              child: Image.asset(
                                'assets/app_icon.png',
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFF6C63FF), Color(0xFF4ECDC4)],
                                    ),
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  child: const Icon(
                                    Icons.savings_rounded,
                                    color: Colors.white,
                                    size: 52,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── App Name ──
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF5ECFB1)],
                      ).createShader(bounds),
                      child: Text(
                        'Sencillo',
                        style: GoogleFonts.quicksand(
                          fontSize: 42,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Tus finanzas, sin complicaciones',
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.35),
                        letterSpacing: 0.5,
                      ),
                    ),

                    const Spacer(flex: 4),

                    // ── Error message ──
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 16, color: Colors.redAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: GoogleFonts.inter(fontSize: 13, color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── 1. Google Sign-In Button ──
                    if (_loading)
                      const SizedBox(
                        height: 54,
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      )
                    else ...[
                      _LoginOption(
                        onTap: _signIn,
                        icon: Icons.login_rounded,
                        iconAsset: 'assets/google_logo.png',
                        label: 'Continuar con Google',
                        sublabel: 'Sincronizá y recuperá tus datos',
                        gradient: [
                          const Color(0xFF6C63FF).withValues(alpha: 0.2),
                          const Color(0xFF5ECFB1).withValues(alpha: 0.1),
                        ],
                        borderColor: const Color(0xFF6C63FF).withValues(alpha: 0.25),
                      ),

                      const SizedBox(height: 12),

                      // ── 2. Empezar de cero (sin cuenta) ──
                      _LoginOption(
                        onTap: () => _startWithoutAccount(loadDemo: false),
                        icon: Icons.rocket_launch_rounded,
                        label: 'Nueva cuenta local',
                        sublabel: 'Sin login, empezá de cero',
                        gradient: [
                          Colors.white.withValues(alpha: 0.06),
                          Colors.white.withValues(alpha: 0.03),
                        ],
                        borderColor: Colors.white.withValues(alpha: 0.1),
                      ),

                    ],

                    const SizedBox(height: 12),

                    // ── Ver onboarding ──
                    GestureDetector(
                      onTap: () {
                        appHaptic(ref, type: HapticType.light);
                        ref.read(onboardingProvider).reset();
                        // app.dart will show OnboardingPage since isComplete = false
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_circle_outline_rounded, size: 14,
                              color: Colors.white.withValues(alpha: 0.25)),
                          const SizedBox(width: 6),
                          Text(
                            'Ver tutorial de bienvenida',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.25),
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Footer ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 12,
                            color: Colors.white.withValues(alpha: 0.15)),
                        const SizedBox(width: 6),
                        Text(
                          'Podés conectar tu cuenta después',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'v1.9.0',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.08),
                        letterSpacing: 1,
                      ),
                    ),

                    const Spacer(),
                  ],
                ),
              ),
            ),

            // ── Backup restore overlay (on top of everything) ──
            if (_showRestoreOverlay)
              BackupRestoreOverlay(
                message: _restoreMessage,
                success: _restoreSuccess,
                error: _restoreError,
              ),
          ],
        ),
      ),
    ),
    );
  }
}

// ─────────────────────────────────────────────
// Touch Ripple
// ─────────────────────────────────────────────
class _TouchRipple {
  final int id;
  final Offset position;
  final AnimationController controller;
  _TouchRipple({required this.id, required this.position, required this.controller});
}

class _TouchRippleWidget extends StatelessWidget {
  final _TouchRipple ripple;
  const _TouchRippleWidget({required this.ripple});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ripple.controller,
      builder: (context, _) {
        final t = ripple.controller.value;
        final scale = 1.0 + t * 3.0;
        final opacity = (1.0 - t) * 0.2;
        return Positioned(
          left: ripple.position.dx - 30,
          top: ripple.position.dy - 30,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6C63FF).withValues(alpha: opacity),
                    const Color(0xFF5ECFB1).withValues(alpha: opacity * 0.4),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Floating Particles — subtle dots
// ─────────────────────────────────────────────
class _FloatingParticle extends StatelessWidget {
  final Animation<double> animation;
  final int index;
  final Size size;

  const _FloatingParticle({
    required this.animation,
    required this.index,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final rng = math.Random(index * 42);
    final x = rng.nextDouble() * size.width;
    final y = rng.nextDouble() * size.height;
    final particleSize = 2.0 + rng.nextDouble() * 3;
    final isPurple = index.isEven;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final offset = math.sin(animation.value * math.pi * 2 + index) * 12;
        return Positioned(
          left: x,
          top: y + offset,
          child: Container(
            width: particleSize,
            height: particleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isPurple ? const Color(0xFF6C63FF) : const Color(0xFF5ECFB1))
                  .withValues(alpha: 0.15 + rng.nextDouble() * 0.1),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Login option button
// ─────────────────────────────────────────────
class _LoginOption extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String? iconAsset;
  final String label;
  final String sublabel;
  final List<Color> gradient;
  final Color borderColor;
  const _LoginOption({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.gradient,
    required this.borderColor,
    this.iconAsset,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          border: Border.all(color: borderColor),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  if (iconAsset != null)
                    Image.asset(
                      iconAsset!,
                      width: 20,
                      height: 20,
                      errorBuilder: (_, __, ___) =>
                          Icon(icon, size: 20, color: Colors.white70),
                    )
                  else
                    Icon(icon, size: 20, color: Colors.white54),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.quicksand(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          sublabel,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: Colors.white.withValues(alpha: 0.2)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
