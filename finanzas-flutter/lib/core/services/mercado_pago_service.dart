import 'dart:convert';
import 'package:http/http.dart' as http;

/// Modelo de movimiento de Mercado Pago
class MpMovement {
  final String id;
  final String type;
  final String status;
  final double amount; // Positivo = ingreso, Negativo = egreso
  final double netAmount;
  final String? description;
  final String? payerEmail;
  final String? paymentMethod;
  final DateTime date;
  final String? category;

  const MpMovement({
    required this.id,
    required this.type,
    required this.status,
    required this.amount,
    required this.netAmount,
    this.description,
    this.payerEmail,
    this.paymentMethod,
    required this.date,
    this.category,
  });

  /// Determina si un movimiento es egreso basándose en:
  /// 1. collector/payer IDs (más confiable)
  /// 2. operation_type como fallback
  static bool _isExpenseForUser(Map<String, dynamic> json, int? userId) {
    final opType = json['operation_type'] as String? ?? '';
    final collectorId = json['collector']?['id'] as int?;
    final payerId = json['payer']?['id'] as int?;

    // Si tenemos el userId → comparar directamente
    if (userId != null) {
      if (collectorId == userId && payerId != userId) return false; // ingreso
      if (payerId == userId && collectorId != userId) return true;  // egreso
    }

    // Fallback por operation_type:
    // regular_payment / pos_payment / money_transfer (payer→collector) = egreso
    // account_fund / bank_transfer recibida = ingreso
    switch (opType) {
      case 'regular_payment':
      case 'pos_payment':
        return true; // el usuario pagó algo
      case 'account_fund':
      case 'investment_transfer_debit': // retiro de inversión
        return false; // el usuario recibió fondos
      case 'money_transfer':
        // Para money_transfer sin userId, mirar si hay net_received_amount > 0
        final netReceived = (json['transaction_details']?['net_received_amount'] as num?)?.toDouble() ?? 0;
        return netReceived <= 0; // si no recibió nada neto, fue egreso
      default:
        return false; // por defecto income
    }
  }

  factory MpMovement.fromPaymentJson(Map<String, dynamic> json, {int? userId, bool? forceExpense}) {
    final rawAmount = (json['transaction_amount'] as num?)?.toDouble() ?? 0;
    final opType = json['operation_type'] as String? ?? 'payment';

    final isExpense = forceExpense ?? _isExpenseForUser(json, userId);
    final signedAmount = isExpense ? -rawAmount : rawAmount;

    final netRaw = (json['transaction_details']?['net_received_amount'] as num?)
            ?.toDouble() ?? rawAmount;

    return MpMovement(
      id: json['id']?.toString() ?? '',
      type: opType,
      status: json['status'] as String? ?? 'unknown',
      amount: signedAmount,
      netAmount: isExpense ? -netRaw.abs() : netRaw.abs(),
      description: _buildDescription(json),
      payerEmail: json['payer']?['email'] as String?,
      paymentMethod: json['payment_method_id'] as String?,
      date: DateTime.tryParse(json['date_created'] as String? ?? '') ?? DateTime.now(),
      category: _categorize(json['description'] as String?),
    );
  }

  static String? _buildDescription(Map<String, dynamic> json) {
    final desc = json['description'] as String?;
    if (desc != null && desc.isNotEmpty && desc != 'null') return desc;

    final opType = json['operation_type'] as String? ?? '';
    final payMethod = json['payment_method_id'] as String? ?? '';

    if (opType == 'money_transfer' || payMethod == 'account_money') {
      return 'Transferencia bancaria';
    }
    if (opType == 'regular_payment') return 'Pago';
    if (opType == 'account_fund') return 'Recarga';
    if (opType == 'pos_payment') return 'Pago en comercio';

    return json['payment_type_id'] as String? ?? 'Movimiento';
  }

