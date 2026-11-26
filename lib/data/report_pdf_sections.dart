import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'models.dart';
import 'report_io.dart';
import 'report_summary.dart';

/// For All Programs, create a single PDF with a new page for each program.
/// Each program contains separate CURRENT/CONTINUING tables and its own total.
Future<Uint8List> pdfAllProgramsReport(
  List<BudgetRecord> records, {
  required int year,
  PdfPageFormat pageFormat = PdfPageFormat.a4,
}) async {
  final assets = await _loadAssets();
  final doc = pw.Document();
  // One continuous table and its built-in TOTAL row per program.
  // Each program starts in a new PDF section/page within the same file.
  final groups = <String, List<BudgetRecord>>{};
  for (final row in records) {
    groups.putIfAbsent(row.program, () => []).add(row);
  }
  final programs = groups.keys.toList()..sort();
  for (final program in programs) {
    final programRows = groups[program]!;
    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat.landscape,
        margin: const pw.EdgeInsets.all(24),
        maxPages: 2000,
        theme: pw.ThemeData.withFont(base: assets.$1, bold: assets.$2),
        header: (_) => _letterhead(assets.$3, year, 'Program: $program'),
        build: (_) => [
          _programTable(
            reportData('Budget Utilization Report', programRows),
            program,
            assets.$2,
          ),
        ],
      ),
    );
  }
  return doc.save();
}

/// Summary PDF mirrors the uploaded workbook's CURRENT APPRO and CONTINUING
/// APPRO sections, with a TOTAL line for each section.
Future<Uint8List> pdfSaobSummaryReport(
  List<BudgetRecord> records, {
  required int year,
  PdfPageFormat pageFormat = PdfPageFormat.a4,
}) async {
  final assets = await _loadAssets();
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: pageFormat.landscape,
      margin: const pw.EdgeInsets.all(24),
      maxPages: 2000,
      theme: pw.ThemeData.withFont(base: assets.$1, bold: assets.$2),
      header: (_) => _letterhead(assets.$3, year, 'SUMMARY'),
      build: (_) => [
        for (final section in saobSummarySections(records)) ...[
          // The section name is a table label, not a separate report title.
          // Keep it directly attached to the corresponding table.
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Center(
                  child: pw.Text(
                    section.title,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
              pw.TableHelper.fromTextArray(
                headers: summaryHeaders,
                data: [
                  for (final row in section.rows)
                    summaryDisplayRow(row.program, row.totals),
                  summaryDisplayRow('TOTAL', section.totals),
                ],
                headerStyle: pw.TextStyle(
                  font: assets.$2,
                  fontSize: 8,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xff173c80),
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellPadding: const pw.EdgeInsets.all(6),
                cellAlignments: {
                  for (var i = 1; i < summaryHeaders.length; i++)
                    i: pw.Alignment.centerRight,
                },
                oddRowDecoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xfff0f4fb),
                ),
                border: pw.TableBorder.all(
                  color: PdfColors.blueGrey200,
                  width: 0.3,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
        ],
      ],
    ),
  );
  return doc.save();
}

Future<(pw.Font, pw.Font, ReportLetterhead)> _loadAssets() async {
  // In Flutter widget tests, asset loads can complete synchronously.
  // Await each asset individually instead of passing these futures to
  // Future.wait, which can produce an empty result with SynchronousFuture.
  final regular = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
  final bold = await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf');
  final letterhead = await ReportLetterhead.load();
  return (
    pw.Font.ttf(regular),
    pw.Font.ttf(bold),
    letterhead,
  );
}

pw.Widget _letterhead(ReportLetterhead letterhead, int year, String heading) =>
    pw.Column(
      children: [
        letterhead.build(),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text(
            heading,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Fiscal Year: $year',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700),
        ),
        pw.SizedBox(height: 10),
      ],
    );

pw.Widget _programTable(
  ReportData data,
  String program,
  pw.Font bold,
) => pw.TableHelper.fromTextArray(
  headers: data.headers,
  data: [
    for (final row in data.rows)
      [
        for (var col = 0; col < row.length; col++)
          row.length > 2 && row[2].toString() == 'Total' && col == 2
              ? 'TOTAL ($program)'
              : data.display(row[col], col),
      ],
  ],
  headerStyle: pw.TextStyle(font: bold, fontSize: 7, color: PdfColors.white),
  headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xff173c80)),
  cellStyle: const pw.TextStyle(fontSize: 7),
  cellPadding: const pw.EdgeInsets.all(4),
  cellAlignments: {
    for (final col in {...data.moneyColumns, ...data.rateColumns})
      col: pw.Alignment.centerRight,
  },
  oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xfff0f4fb)),
  border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.3),
);
