import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/providers/shell_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../accounts/domain/models/account.dart';
import '../pages/transactions_page.dart' show txSelectedMonthProvider, txSelectedAccountProvider;
import 'filters_bottom_sheet.dart';

/// Una sola fila ~44px que reemplaza los 2 ejes verticales de filtros.
/// Izquierda: navegador temporal `[<] Mes [>]` (tap label = picker).
/// Derecha: chip "Filtros (N)" que abre el bottom sheet.
class TransactionsFilterBar extends ConsumerWidget {
  final List<Account> accounts;
  final List<DateTime> availableMonths;
  const TransactionsFilterBar({
    super.key,
    required this.accounts,
    required this.availableMonths,
  });

  static const _monthNames = [
    '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  String _monthLabel(DateTime? m) {
    if (m == null) return 'Todos los meses';
    return '${_monthNames[m.month]} ${m.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final selectedMonth = ref.watch(txSelectedMonthProvider);
    final filterType = ref.watch(txFilterProvider);
    final selectedAccountId = ref.watch(txSelectedAccountProvider);

    final activeFilters = (filterType != TxFilterType.all ? 1 : 0) +
        (selectedAccountId != null ? 1 : 0);

    final canPrev = selectedMonth != null;
    final canNext = selectedMonth != null;

    void prevMonth() {
      final base = selectedMonth ?? DateTime.now();
      final newMonth = DateTime(base.year, base.month - 1);
      ref.read(txSelectedMonthProvider.notifier).state = newMonth;
    }

    void nextMonth() {
      final base = selectedMonth ?? DateTime.now();
      final newMonth = DateTime(base.year, base.month + 1);
      final now = DateTime.now();
      // No permitir avanzar más allá del mes actual.
      if (newMonth.isAfter(DateTime(now.year, now.month))) return;
      ref.read(txSelectedMonthProvider.notifier).state = newMonth;
    }

    Future<void> openMonthPicker() async {
      final picked = await showModalBottomSheet<DateTime?>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _MonthPickerSheet(months: availableMonths, selected: selectedMonth),
      );
      if (picked != null || picked == null) {
        // null intencional = "Todos los meses"
        ref.read(txSelectedMonthProvider.notifier).state = picked;
      }
    }

    void openFilters() {
      FiltersBottomSheet.show(
        context,
        accounts: accounts,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          // Mes navigator
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  _IconBtn(
                    icon: Icons.chevron_left_rounded,
                    enabled: canPrev,
                    onTap: canPrev ? prevMonth : null,
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: openMonthPicker,
                      child: Center(
                        child: Text(
                          _monthLabel(selectedMonth),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _IconBtn(
                    icon: Icons.chevron_right_rounded,
                    enabled: canNext,
                    onTap: canNext ? nextMonth : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Filtros chip
          GestureDetector(
            onTap: openFilters,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: activeFilters > 0
                    ? cs.primary.withValues(alpha: 0.18)
                    : cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: activeFilters > 0
                      ? cs.primary.withValues(alpha: 0.5)
                      : cs.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: activeFilters > 0 ? cs.primary : cs.onSurface,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    activeFilters > 0 ? 'Filtros ($activeFilters)' : 'Filtros',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: activeFilters > 0 ? cs.primary : cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;
  const _IconBtn({required this.icon, required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 20,
          color: enabled ? cs.onSurface : AppTheme.textTertiaryDark,
        ),
      ),
    );
  }
}

class _MonthPickerSheet extends StatelessWidget {
  final List<DateTime> months;
  final DateTime? selected;
  const _MonthPickerSheet({required this.months, this.selected});

  static const _monthNames = [
    '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Elegí un mes',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => Navigator.pop<DateTime?>(context, null),
                  icon: const Icon(Icons.all_inclusive_rounded, size: 16),
                  label: const Text('Ver todos'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: months.length,
              itemBuilder: (_, i) {
                final m = months[i];
                final isSelected = selected != null &&
                    selected!.year == m.year &&
                    selected!.month == m.month;
                return ListTile(
                  title: Text(
                    '${_monthNames[m.month]} ${m.year}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? cs.primary : cs.onSurface,
                    ),
                  ),
                  trailing: isSelected ? Icon(Icons.check_rounded, color: cs.primary) : null,
                  onTap: () => Navigator.pop(context, m),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
