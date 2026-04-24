import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/feedback_provider.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/logic/people_service.dart';
import '../../../../core/providers/friend_requests_provider.dart';
import '../../../../core/providers/incoming_expenses_provider.dart';
import '../../../../core/services/firestore_service.dart';
import '../../domain/models/person.dart';
import '../../domain/models/group.dart';
import '../../../../core/utils/format_utils.dart';

import '../../../accounts/domain/models/account.dart' as dom_a;
import '../../../transactions/domain/models/transaction.dart' as dom_tx;
import '../../../transactions/presentation/pages/transaction_detail_page.dart';
import 'add_expense_page.dart';
import 'person_detail_page.dart';
import 'group_detail_page.dart';
import '../../../../shared/widgets/empty_state.dart';

class PeoplePage extends ConsumerStatefulWidget {
  /// [standalone] = true when pushed on top of the shell (from Más, router).
  /// In standalone mode the page shows its own FAB and back button.
  final bool standalone;
  const PeoplePage({super.key, this.standalone = false});

  @override
  ConsumerState<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends ConsumerState<PeoplePage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final peopleAsync = ref.watch(peopleStreamProvider);
    final globalBalance = ref.watch(globalPeopleBalanceProvider);

    return Scaffold(
      // FAB only when standalone (pushed on top of shell). When in nav bar the
      // shell's MorphingFab handles it with proper positioning + animation.
      floatingActionButton: widget.standalone
          ? FloatingActionButton(
              onPressed: () => showPeopleFabMenu(context, ref),
              backgroundColor: AppTheme.colorTransfer,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ──
            _Header(globalBalance: globalBalance, showBack: widget.standalone),

            // ── Social banners ──
            _SocialBanners(),

            // ── Tabs ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppTheme.colorTransfer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                dividerHeight: 0,
                labelColor: AppTheme.colorTransfer,
                unselectedLabelColor: Colors.white38,
                labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [
                  Tab(text: 'Grupos', height: 40),
                  Tab(text: 'Amigos', height: 40),
                  Tab(text: 'Actividad', height: 40),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Content ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _GroupsTab(),
                  peopleAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                        child: Text('Error: $e',
                            style: const TextStyle(color: Colors.white))),
                    data: (people) => _FriendsTab(people: people),
                  ),
                  _ActivityTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      // FAB is rendered by AppShell's MorphingFab
    );
  }

}

/// Top-level so the shell's MorphingFab can call it too.
void showPeopleFabMenu(BuildContext context, WidgetRef ref) {
    appHaptic(ref, type: HapticType.medium);
    appSound(ref, type: SoundType.tap);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        decoration: const BoxDecoration(
          color: Color(0xFF18181F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(2)),
            ),
            _MenuOption(
              icon: Icons.receipt_long_rounded,
              color: AppTheme.colorTransfer,
              title: 'Gasto compartido',
              subtitle: 'Dividí una cuenta con alguien',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AddExpensePage()));
              },
            ),
            const SizedBox(height: 10),
            _MenuOption(
              icon: Icons.money_off_rounded,
              color: AppTheme.colorExpense,
              title: 'Registrar deuda',
              subtitle: 'Prestaste o te prestaron plata',
              onTap: () {
                Navigator.pop(context);
                _showRecordDebtSheet(context, ref);
              },
            ),
            const SizedBox(height: 10),
            _MenuOption(
              icon: Icons.handshake_outlined,
              color: AppTheme.colorIncome,
              title: 'Liquidar deuda',
              subtitle: 'Pagá o cobrá deudas pendientes',
              onTap: () {
                Navigator.pop(context);
                _showLiquidateSheet(context, ref);
              },
            ),
            const SizedBox(height: 10),
            _MenuOption(
              icon: Icons.qr_code_scanner_rounded,
              color: const Color(0xFF5ECFB1),
              title: 'Escanear QR de amigo',
              subtitle: 'Escaneá el código de tu amigo',
              onTap: () {
                Navigator.pop(context);
                context.push('/link-friend');
              },
            ),
            const SizedBox(height: 10),
            _MenuOption(
              icon: Icons.person_add_rounded,
              color: Colors.white54,
              title: 'Agregar manualmente',
              subtitle: 'Nuevo contacto sin vincular',
              onTap: () {
                Navigator.pop(context);
                showAddPersonSheet(context, ref);
              },
            ),
            const SizedBox(height: 10),
            _MenuOption(
              icon: Icons.group_add_rounded,
              color: Colors.white54,
              title: 'Crear grupo',
              subtitle: 'Viaje, casa, evento...',
              onTap: () {
                Navigator.pop(context);
                showCreateGroupSheet(context, ref);
              },
            ),
          ],
        ),
      ),
      ),
    );
  }

