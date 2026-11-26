import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

import '../data/models.dart';
import '../data/report_io.dart';
import '../data/report_summary.dart';

String _columnName(int index) {
  var name = '';
  for (var n = index + 1; n > 0; n ~/= 26) {
    n--;
    name = String.fromCharCode(65 + n % 26) + name;
  }
  return name;
}

(int, int) _address(String ref) {
  final match = RegExp(r'^([A-Z]+)([0-9]+)$').firstMatch(ref)!;
  var col = 0;
  for (final code in match[1]!.codeUnits) {
    col = col * 26 + code - 64;
  }
  return (int.parse(match[2]!) - 1, col - 1);
}

Iterable<XmlElement> _children(XmlElement? node, String name) =>
    node?.childElements.where((e) => e.name.local == name) ?? const [];
XmlElement? _child(XmlElement? node, String name) =>
    _children(node, name).firstOrNull;
int _int(String? value, [int fallback = 0]) =>
    int.tryParse(value ?? '') ?? fallback;

Color _rgb(XmlElement? node, Color fallback) {
  final rgb = node?.getAttribute('rgb');
  if (rgb == null || rgb.length < 6) return fallback;
  final value = int.tryParse(rgb.substring(rgb.length - 6), radix: 16);
  return value == null ? fallback : Color(0xff000000 | value);
}

class _Look {
  const _Look({
    this.fill = Colors.white,
    this.ink = const Color(0xff132951),
    this.bold = false,
    this.size = 11,
    this.align = TextAlign.left,
    this.format = '',
  });
  final Color fill, ink;
  final bool bold;
  final double size;
  final TextAlign align;
  final String format;

  String display(String value, bool numeric) {
    final number = numeric ? double.tryParse(value) : null;
    if (number == null) return value;
    if (format.contains('%')) return NumberFormat('0.00%').format(number);
    if (format.contains('0.00')) return NumberFormat('#,##0.00').format(number);
    return value;
  }
}

class _Cell {
  const _Cell(this.text, this.look);
  final String text;
  final _Look look;
}

class _Sheet {
  _Sheet(this.name);
  final String name;
  final cells = <(int, int), _Cell>{};
  final widths = <int, double>{};
  final heights = <int, double>{};
  final merges = <(int, int), int>{};
  final covered = <(int, int)>{};
  int rows = 0, columns = 0;

  double width(int col) => widths[col] ?? 110;
  double get totalWidth =>
      38 + List.generate(columns, width).fold<double>(0, (a, b) => a + b);
}

