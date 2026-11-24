import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ncsc_region1_finance/data/models.dart';
import 'package:ncsc_region1_finance/data/report_pdf_sections.dart';
import 'package:ncsc_region1_finance/data/report_summary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  BudgetRecord entry(
    String program,
    String fund,
    int allotment,
    int obligation,
    int disbursement,
  ) =>
      BudgetRecord(
        year: 2026,
        program: program,
        fund: fund,
        code: '5020101000',
        name: 'Traveling Expenses - Local',
        allotment: allotment,
        obligation: obligation,
        disbursement: disbursement,
      );

  late List<BudgetRecord> records;
  setUp(() {
    records = [
      entry('GAS', 'CURRENT', 100000, 60000, 30000),
      entry('ECA', 'CURRENT', 250000, 120000, 70000),
      entry('GAS', 'CONTINUING', 40000, 10000, 4000),
    ];
  });

  test('SUMMARY uses CURRENT/CONTINUING sections and totals per PAP', () {
    final sections = saobSummarySections(records);
    expect(sections.map((s) => s.title), [
      'CURRENT APPRO',
      'CONTINUING APPRO',
    ]);
    expect(sections.first.rows.map((r) => r.program), ['ECA', 'GAS']);
    expect(sections.first.totals.allotment, 350000);
    expect(sections.first.totals.obligation, 180000);
    expect(sections.first.totals.balance, 170000);
    expect(sections.first.totals.disbursement, 100000);
    expect(sections.last.rows.single.program, 'GAS');
    expect(sections.last.totals.allotment, 40000);
    expect(sections.last.totals.obligation, 10000);
    expect(summaryDisplayRow('TOTAL', sections.last.totals).first, 'TOTAL');
    expect(summaryDisplayRow('GAS', sections.last.totals)[4], '25.00%');
    expect(summaryHeaders, [
      'PAP',
      'ALLOTMENT',
      'OBLIGATION',
      'UNOBLIGATED ALLOTMENT',
      'UTILIZATION RATE',
      'DISBURSEMENT',
      'DISB %',
    ]);
  });

  test('Summary-only Excel has one sheet and both appropriation sections', () {
    final bytes = excelSaobSummaryReport(records, year: 2026);
    final archive = ZipDecoder().decodeBytes(bytes);
    final xml = utf8.decode(
      archive.files
          .firstWhere((f) => f.name == 'xl/sharedStrings.xml')
          .content as List<int>,
    );
    final workbook = utf8.decode(
      archive.files
          .firstWhere((f) => f.name == 'xl/workbook.xml')
          .content as List<int>,
    );
    expect(workbook, contains('name="SUMMARY"'));
    expect(workbook, isNot(contains('name="GAS"')));
    expect(xml, contains('CURRENT APPRO'));
    expect(xml, contains('CONTINUING APPRO'));
    expect(xml, contains('UNOBLIGATED ALLOTMENT'));
    expect(xml, contains('TOTAL'));
  });

  test('Grouped All Programs and standalone Summary PDFs generate offline', () async {
    final all = await pdfAllProgramsReport(records, year: 2026);
    final summary = await pdfSaobSummaryReport(records, year: 2026);
    expect(String.fromCharCodes(all.take(4)), '%PDF');
    expect(String.fromCharCodes(summary.take(4)), '%PDF');
    expect(all.length, greaterThan(5000));
    expect(summary.length, greaterThan(5000));
  });

  test('Summary handles a single appropriation source', () {
    final onlyCurrent = saobSummarySections([
      entry('GAS', 'CURRENT', 20000, 0, 0),
    ]);
    expect(onlyCurrent.length, 1);
    expect(onlyCurrent.single.title, 'CURRENT APPRO');
    expect(summaryDisplayRow('GAS', onlyCurrent.single.totals).last, '—');
  });
}
