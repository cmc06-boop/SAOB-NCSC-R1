import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ncsc_region1_finance/data/models.dart';
import 'package:ncsc_region1_finance/data/report_pdf_sections.dart';
import 'package:ncsc_region1_finance/data/report_io.dart';
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
    expect(sections.first.rows.map((r) => r.program), ['GAS', 'ECA']);
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

  test('Imported program suffixes split CURRENT and CONTINUING on Summary', () {
    // The Excel importer stores fund_source=CURRENT for both worksheets,
    // but preserves the appropriation in program codes such as ATOP_Continuing.
    final imported = [
      entry('ATOP_Current', 'CURRENT', 17400000, 10000000, 2000000),
      entry('ATOP_Continuing', 'CURRENT', 4997973, 4799000, 0),
      entry('GAS_Current', 'CURRENT', 100000, 30000, 20000),
      entry('PPD_Current', 'CURRENT', 200000, 40000, 10000),
      entry('SECADNA_Current', 'CURRENT', 300000, 50000, 20000),
      entry('ECA_Current', 'CURRENT', 400000, 60000, 30000),
    ];
    final sections = saobSummarySections(imported);
    expect(sections.map((s) => s.title), [
      'CURRENT APPRO',
      'CONTINUING APPRO',
    ]);
    expect(sections.first.rows.map((r) => r.program), [
      'GAS',
      'PPD',
      'SECADNA',
      'ECA',
      'ATOP',
    ]);
    expect(sections.last.rows.map((r) => r.program), ['ATOP']);
    expect(sections.last.totals.allotment, 4997973);
    expect(sections.last.totals.obligation, 4799000);
    expect(sections.first.totals.allotment, 18400000);
    expect(
      sections.first.rows.last.totals.allotment,
      17400000,
    );
    final book = excelSaobSummaryReport(imported, year: 2026);
    final archive = ZipDecoder().decodeBytes(book);
    final sharedStrings = utf8.decode(
      archive.files
          .firstWhere((f) => f.name == 'xl/sharedStrings.xml')
          .content as List<int>,
    );
    expect(sharedStrings, contains('CURRENT APPRO'));
    expect(sharedStrings, contains('CONTINUING APPRO'));
    expect(sharedStrings, isNot(contains('ATOP_Continuing')));

    // All Programs Excel includes a SUMMARY sheet too; it must not place
    // imported ATOP_Continuing under CURRENT just because DB fund is CURRENT.
    final allPrograms = excelReport(
      imported,
      title: 'Budget Utilization Report',
      year: 2026,
      program: '',
    );
    final allZip = ZipDecoder().decodeBytes(allPrograms);
    final allStrings = utf8.decode(
      allZip.files
          .firstWhere((f) => f.name == 'xl/sharedStrings.xml')
          .content as List<int>,
    );
    expect(allStrings, contains('CURRENT APPRO'));
    expect(allStrings, contains('CONTINUING APPRO'));
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

  test('Summary Excel keeps editable formulas, cached totals and selected fiscal year', () {
    final bytes = excelSaobSummaryReport(records, year: 2027);
    final zip = ZipDecoder().decodeBytes(bytes);
    final shared = utf8.decode(
      zip.files.firstWhere((f) => f.name == 'xl/sharedStrings.xml').content
          as List<int>,
    );
    final sheet = utf8.decode(
      zip.files
          .firstWhere(
            (f) => f.name.startsWith('xl/worksheets/sheet') &&
                f.name.endsWith('.xml'),
          )
          .content as List<int>,
    );

    expect(shared, contains('FISCAL YEAR 2027'));
    expect(shared, contains('CURRENT APPRO'));
    expect(shared, contains('CONTINUING APPRO'));

    // Three title rows and a spacer precede the appropriation sections.
    // CURRENT data starts at Excel row 7; B/C/F remain directly editable.
    expect(sheet, contains('<f>B7-C7</f>'));
    expect(sheet, contains('<f>IF(B7=0,0,C7/B7)</f>'));
    expect(sheet, contains('<f>IF(C7=0,0,F7/C7)</f>'));
    // Totals must recompute after a program's amounts are changed.
    expect(sheet, contains('<f>SUM(B7:B8)</f>'));
    expect(sheet, contains('<f>SUM(C7:C8)</f>'));
    expect(sheet, contains('<f>SUM(F7:F8)</f>'));
    expect(sheet, contains('<f>B9-C9</f>'));
    expect(sheet, contains('<f>IF(B9=0,0,C9/B9)</f>'));
    // CONTINUING has its own table and separate totals.
    expect(sheet, contains('<f>SUM(B13:B13)</f>'));
    expect(sheet, contains('<f>B14-C14</f>'));
    // Cache initial result without replacing the editable formula.
    expect(sheet, matches(RegExp(r'<f>B7-C7</f><v>400(\.0)?</v>')));
    expect(sheet, matches(RegExp(r'<f>B9-C9</f><v>1700(\.0)?</v>')));
    expect(sheet, contains('orientation="landscape"'));
    expect(sheet, contains('fitToWidth="1"'));
    expect(sheet, contains('state="frozen"'));
  });

  test('Summary Excel fiscal year is dynamic, not hard-coded to 2026', () {
    final first = excelSaobSummaryReport(records, year: 2027);
    final later = excelSaobSummaryReport(records, year: 2028);
    String strings(List<int> bytes) {
      final zip = ZipDecoder().decodeBytes(bytes);
      return utf8.decode(
        zip.files.firstWhere((f) => f.name == 'xl/sharedStrings.xml').content
            as List<int>,
      );
    }

    expect(strings(first), contains('FISCAL YEAR 2027'));
    expect(strings(first), isNot(contains('FISCAL YEAR 2026')));
    expect(strings(later), contains('FISCAL YEAR 2028'));
  });

  test('Grouped All Programs and standalone Summary PDFs generate offline', () async {
    final all = await pdfAllProgramsReport(records, year: 2026);
    final oneProgram = await pdfAllProgramsReport(
      records.where((row) => row.program == 'GAS').toList(),
      year: 2026,
    );
    final summary = await pdfSaobSummaryReport(records, year: 2026);
    expect(String.fromCharCodes(all.take(4)), '%PDF');
    expect(String.fromCharCodes(oneProgram.take(4)), '%PDF');
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
    expect(summaryDisplayRow('GAS', onlyCurrent.single.totals).last, '0.00%');
  });
}
