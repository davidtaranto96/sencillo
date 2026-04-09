import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/backup_utils.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/database/database_seeder.dart';
import '../../../../core/database/database_providers.dart' hide databaseProvider;
import '../../../../core/logic/ai_transaction_parser.dart';
import '../../../../core/logic/user_profile_service.dart';
import '../../../../core/widgets/tab_config_sheet.dart';
import '../../../../core/providers/alerts_provider.dart';
import '../../../../core/providers/onboarding_provider.dart';
import '../../../../core/providers/feedback_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../wishlist/presentation/providers/wishlist_provider.dart';
import '../../../../core/providers/mercado_pago_provider.dart';
import '../../../../core/logic/account_service.dart';
import '../../../../core/providers/currency_preferences_provider.dart';
import '../../../../core/providers/crypto_provider.dart';
import '../../../../core/providers/stocks_provider.dart';
import '../../../../core/providers/home_widgets_provider.dart';
import '../../../../core/widgets/home_widget_config_sheet.dart';
import '../../../../core/widgets/select_sheets.dart';
import '../../../../core/utils/currency_utils.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final db = ref.read(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Configuración',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          // ── Profile Card ──
          _ProfileCard(),

          // ── Connect Google (only if not logged in) ──
          _ConnectGoogleCard(),

          const SizedBox(height: 24),

          // ── App Config ──
          _SectionTitle('Aplicación'),
          _SettingsTile(
            icon: Icons.tab_rounded,
            title: 'Personalizar navegación',
            subtitle: 'Elegí qué pestañas mostrar y su orden',
            color: AppTheme.colorTransfer,
            onTap: () => showTabConfigSheet(context, ref),
          ),
          _SettingsTile(
            icon: Icons.dark_mode_rounded,
            title: 'Apariencia',
            subtitle: 'Tema Oscuro',
            color: Colors.deepPurple,
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.attach_money_rounded,
            title: 'Moneda principal',
            subtitle: 'Peso Argentino (ARS)',
            color: AppTheme.colorIncome,
            onTap: () {},
          ),
          _ConversionRateTile(),
          _CurrencySelectTile(),
          _CryptoSelectTile(),
          _StocksSelectTile(),
          _HomeWidgetsTile(),
          _SettingsTile(
            icon: Icons.play_circle_outline_rounded,
            title: 'Restablecer tutorial',
            subtitle: 'Volver a ver el onboarding desde el inicio',
            color: const Color(0xFF6C63FF),
            onTap: () async {
              await ref.read(onboardingProvider).reset();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tutorial restablecido. Se mostrará al reiniciar la app.'),
                  ),
                );
              }
            },
          ),

          const SizedBox(height: 24),
          _SectionTitle('Feedback'),
          _SwitchTile(
            icon: Icons.vibration_rounded,
            title: 'Respuesta háptica',
            subtitle: 'Vibración al tocar botones',
            color: const Color(0xFF6C63FF),
            provider: hapticEnabledProvider,
          ),
          _SwitchTile(
            icon: Icons.volume_up_rounded,
            title: 'Sonidos',
            subtitle: 'Efectos de sonido minimalistas',
            color: AppTheme.colorTransfer,
            provider: soundEnabledProvider,
          ),

          const SizedBox(height: 24),
          _SectionTitle('Notificaciones'),
          _SwitchTile(
            icon: Icons.credit_card_rounded,
            title: 'Vencimientos de tarjetas',
            subtitle: 'Alerta antes del cierre de tarjeta',
            color: AppTheme.colorExpense,
            provider: notifCardDueEnabledProvider,
          ),
          _SwitchTile(
            icon: Icons.people_rounded,
            title: 'Recordatorio de deudas',
            subtitle: 'Aviso periódico de deudas pendientes',
            color: AppTheme.colorTransfer,
            provider: notifDebtRemindEnabledProvider,
          ),
          _NotifDaysSelector(
            icon: Icons.calendar_today_rounded,
            title: 'Días antes del cierre',
            color: AppTheme.colorExpense,
            provider: notifCardDueDaysBeforeProvider,
            options: const [1, 2, 3, 5, 7],
          ),
          _NotifDaysSelector(
            icon: Icons.timer_rounded,
            title: 'Recordar deudas cada',
            color: AppTheme.colorTransfer,
            provider: notifDebtRemindDaysProvider,
            options: const [3, 5, 7, 14, 30],
            suffix: ' días',
          ),
          _SwitchTile(
            icon: Icons.notifications_active_rounded,
            title: 'Recordatorio diario',
            subtitle: 'Anotá tus gastos a la noche',
            color: const Color(0xFFF7931A),
            provider: notifDailyReminderEnabledProvider,
          ),
          _SwitchTile(
            icon: Icons.bar_chart_rounded,
            title: 'Resumen semanal',
            subtitle: 'Cada lunes, revisá tu semana',
            color: const Color(0xFF0066CC),
            provider: notifWeeklySummaryEnabledProvider,
          ),

          const SizedBox(height: 24),
          _SectionTitle('Finanzas'),
          _SettingsTile(
            icon: Icons.category_rounded,
            title: 'Administrar categorías',
            subtitle: 'Personalizá tus agrupaciones de gasto',
            color: AppTheme.colorWarning,
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Administrar cuentas',
            subtitle: 'Efectivo, Bancos, Tarjetas',
            color: AppTheme.colorTransfer,
            onTap: () => context.push('/accounts'),
          ),
          _SettingsTile(
            icon: Icons.repeat_rounded,
            title: 'Gastos recurrentes',
            subtitle: 'Suscripciones, alquileres, cuotas',
            color: const Color(0xFFAB47BC),
            onTap: () => context.push('/recurring'),
          ),
          _DefaultAccountTile(),
          _MercadoPagoTile(),

          const SizedBox(height: 24),
          _SectionTitle('Compras Inteligentes'),
          _ReminderDaysTile(),

          const SizedBox(height: 24),
          _SectionTitle('Inteligencia Artificial'),
          _SwitchTile(
            icon: Icons.mic_rounded,
            title: 'Asistente de voz',
            subtitle: 'Botón de IA en pantalla principal',
            color: const Color(0xFF6C63FF),
            provider: aiAssistantEnabledProvider,
          ),
          _ApiKeyTile(),

          const SizedBox(height: 24),
          _SectionTitle('Datos y Backup'),
          _SettingsTile(
            icon: Icons.backup_rounded,
            title: 'Crear backup',
            subtitle: 'Guardar copia en Descargas',
            color: AppTheme.colorIncome,
            onTap: () => _createBackup(context),
          ),
          _SettingsTile(
            icon: Icons.restore_rounded,
            title: 'Restaurar backup',
            subtitle: 'Recuperar datos desde archivo .sqlite',
            color: AppTheme.colorTransfer,
            onTap: () => _restoreBackup(context),
          ),

          const SizedBox(height: 32),
          _SectionTitle('Zona de Peligro', color: cs.error),
          Container(
            decoration: BoxDecoration(
              color: cs.error.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.error.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                _DangerTile(
                  icon: Icons.bug_report_rounded,
                  title: 'Cargar datos de prueba',
                  subtitle: 'Genera movimientos falsos para probar',
                  color: AppTheme.colorWarning,
                  onTap: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Generando datos...')),
                    );
                    final seeder = DatabaseSeeder(db);
                    await seeder.clearAndSeedMockData();
                    // Clear dismissed alerts so seed data alerts show fresh
                    await ref.read(dismissedAlertsProvider.notifier).clearAll();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Datos generados con éxito.')),
                      );
                    }
                  },
                ),
                Divider(
                    color: cs.error.withValues(alpha: 0.15),
                    height: 1,
                    indent: 56),
                _DangerTile(
                  icon: Icons.delete_forever_rounded,
                  title: 'Borrar todos los datos',
                  subtitle: 'Elimina todo — no se puede deshacer',
                  color: cs.error,
                  onTap: () => _deleteAll(context, ref, db),
                ),
              ],
            ),
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Future<void> _createBackup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
        content: Text('Creando backup...'),
        duration: Duration(seconds: 1)));
    try {
      final path = await BackupUtils.exportBackup();
      if (path != null) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Backup guardado en Descargas'),
            duration: Duration(seconds: 3)));
      } else {
        messenger.showSnackBar(const SnackBar(
            content: Text('No se encontró la base de datos')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.colorExpense));
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Restaurar backup?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          'Esto reemplazará TODOS tus datos actuales con los del backup. '
          'La app se cerrará y tendrás que volver a abrirla.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.colorTransfer),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final success = await BackupUtils.restoreBackup();
    if (success) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Backup restaurado. Cerrá y volvé a abrir la app.'),
        duration: Duration(seconds: 5),
      ));
    } else {
      messenger.showSnackBar(const SnackBar(
          content: Text('No se seleccionó archivo o hubo un error')));
    }
  }

  Future<void> _deleteAll(
      BuildContext context, WidgetRef ref, dynamic db) async {
    final cs = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Borrar todo?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          'Se eliminarán todas las cuentas, movimientos, objetivos, presupuestos y personas. '
          'Esta acción no se puede deshacer.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            child: const Text('Borrar todo'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    await db.delete(db.transactionsTable).go();
    await db.delete(db.accountsTable).go();
    await db.delete(db.categoriesTable).go();
    await db.delete(db.personsTable).go();
    await db.delete(db.goalsTable).go();
    await db.delete(db.budgetsTable).go();
    await db.delete(db.groupsTable).go();
    await db.delete(db.groupMembersTable).go();
    await db.delete(db.wishlistTable).go();
    await db.delete(db.userProfileTable).go();
    await ref.read(dismissedAlertsProvider.notifier).clearAll();

    // Sign out of Firebase if logged in
    try {
      final authState = ref.read(authStateProvider);
      if (authState.valueOrNull != null) {
        await ref.read(firebaseAuthServiceProvider).signOut();
      }
    } catch (_) {}

    // Reset skip-auth flag so router redirects to login
    await ref.read(skipAuthProvider).reset();

    // Reset onboarding so user can re-view it if desired
    await ref.read(onboardingProvider).reset();
  }
}

