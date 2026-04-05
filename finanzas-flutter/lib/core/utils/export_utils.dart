import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';


/// Generates a monthly financial report PDF and returns the file path.
Future<String> generateMonthlyReportPdf({
  required int year,
  required int month,
  required double totalIncome,
  required double totalExpense,
  required Map<String, double> categoryTotals,
  required Map<String, double> accountTotals,
  required List<dynamic> transactions,
  Map<String, String>? categoryNames,
  Map<String, String>? accountNames,
  List<InstallmentInfo>? installments,
}) async {
  final document = PdfDocument();
  document.pageSettings.size = PdfPageSize.a4;
  document.pageSettings.margins.all = 40;

  final page = document.pages.add();
  final graphics = page.graphics;
  final pageWidth = page.getClientSize().width;
  double y = 0;

  // ─── Fonts ───
  final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 22, style: PdfFontStyle.bold);
  final subtitleFont = PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold);
  final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 11);
  final bodyBoldFont = PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);
  final smallFont = PdfStandardFont(PdfFontFamily.helvetica, 9);

  final monthName = DateFormat('MMMM yyyy', 'es').format(DateTime(year, month));
  final capitalizedMonth = '${monthName[0].toUpperCase()}${monthName.substring(1)}';

  // ─── Header ───
  graphics.drawRectangle(
    brush: PdfSolidBrush(PdfColor(30, 30, 44)),
    bounds: Rect.fromLTWH(0, y, pageWidth, 60),
  );
  graphics.drawString(
    'Resumen Mensual — $capitalizedMonth',
    titleFont,
    bounds: Rect.fromLTWH(16, y + 16, pageWidth - 32, 30),
    brush: PdfSolidBrush(PdfColor(255, 255, 255)),
  );
  y += 70;

  graphics.drawString(
    'Generado por Fint · ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
    smallFont,
    bounds: Rect.fromLTWH(0, y, pageWidth, 14),
    brush: PdfSolidBrush(PdfColor(140, 140, 160)),
  );
  y += 24;

  // ─── Balance Section ───
  final balance = totalIncome - totalExpense;
  graphics.drawString('Balance General', subtitleFont, bounds: Rect.fromLTWH(0, y, pageWidth, 20));
  y += 26;

  // Balance boxes
  final boxWidth = (pageWidth - 20) / 3;
  _drawBalanceBox(graphics, 0, y, boxWidth, 'Ingresos', totalIncome, PdfColor(76, 175, 80));
  _drawBalanceBox(graphics, boxWidth + 10, y, boxWidth, 'Gastos', totalExpense, PdfColor(239, 83, 80));
  _drawBalanceBox(graphics, (boxWidth + 10) * 2, y, boxWidth, 'Balance', balance, balance >= 0 ? PdfColor(76, 175, 80) : PdfColor(239, 83, 80));
  y += 60;

  // ─── Categories Section ───
  if (categoryTotals.isNotEmpty) {
    y += 10;
    graphics.drawString('Gastos por Categoría', subtitleFont, bounds: Rect.fromLTWH(0, y, pageWidth, 20));
    y += 28;

    final sortedCats = categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final totalCatExpense = sortedCats.fold(0.0, (s, e) => s + e.value);

    // Table header
    graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(40, 40, 56)),
      bounds: Rect.fromLTWH(0, y, pageWidth, 20),
    );
    graphics.drawString('Categoría', bodyBoldFont, bounds: Rect.fromLTWH(8, y + 3, 200, 16), brush: PdfSolidBrush(PdfColor(200, 200, 220)));
    graphics.drawString('Monto', bodyBoldFont, bounds: Rect.fromLTWH(pageWidth - 200, y + 3, 90, 16), brush: PdfSolidBrush(PdfColor(200, 200, 220)), format: PdfStringFormat(alignment: PdfTextAlignment.right));
    graphics.drawString('%', bodyBoldFont, bounds: Rect.fromLTWH(pageWidth - 60, y + 3, 52, 16), brush: PdfSolidBrush(PdfColor(200, 200, 220)), format: PdfStringFormat(alignment: PdfTextAlignment.right));
    y += 22;

    for (final entry in sortedCats) {
      if (y > page.getClientSize().height - 60) break; // Page overflow protection
      final catName = categoryNames?[entry.key] ?? _cleanCatId(entry.key);
      final pct = totalCatExpense > 0 ? (entry.value / totalCatExpense * 100) : 0.0;

      // Alternating row color
      if (sortedCats.indexOf(entry) % 2 == 0) {
        graphics.drawRectangle(
          brush: PdfSolidBrush(PdfColor(245, 245, 250)),
          bounds: Rect.fromLTWH(0, y, pageWidth, 18),
        );
      }

      graphics.drawString(catName, bodyFont, bounds: Rect.fromLTWH(8, y + 2, 200, 16));
      graphics.drawString(
        _fmtAmount(entry.value),
        bodyFont,
        bounds: Rect.fromLTWH(pageWidth - 200, y + 2, 90, 16),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );
      graphics.drawString(
        '${pct.toStringAsFixed(1)}%',
        smallFont,
        bounds: Rect.fromLTWH(pageWidth - 60, y + 2, 52, 16),
        brush: PdfSolidBrush(PdfColor(120, 120, 140)),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );
      y += 18;
    }
  }

  // ─── Accounts Section ───
  if (accountTotals.isNotEmpty) {
    y += 16;
    if (y > page.getClientSize().height - 120) {
      // Add new page if needed
      document.pages.add();
      y = 0;
    }
    graphics.drawString('Gastos por Cuenta', subtitleFont, bounds: Rect.fromLTWH(0, y, pageWidth, 20));
    y += 28;

    for (final entry in accountTotals.entries) {
      if (y > page.getClientSize().height - 40) break;
      final accName = accountNames?[entry.key] ?? entry.key;
      graphics.drawString(accName, bodyFont, bounds: Rect.fromLTWH(8, y, 250, 16));
      graphics.drawString(
        _fmtAmount(entry.value),
        bodyBoldFont,
        bounds: Rect.fromLTWH(pageWidth - 150, y, 142, 16),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );
      y += 20;
    }
  }

  // ─── Cuotas Pendientes Section ───
  if (installments != null && installments.isNotEmpty) {
    y += 16;
    if (y > page.getClientSize().height - 140) {
      final newPage = document.pages.add();
      // ignore: parameter_assignments
      // We need to draw on the new page now
      final newGraphics = newPage.graphics;
      double ny = 0;
      _drawInstallmentsSection(newGraphics, pageWidth, ny, subtitleFont, bodyFont, bodyBoldFont, smallFont, installments);
    } else {
      _drawInstallmentsSection(graphics, pageWidth, y, subtitleFont, bodyFont, bodyBoldFont, smallFont, installments);
    }
  }

  // ─── Footer ───
  graphics.drawString(
    'Fint — Tu finanzas personales',
    smallFont,
    bounds: Rect.fromLTWH(0, page.getClientSize().height - 20, pageWidth, 14),
    brush: PdfSolidBrush(PdfColor(160, 160, 180)),
    format: PdfStringFormat(alignment: PdfTextAlignment.center),
  );

  // ─── Save ───
  final bytes = await document.save();
  document.dispose();

  // Prefer Downloads (external storage) for easier user access; fallback to app docs.
  Directory? dir = await getExternalStorageDirectory();
  if (dir != null) {
    // Navigate from app-specific external dir to the Downloads folder.
    final downloadDir = Directory('${dir.path.split('Android')[0]}Download');
    if (await downloadDir.exists()) {
      dir = downloadDir;
    }
  }
  dir ??= await getApplicationDocumentsDirectory();
  final fileName = 'Fint_Resumen_${capitalizedMonth.replaceAll(' ', '_')}.pdf';
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);

  return file.path;
}

