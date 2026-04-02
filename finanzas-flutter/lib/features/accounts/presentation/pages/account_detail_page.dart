import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/logic/account_service.dart';
import '../../../../core/logic/transaction_service.dart';
import '../../../transactions/domain/models/transaction.dart' as dom_tx;
import '../../domain/models/account.dart' as dom;

class AccountDetailPage extends ConsumerWidget {
  final String accountId;
  const AccountDetailPage({super.key, required this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final transactionsAsync = ref.watch(transactionsStreamProvider);

    return accountsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (accounts) {
        final account = accounts.firstWhere((a) => a.id == accountId,
          orElse: () => accounts.first);

        return Scaffold(
          appBar: AppBar(
            title: Text(account.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _showEditAccountDialog(context, ref, account),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.colorExpense),
                onPressed: () => _confirmDeleteAccount(context, ref, account),
              ),
            ],
          ),
          body: transactionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
            data: (transactions) {
              final accountTxs = transactions.where((t) => t.accountId == accountId).toList();
              accountTxs.sort((a, b) => b.date.compareTo(a.date));

              return CustomScrollView(
                slivers: [
                  // --- Card de Info de Cuenta ---
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverToBoxAdapter(
                      child: _AccountHeroCard(account: account),
                    ),
                  ),

                  // --- Credit card info (closing/due dates) ---
                  if (account.isCreditCard && (account.closingDay != null || account.dueDay != null))
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              if (account.closingDay != null)
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Icon(Icons.event_note_rounded, color: AppTheme.colorTransfer, size: 14),
                                      const SizedBox(height: 4),
                                      Text('Cierre', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                                      Text('Día ${account.closingDay}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              if (account.closingDay != null && account.dueDay != null)
                                Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.1)),
                              if (account.dueDay != null)
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, color: AppTheme.colorExpense, size: 14),
                                      const SizedBox(height: 4),
                                      Text('Vencimiento', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                                      Text('Día ${account.dueDay}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // --- Historial ---
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'Historial de movimientos',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  if (accountTxs.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('Sin movimientos', style: TextStyle(color: Colors.white30))),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final tx = accountTxs[index];
                          return _TransactionDetailTile(transaction: tx);
                        },
                        childCount: accountTxs.length,
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _AccountHeroCard extends ConsumerWidget {
  final dom.Account account;
  const _AccountHeroCard({required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.isCreditCard ? 'Gastos del período' : 'Saldo actual',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${account.currencyCode} ${formatAmount(account.balance)}',
                        style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.colorTransfer.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  account.isCreditCard ? Icons.credit_card_rounded : Icons.account_balance_wallet_rounded,
                  color: AppTheme.colorTransfer, size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (account.isCreditCard)
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.payments_outlined,
                    label: 'Pagar Resumen',
                    color: AppTheme.colorIncome,
                    onTap: () => _showPayStatementDialog(context, ref, account),
                  ),
                )
              else
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Transferir',
                    onTap: () {},
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Agregar Movimiento',
                  color: AppTheme.colorTransfer,
                  onTap: () => _showAddManualTransactionDialog(context, ref, account),
                ),
              ),
            ],
          ),
          if (account.isCreditCard && account.pendingStatementAmount > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.colorExpense.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                   const Icon(Icons.warning_amber_rounded, color: AppTheme.colorExpense, size: 20),
                   const SizedBox(width: 12),
                   Expanded(
                     child: Text(
                       'Resumen pendiente: ${formatAmount(account.pendingStatementAmount)}',
                       style: const TextStyle(color: AppTheme.colorExpense, fontSize: 13, fontWeight: FontWeight.w600),
                     ),
                   ),
                ],
              ),
            ),
          ],
          // Límite de crédito y disponible
          if (account.isCreditCard && account.creditLimit != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Límite', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                      Text(formatAmount(account.creditLimit!), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.08)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Disponible', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                      Text(
                        formatAmount((account.creditLimit! - account.balance).clamp(0, account.creditLimit!)),
                        style: TextStyle(
                          color: account.availableCredit > 0 ? AppTheme.colorIncome : AppTheme.colorExpense,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          // Alias / CVU
          if (account.alias != null || account.cvu != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (account.alias != null)
                    _CopyRow(
                      icon: Icons.tag_rounded,
                      value: account.alias!,
                      label: 'Alias',
                    ),
                  if (account.alias != null && account.cvu != null) const SizedBox(height: 2),
                  if (account.cvu != null)
                    _CopyRow(
                      icon: Icons.account_balance_rounded,
                      value: account.cvu!,
                      label: 'CBU/CVU',
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _CopyRow({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: Colors.white38),
        const SizedBox(width: 6),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$label copiado'),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.copy_rounded, size: 13, color: Colors.white38),
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _QuickActionButton({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white70;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: c),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
// Editar Cuenta
// ──────────────────────────────────────────────────────
void _showEditAccountDialog(BuildContext context, WidgetRef ref, dom.Account account) {
  final nameController = TextEditingController(text: account.name);
  final balanceController = TextEditingController(text: formatInitialAmount(account.balance));
  final closingDayController = TextEditingController(text: account.closingDay?.toString() ?? '');
  final dueDayController = TextEditingController(text: account.dueDay?.toString() ?? '');
  final aliasController = TextEditingController(text: account.alias ?? '');
  final cvuController = TextEditingController(text: account.cvu ?? '');
  final creditLimitController = TextEditingController(text: account.creditLimit != null ? formatInitialAmount(account.creditLimit!) : '');
  final debtController = TextEditingController(text: account.pendingStatementAmount > 0 ? formatInitialAmount(account.pendingStatementAmount) : '');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 100),
      decoration: const BoxDecoration(
        color: Color(0xFF18181F),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('Editar Cuenta', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 24),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nombre de la cuenta',
                labelStyle: const TextStyle(color: AppTheme.colorTransfer),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: balanceController,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorFormatter()],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: account.isCreditCard ? 'Gastos del período' : 'Saldo actual',
                prefixText: r'$ ',
                labelStyle: const TextStyle(color: AppTheme.colorTransfer),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            if (account.isCreditCard) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: closingDayController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Día de cierre',
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
                      controller: dueDayController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Día de vencimiento',
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
                controller: creditLimitController,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorFormatter()],
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Límite de crédito (opcional)',
                  prefixText: r'$ ',
                  hintText: 'Ej: 500.000',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                  labelStyle: const TextStyle(color: AppTheme.colorTransfer),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: debtController,
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
            TextField(
              controller: aliasController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Alias (opcional)',
                hintText: 'Ej: mi.cuenta.mp',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                labelStyle: const TextStyle(color: AppTheme.colorTransfer),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: cvuController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'CBU / CVU (opcional)',
                hintText: '22 dígitos',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                labelStyle: const TextStyle(color: AppTheme.colorTransfer),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () async {
                  final newBalance = balanceController.text.isNotEmpty ? parseFormattedAmount(balanceController.text) : null;
                  double? newInitialBalance;
                  if (newBalance != null && newBalance != account.balance) {
                    final db = ref.read(databaseProvider);
                    final entity = await (db.select(db.accountsTable)..where((t) => t.id.equals(account.id))).getSingle();
                    newInitialBalance = entity.initialBalance + (newBalance - account.balance);
                  }

                  final closingDay = int.tryParse(closingDayController.text);
                  final dueDay = int.tryParse(dueDayController.text);
                  final creditLimit = creditLimitController.text.isNotEmpty ? parseFormattedAmount(creditLimitController.text) : null;
                  final debt = parseFormattedAmount(debtController.text);
                  final alias = aliasController.text.trim();
                  final cvu = cvuController.text.trim();

                  await ref.read(accountServiceProvider).updateAccount(
                    id: account.id,
                    name: nameController.text,
                    initialBalance: newInitialBalance,
                    closingDay: closingDay,
                    dueDay: dueDay,
                    clearClosingDay: closingDayController.text.isEmpty && account.closingDay != null,
                    clearDueDay: dueDayController.text.isEmpty && account.dueDay != null,
                    creditLimit: creditLimit,
                    clearCreditLimit: creditLimitController.text.isEmpty && account.creditLimit != null,
                    pendingStatementAmount: debt,
                    alias: alias.isNotEmpty ? alias : null,
                    clearAlias: alias.isEmpty && account.alias != null,
                    cvu: cvu.isNotEmpty ? cvu : null,
                    clearCvu: cvu.isEmpty && account.cvu != null,
                  );
                  if (context.mounted) {
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
                child: const Text('Guardar Cambios', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ──────────────────────────────────────────────────────
// Agregar Movimiento Manual
// ──────────────────────────────────────────────────────
void _showAddManualTransactionDialog(BuildContext context, WidgetRef ref, dom.Account account) {
  final titleController = TextEditingController();
  final amountController = TextEditingController();
  String txType = 'expense'; // default

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 100),
        decoration: const BoxDecoration(
          color: Color(0xFF18181F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              Text('Agregar Movimiento', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              Text(account.name, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
              const SizedBox(height: 24),
              // Tipo selector
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => txType = 'expense'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: txType == 'expense' ? AppTheme.colorExpense.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: txType == 'expense' ? AppTheme.colorExpense.withValues(alpha: 0.5) : Colors.transparent),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_upward_rounded, size: 18, color: txType == 'expense' ? AppTheme.colorExpense : Colors.white38),
                            const SizedBox(width: 6),
                            Text('Extracción', style: TextStyle(color: txType == 'expense' ? AppTheme.colorExpense : Colors.white38, fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => txType = 'income'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: txType == 'income' ? AppTheme.colorIncome.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: txType == 'income' ? AppTheme.colorIncome.withValues(alpha: 0.5) : Colors.transparent),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_downward_rounded, size: 18, color: txType == 'income' ? AppTheme.colorIncome : Colors.white38),
                            const SizedBox(width: 6),
                            Text('Depósito', style: TextStyle(color: txType == 'income' ? AppTheme.colorIncome : Colors.white38, fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Descripción',
                  hintText: txType == 'expense' ? 'Ej: Retiro cajero' : 'Ej: Depósito sueldo',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                  labelStyle: const TextStyle(color: AppTheme.colorTransfer),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorFormatter()],
                style: const TextStyle(color: Colors.white, fontSize: 24),
                decoration: InputDecoration(
                  prefixText: r'$ ',
                  labelText: 'Monto',
                  labelStyle: const TextStyle(color: AppTheme.colorTransfer),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () async {
                    final amount = parseFormattedAmount(amountController.text);
                    if (amount <= 0) return;
                    final title = titleController.text.isEmpty
                        ? (txType == 'expense' ? 'Extracción manual' : 'Depósito manual')
                        : titleController.text;

                    final txId = await ref.read(accountServiceProvider).addManualTransaction(
                      accountId: account.id,
                      title: title,
                      amount: amount,
                      type: txType,
                    );
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${txType == 'expense' ? 'Extracción' : 'Depósito'}: ${formatAmount(amount)}'),
                          duration: const Duration(seconds: 6),
                          action: SnackBarAction(
                            label: 'DESHACER',
                            textColor: AppTheme.colorWarning,
                            onPressed: () async {
                              await ref.read(transactionServiceProvider).deleteTransaction(txId);
                            },
                          ),
                        ),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: txType == 'expense' ? AppTheme.colorExpense : AppTheme.colorIncome,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    txType == 'expense' ? 'Registrar Extracción' : 'Registrar Depósito',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ──────────────────────────────────────────────────────
// Pagar Resumen de Tarjeta
// ──────────────────────────────────────────────────────
void _showPayStatementDialog(BuildContext context, WidgetRef ref, dom.Account account) {
  final accounts = ref.read(accountsStreamProvider).value ?? [];
  final sources = accounts.where((a) => !a.isCreditCard).toList();
  dom.Account? selectedSource = sources.isNotEmpty ? sources.first : null;
  final amountController = TextEditingController(text: formatInitialAmount(account.pendingStatementAmount));

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 100),
        decoration: const BoxDecoration(
          color: Color(0xFF18181F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              Text('Pagar Resumen', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              Text(account.name, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
              if (account.pendingStatementAmount > 0) ...[
                const SizedBox(height: 8),
                Text('Pendiente: ${formatAmount(account.pendingStatementAmount)}', style: const TextStyle(color: AppTheme.colorExpense, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 24),
              const Text('Cuenta de origen:', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              if (sources.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('No hay cuentas disponibles para pagar', style: TextStyle(color: Colors.white38)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: DropdownButton<dom.Account>(
                    value: selectedSource,
                    dropdownColor: const Color(0xFF1E1E2C),
                    isExpanded: true,
                    underline: const SizedBox(),
                    style: const TextStyle(color: Colors.white),
                    items: sources.map((s) => DropdownMenuItem(
                      value: s,
                      child: Text('${s.name} (${formatAmount(s.balance)})'),
                    )).toList(),
                    onChanged: (val) => setState(() => selectedSource = val),
                  ),
                ),
              const SizedBox(height: 20),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorFormatter()],
                style: const TextStyle(color: Colors.white, fontSize: 24),
                decoration: InputDecoration(
                  prefixText: r'$ ',
                  labelText: 'Monto a pagar',
                  labelStyle: const TextStyle(color: AppTheme.colorTransfer),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: selectedSource == null ? null : () async {
                    final amount = parseFormattedAmount(amountController.text);
                    if (amount <= 0) return;
                    final srcId = selectedSource!.id;

                    final txId = await ref.read(accountServiceProvider).payCardStatement(
                      sourceAccountId: srcId,
                      cardAccountId: account.id,
                      amount: amount,
                    );
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Pago de ${formatAmount(amount)} registrado'),
                          duration: const Duration(seconds: 6),
                          action: SnackBarAction(
                            label: 'DESHACER',
                            textColor: AppTheme.colorWarning,
                            onPressed: () async {
                              await ref.read(accountServiceProvider).undoPayCardStatement(
                                sourceAccountId: srcId,
                                cardAccountId: account.id,
                                amount: amount,
                                transactionId: txId,
                              );
                            },
                          ),
                        ),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.colorIncome,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Confirmar Pago', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ──────────────────────────────────────────────────────
// Confirmar Eliminar Cuenta
// ──────────────────────────────────────────────────────
void _confirmDeleteAccount(BuildContext context, WidgetRef ref, dom.Account account) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E2C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppTheme.colorExpense),
          SizedBox(width: 12),
          Expanded(child: Text('¿Eliminar cuenta?', style: TextStyle(color: Colors.white, fontSize: 18))),
        ],
      ),
      content: Text('Esto borrará "${account.name}" y todos sus movimientos permanentemente.', style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
        TextButton(
          onPressed: () async {
            await ref.read(accountServiceProvider).deleteAccount(account.id);
            if (context.mounted) {
              Navigator.pop(ctx);
              Navigator.pop(context);
            }
          },
          child: const Text('Eliminar', style: TextStyle(color: AppTheme.colorExpense, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

// ──────────────────────────────────────────────────────
// Tile de Transacción
// ──────────────────────────────────────────────────────
class _TransactionDetailTile extends StatelessWidget {
  final dom_tx.Transaction transaction;
  const _TransactionDetailTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == dom_tx.TransactionType.income;
    final isTransfer = transaction.type == dom_tx.TransactionType.transfer;
    final color = isTransfer ? AppTheme.colorTransfer : (isIncome ? AppTheme.colorIncome : AppTheme.colorExpense);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isTransfer ? Icons.swap_horiz_rounded : (isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded),
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  formatDate(transaction.date),
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'}${formatAmount(transaction.amount)}',
            style: GoogleFonts.inter(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
