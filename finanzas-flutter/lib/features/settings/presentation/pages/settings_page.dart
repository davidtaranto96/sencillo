import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/database/database_seeder.dart';

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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          _SectionTitle('General'),
          _SettingsListTile(
            icon: Icons.dark_mode_rounded,
            title: 'Apariencia',
            subtitle: 'Tema Oscuro',
            onTap: () {},
          ),
          _SettingsListTile(
            icon: Icons.attach_money_rounded,
            title: 'Moneda Principal',
            subtitle: 'Peso Argentino (ARS)',
            onTap: () {},
          ),

          const SizedBox(height: 24),
          _SectionTitle('Preferencias de Finanzas'),
          _SettingsListTile(
            icon: Icons.category_rounded,
            title: 'Administrar Categorías',
            subtitle: 'Personalizá tus agrupaciones de gasto',
            onTap: () {},
          ),
          _SettingsListTile(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Administrar Cuentas',
            subtitle: 'Efectivo, Bancos, Tarjetas',
            onTap: () {},
          ),

          const SizedBox(height: 24),
          _SectionTitle('Datos y Backup'),
          _SettingsListTile(
            icon: Icons.cloud_upload_rounded,
            title: 'Exportar Datos',
            subtitle: 'Generar CSV de todos los movimientos',
            onTap: () {},
          ),
          
          const SizedBox(height: 32),
          _SectionTitle('Zona de Peligro', color: cs.error),
          Container(
            decoration: BoxDecoration(
              color: cs.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.error.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Icon(Icons.bug_report_rounded, color: AppTheme.colorWarning),
                  title: const Text('Cargar datos de prueba', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                  subtitle: const Text('Genera movimientos falsos en SQLite para probar', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  onTap: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Generando datos en Drift...')),
                    );
                    final seeder = DatabaseSeeder(db);
                    await seeder.clearAndSeedMockData();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Datos generados con éxito. Usa Refrescar.')),
                      );
                    }
                  },
                ),
                Divider(color: cs.error.withValues(alpha: 0.2), height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Icon(Icons.delete_forever_rounded, color: cs.error),
                  title: Text('Borrar toda la base de datos', style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
                  onTap: () async {
                    await db.delete(db.transactionsTable).go();
                    await db.delete(db.accountsTable).go();
                    await db.delete(db.categoriesTable).go();
                    await db.delete(db.personsTable).go();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('SQLite Limpio.')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
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
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: color ?? Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white54)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
      ),
    );
  }
}