void _drawBalanceBox(PdfGraphics graphics, double x, double y, double w, String label, double amount, PdfColor color) {
  graphics.drawRectangle(
    brush: PdfSolidBrush(PdfColor(248, 248, 252)),
    bounds: Rect.fromLTWH(x, y, w, 48),
  );
  graphics.drawRectangle(
    brush: PdfSolidBrush(color),
    bounds: Rect.fromLTWH(x, y, 3, 48),
  );
  final labelFont = PdfStandardFont(PdfFontFamily.helvetica, 9);
  final valueFont = PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold);
  graphics.drawString(label, labelFont, bounds: Rect.fromLTWH(x + 10, y + 6, w - 16, 12), brush: PdfSolidBrush(PdfColor(120, 120, 140)));
  graphics.drawString(_fmtAmount(amount), valueFont, bounds: Rect.fromLTWH(x + 10, y + 22, w - 16, 20));
}

String _fmtAmount(double amount) {
  final negative = amount < 0;
  final abs = amount.abs();
  final formatter = NumberFormat('#,##0', 'es_AR');
  return '${negative ? '-' : ''}\$${formatter.format(abs)}';
}

String _cleanCatId(String id) {
  final clean = id.replaceAll('cat_', '').replaceAll('_', ' ');
  return clean.isEmpty ? 'Otro' : '${clean[0].toUpperCase()}${clean.substring(1)}';
}

