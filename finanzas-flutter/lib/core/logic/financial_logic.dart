import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/accounts/domain/models/account.dart';
import '../../features/budget/presentation/providers/budget_provider.dart';
import '../../features/people/presentation/providers/people_provider.dart';

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
  
  return FinancialBrain(
    arsCashBalance: 692932.13,   // Mercado Pago
    usdCashBalance: 2101.12,    // AstroPay
    peopleOweMe: peopleTotal,    // $274k aprox
    mastercardDebt: 1522588.00,  // Resumen Mar
    visaDebt: 511659.00,        // Resumen Abr
    upcomingFixedExpenses: totalFixed,
  );
});

final safeBudgetProvider = Provider<double>((ref) {
  return ref.watch(financialBrainProvider).safeBudgetARS;
});
