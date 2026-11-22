import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:excel/excel.dart' hide TextSpan;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../data/finance_store.dart';
import '../data/models.dart';
import '../data/workbook_io.dart';
import '../ui/common.dart';
import '../ui/theme.dart';

/// Small valid workbook used by "Load sample workbook" in the Add Record dialog.
Uint8List buildSampleWorkbook() {
  final book = Excel.createExcel();
  const sheetName = 'GAS_CURRENT';
  if (book.tables.containsKey('Sheet1')) {
    book.rename('Sheet1', sheetName);
  }
  final sheet = book[sheetName];
  const values = [
    [
      'UACS Code',
      'UACS Name',
      'Allotment',
      'Obligation',
      'Disbursement',
      'Remarks',
    ],
    [
      '5020101000',
      'Traveling Expenses - Local',
      '100000',
      '25000',
      '10000',
      'Sample line',
    ],
  ];
  for (var r = 0; r < values.length; r++) {
    for (var c = 0; c < values[r].length; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
          .value = TextCellValue(
        values[r][c],
      );
    }
  }
  final encoded = book.encode();
  if (encoded == null || encoded.isEmpty) {
    throw const FinanceError('The sample workbook could not be created.');
  }
  return Uint8List.fromList(encoded);
}

class ImportController extends ChangeNotifier {
  ImportController(this.store, {required this.year});
  final FinanceStore store;
  String filename = '', program = '', fund = 'CURRENT';
  int year, sheetIndex = 0, page = 1;
  bool busy = false, updateExisting = false;
  List<ImportSheet> sheets = [];

