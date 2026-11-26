import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/format.dart';
import 'models.dart';
import 'excel_formula_cache.dart';
import 'report_summary.dart';

const reportTypes = [
  'Budget Utilization Report',
  'Obligation Status Report',
  'Program Budget Report',
];

class ReportData {
  const ReportData(
    this.headers,
    this.rows,
    this.moneyColumns,
    this.rateColumns,
  );
  final List<String> headers;
  final List<List<Object>> rows;
  final Set<int> moneyColumns, rateColumns;
  String display(Object value, int column) {
    if (value is num && moneyColumns.contains(column)) {
      return money((value * 100).round());
    }
    if (value is num && rateColumns.contains(column)) {
      return '${(value * 100).toStringAsFixed(2)}%';
    }
    return value.toString();
  }
}

ReportData reportData(String type, List<BudgetRecord> records) {
  final t = Totals(records);
  double ratio(int a, int b) => b == 0 ? 0 : a / b;
  if (type == 'Program Budget Report') {
    final groups = <String, List<BudgetRecord>>{};
    for (final r in records) {
      groups.putIfAbsent('${r.program}/${r.fund}', () => []).add(r);
    }
    List<Object> totalRow(String p, String f, Totals t) => [
      p,
      f,
      t.allotment / 100,
      t.obligation / 100,
      t.disbursement / 100,
      t.balance / 100,
      ratio(t.obligation, t.allotment),
    ];
    return ReportData(
      [
        'Program',
        'Fund Source',
        'Allotment',
        'Obligation',
        'Disbursement',
        'Balance',
        'Obligation Rate',
      ],
      [
        for (final g in groups.entries)
          totalRow(g.value.first.program, g.value.first.fund, Totals(g.value)),
        totalRow('TOTAL', '', t),
      ],
      {2, 3, 4, 5},
      {6},
    );
  }
  if (type == 'Obligation Status Report') {
    return ReportData(
      [
        'Program',
        'Fund Source',
        'UACS Code',
        'Expense (UACS Name)',
        'Allotment',
        'Obligation',
        'Obligation Rate',
        'Balance',
      ],
      [
        for (final r in records)
          [
            r.program,
            r.fund,
            displayCode(r.code),
            r.name,
            r.allotment / 100,
            r.obligation / 100,
            ratio(r.obligation, r.allotment),
            r.balance / 100,
          ],
        [
          'TOTAL',
          '',
          '',
          '',
          t.allotment / 100,
          t.obligation / 100,
          ratio(t.obligation, t.allotment),
          t.balance / 100,
        ],
      ],
      {4, 5, 7},
      {6},
    );
  }
  return ReportData(
    [
      '#',
      'UACS Code',
      'Expense (UACS Name)',
      'Allotment',
      'Obligation',
      'Obligation Rate',
      'Balance',
      'Disbursement',
      'Disbursement Rate',
    ],
    [
      for (var i = 0; i < records.length; i++)
        [
          i + 1,
          displayCode(records[i].code),
          records[i].name,
          records[i].allotment / 100,
          records[i].obligation / 100,
          ratio(records[i].obligation, records[i].allotment),
          records[i].balance / 100,
          records[i].disbursement / 100,
          ratio(records[i].disbursement, records[i].obligation),
        ],
      [
        '',
        '',
        'Total',
        t.allotment / 100,
        t.obligation / 100,
        ratio(t.obligation, t.allotment),
        t.balance / 100,
        t.disbursement / 100,
        ratio(t.disbursement, t.obligation),
      ],
    ],
    {3, 4, 6, 7},
    {5, 8},
  );
}

String _excelColumn(int index) {
  var n = index + 1;
  var name = '';
  while (n > 0) {
    n--;
    name = String.fromCharCode(65 + (n % 26)) + name;
    n ~/= 26;
  }
  return name;
}

bool _isTotalRow(List<Object> row) =>
    row.any((v) => v.toString().toLowerCase().startsWith('total'));

String _programLabel(String program) =>
    program.isEmpty ? 'All Programs' : program;

String _saobSheetName(String program, String fund) {
  // Sheet name matches the program so re-import adds/uses that program.
  var name = program.isEmpty ? 'SAOB' : program;
  if (fund == 'CONTINUING') name = '${name}_CONT';
  name = name.replaceAll(RegExp(r'[:\\/?*\[\]]'), '-').trim();
  if (name.isEmpty) name = 'SAOB';
  if (name.length > 31) name = name.substring(0, 31);
  return name;
}

String _sheetCell(String sheet, String cell) {
  final escaped = sheet.replaceAll("'", "''");
  return "'$escaped'!$cell";
}

