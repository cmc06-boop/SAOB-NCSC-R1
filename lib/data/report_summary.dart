import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../core/format.dart';
import 'models.dart';

const summarySelection = '__SUMMARY__';

const summaryHeaders = [
  'PAP',
  'ALLOTMENT',
  'OBLIGATION',
  'UNOBLIGATED ALLOTMENT',
  'UTILIZATION RATE',
  'DISBURSEMENT',
  'DISB %',
];

class SaobSummaryRow {
  const SaobSummaryRow(this.program, this.totals);
  final String program;
  final Totals totals;
}

class SaobSummarySection {
  const SaobSummarySection(this.fund, this.rows, this.totals);
  final String fund;
  final List<SaobSummaryRow> rows;
  final Totals totals;

  String get title => fund == 'CONTINUING' ? 'CONTINUING APPRO' : 'CURRENT APPRO';
}

/// Matches the uploaded SAOB SUMMARY sheet: current/continuing groups,
/// one PAP row per program, then a TOTAL for each appropriation type.
List<SaobSummarySection> saobSummarySections(
  Iterable<BudgetRecord> records,
) {
  final sections = <SaobSummarySection>[];
  final source = records.toList();
  for (final fund in ['CURRENT', 'CONTINUING']) {
    final programs = <String, List<BudgetRecord>>{};
    for (final row in source.where((row) => row.fund == fund)) {
      programs.putIfAbsent(row.program, () => []).add(row);
    }
    if (programs.isEmpty) continue;
    final codes = programs.keys.toList()..sort();
    sections.add(
      SaobSummarySection(
        fund,
        [for (final code in codes) SaobSummaryRow(code, Totals(programs[code]!))],
        Totals([for (final code in codes) ...programs[code]!]),
      ),
    );
  }
  return sections;
}

List<String> summaryDisplayRow(String name, Totals t) => [
  name,
  money(t.allotment),
  money(t.obligation),
  money(t.balance),
  // The source SUMMARY worksheet displays 0.00% for zero denominators.
  t.allotment == 0 ? '0.00%' : rate(t.obligation, t.allotment),
  money(t.disbursement),
  t.obligation == 0 ? '0.00%' : rate(t.disbursement, t.obligation),
];

/// Standalone SUMMARY Excel workbook for printing or further review.
Uint8List excelSaobSummaryReport(
  List<BudgetRecord> records, {
  required int year,
}) {
  final book = Excel.createExcel();
  if (book.tables.containsKey('Sheet1')) book.rename('Sheet1', 'SUMMARY');
  final sheet = book['SUMMARY'];
  sheet.setColumnWidth(0, 18);
  for (var i = 1; i < 7; i++) {
    sheet.setColumnWidth(i, i == 3 ? 28 : 20);
  }
  final navy = ExcelColor.fromHexString('#173C80');
  final pale = ExcelColor.fromHexString('#EEF3FB');
  final totalFill = ExcelColor.fromHexString('#E7EEFC');
  final ink = ExcelColor.fromHexString('#132951');
  final currencyFormat = NumFormat.custom(formatCode: '#,##0.00');
  final rateFormat = NumFormat.custom(formatCode: '0.00%');

  void put(
    int row,
    int col,
    CellValue value, {
    bool heading = false,
    bool section = false,
    bool total = false,
  }) {
    final target = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    target.value = value;
    target.cellStyle = CellStyle(
      bold: heading || section || total,
      fontColorHex: section ? ExcelColor.white : ink,
      backgroundColorHex: section ? navy : total ? totalFill : heading ? pale : ExcelColor.none,
      horizontalAlign: col == 0 ? HorizontalAlign.Left : HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      numberFormat: col == 4 || col == 6
          ? rateFormat
          : col == 0
          ? NumFormat.standard_0
          : currencyFormat,
    );
  }

  var at = 0;
  for (final section in saobSummarySections(records)) {
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: at),
      CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: at),
    );
    put(at++, 0, TextCellValue(section.title), section: true);
    for (var col = 0; col < summaryHeaders.length; col++) {
      put(at, col, TextCellValue(summaryHeaders[col]), heading: true);
    }
    at++;

    void row(String name, Totals totals, {bool total = false}) {
      put(at, 0, TextCellValue(name), total: total);
      for (final (col, amount) in [
        (1, totals.allotment),
        (2, totals.obligation),
        (3, totals.balance),
        (5, totals.disbursement),
      ]) {
        put(at, col, DoubleCellValue(amount / 100), total: total);
      }
      put(
        at,
        4,
        DoubleCellValue(
          totals.allotment == 0 ? 0 : totals.obligation / totals.allotment,
        ),
        total: total,
      );
      put(
        at,
        6,
        DoubleCellValue(
          totals.obligation == 0 ? 0 : totals.disbursement / totals.obligation,
        ),
        total: total,
      );
      at++;
    }

    for (final entry in section.rows) {
      row(entry.program, entry.totals);
    }
    row('TOTAL', section.totals, total: true);
    // One blank row between sections, like the source SUMMARY worksheet.
    at += 1;
  }
  book.setDefaultSheet('SUMMARY');
  final encoded = book.encode();
  if (encoded == null || encoded.isEmpty) {
    throw const FinanceError('Could not create the summary Excel report.');
  }
  return Uint8List.fromList(encoded);
}
