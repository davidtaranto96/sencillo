import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/logic/people_service.dart';
import '../../../../core/utils/format_utils.dart';
import '../../domain/models/person.dart';
import '../../../transactions/domain/models/transaction.dart' as dom_tx;
import '../../../transactions/presentation/pages/transaction_detail_page.dart';
import '../../../accounts/domain/models/account.dart' as dom_a;
import 'add_expense_page.dart';

class PersonDetailPage extends ConsumerWidget {
  final Person person;
  const PersonDetailPage({super.key, required this.person});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Re-watch person for live updates
    final peopleAsync = ref.watch(peopleStreamProvider);
    final livePerson = peopleAsync.valueOrNull
            ?.where((p) => p.id == person.id)
            .firstOrNull ??
        person;

    final txsAsync = ref.watch(personTransactionsProvider(person.id));
    final isPositive = livePerson.totalBalance > 0;
    final isZero = livePerson.totalBalance == 0;
    final color = isZero
        ? Colors.white38
        : isPositive
            ? AppTheme.colorIncome
            : AppTheme.colorExpense;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: const BackButton(color: Colors.white),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white54),
                color: const Color(0xFF1E1E2C),
                onSelected: (val) {
                  if (val == 'edit') _showEditSheet(context, ref, livePerson);
                  if (val == 'delete') _confirmDelete(context, ref);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                      value: 'edit',
                      child: Text('Editar', style: TextStyle(color: Colors.white))),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Text('Eliminar',
                          style: TextStyle(color: AppTheme.colorExpense))),
                ],
              ),
            ],
          ),

          // ── Profile Header ──
          SliverToBoxAdapter(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor:
                      livePerson.avatarColor.withValues(alpha: 0.2),
                  child: Text(
                    livePerson.displayName[0].toUpperCase(),
                    style: TextStyle(
                        color: livePerson.avatarColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 28),
                  ),
                ),
                const SizedBox(height: 12),
                Text(livePerson.displayName,
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
                if (livePerson.alias != null && livePerson.alias != livePerson.name)
                  Text(livePerson.name,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 14)),
                if (livePerson.cbu != null && livePerson.cbu!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: livePerson.cbu!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('CBU/CVU copiado'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 60),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_balance_rounded,
                              color: Colors.white.withValues(alpha: 0.3), size: 14),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              livePerson.cbu!,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 11,
                                  fontFamily: 'monospace'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.copy_rounded,
                              color: AppTheme.colorTransfer.withValues(alpha: 0.5), size: 13),
                        ],
                      ),
                    ),
                  ),
                ],
                if (livePerson.notes != null && livePerson.notes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(livePerson.notes!,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 12,
                          fontStyle: FontStyle.italic)),
                ],
                const SizedBox(height: 16),

                // Balance card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isZero
                            ? 'Al día'
                            : isPositive
                                ? 'Te debe'
                                : 'Le debés',
                        style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isZero
                            ? '\$0'
                            : formatAmount(livePerson.totalBalance.abs()),
                        style: GoogleFonts.inter(
                          color: isZero ? Colors.white38 : Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      if (!isZero)
                        Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.handshake_outlined,
                                label: isPositive ? 'Me pagó' : 'Pagarle',
                                color: color,
                                onTap: () =>
                                    _showLiquidateSheet(context, ref, livePerson),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.receipt_long_rounded,
                                label: 'Nuevo gasto',
                                color: AppTheme.colorTransfer,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddExpensePage(
                                        preselectedPersonId: person.id),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (!isZero) const SizedBox(height: 8),
                      _ActionButton(
                        icon: Icons.history_rounded,
                        label: 'Deuda anterior',
                        color: Colors.white38,
                        onTap: () =>
                            _showPriorDebtSheet(context, ref, livePerson),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // ── Section header ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('Historial',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3)),
            ),
          ),

          // ── Transactions ──
          txsAsync.when(
            loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverFillRemaining(
                child: Center(
                    child: Text('Error: $e',
                        style: const TextStyle(color: Colors.white)))),
            data: (txs) {
              if (txs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 40,
                            color: Colors.white.withValues(alpha: 0.1)),
                        const SizedBox(height: 8),
                        const Text('Sin transacciones',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 14)),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _TransactionRow(tx: txs[index]),
                    childCount: txs.length,
                  ),
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref, Person p) {
    final nameCtrl = TextEditingController(text: p.name);
    final aliasCtrl = TextEditingController(text: p.alias ?? '');
    final cbuCtrl = TextEditingController(text: p.cbu ?? '');
    final notesCtrl = TextEditingController(text: p.notes ?? '');

    InputDecoration fieldDecor(String label, {bool highlight = false}) =>
        InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
              color: highlight
                  ? AppTheme.colorTransfer
                  : Colors.white.withValues(alpha: 0.4)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.colorTransfer),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        );

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
              Text('Editar ${p.displayName}',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: fieldDecor('Nombre', highlight: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: aliasCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: fieldDecor('Apodo'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cbuCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                keyboardType: TextInputType.number,
                decoration: fieldDecor('CBU / CVU / Alias bancario'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                maxLines: 2,
                minLines: 1,
                decoration: fieldDecor('Notas'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final alias = aliasCtrl.text.trim();
                    final cbu = cbuCtrl.text.trim();
                    final notes = notesCtrl.text.trim();
                    await ref.read(peopleServiceProvider).updatePerson(
                      personId: p.id,
                      name: name,
                      alias: alias.isEmpty ? null : alias,
                      cbu: cbu.isEmpty ? null : cbu,
                      clearCbu: cbu.isEmpty && p.cbu != null,
                      notes: notes.isEmpty ? null : notes,
                      clearNotes: notes.isEmpty && p.notes != null,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.colorTransfer,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Guardar',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens a sheet to record a pre-existing debt/loan without touching any account.
  void _showPriorDebtSheet(
      BuildContext context, WidgetRef ref, Person p) {
    bool iTheyOweMe = true; // true = me deben, false = les debo
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    InputDecoration fieldDecor(String label) => InputDecoration(
          labelText: label,
          labelStyle:
              TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.colorTransfer),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Container(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 40),
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
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text('Deuda anterior con ${p.displayName}',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text(
                    'Registrá una deuda existente sin afectar ninguna cuenta.',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 20),

                // Direction
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => iTheyOweMe = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: iTheyOweMe
                                ? AppTheme.colorIncome.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: iTheyOweMe
                                  ? AppTheme.colorIncome.withValues(alpha: 0.3)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Center(
                            child: Text('Me debe',
                                style: TextStyle(
                                    color: iTheyOweMe
                                        ? AppTheme.colorIncome
                                        : Colors.white38,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => iTheyOweMe = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !iTheyOweMe
                                ? AppTheme.colorExpense.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: !iTheyOweMe
                                  ? AppTheme.colorExpense.withValues(alpha: 0.3)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Center(
                            child: Text('Le debo',
                                style: TextStyle(
                                    color: !iTheyOweMe
                                        ? AppTheme.colorExpense
                                        : Colors.white38,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsSeparatorFormatter()],
                  autofocus: true,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    prefixText: '\$ ',
                    prefixStyle:
                        TextStyle(color: Colors.white24, fontSize: 24),
                    hintText: '0',
                    hintStyle: TextStyle(color: Colors.white12),
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 14),
                  decoration: fieldDecor('Nota (opcional)'),
                  maxLines: 2,
                  minLines: 1,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () async {
                      final amount =
                          parseFormattedAmount(amountCtrl.text);
                      if (amount <= 0) return;
                      // positive delta = they owe me more; negative = I owe them more
                      final delta = iTheyOweMe ? amount : -amount;
                      await ref
                          .read(peopleServiceProvider)
                          .adjustBalance(personId: p.id, delta: delta);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.colorTransfer,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Registrar',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('Eliminar persona',
            style: TextStyle(color: Colors.white)),
        content: Text(
            '¿Eliminar a ${person.displayName}? Se mantendrán las transacciones.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(peopleServiceProvider).deletePerson(person.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.colorExpense),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showLiquidateSheet(
      BuildContext context, WidgetRef ref, Person p) {
    final accounts = ref.read(accountsStreamProvider).value ?? [];
    final sources = accounts.toList();
    dom_a.Account? selectedSource; // null = sin cuenta
    final amountCtrl =
        TextEditingController(text: formatInitialAmount(p.totalBalance.abs()));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85),
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 40),
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
                Text(
                  p.totalBalance > 0
                      ? '${p.displayName} te paga'
                      : 'Le pagás a ${p.displayName}',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                if (sources.isNotEmpty) ...[
                  const Text('Cuenta (opcional)',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButton<dom_a.Account?>(
                    value: selectedSource,
                    dropdownColor: const Color(0xFF1E1E2C),
                    isExpanded: true,
                    style: const TextStyle(color: Colors.white),
                    hint: const Text('Sin cuenta (solo ajustar saldo)',
                        style: TextStyle(color: Colors.white38, fontSize: 14)),
                    items: [
                      const DropdownMenuItem<dom_a.Account?>(
                        value: null,
                        child: Text('Sin cuenta',
                            style: TextStyle(color: Colors.white54)),
                      ),
                      ...sources.map((s) => DropdownMenuItem<dom_a.Account?>(
                          value: s,
                          child: Text('${s.name} (${formatAmount(s.balance)})'))),
                    ],
                    onChanged: (val) => setState(() => selectedSource = val),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsSeparatorFormatter()],
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    prefixText: '\$ ',
                    prefixStyle: TextStyle(color: Colors.white24, fontSize: 24),
                    hintText: '0',
                    hintStyle: TextStyle(color: Colors.white12),
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () async {
                            final amount =
                                parseFormattedAmount(amountCtrl.text);
                            if (amount <= 0) return;
                            final actualAmount =
                                p.totalBalance > 0 ? amount : -amount;
                            await ref.read(peopleServiceProvider).liquidateDebt(
                              personId: p.id,
                              amount: actualAmount,
                              accountId: selectedSource?.id,
                            );
                            if (context.mounted) Navigator.pop(ctx);
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.colorTransfer,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Confirmar',
                        style:
                            TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final dom_tx.Transaction tx;
  const _TransactionRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isExpense = tx.type == dom_tx.TransactionType.expense;
    final isLoanGiven = tx.type == dom_tx.TransactionType.loanGiven;
    final isIncome = tx.type == dom_tx.TransactionType.income;

    Color color;
    IconData icon;

    if (tx.isShared) {
      color = AppTheme.colorTransfer;
      icon = Icons.call_split_rounded;
    } else if (isLoanGiven) {
      color = AppTheme.colorWarning;
      icon = Icons.arrow_upward_rounded;
    } else if (isIncome) {
      color = AppTheme.colorIncome;
      icon = Icons.arrow_downward_rounded;
    } else {
      color = AppTheme.colorExpense;
      icon = Icons.receipt_outlined;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionDetailPage(txId: tx.id),
          ),
        );
      },
      onLongPress: tx.isShared
          ? () => _showEditSharedSheet(context, tx)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C).withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(
                    DateFormat('d MMM yyyy', 'es').format(tx.date),
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isExpense || isLoanGiven ? '-' : '+'}${formatAmount(tx.amount)}',
                  style: GoogleFonts.inter(
                      color: color, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                if (tx.isShared && tx.sharedOwnAmount != null)
                  Text(
                    'Tu parte: ${formatAmount(tx.sharedOwnAmount!)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static void _showEditSharedSheet(
      BuildContext context, dom_tx.Transaction tx) {
    final totalCtrl = TextEditingController(
        text: formatInitialAmount(tx.sharedTotalAmount ?? tx.amount));
    final ownCtrl = TextEditingController(
        text: formatInitialAmount(tx.sharedOwnAmount ?? 0));
    final descCtrl = TextEditingController(text: tx.title);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer(
          builder: (context, ref, _) => Container(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            padding: EdgeInsets.fromLTRB(
                24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 40),
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
                        borderSide:
                            const BorderSide(color: AppTheme.colorTransfer),
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
                      prefixStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3)),
                      labelStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AppTheme.colorTransfer),
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
                      prefixStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3)),
                      labelStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AppTheme.colorTransfer),
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
                        await ref
                            .read(peopleServiceProvider)
                            .updateSharedExpense(
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
        ),
    );
  }
}


