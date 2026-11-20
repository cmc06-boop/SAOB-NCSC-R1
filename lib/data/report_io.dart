import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/format.dart';
import 'models.dart';

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
      'Program',
      'Fund Source',
      'UACS Code',
      'Expense (UACS Name)',
      'Allotment',
      'Obligation',
      'Obligation Rate',
      'Balance',
      'Disbursement',
      'Disbursement Rate',
      'Remarks',
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
          r.disbursement / 100,
          ratio(r.disbursement, r.obligation),
          r.remarks,
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
        t.disbursement / 100,
        ratio(t.disbursement, t.obligation),
        '',
      ],
    ],
    {4, 5, 7, 8},
    {6, 9},
  );
}

Uint8List excelReport(
  ReportData data, {
  required String title,
  required int year,
  required String program,
}) {
  final book = Excel.createExcel();
  final sheet = book['SAOB'];
  book.delete('Sheet1');
  sheet.appendRow(data.headers.map(TextCellValue.new).toList());
  for (final row in data.rows) {
    sheet.appendRow(
      row
          .map<CellValue>(
            (v) => v is num
                ? DoubleCellValue(v.toDouble())
                : TextCellValue(v.toString()),
          )
          .toList(),
    );
  }
  for (var c = 0; c < data.headers.length; c++) {
    sheet.setColumnWidth(c, data.headers[c].contains('Expense') ? 40 : 22);
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
        .cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#173C80'),
      fontColorHex: ExcelColor.white,
    );
    for (var r = 1; r <= data.rows.length; r++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
      );
      if (data.moneyColumns.contains(c)) {
        cell.cellStyle = CellStyle(
          numberFormat: NumFormat.custom(formatCode: '#,##0.00'),
        );
      } else if (data.rateColumns.contains(c)) {
        cell.cellStyle = CellStyle(
          numberFormat: NumFormat.custom(formatCode: '0.00%'),
        );
      }
    }
  }
  final about = book['Report Details'];
  about.appendRow([TextCellValue('Report'), TextCellValue(title)]);
  about.appendRow([TextCellValue('Fiscal Year'), IntCellValue(year)]);
  about.appendRow([
    TextCellValue('Program'),
    TextCellValue(program.isEmpty ? 'All Programs' : program),
  ]);
  about.appendRow([
    TextCellValue('Date Generated'),
    TextCellValue(dateLabel(nowStamp())),
  ]);
  about.setColumnWidth(0, 22);
  about.setColumnWidth(1, 65);
  return Uint8List.fromList(book.encode()!);
}

Future<Uint8List> pdfReport(
  ReportData data, {
  required String title,
  required int year,
  required String program,
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
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      maxPages: 2000,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      header: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Image(logo, width: 42, height: 42),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'National Commission of Senior Citizens · Region I',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(title, style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(
                      'Fiscal Year $year · ${program.isEmpty ? 'All Programs' : program}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
        ],
      ),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ),
      build: (_) => [
        pw.TableHelper.fromTextArray(
          headers: data.headers,
          data: [
            for (final row in data.rows)
              [for (var c = 0; c < row.length; c++) data.display(row[c], c)],
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