void _showRecordDebtSheet(BuildContext context, WidgetRef ref) {
    final people = ref.read(peopleStreamProvider).valueOrNull ?? [];
    if (people.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero agregá un amigo')),
      );
      return;
    }
    final accounts =
        ref.read(accountsStreamProvider).valueOrNull ?? [];
    final sources = accounts.toList();

    Person? selected;
    bool iLent = true;
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    dom_a.Account? selectedAccount = sources.isNotEmpty ? sources.first : null;

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
                Text('Registrar deuda',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),

                // Person selector
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: people.map((p) {
                    final isSelected = selected?.id == p.id;
                    return GestureDetector(
                      onTap: () => setState(() => selected = p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.colorTransfer.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.colorTransfer.withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Text(p.displayName,
                            style: TextStyle(
                                color: isSelected
                                    ? AppTheme.colorTransfer
                                    : Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Direction toggle
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => iLent = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: iLent
                                ? AppTheme.colorIncome.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text('Le presté',
                                style: TextStyle(
                                    color: iLent
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
                        onTap: () => setState(() => iLent = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !iLent
                                ? AppTheme.colorExpense.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text('Me prestó',
                                style: TextStyle(
                                    color: !iLent
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
                  style:
                      const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    prefixText: '\$ ',
                    prefixStyle: TextStyle(color: Colors.white24, fontSize: 24),
                    hintText: '0',
                    hintStyle: TextStyle(color: Colors.white12),
                    border: InputBorder.none,
                  ),
                ),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Descripción (opcional)',
                    hintStyle: TextStyle(color: Colors.white24),
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 12),

                // Account
                if (sources.isNotEmpty)
                  DropdownButton<dom_a.Account>(
                    value: selectedAccount,
                    dropdownColor: const Color(0xFF1E1E2C),
                    isExpanded: true,
                    style: const TextStyle(color: Colors.white),
                    items: sources
                        .map((s) => DropdownMenuItem(
                            value: s,
                            child:
                                Text('${s.name} (${formatAmount(s.balance)})')))
                        .toList(),
                    onChanged: (val) => setState(() => selectedAccount = val),
                  ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: selected == null || selectedAccount == null
                        ? null
                        : () async {
                            final amount = parseFormattedAmount(amountCtrl.text);
                            if (amount <= 0) return;
                            await ref.read(peopleServiceProvider).recordDirectDebt(
                              personId: selected!.id,
                              amount: amount,
                              iLent: iLent,
                              description: descCtrl.text.isNotEmpty
                                  ? descCtrl.text
                                  : (iLent ? 'Préstamo' : 'Deuda'),
                              accountId: selectedAccount?.id,
                            );
                            if (context.mounted) Navigator.pop(ctx);
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.colorTransfer,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Registrar',
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

void _showLiquidateSheet(BuildContext context, WidgetRef ref) {
    final people = ref.read(peopleStreamProvider).valueOrNull ?? [];
    final withBalance = people.where((p) => p.totalBalance != 0).toList();
    if (withBalance.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay deudas pendientes')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        decoration: const BoxDecoration(
          color: Color(0xFF18181F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
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
            Text('Liquidar deuda',
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Elegí a quién pagarle o cobrarle',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
            const SizedBox(height: 16),
            ...withBalance.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _showLiquidateAmountSheet(context, ref, p);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              p.avatarColor.withValues(alpha: 0.2),
                          child: Text(p.displayName[0].toUpperCase(),
                              style: TextStyle(
                                  color: p.avatarColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(p.displayName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ),
                        Text(
                          p.totalBalance > 0
                              ? 'Te debe ${formatAmount(p.totalBalance)}'
                              : 'Le debés ${formatAmount(p.totalBalance.abs())}',
                          style: TextStyle(
                            color: p.totalBalance > 0
                                ? AppTheme.colorIncome
                                : AppTheme.colorExpense,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

void _showLiquidateAmountSheet(BuildContext context, WidgetRef ref, Person person) {
    final accounts = ref.read(accountsStreamProvider).value ?? [];
    final sources = accounts.toList();
    dom_a.Account? selectedSource; // null = sin cuenta
    final amountController =
        TextEditingController(text: formatInitialAmount(person.totalBalance.abs()));

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
                  person.totalBalance > 0
                      ? '${person.displayName} te paga'
                      : 'Le pagás a ${person.displayName}',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
                if (sources.isNotEmpty) ...[
                  const SizedBox(height: 16),
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
                          child:
                              Text('${s.name} (${formatAmount(s.balance)})'))),
                    ],
                    onChanged: (val) => setState(() => selectedSource = val),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsSeparatorFormatter()],
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    prefixText: '\$ ',
                    prefixStyle: TextStyle(color: Colors.white24, fontSize: 24),
                    labelText: 'Monto a liquidar',
                    labelStyle: TextStyle(color: AppTheme.colorTransfer),
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
                                parseFormattedAmount(amountController.text);
                            if (amount <= 0) return;
                            final actualAmount = person.totalBalance > 0
                                ? amount
                                : -amount;
                            await ref.read(peopleServiceProvider).liquidateDebt(
                              personId: person.id,
                              amount: actualAmount,
                              accountId: selectedSource?.id,
                            );

                            // Notificar al amigo vinculado
                            if (person.isLinked) {
                              try {
                                final firestoreService = ref.read(firestoreServiceProvider);
                                await firestoreService.createDebtSettlement(
                                  friendUid: person.linkedUserId!,
                                  amount: actualAmount,
                                  description: actualAmount > 0
                                      ? '${person.displayName} te pagó'
                                      : 'Pago a ${person.displayName}',
                                );
                              } catch (_) {}
                            }

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

// ─── Social Banners (solicitudes + gastos entrantes) ──

class _SocialBanners extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestCount = ref.watch(friendRequestCountProvider).valueOrNull ?? 0;
    final incomingExpenses = ref.watch(incomingSharedExpensesProvider).valueOrNull ?? [];

    if (requestCount == 0 && incomingExpenses.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        children: [
          // ── Solicitudes de amistad pendientes ──
          if (requestCount > 0)
            GestureDetector(
              onTap: () => context.push('/friend-requests'),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$requestCount',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF9B96FF)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        requestCount == 1
                            ? '1 solicitud de amistad pendiente'
                            : '$requestCount solicitudes de amistad',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF9B96FF)),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF9B96FF)),
                  ],
                ),
              ),
            ),

          // ── Gastos compartidos entrantes ──
          ...incomingExpenses.map((exp) => _IncomingExpenseBanner(expense: exp)),
        ],
      ),
    );
  }
}

class _IncomingExpenseBanner extends ConsumerStatefulWidget {
  final IncomingSharedExpense expense;
  const _IncomingExpenseBanner({required this.expense});

  @override
  ConsumerState<_IncomingExpenseBanner> createState() => _IncomingExpenseBannerState();
}

class _IncomingExpenseBannerState extends ConsumerState<_IncomingExpenseBanner> {
  bool _loading = false;

  Future<void> _accept() async {
    setState(() => _loading = true);
    try {
      final peopleService = ref.read(peopleServiceProvider);

      // Buscar/crear persona localmente
      final people = ref.read(peopleStreamProvider).valueOrNull ?? [];
      String personId;
      final match = people.where((p) => p.linkedUserId == widget.expense.createdByUid).toList();

      if (match.isNotEmpty) {
        personId = match.first.id;
      } else {
        // Buscar nombre real del sender en Firestore
        String senderName = 'Amigo';
        try {
          final firestoreService = ref.read(firestoreServiceProvider);
          final userDoc = await firestoreService.fetchUserDoc(widget.expense.createdByUid);
          senderName = userDoc?['displayName'] as String? ?? 'Amigo';
        } catch (_) {}
        personId = await peopleService.addPerson(name: senderName);
        await peopleService.setLinkedUser(personId, widget.expense.createdByUid);
      }

      // Crear transacción local de gasto compartido
      final localTxId = await peopleService.addSharedExpenseFromIncoming(
        personId: personId,
        title: widget.expense.title,
        totalAmount: widget.expense.totalAmount,
        ownAmount: widget.expense.myAmount,
        otherAmount: widget.expense.totalAmount - widget.expense.myAmount,
        date: widget.expense.date,
        categoryId: widget.expense.category,
        iOwe: true, // el amigo pagó, yo debo mi parte
      );

      // Actualizar Firestore
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.acceptSharedExpense(widget.expense.docId, localTxId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gasto "${widget.expense.title}" aceptado')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al aceptar el gasto')),
        );
      }
    }
  }

  Future<void> _decline() async {
    final firestoreService = ref.read(firestoreServiceProvider);
    await firestoreService.declineSharedExpense(widget.expense.docId);
  }

  @override
  Widget build(BuildContext context) {
    final exp = widget.expense;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.colorTransfer.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.colorTransfer.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💸', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Gasto compartido: ${exp.title}',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              Text(
                formatAmount(exp.myAmount),
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.colorTransfer),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tu parte: ${formatAmount(exp.myAmount)} de ${formatAmount(exp.totalAmount)} total',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: _decline,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Ignorar', style: GoogleFonts.inter(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _accept,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTheme.colorTransfer.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Aceptar', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.colorTransfer, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────

class _Header extends StatelessWidget {
  final double globalBalance;
  final bool showBack;
  const _Header({required this.globalBalance, this.showBack = false});

  @override
  Widget build(BuildContext context) {
    final isPositive = globalBalance >= 0;
    final isZero = globalBalance == 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showBack) ...[
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white54, size: 20),
                ),
                const SizedBox(width: 8),
              ],
              Text('Amigos',
                  style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ],
          ),
          const SizedBox(height: 4),
          if (isZero)
            const Text('Estás al día con todos',
                style: TextStyle(color: Colors.white38, fontSize: 14))
          else
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isPositive
                        ? AppTheme.colorIncome
                        : AppTheme.colorExpense,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isPositive
                      ? 'Te deben ${formatAmount(globalBalance)}'
                      : 'Debés ${formatAmount(globalBalance.abs())}',
                  style: TextStyle(
                    color: isPositive
                        ? AppTheme.colorIncome
                        : AppTheme.colorExpense,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Friends Tab ──────────────────────────────────────

class _FriendsTab extends ConsumerWidget {
  final List<Person> people;
  const _FriendsTab({required this.people});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (people.isEmpty) {
      return EmptyState(
        variant: EmptyStateVariant.full,
        icon: Icons.people_outline_rounded,
        title: 'Dividí gastos con amigos',
        description: 'Agregá personas y la app calcula quién debe cuánto, sin discusiones.',
        ctaLabel: 'Agregar amigo',
        ctaIcon: Icons.person_add_rounded,
        onCta: () => showAddPersonSheet(context, ref),
        extraContent: const EmptyStateExampleChip(
          text: 'Cena \$12.000 ÷ 3 = \$4.000 c/u',
        ),
      );
    }

    // Sort: with balance first, then alphabetical
    final sorted = List<Person>.from(people)
      ..sort((a, b) {
        if (a.totalBalance != 0 && b.totalBalance == 0) return -1;
        if (a.totalBalance == 0 && b.totalBalance != 0) return 1;
        return a.displayName.compareTo(b.displayName);
      });

    final bottomPad = 70 + MediaQuery.of(context).padding.bottom + 24;
    return ListView.builder(
      padding: EdgeInsets.only(top: 4, bottom: bottomPad),
      physics: const BouncingScrollPhysics(),
      itemCount: sorted.length,
      itemBuilder: (context, index) =>
          _FriendCard(person: sorted[index]),
    );
  }
}

class _FriendCard extends StatelessWidget {
  final Person person;
  const _FriendCard({required this.person});

  @override
  Widget build(BuildContext context) {
    final isPositive = person.totalBalance > 0;
    final isZero = person.totalBalance == 0;
    final color = isZero
        ? Colors.white38
        : isPositive
            ? AppTheme.colorIncome
            : AppTheme.colorExpense;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PersonDetailPage(person: person)),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: person.avatarColor.withValues(alpha: 0.2),
              child: Text(
                person.displayName[0].toUpperCase(),
                style: TextStyle(
                    color: person.avatarColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
            ),
            const SizedBox(width: 14),

            // Name + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.displayName,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isZero
                        ? 'Al día'
                        : isPositive
                            ? 'te debe'
                            : 'le debés',
                    style: TextStyle(color: color, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Amount
            if (!isZero)
              Text(
                formatAmount(person.totalBalance.abs()),
                style: GoogleFonts.inter(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            if (isZero)
              Icon(Icons.check_circle_rounded,
                  color: Colors.white.withValues(alpha: 0.15), size: 20),

            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.15), size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Groups Tab ──────────────────────────────────────

class _GroupsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsStreamProvider);

    return groupsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: Colors.white))),
      data: (groups) {
        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.group_outlined,
                    size: 48, color: Colors.white.withValues(alpha: 0.15)),
                const SizedBox(height: 12),
                const Text('Sin grupos',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                const Text('Creá grupos para viajes, casa, eventos...',
                    style: TextStyle(color: Colors.white24, fontSize: 13)),
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () => showCreateGroupSheet(context, ref),
                  icon: const Icon(Icons.group_add_rounded, size: 18),
                  label: const Text('Crear grupo'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppTheme.colorTransfer),
                ),
              ],
            ),
          );
        }

        final bottomPad = 70 + MediaQuery.of(context).padding.bottom + 24;
        return ListView.builder(
          padding: EdgeInsets.only(top: 4, bottom: bottomPad),
          physics: const BouncingScrollPhysics(),
          itemCount: groups.length,
          itemBuilder: (context, index) =>
              _GroupCard(group: groups[index]),
        );
      },
    );
  }
}