/// Reads the generated workbook, not a separate report calculation.
/// Cached formula values, sheet order, merges and exported formatting are retained.
List<_Sheet> _readWorkbook(Uint8List bytes) {
  final files = {
    for (final f in ZipDecoder().decodeBytes(bytes).files)
      if (f.isFile) f.name: f,
  };
  XmlElement? xml(String name) {
    final file = files[name];
    return file == null
        ? null
        : XmlDocument.parse(utf8.decode(file.content as List<int>)).rootElement;
  }
  final workbook = xml('xl/workbook.xml');
  final relationships = xml('xl/_rels/workbook.xml.rels');
  final targets = {
    for (final rel in _children(relationships, 'Relationship'))
      rel.getAttribute('Id'): rel.getAttribute('Target') ?? '',
  };
  final strings = [
    for (final item in _children(xml('xl/sharedStrings.xml'), 'si'))
      item.descendants.whereType<XmlElement>()
          .where((e) => e.name.local == 't').map((e) => e.innerText).join(),
  ];
  final styleRoot = xml('xl/styles.xml');
  final fonts = _children(_child(styleRoot, 'fonts'), 'font').toList();
  final fills = _children(_child(styleRoot, 'fills'), 'fill').toList();
  final formats = <int, String>{
    2: '0.00', 4: '#,##0.00', 9: '0%', 10: '0.00%',
    for (final fmt in _children(_child(styleRoot, 'numFmts'), 'numFmt'))
      _int(fmt.getAttribute('numFmtId')): fmt.getAttribute('formatCode') ?? '',
  };
  final looks = <_Look>[];
  for (final xf in _children(_child(styleRoot, 'cellXfs'), 'xf')) {
    final fontId = _int(xf.getAttribute('fontId'));
    final fillId = _int(xf.getAttribute('fillId'));
    final font = fontId < fonts.length ? fonts[fontId] : null;
    final fill = fillId < fills.length ? fills[fillId] : null;
    final pattern = _child(fill, 'patternFill');
    final alignment = _child(xf, 'alignment')?.getAttribute('horizontal');
    looks.add(_Look(
      fill: pattern?.getAttribute('patternType') == 'solid'
          ? _rgb(_child(pattern, 'fgColor'), Colors.white) : Colors.white,
      ink: _rgb(_child(font, 'color'), const Color(0xff132951)),
      bold: _child(font, 'b') != null &&
          _child(font, 'b')?.getAttribute('val') != '0',
      size: double.tryParse(_child(font, 'sz')?.getAttribute('val') ?? '') ?? 11,
      align: alignment == 'center' ? TextAlign.center
          : alignment == 'right' ? TextAlign.right : TextAlign.left,
      format: formats[_int(xf.getAttribute('numFmtId'))] ?? '',
    ));
  }
  final sheets = <_Sheet>[];
  for (final entry in _children(_child(workbook, 'sheets'), 'sheet')) {
    final id = entry.attributes.where((a) => a.name.local == 'id').firstOrNull?.value;
    final target = targets[id];
    if (target == null || target.isEmpty) continue;
    final fileName = target.startsWith('/') ? target.substring(1)
        : target.startsWith('xl/') ? target : path.posix.normalize('xl/$target');
    final source = xml(fileName);
    if (source == null) continue;
    final sheet = _Sheet(entry.getAttribute('name') ?? 'Worksheet');
    for (final col in _children(_child(source, 'cols'), 'col')) {
      final min = _int(col.getAttribute('min'), 1) - 1;
      final max = _int(col.getAttribute('max'), 1) - 1;
      final width = double.tryParse(col.getAttribute('width') ?? '') ?? 16;
      for (var c = min; c <= max; c++) {
        sheet.widths[c] = math.max(75.0, width * 7 + 12);
      }
    }
    for (final row in _children(_child(source, 'sheetData'), 'row')) {
      final r = _int(row.getAttribute('r'), 1) - 1;
      final height = double.tryParse(row.getAttribute('ht') ?? '');
      if (height != null) sheet.heights[r] = math.max(28.0, height * 1.333);
      for (final cell in _children(row, 'c')) {
        final ref = cell.getAttribute('r');
        if (ref == null) continue;
        final (r, c) = _address(ref);
        sheet.rows = math.max(sheet.rows, r + 1);
        sheet.columns = math.max(sheet.columns, c + 1);
        final style = _int(cell.getAttribute('s'));
        final look = style < looks.length ? looks[style] : const _Look();
        final type = cell.getAttribute('t');
        var value = _child(cell, 'v')?.innerText ?? '';
        if (type == 's') {
          final index = _int(value, -1);
          value = index >= 0 && index < strings.length ? strings[index] : '';
        } else if (type == 'inlineStr') {
          value = _child(cell, 'is')?.innerText ?? '';
        }
        final formula = _child(cell, 'f');
        if (formula != null && value.isEmpty) value = '=${formula.innerText}';
        sheet.cells[(r, c)] = _Cell(look.display(value, type == null || type == 'n'), look);
      }
    }
    for (final merge in _children(_child(source, 'mergeCells'), 'mergeCell')) {
      final ref = merge.getAttribute('ref')?.split(':');
      if (ref == null || ref.length != 2) continue;
      final (r1, c1) = _address(ref.first);
      final (r2, c2) = _address(ref.last);
      // Current report exports only horizontal merges.
      if (r1 != r2) continue;
      sheet.merges[(r1, c1)] = c2 - c1 + 1;
      for (var c = c1 + 1; c <= c2; c++) {
        sheet.covered.add((r1, c));
      }
      sheet.columns = math.max(sheet.columns, c2 + 1);
    }
    sheets.add(sheet);
  }
  return sheets;
}

class ExcelReportPreview extends StatefulWidget {
  const ExcelReportPreview({
    super.key,
    required this.records,
    required this.year,
    required this.program,
    required this.zoom,
    required this.onFitScale,
  });
  final List<BudgetRecord> records;
  final int year;
  final String program;
  final double? zoom;
  final ValueChanged<double> onFitScale;

  @override
  State<ExcelReportPreview> createState() => _ExcelReportPreviewState();
}

