import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/logic/transaction_service.dart';
import '../../../../core/database/database_providers.dart';
import '../../domain/models/transaction.dart';
import '../../../accounts/domain/models/account.dart' as dom_acc;

class AddTransactionBottomSheet extends ConsumerStatefulWidget {
  const AddTransactionBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddTransactionBottomSheet(),
    );
  }

  @override
  ConsumerState<AddTransactionBottomSheet> createState() => _AddTransactionBottomSheetState();
}

class _AddTransactionBottomSheetState extends ConsumerState<AddTransactionBottomSheet> {
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  TransactionType _type = TransactionType.expense;
  String _selectedCategoryId = 'food';
  dom_acc.Account? _selectedAccount;

  final Map<String, String> _categories = {
    'food': '🍔',
    'transport': '🚗',
    'health': '🏥',
    'entertainment': '🎬',
    'shopping': '🛍️',
    'home': '🏠',
    'education': '📚',
    'services': '🔌',
    'salary': '💼',
    'freelance': '💻',
    'transfer': '🔄',
    'other_expense': '💸',
    'other_income': '💰',
  };

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accounts = ref.watch(accountsStreamProvider).value ?? [];
    if (_selectedAccount == null && accounts.isNotEmpty) {
      _selectedAccount = accounts.firstWhere((a) => a.isDefault, orElse: () => accounts.first);
    }

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      decoration: const BoxDecoration(
        color: Color(0xFF18181F),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nuevo Movimiento',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              _TypeSelector(
                current: _type,
                onChanged: (val) => setState(() => _type = val),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // --- Monto ---
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: const TextStyle(color: Colors.white10),
              prefixText: '\$ ',
              border: InputBorder.none,
            ),
          ),
          
          // --- Concepto ---
          TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: const InputDecoration(
              hintText: '¿En qué se gastó?',
              hintStyle: TextStyle(color: Colors.white38),
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 16),

          // --- Cuenta ---
          if (accounts.isNotEmpty)
            DropdownButton<dom_acc.Account>(
              value: _selectedAccount,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E1E2C),
              style: const TextStyle(color: Colors.white),
              underline: const SizedBox(),
              items: accounts.map((a) => DropdownMenuItem(
                value: a,
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(a.name),
                  ],
                ),
              )).toList(),
              onChanged: (val) => setState(() => _selectedAccount = val),
            ),
          
          const SizedBox(height: 20),

          // --- Categorías Grid ---
          Text('Categoría', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _categories.entries.map((entry) {
                final isSelected = _selectedCategoryId == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () => setState(() => _selectedCategoryId = entry.key),
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.colorTransfer.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isSelected ? AppTheme.colorTransfer : Colors.transparent),
                          ),
                          alignment: Alignment.center,
                          child: Text(entry.value, style: const TextStyle(fontSize: 24)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.key.split('_').first, 
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white38, 
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _saveTransaction,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.colorTransfer,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Guardar Movimiento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  void _saveTransaction() async {
    if (_amountController.text.isEmpty || _selectedAccount == null) return;
    
    final amount = double.tryParse(_amountController.text) ?? 0;
    await ref.read(transactionServiceProvider).addTransaction(
      title: _titleController.text.isEmpty ? 'Gasto' : _titleController.text,
      amount: amount,
      type: _type == TransactionType.expense ? 'expense' : _type == TransactionType.income ? 'income' : 'transfer',
      categoryId: _selectedCategoryId,
      accountId: _selectedAccount!.id,
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }
}

class _TypeSelector extends StatelessWidget {
  final TransactionType current;
  final ValueChanged<TransactionType> onChanged;

  const _TypeSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _TypeButton(
            isSelected: current == TransactionType.expense,
            label: 'Gasto',
            onTap: () => onChanged(TransactionType.expense),
          ),
          _TypeButton(
            isSelected: current == TransactionType.income,
            label: 'Ingreso',
            onTap: () => onChanged(TransactionType.income),
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final bool isSelected;
  final String label;
  final VoidCallback onTap;

  const _TypeButton({required this.isSelected, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.colorTransfer : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