class _GroupCard extends StatelessWidget {
  final ExpenseGroup group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final memberCount = group.members.length;
    final hasExpenses = group.totalGroupExpense > 0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => GroupDetailPage(group: group)),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2C).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Row(
          children: [
            // Group icon
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.colorTransfer.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.group_rounded,
                  color: AppTheme.colorTransfer, size: 22),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name,
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    memberCount == 0
                        ? 'Sin miembros'
                        : '$memberCount miembro${memberCount == 1 ? '' : 's'}',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),

            if (hasExpenses)
              Text(
                formatAmount(group.totalGroupExpense),
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.15), size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Activity Tab ────────────────────────────────────

class _ActivityTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsStreamProvider);

    return transactionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: Colors.white))),
      data: (transactions) {
        final peopleTxs =
            transactions.where((t) => t.personId != null).toList()
              ..sort((a, b) => b.date.compareTo(a.date));

        if (peopleTxs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 48, color: Colors.white.withValues(alpha: 0.15)),
                const SizedBox(height: 12),
                const Text('Sin actividad',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                const Text('Las transacciones compartidas aparecerán acá',
                    style: TextStyle(color: Colors.white24, fontSize: 13)),
              ],
            ),
          );
        }

        // Group by date
        final grouped = <String, List<dom_tx.Transaction>>{};
        for (final tx in peopleTxs) {
          final key = _dateGroupKey(tx.date);
          grouped.putIfAbsent(key, () => []).add(tx);
        }

        final bottomPad = 70 + MediaQuery.of(context).padding.bottom + 24;
        return ListView.builder(
          padding: EdgeInsets.only(top: 4, bottom: bottomPad),
          physics: const BouncingScrollPhysics(),
          itemCount: grouped.length,
          itemBuilder: (context, index) {
            final key = grouped.keys.elementAt(index);
            final txs = grouped[key]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Text(key,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3)),
                ),
                ...txs.map((tx) => _ActivityRow(tx: tx)),
              ],
            );
          },
        );
      },
    );
  }

  static String _dateGroupKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final txDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(txDay).inDays;

    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    if (diff < 7) return 'Esta semana';
    if (date.month == now.month && date.year == now.year) return 'Este mes';
    return DateFormat('MMMM yyyy', 'es').format(date);
  }
}

