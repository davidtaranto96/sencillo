import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:uuid/uuid.dart';

import '../../../../core/database/database_providers.dart';
import '../../../../core/logic/account_service.dart';
import '../../../../core/logic/pdf_parser_service.dart';
import '../../../../core/models/parsed_transaction.dart';
import '../../../../core/providers/import_history_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../shared/widgets/pdf_processing_overlay.dart';

// ─── Estados del flujo ────────────────────────────────────────────────────

enum _ScanState { idle, parsing, review, importing, done }

// ─── Bottom Sheet ─────────────────────────────────────────────────────────

class StatementScannerBottomSheet extends ConsumerStatefulWidget {
  const StatementScannerBottomSheet({super.key});

  /// Shows the scanner bottom sheet. Returns a map with import info if the user
  /// wants to navigate to the Detalle tab after import:
  /// {'action': 'show_detail', 'month': int, 'year': int, 'cardId': String}
  static Future<Map<String, dynamic>?> show(BuildContext context) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const StatementScannerBottomSheet(),
    );
  }

  @override
  ConsumerState<StatementScannerBottomSheet> createState() =>
      _StatementScannerBottomSheetState();
}

class _StatementScannerBottomSheetState
    extends ConsumerState<StatementScannerBottomSheet> {
  _ScanState _state = _ScanState.idle;
  List<ParsedTransaction> _transactions = [];
  CardFormat _detectedFormat = CardFormat.unknown;
  String? _selectedCardId;
  ImportResult? _importResult;
  String? _errorMessage;
  String? _duplicateWarning;
  int _importedCompras = 0;
  int _importedCuotas = 0;
  String _fileName = '';
  int? _detectedMonth;
  int? _detectedYear;
  String? _detectedBankName;
  double? _pagoMinimo;
  double? _saldoActual;

  // ─── Lógica central ──────────────────────────────────────────────────────

  Future<void> _pickAndParse() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    _fileName = result.files.first.name;

    setState(() {
      _state = _ScanState.parsing;
      _errorMessage = null;
    });

    try {
      Uint8List bytes;
      final file = result.files.first;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else {
        throw Exception('No se pudo leer el archivo seleccionado.');
      }

      final text = await Future.microtask(() => PdfParserService.extractText(bytes));
      _detectedFormat = PdfParserService.detectFormat(text);
      final parsed = await Future.microtask(() => PdfParserService.parse(text));

      // Auto-detect statement info (bank, month, year)
      final stInfo = PdfParserService.detectStatementInfo(text);
      _detectedMonth = stInfo.month;
      _detectedYear = stInfo.year;
      _detectedBankName = stInfo.bankName;

      // Extract pago mínimo and saldo actual
      final amounts = PdfParserService.extractStatementAmounts(text);
      _pagoMinimo = amounts.pagoMinimo;
      _saldoActual = amounts.saldoActual;

      // Auto-select card based on detected format
      if (_selectedCardId == null) {
        final accounts = ref.read(accountsStreamProvider).valueOrNull ?? [];
        final cards = accounts.where((a) => a.isCreditCard).toList();
        if (cards.isNotEmpty) {
          // Try to match by name containing bank keywords
          final matched = cards.where((c) {
            final name = c.name.toLowerCase();
            if (_detectedFormat == CardFormat.mastercardICBC) {
              return name.contains('master') || name.contains('mc');
            }
            if (_detectedFormat == CardFormat.visaICBC) {
              return name.contains('visa');
            }
            return false;
          }).toList();
          _selectedCardId = matched.isNotEmpty ? matched.first.id : cards.first.id;
        }
      }

      // Check for duplicate import
      _duplicateWarning = null;
      final history = ref.read(importHistoryProvider);
      final existingImport = history.where((r) => r.fileName == _fileName).toList();
      if (existingImport.isNotEmpty) {
        final prev = existingImport.first;
        final monthNames = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
        _duplicateWarning = 'Este archivo ya fue importado el '
            '${DateFormat('dd/MM/yy').format(prev.importDate)} '
            '(${prev.importedTransactions} movimientos, ${monthNames[prev.statementMonth]} ${prev.statementYear}).';
      }

      if (parsed.isEmpty) {
        final debug = PdfParserService.debugExtraction(text);
        final detected = debug['format'] as String;
        String hint;
        if (detected == 'unknown') {
          hint = 'No pudimos reconocer el formato de este PDF.\n\n'
              'Formatos soportados:\n'
              '  •  Mastercard ICBC\n'
              '  •  Visa ICBC\n\n'
              'Asegurate de importar el resumen descargado '
              'directamente del home banking de ICBC.';
        } else {
          hint = 'Se detectó formato "$detected" pero no se '
              'encontraron transacciones.\n\n'
              'Posibles causas:\n'
              '  •  El PDF está vacío o solo tiene información institucional\n'
              '  •  El resumen no contiene compras del período\n\n'
              'Probá con otro resumen o verificá que sea el archivo correcto.';
        }
        setState(() {
          _errorMessage = hint;
          _state = _ScanState.idle;
        });
        return;
      }

      // Check for duplicates against already-imported transactions in the DB
      final existingTxs = ref.read(transactionsStreamProvider).valueOrNull ?? [];
      int duplicatesFound = 0;
      for (int i = 0; i < parsed.length; i++) {
        final tx = parsed[i];
        final isDuplicate = existingTxs.any((existing) =>
            existing.title == tx.description &&
            (existing.amount - tx.amount).abs() < 0.01 &&
            existing.date.year == tx.date.year &&
            existing.date.month == tx.date.month &&
            existing.date.day == tx.date.day);
        if (isDuplicate) {
          parsed[i] = tx.copyWith(isSelected: false);
          duplicatesFound++;
        }
      }

      setState(() {
        _transactions = parsed;
        _state = _ScanState.review;
        if (duplicatesFound > 0) {
          final prefix = (_duplicateWarning?.isNotEmpty ?? false) ? '$_duplicateWarning\n' : '';
          final plural = duplicatesFound > 1;
          _duplicateWarning = '$prefix$duplicatesFound movimiento${plural ? 's' : ''} '
              'ya existe${plural ? 'n' : ''} en tu cuenta '
              'y se deseleccionaron automáticamente.';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al procesar el PDF: ${e.toString()}\n'
            'Verificá que el archivo sea un PDF válido.';
        _state = _ScanState.idle;
      });
    }
  }

  Future<void> _import() async {
    _importedCompras = _transactions.where((t) => t.isSelected && !t.isInstallment).length;
    _importedCuotas = _transactions.where((t) => t.isSelected && t.isInstallment).length;
    setState(() => _state = _ScanState.importing);
    try {
      final service = ref.read(accountServiceProvider);
      final result = await service.importStatementTransactions(
        cardAccountId: _selectedCardId!,
        transactions: _transactions,
        fileName: _fileName,
        cardFormat: _detectedFormat.name,
      );

      // Calculate most common month/year from transaction dates
      final selected = _transactions.where((t) => t.isSelected).toList();
      final monthCounts = <String, int>{};
      for (final tx in selected) {
        final key = '${tx.date.year}-${tx.date.month}';
        monthCounts[key] = (monthCounts[key] ?? 0) + 1;
      }
      String topKey = '${DateTime.now().year}-${DateTime.now().month}';
      if (monthCounts.isNotEmpty) {
        topKey = monthCounts.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;
      }
      final parts = topKey.split('-');
      final stYear = int.parse(parts[0]);
      final stMonth = int.parse(parts[1]);

      final totalAmount =
          selected.fold(0.0, (sum, t) => sum + t.amount);

      // Save to import history (including transaction IDs for undo)
      ref.read(importHistoryProvider.notifier).add(ImportRecord(
            id: const Uuid().v4(),
            cardAccountId: _selectedCardId!,
            cardName: result.cardName,
            cardFormat: _detectedFormat.name,
            fileName: _fileName,
            totalTransactions: _transactions.length,
            importedTransactions: result.imported,
            totalAmount: totalAmount,
            statementMonth: stMonth,
            statementYear: stYear,
            importDate: DateTime.now(),
            transactionIds: result.transactionIds,
          ));

      setState(() {
        _importResult = result;
        _state = _ScanState.done;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al importar: ${e.toString()}';
        _state = _ScanState.review;
      });
    }
  }

  Future<void> _undoLastImport() async {
    if (_importResult == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = ref.read(accountServiceProvider);
      await service.undoImportBatch(
        cardAccountId: _selectedCardId!,
        transactionIds: _importResult!.transactionIds,
      );

      // Remove from import history (last added)
      final history = ref.read(importHistoryProvider);
      if (history.isNotEmpty) {
        ref.read(importHistoryProvider.notifier).remove(history.first.id);
      }

      messenger.showSnackBar(const SnackBar(
        content: Text('Importación deshecha correctamente'),
        duration: Duration(seconds: 2),
      ));

      setState(() {
        _state = _ScanState.idle;
        _importResult = null;
        _transactions = [];
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Error al deshacer: $e'),
        backgroundColor: AppTheme.colorExpense,
      ));
    }
  }

  Future<void> _undoImportRecord(ImportRecord record) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = ref.read(accountServiceProvider);
      await service.undoImportBatch(
        cardAccountId: record.cardAccountId,
        transactionIds: record.transactionIds,
      );
      ref.read(importHistoryProvider.notifier).remove(record.id);

      messenger.showSnackBar(SnackBar(
        content: Text('Importación de ${record.cardName} deshecha'),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Error al deshacer: $e'),
        backgroundColor: AppTheme.colorExpense,
      ));
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.9,
      padding: const EdgeInsets.only(top: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF18181F),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Icon(Icons.document_scanner_rounded,
                        color: AppTheme.colorTransfer),
                    const SizedBox(width: 8),
                    Text(
                      'Escáner de Resúmenes',
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Seleccioná el PDF de tu resumen de tarjeta (Visa o Mastercard ICBC).',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildBody()),
            ],
          ),
          if (_state == _ScanState.parsing || _state == _ScanState.importing)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                child: const PdfProcessingOverlay(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _ScanState.idle:
      case _ScanState.parsing:
        return _buildIdle();
      case _ScanState.review:
        return _buildReview();
      case _ScanState.importing:
        return _buildIdle();
      case _ScanState.done:
        return _buildDone();
    }
  }

  // ─── Idle ─────────────────────────────────────────────────────────────────

  Widget _buildIdle() {
    final history = ref.watch(importHistoryProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.colorTransfer.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.picture_as_pdf_rounded,
                size: 56, color: AppTheme.colorTransfer),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            'Importá tu resumen',
            style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Seleccioná el PDF y la app detecta automáticamente\nel banco, la tarjeta y todos los gastos.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
          ),
        ),
        // Supported formats chips
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _FormatChip(label: 'Mastercard ICBC', icon: Icons.credit_card),
            const SizedBox(width: 8),
            _FormatChip(label: 'Visa ICBC', icon: Icons.credit_card),
          ],
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.colorExpense.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.colorExpense.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline,
                    color: AppTheme.colorExpense, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_errorMessage!,
                      style: TextStyle(
                          color: AppTheme.colorExpense, fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: _pickAndParse,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Seleccionar PDF',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.colorTransfer,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),

        // ─── Import History ─────────────────────────────────────────────
        if (history.isNotEmpty) ...[
          const SizedBox(height: 28),
          Row(
            children: [
              Icon(Icons.history_rounded,
                  size: 16, color: Colors.white.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text(
                'Importaciones anteriores',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final record in history) _buildHistoryItem(record),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _buildHistoryItem(ImportRecord record) {
    final dateStr = DateFormat('dd/MM/yy HH:mm').format(record.importDate);
    final monthNames = [
      '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    final periodLabel = '${monthNames[record.statementMonth]} ${record.statementYear}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.colorTransfer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.credit_card_rounded,
                size: 18, color: AppTheme.colorTransfer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        record.cardName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.colorTransfer.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        record.cardFormat == 'mastercardICBC'
                            ? 'MC'
                            : record.cardFormat == 'visaICBC'
                                ? 'VISA'
                                : record.cardFormat,
                        style: TextStyle(
                            color: AppTheme.colorTransfer,
                            fontSize: 9,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${record.importedTransactions} movimientos · ${formatAmount(record.totalAmount)}',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateStr  ·  $periodLabel',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 11),
                ),
              ],
            ),
          ),
          // Undo button for history items with stored transaction IDs
          if (record.transactionIds.isNotEmpty)
            GestureDetector(
              onTap: () => _undoImportRecord(record),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.colorExpense.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.undo_rounded,
                    size: 16, color: AppTheme.colorExpense.withValues(alpha: 0.6)),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Review ───────────────────────────────────────────────────────────────

  Widget _buildReview() {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final selectedCount = _transactions.where((t) => t.isSelected).length;
    final total = _transactions
        .where((t) => t.isSelected)
        .fold(0.0, (s, t) => s + t.amount);
    final installmentCount =
        _transactions.where((t) => t.isInstallment && t.isSelected).length;

    return Column(
      children: [
        // Resumen y selector de cuenta
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.colorTransfer.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _detectedBankName ?? (_detectedFormat == CardFormat.mastercardICBC
                            ? '🔵 Mastercard ICBC'
                            : _detectedFormat == CardFormat.visaICBC
                                ? '🟡 Visa ICBC'
                                : '❓ Formato desconocido'),
                        style: TextStyle(
                            color: AppTheme.colorTransfer,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (_detectedMonth != null && _detectedYear != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.colorIncome.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'][_detectedMonth!]} $_detectedYear',
                          style: TextStyle(
                              color: AppTheme.colorIncome,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      '$selectedCount / ${_transactions.length}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12),
                    ),
                  ],
                ),
                // Duplicate warning
                if (_duplicateWarning != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.colorWarning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.colorWarning.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.colorWarning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _duplicateWarning!,
                            style: TextStyle(color: AppTheme.colorWarning, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total a importar',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14)),
                    Text(formatAmount(total),
                        style: const TextStyle(
                            color: AppTheme.colorExpense,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                if (installmentCount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Cuotas incluidas',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12)),
                      Text('$installmentCount cuotas',
                          style: const TextStyle(
                              color: AppTheme.colorWarning,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
                if (_pagoMinimo != null || _saldoActual != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        if (_saldoActual != null && _saldoActual! > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Saldo del resumen',
                                    style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        fontSize: 12)),
                                Text('\$ ${formatAmount(_saldoActual!)}',
                                    style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        if (_pagoMinimo != null && _pagoMinimo! > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.info_outline_rounded,
                                      size: 14,
                                      color: Colors.white.withValues(alpha: 0.4)),
                                  const SizedBox(width: 6),
                                  Text('Pago mínimo',
                                      style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.5),
                                          fontSize: 12)),
                                ],
                              ),
                              Text('\$ ${formatAmount(_pagoMinimo!)}',
                                  style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                accountsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (accounts) {
                    final cards =
                        accounts.where((a) => a.isCreditCard).toList();
                    if (cards.isEmpty) return const SizedBox.shrink();
                    // Ensure selected card matches an existing item
                    final validId = cards.any((c) => c.id == _selectedCardId)
                        ? _selectedCardId
                        : cards.first.id;
                    if (_selectedCardId != validId) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _selectedCardId = validId);
                      });
                    }
                    return DropdownButtonFormField<String>(
                      initialValue: validId,
                      decoration: InputDecoration(
                        labelText: 'Importar a tarjeta',
                        labelStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF2A2A38),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                      dropdownColor: const Color(0xFF2A2A38),
                      style: const TextStyle(color: Colors.white),
                      items: cards
                          .map((a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(a.name),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedCardId = v);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // Lista agrupada: compras primero, luego cuotas
        Expanded(
          child: Builder(
            builder: (context) {
              final compras = <int>[];
              final cuotas = <int>[];
              for (var i = 0; i < _transactions.length; i++) {
                if (_transactions[i].isInstallment) {
                  cuotas.add(i);
                } else {
                  compras.add(i);
                }
              }

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Section: Compras del Mes
                  if (compras.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.shopping_bag_outlined,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.4)),
                          const SizedBox(width: 6),
                          Text(
                            'Compras del Mes',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('${compras.length}',
                                style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.4),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    for (final i in compras)
                      _TransactionReviewItem(
                        transaction: _transactions[i],
                        onToggle: (val) =>
                            setState(() => _transactions[i].isSelected = val),
                      ),
                  ],
                  // Section: Cuotas del Mes
                  if (cuotas.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month_outlined,
                              size: 14,
                              color: AppTheme.colorWarning
                                  .withValues(alpha: 0.6)),
                          const SizedBox(width: 6),
                          Text(
                            'Cuotas del Mes',
                            style: TextStyle(
                                color: AppTheme.colorWarning
                                    .withValues(alpha: 0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.colorWarning
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('${cuotas.length}',
                                style: TextStyle(
                                    color: AppTheme.colorWarning
                                        .withValues(alpha: 0.7),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    for (final i in cuotas)
                      _TransactionReviewItem(
                        transaction: _transactions[i],
                        onToggle: (val) =>
                            setState(() => _transactions[i].isSelected = val),
                      ),
                  ],
                ],
              );
            },
          ),
        ),

        // Botón importar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: selectedCount == 0 ? null : _import,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.colorTransfer,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Importar $selectedCount movimientos  ·  ${formatAmount(total)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Done ─────────────────────────────────────────────────────────────────

  Widget _buildDone() {
    final result = _importResult!;

    // Calculate month distribution
    final selected = _transactions.where((t) => t.isSelected).toList();
    final monthDist = <String, int>{};
    final monthNames = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    for (final tx in selected) {
      final label = '${monthNames[tx.date.month]} ${tx.date.year}';
      monthDist[label] = (monthDist[label] ?? 0) + 1;
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.colorIncome.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded,
                  size: 64, color: AppTheme.colorIncome),
            ),
            const SizedBox(height: 24),
            Text(
              '¡Importación exitosa!',
              style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              _importedCompras > 0 && _importedCuotas > 0
                  ? '$_importedCompras compras + $_importedCuotas cuotas importadas\nen ${result.cardName}.'
                  : '${result.imported} movimientos importados\nen ${result.cardName}.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 15),
            ),
            // Month distribution — show when transactions span multiple months
            if (monthDist.length > 1) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 14, color: Colors.white.withValues(alpha: 0.4)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        monthDist.entries.map((e) => '${e.value} en ${e.key}').join(' · '),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () {
                  // Calculate most common month from imported transactions
                  final selected = _transactions.where((t) => t.isSelected).toList();
                  final monthCounts = <String, int>{};
                  for (final tx in selected) {
                    final key = '${tx.date.year}-${tx.date.month}';
                    monthCounts[key] = (monthCounts[key] ?? 0) + 1;
                  }
                  int navMonth = _detectedMonth ?? DateTime.now().month;
                  int navYear = _detectedYear ?? DateTime.now().year;
                  if (monthCounts.isNotEmpty) {
                    final topKey = monthCounts.entries
                        .reduce((a, b) => a.value >= b.value ? a : b)
                        .key;
                    final parts = topKey.split('-');
                    navYear = int.parse(parts[0]);
                    navMonth = int.parse(parts[1]);
                  }
                  Navigator.pop(context, {
                    'action': 'show_detail',
                    'month': navMonth,
                    'year': navYear,
                    'cardId': _selectedCardId,
                  });
                },
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Ver movimientos importados'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.colorTransfer,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.assessment_outlined),
                label: const Text('Volver al resumen'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.colorTransfer,
                  side: BorderSide(
                      color: AppTheme.colorTransfer.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Undo button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () => _undoLastImport(),
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: const Text('Deshacer importación'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.colorExpense,
                  side: BorderSide(
                      color: AppTheme.colorExpense.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cerrar',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45))),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Item de revisión ─────────────────────────────────────────────────────

class _TransactionReviewItem extends StatelessWidget {
  const _TransactionReviewItem({
    required this.transaction,
    required this.onToggle,
  });

  final ParsedTransaction transaction;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yy').format(transaction.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: transaction.isSelected
            ? const Color(0xFF1E1E2C)
            : const Color(0xFF1A1A22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: transaction.isSelected
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.03),
        ),
      ),
      child: InkWell(
        onTap: () => onToggle(!transaction.isSelected),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Checkbox
              Checkbox(
                value: transaction.isSelected,
                onChanged: (v) => onToggle(v ?? false),
                activeColor: AppTheme.colorTransfer,
                side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),

              // Fecha
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(dateStr,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white60)),
              ),
              const SizedBox(width: 10),

              // Descripción + categoría
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description,
                      style: TextStyle(
                        color: transaction.isSelected
                            ? Colors.white
                            : Colors.white38,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: GestureDetector(
                            onTap: () => _showCategoryPicker(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.colorTransfer.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                transaction.suggestedCategoryName,
                                style: TextStyle(
                                    color: AppTheme.colorTransfer
                                        .withValues(alpha: 0.8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        if (transaction.isInstallment) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.colorWarning
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              transaction.installmentLabel,
                              style: const TextStyle(
                                  color: AppTheme.colorWarning,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Monto
              Text(
                formatAmount(transaction.amount),
                style: TextStyle(
                  color: transaction.isSelected
                      ? AppTheme.colorExpense
                      : AppTheme.colorExpense.withValues(alpha: 0.4),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategoryPicker(BuildContext context) {
    // Categories list based on PdfParserService keywords
    final categories = [
      {'id': 'cat_alim', 'name': 'Alimentación'},
      {'id': 'cat_super', 'name': 'Supermercado'},
      {'id': 'cat_entret', 'name': 'Entretenimiento'},
      {'id': 'cat_transp', 'name': 'Transporte'},
      {'id': 'cat_salud', 'name': 'Salud'},
      {'id': 'cat_hogar', 'name': 'Hogar'},
      {'id': 'cat_tecno', 'name': 'Tecnología'},
      {'id': 'cat_ropa', 'name': 'Ropa'},
      {'id': 'cat_otros_gasto', 'name': 'Otros alimentos'},
      {'id': 'cat_finanzas', 'name': 'Finanzas'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: categories.length,
          itemBuilder: (context, i) => ListTile(
            leading: const Icon(Icons.category_outlined, color: AppTheme.colorTransfer),
            title: Text(categories[i]['name']!, style: const TextStyle(color: Colors.white, fontSize: 14)),
            onTap: () {
              // Update transaction and trigger rebuild via onToggle
              transaction.suggestedCategoryId = categories[i]['id']!;
              transaction.suggestedCategoryName = categories[i]['name']!;
              onToggle(transaction.isSelected);
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _FormatChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.4)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }
}
