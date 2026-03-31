import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/accounts/domain/models/account.dart';
import '../../features/budget/presentation/providers/budget_provider.dart';
import '../../features/people/presentation/providers/people_provider.dart';

class FinancialBrain {
  final double arsCashBalance;
  final double usdCashBalance;
  final double peopleOweMe;
  final double totalCreditCardDebt;
  final double upcomingFixedExpenses;

  FinancialBrain({
    required this.arsCashBalance,
    required this.usdCashBalance,
    required this.peopleOweMe,
    required this.totalCreditCardDebt,
    required this.upcomingFixedExpenses,
  });

  /// Safe Budget = (ARS Cash + Shared debts) - (Card Debts + Fixed Expenses)
  double get safeBudgetARS => 
      (arsCashBalance + peopleOweMe) - (totalCreditCardDebt + upcomingFixedExpenses);

  /// Recommendation based on balances
  String get message {
    if (safeBudgetARS < 0) return "⚠️ Cuidado: Tus deudas de tarjeta y gastos fijos superan tu efectivo hoy.";
    if (safeBudgetARS < 100000) return "🛡️ Presupuesto ajustado. Priorizá pagar la tarjeta.";
    return "✅ Presupuesto Seguro: Tenés cubiertos tus gastos fijos y la tarjeta.";
  }
}

final financialBrainProvider = Provider<FinancialBrain>((ref) {
  // In a real app, these would come from StreamProviders of the database.
  // For now, we inject the real data we got from the PDFs/Screenshots.
  
  final fixedBudgets = ref.watch(fixedBudgetsProvider);
  final totalFixed = fixedBudgets.fold(0.0, (sum, b) => sum + b.limitAmount);
  
  final peopleTotal = ref.watch(globalPeopleBalanceProvider);
  
  return FinancialBrain(
    arsCashBalance: 692932.13,   // Mercado Pago ARS
    usdCashBalance: 2101.12,    // AstroPay USD
    peopleOweMe: peopleTotal,    // Deudas de Sofia/Juan
    totalCreditCardDebt: 79987.00, // Lo que dice el resumen de Abril
    upcomingFixedExpenses: totalFixed,
  );
});

final safeBudgetProvider = Provider<double>((ref) {
  return ref.watch(financialBrainProvider).safeBudgetARS;
});
