import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/budget/presentation/providers/budget_provider.dart';
import '../database/database_providers.dart';

class FinancialBrain {
  final double arsCashBalance;
  final double usdCashBalance;
  final double peopleOweMe;
  final double mastercardDebt;
  final double visaDebt;
  final double upcomingFixedExpenses;

  FinancialBrain({
    required this.arsCashBalance,
    required this.usdCashBalance,
    required this.peopleOweMe,
    required this.mastercardDebt,
    required this.visaDebt,
    required this.upcomingFixedExpenses,
  });

  /// Safe Budget = (ARS Cash + Shared debts) - (MC Debt + Visa Debt + Fixed Expenses)
  double get safeBudgetARS => 
      (arsCashBalance + peopleOweMe) - (mastercardDebt + visaDebt + upcomingFixedExpenses);

  /// Recommendation based on balances
  String get message {
    if (safeBudgetARS < 0) return "⚠️ Atención: Tus deudas de tarjeta superan tu efectivo disponible.";
    if (safeBudgetARS < 100000) return "🛡️ Presupuesto muy ajustado.";
    return "✅ Todo bajo control.";
  }
}

final financialBrainProvider = Provider<FinancialBrain>((ref) {
  final fixedBudgets = ref.watch(fixedBudgetsProvider);
  final totalFixed = fixedBudgets.fold(0.0, (sum, b) => sum + b.limitAmount);
  final peopleTotal = ref.watch(globalPeopleBalanceProvider);
  
  final accountsAsync = ref.watch(accountsStreamProvider);
  
  return accountsAsync.when(
    data: (accounts) {
      final mp = accounts.any((a) => a.id == 'mp_ars') 
          ? accounts.firstWhere((a) => a.id == 'mp_ars').balance 
          : 0.0;
      final ap = accounts.any((a) => a.id == 'ap_usd') 
          ? accounts.firstWhere((a) => a.id == 'ap_usd').balance 
          : 0.0;
      final mc = accounts.any((a) => a.id == 'mc_credit') 
          ? accounts.firstWhere((a) => a.id == 'mc_credit').pendingStatementAmount 
          : 0.0;
      final visa = accounts.any((a) => a.id == 'visa_credit') 
          ? accounts.firstWhere((a) => a.id == 'visa_credit').pendingStatementAmount 
          : 0.0;

      return FinancialBrain(
        arsCashBalance: mp,
        usdCashBalance: ap,
        peopleOweMe: peopleTotal,
        mastercardDebt: mc,
        visaDebt: visa,
        upcomingFixedExpenses: totalFixed,
      );
    },
    loading: () => FinancialBrain(
      arsCashBalance: 0,
      usdCashBalance: 0,
      peopleOweMe: peopleTotal,
      mastercardDebt: 0,
      visaDebt: 0,
      upcomingFixedExpenses: totalFixed,
    ),
    error: (_, __) => FinancialBrain(
      arsCashBalance: 0,
      usdCashBalance: 0,
      peopleOweMe: peopleTotal,
      mastercardDebt: 0,
      visaDebt: 0,
      upcomingFixedExpenses: totalFixed,
    ),
  );
});

final safeBudgetProvider = Provider<double>((ref) {
  return ref.watch(financialBrainProvider).safeBudgetARS;
});
