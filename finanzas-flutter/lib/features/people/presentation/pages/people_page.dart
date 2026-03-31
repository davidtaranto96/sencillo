import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/logic/people_service.dart';
import '../../domain/models/person.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/providers/mock_data_provider.dart';
import '../../../accounts/domain/models/account.dart' as dom_a;
import '../../../transactions/domain/models/transaction.dart' as dom_tx;
import 'add_expense_page.dart';

class PeoplePage extends ConsumerStatefulWidget {
  const PeoplePage({super.key});

  @override
  ConsumerState<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends ConsumerState<PeoplePage> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final peopleAsync = ref.watch(peopleStreamProvider);
    final globalBalance = ref.watch(globalPeopleBalanceProvider);
    final isPositive = globalBalance >= 0;

    return DefaultTabController(
      length: 3,
      initialIndex: 1, 
      child: peopleAsync.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
        data: (allPeople) {
          // Filtrar personas por búsqueda
          final query = _searchController.text.toLowerCase();
          final filteredPeople = allPeople.where((p) {
            final nameMatch = p.name.toLowerCase().contains(query) || 
                             (p.alias?.toLowerCase().contains(query) ?? false);
            // También buscamos en los nombres de las deudas (grupos/conceptos)
            final debtMatch = p.groupDebts.any((d) => d.groupName.toLowerCase().contains(query));
            return nameMatch || debtMatch;
          }).toList();

          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: _isSearching 
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => setState(() {
                      _isSearching = false;
                      _searchController.clear();
                    }),
                  )
                : const BackButton(color: Colors.white),
              title: _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nombre, grupo o gasto...',
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                  )
                : Text(
                    'Personas y Saldos',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
              actions: [
                if (!_isSearching)
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white70), 
                    onPressed: () => setState(() => _isSearching = true),
                  ),
                IconButton(
                  icon: const Icon(Icons.person_add_alt_1_outlined, color: Colors.white70), 
                  onPressed: () => _showAddPersonPlaceholder(context),
                ),
              ],
            ),
            body: Column(
              children: [
                if (!_isSearching)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isPositive 
                            ? 'En general, te deben ${formatAmount(globalBalance)}'
                            : 'En general, debés ${formatAmount(globalBalance.abs())}',
                          style: GoogleFonts.inter(
                            color: isPositive ? AppTheme.colorTransfer : AppTheme.colorExpense,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.tune_rounded, color: Colors.white70, size: 20),
                          onPressed: () => _showFilterPlaceholder(context),
                        ),
                      ],
                    ),
                  ),
                
                TabBar(
                  indicatorColor: AppTheme.colorTransfer,
                  labelColor: AppTheme.colorTransfer,
                  unselectedLabelColor: Colors.white38,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Grupos'),
                    Tab(text: 'Amigos'),
                    Tab(text: 'Actividad'),
                  ],
                ),

                Expanded(
                  child: TabBarView(
                    children: [
                      _buildGroupsTab(context, ref, query),
                      _buildFriendsTab(context, filteredPeople),
                      _buildActivityTab(context, ref),
                    ],
                  ),
                ),
              ],
            ),
            floatingActionButton: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 90),
              child: FloatingActionButton(
                onPressed: () => _showFabMenu(context),
                backgroundColor: AppTheme.colorTransfer,
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showFabMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        decoration: const BoxDecoration(
          color: Color(0xFF18181F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2)),
            ),
            _buildMenuOption(
              context, 
              icon: Icons.receipt_long_rounded, 
              color: AppTheme.colorTransfer,
              title: 'Añadir gasto repartido',
              subtitle: 'Dividí una cuenta con alguien',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AddExpensePage()));
              },
            ),
            const SizedBox(height: 12),
            _buildMenuOption(
              context, 
              icon: Icons.money_off_rounded, 
              color: AppTheme.colorExpense,
              title: 'Registrar deuda',
              subtitle: 'Anotá algo que debés o te deben',
              onTap: () {
                Navigator.pop(context);
                _showAddPersonPlaceholder(context); // Placeholder for now
              },
            ),
            const SizedBox(height: 12),
            _buildMenuOption(
              context, 
              icon: Icons.handshake_outlined, 
              color: AppTheme.colorIncome,
              title: 'Registrar pago / cobro',
              subtitle: 'Liquidar deudas pendientes',
              onTap: () {
                Navigator.pop(context);
                // Search for person to liquidate
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white12, size: 14),
          ],
        ),
      ),
    );
  }

  void _showAddPersonPlaceholder(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_add_alt_1_outlined, color: AppTheme.colorTransfer, size: 48),
            const SizedBox(height: 16),
            const Text('Añadir contacto', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            const TextField(decoration: InputDecoration(labelText: 'Email o nombre', hintText: 'ej. juan@gmail.com')),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.colorTransfer),
                child: const Text('Continuar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterPlaceholder(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D2E),
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Filtrar actividad', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListTile(title: const Text('Este mes'), leading: const Icon(Icons.calendar_today), onTap: () => Navigator.pop(context)),
          ListTile(title: const Text('Último año'), leading: const Icon(Icons.history), onTap: () => Navigator.pop(context)),
          ListTile(title: const Text('Solo deudas pendientes'), leading: const Icon(Icons.money_off), onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _buildFriendsTab(BuildContext context, List<Person> people) {
    if (people.isEmpty) {
      return const Center(child: Text('No se encontraron personas', style: TextStyle(color: Colors.white38)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      physics: const BouncingScrollPhysics(),
      itemCount: people.length,
      itemBuilder: (context, index) {
        final person = people[index];
        return _FriendListTile(person: person);
      },
    );
  }

  Widget _buildGroupsTab(BuildContext context, WidgetRef ref, String query) {
    final allGroups = ref.watch(mockGroupsProvider);
    final groups = allGroups.where((g) => g.name.toLowerCase().contains(query)).toList();

    if (groups.isEmpty) {
      return const Center(child: Text('No se encontraron grupos', style: TextStyle(color: Colors.white38)));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: groups.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final group = groups[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.colorTransfer.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.group_rounded, color: AppTheme.colorTransfer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const Text('Sin deudas pendientes', style: TextStyle(color: Colors.white38, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityTab(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsStreamProvider);

    return transactionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white))),
      data: (transactions) {
        final peopleTxs = transactions.where((t) => t.personId != null).toList();
        
        if (peopleTxs.isEmpty) {
          return const Center(
            child: Text('No hay actividad reciente', style: TextStyle(color: Colors.white38)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: peopleTxs.length,
          itemBuilder: (context, index) {
            final tx = peopleTxs[index];
            final isExpense = tx.type == dom_tx.TransactionType.expense;
            final color = isExpense ? AppTheme.colorExpense : AppTheme.colorIncome;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                   Container(
                     padding: const EdgeInsets.all(10),
                     decoration: BoxDecoration(
                       color: color.withValues(alpha: 0.1),
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: Icon(
                       tx.isShared == true ? Icons.group_outlined : Icons.person_outline,
                       color: color, size: 20,
                     ),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(tx.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                         Text(formatDate(tx.date), style: const TextStyle(color: Colors.white38, fontSize: 12)),
                       ],
                     ),
                   ),
                   Text(
                     '${isExpense ? '-' : '+'}${formatAmount(tx.amount)}',
                     style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w700, fontSize: 14),
                   ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _FriendListTile extends ConsumerWidget {
  final Person person;
  const _FriendListTile({required this.person});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPositive = person.totalBalance >= 0;
    final color = isPositive ? AppTheme.colorTransfer : AppTheme.colorExpense;
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0, locale: 'es_AR');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: person.avatarColor.withValues(alpha: 0.2),
                radius: 20,
                child: Text(
                  person.displayName[0].toUpperCase(),
                  style: TextStyle(color: person.avatarColor, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.displayName,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ...person.groupDebts.map((debt) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Container(width: 20, height: 1, color: Colors.white12),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 13, color: Colors.white54),
                                children: [
                                  TextSpan(text: person.displayName),
                                  TextSpan(text: debt.amount > 0 ? ' te debe ' : ' debés a '),
                                  TextSpan(
                                    text: fmt.format(debt.amount.abs()),
                                    style: TextStyle(
                                      color: debt.amount > 0 
                                          ? AppTheme.colorTransfer.withValues(alpha: 0.8) 
                                          : AppTheme.colorExpense.withValues(alpha: 0.8),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const TextSpan(text: ' para '),
                                  TextSpan(text: '"${debt.groupName}"', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isPositive ? 'te debe' : 'debés',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  Text(
                    fmt.format(person.totalBalance.abs()),
                    style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  if (person.totalBalance != 0)
                    TextButton(
                      onPressed: () => _showLiquidateDialog(context, ref, person),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        isPositive ? 'Me pagó' : 'Pagarle',
                        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white10, height: 1, indent: 76),
      ],
    );
  }

  void _showLiquidateDialog(BuildContext context, WidgetRef ref, Person person) {
    final accounts = ref.read(accountsStreamProvider).value ?? [];
    final sources = accounts.where((a) => !a.isCreditCard).toList();
    dom_a.Account? selectedSource = sources.isNotEmpty ? sources.first : null;
    final amountController = TextEditingController(text: person.totalBalance.abs().toStringAsFixed(0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32),
          decoration: const BoxDecoration(
            color: Color(0xFF18181F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Liquidar con ${person.displayName}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButton<dom_a.Account>(
                value: selectedSource,
                dropdownColor: const Color(0xFF1E1E2C),
                isExpanded: true,
                style: const TextStyle(color: Colors.white),
                items: sources.map((s) => DropdownMenuItem(value: s, child: Text('${s.name} (${formatAmount(s.balance)})'))).toList(),
                onChanged: (val) => setState(() => selectedSource = val),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 24),
                decoration: const InputDecoration(prefixText: '\$ ', labelText: 'Monto a liquidar', labelStyle: TextStyle(color: AppTheme.colorTransfer)),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: selectedSource == null ? null : () async {
                    final amount = double.tryParse(amountController.text) ?? 0;
                    final actualAmount = person.totalBalance > 0 ? amount : -amount;
                    
                    await ref.read(peopleServiceProvider).liquidateDebt(
                      personId: person.id,
                      amount: actualAmount,
                      accountId: selectedSource!.id,
                    );
                    if (context.mounted) Navigator.pop(ctx);
                  },
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.colorTransfer),
                  child: const Text('Confirmar Liquidación'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
