import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  DateTime _selectedMonth = DateTime.now();

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat.compactCurrency(symbol: '\$', decimalDigits: 1, locale: 'es_AR');
    final monthName = DateFormat('MMMM yyyy', 'es').format(_selectedMonth);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, color: Colors.white54),
              onPressed: () => _changeMonth(-1),
            ),
            Text(
              '${monthName[0].toUpperCase()}${monthName.substring(1)}',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
              onPressed: () => _changeMonth(1),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumen de Gastos vs Real
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    title: 'Gasto Total',
                    amount: '\$450.000',
                    color: AppTheme.colorExpense,
                    subtitle: 'Todo lo que salió',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    title: 'Gasto Real',
                    amount: '\$230.000',
                    color: AppTheme.colorTransfer,
                    subtitle: 'Sin contar adelantos',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Gráfico de Gastos por Día (Semana)
            Text(
              'Evolución del Gasto',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 250,
              padding: const EdgeInsets.only(top: 24, bottom: 12, left: 12, right: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2C).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100000,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          const style = TextStyle(color: Colors.white54, fontSize: 12);
                          String text;
                          switch (value.toInt()) {
                            case 0: text = 'Lun'; break;
                            case 1: text = 'Mar'; break;
                            case 2: text = 'Mié'; break;
                            case 3: text = 'Jue'; break;
                            case 4: text = 'Vie'; break;
                            case 5: text = 'Sáb'; break;
                            case 6: text = 'Dom'; break;
                            default: text = ''; break;
                          }
                          return SideTitleWidget(
                            meta: meta,
                            space: 8,
                            child: Text(text, style: style),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          return Text(
                            fmt.format(value),
                            style: const TextStyle(color: Colors.white54, fontSize: 10),
                            textAlign: TextAlign.right,
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 25000,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.white.withValues(alpha: 0.05),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    _buildBarData(0, 45000),
                    _buildBarData(1, 12000),
                    _buildBarData(2, 60000), // Sushi
                    _buildBarData(3, 8000),
                    _buildBarData(4, 30000),
                    _buildBarData(5, 85000),
                    _buildBarData(6, 0),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            Text(
              'Top Categorías (Real)',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _TopCategoryRow(name: 'Comida & Salidas', percent: 0.45, amount: '\$103.500', color: AppTheme.colorExpense),
            const SizedBox(height: 12),
            _TopCategoryRow(name: 'Transporte', percent: 0.25, amount: '\$57.500', color: Colors.orangeAccent),
            const SizedBox(height: 12),
            _TopCategoryRow(name: 'Suscripciones', percent: 0.15, amount: '\$34.500', color: Colors.purpleAccent),
            
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _buildBarData(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: AppTheme.colorTransfer,
          width: 14,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 100000,
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String amount;
  final String subtitle;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _TopCategoryRow extends StatelessWidget {
  final String name;
  final double percent;
  final String amount;
  final Color color;

  const _TopCategoryRow({
    required this.name,
    required this.percent,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percent,
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 1,
          child: Text(
            amount,
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
