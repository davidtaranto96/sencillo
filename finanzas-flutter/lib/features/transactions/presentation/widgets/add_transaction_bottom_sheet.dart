import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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
  // Mode state
  bool _isSmart = true;

  // Manual Form State
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  TransactionType _type = TransactionType.expense;
  String _selectedCategoryId = 'food';
  dom_acc.Account? _selectedAccount;

  // AI Form State
  final _aiController = TextEditingController();
  bool _isAnalyzing = false;
  bool _isListeningVoice = false;
  final List<String> _detectedTags = [];

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
    _aiController.dispose();
    super.dispose();
  }

  // --- AI Logic ---
  void _onAiTextChanged(String text) {
    setState(() {
      _detectedTags.clear();
      final lower = text.toLowerCase();
      if (lower.contains('sushi') || lower.contains('comida')) _detectedTags.add('🍔 Comida & Salidas');
      if (lower.contains('juan') || lower.contains('sofi')) _detectedTags.add('👥 Compartido');
      if (lower.contains('dividir')) _detectedTags.add('➗ División en partes');
      final numberMatch = RegExp(r'\b\d+\b').firstMatch(text);
      if (numberMatch != null) _detectedTags.add('💵 \$${numberMatch.group(0)}');
    });
  }

  void _processAiInput() async {
    if (_aiController.text.isEmpty) return;
    setState(() => _isAnalyzing = true);
    await Future.delayed(const Duration(milliseconds: 800));
    
    final lower = _aiController.text.toLowerCase();
    double amount = 0;
    final numberMatch = RegExp(r'\d+').firstMatch(_aiController.text);
    if (numberMatch != null) amount = double.parse(numberMatch.group(0)!);
    
    String title = "Gasto Inteligente";
    if (lower.contains('sushi')) title = "Sushi";
    if (lower.contains('super')) title = "Supermercado";
    
    String type = 'expense';
    if (lower.contains('gané') || lower.contains('cobré') || lower.contains('sueldo')) type = 'income';

    await ref.read(transactionServiceProvider).addTransaction(
      title: title,
      amount: amount,
      type: type,
      categoryId: type == 'expense' ? 'cat_food' : 'cat_salary',
      accountId: 'mp_ars', // Fixed for prototype
      note: _aiController.text,
    );
    
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transacción guardada: $title por \$$amount'), backgroundColor: Colors.green),
      );
    }
  }

  void _toggleListening() async {
    setState(() => _isListeningVoice = !_isListeningVoice);
    if (_isListeningVoice) {
      await Future.delayed(const Duration(seconds: 3));
      if (mounted && _isListeningVoice) {
        setState(() {
          _isListeningVoice = false;
          _aiController.text = "Pagué 45 mil de sushi con Juan y Sofi dividir";
        });
        _onAiTextChanged(_aiController.text);
      }
    }
  }

  // --- Manual Logic ---
  void _saveManualTransaction() async {
    if (_amountController.text.isEmpty || _selectedAccount == null) return;
    final amount = double.tryParse(_amountController.text) ?? 0;
    await ref.read(transactionServiceProvider).addTransaction(
      title: _titleController.text.isEmpty ? 'Gasto' : _titleController.text,
      amount: amount,
      type: _type == TransactionType.expense ? 'expense' : _type == TransactionType.income ? 'income' : 'transfer',
      categoryId: _selectedCategoryId,
      accountId: _selectedAccount!.id,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accounts = ref.watch(accountsStreamProvider).value ?? [];
    if (_selectedAccount == null && accounts.isNotEmpty) {
      _selectedAccount = accounts.firstWhere((a) => a.isDefault, orElse: () => accounts.first);
    }

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 100),
      decoration: const BoxDecoration(
        color: Color(0xFF18181F),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Movimiento',
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
                // IA / MANUAL TOGGLE
                _SmartToggle(
                  isSmart: _isSmart,
                  onChanged: (val) => setState(() => _isSmart = val),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_isSmart) _buildSmartUI(cs) else _buildManualUI(cs, accounts),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartUI(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Escribí o dictá como hablas normalmente y nosotros hacemos el resto.',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(
                child: _isListeningVoice
                    ? Row(
                        children: [
                          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.colorTransfer)),
                          const SizedBox(width: 12),
                          Text('Escuchando...', style: TextStyle(color: AppTheme.colorTransfer, fontWeight: FontWeight.w500)),
                        ],
                      )
                    : TextField(
                        controller: _aiController,
                        onChanged: _onAiTextChanged,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        maxLines: 3,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: 'Ej. Pagué 45 mil de sushi con Juan...',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                        ),
                      ),
              ),
              IconButton(
                icon: Icon(
                  _isListeningVoice ? Icons.stop_circle_rounded : Icons.mic_rounded,
                  color: _isListeningVoice ? cs.error : AppTheme.colorTransfer,
                  size: _isListeningVoice ? 32 : 24,
                ),
                onPressed: _toggleListening,
              ),
            ],
          ),
        ),
        if (_detectedTags.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _detectedTags.map((tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.colorTransfer.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.colorTransfer.withValues(alpha: 0.3)),
              ),
              child: Text(tag, style: TextStyle(color: AppTheme.colorTransfer, fontSize: 12, fontWeight: FontWeight.w600)),
            )).toList(),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isAnalyzing ? null : _processAiInput,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.colorTransfer,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isAnalyzing
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Procesar Movimiento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildManualUI(ColorScheme cs, List<dom_acc.Account> accounts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white),
          decoration: const InputDecoration(
            hintText: '0',
            hintStyle: TextStyle(color: Colors.white10),
            prefixText: '\$ ',
            border: InputBorder.none,
          ),
        ),
        const SizedBox(height: 8),
        _TypeSelector(
          current: _type,
          onChanged: (val) => setState(() => _type = val),
        ),
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
        if (accounts.isNotEmpty)
          DropdownButton<dom_acc.Account>(
            value: _selectedAccount,
            isExpanded: true,
            dropdownColor: const Color(0xFF1E1E2C),
            style: const TextStyle(color: Colors.white),
            underline: Container(height: 1, color: Colors.white10),
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
                        style: TextStyle(color: isSelected ? Colors.white : Colors.white38, fontSize: 10),
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
            onPressed: _saveManualTransaction,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.colorTransfer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Guardar Movimiento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

class _SmartToggle extends StatelessWidget {
  final bool isSmart;
  final ValueChanged<bool> onChanged;
  const _SmartToggle({required this.isSmart, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isSmart ? Icons.auto_awesome_rounded : Icons.edit_note_rounded,
              size: 14, color: isSmart ? AppTheme.colorTransfer : Colors.white54),
          const SizedBox(width: 4),
          Text(isSmart ? 'IA' : 'Manual', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70)),
          Transform.scale(
            scale: 0.7,
            child: Switch(
              value: isSmart,
              activeTrackColor: AppTheme.colorTransfer.withValues(alpha: 0.3),
              activeThumbColor: AppTheme.colorTransfer,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
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
          _TypeButton(isSelected: current == TransactionType.expense, label: 'Gasto', onTap: () => onChanged(TransactionType.expense)),
          _TypeButton(isSelected: current == TransactionType.income, label: 'Ingreso', onTap: () => onChanged(TransactionType.income)),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.colorTransfer : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
