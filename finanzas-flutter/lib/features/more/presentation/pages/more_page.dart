import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';


class MorePage extends StatelessWidget {
  const MorePage({super.key});

  static final _items = [
    _MoreItem(
      icon: Icons.calendar_month_rounded,
      label: 'Mes',
      subtitle: 'Resumen mensual completo',
      color: AppTheme.colorTransfer,
      path: '/monthly_overview',
    ),
    _MoreItem(
      icon: Icons.people_rounded,
      label: 'Personas',
      subtitle: 'Quién me debe · Qué debo',
      color: AppTheme.colorIncome,
      path: '/people',
    ),
    _MoreItem(
      icon: Icons.shopping_cart_rounded,
      label: 'Compras inteligentes',
      subtitle: 'Decidí si conviene comprar',
      color: AppTheme.colorWarning,
      path: '/wishlist',
    ),
    _MoreItem(
      icon: Icons.bar_chart_rounded,
      label: 'Reportes',
      subtitle: 'Métricas y análisis',
      color: AppTheme.colorExpense,
      path: '/reports',
    ),
    _MoreItem(
      icon: Icons.settings_rounded,
      label: 'Configuración',
      subtitle: 'Cuentas, categorías, moneda',
      color: AppTheme.colorNeutral,
      path: '/settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Más')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = _items[index];
          return Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              title: Text(
                item.label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              subtitle: Text(
                item.subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: Icon(Icons.chevron_right_rounded,
                  color: cs.onSurfaceVariant, size: 20),
              onTap: () {
                if (item.path != null) {
                  context.push(item.path!);
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class _MoreItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final String? path;
  final Color color;
  const _MoreItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    this.path,
  });
}
