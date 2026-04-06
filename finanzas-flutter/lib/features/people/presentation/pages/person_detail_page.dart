import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/logic/people_service.dart';
import '../../../../core/services/firestore_service.dart';
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

    final balanceColor = isZero
        ? Colors.white38
        : isPositive
            ? AppTheme.colorIncome
            : AppTheme.colorExpense;

    // Stats calculated from transactions
    final txs = txsAsync.valueOrNull ?? [];
    final sharedTxs = txs.where((t) => t.isShared).toList();
    final totalSharedAmount = sharedTxs.fold(0.0, (s, t) => s + (t.sharedTotalAmount ?? t.amount));
    final lastDate = txs.isNotEmpty ? txs.first.date : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            pinned: true,
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
                      child: Text('Eliminar', style: TextStyle(color: AppTheme.colorExpense))),
                ],
              ),
            ],
          ),

          // ── Hero Card (avatar + nombre + balance) ──
          SliverToBoxAdapter(
            child: _PersonHeroCard(
              person: livePerson,
              balanceColor: balanceColor,
              isZero: isZero,
              isPositive: isPositive,
            ),
          ),

          // ── Quick Actions — siempre visibles ──
          SliverToBoxAdapter(
            child: _QuickActionsRow(
              person: livePerson,
              isZero: isZero,
              isPositive: isPositive,
              onNewExpense: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddExpensePage(preselectedPersonId: person.id)),
              ),
              onLiquidate: () => isZero
                  ? ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text('Al día con ${livePerson.displayName} ✓'),
                        ]),
                        backgroundColor: const Color(0xFF4CAF50),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    )
                  : _showLiquidateSheet(context, ref, livePerson),
              onPriorDebt: () => _showPriorDebtSheet(context, ref, livePerson),
            ),
          ),

          // ── Stats card (if any transactions) ──
          if (txs.isNotEmpty)
            SliverToBoxAdapter(
              child: _StatsCard(
                sharedCount: sharedTxs.length,
                totalShared: totalSharedAmount,
                lastDate: lastDate,
              ),
            ),

          // ── Group debts (if person belongs to groups) ──
          if (livePerson.groupDebts.isNotEmpty)
            SliverToBoxAdapter(
              child: _GroupDebtsSection(groupDebts: livePerson.groupDebts),
            ),

          // ── Section header ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                children: [
                  Text(
                    'Historial',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5),
                  ),
                  const SizedBox(width: 8),
                  if (txs.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${txs.length}',
                        style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.3)),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Transactions list ──
          txsAsync.when(
            loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white)))),
            data: (txList) {
              if (txList.isEmpty) {
                return const SliverFillRemaining(child: _EmptyHistory());
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TransactionRow(tx: txList[index]),
                    ),
                    childCount: txList.length,
                  ),
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }

  // ── Edit Sheet ────────────────────────────────────────────────────────────

  void _showEditSheet(BuildContext context, WidgetRef ref, Person p) {
    final nameCtrl = TextEditingController(text: p.name);
    final aliasCtrl = TextEditingController(text: p.alias ?? '');
    final cbuCtrl = TextEditingController(text: p.cbu ?? '');
    final notesCtrl = TextEditingController(text: p.notes ?? '');

    InputDecoration fieldDecor(String label, {bool highlight = false}) =>
        InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: highlight ? AppTheme.colorTransfer : Colors.white.withValues(alpha: 0.4)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.colorTransfer),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 40),
        decoration: const BoxDecoration(
          color: Color(0xFF18181F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2)))),
              Text('Editar ${p.displayName}',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              TextField(controller: nameCtrl, autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: fieldDecor('Nombre', highlight: true)),
              const SizedBox(height: 12),
              TextField(controller: aliasCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: fieldDecor('Apodo')),
              const SizedBox(height: 12),
              TextField(controller: cbuCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  keyboardType: TextInputType.number,
                  decoration: fieldDecor('CBU / CVU / Alias bancario')),
              const SizedBox(height: 12),
              TextField(controller: notesCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  maxLines: 2, minLines: 1,
                  decoration: fieldDecor('Notas')),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 52,
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Prior Debt Sheet ──────────────────────────────────────────────────────

  void _showPriorDebtSheet(BuildContext context, WidgetRef ref, Person p) {
    bool iTheyOweMe = true;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    InputDecoration fieldDecor(String label) => InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.colorTransfer)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 40),
          decoration: const BoxDecoration(
            color: Color(0xFF18181F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2)))),
                Text('Deuda anterior con ${p.displayName}',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Registrá una deuda existente sin afectar ninguna cuenta.',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => iTheyOweMe = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: iTheyOweMe ? AppTheme.colorIncome.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: iTheyOweMe ? AppTheme.colorIncome.withValues(alpha: 0.3) : Colors.transparent),
                          ),
                          child: Center(child: Text('Me debe', style: TextStyle(
                              color: iTheyOweMe ? AppTheme.colorIncome : Colors.white38,
                              fontWeight: FontWeight.w600))),
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
                            color: !iTheyOweMe ? AppTheme.colorExpense.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: !iTheyOweMe ? AppTheme.colorExpense.withValues(alpha: 0.3) : Colors.transparent),
                          ),
                          child: Center(child: Text('Le debo', style: TextStyle(
                              color: !iTheyOweMe ? AppTheme.colorExpense : Colors.white38,
                              fontWeight: FontWeight.w600))),
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
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    prefixText: '\$ ',
                    prefixStyle: TextStyle(color: Colors.white24, fontSize: 24),
                    hintText: '0',
                    hintStyle: TextStyle(color: Colors.white12),
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  decoration: fieldDecor('Nota (opcional)'),
                  maxLines: 2, minLines: 1,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: FilledButton(
                    onPressed: () async {
                      final amount = parseFormattedAmount(amountCtrl.text);
                      if (amount <= 0) return;
                      final delta = iTheyOweMe ? amount : -amount;
                      await ref.read(peopleServiceProvider).adjustBalance(personId: p.id, delta: delta);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.colorTransfer,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Registrar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Delete Confirm ────────────────────────────────────────────────────────

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('Eliminar persona', style: TextStyle(color: Colors.white)),
        content: Text('¿Eliminar a ${person.displayName}? Se mantendrán las transacciones.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
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

  // ── Liquidate Sheet ───────────────────────────────────────────────────────

  void _showLiquidateSheet(BuildContext context, WidgetRef ref, Person p) {
    final accounts = ref.read(accountsStreamProvider).value ?? [];
    dom_a.Account? selectedSource;
    final amountCtrl = TextEditingController(text: formatInitialAmount(p.totalBalance.abs()));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 40),
          decoration: const BoxDecoration(
            color: Color(0xFF18181F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2)))),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.colorTransfer.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.handshake_rounded, color: AppTheme.colorTransfer, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.totalBalance > 0 ? '${p.displayName} te paga' : 'Le pagás a ${p.displayName}',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            p.totalBalance > 0
                                ? 'Balance actual: ${formatAmount(p.totalBalance)} a tu favor'
                                : 'Balance actual: debés ${formatAmount(p.totalBalance.abs())}',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (accounts.isNotEmpty) ...[
                  Text('Cuenta (opcional)', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => selectedSource = null),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: selectedSource == null ? AppTheme.colorTransfer.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: selectedSource == null ? AppTheme.colorTransfer.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06)),
                            ),
                            child: Center(child: Text('Sin cuenta', style: TextStyle(
                                color: selectedSource == null ? AppTheme.colorTransfer : Colors.white38,
                                fontSize: 12, fontWeight: FontWeight.w600))),
                          ),
                        ),
                        ...accounts.map((acc) {
                          final isSelected = selectedSource?.id == acc.id;
                          return GestureDetector(
                            onTap: () => setState(() => selectedSource = acc),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.colorTransfer.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isSelected ? AppTheme.colorTransfer.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06)),
                              ),
                              child: Center(child: Text(acc.name, style: TextStyle(
                                  color: isSelected ? AppTheme.colorTransfer : Colors.white38,
                                  fontSize: 12, fontWeight: FontWeight.w600))),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsSeparatorFormatter()],
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
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
                  width: double.infinity, height: 52,
                  child: FilledButton(
                    onPressed: () async {
                      final amount = parseFormattedAmount(amountCtrl.text);
                      if (amount <= 0) return;
                      final actualAmount = p.totalBalance > 0 ? amount : -amount;
                      await ref.read(peopleServiceProvider).liquidateDebt(
                        personId: p.id,
                        amount: actualAmount,
                        accountId: selectedSource?.id,
                      );
                      if (context.mounted) Navigator.pop(ctx);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.colorTransfer,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Confirmar liquidación', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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

// ═════════════════════════════════════════════════════════════════════════════
// HERO CARD
// ═════════════════════════════════════════════════════════════════════════════

class _PersonHeroCard extends ConsumerWidget {
  final Person person;
  final Color balanceColor;
  final bool isZero;
  final bool isPositive;

  const _PersonHeroCard({
    required this.person,
    required this.balanceColor,
    required this.isZero,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            balanceColor.withValues(alpha: isZero ? 0.04 : 0.08),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: balanceColor.withValues(alpha: isZero ? 0.08 : 0.15)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              children: [
                // Avatar
                _LinkedAvatar(person: person, radius: 36),
                const SizedBox(height: 12),

                // Name
                Text(
                  person.displayName,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),

                // Sub-name (if alias)
                if (person.alias != null && person.alias != person.name)
                  Text(person.name, style: const TextStyle(color: Colors.white38, fontSize: 14)),

                const SizedBox(height: 8),

                // Badges row
                Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (person.isLinked)
                      _Badge(
                        icon: Icons.link_rounded,
                        label: 'Vinculado',
                        color: const Color(0xFF5ECFB1),
                      ),
                    if (person.cbu != null && person.cbu!.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: person.cbu!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('CBU/CVU copiado'), duration: Duration(seconds: 2)),
                          );
                        },
                        child: _Badge(
                          icon: Icons.account_balance_rounded,
                          label: person.cbu!.length > 14
                              ? '${person.cbu!.substring(0, 14)}…'
                              : person.cbu!,
                          color: Colors.white38,
                          trailingIcon: Icons.copy_rounded,
                        ),
                      ),
                  ],
                ),

                if (person.notes != null && person.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    person.notes!,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Balance strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: balanceColor.withValues(alpha: isZero ? 0.04 : 0.1),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
            ),
            child: Column(
              children: [
                Text(
                  isZero ? 'Al día' : isPositive ? 'Te debe' : 'Le debés',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: balanceColor.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 4),
                Text(
                  isZero ? '\$0' : formatAmount(person.totalBalance.abs()),
                  style: GoogleFonts.inter(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: isZero ? Colors.white24 : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// QUICK ACTIONS ROW — 3 botones siempre visibles
// ═════════════════════════════════════════════════════════════════════════════

class _QuickActionsRow extends StatelessWidget {
  final Person person;
  final bool isZero;
  final bool isPositive;
  final VoidCallback onNewExpense;
  final VoidCallback onLiquidate;
  final VoidCallback onPriorDebt;

  const _QuickActionsRow({
    required this.person,
    required this.isZero,
    required this.isPositive,
    required this.onNewExpense,
    required this.onLiquidate,
    required this.onPriorDebt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _QuickBtn(
              icon: Icons.receipt_long_rounded,
              label: 'Nuevo gasto',
              color: AppTheme.colorTransfer,
              onTap: onNewExpense,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickBtn(
              icon: Icons.handshake_rounded,
              label: isPositive ? 'Me pagó' : isZero ? 'Liquidar' : 'Pagarle',
              color: isZero ? Colors.white38 : (isPositive ? AppTheme.colorIncome : AppTheme.colorExpense),
              onTap: onLiquidate,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickBtn(
              icon: Icons.history_rounded,
              label: 'Deuda anterior',
              color: Colors.white38,
              onTap: onPriorDebt,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.14)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 5),
            Text(
              label,
              style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STATS CARD
// ═════════════════════════════════════════════════════════════════════════════

class _StatsCard extends StatelessWidget {
  final int sharedCount;
  final double totalShared;
  final DateTime? lastDate;

  const _StatsCard({required this.sharedCount, required this.totalShared, required this.lastDate});

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date).inDays;
    if (diff == 0) return 'hoy';
    if (diff == 1) return 'ayer';
    if (diff < 7) return 'hace $diff días';
    if (diff < 30) return 'hace ${(diff / 7).round()} sem.';
    return DateFormat('d MMM', 'es').format(date);
  }

  @override
  Widget build(BuildContext context) {
    if (sharedCount == 0 && lastDate == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          if (sharedCount > 0) ...[
            _StatItem(
              icon: Icons.call_split_rounded,
              value: '$sharedCount',
              label: 'gastos compartidos',
              color: AppTheme.colorTransfer,
            ),
            if (totalShared > 0) ...[
              Container(width: 1, height: 32, margin: const EdgeInsets.symmetric(horizontal: 12), color: Colors.white.withValues(alpha: 0.07)),
              _StatItem(
                icon: Icons.attach_money_rounded,
                value: formatAmount(totalShared, compact: true),
                label: 'total gastado juntos',
                color: Colors.white54,
              ),
            ],
          ],
          if (lastDate != null) ...[
            if (sharedCount > 0)
              Container(width: 1, height: 32, margin: const EdgeInsets.symmetric(horizontal: 12), color: Colors.white.withValues(alpha: 0.07)),
            _StatItem(
              icon: Icons.schedule_rounded,
              value: _timeAgo(lastDate!),
              label: 'último movimiento',
              color: Colors.white38,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.white30), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// GROUP DEBTS SECTION
// ═════════════════════════════════════════════════════════════════════════════

class _GroupDebtsSection extends StatelessWidget {
  final List<DebtDetail> groupDebts;
  const _GroupDebtsSection({required this.groupDebts});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.group_rounded, size: 14, color: Colors.white38),
              const SizedBox(width: 6),
              Text('Desglose por grupos', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white38)),
            ],
          ),
          const SizedBox(height: 10),
          ...groupDebts.map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.colorTransfer.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.people_rounded, size: 14, color: AppTheme.colorTransfer),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(d.groupName, style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
                ),
                Text(
                  formatAmount(d.amount.abs(), compact: true),
                  style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: d.amount > 0 ? AppTheme.colorIncome : AppTheme.colorExpense,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TRANSACTION ROW — mejorado con badges de tipo
// ═════════════════════════════════════════════════════════════════════════════

class _TransactionRow extends ConsumerWidget {
  final dom_tx.Transaction tx;
  const _TransactionRow({required this.tx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpense = tx.type == dom_tx.TransactionType.expense;
    final isLoanGiven = tx.type == dom_tx.TransactionType.loanGiven;
    final isIncome = tx.type == dom_tx.TransactionType.income;
    final isLoanReceived = tx.type == dom_tx.TransactionType.loanReceived;

    Color color;
    IconData icon;
    String typeLabel;
    Color typeBadgeColor;

    if (tx.isShared) {
      color = AppTheme.colorTransfer;
      icon = Icons.call_split_rounded;
      typeLabel = 'Compartido';
      typeBadgeColor = AppTheme.colorTransfer;
    } else if (isLoanGiven) {
      color = AppTheme.colorWarning;
      icon = Icons.arrow_upward_rounded;
      typeLabel = 'Préstamo';
      typeBadgeColor = AppTheme.colorWarning;
    } else if (isIncome) {
      color = AppTheme.colorIncome;
      icon = Icons.arrow_downward_rounded;
      typeLabel = tx.note?.contains('liquidacion') == true ? 'Cobrado' : 'Ingreso';
      typeBadgeColor = AppTheme.colorIncome;
    } else if (isLoanReceived) {
      color = AppTheme.colorIncome;
      icon = Icons.arrow_downward_rounded;
      typeLabel = 'Recibido';
      typeBadgeColor = AppTheme.colorIncome;
    } else {
      color = AppTheme.colorExpense;
      icon = Icons.receipt_outlined;
      typeLabel = 'Gasto';
      typeBadgeColor = AppTheme.colorExpense;
    }

    // Detect settlement
    final isSettlement = tx.note?.contains('liquidacion') == true || tx.note?.contains('settlement') == true;
    if (isSettlement) {
      typeLabel = isIncome ? 'Cobrado' : 'Liquidado';
      typeBadgeColor = AppTheme.colorIncome;
      color = AppTheme.colorIncome;
    }

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TransactionDetailPage(txId: tx.id))),
      onLongPress: tx.isShared ? () => _showEditSharedSheet(context, ref, tx) : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.title,
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Type badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeBadgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(typeLabel, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: typeBadgeColor)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('d MMM', 'es').format(tx.date),
                        style: GoogleFonts.inter(fontSize: 10, color: Colors.white30),
                      ),
                    ],
                  ),
                  // Shared detail
                  if (tx.isShared && tx.sharedOwnAmount != null && tx.sharedTotalAmount != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Tu parte ${formatAmount(tx.sharedOwnAmount!)} de ${formatAmount(tx.sharedTotalAmount!)}',
                      style: GoogleFonts.inter(fontSize: 10, color: Colors.white30),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),
            // Amount
            Text(
              '${isExpense || isLoanGiven ? '-' : '+'}${formatAmount(tx.amount)}',
              style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  static void _showEditSharedSheet(BuildContext context, WidgetRef ref, dom_tx.Transaction tx) {
    final totalCtrl = TextEditingController(text: formatInitialAmount(tx.sharedTotalAmount ?? tx.amount));
    final ownCtrl = TextEditingController(text: formatInitialAmount(tx.sharedOwnAmount ?? 0));
    final descCtrl = TextEditingController(text: tx.title);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) => Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 40),
          decoration: const BoxDecoration(
            color: Color(0xFF18181F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2)))),
                Text('Editar gasto compartido',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                _EditField(controller: descCtrl, label: 'Descripción'),
                const SizedBox(height: 12),
                _EditField(controller: totalCtrl, label: 'Total', prefixText: r'$ ', isNumber: true),
                const SizedBox(height: 12),
                _EditField(controller: ownCtrl, label: 'Mi parte', prefixText: r'$ ', isNumber: true),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: FilledButton(
                    onPressed: () async {
                      final newTotal = parseFormattedAmount(totalCtrl.text);
                      final newOwn = parseFormattedAmount(ownCtrl.text);
                      final newOther = newTotal - newOwn;
                      if (newTotal <= 0 || newOwn < 0 || newOther < 0) return;
                      await ref.read(peopleServiceProvider).updateSharedExpense(
                        txId: tx.id, newTotal: newTotal, newOwn: newOwn, newOther: newOther,
                        description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.colorTransfer,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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

// ═════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═════════════════════════════════════════════════════════════════════════════

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final IconData? trailingIcon;

  const _Badge({required this.icon, required this.label, required this.color, this.trailingIcon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          if (trailingIcon != null) ...[
            const SizedBox(width: 4),
            Icon(trailingIcon, size: 10, color: color.withValues(alpha: 0.5)),
          ],
        ],
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? prefixText;
  final bool isNumber;

  const _EditField({required this.controller, required this.label, this.prefixText, this.isNumber = false});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber ? [ThousandsSeparatorFormatter()] : null,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        prefixStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.colorTransfer)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 12),
          Text('Sin transacciones todavía',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('Registrá un gasto compartido o una deuda',
              style: GoogleFonts.inter(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Avatar widget that shows Firebase photo for linked friends.
class _LinkedAvatar extends ConsumerWidget {
  final Person person;
  final double radius;
  const _LinkedAvatar({required this.person, this.radius = 36});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!person.isLinked) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: person.avatarColor.withValues(alpha: 0.2),
        child: Text(
          person.displayName[0].toUpperCase(),
          style: TextStyle(color: person.avatarColor, fontWeight: FontWeight.w800, fontSize: radius * 0.75),
        ),
      );
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: ref.read(firestoreServiceProvider).fetchUserDoc(person.linkedUserId!),
      builder: (context, snapshot) {
        final photoUrl = snapshot.data?['photoUrl'] as String?;
        return CircleAvatar(
          radius: radius,
          backgroundColor: person.avatarColor.withValues(alpha: 0.2),
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null
              ? Text(
                  person.displayName[0].toUpperCase(),
                  style: TextStyle(color: person.avatarColor, fontWeight: FontWeight.w800, fontSize: radius * 0.75),
                )
              : null,
        );
      },
    );
  }
}
