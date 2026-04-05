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
import '../../../../core/providers/tab_config_provider.dart';
import '../../../../core/providers/alerts_provider.dart';
import '../../../wishlist/presentation/providers/wishlist_provider.dart';

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

          const SizedBox(height: 24),
          _SectionTitle('Compras Inteligentes'),
          _ReminderDaysTile(),

          const SizedBox(height: 24),
          _SectionTitle('Inteligencia Artificial'),
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
          const SizedBox(height: 100),
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
    await db.ensureDefaultCashAccount();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Datos eliminados. Configurá tu primera cuenta para empezar.'),
          duration: Duration(seconds: 4),
        ),
      );
      context.go('/accounts');
    }
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
void showTabConfigSheet(BuildContext context, WidgetRef ref) {
  final currentTabs = List<String>.from(ref.read(tabConfigProvider));

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final allDisabled =
            kAllTabs.where((t) => !currentTabs.contains(t)).toList();

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 24),
          decoration: const BoxDecoration(
            color: Color(0xFF18181F),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Personalizar navegación',
                          style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                    FilledButton(
                      onPressed: () {
                        ref
                            .read(tabConfigProvider.notifier)
                            .setOrder(currentTabs);
                        Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.colorTransfer,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                      ),
                      child: const Text('Guardar',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                    'Mantené presionado y arrastrá para reordenar · Máximo $kMaxVisibleTabs',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.white38)),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('ACTIVAS  (${currentTabs.length})',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white38,
                          letterSpacing: 1)),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: currentTabs.length,
                      onReorder: (oldIndex, newIndex) {
                        setLocal(() {
                          if (newIndex > oldIndex) newIndex--;
                          final item = currentTabs.removeAt(oldIndex);
                          currentTabs.insert(newIndex, item);
                        });
                      },
                      proxyDecorator: (child, index, animation) =>
                          Material(
                        color: Colors.transparent,
                        elevation: 4,
                        shadowColor: AppTheme.colorTransfer
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(14),
                        child: child,
                      ),
                      itemBuilder: (ctx, index) {
                        final tabId = currentTabs[index];
                        final info = kTabInfo[tabId]!;
                        final locked =
                            kAlwaysVisibleTabs.contains(tabId);
                        return Container(
                          key: ValueKey(tabId),
                          margin:
                              const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E2C),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppTheme.colorTransfer
                                    .withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.drag_handle_rounded,
                                  size: 20, color: Colors.white38),
                              const SizedBox(width: 12),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppTheme.colorTransfer
                                      .withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: Icon(info.icon,
                                    size: 16,
                                    color: AppTheme.colorTransfer),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(info.label,
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white)),
                              ),
                              if (locked)
                                Icon(Icons.lock_rounded,
                                    size: 14,
                                    color: Colors.white
                                        .withValues(alpha: 0.15))
                              else
                                GestureDetector(
                                  onTap: () {
                                    if (currentTabs.length <= 3) return;
                                    setLocal(() {
                                      currentTabs.removeAt(index);
                                    });
                                  },
                                  child: Icon(
                                      Icons
                                          .remove_circle_outline_rounded,
                                      size: 20,
                                      color: currentTabs.length <= 3
                                          ? Colors.white12
                                          : AppTheme.colorExpense
                                              .withValues(alpha: 0.7)),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    if (allDisabled.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 24),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                              'DISPONIBLES  (${allDisabled.length})',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white38,
                                  letterSpacing: 1)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...allDisabled.map((tabId) {
                        final info = kTabInfo[tabId]!;
                        final canAdd =
                            currentTabs.length < kMaxVisibleTabs;
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color:
                                  Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 32),
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withValues(alpha: 0.05),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Icon(info.icon,
                                      size: 16,
                                      color: Colors.white38),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(info.label,
                                      style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white54)),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    if (!canAdd) return;
                                    setLocal(() {
                                      final moreIdx = currentTabs
                                          .indexOf('more');
                                      if (moreIdx >= 0 &&
                                          moreIdx ==
                                              currentTabs.length - 1) {
                                        currentTabs.insert(
                                            moreIdx, tabId);
                                      } else {
                                        currentTabs.add(tabId);
                                      }
                                    });
                                  },
                                  child: Icon(
                                      Icons
                                          .add_circle_outline_rounded,
                                      size: 20,
                                      color: canAdd
                                          ? AppTheme.colorIncome
                                              .withValues(alpha: 0.7)
                                          : Colors.white12),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

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
// Shared Widgets
// ─────────────────────────────────────────────────────
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