// ─────────────────────────────────────────────────────
// Connect Google Card — shown only when not logged in
// ─────────────────────────────────────────────────────
class _ConnectGoogleCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isLoggedIn = authState.valueOrNull != null;

    // Don't show if already logged in
    if (isLoggedIn) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GestureDetector(
        onTap: () async {
          try {
            final service = ref.read(firebaseAuthServiceProvider);
            final user = await service.signInWithGoogle();
            if (user != null) {
              // Clear skip-auth flag since they're now logged in
              await ref.read(skipAuthProvider).reset();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Cuenta conectada: ${user.email}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                  backgroundColor: const Color(0xFF5ECFB1),
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error al conectar: $e'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF40C4FF).withValues(alpha: 0.12),
                const Color(0xFF40C4FF).withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: const Color(0xFF40C4FF).withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF40C4FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.cloud_outlined,
                    color: Color(0xFF40C4FF), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conectar cuenta Google',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Activá backup y sincronización',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: Colors.white.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Profile Card — prominent with avatar
// ─────────────────────────────────────────────────────
class _ProfileCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileStreamProvider);
    final profile = profileAsync.valueOrNull;
    final fmt = NumberFormat.currency(
        symbol: '\$', decimalDigits: 0, locale: 'es_AR');

    final name = profile?.name?.isNotEmpty == true ? profile!.name! : '';
    final hasSalary = profile?.monthlySalary != null;
    final hasPayDay = profile?.payDay != null;
    final initials = name.isNotEmpty
        ? name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';

    return GestureDetector(
      onTap: () => _showProfileEditor(context, ref, profile),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.colorTransfer.withValues(alpha: 0.12),
              AppTheme.colorTransfer.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppTheme.colorTransfer.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.colorTransfer.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.colorTransfer),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isNotEmpty ? name : 'Configurá tu perfil',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (hasSalary || hasPayDay)
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (hasSalary)
                          _ProfileChip(
                            icon: Icons.payments_rounded,
                            label: fmt.format(profile!.monthlySalary),
                          ),
                        if (hasPayDay)
                          _ProfileChip(
                            icon: Icons.calendar_today_rounded,
                            label: 'Día ${profile!.payDay}',
                          ),
                      ],
                    )
                  else
                    Text(
                      'Sueldo y día de cobro sin configurar',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12),
                    ),
                ],
              ),
            ),
            Icon(Icons.edit_rounded,
                color: AppTheme.colorTransfer.withValues(alpha: 0.5),
                size: 20),
          ],
        ),
      ),
    );
  }

  void _showProfileEditor(
      BuildContext context, WidgetRef ref, dynamic profile) {
    final nameCtrl = TextEditingController(text: profile?.name ?? '');
    final salaryCtrl = TextEditingController(
      text: profile?.monthlySalary != null
          ? formatInitialAmount(profile.monthlySalary)
          : '',
    );
    final payDayCtrl = TextEditingController(
      text: profile?.payDay != null ? profile.payDay.toString() : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
          decoration: const BoxDecoration(
            color: Color(0xFF18181F),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 24),
              Text('Mi Perfil',
                  style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(height: 8),
              Text(
                'Estos datos se usan para calcular horas de trabajo, cuenta regresiva de cobro y registro de ingresos.',
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.white54),
              ),
              const SizedBox(height: 24),
              _ProfileField(
                controller: nameCtrl,
                label: 'Tu nombre',
                hint: 'Ej: David',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 14),
              _ProfileField(
                controller: salaryCtrl,
                label: 'Sueldo mensual',
                hint: 'Ej: 850.000',
                icon: Icons.payments_outlined,
                prefix: '\$ ',
                keyboard: TextInputType.number,
                formatters: [ThousandsSeparatorFormatter()],
              ),
              const SizedBox(height: 14),
              _ProfileField(
                controller: payDayCtrl,
                label: 'Día de cobro (1-31)',
                hint: 'Ej: 5',
                icon: Icons.calendar_today_rounded,
                keyboard: TextInputType.number,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () async {
                    final payDay = int.tryParse(payDayCtrl.text);
                    if (payDay != null && (payDay < 1 || payDay > 31)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'El día de cobro debe ser entre 1 y 31')),
                      );
                      return;
                    }
                    await ref
                        .read(userProfileServiceProvider)
                        .updateProfile(
                          name: nameCtrl.text.trim().isEmpty
                              ? null
                              : nameCtrl.text.trim(),
                          monthlySalary: salaryCtrl.text.isNotEmpty
                              ? parseFormattedAmount(salaryCtrl.text)
                              : null,
                          payDay: payDay,
                          clearSalary: salaryCtrl.text.trim().isEmpty,
                          clearPayDay: payDayCtrl.text.trim().isEmpty,
                        );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Perfil actualizado')),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.colorTransfer,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Guardar',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ProfileChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.colorTransfer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.colorTransfer),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? prefix;
  final TextInputType? keyboard;
  final List<dynamic>? formatters;

  const _ProfileField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.prefix,
    this.keyboard,
    this.formatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: formatters?.cast(),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.colorTransfer),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
        prefixText: prefix,
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppTheme.colorTransfer),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Tab Config Sheet (extracted as top-level function)
// ─────────────────────────────────────────────────────
// showTabConfigSheet() moved to lib/core/widgets/tab_config_sheet.dart

