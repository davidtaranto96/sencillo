import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/logic/account_service.dart';
import '../../../../core/utils/format_utils.dart';
import '../../domain/models/account.dart' as dom;

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsStreamProvider);

    return accountsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (accounts) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'Tus Cuentas',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 20),
            ),
          ),
          body: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final acc = accounts[index];
              return InkWell(
                onTap: () => context.push('/accounts/${acc.id}'),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2C),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.colorTransfer.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(_getIconData(acc.icon ?? 'wallet'), color: AppTheme.colorTransfer),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  acc.name,
                                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  formatAmount(acc.balance),
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                if (acc.pendingStatementAmount > 0) 
                                  Text(
                                    'Pendiente: ${formatAmount(acc.pendingStatementAmount)}',
                                    style: TextStyle(color: AppTheme.colorExpense, fontSize: 10),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  acc.isCreditCard ? 'Gastos' : 'Actual',
                                  style: TextStyle(color: AppTheme.colorTransfer, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (acc.isCreditCard && acc.pendingStatementAmount > 0) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showPayStatementDialog(context, ref, acc),
                            icon: const Icon(Icons.payments_outlined, size: 16),
                            label: const Text('Pagar Resumen'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.colorIncome,
                              side: BorderSide(color: AppTheme.colorIncome.withValues(alpha: 0.5)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          floatingActionButton: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 100),
            child: FloatingActionButton(
              onPressed: () => _showAddAccountDialog(context, ref),
              backgroundColor: AppTheme.colorTransfer,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded, size: 32),
            ),
          ),
        );
      },
    );
  }

  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final aliasController = TextEditingController();
    final cvuController = TextEditingController();
    final balanceController = TextEditingController(text: '0');
    String selectedType = 'Débito';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) => Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 100),
            decoration: const BoxDecoration(
              color: Color(0xFF18181F),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nueva Cuenta / Billetera',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Nombre / Institución',
                    labelStyle: const TextStyle(color: AppTheme.colorTransfer),
                    hintText: 'Ej. Mercado Pago, Efectivo, BBVA',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: aliasController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Alias (Opcional)',
                    labelStyle: const TextStyle(color: AppTheme.colorTransfer),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: cvuController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'CBU / CVU (Opcional)',
                    labelStyle: const TextStyle(color: AppTheme.colorTransfer),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: balanceController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Saldo Inicial',
                          prefixText: r'$ ',
                          labelStyle: const TextStyle(color: AppTheme.colorTransfer),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: DropdownButton<String>(
                        value: selectedType,
                        dropdownColor: const Color(0xFF18181F),
                        underline: const SizedBox(),
                        style: const TextStyle(color: Colors.white),
                        items: ['Débito', 'Crédito', 'Efectivo'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => selectedType = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () async {
                      if (nameController.text.isEmpty) return;
                      
                      final type = selectedType == 'Crédito' ? 'credit' : (selectedType == 'Efectivo' ? 'cash' : 'bank');
                      
                      await ref.read(accountServiceProvider).addAccount(
                        name: nameController.text,
                        type: type,
                        currencyCode: 'ARS',
                        initialBalance: double.tryParse(balanceController.text) ?? 0,
                        iconName: type == 'credit' ? 'credit_card' : 'wallet',
                      );
                      
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cuenta creada satisfactoriamente')),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.colorTransfer,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Crear Cuenta', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPayStatementDialog(BuildContext context, WidgetRef ref, dom.Account card) {
    final allAccounts = ref.read(accountsStreamProvider).value ?? [];
    final sources = allAccounts.where((a) => !a.isCreditCard).toList();
    dom.Account? selectedSource = sources.isNotEmpty ? sources.first : null;
    final amountController = TextEditingController(text: card.pendingStatementAmount.toStringAsFixed(0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottomPadding = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding + 32),
              decoration: const BoxDecoration(
                color: Color(0xFF18181F),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pagar Resumen: ${card.name}',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text('Seleccionar origen:', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButton<dom.Account>(
                    value: selectedSource,
                    dropdownColor: const Color(0xFF1E1E2C),
                    isExpanded: true,
                    style: const TextStyle(color: Colors.white),
                    items: sources.map((s) => DropdownMenuItem(
                      value: s,
                      child: Text('${s.name} (${formatAmount(s.balance)})'),
                    )).toList(),
                    onChanged: (val) => setState(() => selectedSource = val),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 24),
                    decoration: const InputDecoration(
                      prefixText: r'$ ',
                      labelText: 'Monto a pagar',
                      labelStyle: TextStyle(color: AppTheme.colorTransfer),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: selectedSource == null ? null : () async {
                        final amount = double.tryParse(amountController.text) ?? 0;
                        await ref.read(accountServiceProvider).payCardStatement(
                          sourceAccountId: selectedSource!.id,
                          cardAccountId: card.id,
                          amount: amount,
                        );
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Pago de resumen registrado.')),
                          );
                        }
                      },
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.colorIncome),
                      child: const Text('Confirmar Pago', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  IconData _getIconData(String name) {
    if (name.contains('wallet')) return Icons.account_balance_wallet_rounded;
    if (name.contains('bank') || name.contains('balance')) return Icons.account_balance_rounded;
    return Icons.credit_card_rounded;
  }
}
