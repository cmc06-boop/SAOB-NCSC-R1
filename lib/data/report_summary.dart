import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../core/format.dart';
import 'excel_formula_cache.dart';
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

/// A worksheet such as ATOP-REG_CONT is imported as program
/// ATOP_Continuing while keeping fund_source=CURRENT for DB compatibility.
/// For summaries, the program suffix is the authoritative appropriation type.
/// Manually encoded programs without that suffix still use their fund source.
(String, String) summaryProgramAndFund(String program, String fund) {
  final readable = readableProgramCode(program);
  if (readable == null) return (program, fund);
  if (readable.endsWith('_Continuing')) {
    return (
      readable.substring(0, readable.length - '_Continuing'.length),
      'CONTINUING',
    );
  }
  return (
    readable.substring(0, readable.length - '_Current'.length),
    'CURRENT',
  );
}

/// Matches the reference workbook: one CURRENT APPRO table and one
/// CONTINUING APPRO table, each with its own PAP rows and subtotal.
List<SaobSummarySection> saobSummarySections(
  Iterable<BudgetRecord> records,
) {
  final byFund = <String, Map<String, List<BudgetRecord>>>{
    'CURRENT': {},
    'CONTINUING': {},
  };
  for (final record in records) {
    final (code, fund) = summaryProgramAndFund(record.program, record.fund);
    if (!byFund.containsKey(fund)) continue;
    byFund[fund]!.putIfAbsent(code, () => []).add(record);
  }

  // Follow the PAP order in the uploaded SUMMARY worksheet.
  const sourceOrder = ['GAS', 'PPD', 'SECADNA', 'ECA', 'ATOP'];
  int rank(String code) {
    final pos = sourceOrder.indexOf(code.toUpperCase());
    return pos < 0 ? sourceOrder.length : pos;
  }

  final sections = <SaobSummarySection>[];
  for (final fund in ['CURRENT', 'CONTINUING']) {
    final programs = byFund[fund]!;
    if (programs.isEmpty) continue;
    final codes = programs.keys.toList()
      ..sort((a, b) {
        final order = rank(a).compareTo(rank(b));
        return order != 0 ? order : a.compareTo(b);
      });
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

/// Standalone SUMMARY workbook. All amounts that users enter are numeric;
/// balances, utilization rates, disbursement rates and section totals are
/// Excel formulas, so they update automatically when the workbook is edited.
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
  final totalFill = ExcelColor.fromHexString('#E7EEFC');
  final ink = ExcelColor.fromHexString('#132951');
  final currencyFormat = NumFormat.custom(formatCode: '#,##0.00');
  final rateFormat = NumFormat.custom(formatCode: '0.00%');
  final cached = <String, String>{};

  void put(
    int row,
    int col,
    CellValue value, {
    bool heading = false,
    bool section = false,
    bool title = false,
    bool total = false,
  }) {
    final target = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    target.value = value;
    target.cellStyle = CellStyle(
      bold: heading || section || title || total,
      fontFamily: 'Arial',
      fontSize: 10,
      fontColorHex: heading ? ExcelColor.white : ink,
      // Section titles stay centered on white, without a colored background.
      backgroundColorHex: total
          ? totalFill
          : heading
          ? navy
          : ExcelColor.none,
      horizontalAlign: section || title || heading
          ? HorizontalAlign.Center
          : col == 0
          ? HorizontalAlign.Left
          : HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      textWrapping: heading ? TextWrapping.WrapText : null,
      numberFormat: col == 4 || col == 6
          ? rateFormat
          : col == 0
          ? NumFormat.standard_0
          : currencyFormat,
    );
  }

  // FormulaCellValue keeps formulas editable, and the cached result makes the
  // initial numbers readable in viewers that do not recalculate immediately.
  void formula(
    int row,
    int col,
    String expression,
    num initialValue, {
    bool total = false,
  }) {
    put(row, col, FormulaCellValue(expression), total: total);
    cached['${String.fromCharCode(65 + col)}${row + 1}'] =
        initialValue.toString();
  }

  for (final (row, label) in [
    (0, 'NATIONAL COMMISSION OF SENIOR CITIZENS'),
    (1, 'REGION I'),
    (2, 'SUMMARY  |  FISCAL YEAR $year'),
  ]) {
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row),
    );
    put(row, 0, TextCellValue(label), title: true);
    sheet.setRowHeight(row, 20);
  }

  var at = 4;
  for (final section in saobSummarySections(records)) {
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: at),
      CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: at),
    );
    put(at++, 0, TextCellValue(section.title), section: true);
    sheet.setRowHeight(at, 30);
    for (var col = 0; col < summaryHeaders.length; col++) {
      put(at, col, TextCellValue(summaryHeaders[col]), heading: true);
    }
    at++;

    final firstDataExcel = at + 1;

    for (final entry in section.rows) {
      final t = entry.totals;
      final excelRow = at + 1;
      put(at, 0, TextCellValue(entry.program));
      put(at, 1, DoubleCellValue(t.allotment / 100));
      put(at, 2, DoubleCellValue(t.obligation / 100));
      formula(at, 3, 'B$excelRow-C$excelRow', t.balance / 100);
      formula(
        at,
        4,
        'IF(B$excelRow=0,0,C$excelRow/B$excelRow)',
        t.allotment == 0 ? 0 : t.obligation / t.allotment,
      );
      put(at, 5, DoubleCellValue(t.disbursement / 100));
      formula(
        at,
        6,
        'IF(C$excelRow=0,0,F$excelRow/C$excelRow)',
        t.obligation == 0 ? 0 : t.disbursement / t.obligation,
      );
      at++;
    }

    final total = section.totals;
    final excelRow = at + 1;
    final lastDataExcel = at;
    put(at, 0, TextCellValue('TOTAL'), total: true);

    for (final (col, amount) in [
      (1, total.allotment),
      (2, total.obligation),
      (5, total.disbursement),
    ]) {
      final letter = String.fromCharCode(65 + col);
      formula(
        at,
        col,
        'SUM($letter$firstDataExcel:$letter$lastDataExcel)',
        amount / 100,
        total: true,
      );
    }
    formula(
      at,
      3,
      'B$excelRow-C$excelRow',
      total.balance / 100,
      total: true,
    );
    formula(
      at,
      4,
      'IF(B$excelRow=0,0,C$excelRow/B$excelRow)',
      total.allotment == 0 ? 0 : total.obligation / total.allotment,
      total: true,
    );
    formula(
      at,
      6,
      'IF(C$excelRow=0,0,F$excelRow/C$excelRow)',
      total.obligation == 0 ? 0 : total.disbursement / total.obligation,
      total: true,
    );
    // Keep one blank row between Current and Continuing tables.
    at += 2;
  }

  book.setDefaultSheet('SUMMARY');
  final encoded = book.encode();
  if (encoded == null || encoded.isEmpty) {
    throw const FinanceError('Could not create the summary Excel report.');
  }
  return excelWithCachedFormulas(
    Uint8List.fromList(encoded),
    {'SUMMARY': cached},
  );
}
