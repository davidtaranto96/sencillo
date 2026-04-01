import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/logic/account_service.dart';
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
              
              return CustomScrollView(
                slivers: [
                  // --- Card de Info de Cuenta ---
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverToBoxAdapter(
                      child: _AccountHeroCard(account: account),
                    ),
                  ),

                  // --- Alias y CBU (Info Extra) ---
                  if (account.alias != null || account.cvu != null)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              if (account.alias != null)
                                _InfoRow(label: 'Alias', value: account.alias!),
                              if (account.alias != null && account.cvu != null)
                                const Divider(height: 24, color: Colors.white10),
                              if (account.cvu != null)
                                _InfoRow(label: 'CBU / CVU', value: account.cvu!),
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.colorTransfer),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('$label copiado'), duration: const Duration(seconds: 1)),
            );
          },
        ),
      ],
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saldo actual',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${account.currencyCode} ${formatAmount(account.balance)}',
                    style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.colorTransfer.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.account_balance_wallet_rounded, color: AppTheme.colorTransfer, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (account.isCreditCard)
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.payments_outlined, 
                    label: 'Pagar Resumen',
                    onTap: () => _showPayStatementDialog(context, ref, account),
                  ),
                )
              else
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.swap_horiz_rounded, 
                    label: 'Transferir',
                    onTap: () => context.push('/transactions/new'),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Agregar Movimiento',
                  onTap: () => context.push('/transactions/new'),
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
                       'Resumen vencido o pendiente: \$${formatAmount(account.pendingStatementAmount)}',
                       style: const TextStyle(color: AppTheme.colorExpense, fontSize: 13, fontWeight: FontWeight.w600),
                     ),
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

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.white70),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

void _showEditAccountDialog(BuildContext context, WidgetRef ref, dom.Account account) {
  final nameController = TextEditingController(text: account.name);
  final aliasController = TextEditingController(text: account.alias);
  final cvuController = TextEditingController(text: account.cvu);
  // Nota: Drift maneja el balance dinámicamente sumando transacciones. 
  // Pero aquí podríamos permitir editar el balance base si se quisiera.
  
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
            controller: aliasController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Alias',
              labelStyle: const TextStyle(color: AppTheme.colorTransfer),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: cvuController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'CBU / CVU',
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
                await ref.read(accountServiceProvider).updateAccount(
                  id: account.id,
                  name: nameController.text,
                );
                if (context.mounted) Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(backgroundColor: AppTheme.colorTransfer),
              child: const Text('Guardar Cambios'),
            ),
          ),
        ],
      ),
    ),
  );
}

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
          Text('¿Eliminar cuenta?', style: TextStyle(color: Colors.white, fontSize: 18)),
        ],
      ),
      content: Text('Esto borrará "${account.name}" y todos sus movimientos permanentemente de forma irreversible.', style: const TextStyle(color: Colors.white70)),
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

void _showPayStatementDialog(BuildContext context, WidgetRef ref, dom.Account account) {
  final accounts = ref.read(accountsStreamProvider).value ?? [];
  final sources = accounts.where((a) => !a.isCreditCard).toList();
  dom.Account? selectedSource = sources.isNotEmpty ? sources.first : null;
  final amountController = TextEditingController(text: account.pendingStatementAmount.toStringAsFixed(0));

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pagar Resumen: ${account.name}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            const Text('Cuenta de origen:', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            DropdownButton<dom.Account>(
              value: selectedSource,
              dropdownColor: const Color(0xFF1E1E2C),
              isExpanded: true,
              style: const TextStyle(color: Colors.white),
              items: sources.map((s) => DropdownMenuItem(value: s, child: Text('${s.name} (${formatAmount(s.balance)})'))).toList(),
              onChanged: (val) => setState(() => selectedSource = val),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 24),
              decoration: const InputDecoration(
                prefixText: '\$ ',
                labelText: 'Monto a pagar',
                labelStyle: TextStyle(color: AppTheme.colorTransfer),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: selectedSource == null ? null : () async {
                  final amount = double.tryParse(amountController.text) ?? 0;
                  if (amount <= 0) return;

                  await ref.read(accountServiceProvider).payCardStatement(
                    sourceAccountId: selectedSource!.id,
                    cardAccountId: account.id,
                    amount: amount,
                  );
                  if (context.mounted) Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(backgroundColor: AppTheme.colorTransfer),
                child: const Text('Confirmar Pago'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TransactionDetailTile extends StatelessWidget {
  final dom_tx.Transaction transaction;
  const _TransactionDetailTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == dom_tx.TransactionType.income;
    final color = isIncome ? AppTheme.colorIncome : AppTheme.colorExpense;
    
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
              isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
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