class _SaobGroup {
  _SaobGroup(this.program, this.fund, this.rows);
  final String program, fund;
  final List<BudgetRecord> rows;
  String get sheet => _saobSheetName(program, fund);
  Totals get totals => Totals(rows);
}

const _moneyFormat = '#,##0.00';
const _percentFormat = '0.00%';

CellStyle _saobStyle({
  bool bold = false,
  int? size,
  ExcelColor? fill,
  ExcelColor? color,
  HorizontalAlign align = HorizontalAlign.Left,
  NumFormat? format,
  bool wrap = false,
  bool border = true,
}) {
  final line = Border(borderColorHex: ExcelColor.fromHexString('#D5E1F2'));
  return CellStyle(
    bold: bold,
    fontSize: size,
    backgroundColorHex: fill ?? ExcelColor.none,
    fontColorHex: color ?? ExcelColor.fromHexString('#132951'),
    horizontalAlign: align,
    verticalAlign: VerticalAlign.Center,
    textWrapping: wrap ? TextWrapping.WrapText : null,
    leftBorder: border ? line : Border(),
    rightBorder: border ? line : Border(),
    topBorder: border ? line : Border(),
    bottomBorder: border ? line : Border(),
    numberFormat: format ?? NumFormat.standard_0,
  );
}

void _writeCell(
  Sheet sheet,
  int row,
  int col,
  CellValue value,
  CellStyle look,
) {
  final cell = sheet.cell(
    CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
  );
  cell.value = value;
  cell.cellStyle = look;
}

Uint8List excelReport(
  List<BudgetRecord> records, {
  required String title,
  required int year,
  required String program,
}) {
  final grouped = <String, _SaobGroup>{};
  for (final row in records) {
    final key = '${row.program}\u0001${row.fund}';
    grouped
        .putIfAbsent(key, () => _SaobGroup(row.program, row.fund, []))
        .rows
        .add(row);
  }
  final sheets = grouped.values.toList()
    ..sort((a, b) {
      final fund = (a.fund == 'CURRENT' ? 0 : 1) - (b.fund == 'CURRENT' ? 0 : 1);
      return fund != 0 ? fund : a.program.compareTo(b.program);
    });
  final book = Excel.createExcel();
  final cache = <String, Map<String, String>>{};
  var renamed = false;
  for (final group in sheets) {
    if (!renamed && book.tables.containsKey('Sheet1')) {
      book.rename('Sheet1', group.sheet);
      renamed = true;
    }
    _writeSaobProgramSheet(book[group.sheet], group, year, cache);
  }
  if (program.isEmpty && sheets.isNotEmpty) {
    _writeSaobSummarySheet(book['SUMMARY'], sheets, cache);
  }
  if (renamed == false && book.tables.containsKey('Sheet1')) {
    book.delete('Sheet1');
  }
  book.setDefaultSheet(sheets.first.sheet);
  final encoded = book.encode();
  if (encoded == null || encoded.isEmpty) {
    throw const FinanceError('The Excel report could not be generated.');
  }
  return excelWithCachedFormulas(Uint8List.fromList(encoded), cache);
}

