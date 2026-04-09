import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/logic/account_service.dart';
import '../../domain/models/account.dart' as dom;

// ── Icon & color catalogs ──

const accountIcons = <String, IconData>{
  'wallet': Icons.account_balance_wallet_rounded,
  'bank': Icons.account_balance_rounded,
  'credit_card': Icons.credit_card_rounded,
  'savings': Icons.savings_rounded,
  'cash': Icons.payments_rounded,
  'phone': Icons.phone_android_rounded,
  'store': Icons.store_rounded,
  'piggy': Icons.savings_outlined,
  'chart': Icons.show_chart_rounded,
  'world': Icons.public_rounded,
};

const accountColors = <Color>[
  AppTheme.colorTransfer,
  AppTheme.colorIncome,
  AppTheme.colorExpense,
  AppTheme.colorWarning,
  Color(0xFF6C63FF),
  Color(0xFF00BCD4),
  Color(0xFFFF6B9D),
  Color(0xFFFF9800),
  Color(0xFF8BC34A),
  Color(0xFF9C27B0),
];

IconData getAccountIcon(String name) {
  return accountIcons[name] ?? Icons.account_balance_wallet_rounded;
}

Color getAccountColor(dom.Account acc) {
  if (acc.color != null) {
    return Color(
      int.tryParse(acc.color!.replaceFirst('#', ''), radix: 16) ??
          AppTheme.colorTransfer.toARGB32(),
    );
  }
  return AppTheme.colorTransfer;
}

/// Unified edit account bottom sheet — used from both accounts list and detail page.
void showEditAccountSheet(BuildContext context, WidgetRef ref, dom.Account account) {
  final nameCtrl = TextEditingController(text: account.name);
  final balanceCtrl = TextEditingController(text: formatInitialAmount(account.balance));
  final aliasCtrl = TextEditingController(text: account.alias ?? '');
  final cvuCtrl = TextEditingController(text: account.cvu ?? '');
  final closingDayCtrl = TextEditingController(text: account.closingDay?.toString() ?? '');
  final dueDayCtrl = TextEditingController(text: account.dueDay?.toString() ?? '');
  final creditLimitCtrl = TextEditingController(
      text: account.creditLimit != null ? formatInitialAmount(account.creditLimit!) : '');
  final debtCtrl = TextEditingController(
      text: account.pendingStatementAmount > 0
          ? formatInitialAmount(account.pendingStatementAmount)
          : '');

  String selectedIcon = account.icon ?? 'wallet';
  Color selectedColor = getAccountColor(account);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) => SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
          decoration: const BoxDecoration(
            color: Color(0xFF18181F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text('Editar cuenta',
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(height: 24),

              // ── Name ──
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  labelStyle: const TextStyle(color: AppTheme.colorTransfer),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),

              const SizedBox(height: 16),

              // ── Balance ──
              TextField(
                controller: balanceCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorFormatter()],
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: account.isCreditCard ? 'Gastos del periodo' : 'Saldo actual',
                  prefixText: r'$ ',
                  labelStyle: const TextStyle(color: AppTheme.colorTransfer),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),

              const SizedBox(height: 20),

              // ── Icon picker ──
              Text('Icono',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: accountIcons.entries.map((entry) {
                  final isSelected = entry.key == selectedIcon;
                  return GestureDetector(
                    onTap: () => setState(() => selectedIcon = entry.key),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? selectedColor.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected ? Border.all(color: selectedColor, width: 2) : null,
                      ),
                      child: Icon(entry.value,
                          color: isSelected ? selectedColor : Colors.white38, size: 20),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // ── Color picker ──
              Text('Color',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: accountColors.map((color) {
                  final isSelected = color.toARGB32() == selectedColor.toARGB32();
                  return GestureDetector(
                    onTap: () => setState(() => selectedColor = color),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),

              // ── Credit card fields ──
              if (account.isCreditCard) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: closingDayCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Dia de cierre',
                          hintText: 'Ej: 15',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                          labelStyle: const TextStyle(color: AppTheme.colorTransfer),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: dueDayCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Dia de vencimiento',
                          hintText: 'Ej: 5',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                          labelStyle: const TextStyle(color: AppTheme.colorTransfer),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: creditLimitCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsSeparatorFormatter()],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Limite de credito (opcional)',
                    prefixText: r'$ ',
                    hintText: 'Ej: 500.000',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                    labelStyle: const TextStyle(color: AppTheme.colorTransfer),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: debtCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsSeparatorFormatter()],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Deuda pendiente',
                    prefixText: r'$ ',
                    hintText: 'Ej: 120.000',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                    labelStyle: const TextStyle(color: AppTheme.colorExpense),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppTheme.colorExpense),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // ── Alias ──
              TextField(
                controller: aliasCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Alias (opcional)',
                  hintText: 'Ej: mi.alias.mp',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                  labelStyle: const TextStyle(color: AppTheme.colorTransfer),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 12),

              // ── CVU/CBU ──
              TextField(
                controller: cvuCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'CBU / CVU (opcional)',
                  hintText: '22 digitos',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                  labelStyle: const TextStyle(color: AppTheme.colorTransfer),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),

              const SizedBox(height: 32),

              // ── Save button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () async {
                    // Balance change → adjust initialBalance
                    final newBalance = balanceCtrl.text.isNotEmpty
                        ? parseFormattedAmount(balanceCtrl.text)
                        : null;
                    double? newInitialBalance;
                    if (newBalance != null && newBalance != account.balance) {
                      final db = ref.read(databaseProvider);
                      final entity = await (db.select(db.accountsTable)
                            ..where((t) => t.id.equals(account.id)))
                          .getSingle();
                      newInitialBalance = entity.initialBalance + (newBalance - account.balance);
                    }

                    final closingDay = int.tryParse(closingDayCtrl.text);
                    final dueDay = int.tryParse(dueDayCtrl.text);
                    final creditLimit = creditLimitCtrl.text.isNotEmpty
                        ? parseFormattedAmount(creditLimitCtrl.text)
                        : null;
                    final debt = parseFormattedAmount(debtCtrl.text);
                    final alias = aliasCtrl.text.trim();
                    final cvu = cvuCtrl.text.trim();

                    await ref.read(accountServiceProvider).updateAccount(
                      id: account.id,
                      name: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
                      iconName: selectedIcon,
                      colorValue: selectedColor.toARGB32(),
                      initialBalance: newInitialBalance,
                      closingDay: closingDay,
                      dueDay: dueDay,
                      clearClosingDay: closingDayCtrl.text.isEmpty && account.closingDay != null,
                      clearDueDay: dueDayCtrl.text.isEmpty && account.dueDay != null,
                      creditLimit: creditLimit,
                      clearCreditLimit:
                          creditLimitCtrl.text.isEmpty && account.creditLimit != null,
                      pendingStatementAmount: debt,
                      alias: alias.isNotEmpty ? alias : null,
                      clearAlias: alias.isEmpty && account.alias != null,
                      cvu: cvu.isNotEmpty ? cvu : null,
                      clearCvu: cvu.isEmpty && account.cvu != null,
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cuenta actualizada')),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.colorTransfer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Guardar',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