class _ActivityRow extends ConsumerWidget {
  final dom_tx.Transaction tx;
  const _ActivityRow({required this.tx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpense = tx.type == dom_tx.TransactionType.expense;
    final isLoanGiven = tx.type == dom_tx.TransactionType.loanGiven;
    final isIncome = tx.type == dom_tx.TransactionType.income;

    Color color;
    IconData icon;
    String subtitle;

    if (tx.isShared) {
      color = AppTheme.colorTransfer;
      icon = Icons.call_split_rounded;
      subtitle = 'Gasto compartido';
    } else if (isLoanGiven) {
      color = AppTheme.colorWarning;
      icon = Icons.arrow_upward_rounded;
      subtitle = 'Préstamo dado';
    } else if (isIncome) {
      color = AppTheme.colorIncome;
      icon = Icons.arrow_downward_rounded;
      subtitle = 'Liquidación';
    } else {
      color = AppTheme.colorExpense;
      icon = Icons.arrow_downward_rounded;
      subtitle = isExpense ? 'Deuda' : 'Cobro';
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TransactionDetailPage(txId: tx.id)),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
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
                  Text(subtitle,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            Text(
              '${isExpense || isLoanGiven ? '-' : '+'}${formatAmount(tx.amount)}',
              style: GoogleFonts.inter(
                  color: color, fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Menu Option ─────────────────────────────────────

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(subtitle,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white12, size: 12),
          ],
        ),
      ),
    );
  }
}