void _writeSaobProgramSheet(
  Sheet sheet,
  _SaobGroup group,
  int year,
  Map<String, Map<String, String>> cache,
) {
  const headers = [
    'UACs Name',
    'UACS CODE',
    'ALLOTMENT',
    'OBLIGATION',
    'OBLIGATION RATE',
    'BALANCE',
    'DISBURSEMENT',
    'DISBURSEMENT RATE',
    'REMARKS',
  ];
  const money = {2, 3, 5, 6};
  const rates = {4, 7};
  const firstExcel = 4;
  final lastExcel = 3 + group.rows.length;
  final totalExcel = lastExcel + 1;
  final moneyFmt = NumFormat.custom(formatCode: _moneyFormat);
  final percentFmt = NumFormat.custom(formatCode: _percentFormat);
  final navy = ExcelColor.fromHexString('#173C80');
  final totalFill = ExcelColor.fromHexString('#E7EEFC');
  final oddFill = ExcelColor.fromHexString('#F7F9FC');
  final cells = cache.putIfAbsent(group.sheet, () => {});
  sheet.setColumnWidth(0, 42);
  sheet.setColumnWidth(1, 16);
  for (var c = 2; c <= 7; c++) {
    sheet.setColumnWidth(c, 16);
  }
  sheet.setColumnWidth(8, 28);

  _writeCell(
    sheet,
    0,
    0,
    TextCellValue('REGION I'),
    _saobStyle(bold: true, size: 14, border: false),
  );
  _writeCell(
    sheet,
    0,
    1,
    TextCellValue(group.program),
    _saobStyle(bold: true, size: 14, border: false),
  );
  _writeCell(
    sheet,
    0,
    2,
    FormulaCellValue('C$totalExcel'),
    _saobStyle(bold: true, size: 12, border: false, format: moneyFmt),
  );
  cells['C1'] = (group.totals.allotment / 100).toString();
  _writeCell(
    sheet,
    1,
    0,
    TextCellValue(
      group.fund == 'CONTINUING'
          ? 'REGULAR FUND-CONTINUING'
          : 'REGULAR FUND-CURRENT',
    ),
    _saobStyle(border: false),
  );
  _writeCell(
    sheet,
    1,
    1,
    IntCellValue(year),
    _saobStyle(border: false),
  );
  for (var c = 0; c < headers.length; c++) {
    final numeric = money.contains(c) || rates.contains(c);
    _writeCell(
      sheet,
      2,
      c,
      TextCellValue(headers[c]),
      _saobStyle(
        bold: true,
        fill: navy,
        color: ExcelColor.white,
        align: numeric ? HorizontalAlign.Right : HorizontalAlign.Left,
      ),
    );
  }

  CellStyle body(int col, {bool total = false, bool odd = false}) =>
      _saobStyle(
        bold: total,
        fill: total
            ? totalFill
            : odd
            ? oddFill
            : ExcelColor.none,
        align: money.contains(col) || rates.contains(col)
            ? HorizontalAlign.Right
            : HorizontalAlign.Left,
        wrap: col == 0 || col == 8,
        format: rates.contains(col)
            ? percentFmt
            : money.contains(col)
            ? moneyFmt
            : NumFormat.standard_0,
      );

  void formula(int row, int col, String expr, num value, CellStyle look) {
    cells['${_excelColumn(col)}$row'] = value.toString();
    _writeCell(sheet, row - 1, col, FormulaCellValue(expr), look);
  }

  for (var i = 0; i < group.rows.length; i++) {
    final row = group.rows[i];
    final excel = firstExcel + i;
    final dart = excel - 1;
    final odd = i.isOdd;
    final c = 'C$excel', d = 'D$excel', g = 'G$excel';
    _writeCell(sheet, dart, 0, TextCellValue(row.name), body(0, odd: odd));
    _writeCell(
      sheet,
      dart,
      1,
      TextCellValue(displayCode(row.code)),
      body(1, odd: odd),
    );
    _writeCell(
      sheet,
      dart,
      2,
      DoubleCellValue(row.allotment / 100),
      body(2, odd: odd),
    );
    _writeCell(
      sheet,
      dart,
      3,
      DoubleCellValue(row.obligation / 100),
      body(3, odd: odd),
    );
    formula(
      excel,
      4,
      'IF($c=0,0,$d/$c)',
      row.allotment == 0 ? 0 : row.obligation / row.allotment,
      body(4, odd: odd),
    );
    formula(excel, 5, '$c-$d', row.balance / 100, body(5, odd: odd));
    _writeCell(
      sheet,
      dart,
      6,
      DoubleCellValue(row.disbursement / 100),
      body(6, odd: odd),
    );
    formula(
      excel,
      7,
      'IF($d=0,0,$g/$d)',
      row.obligation == 0 ? 0 : row.disbursement / row.obligation,
      body(7, odd: odd),
    );
    _writeCell(sheet, dart, 8, TextCellValue(row.remarks), body(8, odd: odd));
  }

  final totalRow = group.totals;
  final dartTotal = totalExcel - 1;
  final look = body;
  _writeCell(sheet, dartTotal, 0, TextCellValue('TOTAL'), look(0, total: true));
  _writeCell(sheet, dartTotal, 1, TextCellValue(''), look(1, total: true));
  for (final col in [2, 3, 5, 6]) {
    final letter = _excelColumn(col);
    final amount = switch (col) {
      2 => totalRow.allotment,
      3 => totalRow.obligation,
      5 => totalRow.balance,
      _ => totalRow.disbursement,
    };
    formula(
      totalExcel,
      col,
      group.rows.isEmpty
          ? '0'
          : 'SUM($letter$firstExcel:$letter$lastExcel)',
      amount / 100,
      look(col, total: true),
    );
  }
  formula(
    totalExcel,
    4,
    'IF(C$totalExcel=0,0,D$totalExcel/C$totalExcel)',
    totalRow.allotment == 0 ? 0 : totalRow.obligation / totalRow.allotment,
    look(4, total: true),
  );
  formula(
    totalExcel,
    7,
    'IF(D$totalExcel=0,0,G$totalExcel/D$totalExcel)',
    totalRow.obligation == 0 ? 0 : totalRow.disbursement / totalRow.obligation,
    look(7, total: true),
  );
  _writeCell(sheet, dartTotal, 8, TextCellValue(''), look(8, total: true));
}

