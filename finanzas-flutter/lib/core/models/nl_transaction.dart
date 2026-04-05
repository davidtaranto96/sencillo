/// Escenarios detectados por IA desde texto libre
enum NLScenario {
  expense,           // gasto genérico (efectivo, débito, tarjeta)
  income,            // ingreso de dinero a una cuenta
  cardPayment,       // pago del resumen de una tarjeta
  loanGiven,         // presté plata a alguien (ellos me deben)
  loanReceived,      // alguien me devolvió/pagó plata
  loanRepayment,     // yo le pagué a alguien lo que le debía
  sharedExpense,     // gasto compartido con división
  goalContribution,  // guardé plata para un objetivo
  wishlistPurchase,  // compré algo de la lista de deseos
  internalTransfer,  // transferencia entre mis propias cuentas
  createGoal,        // crear un nuevo objetivo de ahorro
  createBudget,      // crear un nuevo presupuesto
  navigateTo,        // navegar a una sección de la app
  createPerson,      // agregar un nuevo contacto / persona
  queryBalance,      // consultar saldo de cuentas
  queryBudget,       // consultar estado de un presupuesto
  queryDebt,         // consultar deuda con una persona
  duplicateLastTx,   // "lo mismo de ayer" — duplicar último movimiento
  settleDebt,        // "saldar todo con Juan" — liquidar deuda completa
  unclear,           // no se pudo interpretar
}

/// Resultado del parsing IA de un input de lenguaje natural
class NLTransaction {
  final NLScenario scenario;
  final double? amount;
  final String? title;
  final String? categoryId;
  final String? personId;
  final String? personName;        // nombre para mostrar si no matchea id
  final String? accountId;         // cuenta fuente / destino principal
  final String? targetAccountId;   // para internalTransfer: cuenta destino
  final String? cardId;            // para cardPayment
  final String? goalId;
  final String? wishlistItemId;
  final String? budgetCategoryId;    // para createBudget: categoryId predefinido
  final String? deadlineRaw;         // para createGoal: fecha límite como string
  final bool isSplit;
  final double? splitOwnAmount;    // para sharedExpense: mi parte
  final double? splitOtherAmount;  // para sharedExpense: parte ajena
  final String? note;
  final String rawInput;
  // Nuevos campos
  final String? navigationTarget;  // para navigateTo: tab ID ('people', 'budget', etc.)

  const NLTransaction({
    required this.scenario,
    this.amount,
    this.title,
    this.categoryId,
    this.personId,
    this.personName,
    this.accountId,
    this.targetAccountId,
    this.cardId,
    this.goalId,
    this.wishlistItemId,
    this.budgetCategoryId,
    this.deadlineRaw,
    this.isSplit = false,
    this.splitOwnAmount,
    this.splitOtherAmount,
    this.note,
    required this.rawInput,
    this.navigationTarget,
  });

  /// Descripción legible del escenario para mostrar al usuario
  String get scenarioLabel {
    switch (scenario) {
      case NLScenario.expense:
        return 'Gasto';
      case NLScenario.income:
        return 'Ingreso';
      case NLScenario.cardPayment:
        return 'Pago de tarjeta';
      case NLScenario.loanGiven:
        return 'Préstamo dado';
      case NLScenario.loanReceived:
        return 'Devolución recibida';
      case NLScenario.loanRepayment:
        return 'Pago de deuda propia';
      case NLScenario.sharedExpense:
        return 'Gasto compartido';
      case NLScenario.goalContribution:
        return 'Ahorro para objetivo';
      case NLScenario.wishlistPurchase:
        return 'Compra de lista';
      case NLScenario.internalTransfer:
        return 'Transferencia propia';
      case NLScenario.createGoal:
        return 'Crear objetivo';
      case NLScenario.createBudget:
        return 'Crear presupuesto';
      case NLScenario.navigateTo:
        return 'Navegar';
      case NLScenario.createPerson:
        return 'Nuevo contacto';
      case NLScenario.queryBalance:
        return 'Consultar saldo';
      case NLScenario.queryBudget:
        return 'Consultar presupuesto';
      case NLScenario.queryDebt:
        return 'Consultar deuda';
      case NLScenario.duplicateLastTx:
        return 'Repetir movimiento';
      case NLScenario.settleDebt:
        return 'Saldar deuda';
      case NLScenario.unclear:
        return 'No reconocido';
    }
  }

  NLTransaction copyWith({
    NLScenario? scenario,
    double? amount,
    String? title,
    String? categoryId,
    String? personId,
    String? personName,
    String? accountId,
    String? targetAccountId,
    String? cardId,
    String? goalId,
    String? wishlistItemId,
    String? budgetCategoryId,
    String? deadlineRaw,
    bool? isSplit,
    double? splitOwnAmount,
    double? splitOtherAmount,
    String? note,
    String? rawInput,
    String? navigationTarget,
  }) {
    return NLTransaction(
      scenario: scenario ?? this.scenario,
      amount: amount ?? this.amount,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      personId: personId ?? this.personId,
      personName: personName ?? this.personName,
      accountId: accountId ?? this.accountId,
      targetAccountId: targetAccountId ?? this.targetAccountId,
      cardId: cardId ?? this.cardId,
      goalId: goalId ?? this.goalId,
      wishlistItemId: wishlistItemId ?? this.wishlistItemId,
      budgetCategoryId: budgetCategoryId ?? this.budgetCategoryId,
      deadlineRaw: deadlineRaw ?? this.deadlineRaw,
      isSplit: isSplit ?? this.isSplit,
      splitOwnAmount: splitOwnAmount ?? this.splitOwnAmount,
      splitOtherAmount: splitOtherAmount ?? this.splitOtherAmount,
      note: note ?? this.note,
      rawInput: rawInput ?? this.rawInput,
      navigationTarget: navigationTarget ?? this.navigationTarget,
    );
  }
}