// ─── Shared Bottom Sheets ────────────────────────────

void showAddPersonSheet(BuildContext context, WidgetRef ref) {
  final nameCtrl = TextEditingController();
  final aliasCtrl = TextEditingController();
  final cbuCtrl = TextEditingController();

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
            Text('Agregar amigo',
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Nombre',
                labelStyle: const TextStyle(color: AppTheme.colorTransfer),
                hintText: 'ej. Juan Pérez',
                hintStyle: const TextStyle(color: Colors.white24),
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
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: aliasCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Apodo (opcional)',
                labelStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                hintText: 'ej. Juani',
                hintStyle: const TextStyle(color: Colors.white24),
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
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cbuCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'CBU / CVU / Alias (opcional)',
                labelStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                hintText: 'Para pagos bancarios',
                hintStyle: const TextStyle(color: Colors.white24),
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
              ),
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
                  await ref.read(peopleServiceProvider).addPerson(
                    name: name,
                    alias: alias.isEmpty ? null : alias,
                    cbu: cbu.isEmpty ? null : cbu,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.colorTransfer,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Agregar',
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

void showCreateGroupSheet(BuildContext context, WidgetRef ref) {
  final nameCtrl = TextEditingController();
  final people = ref.read(peopleStreamProvider).valueOrNull ?? [];
  final selectedIds = <String>{};
  DateTime? startDate;
  DateTime? endDate;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) => Container(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 40),
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
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
              Text('Crear grupo',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Nombre del grupo',
                  labelStyle: const TextStyle(color: AppTheme.colorTransfer),
                  hintText: 'ej. Viaje a Bariloche',
                  hintStyle: const TextStyle(color: Colors.white24),
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
              const SizedBox(height: 16),
              // Date pickers
              Text('Periodo / viaje (opcional)',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildDateTile(
                      context: context,
                      label: 'Inicio',
                      date: startDate,
                      onPick: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                  primary: AppTheme.colorTransfer,
                                  surface: Color(0xFF1E1E2C)),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) setState(() => startDate = picked);
                      },
                      onClear: () => setState(() => startDate = null),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDateTile(
                      context: context,
                      label: 'Fin',
                      date: endDate,
                      onPick: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              endDate ?? startDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                  primary: AppTheme.colorTransfer,
                                  surface: Color(0xFF1E1E2C)),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) setState(() => endDate = picked);
                      },
                      onClear: () => setState(() => endDate = null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (people.isNotEmpty) ...[
                const Text('Miembros',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: people.map((p) {
                    final isSelected = selectedIds.contains(p.id);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            selectedIds.remove(p.id);
                          } else {
                            selectedIds.add(p.id);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.colorTransfer
                                  .withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.colorTransfer
                                    .withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Icon(Icons.check_circle_rounded,
                                    color: AppTheme.colorTransfer, size: 16),
                              ),
                            Text(p.displayName,
                                style: TextStyle(
                                    color: isSelected
                                        ? AppTheme.colorTransfer
                                        : Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    await ref.read(peopleServiceProvider).addGroup(
                      name: name,
                      memberIds: selectedIds.toList(),
                      startDate: startDate,
                      endDate: endDate,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.colorTransfer,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Crear grupo',
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

Widget _buildDateTile({
  required BuildContext context,
  required String label,
  required DateTime? date,
  required VoidCallback onPick,
  required VoidCallback onClear,
}) {
  return GestureDetector(
    onTap: onPick,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: date != null
            ? AppTheme.colorTransfer.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: date != null
              ? AppTheme.colorTransfer.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_rounded,
              color: date != null
                  ? AppTheme.colorTransfer.withValues(alpha: 0.6)
                  : Colors.white24,
              size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              date != null
                  ? DateFormat('d MMM', 'es').format(date)
                  : label,
              style: TextStyle(
                color: date != null ? Colors.white : Colors.white38,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (date != null)
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close_rounded, color: Colors.white24, size: 14),
            ),
        ],
      ),
    ),
  );
}
