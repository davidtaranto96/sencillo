import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/database_providers.dart';
import '../../../../core/logic/account_service.dart';
import '../../../../core/logic/pdf_parser_service.dart';
import '../../../../core/models/parsed_transaction.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../shared/widgets/pdf_processing_overlay.dart';

// ─── Estados del flujo ────────────────────────────────────────────────────

enum _ScanState { idle, parsing, review, importing, done }

// ─── Bottom Sheet ─────────────────────────────────────────────────────────

class StatementScannerBottomSheet extends ConsumerStatefulWidget {
  const StatementScannerBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
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
  String _selectedCardId = 'mc_credit';
  ImportResult? _importResult;
  String? _errorMessage;

  // ─── Lógica central ──────────────────────────────────────────────────────

  Future<void> _pickAndParse() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

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

      if (_detectedFormat == CardFormat.visaICBC) {
        _selectedCardId = 'visa_credit';
      } else if (_detectedFormat == CardFormat.mastercardICBC) {
        _selectedCardId = 'mc_credit';
      }

      if (parsed.isEmpty) {
        setState(() {
          _errorMessage = 'No se encontraron transacciones en este PDF.\n'
              'Asegurate de seleccionar un resumen de Visa o Mastercard ICBC.';
          _state = _ScanState.idle;
        });
        return;
      }

      setState(() {
        _transactions = parsed;
        _state = _ScanState.review;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al procesar el PDF: ${e.toString()}';
        _state = _ScanState.idle;
      });
    }
  }

  Future<void> _import() async {
    setState(() => _state = _ScanState.importing);
    try {
      final service = ref.read(accountServiceProvider);
      final result = await service.importStatementTransactions(
        cardAccountId: _selectedCardId,
        transactions: _transactions,
      );
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.colorTransfer.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.picture_as_pdf_rounded,
                  size: 64, color: AppTheme.colorTransfer),
            ),
            const SizedBox(height: 28),
            Text(
              'Importá tu resumen',
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'La app parsea el PDF, detecta todos los gastos\ny los importa automáticamente con categorías.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 20),
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
            const SizedBox(height: 32),
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
            const SizedBox(height: 12),
            Text(
              'Soporta: Visa ICBC · Mastercard ICBC',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
            ),
          ],
        ),
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
                        _detectedFormat == CardFormat.mastercardICBC
                            ? '🔵 Mastercard ICBC'
                            : _detectedFormat == CardFormat.visaICBC
                                ? '🟡 Visa ICBC'
                                : '❓ Formato desconocido',
                        style: TextStyle(
                            color: AppTheme.colorTransfer,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$selectedCount / ${_transactions.length}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12),
                    ),
                  ],
                ),
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
                const SizedBox(height: 12),
                accountsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (accounts) {
                    final cards =
                        accounts.where((a) => a.isCreditCard).toList();
                    if (cards.isEmpty) return const SizedBox.shrink();
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedCardId,
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

        // Lista
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _transactions.length,
            itemBuilder: (context, i) {
              final tx = _transactions[i];
              return _TransactionReviewItem(
                transaction: tx,
                onToggle: (val) =>
                    setState(() => _transactions[i].isSelected = val),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
              '${result.imported} movimientos importados\nen ${result.cardName}.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 15),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/transactions');
                },
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Ver en Movimientos'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.colorTransfer,
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
                        GestureDetector(
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
