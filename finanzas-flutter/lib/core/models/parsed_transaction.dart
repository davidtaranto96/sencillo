/// Representa una transacción extraída de un resumen de tarjeta de crédito (PDF).
/// Este modelo es temporal — se usa solo durante el flujo de importación.
class ParsedTransaction {
  ParsedTransaction({
    required this.date,
    required this.description,
    required this.amount,
    this.isInstallment = false,
    this.installmentCurrent,
    this.installmentTotal,
    required this.suggestedCategoryId,
    required this.suggestedCategoryName,
    this.isSelected = true,
  });

  final DateTime date;
  final String description;
  final double amount;
  final bool isInstallment;
  final int? installmentCurrent;
  final int? installmentTotal;
  String suggestedCategoryId;
  String suggestedCategoryName;

  /// Controlado por el usuario en la pantalla de revisión antes de importar.
  bool isSelected;

  String get installmentLabel =>
      isInstallment ? 'Cuota $installmentCurrent/$installmentTotal' : '';

  ParsedTransaction copyWith({bool? isSelected, String? suggestedCategoryId, String? suggestedCategoryName}) {
    return ParsedTransaction(
      date: date,
      description: description,
      amount: amount,
      isInstallment: isInstallment,
      installmentCurrent: installmentCurrent,
      installmentTotal: installmentTotal,
      suggestedCategoryId: suggestedCategoryId ?? this.suggestedCategoryId,
      suggestedCategoryName: suggestedCategoryName ?? this.suggestedCategoryName,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

/// Resultado del proceso de importación.
class ImportResult {
  const ImportResult({required this.imported, required this.total, required this.cardName});

  final int imported;
  final int total;
  final String cardName;
}

/// Formato de tarjeta detectado en el PDF.
enum CardFormat {
  mastercardICBC,
  visaICBC,
  unknown,
}
