import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:path/path.dart' as p;

import '../core/format.dart';
import 'models.dart';

class ImportLine {
  const ImportLine(
    this.number,
    this.code,
    this.name,
    this.allotment,
    this.obligation,
    this.disbursement,
    this.remarks,
    this.parseError,
  );
  final int number;
  final String code, name, remarks, parseError;
  final int allotment, obligation, disbursement;
  BudgetRecord record(int year, String program, String fund) => BudgetRecord(
    year: year,
    program: program,
    fund: fund,
    code: code,
    name: name,
    allotment: allotment,
    obligation: obligation,
    disbursement: disbursement,
    remarks: remarks,
  );
}

class ImportSheet {
  const ImportSheet(this.name, this.program, this.fund, this.lines, this.error);
  final String name, program, fund, error;
  final List<ImportLine> lines;
}

String _key(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
const _aliases = {
  'code': ['uacscode', 'uacscodes'],
  'name': [
    'uacsname',
    'expenseuacsname',
    'expense',
    'expenseitem',
    'particulars',
  ],
  'allotment': ['allotment', 'allotments', 'totalallotment'],
  'obligation': [
    'obligation',
    'obligations',
    'totalobligation',
    'totalobligations',
  ],
  'disbursement': [
    'disbursement',
    'disbursements',
    'disbursment',
    'totaldisbursement',
  ],
  'remarks': ['remarks', 'notes'],
};
Iterable<XmlElement> _elements(XmlNode node, String name) =>
    node.descendants.whereType<XmlElement>().where((e) => e.name.local == name);
String? _attribute(XmlElement e, String key) {
  for (final a in e.attributes) {
    if (a.name.local == key) return a.value;
  }
  return null;
}

int _column(String reference) {
  var value = 0;
  for (final code in reference.toUpperCase().codeUnits) {
    if (code < 65 || code > 90) break;
    value = value * 26 + code - 64;
  }
  return value - 1;
}

/// Read raw OOXML cached values so formulas are never mistaken for zero.
/// No formulas are executed and no links or macros are loaded.
List<ImportSheet> parseWorkbook(Uint8List bytes) {
  if (bytes.length > 25 * 1024 * 1024) {
    throw const FinanceError('Choose an Excel file smaller than 25 MB.');
  }
  final archive = ZipDecoder().decodeBytes(bytes, verify: true);
  final files = {
    for (final f in archive.files.where((f) => f.isFile)) f.name: f,
  };
  var expanded = 0;
  for (final file in files.values) {
    expanded += file.size;
    if (expanded > 150 * 1024 * 1024) {
      throw const FinanceError('The workbook is too large after extraction.');
    }
  }
  XmlDocument? xml(String name) {
    final entry = files[name];
    return entry == null
        ? null
        : XmlDocument.parse(utf8.decode(entry.content as List<int>));
  }

  final workbook = xml('xl/workbook.xml');
  final relationships = xml('xl/_rels/workbook.xml.rels');
  if (workbook == null || relationships == null) {
    throw const FinanceError('Select a valid .xlsx workbook.');
  }
  final links = <String, String>{};
  for (final rel in _elements(relationships, 'Relationship')) {
    if (rel.getAttribute('TargetMode') == 'External') continue;
    final target = rel.getAttribute('Target') ?? '';
    links[rel.getAttribute('Id') ?? ''] = target.startsWith('/')
        ? target.substring(1)
        : p.posix.normalize(p.posix.join('xl', target));
  }
  final shared = xml('xl/sharedStrings.xml');
  final strings = shared == null
      ? <String>[]
      : _elements(shared, 'si')
            .map((si) => _elements(si, 't').map((t) => t.innerText).join())
            .toList();

  final result = <ImportSheet>[];
  for (final sheet in _elements(workbook, 'sheet')) {
    final name = sheet.getAttribute('name') ?? 'Worksheet';
    final tokens = name.toUpperCase().split(RegExp(r'[^A-Z0-9]+'));
    final fund = tokens.any((s) => s.startsWith('CONT'))
        ? 'CONTINUING'
        : 'CURRENT';
    final program =
        tokens
            .where(['GAS', 'PPD', 'ECA', 'SECADNA', 'ATOP'].contains)
            .firstOrNull ??
        '';
    if (name.toUpperCase().contains('SUMMARY')) {
      result.add(
        ImportSheet(
          name,
          program,
          fund,
          [],
          'Summary worksheets are not imported as budget lines.',
        ),
      );
      continue;
    }
    final content = xml(links[_attribute(sheet, 'id')] ?? '');
    if (content == null) {
      result.add(
        ImportSheet(
          name,
          program,
          fund,
          [],
          'This worksheet could not be read.',
        ),
      );
      continue;
    }
    final rows = _elements(content, 'row').toList();
    if (rows.length > 100000) {
      throw const FinanceError(
        'A worksheet exceeds 100,000 rows. Split the workbook before importing.',
      );
    }
    final cells = <int, Map<int, String>>{};
    final unresolved = <String>{};
    var rowIndex = 0;
    for (final row in rows) {
      rowIndex = int.tryParse(row.getAttribute('r') ?? '') ?? rowIndex + 1;
      final values = <int, String>{};
      var colIndex = -1;
      for (final cell in row.childElements.where((e) => e.name.local == 'c')) {
        final reference = cell.getAttribute('r');
        colIndex = reference == null ? colIndex + 1 : _column(reference);
        final type = cell.getAttribute('t');
        final raw = _elements(cell, 'v').firstOrNull?.innerText ?? '';
        var value = raw;
        if (type == 's') {
          final index = int.tryParse(raw);
          value = index != null && index >= 0 && index < strings.length
              ? strings[index]
              : '';
        } else if (type == 'inlineStr') {
          value = _elements(cell, 't').map((e) => e.innerText).join();
        }
        if (_elements(cell, 'f').isNotEmpty && raw.isEmpty) {
          unresolved.add('$rowIndex/$colIndex');
        }
        if (type == 'e') unresolved.add('$rowIndex/$colIndex');
        values[colIndex] = value.trim();
      }
      cells[rowIndex] = values;
    }
    var header = -1;
    final columns = <String, int>{};
    for (final entry in cells.entries.take(20)) {
      final found = <String, int>{};
      for (final cell in entry.value.entries) {
        for (final aliases in _aliases.entries) {
          if (aliases.value.contains(_key(cell.value))) {
            found[aliases.key] = cell.key;
          }
        }
      }
      if ([
        'code',
        'name',
        'allotment',
        'obligation',
        'disbursement',
      ].every(found.containsKey)) {
        header = entry.key;
        columns.addAll(found);
        break;
      }
    }
    if (header < 0) {
      result.add(
        ImportSheet(
          name,
          program,
          fund,
          [],
          'Required columns: UACS Code, UACS Name, Allotment, Obligation, and Disbursement.',
        ),
      );
      continue;
    }
    final lines = <ImportLine>[];
    for (final entry in cells.entries.where((e) => e.key > header)) {
      String value(String field) => entry.value[columns[field]] ?? '';
      var code = codeKey(value('code'));
      final expense = value('name');
      if (code.isEmpty && expense.isEmpty) continue;
      if (RegExp(
            r'^(sub\s*)?total',
            caseSensitive: false,
          ).hasMatch('$code $expense') ||
          RegExp(r'^(sub\s*)?total', caseSensitive: false).hasMatch(expense)) {
        continue;
      }
      // Ignore empty section headings; keep malformed data lines visible for review.
      if (code.isEmpty &&
          [
            'allotment',
            'obligation',
            'disbursement',
          ].every((k) => value(k).isEmpty)) {
        continue;
      }
      if (RegExp(r'^\d+(\.0+|[Ee]\+?\d+)$').hasMatch(code)) {
        final n = num.tryParse(code);
        if (n != null && n.isFinite && n == n.round()) {
          code = n.toInt().toString();
        }
      }
      var error = '';
      int amount(String field) {
        if (unresolved.contains('${entry.key}/${columns[field]}')) {
          error = 'An amount has an Excel error or an uncached formula. Open, recalculate, and save the workbook in Excel.';
          return 0;
        }
        final raw = value(field);
        // Excel numeric cells may contain more than two binary-decimal digits.
        final numeric = num.tryParse(raw.replaceAll(',', ''));
        if (numeric != null &&
            numeric.isFinite &&
            numeric >= 0 &&
            numeric <= 9000000000000) {
          return (numeric * 100).round();
        }
        final parsed = parseCents(raw, required: field == 'allotment');
        if (parsed == null) {
          error =
              'Invalid $field amount. Enter a valid non-negative peso amount.';
        }
        return parsed ?? 0;
      }

      final a = amount('allotment'),
          o = amount('obligation'),
          d = amount('disbursement');
      lines.add(
        ImportLine(entry.key, code, expense, a, o, d, value('remarks'), error),
      );
    }
    result.add(
      ImportSheet(
        name,
        program,
        fund,
        lines,
        lines.isEmpty ? 'This worksheet has no budget lines.' : '',
      ),
    );
  }
  if (result.isEmpty) {
    throw const FinanceError('The workbook has no worksheets.');
  }
  return result;
}