  factory MpMovement.fromActivityJson(Map<String, dynamic> json) {
    final amount = (json['amount'] as num?)?.toDouble() ?? 0;
    return MpMovement(
      id: json['id']?.toString() ?? '',
      type: json['type'] as String? ?? 'unknown',
      status: json['status'] as String? ?? 'unknown',
      amount: amount,
      netAmount: amount,
      description: json['description'] as String? ?? 'Movimiento',
      date: DateTime.tryParse(json['date_created'] as String? ?? '') ?? DateTime.now(),
    );
  }

  static String? _categorize(String? description) {
    if (description == null) return null;
    final d = description.toLowerCase();
    if (d.contains('uber') || d.contains('cabify') || d.contains('didi')) return 'Transporte';
    if (d.contains('rappi') || d.contains('pedidosya') || d.contains('mcdonald')) return 'Comida';
    if (d.contains('spotify') || d.contains('netflix') || d.contains('disney')) return 'Entretenimiento';
    if (d.contains('edenor') || d.contains('edesur') || d.contains('metrogas') || d.contains('aysa')) return 'Servicios';
    if (d.contains('farmacia') || d.contains('osde')) return 'Salud';
    return null;
  }

  bool get isExpense => amount < 0;
  bool get isIncome => amount > 0;
  double get absAmount => amount.abs();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'status': status,
        'amount': amount,
        'netAmount': netAmount,
        'description': description,
        'payerEmail': payerEmail,
        'paymentMethod': paymentMethod,
        'date': date.toIso8601String(),
        'category': category,
      };

  factory MpMovement.fromCacheJson(Map<String, dynamic> json) => MpMovement(
        id: json['id'] as String,
        type: json['type'] as String,
        status: json['status'] as String,
        amount: (json['amount'] as num).toDouble(),
        netAmount: (json['netAmount'] as num).toDouble(),
        description: json['description'] as String?,
        payerEmail: json['payerEmail'] as String?,
        paymentMethod: json['paymentMethod'] as String?,
        date: DateTime.parse(json['date'] as String),
        category: json['category'] as String?,
      );
}

/// Balance de la cuenta de Mercado Pago
class MpBalance {
  final double availableBalance;
  final double totalAmount;
  final double unavailableAmount;
  final String currencyId;

  const MpBalance({
    required this.availableBalance,
    required this.totalAmount,
    required this.unavailableAmount,
    required this.currencyId,
  });

