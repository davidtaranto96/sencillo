import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../transactions/domain/models/transaction.dart' as dom_tx;
import 'daily_spending_message.dart';

enum _SpendingPeriod { today, week, month }

class DailySpendingCard extends StatefulWidget {
  final List<dom_tx.Transaction> transactions;

  const DailySpendingCard({super.key, required this.transactions});

  @override
  State<DailySpendingCard> createState() => _DailySpendingCardState();
}

class _DailySpendingCardState extends State<DailySpendingCard> {
  _SpendingPeriod _period = _SpendingPeriod.today;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: now.weekday - 1)); // Monday
    final monthStart = DateTime(now.year, now.month, 1);

    // Filter expenses by period
    List<dom_tx.Transaction> filtered;
    String periodLabel;
    switch (_period) {
      case _SpendingPeriod.today:
        filtered = widget.transactions.where((t) {
          final d = DateTime(t.date.year, t.date.month, t.date.day);
          return d == today && _isExpense(t);
        }).toList();
        periodLabel = 'Hoy';
      case _SpendingPeriod.week:
        filtered = widget.transactions.where((t) {
          return !t.date.isBefore(weekStart) && _isExpense(t);
        }).toList();
        periodLabel = 'Esta semana';
      case _SpendingPeriod.month:
        filtered = widget.transactions.where((t) {
          return !t.date.isBefore(monthStart) && _isExpense(t);
        }).toList();
        periodLabel = DateFormat('MMMM', 'es').format(now);
        periodLabel = periodLabel[0].toUpperCase() + periodLabel.substring(1);
    }

    final totalSpent = filtered.fold(0.0, (sum, t) => sum + t.amount);
    final txCount = filtered.length;

    // Yesterday's spending for comparison (only shown in "today" mode)
    double? yesterdaySpent;
    if (_period == _SpendingPeriod.today) {
      final yesterday = today.subtract(const Duration(days: 1));
      yesterdaySpent = widget.transactions
          .where((t) {
            final d = DateTime(t.date.year, t.date.month, t.date.day);
            return d == yesterday && _isExpense(t);
          })
          .fold<double>(0.0, (sum, t) => sum + t.amount);
    }

    // Top categories for the period
    final categoryTotals = <String, double>{};
    for (final t in filtered) {
      final cat = t.categoryId;
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + t.amount;
    }
    final topCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.18),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header with period toggles ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14,
                    color: AppTheme.colorExpense.withValues(alpha: 0.7)),
                const SizedBox(width: 8),
                Text(
                  'Gastos',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
                const Spacer(),
                // Period toggle chips
                _PeriodChip(
                  label: 'Hoy',
                  active: _period == _SpendingPeriod.today,
                  onTap: () => setState(() => _period = _SpendingPeriod.today),
                ),
                const SizedBox(width: 4),
                _PeriodChip(
                  label: 'Semana',
                  active: _period == _SpendingPeriod.week,
                  onTap: () => setState(() => _period = _SpendingPeriod.week),
                ),
                const SizedBox(width: 4),
                _PeriodChip(
                  label: 'Mes',
                  active: _period == _SpendingPeriod.month,
                  onTap: () => setState(() => _period = _SpendingPeriod.month),
                ),
              ],
            ),
          ),

          // ── Main amount ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        periodLabel,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white38,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatAmount(totalSpent),
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: totalSpent > 0 ? AppTheme.colorExpense : Colors.white30,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                // Transaction count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$txCount mov.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white38,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Yesterday comparison (only in "today" mode) ──
          if (_period == _SpendingPeriod.today && yesterdaySpent != null && yesterdaySpent > 0) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(
                children: [
                  Icon(
                    totalSpent > yesterdaySpent
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    size: 14,
                    color: totalSpent > yesterdaySpent
                        ? AppTheme.colorExpense.withValues(alpha: 0.6)
                        : const Color(0xFF4CAF50).withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Ayer: ${formatAmount(yesterdaySpent)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white30,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Top categories bar ──
          if (topCategories.isNotEmpty && totalSpent > 0) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 6,
                  child: Row(
                    children: topCategories.take(5).map((e) {
                      final pct = e.value / totalSpent;
                      return Expanded(
                        flex: (pct * 100).round().clamp(1, 100),
                        child: Container(
                          margin: const EdgeInsets.only(right: 1),
                          color: _categoryColor(e.key),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            // Category labels
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: topCategories.take(3).map((e) {
                  final pct = (e.value / totalSpent * 100).round();
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          color: _categoryColor(e.key),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_categoryLabel(e.key)} $pct%',
                        style: GoogleFonts.inter(fontSize: 10, color: Colors.white30),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],

          // ── Empty state contextual ──
          if (txCount == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: _period == _SpendingPeriod.today
                  ? DailySpendingMessage(transactions: widget.transactions)
                  : Text(
                      'Sin gastos en este período',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondaryDark,
                      ),
                    ),
            ),

          const SizedBox(height: 14),
        ],
      ),
    );
  }

  bool _isExpense(dom_tx.Transaction t) =>
      t.type == dom_tx.TransactionType.expense ||
      t.type == dom_tx.TransactionType.transfer;

  Color _categoryColor(String categoryId) {
    switch (categoryId) {
      case 'food': return const Color(0xFFFF6B6B);
      case 'transport': return const Color(0xFF4ECDC4);
      case 'entertainment': return const Color(0xFF9B59B6);
      case 'health': return const Color(0xFF2ECC71);
      case 'shopping': return AppTheme.colorWarning;
      case 'home': return const Color(0xFF3498DB);
      case 'services': return const Color(0xFF1ABC9C);
      case 'education': return const Color(0xFFE67E22);
      case 'cat_peer_to_peer': return const Color(0xFFFF8C69);
      case 'cat_financial': return const Color(0xFF6C63FF);
      default: return Colors.white24;
    }
  }

  String _categoryLabel(String categoryId) {
    switch (categoryId) {
      case 'food': return 'Comida';
      case 'transport': return 'Transporte';
      case 'entertainment': return 'Ocio';
      case 'health': return 'Salud';
      case 'shopping': return 'Compras';
      case 'home': return 'Hogar';
      case 'services': return 'Servicios';
      case 'education': return 'Educación';
      case 'cat_peer_to_peer': return 'Personas';
      case 'cat_financial': return 'Financiero';
      case 'salary': return 'Sueldo';
      case 'other_expense': return 'Otros';
      case 'other_income': return 'Otros';
      default: return categoryId;
    }
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _PeriodChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF5ECFB1)],
                )
              : null,
          color: active ? null : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            color: active ? Colors.white : Colors.white38,
          ),
        ),
      ),
    );
  }
}
