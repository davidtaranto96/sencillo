import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/person.dart';
import '../providers/people_provider.dart';

class PeoplePage extends ConsumerWidget {
  const PeoplePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allPeople = ref.watch(mockPeopleProvider);
    final globalBalance = ref.watch(globalPeopleBalanceProvider);
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2, locale: 'en_US');
    final isPositive = globalBalance >= 0;
    final cs = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 3,
      initialIndex: 1, 
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: Colors.white),
          title: Text(
            'Personas y Saldos',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white70), 
              onPressed: () => _showSearchPlaceholder(context),
            ),
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_outlined, color: Colors.white70), 
              onPressed: () => _showAddPersonPlaceholder(context),
            ),
          ],
        ),
        body: Column(
          children: [
            // Resumen de Saldo Global (AstroPay style)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isPositive 
                      ? 'En general, te deben ${fmt.format(globalBalance)}'
                      : 'En general, debés ${fmt.format(globalBalance.abs())}',
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

            // TabBar (AstroPay style indicator)
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
                  _buildGroupsTab(context, ref),
                  _buildFriendsTab(context, allPeople),
                  _buildActivityTab(context),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          backgroundColor: AppTheme.colorTransfer,
          child: const Icon(Icons.receipt_long_rounded, color: Colors.white),
        ),
      ),
    );
  }

  void _showSearchPlaceholder(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Buscando personas... (Simulado)')),
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
            TextField(decoration: InputDecoration(labelText: 'Email o nombre', hintText: 'ej. juan@gmail.com')),
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

  Widget _buildGroupsTab(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(mockGroupsProvider);
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

  Widget _buildActivityTab(BuildContext context) {
    return const Center(
      child: Text('No hay actividad reciente', style: TextStyle(color: Colors.white38)),
    );
  }
}

class _FriendListTile extends StatelessWidget {
  final Person person;
  const _FriendListTile({required this.person});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2, locale: 'en_US');
    final isPositive = person.owesMe;
    final color = isPositive ? AppTheme.colorTransfer : AppTheme.colorExpense;

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
                ],
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white10, height: 1, indent: 76),
      ],
    );
  }
}
