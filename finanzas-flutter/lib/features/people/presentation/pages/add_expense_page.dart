import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/logic/people_service.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../accounts/domain/models/account.dart' as dom_a;
import '../../domain/models/person.dart' as dom_p;
import '../../domain/models/group.dart' as dom_grp;

class AddExpensePage extends ConsumerStatefulWidget {
  final String? preselectedPersonId;
  final String? preselectedGroupId;

  const AddExpensePage({
    super.key,
    this.preselectedPersonId,
    this.preselectedGroupId,
  });

  @override
  ConsumerState<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends ConsumerState<AddExpensePage> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _customSplitController = TextEditingController();

  dom_p.Person? _selectedPerson;
  dom_a.Account? _selectedAccount;
  dom_grp.ExpenseGroup? _selectedGroup;
  bool _iPaid = true;
  String _splitType = 'equal'; // 'equal', 'custom', 'full_me', 'full_them'
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Pre-select person/group after first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.preselectedPersonId != null) {
        final people = ref.read(peopleStreamProvider).valueOrNull ?? [];
        final match = people.where((p) => p.id == widget.preselectedPersonId).firstOrNull;
        if (match != null) setState(() => _selectedPerson = match);
      }
      if (widget.preselectedGroupId != null) {
        final groups = ref.read(groupsStreamProvider).valueOrNull ?? [];
        final match = groups.where((g) => g.id == widget.preselectedGroupId).firstOrNull;
        if (match != null) setState(() => _selectedGroup = match);
      }
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _customSplitController.dispose();
    super.dispose();
  }

  double get _totalAmount => parseFormattedAmount(_amountController.text);

  double get _ownAmount {
    switch (_splitType) {
      case 'equal':
        return _totalAmount / 2;
      case 'full_me':
        return _totalAmount;
      case 'full_them':
        return 0;
      case 'custom':
        final custom = parseFormattedAmount(_customSplitController.text);
        return custom.clamp(0, _totalAmount);
      default:
        return _totalAmount / 2;
    }
  }

  double get _otherAmount => _totalAmount - _ownAmount;

  Future<void> _save() async {
    if (_amountController.text.isEmpty || _selectedPerson == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completá monto y persona')),
      );
      return;
    }
    if (_iPaid && _selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná una cuenta')),
      );
      return;
    }

    final totalAmount = _totalAmount;
    if (totalAmount <= 0) return;

    try {
      await ref.read(peopleServiceProvider).recordSharedExpense(
        personId: _selectedPerson!.id,
        totalAmount: totalAmount,
        iPaid: _iPaid,
        ownAmount: _ownAmount,
        otherAmount: _otherAmount,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : 'Gasto compartido',
        accountId: _iPaid ? _selectedAccount?.id : null,
        groupId: _selectedGroup?.id,
        date: _selectedDate,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final peopleAsync = ref.watch(peopleStreamProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);
    final groupsAsync = ref.watch(groupsStreamProvider);

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
          'Gasto compartido',
          style: GoogleFonts.inter(
              fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // ── Person selector ──
            Text('Con quién',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            peopleAsync.when(
              data: (people) {
                if (people.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text('Primero agregá un amigo',
                        style: TextStyle(color: Colors.white38)),
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: people.map((p) {
                    final isSelected = _selectedPerson?.id == p.id;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedPerson = p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? p.avatarColor.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? p.avatarColor.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor:
                                  p.avatarColor.withValues(alpha: 0.2),
                              child: Text(p.displayName[0].toUpperCase(),
                                  style: TextStyle(
                                      color: p.avatarColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 8),
                            Text(p.displayName,
                                style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white60,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            // ── Group selector (optional) ──
            groupsAsync.when(
              data: (groups) {
                if (groups.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Grupo (opcional)',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // "Sin grupo" chip
                        GestureDetector(
                          onTap: () => setState(() => _selectedGroup = null),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedGroup == null
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('Sin grupo',
                                style: TextStyle(
                                    color: _selectedGroup == null
                                        ? Colors.white70
                                        : Colors.white30,
                                    fontSize: 13)),
                          ),
                        ),
                        ...groups.map((g) {
                          final isSelected = _selectedGroup?.id == g.id;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedGroup = g),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.colorTransfer
                                        .withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.colorTransfer
                                          .withValues(alpha: 0.3)
                                      : Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.group_rounded,
                                      color: isSelected
                                          ? AppTheme.colorTransfer
                                          : Colors.white38,
                                      size: 14),
                                  const SizedBox(width: 6),
                                  Text(g.name,
                                      style: TextStyle(
                                          color: isSelected
                                              ? AppTheme.colorTransfer
                                              : Colors.white60,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // ── Description ──
            TextField(
              controller: _descriptionController,
              style: GoogleFonts.inter(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                hintText: '¿En qué gastaste?',
                hintStyle: TextStyle(color: Colors.white24, fontSize: 18),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),

            // ── Amount ──
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [ThousandsSeparatorFormatter()],
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w700),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixText: '\$ ',
                prefixStyle: TextStyle(color: Colors.white24, fontSize: 30),
                hintText: '0',
                hintStyle: TextStyle(color: Colors.white12),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),

            const SizedBox(height: 24),

            // ── Payer toggle ──
            Text('Quién pagó',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _iPaid = true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _iPaid
                            ? AppTheme.colorIncome.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _iPaid
                              ? AppTheme.colorIncome.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.person_rounded,
                              color: _iPaid
                                  ? AppTheme.colorIncome
                                  : Colors.white24,
                              size: 20),
                          const SizedBox(height: 4),
                          Text('Yo pagué',
                              style: TextStyle(
                                  color: _iPaid
                                      ? AppTheme.colorIncome
                                      : Colors.white38,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _iPaid = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: !_iPaid
                            ? AppTheme.colorExpense.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: !_iPaid
                              ? AppTheme.colorExpense.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.person_outline_rounded,
                              color: !_iPaid
                                  ? AppTheme.colorExpense
                                  : Colors.white24,
                              size: 20),
                          const SizedBox(height: 4),
                          Text(
                              _selectedPerson != null
                                  ? '${_selectedPerson!.displayName} pagó'
                                  : 'Otro pagó',
                              style: TextStyle(
                                  color: !_iPaid
                                      ? AppTheme.colorExpense
                                      : Colors.white38,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Split options ──
            Text('Cómo se divide',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SplitChip(
                    label: '50/50',
                    isSelected: _splitType == 'equal',
                    onTap: () => setState(() => _splitType = 'equal')),
                _SplitChip(
                    label: 'Todo mío',
                    isSelected: _splitType == 'full_me',
                    onTap: () => setState(() => _splitType = 'full_me')),
                _SplitChip(
                    label: 'Todo suyo',
                    isSelected: _splitType == 'full_them',
                    onTap: () => setState(() => _splitType = 'full_them')),
                _SplitChip(
                    label: 'Custom',
                    isSelected: _splitType == 'custom',
                    onTap: () => setState(() => _splitType = 'custom')),
              ],
            ),

            if (_splitType == 'custom') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Tu parte: ',
                      style: TextStyle(color: Colors.white54, fontSize: 14)),
                  Expanded(
                    child: TextField(
                      controller: _customSplitController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsSeparatorFormatter()],
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                        prefixText: '\$ ',
                        prefixStyle: TextStyle(color: Colors.white24),
                        border: InputBorder.none,
                        hintText: '0',
                        hintStyle: TextStyle(color: Colors.white12),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Split preview
            if (_totalAmount > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text('Vos',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(formatAmount(_ownAmount),
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16)),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                              _selectedPerson?.displayName ?? 'Otro',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(formatAmount(_otherAmount),
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Account selector (only if iPaid) ──
            if (_iPaid)
              accountsAsync.when(
                data: (accounts) {
                  final sources = accounts.toList();
                  if (sources.isEmpty) return const SizedBox.shrink();
                  _selectedAccount ??= sources.first;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cuenta',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: sources.map((s) {
                          final isSelected = _selectedAccount?.id == s.id;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedAccount = s),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.colorTransfer
                                        .withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.colorTransfer
                                          .withValues(alpha: 0.3)
                                      : Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                              child: Text(s.name,
                                  style: TextStyle(
                                      color: isSelected
                                          ? AppTheme.colorTransfer
                                          : Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

            const SizedBox(height: 24),

            // ── Date ──
            GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  builder: (ctx, child) => Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AppTheme.colorTransfer,
                        surface: Color(0xFF1E1E2C),
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (date != null) setState(() => _selectedDate = date);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: Colors.white38, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('d MMM yyyy', 'es').format(_selectedDate),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _SplitChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SplitChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.colorTransfer.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppTheme.colorTransfer.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Text(label,
            style: TextStyle(
                color:
                    isSelected ? AppTheme.colorTransfer : Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}