  factory MpBalance.fromJson(Map<String, dynamic> json) {
    return MpBalance(
      availableBalance: (json['available_balance'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      unavailableAmount: (json['unavailable_balance'] as num?)?.toDouble() ?? 0,
      currencyId: json['currency_id'] as String? ?? 'ARS',
    );
  }
}

/// Perfil del usuario de Mercado Pago
class MpUserProfile {
  final int id;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? nickname;

  const MpUserProfile({
    required this.id,
    this.firstName,
    this.lastName,
    this.email,
    this.nickname,
  });

  String get displayName =>
      '${firstName ?? ''} ${lastName ?? ''}'.trim().isNotEmpty
          ? '${firstName ?? ''} ${lastName ?? ''}'.trim()
          : nickname ?? 'Usuario MP';

  factory MpUserProfile.fromJson(Map<String, dynamic> json) {
    return MpUserProfile(
      id: json['id'] as int? ?? 0,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      email: json['email'] as String?,
      nickname: json['nickname'] as String?,
    );
  }
}

/// Servicio HTTP para comunicarse con la API de Mercado Pago
class MercadoPagoService {
  static const _baseUrl = 'https://api.mercadopago.com';
  final String accessToken;

  MercadoPagoService({required this.accessToken});

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };

  /// Obtiene el perfil del usuario autenticado
  Future<MpUserProfile> fetchUserProfile() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/users/me'), headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Error al obtener perfil: HTTP ${response.statusCode}');
    }

    return MpUserProfile.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Obtiene el balance. Prueba múltiples endpoints.
  Future<MpBalance?> fetchBalance({int? userId}) async {
    final endpoints = [
      if (userId != null)
        '$_baseUrl/users/$userId/mercadopago_account/balance',
      '$_baseUrl/users/me/mercadopago_account/balance',
      '$_baseUrl/v1/account/settlement_report',
    ];

    for (final url in endpoints) {
      try {
        final response = await http
            .get(Uri.parse(url), headers: _headers)
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic>) {
            if (data.containsKey('available_balance')) {
              return MpBalance.fromJson(data);
            }
            // Intentar extraer balance de otra estructura
            if (data.containsKey('total')) {
              return MpBalance(
                availableBalance: (data['total'] as num?)?.toDouble() ?? 0,
                totalAmount: (data['total'] as num?)?.toDouble() ?? 0,
                unavailableAmount: 0,
                currencyId: 'ARS',
              );
            }
          }
        }
      } catch (_) {
        continue;
      }
    }
    return null; // Balance no disponible con este tipo de token
  }

  /// Obtiene movimientos de la API (ingresos y egresos)
  /// Hace dos búsquedas y combina:
  /// 1. Búsqueda general: incluye tanto pagos recibidos como realizados
  /// 2. Búsqueda por payer.id: asegura capturar egresos donde el user pagó
  Future<List<MpMovement>> fetchMovements({
    int limit = 30,
    int offset = 0,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? userId,
  }) async {
    final baseParams = <String, String>{
      'sort': 'date_created',
      'criteria': 'desc',
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    if (dateFrom != null) baseParams['begin_date'] = dateFrom.toIso8601String();
    if (dateTo != null) baseParams['end_date'] = dateTo.toIso8601String();

    // ── Búsqueda 1: General (collector = user + pagos realizados) ──────────
    final uri1 = Uri.parse('$_baseUrl/v1/payments/search')
        .replace(queryParameters: baseParams);

    final response1 = await http
        .get(uri1, headers: _headers)
        .timeout(const Duration(seconds: 20));

    if (response1.statusCode != 200) {
      throw Exception('Error al obtener movimientos: HTTP ${response1.statusCode}');
    }

    final data1 = jsonDecode(response1.body) as Map<String, dynamic>;
    final results1 = data1['results'] as List<dynamic>? ?? [];

    final allById = <String, MpMovement>{};

    for (final e in results1) {
      final m = MpMovement.fromPaymentJson(
        e as Map<String, dynamic>,
        userId: userId,
        // No forzar dirección — dejar que _isExpenseForUser decida
      );
      if (m.status == 'approved') {
        allById[m.id] = m;
      }
    }

    // ── Búsqueda 2: Egresos explícitos (payer.id = user) ──────────────────
    if (userId != null) {
      try {
        final payerParams = Map<String, String>.from(baseParams)
          ..['payer.id'] = userId.toString();

        final uri2 = Uri.parse('$_baseUrl/v1/payments/search')
            .replace(queryParameters: payerParams);

        final response2 = await http
            .get(uri2, headers: _headers)
            .timeout(const Duration(seconds: 15));

        if (response2.statusCode == 200) {
          final data2 = jsonDecode(response2.body) as Map<String, dynamic>;
          final results2 = data2['results'] as List<dynamic>? ?? [];

          for (final e in results2) {
            final m = MpMovement.fromPaymentJson(
              e as Map<String, dynamic>,
              userId: userId,
              forceExpense: true, // Si busqué por payer.id, definitivamente egreso
            );
            if (m.status == 'approved') {
              allById[m.id] = m; // Sobreescribe: egreso tiene prioridad
            }
          }
        }
      } catch (_) {
        // Si falla búsqueda 2, continuamos con los resultados de búsqueda 1
      }
    }

    final all = allById.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return all;
  }

  Future<bool> validateToken() async {
    try {
      await fetchUserProfile();
      return true;
    } catch (_) {
      return false;
    }
  }
}