// ─────────────────────────────────────────────────────
// Reminder Days Tile
// ─────────────────────────────────────────────────────
class _ReminderDaysTile extends ConsumerWidget {
  const _ReminderDaysTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(globalReminderDaysProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.colorWarning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.notifications_active_rounded,
                    color: AppTheme.colorWarning, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recordatorio "¿Lo necesitás?"',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Recordar a los $days días de agregar un item',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.colorWarning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$days d',
                  style: const TextStyle(
                      color: AppTheme.colorWarning,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppTheme.colorWarning,
              inactiveTrackColor: Colors.white12,
              thumbColor: AppTheme.colorWarning,
              overlayColor:
                  AppTheme.colorWarning.withValues(alpha: 0.15),
              trackHeight: 3,
            ),
            child: Slider(
              value: days.toDouble(),
              min: 5,
              max: 90,
              divisions: 17,
              label: '$days días',
              onChanged: (val) {
                ref
                    .read(globalReminderDaysProvider.notifier)
                    .setDays(val.round());
              },
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('5 días',
                  style:
                      TextStyle(color: Colors.white24, fontSize: 10)),
              Text('90 días',
                  style:
                      TextStyle(color: Colors.white24, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// API Key Tile
// ─────────────────────────────────────────────────────
class _ApiKeyTile extends StatefulWidget {
  @override
  State<_ApiKeyTile> createState() => _ApiKeyTileState();
}

class _ApiKeyTileState extends State<_ApiKeyTile> {
  String? _apiKey;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final key = await AiTransactionParser.getApiKey();
    if (mounted) setState(() { _apiKey = key; _loading = false; });
  }

  bool get _hasKey => _apiKey != null && _apiKey!.isNotEmpty;

  void _showKeyDialog() {
    final ctrl = TextEditingController(text: _apiKey ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('API Key de Anthropic',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Necesitás una API key de Anthropic para la detección inteligente de movimientos con IA.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'sk-ant-...',
                labelStyle:
                    const TextStyle(color: AppTheme.colorTransfer),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          if (_hasKey)
            TextButton(
              onPressed: () async {
                await AiTransactionParser.clearApiKey();
                if (mounted) setState(() => _apiKey = null);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Eliminar',
                  style: TextStyle(color: AppTheme.colorExpense)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () async {
              final key = ctrl.text.trim();
              if (key.isNotEmpty) {
                await AiTransactionParser.saveApiKey(key);
                if (mounted) setState(() => _apiKey = key);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.colorTransfer),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    return _SettingsTile(
      icon: Icons.auto_awesome_rounded,
      title: 'IA — API Key de Anthropic',
      subtitle: _hasKey
          ? 'Configurada — Tocá para cambiar o eliminar'
          : 'Sin configurar — La IA usará modo regex',
      color: _hasKey ? AppTheme.colorIncome : AppTheme.colorTransfer,
      highlight: _hasKey,
      onTap: _showKeyDialog,
    );
  }
}

// ─────────────────────────────────────────────────────
// Currency Select Tile
// ─────────────────────────────────────────────────────
class _CurrencySelectTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCurrenciesProvider);

    return _SettingsTile(
      icon: Icons.currency_exchange_rounded,
      title: 'Cotizaciones',
      subtitle: '${selected.length} de ${kAllCurrencies.length} visibles',
      color: const Color(0xFF6C63FF),
      onTap: () => showCurrencySelectSheet(context, ref),
    );
  }
}

// ─────────────────────────────────────────────────────
// Crypto Select Tile
// ─────────────────────────────────────────────────────
class _CryptoSelectTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCryptosProvider);

    return _SettingsTile(
      icon: Icons.currency_bitcoin_rounded,
      title: 'Criptomonedas',
      subtitle: '${selected.length} de ${kAvailableCryptos.length} visibles',
      color: const Color(0xFFF7931A),
      onTap: () => showCryptoSelectSheet(context, ref),
    );
  }
}

// ─────────────────────────────────────────────────────
// Stocks Select Tile
// ─────────────────────────────────────────────────────
class _StocksSelectTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedStocksProvider);

    return _SettingsTile(
      icon: Icons.show_chart_rounded,
      title: 'Acciones',
      subtitle: '${selected.length} de ${kAvailableStocks.length} visibles',
      color: const Color(0xFF0066CC),
      onTap: () => showStocksSelectSheet(context, ref),
    );
  }
}

