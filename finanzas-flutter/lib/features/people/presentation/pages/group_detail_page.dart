import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/logic/people_service.dart';
import '../../../../core/utils/format_utils.dart';
import '../../domain/models/group.dart';
import 'add_expense_page.dart';
import 'people_page.dart';

class GroupDetailPage extends ConsumerWidget {
  final ExpenseGroup group;
  const GroupDetailPage({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Re-watch for live updates
    final groupsAsync = ref.watch(groupsStreamProvider);
    final liveGroup = groupsAsync.valueOrNull
            ?.where((g) => g.id == group.id)
            .firstOrNull ??
        group;
    final txsAsync = ref.watch(groupTransactionsProvider(group.id));

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
                icon:
                    const Icon(Icons.more_vert_rounded, color: Colors.white54),
                color: const Color(0xFF1E1E2C),
                onSelected: (val) {
                  if (val == 'edit') _showEditSheet(context, ref, liveGroup);
                  if (val == 'members') _showMembersSheet(context, ref, liveGroup);
                  if (val == 'delete') _confirmDelete(context, ref);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                      value: 'edit',
                      child:
                          Text('Editar nombre', style: TextStyle(color: Colors.white))),
                  const PopupMenuItem(
                      value: 'members',
                      child: Text('Gestionar miembros',
                          style: TextStyle(color: Colors.white))),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Text('Eliminar grupo',
                          style: TextStyle(color: AppTheme.colorExpense))),
                ],
              ),
            ],
          ),

          // ── Header ──
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Group icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.colorTransfer.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(Icons.group_rounded,
                      color: AppTheme.colorTransfer, size: 36),
                ),
                const SizedBox(height: 12),
                Text(liveGroup.name,
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  '${liveGroup.members.length} miembro${liveGroup.members.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.white38, fontSize: 14),
                ),
                if (liveGroup.hasDates) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.date_range_rounded,
                          color: AppTheme.colorTransfer.withValues(alpha: 0.5),
                          size: 14),
                      const SizedBox(width: 6),
                      Text(
                        _formatDateRange(liveGroup.startDate, liveGroup.endDate),
                        style: TextStyle(
                            color: AppTheme.colorTransfer.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),

                // Total expense card
                if (liveGroup.totalGroupExpense > 0)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color:
                          AppTheme.colorTransfer.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppTheme.colorTransfer
                              .withValues(alpha: 0.12)),
                    ),
                    child: Column(
                      children: [
                        const Text('Total del grupo',
                            style: TextStyle(
                                color: AppTheme.colorTransfer,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(
                          formatAmount(liveGroup.totalGroupExpense),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Action button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AddExpensePage(preselectedGroupId: group.id),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color:
                            AppTheme.colorTransfer.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppTheme.colorTransfer
                                .withValues(alpha: 0.15)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded,
                              color: AppTheme.colorTransfer, size: 18),
                          SizedBox(width: 8),
                          Text('Agregar gasto',
                              style: TextStyle(
                                  color: AppTheme.colorTransfer,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // ── Members ──
          if (liveGroup.members.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text('MIEMBROS',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3)),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: liveGroup.members.length,
                  itemBuilder: (context, index) {
                    final m = liveGroup.members[index];
                    final bal = m.totalBalance;
                    final color = bal > 0
                        ? AppTheme.colorIncome
                        : bal < 0
                            ? AppTheme.colorExpense
                            : Colors.white38;
                    return Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2C).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor:
                                m.avatarColor.withValues(alpha: 0.2),
                            child: Text(m.displayName[0].toUpperCase(),
                                style: TextStyle(
                                    color: m.avatarColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: 4),
                          Text(m.displayName,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          if (bal != 0)
                            Text(formatAmount(bal.abs(), compact: true),
                                style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],

          // ── Transactions ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('GASTOS',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3)),
            ),
          ),

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
                        const Text('Sin gastos en este grupo',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 14)),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final tx = txs[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E2C)
                              .withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.colorTransfer
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(Icons.call_split_rounded,
                                  color: AppTheme.colorTransfer, size: 18),
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
                                    DateFormat('d MMM yyyy', 'es')
                                        .format(tx.date),
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              formatAmount(tx.amount),
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    },
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

  String _formatDateRange(DateTime? start, DateTime? end) {
    final fmt = DateFormat('d MMM yyyy', 'es');
    if (start != null && end != null) {
      return '${fmt.format(start)} – ${fmt.format(end)}';
    } else if (start != null) {
      return 'Desde ${fmt.format(start)}';
    } else if (end != null) {
      return 'Hasta ${fmt.format(end)}';
    }
    return '';
  }

  void _showEditSheet(
      BuildContext context, WidgetRef ref, ExpenseGroup g) {
    final nameCtrl = TextEditingController(text: g.name);
    DateTime? startDate = g.startDate;
    DateTime? endDate = g.endDate;

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
                Text('Editar grupo',
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
                    labelStyle:
                        const TextStyle(color: AppTheme.colorTransfer),
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
                Text('Periodo / viaje',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _DatePickerTile(
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
                          if (picked != null) {
                            setState(() => startDate = picked);
                          }
                        },
                        onClear: () => setState(() => startDate = null),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DatePickerTile(
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
                          if (picked != null) {
                            setState(() => endDate = picked);
                          }
                        },
                        onClear: () => setState(() => endDate = null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      await ref.read(peopleServiceProvider).updateGroup(
                        groupId: g.id,
                        name: name,
                        startDate: startDate,
                        endDate: endDate,
                        clearStartDate:
                            startDate == null && g.startDate != null,
                        clearEndDate: endDate == null && g.endDate != null,
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

  void _showMembersSheet(
      BuildContext context, WidgetRef ref, ExpenseGroup g) {
    final allPeople = ref.read(peopleStreamProvider).valueOrNull ?? [];
    final currentMemberIds = g.members.map((m) => m.id).toSet();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final memberIds = Set<String>.from(currentMemberIds);
          return Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.7),
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
                Text('Miembros de ${g.name}',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Tocá para agregar o quitar',
                    style: TextStyle(color: Colors.white38, fontSize: 13)),
                const SizedBox(height: 16),
                if (allPeople.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('Primero agregá amigos',
                          style: TextStyle(color: Colors.white38)),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allPeople.map((p) {
                      final isSelected = memberIds.contains(p.id);
                      return GestureDetector(
                        onTap: () async {
                          if (isSelected) {
                            await ref
                                .read(peopleServiceProvider)
                                .removeMemberFromGroup(g.id, p.id);
                            setState(() => memberIds.remove(p.id));
                          } else {
                            await ref
                                .read(peopleServiceProvider)
                                .addMemberToGroup(g.id, p.id);
                            setState(() => memberIds.add(p.id));
                          }
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
                                          ? AppTheme.colorTransfer
                                          : Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                              if (isSelected) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.check_circle_rounded,
                                    color: AppTheme.colorTransfer, size: 16),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    showAddPersonSheet(context, ref);
                  },
                  icon: const Icon(Icons.person_add_rounded, size: 16),
                  label: const Text('Agregar nuevo amigo'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppTheme.colorTransfer),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('Eliminar grupo',
            style: TextStyle(color: Colors.white)),
        content: Text(
            '¿Eliminar "${group.name}"? Las transacciones se mantendrán.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(peopleServiceProvider).deleteGroup(group.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) Navigator.pop(context);
            },
            style:
                FilledButton.styleFrom(backgroundColor: AppTheme.colorExpense),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _DatePickerTile({
    required this.label,
    required this.date,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
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
                    ? DateFormat('d MMM', 'es').format(date!)
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
                child: Icon(Icons.close_rounded,
                    color: Colors.white24, size: 14),
              ),
          ],
        ),
      ),
    );
  }
}
