import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ImportRecord {
  final String id;
  final String cardAccountId;
  final String cardName;
  final String cardFormat;
  final String fileName;
  final int totalTransactions;
  final int importedTransactions;
  final double totalAmount;
  final int statementMonth;
  final int statementYear;
  final DateTime importDate;
  final List<String> transactionIds;

  ImportRecord({
    required this.id,
    required this.cardAccountId,
    required this.cardName,
    required this.cardFormat,
    required this.fileName,
    required this.totalTransactions,
    required this.importedTransactions,
    required this.totalAmount,
    required this.statementMonth,
    required this.statementYear,
    required this.importDate,
    this.transactionIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'cardAccountId': cardAccountId,
        'cardName': cardName,
        'cardFormat': cardFormat,
        'fileName': fileName,
        'totalTransactions': totalTransactions,
        'importedTransactions': importedTransactions,
        'totalAmount': totalAmount,
        'statementMonth': statementMonth,
        'statementYear': statementYear,
        'importDate': importDate.toIso8601String(),
        'transactionIds': transactionIds,
      };

  factory ImportRecord.fromJson(Map<String, dynamic> json) => ImportRecord(
        id: json['id'],
        cardAccountId: json['cardAccountId'],
        cardName: json['cardName'],
        cardFormat: json['cardFormat'] ?? '',
        fileName: json['fileName'] ?? '',
        totalTransactions: json['totalTransactions'],
        importedTransactions: json['importedTransactions'],
        totalAmount: (json['totalAmount'] as num).toDouble(),
        statementMonth: json['statementMonth'],
        statementYear: json['statementYear'],
        importDate: DateTime.parse(json['importDate']),
        transactionIds: (json['transactionIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}

class ImportHistoryNotifier extends StateNotifier<List<ImportRecord>> {
  ImportHistoryNotifier() : super([]) {
    _load();
  }

  static const _key = 'import_history';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    state = raw
        .map((s) => ImportRecord.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.importDate.compareTo(a.importDate));
  }

  Future<void> add(ImportRecord record) async {
    state = [record, ...state];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      state.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }

  Future<void> remove(String id) async {
    state = state.where((r) => r.id != id).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      state.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }

  /// Check if a file was already imported.
  bool isAlreadyImported(String fileName) {
    return state.any((r) => r.fileName == fileName);
  }

  /// Get the record for a previously imported file.
  ImportRecord? findByFileName(String fileName) {
    try {
      return state.firstWhere((r) => r.fileName == fileName);
    } catch (_) {
      return null;
    }
  }
}

final importHistoryProvider =
    StateNotifierProvider<ImportHistoryNotifier, List<ImportRecord>>(
  (ref) => ImportHistoryNotifier(),
);