// ─────────────────────────────────────────────────────
// Home Widgets Tile
// ─────────────────────────────────────────────────────
class _HomeWidgetsTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(homeWidgetConfigProvider);
    final visible = config.visibleWidgets.length;

    return _SettingsTile(
      icon: Icons.dashboard_customize_rounded,
      title: 'Widgets de inicio',
      subtitle: '$visible de ${kHomeWidgets.length} visibles · Reordenables',
      color: AppTheme.colorTransfer,
      onTap: () => showHomeWidgetConfigSheet(context, ref),
    );
  }
}

// ─────────────────────────────────────────────────────
// Default Account Tile
// ─────────────────────────────────────────────────────
class _DefaultAccountTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final accounts = accountsAsync.valueOrNull ?? [];
    final current = accounts.where((a) => a.isDefault).firstOrNull;

    return _SettingsTile(
      icon: Icons.wallet_rounded,
      title: 'Cuenta por defecto',
      subtitle: current?.name ?? 'Sin asignar',
      color: const Color(0xFF4ECDC4),
      onTap: () async {
        if (accounts.isEmpty) return;
        final selected = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: const Color(0xFF18181F),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (ctx) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Elegí tu cuenta por defecto',
                    style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Se usará al cargar movimientos nuevos',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
                  ),
                  const SizedBox(height: 16),
                  ...accounts.map((a) => ListTile(
                    leading: Icon(
                      a.isCreditCard ? Icons.credit_card_rounded : Icons.account_balance_wallet_rounded,
                      color: a.isDefault ? const Color(0xFF4ECDC4) : Colors.white38,
                    ),
                    title: Text(a.name, style: TextStyle(
                      color: Colors.white,
                      fontWeight: a.isDefault ? FontWeight.w700 : FontWeight.w400,
                    )),
                    subtitle: Text(
                      a.isCreditCard ? 'Tarjeta de crédito' : formatAmount(a.balance),
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    trailing: a.isDefault
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF4ECDC4), size: 20)
                        : null,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onTap: () => Navigator.pop(ctx, a.id),
                  )),
                ],
              ),
            );
          },
        );
        if (selected != null) {
          await ref.read(accountServiceProvider).setDefaultAccount(selected);
        }
      },
    );
  }
}