void _writeSaobSummarySheet(
  Sheet sheet,
  List<_SaobGroup> groups,
  Map<String, Map<String, String>> cache,
) {
  final moneyFmt = NumFormat.custom(formatCode: _moneyFormat);
  final percentFmt = NumFormat.custom(formatCode: _percentFormat);
  final navy = ExcelColor.fromHexString('#173C80');
  final totalFill = ExcelColor.fromHexString('#E7EEFC');
  final cells = cache.putIfAbsent('SUMMARY', () => {});
  sheet.setColumnWidth(0, 16);
  for (var c = 1; c <= 6; c++) {
    sheet.setColumnWidth(c, 18);
  }
  const headers = [
    'PAP',
    'ALLOTMENT',
    'OBLIGATION',
    'UNOBLIGATED ALLOTMENT',
    'UTILIZATION RATE',
    'DISBURSEMENT',
    'DISB %',
  ];

  void headerRow(int dart, String title) {
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: dart),
      CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: dart),
    );
    _writeCell(
      sheet,
      dart,
      0,
      TextCellValue(title),
      _saobStyle(bold: true, size: 12, fill: navy, color: ExcelColor.white),
    );
  }

  void columnHeads(int dart) {
    for (var c = 0; c < headers.length; c++) {
      _writeCell(
        sheet,
        dart,
        c,
        TextCellValue(headers[c]),
        _saobStyle(
          bold: true,
          fill: ExcelColor.fromHexString('#EEF3FB'),
          align: c == 0 ? HorizontalAlign.Left : HorizontalAlign.Right,
        ),
      );
    }
  }

  CellStyle moneyStyle({bool total = false}) => _saobStyle(
    bold: total,
    fill: total ? totalFill : ExcelColor.none,
    align: HorizontalAlign.Right,
    format: moneyFmt,
  );
  CellStyle rateStyle({bool total = false}) => _saobStyle(
    bold: total,
    fill: total ? totalFill : ExcelColor.none,
    align: HorizontalAlign.Right,
    format: percentFmt,
  );

  void writeSection(String title, List<_SaobGroup> rows, int startDart) {
    headerRow(startDart, title);
    columnHeads(startDart + 1);
    for (var i = 0; i < rows.length; i++) {
      final group = rows[i];
      final dart = startDart + 2 + i;
      final excel = dart + 1;
      final total = 3 + group.rows.length + 1;
      final allotment = group.totals.allotment / 100;
      final obligation = group.totals.obligation / 100;
      final disbursement = group.totals.disbursement / 100;
      _writeCell(
        sheet,
        dart,
        0,
        TextCellValue(summaryProgramAndFund(group.program, group.fund).$1),
        _saobStyle(bold: true),
      );
      void ref(int col, String cell, num value, CellStyle look) {
        cells['${_excelColumn(col)}$excel'] = value.toString();
        _writeCell(
          sheet,
          dart,
          col,
          FormulaCellValue(_sheetCell(group.sheet, cell)),
          look,
        );
      }

      ref(1, 'C$total', allotment, moneyStyle());
      ref(2, 'D$total', obligation, moneyStyle());
      cells['D$excel'] = (allotment - obligation).toString();
      _writeCell(
        sheet,
        dart,
        3,
        FormulaCellValue('B$excel-C$excel'),
        moneyStyle(),
      );
      cells['E$excel'] = allotment == 0 ? '0' : (obligation / allotment).toString();
      _writeCell(
        sheet,
        dart,
        4,
        FormulaCellValue('IF(B$excel=0,0,C$excel/B$excel)'),
        rateStyle(),
      );
      ref(5, 'G$total', disbursement, moneyStyle());
      cells['G$excel'] = obligation == 0
          ? '0'
          : (disbursement / obligation).toString();
      _writeCell(
        sheet,
        dart,
        6,
        FormulaCellValue('IF(C$excel=0,0,F$excel/C$excel)'),
        rateStyle(),
      );
    }
    final totalDart = startDart + 2 + rows.length;
    final firstExcel = startDart + 3;
    final lastExcel = totalDart;
    final look = moneyStyle(total: true);
    _writeCell(
      sheet,
      totalDart,
      0,
      TextCellValue('TOTAL'),
      _saobStyle(bold: true, fill: totalFill),
    );
    for (final col in [1, 2, 3, 5]) {
      final letter = _excelColumn(col);
      final sum = rows.fold<double>(0, (n, g) {
        final t = g.totals;
        return n +
            switch (col) {
              1 => t.allotment,
              2 => t.obligation,
              3 => t.balance,
              _ => t.disbursement,
            } /
                100;
      });
      cells['$letter${totalDart + 1}'] = sum.toString();
      _writeCell(
        sheet,
        totalDart,
        col,
        FormulaCellValue(
          rows.isEmpty ? '0' : 'SUM($letter$firstExcel:$letter$lastExcel)',
        ),
        look,
      );
    }
    final totalExcel = totalDart + 1;
    final all = Totals([for (final g in rows) ...g.rows]);
    cells['E$totalExcel'] = all.allotment == 0
        ? '0'
        : (all.obligation / all.allotment).toString();
    _writeCell(
      sheet,
      totalDart,
      4,
      FormulaCellValue('IF(B$totalExcel=0,0,C$totalExcel/B$totalExcel)'),
      rateStyle(total: true),
    );
    cells['G$totalExcel'] = all.obligation == 0
        ? '0'
        : (all.disbursement / all.obligation).toString();
    _writeCell(
      sheet,
      totalDart,
      6,
      FormulaCellValue('IF(C$totalExcel=0,0,F$totalExcel/C$totalExcel)'),
      rateStyle(total: true),
    );
  }

  // Imported *_Continuing worksheets use fund_source=CURRENT internally.
  // Classify by the encoded program suffix, as in standalone Summary reports.
  const sourceOrder = ['GAS', 'PPD', 'SECADNA', 'ECA', 'ATOP'];
  int programRank(_SaobGroup group) {
    final name = summaryProgramAndFund(group.program, group.fund).$1;
    final index = sourceOrder.indexOf(name.toUpperCase());
    return index < 0 ? sourceOrder.length : index;
  }

  List<_SaobGroup> sorted(String fund) =>
      groups
          .where((g) => summaryProgramAndFund(g.program, g.fund).$2 == fund)
          .toList()
        ..sort((a, b) {
          final rank = programRank(a).compareTo(programRank(b));
          return rank != 0 ? rank : a.program.compareTo(b.program);
        });
  final current = sorted('CURRENT');
  final continuing = sorted('CONTINUING');
  if (current.isNotEmpty) {
    writeSection('CURRENT APPRO', current, 0);
  }
  if (continuing.isNotEmpty) {
    writeSection(
      'CONTINUING APPRO',
      continuing,
      // One blank row between the two tables, as in the reference workbook.
      current.isEmpty ? 0 : current.length + 4,
    );
  }
}

