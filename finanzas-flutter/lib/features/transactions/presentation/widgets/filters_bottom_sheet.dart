import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/providers/shell_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../accounts/domain/models/account.dart';
import '../pages/transactions_page.dart' show txSelectedAccountProvider;

class FiltersBottomSheet extends ConsumerStatefulWidget {
  final List<Account> accounts;
  const FiltersBottomSheet({super.key, required this.accounts});

  static Future<void> show(BuildContext context, {required List<Account> accounts}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FiltersBottomSheet(accounts: accounts),
    );
  }

  @override
  ConsumerState<FiltersBottomSheet> createState() => _FiltersBottomSheetState();
}

class _FiltersBottomSheetState extends ConsumerState<FiltersBottomSheet> {
  late TxFilterType _localType;
  String? _localAccountId;

  @override
  void initState() {
    super.initState();
    _localType = ref.read(txFilterProvider);
    _localAccountId = ref.read(txSelectedAccountProvider);
  }

  void _apply() {
    ref.read(txFilterProvider.notifier).state = _localType;
    ref.read(txSelectedAccountProvider.notifier).state = _localAccountId;
    Navigator.pop(context);
  }

  void _clearAll() {
    setState(() {
      _localType = TxFilterType.all;
      _localAccountId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Text(
                  'Filtros',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _clearAll,
                  child: Text(
                    'Limpiar todo',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Tipo ──
          _SectionTitle('Tipo'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TxFilterType.values.map((t) {
                final selected = t == _localType;
                final (label, color) = switch (t) {
                  TxFilterType.all => ('Todos', cs.primary),
                  TxFilterType.income => ('Ingresos', AppTheme.colorIncome),
                  TxFilterType.expense => ('Gastos', AppTheme.colorExpense),
                  TxFilterType.shared => ('Compartidos', AppTheme.colorWarning),
                };
                return _ChipTile(
                  label: label,
                  color: color,
                  selected: selected,
                  onTap: () => setState(() => _localType = t),
                );
              }).toList(),
            ),
          ),
          // ── Cuenta ──
          _SectionTitle('Cuenta'),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _AccountRow(
                  label: 'Todas las cuentas',
                  iconColor: cs.primary,
                  selected: _localAccountId == null,
                  onTap: () => setState(() => _localAccountId = null),
                ),
                ...widget.accounts.map((a) => _AccountRow(
                      label: a.name,
                      iconColor: cs.primary,
                      selected: _localAccountId == a.id,
                      isCard: a.isCreditCard,
                      onTap: () => setState(() => _localAccountId = a.id),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _apply,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Aplicar',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondaryDark,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ChipTile extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ChipTile({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.5) : cs.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? color : cs.onSurface,
          ),
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final String label;
  final Color iconColor;
  final bool selected;
  final bool isCard;
  final VoidCallback onTap;
  const _AccountRow({
    required this.label,
    required this.iconColor,
    required this.selected,
    required this.onTap,
    this.isCard = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: 0.4)
                : cs.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isCard ? Icons.credit_card_rounded : Icons.account_balance_wallet_rounded,
              size: 18,
              color: selected ? cs.primary : AppTheme.textSecondaryDark,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? cs.primary : cs.onSurface,
                ),
              ),
            ),
            if (selected) Icon(Icons.check_rounded, color: cs.primary, size: 18),
          ],
        ),
      ),
    );
  }
}