// ─────────────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────────────
class _MercadoPagoTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(mpConnectedProvider);
    final connected = isConnected.valueOrNull ?? false;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: GestureDetector(
        onTap: () => context.push('/mercado-pago'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF009EE3).withValues(alpha: 0.12),
                const Color(0xFF009EE3).withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFF009EE3).withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF009EE3).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_rounded,
                    color: Color(0xFF009EE3), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected ? 'Mercado Pago conectado' : 'Conectar Mercado Pago',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      connected
                          ? 'Ver saldo y movimientos'
                          : 'Sincronizá tu saldo y gastos',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                connected
                    ? Icons.check_circle_rounded
                    : Icons.arrow_forward_ios_rounded,
                color: connected
                    ? const Color(0xFF5ECFB1)
                    : const Color(0xFF009EE3),
                size: connected ? 22 : 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color? color;

  const _SectionTitle(this.title, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: color ?? Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool highlight;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: highlight
            ? color.withValues(alpha: 0.08)
            : const Color(0xFF1E1E2C).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? color.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.white,
                fontSize: 14)),
        subtitle: Text(subtitle,
            style: const TextStyle(
                fontSize: 12, color: Colors.white54)),
        trailing: Icon(Icons.chevron_right_rounded,
            color: Colors.white.withValues(alpha: 0.3), size: 20),
      ),
    );
  }
}

