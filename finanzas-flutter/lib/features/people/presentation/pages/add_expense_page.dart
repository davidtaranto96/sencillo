import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/logic/people_service.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../accounts/domain/models/account.dart' as dom_a;
import '../../domain/models/person.dart' as dom_p;

class AddExpensePage extends ConsumerStatefulWidget {
  const AddExpensePage({super.key});

  @override
  ConsumerState<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends ConsumerState<AddExpensePage> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  
  dom_p.Person? _selectedPerson;
  dom_a.Account? _selectedAccount;
  bool _iPaid = true;
  String _splitType = 'equal'; // 'equal', 'only_me', 'only_them'
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_amountController.text.isEmpty || _selectedPerson == null || _selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa los campos obligatorios')),
      );
      return;
    }

    final totalAmount = double.tryParse(_amountController.text) ?? 0;
    if (totalAmount <= 0) return;

    double ownAmount = 0;
    double otherAmount = 0;

    if (_splitType == 'equal') {
      ownAmount = totalAmount / 2;
      otherAmount = totalAmount / 2;
    } else if (_splitType == 'only_me') {
      ownAmount = totalAmount;
      otherAmount = 0;
    } else if (_splitType == 'only_them') {
      ownAmount = 0;
      otherAmount = totalAmount;
    }

    try {
      final service = ref.read(peopleServiceProvider);
      await service.recordSharedExpense(
        personId: _selectedPerson!.id,
        totalAmount: totalAmount,
        iPaid: _iPaid,
        ownAmount: ownAmount,
        otherAmount: otherAmount,
        description: _descriptionController.text.isNotEmpty 
            ? _descriptionController.text 
            : 'Gasto compartido',
        accountId: _iPaid ? _selectedAccount?.id : null,
        date: _selectedDate,
      );
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final peopleAsync = ref.watch(peopleStreamProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Añadir gasto',
          style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              'Guardar',
              style: GoogleFonts.inter(
                color: AppTheme.colorTransfer,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Header: Con vos y...
            Row(
              children: [
                Text(
                  'Con vos y:',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: peopleAsync.when(
                    data: (people) => _selectedPerson == null 
                      ? GestureDetector(
                          onTap: () => _showPersonPicker(context, people),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('seleccionar persona', style: TextStyle(color: Colors.white24, fontSize: 13)),
                          ),
                        )
                      : InputChip(
                          label: Text(_selectedPerson!.displayName),
                          onDeleted: () => setState(() => _selectedPerson = null),
                          deleteIconColor: Colors.white54,
                          backgroundColor: AppTheme.colorTransfer.withValues(alpha: 0.2),
                          labelStyle: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 48),
            
            // Icon + Description + Amount
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: const Icon(Icons.receipt_long_outlined, color: Colors.white38, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        controller: _descriptionController,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: '¿En qué gastaste?',
                          hintStyle: TextStyle(color: Colors.white24, fontSize: 18),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const Divider(color: Colors.white10, height: 1),
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          prefixText: '\$ ',
                          prefixStyle: const TextStyle(color: Colors.white24, fontSize: 28),
                          hintText: '0.00',
                          hintStyle: const TextStyle(color: Colors.white12),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 40),
            
            // Selector de Pago y División
            Center(
              child: Column(
                children: [
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 15),
                      children: [
                        const TextSpan(text: 'Pagado por '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: GestureDetector(
                            onTap: () => _togglePayer(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.colorTransfer.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _iPaid ? 'VOS' : (_selectedPerson?.displayName ?? 'ALGUIEN'),
                                style: TextStyle(color: AppTheme.colorTransfer, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(text: ' e íntegramente\na partes '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: GestureDetector(
                            onTap: () => _showSplitPicker(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.colorTransfer.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _splitType == 'equal' ? 'IGUALES' : (_splitType == 'only_me' ? 'TODO VOS' : 'TODO ELLOS'),
                                style: const TextStyle(color: AppTheme.colorTransfer, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Selector de cuenta (solo si yo pagué)
                  if (_iPaid) 
                    accountsAsync.when(
                      data: (accounts) {
                        final sources = accounts.where((a) => !a.isCreditCard).toList();
                        if (sources.isEmpty) return const SizedBox.shrink();
                        _selectedAccount ??= sources.first;
                        return GestureDetector(
                          onTap: () => _showAccountPicker(context, sources),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.account_balance_wallet_outlined, color: Colors.white38, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Usando: ${_selectedAccount?.name ?? 'Seleccionar cuenta'}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white38, size: 16),
                              ],
                            ),
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 60),
            
            // Iconos inferiores (Fecha, Cámara, Notas)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCircularIcon(Icons.calendar_today_outlined, 
                  label: DateFormat('d MMM').format(_selectedDate)),
                const SizedBox(width: 24),
                _buildCircularIcon(Icons.camera_alt_outlined),
                const SizedBox(width: 24),
                _buildCircularIcon(Icons.notes_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularIcon(IconData icon, {String? label}) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white12),
          ),
          child: Icon(icon, color: Colors.white54, size: 22),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ],
    );
  }

  void _togglePayer() {
    setState(() => _iPaid = !_iPaid);
  }

  void _showSplitPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          const Text('¿Cómo se divide?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.people_alt_outlined, color: AppTheme.colorTransfer),
            title: const Text('A partes iguales', style: TextStyle(color: Colors.white)),
            onTap: () {
              setState(() => _splitType = 'equal');
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline, color: AppTheme.colorIncome),
            title: const Text('Todo vos', style: TextStyle(color: Colors.white)),
            onTap: () {
              setState(() => _splitType = 'only_me');
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline, color: AppTheme.colorExpense),
            title: const Text('Todo ellos', style: TextStyle(color: Colors.white)),
            onTap: () {
              setState(() => _splitType = 'only_them');
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showPersonPicker(BuildContext context, List<dom_p.Person> people) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: people.length,
        itemBuilder: (context, i) => ListTile(
          leading: CircleAvatar(backgroundColor: people[i].avatarColor.withValues(alpha: 0.2), child: Text(people[i].name[0])),
          title: Text(people[i].displayName, style: const TextStyle(color: Colors.white)),
          onTap: () {
            setState(() => _selectedPerson = people[i]);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _showAccountPicker(BuildContext context, List<dom_a.Account> accounts) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => ListView.builder(
        padding: const EdgeInsets.all(16),
        shrinkWrap: true,
        itemCount: accounts.length,
        itemBuilder: (context, i) => ListTile(
          leading: const Icon(Icons.account_balance_wallet, color: AppTheme.colorTransfer),
          title: Text(accounts[i].name, style: const TextStyle(color: Colors.white)),
          trailing: Text(formatAmount(accounts[i].balance), style: const TextStyle(color: Colors.white54)),
          onTap: () {
            setState(() => _selectedAccount = accounts[i]);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}
