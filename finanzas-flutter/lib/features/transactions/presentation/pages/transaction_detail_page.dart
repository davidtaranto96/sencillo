import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/logic/transaction_service.dart';
import '../../../../core/logic/people_service.dart';
import '../../domain/models/transaction.dart';
import '../../../accounts/domain/models/account.dart' as dom_acc;
import '../widgets/add_transaction_bottom_sheet.dart' show kCategoryIcons, kCategoryEmojis;

class TransactionDetailPage extends ConsumerWidget {
  final String txId;
  const TransactionDetailPage({super.key, required this.txId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(transactionsStreamProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);
    final categories = ref.watch(categoriesStreamProvider).valueOrNull ?? [];

    return txAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (transactions) {
        final tx = transactions.cast<Transaction?>().firstWhere(
          (t) => t?.id == txId,
          orElse: () => null,
        );

        if (tx == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Movimiento')),
            body: const Center(child: Text('Movimiento no encontrado', style: TextStyle(color: Colors.white54))),
          );
        }

        final accounts = accountsAsync.value ?? [];
        final account = accounts.cast<dynamic>().firstWhere(
          (a) => a.id == tx.accountId,
          orElse: () => null,
        );

        final color = colorForType(tx.type);
        final emoji = kCategoryEmojis[tx.categoryId];

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text('Detalle', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _showEditDialog(context, ref, tx, accounts),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.colorExpense),
                onPressed: () => _confirmDelete(context, ref, tx),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero amount card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2C),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: color.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: emoji != null
                            ? Center(child: Text(emoji, style: const TextStyle(fontSize: 28)))
                            : Icon(kCategoryIcons[tx.categoryId] ?? _iconForType(tx.type), color: color, size: 28),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        tx.title,
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${signForType(tx.type)}${formatAmount(tx.isShared ? tx.realExpense : tx.amount)}',
                        style: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w900, color: color),
                      ),
                      if (tx.isShared && tx.sharedTotalAmount != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Total: ${formatAmount(tx.sharedTotalAmount!)} · Tu parte: ${formatAmount(tx.sharedOwnAmount ?? 0)}',
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Info grid
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2C),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _InfoTile(
                            icon: Icons.calendar_today_rounded,
                            label: 'Fecha',
                            value: DateFormat('d MMM yyyy', 'es').format(tx.date),
                          )),
                          Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.06)),
                          Expanded(child: _InfoTile(
                            icon: Icons.access_time_rounded,
                            label: 'Hora',
                            value: DateFormat('HH:mm', 'es').format(tx.date),
                          )),
                        ],
                      ),
                      Divider(height: 24, color: Colors.white.withValues(alpha: 0.06)),
                      Row(
                        children: [
                          Expanded(child: _InfoTile(
                            icon: Icons.swap_vert_rounded,
                            label: 'Tipo',
                            value: _typeLabel(tx.type),
                            valueColor: color,
                          )),
                          Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.06)),
                          Expanded(child: _InfoTile(
                            icon: kCategoryIcons[tx.categoryId] ?? Icons.label_rounded,
                            label: 'Categoría',
                            value: _categoryLabel(tx.categoryId, categories),
                          )),
                        ],
                      ),
                      if (account != null) ...[
                        Divider(height: 24, color: Colors.white.withValues(alpha: 0.06)),
                        _InfoTile(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Cuenta',
                          value: account.name,
                          fullWidth: true,
                        ),
                      ],
                      if (tx.note != null && tx.note!.isNotEmpty) ...[
                        Divider(height: 24, color: Colors.white.withValues(alpha: 0.06)),
                        _InfoTile(
                          icon: Icons.notes_rounded,
                          label: 'Nota',
                          value: tx.note!,
                          fullWidth: true,
                        ),
                      ],
                    ],
                  ),
                ),

                // Shared expense desglose
                if (tx.isShared) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E2C),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.colorTransfer.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Gasto compartido', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => _showEditSharedSheet(context, ref, tx),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.colorTransfer.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_rounded, color: AppTheme.colorTransfer, size: 12),
                                    const SizedBox(width: 4),
                                    Text('Editar', style: TextStyle(color: AppTheme.colorTransfer, fontSize: 11, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(icon: Icons.payments_rounded, label: 'Total pagado', value: formatAmount(tx.sharedTotalAmount ?? tx.amount)),
                        _DetailRow(icon: Icons.person_rounded, label: 'Mi parte', value: formatAmount(tx.sharedOwnAmount ?? 0), valueColor: AppTheme.colorExpense),
                        _DetailRow(icon: Icons.people_rounded, label: 'Parte ajena', value: formatAmount(tx.sharedOtherAmount ?? 0), valueColor: AppTheme.colorWarning),
                        if ((tx.sharedRecovered ?? 0) > 0)
                          _DetailRow(icon: Icons.check_circle_rounded, label: 'Recuperado', value: formatAmount(tx.sharedRecovered!), valueColor: AppTheme.colorIncome),
                        if (tx.pendingToRecover > 0)
                          _DetailRow(icon: Icons.pending_rounded, label: 'Pendiente', value: formatAmount(tx.pendingToRecover), valueColor: AppTheme.colorWarning),
                      ],
                    ),
                  ),
                ],

                // Tags
                if (tx.isShared || tx.isExtraordinary) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (tx.isShared) _Tag(label: 'Compartido', color: AppTheme.colorTransfer),
                      if (tx.isExtraordinary) _Tag(label: 'Extraordinario', color: AppTheme.colorWarning),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _iconForType(TransactionType type) {
    switch (type) {
      case TransactionType.income:
      case TransactionType.loanReceived:
        return Icons.arrow_downward_rounded;
      case TransactionType.expense:
      case TransactionType.loanGiven:
        return Icons.arrow_upward_rounded;
      case TransactionType.transfer:
        return Icons.swap_horiz_rounded;
    }
  }

  String _categoryLabel(String? id, [List<dynamic>? dbCategories]) {
    const labels = {
      'food': 'Comida',
      'transport': 'Transporte',
      'health': 'Salud',
      'entertainment': 'Entretenimiento',
      'shopping': 'Compras',
      'home': 'Hogar',
      'education': 'Educación',
      'services': 'Servicios',
      'salary': 'Sueldo',
      'freelance': 'Freelance',
      'transfer': 'Transferencia',
      'cat_alim': 'Supermercado',
      'cat_transp': 'Transporte',
      'cat_entret': 'Entretenimiento',
      'cat_salud': 'Salud',
      'cat_financial': 'Financiero',
      'cat_peer_to_peer': 'Entre personas',
      'other_expense': 'Otro gasto',
      'other_income': 'Otro ingreso',
    };
    if (labels.containsKey(id)) return labels[id]!;
    // Check DB categories for custom budget categories (UUID-based)
    if (id != null && dbCategories != null) {
      for (final cat in dbCategories) {
        if (cat.id == id) return cat.name;
      }
    }
    return id ?? 'Sin categoría';
  }

  String _typeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.income: return 'Ingreso';
      case TransactionType.expense: return 'Gasto';
      case TransactionType.transfer: return 'Transferencia';
      case TransactionType.loanGiven: return 'Préstamo dado';
      case TransactionType.loanReceived: return 'Préstamo recibido';
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Transaction tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.colorExpense),
            SizedBox(width: 12),
            Expanded(child: Text('¿Eliminar movimiento?', style: TextStyle(color: Colors.white, fontSize: 17))),
          ],
        ),
        content: Text(
          '"${tx.title}" por ${formatAmount(tx.amount)}\n\nEl saldo de la cuenta se restaurará.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(transactionServiceProvider).deleteTransaction(tx.id);
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

  void _showEditDialog(BuildContext context, WidgetRef ref, Transaction tx, List accounts) {
    final titleCtrl = TextEditingController(text: tx.title);
    final amountCtrl = TextEditingController(text: formatInitialAmount(tx.isShared ? (tx.sharedTotalAmount ?? tx.amount) : tx.amount));
    final noteCtrl = TextEditingController(text: tx.note ?? '');
    final sharedOwnCtrl = TextEditingController(text: tx.isShared ? formatInitialAmount(tx.sharedOwnAmount ?? 0) : '');
    String selectedType = tx.type == TransactionType.income ? 'income' : tx.type == TransactionType.transfer ? 'transfer' : 'expense';
    String selectedCategory = tx.categoryId;
    String selectedAccountId = tx.accountId;
    DateTime selectedDate = tx.date;
    bool saving = false;
    // Shared expense state
    bool iPaid = tx.isShared ? (tx.accountId != 'shared_obligation') : true;


    final typeOptions = [
      ('income', 'Ingreso', Icons.arrow_downward_rounded, AppTheme.colorIncome),
      ('expense', 'Gasto', Icons.arrow_upward_rounded, AppTheme.colorExpense),
      ('transfer', 'Transferencia', Icons.swap_horiz_rounded, AppTheme.colorTransfer),
    ];

    IconData accountIcon(dom_acc.Account acc) {
      switch (acc.type) {
        case dom_acc.AccountType.cash: return Icons.payments_rounded;
        case dom_acc.AccountType.credit: return Icons.credit_card_rounded;
        case dom_acc.AccountType.bank: return Icons.account_balance_rounded;
        case dom_acc.AccountType.savings: return Icons.savings_rounded;
        case dom_acc.AccountType.investment: return Icons.trending_up_rounded;
      }
    }

showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          final typeColor = selectedType == 'income'
              ? AppTheme.colorIncome
              : selectedType == 'expense'
                  ? AppTheme.colorExpense
                  : AppTheme.colorTransfer;

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
            decoration: const BoxDecoration(
              color: Color(0xFF18181F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Handle + Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    children: [
                      Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.edit_rounded, color: typeColor, size: 18),
                          const SizedBox(width: 8),
                          Text('Editar Movimiento', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Scrollable content ──
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset > 0 ? bottomInset + 12 : 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Monto + Descripción en una fila ──
                        Row(
                          children: [
                            // Monto
                            Expanded(
                              flex: 3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: typeColor.withValues(alpha: 0.12)),
                                ),
                                child: Row(
                                  children: [
                                    Text(r'$', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: typeColor.withValues(alpha: 0.6))),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: TextField(
                                        controller: amountCtrl,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [ThousandsSeparatorFormatter()],
                                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Tipo inline chips
                            ...typeOptions.map((e) {
                              final isSelected = selectedType == e.$1;
                              final c = e.$4;
                              return Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: GestureDetector(
                                  onTap: () => setState(() => selectedType = e.$1),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isSelected ? c.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.03),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: isSelected ? c.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.06)),
                                    ),
                                    child: Icon(e.$3, size: 18, color: isSelected ? c : Colors.white24),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // ── Descripción ──
                        TextField(
                          controller: titleCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Descripción',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                            prefixIcon: Icon(Icons.short_text_rounded, color: Colors.white.withValues(alpha: 0.3), size: 18),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Cuenta ──
                        if (accounts.isNotEmpty) ...[
                          _sectionLabel('Cuenta'),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 52,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: accounts.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 6),
                              itemBuilder: (context, index) {
                                final acc = accounts[index] as dom_acc.Account;
                                final isSelected = acc.id == selectedAccountId;
                                final accColor = acc.isCreditCard ? AppTheme.colorWarning : AppTheme.colorTransfer;
                                return GestureDetector(
                                  onTap: () => setState(() => selectedAccountId = acc.id),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected ? accColor.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.02),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isSelected ? accColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.06)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(accountIcon(acc), size: 16, color: isSelected ? accColor : Colors.white30),
                                        const SizedBox(width: 6),
                                        Text(acc.name, style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.white54,
                                          fontSize: 12, fontWeight: FontWeight.w600,
                                        ), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // ── Fecha + Categoría en fila ──
                        Row(
                          children: [
                            // Fecha compacta
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now().add(const Duration(days: 365)),
                                    builder: (context, child) => Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.dark(primary: AppTheme.colorTransfer, surface: Color(0xFF1E1E2C)),
                                      ),
                                      child: child!,
                                    ),
                                  );
                                  if (picked != null) {
                                    setState(() => selectedDate = DateTime(picked.year, picked.month, picked.day, selectedDate.hour, selectedDate.minute));
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.02),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today_rounded, color: AppTheme.colorTransfer.withValues(alpha: 0.6), size: 15),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          DateFormat('d MMM yyyy', 'es').format(selectedDate),
                                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ── Categoría ──
                        _sectionLabel('Categoría'),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 34,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: kCategoryEmojis.entries.map((entry) {
                              final isSelected = selectedCategory == entry.key;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: GestureDetector(
                                  onTap: () => setState(() => selectedCategory = entry.key),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected ? typeColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.02),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: isSelected ? typeColor.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06)),
                                    ),
                                    child: Center(child: Text(
                                      '${entry.value} ${_categoryLabel(entry.key)}',
                                      style: TextStyle(color: isSelected ? Colors.white : Colors.white38, fontSize: 12, fontWeight: FontWeight.w500),
                                    )),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Nota ──
                        TextField(
                          controller: noteCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          maxLines: 2,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: 'Nota (opcional)',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                            prefixIcon: Icon(Icons.notes_rounded, color: Colors.white.withValues(alpha: 0.3), size: 18),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                          ),
                        ),

                        // ── Shared expense fields ──
                        if (tx.isShared) ...[
                          const SizedBox(height: 16),
                          _sectionLabel('Gasto compartido'),
                          const SizedBox(height: 8),
                          // Payer toggle
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => iPaid = true),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: iPaid ? AppTheme.colorIncome.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.03),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: iPaid ? AppTheme.colorIncome.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.06)),
                                    ),
                                    child: Center(child: Text('Yo pagué', style: TextStyle(color: iPaid ? AppTheme.colorIncome : Colors.white38, fontWeight: FontWeight.w600, fontSize: 12))),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => iPaid = false),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: !iPaid ? AppTheme.colorExpense.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.03),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: !iPaid ? AppTheme.colorExpense.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.06)),
                                    ),
                                    child: Center(child: Text('Otro pagó', style: TextStyle(color: !iPaid ? AppTheme.colorExpense : Colors.white38, fontWeight: FontWeight.w600, fontSize: 12))),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Own amount
                          TextField(
                            controller: sharedOwnCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [ThousandsSeparatorFormatter()],
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Mi parte',
                              prefixText: r'$ ',
                              prefixStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),

                // ── Botón guardar (fijo abajo) ──
                Container(
                  padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).padding.bottom + 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181F),
                    border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.04))),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      onPressed: saving ? null : () async {
                        setState(() => saving = true);
                        try {
                          final newAmount = amountCtrl.text.isNotEmpty ? parseFormattedAmount(amountCtrl.text) : tx.amount;

                          if (tx.isShared) {
                            // Update shared expense with balance recalculation
                            final newOwn = sharedOwnCtrl.text.isNotEmpty ? parseFormattedAmount(sharedOwnCtrl.text) : (tx.sharedOwnAmount ?? 0);
                            final newOther = newAmount - newOwn;
                            await ref.read(peopleServiceProvider).updateSharedExpense(
                              txId: tx.id,
                              newTotal: newAmount,
                              newOwn: newOwn,
                              newOther: newOther > 0 ? newOther : 0,
                              description: titleCtrl.text.isNotEmpty ? titleCtrl.text : null,
                            );
                          } else {
                            final origType = tx.type == TransactionType.income ? 'income' : tx.type == TransactionType.transfer ? 'transfer' : 'expense';
                            // Always pass accountId if it changed — use explicit variable
                            final newAccountId = selectedAccountId;
                            final accountChanged = newAccountId != tx.accountId;
                            await ref.read(transactionServiceProvider).updateTransaction(
                              id: tx.id,
                              title: titleCtrl.text,
                              amount: newAmount != tx.amount ? newAmount : null,
                              type: selectedType != origType ? selectedType : null,
                              categoryId: selectedCategory != tx.categoryId ? selectedCategory : null,
                              accountId: accountChanged ? newAccountId : null,
                              date: selectedDate != tx.date ? selectedDate : null,
                              note: noteCtrl.text.isNotEmpty ? noteCtrl.text : null,
                              clearNote: noteCtrl.text.isEmpty && tx.note != null,
                            );
                          }
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Movimiento actualizado')),
                            );
                          }
                        } catch (_) {
                          if (ctx.mounted) setState(() => saving = false);
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: typeColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_rounded, size: 18),
                                const SizedBox(width: 6),
                                const Text('Guardar Cambios', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget _sectionLabel(String text) {
    return Text(text, style: TextStyle(
      color: Colors.white.withValues(alpha: 0.4),
      fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3,
    ));
  }

  void _showEditSharedSheet(BuildContext context, WidgetRef ref, Transaction tx) {
    final totalCtrl = TextEditingController(
        text: formatInitialAmount(tx.sharedTotalAmount ?? tx.amount));
    final ownCtrl = TextEditingController(
        text: formatInitialAmount(tx.sharedOwnAmount ?? 0));
    final descCtrl = TextEditingController(text: tx.title);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85),
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 40),
        decoration: const BoxDecoration(
          color: Color(0xFF18181F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text('Editar gasto compartido',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              TextField(
                controller: descCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Descripción',
                  labelStyle: const TextStyle(color: AppTheme.colorTransfer),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.colorTransfer),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: totalCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorFormatter()],
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Total',
                  prefixText: r'$ ',
                  prefixStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  labelStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.colorTransfer),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ownCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorFormatter()],
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Mi parte',
                  prefixText: r'$ ',
                  prefixStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  labelStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.colorTransfer),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () async {
                    final newTotal = parseFormattedAmount(totalCtrl.text);
                    final newOwn = parseFormattedAmount(ownCtrl.text);
                    final newOther = newTotal - newOwn;
                    if (newTotal <= 0 || newOwn < 0 || newOther < 0) return;
                    await ref.read(peopleServiceProvider).updateSharedExpense(
                      txId: tx.id,
                      newTotal: newTotal,
                      newOwn: newOwn,
                      newOther: newOther,
                      description: descCtrl.text.trim().isNotEmpty
                          ? descCtrl.text.trim()
                          : null,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.colorTransfer,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Guardar',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool fullWidth;
  const _InfoTile({required this.icon, required this.label, required this.value, this.valueColor, this.fullWidth = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: fullWidth ? 0 : 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _DetailRow({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white38),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 13)),
          const Spacer(),
          Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