class _ExcelReportPreviewState extends State<ExcelReportPreview> {
  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  final _tabs = ScrollController();
  List<_Sheet> _sheets = [];
  int _selected = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    try {
      final bytes = widget.program == summarySelection
          ? excelSaobSummaryReport(widget.records, year: widget.year)
          : excelReport(widget.records, title: 'Budget Utilization Report',
              year: widget.year, program: widget.program);
      _sheets = _readWorkbook(bytes);
    } catch (_) {
      _failed = true;
    }
  }

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (_selected == index) return;
    if (_vertical.hasClients) _vertical.jumpTo(0);
    if (_horizontal.hasClients) _horizontal.jumpTo(0);
    setState(() => _selected = index);
  }

  Widget _cell(String value, double width, double height, double scale,
      _Look look, {bool coordinate = false}) {
    return Container(
      width: width * scale,
      height: height * scale,
      alignment: look.align == TextAlign.right ? Alignment.centerRight
          : look.align == TextAlign.center ? Alignment.center : Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: 5 * scale),
      decoration: BoxDecoration(
        color: coordinate ? const Color(0xffedf1f5) : look.fill,
        border: const Border(
          right: BorderSide(color: Color(0xffd5dce5), width: 0.7),
          bottom: BorderSide(color: Color(0xffd5dce5), width: 0.7),
        ),
      ),
      child: Tooltip(
        message: value,
        child: Text(value, textAlign: look.align,
          maxLines: coordinate ? 1 : 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Arial',
            fontSize: look.size * 1.2 * scale,
            color: coordinate ? const Color(0xff526274) : look.ink,
            fontWeight: look.bold ? FontWeight.w700 : FontWeight.w400,
          )),
      ),
    );
  }

  Widget _row(_Sheet sheet, int r, double scale) {
    const coordinates = _Look(align: TextAlign.center, size: 10);
    final height = sheet.heights[r] ?? 40.0;
    return Row(
      children: [
        _cell('${r + 1}', 38, height, scale, coordinates, coordinate: true),
        for (var c = 0; c < sheet.columns; c++)
          if (!sheet.covered.contains((r, c)))
            _cell(
              sheet.cells[(r, c)]?.text ?? '',
              List.generate(sheet.merges[(r, c)] ?? 1, (i) => sheet.width(c + i))
                  .fold<double>(0, (a, b) => a + b),
              height,
              scale,
              sheet.cells[(r, c)]?.look ?? const _Look(),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || _sheets.isEmpty) {
      return const Center(child: Text('Excel preview unavailable. You can still export the report.'));
    }
    final sheet = _sheets[_selected];
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxHeight <= 48 || constraints.maxWidth <= 0) {
        return const SizedBox.shrink();
      }
      final fit = math.min(1.0, math.max(0.05, (constraints.maxWidth - 14) / sheet.totalWidth));
      widget.onFitScale(fit);
      final scale = widget.zoom ?? fit;
      final gridWidth = sheet.totalWidth * scale;
      const coordinates = _Look(align: TextAlign.center, size: 10);
      return Column(
        key: const ValueKey('excel-workbook-preview'),
        children: [
          Expanded(
            child: Scrollbar(
              controller: _horizontal,
              notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
              thumbVisibility: gridWidth > constraints.maxWidth,
              child: SingleChildScrollView(
                controller: _horizontal,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: math.max(gridWidth, constraints.maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _cell('', 38, 26, scale, coordinates, coordinate: true),
                          for (var c = 0; c < sheet.columns; c++)
                            _cell(_columnName(c), sheet.width(c), 26, scale,
                                coordinates, coordinate: true),
                        ],
                      ),
                      Expanded(
                        child: Scrollbar(
                          controller: _vertical,
                          thumbVisibility: true,
                          notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
                          child: ListView.builder(
                            controller: _vertical,
                            itemCount: sheet.rows,
                            itemBuilder: (context, r) => _row(sheet, r, scale),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xfff1f4f7),
              border: Border(top: BorderSide(color: Color(0xffd5dce5))),
            ),
            child: Scrollbar(
              controller: _tabs,
              thumbVisibility: true,
              child: ListView.separated(
                controller: _tabs,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 7),
                itemCount: _sheets.length,
                separatorBuilder: (_, _) => const SizedBox(width: 3),
                itemBuilder: (context, i) => InkWell(
                  key: ValueKey('excel-sheet-${_sheets[i].name}'),
                  onTap: () => _select(i),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: i == _selected ? Colors.white : Colors.transparent,
                      border: Border(bottom: BorderSide(
                        color: i == _selected ? const Color(0xff15803d) : Colors.transparent,
                        width: 2,
                      )),
                    ),
                    child: Text(_sheets[i].name, style: TextStyle(
                      fontSize: 12,
                      fontWeight: i == _selected ? FontWeight.w700 : FontWeight.w400,
                      color: i == _selected ? const Color(0xff15803d) : const Color(0xff526274),
                    )),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
