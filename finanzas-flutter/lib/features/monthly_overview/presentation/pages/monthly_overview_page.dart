import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../widgets/statement_scanner_bottom_sheet.dart';
import '../widgets/month_closure_wizard.dart';

class MonthlyOverviewPage extends StatefulWidget {
  const MonthlyOverviewPage({super.key});

  @override
  State<MonthlyOverviewPage> createState() => _MonthlyOverviewPageState();
}

class _MonthlyOverviewPageState extends State<MonthlyOverviewPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy', 'es').format(_selectedMonth);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Colors.white),
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
            const SizedBox(width: 8),
            // Botón de Cierre de Mes
            if (_selectedMonth.month == DateTime.now().month)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  side: BorderSide(color: AppTheme.colorTransfer.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () => MonthClosureWizard.show(context, _selectedMonth),
                child: const Text('Cerrar Mes', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.document_scanner_outlined, color: AppTheme.colorTransfer),
            tooltip: 'Escanear Resumen',
            onPressed: () => StatementScannerBottomSheet.show(context),
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.colorTransfer,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(text: 'Resumen'),
            Tab(text: 'Compartidos'),
            Tab(text: 'Préstamos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ResumenTab(),
          _CompartidosTab(),
          _PrestamosTab(),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// COMPONENTES DE LAS TABS (MOCK)
// ──────────────────────────────────────────────────────────────────

class _ResumenTab extends StatelessWidget {
  const _ResumenTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Pestaña Resumen mensual',
        style: TextStyle(color: Colors.white54),
      ),
    );
  }
}

class _CompartidosTab extends StatelessWidget {
  const _CompartidosTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      children: [
        const Text(
          'Por cobrar',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.colorTransfer.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.receipt_long_rounded, color: AppTheme.colorTransfer),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sushi con Sofi y Juan',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Sofi debe \$15.000, Juan \$15.000',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 100), // spacing for bottom bar
      ],
    );
  }
}

class _PrestamosTab extends StatelessWidget {
  const _PrestamosTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      children: [
        const Text(
          'Mis Préstamos',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Presté a Martin',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15)),
                  Text('\$120.000',
                      style: TextStyle(color: AppTheme.colorTransfer, fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: 0.2, // 20% devuelto
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.colorTransfer),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Devolvió \$24.000', style: TextStyle(color: Colors.white54, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }
}