Future<Uint8List> pdfReport(
  ReportData data, {
  required String title,
  required int year,
  required String program,
  PdfPageFormat? pageFormat,
}) async {
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/DejaVuSans.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'),
  );
  final logo = pw.MemoryImage(
    (await rootBundle.load('assets/ncsc-logo-transparent.png')).buffer
        .asUint8List(),
  );
  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      pageFormat: pageFormat ?? PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      maxPages: 2000,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      header: (_) => pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Image(logo, width: 42, height: 42),
              pw.SizedBox(width: 10),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'NATIONAL COMMISSION OF SENIOR CITIZENS',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'REGION I',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          // The obsolete Report Type title is deliberately not shown.
          pw.Text(
            'Program: ${_programLabel(program)}  |  Fiscal Year: $year',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey700),
          ),
          pw.SizedBox(height: 10),
        ],
      ),
      build: (_) => [
        pw.TableHelper.fromTextArray(
          headers: data.headers,
          data: [
            for (final row in data.rows)
              [
                for (var c = 0; c < row.length; c++)
                  _isTotalRow(row) &&
                          c == data.headers.indexOf('Expense (UACS Name)')
                      ? 'Total (${_programLabel(program)})'
                      : data.display(row[c], c),
              ],
          ],
          headerStyle: pw.TextStyle(
            font: bold,
            fontSize: 7,
            color: PdfColors.white,
          ),
          headerDecoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xff173c80),
          ),
          cellStyle: const pw.TextStyle(fontSize: 7),
          cellPadding: const pw.EdgeInsets.all(4),
          cellAlignments: {
            for (final c in {...data.moneyColumns, ...data.rateColumns})
              c: pw.Alignment.centerRight,
          },
          oddRowDecoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xfff0f4fb),
          ),
          border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.3),
        ),
      ],
    ),
  );
  return document.save();
}
