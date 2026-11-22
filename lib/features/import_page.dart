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

/// Sample workbook used by unit tests.
Uint8List buildSampleWorkbook() {
  final book = Excel.createExcel();
  const sheetName = 'Current';
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
  ImportController(
    this.store, {
    required this.year,
    this.onImported,
  });
  final FinanceStore store;
  final VoidCallback? onImported;
  String filename = '';
  int year;
  bool busy = false;
  static const _fund = 'CURRENT';

  Future<void> importFile(BuildContext context, Uint8List bytes, String name) async {
    if (busy) return;
    busy = true;
    filename = name;
    // Excel import always targets the current fiscal year.
    year = manilaNow().year;
    notifyListeners();
    try {
      if (bytes.length > 25 * 1024 * 1024) {
        throw const FinanceError('Choose an Excel file smaller than 25 MB.');
      }
      final sheets = await compute(parseWorkbook, bytes);
      var imported = 0;
      var programs = 0;
      final linesByProgram = <String, int>{};
      for (final sheet in sheets) {
        if (sheet.error.isNotEmpty || sheet.program.isEmpty) continue;
        final seen = <String>{};
        final payload = <BudgetRecord>[];
        for (final line in sheet.lines) {
          final key = codeKey(line.code);
          // Real UACS lines only (parser already filters; keep as a safety net).
          if (!RegExp(r'^\d{8,14}$').hasMatch(key)) continue;
          final name = line.name.trim().isEmpty ? key : line.name.trim();
          final record = BudgetRecord(
            year: year,
            program: sheet.program,
            fund: _fund,
            code: key,
            name: name,
            allotment: line.allotment < 0 ? 0 : line.allotment,
            obligation: line.obligation < 0 ? 0 : line.obligation,
            disbursement: line.disbursement < 0 ? 0 : line.disbursement,
            remarks: line.remarks,
          );
          // Keep the first UACS row (first SAOB table). Later duplicates on the
          // same sheet are usually a stacked Continuing block — do not overwrite.
          if (!seen.add(key)) continue;
          payload.add(record);
        }
        if (payload.isEmpty) continue;
        final count = store.importRecords(
          payload,
          updateExisting: true,
          programName: programNameFromSheet(sheet.name),
        );
        imported += count;
        programs++;
        if (count > 0) {
          linesByProgram[sheet.program] =
              (linesByProgram[sheet.program] ?? 0) + count;
        }
      }
      if (!context.mounted) return;
      if (imported == 0 && programs == 0) {
        throw const FinanceError(
          'No matching worksheets were found. Use sheets with the same Excel format (UACS Code, UACS Name, Allotment, Obligation, Disbursement).',
        );
      }
      if (imported == 0) {
        showMessage(
          context,
          'Workbook read, but there were no new or changed budget lines to save.',
        );
      } else {
        store.logWorkbookImport(filename: name, year: year);
        showMessage(
          context,
          '$imported budget record(s) imported'
          '${linesByProgram.length > 1 ? ' from ${linesByProgram.length} programs' : ''}.',
        );
      }
      onImported?.call();
    } catch (e) {
      if (context.mounted) {
        showMessage(
          context,
          e is FinanceError
              ? e.message
              : 'The Excel file could not be imported. Check that it is a valid .xlsx workbook.',
          error: true,
        );
      }
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
      await importFile(context, await file.readAsBytes(), file.name);
    } catch (e) {
      if (context.mounted) {
        showMessage(
          context,
          e is FinanceError
              ? e.message
              : 'The Excel file could not be read.',
          error: true,
        );
      }
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
      await importFile(context, await file.readAsBytes(), file.name);
    } catch (e) {
      if (context.mounted) {
        showMessage(
          context,
          e is FinanceError
              ? e.message
              : 'The Excel file could not be read.',
          error: true,
        );
      }
    }
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
    final caption = session.busy
        ? 'Importing…'
        : session.filename.isEmpty
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
                      color: session.filename.isEmpty && !session.busy
                          ? const Color(0xff7d8ba3)
                          : ink,
                      fontWeight: session.filename.isEmpty && !session.busy
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
                    label: Text(session.busy ? 'Importing…' : 'Browse File'),
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
