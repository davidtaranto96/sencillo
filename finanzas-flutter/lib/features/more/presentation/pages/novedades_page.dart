import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';

class NovedadesPage extends StatelessWidget {
  const NovedadesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Novedades',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          // Current version
          _VersionCard(
            version: 'v1.2.0',
            date: 'Abril 2026',
            isCurrent: true,
            items: const [
              _ChangeItem(icon: Icons.currency_exchange_rounded, text: 'Cotización del dólar en tiempo real con refresh manual', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.people_rounded, text: 'Sistema de amigos con QR y gastos compartidos', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.cloud_rounded, text: 'Backup en la nube con Firebase Storage', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.auto_awesome_rounded, text: 'Alertas inteligentes con snooze y descarte', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.play_circle_outline, text: 'Tutorial restablecible desde Configuración', type: _ChangeType.improvement),
              _ChangeItem(icon: Icons.volunteer_activism_rounded, text: 'Sección de donaciones y links del proyecto', type: _ChangeType.feature),
            ],
          ),

          _VersionCard(
            version: 'v1.1.0',
            date: 'Marzo 2026',
            items: const [
              _ChangeItem(icon: Icons.credit_card_rounded, text: 'Tarjetas de crédito con cierre y vencimiento', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.shopping_cart_rounded, text: 'Lista de deseos con recordatorios', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.bar_chart_rounded, text: 'Reportes y gráficos financieros', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.calendar_month_rounded, text: 'Resumen y cierre de mes', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.savings_rounded, text: 'Metas de ahorro con progreso visual', type: _ChangeType.improvement),
            ],
          ),

          _VersionCard(
            version: 'v1.0.0',
            date: 'Febrero 2026',
            items: const [
              _ChangeItem(icon: Icons.rocket_launch_rounded, text: 'Lanzamiento de SENCILLO', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.account_balance_wallet_rounded, text: 'Dashboard con balance y cuentas', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.swap_horiz_rounded, text: 'CRUD de transacciones, cuentas y presupuestos', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.donut_large_rounded, text: 'Presupuesto por categoría', type: _ChangeType.feature),
              _ChangeItem(icon: Icons.login_rounded, text: 'Google Sign-In con Firebase Auth', type: _ChangeType.feature),
            ],
          ),

          const SizedBox(height: 24),

          // Roadmap
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.colorTransfer.withValues(alpha: 0.12),
                  AppTheme.colorTransfer.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.colorTransfer.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.map_rounded, color: AppTheme.colorTransfer, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Próximamente',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _RoadmapItem(text: 'Exportar reportes a PDF', icon: Icons.picture_as_pdf_rounded),
                _RoadmapItem(text: 'Notificaciones push de alertas', icon: Icons.notifications_rounded),
                _RoadmapItem(text: 'Widgets de pantalla de inicio', icon: Icons.widgets_rounded),
                _RoadmapItem(text: 'Sincronización multi-dispositivo', icon: Icons.sync_rounded),
                _RoadmapItem(text: 'Modo claro / tema personalizable', icon: Icons.palette_rounded),
              ],
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Version Card
// ─────────────────────────────────────────────
class _VersionCard extends StatelessWidget {
  final String version;
  final String date;
  final bool isCurrent;
  final List<_ChangeItem> items;

  const _VersionCard({
    required this.version,
    required this.date,
    this.isCurrent = false,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppTheme.colorTransfer.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent
              ? AppTheme.colorTransfer.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppTheme.colorTransfer.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  version,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isCurrent ? AppTheme.colorTransfer : Colors.white54,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                date,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
              ),
              const Spacer(),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.colorIncome.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ACTUAL',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.colorIncome,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: item.type.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(item.icon, size: 14, color: item.type.color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          item.text,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

enum _ChangeType {
  feature,
  improvement,
  fix;

  Color get color {
    switch (this) {
      case _ChangeType.feature:
        return AppTheme.colorTransfer;
      case _ChangeType.improvement:
        return AppTheme.colorIncome;
      case _ChangeType.fix:
        return AppTheme.colorWarning;
    }
  }
}

class _ChangeItem {
  final IconData icon;
  final String text;
  final _ChangeType type;

  const _ChangeItem({required this.icon, required this.text, required this.type});
}

class _RoadmapItem extends StatelessWidget {
  final String text;
  final IconData icon;

  const _RoadmapItem({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.colorTransfer.withValues(alpha: 0.6)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