  Future<void> loadBytes(Uint8List bytes, String name) async {
    if (busy) return;
    busy = true;
    notifyListeners();
    try {
      if (bytes.length > 25 * 1024 * 1024) {
        throw const FinanceError('Choose an Excel file smaller than 25 MB.');
      }
      final parsed = await compute(parseWorkbook, bytes);
      sheets = parsed;
      filename = name;
      sheetIndex = math.max(0, sheets.indexWhere((s) => s.error.isEmpty));
      syncSheet();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> browse(BuildContext context) async {
    if (busy) return;
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Excel Workbook', extensions: ['xlsx']),
        ],
      );
      if (file == null || !context.mounted) return;
      await loadBytes(await file.readAsBytes(), file.name);
    } catch (e) {
      if (context.mounted) _showReadError(context, e);
    }
  }

  Future<void> acceptDrop(BuildContext context, List<DropItem> files) async {
    if (busy) return;
    final file = files
        .where((f) => f.name.toLowerCase().endsWith('.xlsx'))
        .firstOrNull;
    if (file == null) {
      if (context.mounted) {
        showMessage(context, 'Choose an Excel file (.xlsx).', error: true);
      }
      return;
    }
    try {
      await loadBytes(await file.readAsBytes(), file.name);
    } catch (e) {
      if (context.mounted) _showReadError(context, e);
    }
  }

  Future<void> loadSample(BuildContext context) async {
    if (busy) return;
    try {
      await loadBytes(buildSampleWorkbook(), 'sample-workbook.xlsx');
    } catch (e) {
      if (context.mounted) _showReadError(context, e);
    }
  }

  void syncSheet() {
    final sheet = sheets[sheetIndex];
    final active = store.programs
        .where((p) => p.active)
        .map((p) => p.code)
        .toList();
    program = active.contains(sheet.program)
        ? sheet.program
        : active.firstOrNull ?? '';
    fund = sheet.fund;
    page = 1;
  }

  void chooseYear(int value) {
    year = value;
    page = 1;
    notifyListeners();
  }

  void chooseSheet(int value) {
    sheetIndex = value;
    syncSheet();
    notifyListeners();
  }

  void chooseProgram(String value) {
    program = value;
    page = 1;
    notifyListeners();
  }

  void chooseFund(String value) {
    fund = value;
    page = 1;
    notifyListeners();
  }

  void choosePage(int value) {
    page = value;
    notifyListeners();
  }

  void chooseUpdateExisting(bool value) {
    updateExisting = value;
    notifyListeners();
  }

  List<(ImportLine, BudgetRecord, String, String)> classified() {
    if (sheets.isEmpty) return [];
    final lines = sheets[sheetIndex].lines;
    final previous = {
      for (final r in store.records(year, program: program, fund: fund))
        r.code: r,
    };
    final counts = <String, int>{};
    for (final line in lines) {
      counts[line.code] = (counts[line.code] ?? 0) + 1;
    }
    return [
      for (final line in lines)
        (() {
          final record = line.record(year, program, fund),
              before = previous[line.code];
          final error = line.parseError.isNotEmpty
              ? line.parseError
              : (record.error ??
                    ((counts[line.code] ?? 0) > 1
                        ? 'This code appears more than once in this worksheet.'
                        : ''));
          final status = error.isNotEmpty
              ? 'Invalid'
              : before == null
              ? 'Added'
              : before.sameAmountsAndText(record)
              ? 'Unchanged'
              : 'Updated';
          return (line, record, status, error);
        })(),
    ];
  }

  Future<void> apply(BuildContext context) async {
    if (busy || sheets.isEmpty) return;
    final payload = classified()
        .where((r) => r.$3 == 'Added' || (r.$3 == 'Updated' && updateExisting))
        .map((r) => r.$2)
        .toList();
    try {
      final count = store.importRecords(
        payload,
        updateExisting: updateExisting,
      );
      if (!context.mounted) return;
      page = 1;
      notifyListeners();
      showMessage(context, '$count budget record(s) imported.');
    } catch (e) {
      if (context.mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  void _showReadError(BuildContext context, Object error) {
    if (!context.mounted) return;
    showMessage(
      context,
      error is FinanceError ? error.message : 'The Excel file could not be read. Check that it is a valid .xlsx workbook.',
      error: true,
    );
  }
}

class ExcelDropZone extends StatefulWidget {
  const ExcelDropZone({super.key, required this.session});
  final ImportController session;
  @override
  State<ExcelDropZone> createState() => _ExcelDropZoneState();
}

class _ExcelDropZoneState extends State<ExcelDropZone> {
  bool _hover = false, _dragging = false;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final active = _hover || _dragging;
    final caption = session.filename.isEmpty
        ? 'Drag and drop the file here, or click the button below.'
        : session.filename;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: DropTarget(
        enable: !session.busy,
        onDragEntered: (_) => setState(() => _dragging = true),
        onDragExited: (_) => setState(() => _dragging = false),
        onDragDone: (detail) {
          setState(() => _dragging = false);
          session.acceptDrop(context, detail.files);
        },
        child: CustomPaint(
          foregroundPainter: _DashedRRectPainter(
            color: active ? blue : const Color(0xffc5d0e2),
            radius: 12,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: active ? const Color(0xffeef4fc) : const Color(0xfff7f9fc),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 46,
                    height: 50,
                    child: CustomPaint(painter: _ExcelMarkPainter()),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Select an Excel File (.xlsx)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    caption,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: session.filename.isEmpty
                          ? const Color(0xff7d8ba3)
                          : ink,
                      fontWeight: session.filename.isEmpty
                          ? FontWeight.w400
                          : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: blue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: blue.withValues(alpha: 0.45),
                      disabledForegroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: session.busy
                        ? null
                        : () => session.browse(context),
                    icon: Icon(
                      session.busy
                          ? Icons.hourglass_top
                          : Icons.folder_outlined,
                      size: 16,
                    ),
                    label: Text(session.busy ? 'Reading…' : 'Browse File'),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: blue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: session.busy
                        ? null
                        : () => session.loadSample(context),
                    child: const Text('Load sample workbook'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ImportPreview extends StatelessWidget {
  const ImportPreview({super.key, required this.session});
  final ImportController session;
  @override
  Widget build(BuildContext context) {
    final rows = session.classified(), counts = <String, int>{};
    for (final row in rows) {
      counts[row.$3] = (counts[row.$3] ?? 0) + 1;
    }
    final eligible =
        (counts['Added'] ?? 0) +
        (session.updateExisting ? (counts['Updated'] ?? 0) : 0);
    final page = session.page
        .clamp(1, math.max(1, (rows.length / 25).ceil()))
        .toInt();
    final sheet = session.sheets[session.sheetIndex];
    return Panel(
      padding: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              SelectField(
                label: 'Fiscal Year',
                value: session.year,
                width: 130,
                items: [for (final y in session.store.years) (y, '$y')],
                onChanged: session.chooseYear,
              ),
              SelectField(
                label: 'Worksheet',
                value: session.sheetIndex,
                width: 220,
                items: [
                  for (var i = 0; i < session.sheets.length; i++)
                    (i, session.sheets[i].name),
                ],
                onChanged: session.chooseSheet,
              ),
              SelectField(
                label: 'Program',
                value: session.program,
                items: [
                  for (final p in session.store.programs.where((p) => p.active))
                    (p.code, p.code),
                ],
                onChanged: session.chooseProgram,
              ),
              SelectField(
                label: 'Fund Source',
                value: session.fund,
                items: const [
                  ('CURRENT', 'Current'),
                  ('CONTINUING', 'Continuing'),
                ],
                onChanged: session.chooseFund,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Import Preview',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (sheet.error.isNotEmpty)
            Text(sheet.error, style: const TextStyle(color: red))
          else
            Text(
              'Added ${counts['Added'] ?? 0}   ·   Updated ${counts['Updated'] ?? 0}   ·   Unchanged ${counts['Unchanged'] ?? 0}   ·   Invalid ${counts['Invalid'] ?? 0}',
              style: const TextStyle(color: muted),
            ),
          const SizedBox(height: 12),
          WideTable(
            columns: const [
              'Excel Row',
              'UACS Code',
              'Expense',
              'Allotment',
              'Obligation',
              'Disbursement',
              'Status',
            ],
            numeric: const {3, 4, 5},
            rows: [
              for (final r in rows.skip((page - 1) * 25).take(25))
                [
                  Text('${r.$1.number}'),
                  tableText(displayCode(r.$2.code)),
                  tableText(r.$2.name, width: 180),
                  Text(money(r.$2.allotment)),
                  Text(money(r.$2.obligation)),
                  Text(money(r.$2.disbursement)),
                  Tooltip(
                    message: r.$4,
                    child: tableText(
                      '${r.$3}${r.$4.isEmpty ? '' : ' · ${r.$4}'}',
                      width: 220,
                    ),
                  ),
                ],
            ],
          ),
          Pager(
            page: page,
            count: rows.length,
            pageSize: 25,
            onChanged: session.choosePage,
          ),
          const Divider(),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: session.updateExisting,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Apply updates to existing records',
              style: TextStyle(fontSize: 14),
            ),
            subtitle: const Text(
              'Replace the amounts, expense name, and remarks of matching lines.',
              style: TextStyle(fontSize: 12),
            ),
            onChanged: session.busy
                ? null
                : (v) => session.chooseUpdateExisting(v ?? false),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed:
                    eligible > 0 && session.program.isNotEmpty && !session.busy
                    ? () => session.apply(context)
                    : null,
                icon: const Icon(Icons.file_download_done, size: 18),
                label: Text(
                  'Import $eligible Record${eligible == 1 ? '' : 's'}',
                ),
              ),
              const Text(
                'Invalid and unchanged rows are skipped.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(0.8),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = 5.0, gap = 4.0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _ExcelMarkPainter extends CustomPainter {
  const _ExcelMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final page = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(6),
    );
    canvas.drawRRect(page, Paint()..color = Colors.white);
    canvas.drawRRect(
      page,
      Paint()
        ..color = const Color(0xffd5deea)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    final fold = Path()
      ..moveTo(size.width - 14, 0.6)
      ..lineTo(size.width - 0.6, 14)
      ..lineTo(size.width - 14, 14)
      ..close();
    canvas.drawPath(fold, Paint()..color = const Color(0xffe7eef6));
    canvas.drawLine(
      Offset(size.width - 14, 0.6),
      Offset(size.width - 0.6, 14),
      Paint()
        ..color = const Color(0xffd5deea)
        ..strokeWidth = 1.1,
    );
    final badge = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        4,
        size.height * 0.28,
        size.width * 0.46,
        size.height * 0.5,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(badge, Paint()..color = const Color(0xff1f7a45));
    final mark = TextPainter(
      text: const TextSpan(
        text: 'X',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          height: 1,
          fontFamily: 'Segoe UI',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    mark.paint(
      canvas,
      Offset(
        badge.outerRect.center.dx - mark.width / 2,
        badge.outerRect.center.dy - mark.height / 2,
      ),
    );
    mark.dispose();
    final line = Paint()
      ..color = const Color(0xff1f7a45)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final left = size.width * 0.58;
    final right = size.width - 7;
    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.4 + i * 0.16);
      canvas.drawLine(Offset(left, y), Offset(right, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