void _drawInstallmentsSection(
  PdfGraphics graphics,
  double pageWidth,
  double y,
  PdfFont subtitleFont,
  PdfFont bodyFont,
  PdfFont bodyBoldFont,
  PdfFont smallFont,
  List<InstallmentInfo> installments,
) {
  graphics.drawString('Cuotas Pendientes', subtitleFont, bounds: Rect.fromLTWH(0, y, pageWidth, 20));
  y += 28;

  final totalDebt = installments.fold(0.0, (s, i) => s + i.remainingAmount);
  final monthlyObligation = installments.fold(0.0, (s, i) => s + i.monthlyAmount);

  // Summary boxes
  final boxW = (pageWidth - 10) / 2;
  _drawBalanceBox(graphics, 0, y, boxW, 'Deuda total cuotas', totalDebt, PdfColor(255, 152, 0));
  _drawBalanceBox(graphics, boxW + 10, y, boxW, 'Cuota mensual', monthlyObligation, PdfColor(255, 152, 0));
  y += 58;

  // Table header
  graphics.drawRectangle(
    brush: PdfSolidBrush(PdfColor(40, 40, 56)),
    bounds: Rect.fromLTWH(0, y, pageWidth, 20),
  );
  graphics.drawString('Descripción', bodyBoldFont, bounds: Rect.fromLTWH(8, y + 3, 200, 16), brush: PdfSolidBrush(PdfColor(200, 200, 220)));
  graphics.drawString('Cuota', bodyBoldFont, bounds: Rect.fromLTWH(220, y + 3, 80, 16), brush: PdfSolidBrush(PdfColor(200, 200, 220)));
  graphics.drawString('Monto/cuota', bodyBoldFont, bounds: Rect.fromLTWH(310, y + 3, 90, 16), brush: PdfSolidBrush(PdfColor(200, 200, 220)), format: PdfStringFormat(alignment: PdfTextAlignment.right));
  graphics.drawString('Restante', bodyBoldFont, bounds: Rect.fromLTWH(pageWidth - 100, y + 3, 92, 16), brush: PdfSolidBrush(PdfColor(200, 200, 220)), format: PdfStringFormat(alignment: PdfTextAlignment.right));
  y += 22;

  for (var i = 0; i < installments.length; i++) {
    final inst = installments[i];
    if (i % 2 == 0) {
      graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(245, 245, 250)),
        bounds: Rect.fromLTWH(0, y, pageWidth, 18),
      );
    }
    graphics.drawString(inst.description, bodyFont, bounds: Rect.fromLTWH(8, y + 2, 210, 16));
    graphics.drawString('${inst.currentInstallment}/${inst.totalInstallments}', bodyFont, bounds: Rect.fromLTWH(220, y + 2, 80, 16));
    graphics.drawString(_fmtAmount(inst.monthlyAmount), bodyFont, bounds: Rect.fromLTWH(310, y + 2, 90, 16), format: PdfStringFormat(alignment: PdfTextAlignment.right));
    graphics.drawString(
      _fmtAmount(inst.remainingAmount),
      bodyFont,
      bounds: Rect.fromLTWH(pageWidth - 100, y + 2, 92, 16),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
      brush: PdfSolidBrush(PdfColor(239, 83, 80)),
    );
    y += 18;
  }
}

/// Data class for installment info to include in PDF export.
class InstallmentInfo {
  final String description;
  final int currentInstallment;
  final int totalInstallments;
  final double monthlyAmount;
  final double remainingAmount;

  const InstallmentInfo({
    required this.description,
    required this.currentInstallment,
    required this.totalInstallments,
    required this.monthlyAmount,
    required this.remainingAmount,
  });
}