class _DangerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _DangerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: color, size: 22),
      title: Text(title,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text(subtitle,
          style:
              const TextStyle(color: Colors.white38, fontSize: 12)),
    );
  }
}

class _SwitchTile extends ConsumerWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final StateNotifierProvider<BoolPrefNotifier, bool> provider;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.provider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(provider);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.white,
                fontSize: 14)),
        subtitle: Text(subtitle,
            style: const TextStyle(
                fontSize: 12, color: Colors.white54)),
        trailing: Switch.adaptive(
          value: enabled,
          onChanged: (_) => ref.read(provider.notifier).toggle(),
          activeThumbColor: color,
          activeTrackColor: color.withValues(alpha: 0.3),
          inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
          inactiveThumbColor: Colors.white38,
        ),
      ),
    );
  }
}

/// Selector for notification timing (days)
class _NotifDaysSelector extends ConsumerWidget {
  final IconData icon;
  final String title;
  final Color color;
  final StateNotifierProvider<IntPrefNotifier, int> provider;
  final List<int> options;
  final String suffix;

  const _NotifDaysSelector({
    required this.icon,
    required this.title,
    required this.color,
    required this.provider,
    required this.options,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(provider);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.white,
                fontSize: 14)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<int>(
            value: options.contains(current) ? current : options.first,
            dropdownColor: const Color(0xFF2A2A3C),
            underline: const SizedBox.shrink(),
            icon: Icon(Icons.expand_more_rounded, color: color, size: 18),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            items: options
                .map((v) => DropdownMenuItem(
                      value: v,
                      child: Text('$v${suffix.isEmpty ? " días" : suffix}'),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) ref.read(provider.notifier).set(v);
            },
          ),
        ),
      ),
    );
  }
}

class _ConversionRateTile extends ConsumerWidget {
  const _ConversionRateTile();

  static const _rateLabels = {
    'blue': 'Dólar Blue',
    'oficial': 'Dólar Oficial',
    'mep': 'Dólar MEP',
    'ccl': 'Dólar CCL',
    'tarjeta': 'Dólar Tarjeta',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(preferredConversionRateProvider);
    final label = _rateLabels[current] ?? current;

    return _SettingsTile(
      icon: Icons.currency_exchange_rounded,
      title: 'Cotización para conversión',
      subtitle: label,
      color: const Color(0xFF00BCD4),
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF1E1E2C),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(
                    color: Colors.white24, borderRadius: BorderRadius.circular(2),
                  )),
                  const SizedBox(height: 16),
                  Text('Cotización para conversión', style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
                  )),
                  const SizedBox(height: 4),
                  const Text(
                    'Se usa para convertir cuentas en USD al balance total',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ..._rateLabels.entries.map((e) {
                    final isSel = current == e.key;
                    return ListTile(
                      title: Text(e.value, style: TextStyle(
                        color: isSel ? const Color(0xFF00BCD4) : Colors.white,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                        fontSize: 14,
                      )),
                      trailing: isSel
                          ? const Icon(Icons.check_rounded, color: Color(0xFF00BCD4), size: 20)
                          : null,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: isSel ? const Color(0xFF00BCD4).withValues(alpha: 0.08) : null,
                      onTap: () {
                        ref.read(preferredConversionRateProvider.notifier).set(e.key);
                        Navigator.pop(ctx);
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
