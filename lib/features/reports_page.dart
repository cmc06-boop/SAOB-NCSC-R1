import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show MethodChannel;
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart' hide TextDirection;
import 'package:material_ui/material_ui.dart';
import 'package:printing/printing.dart';

import '../core/format.dart';
import '../data/export_file.dart';
import '../data/finance_store.dart';
import '../data/models.dart';
import '../data/report_io.dart';
import '../data/report_pdf_sections.dart';
import '../data/report_summary.dart';
import 'excel_report_preview.dart';
import '../ui/common.dart';
import '../ui/app_icon.dart';
import '../ui/theme.dart';

/// Distinct document-format symbols, drawn locally without extra packages.
class _ReportFileIcon extends StatelessWidget {
  const _ReportFileIcon({required this.format});

  final String format;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: ValueKey('reports-file-icon-${format.toLowerCase()}'),
    width: 20,
    height: 22,
    child: CustomPaint(
      painter: _ReportFilePainter(format == 'PDF'),
    ),
  );
}

class _ReportFilePainter extends CustomPainter {
  const _ReportFilePainter(this.isPdf);
  final bool isPdf;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 26);
    final accent = isPdf ? const Color(0xffd42035) : const Color(0xff107c41);
    final paper = Path()
      ..moveTo(4, 1)
      ..lineTo(16, 1)
      ..lineTo(22, 7)
      ..lineTo(22, 25)
      ..lineTo(4, 25)
      ..close();
    canvas.drawPath(paper, Paint()..color = Colors.white);
    final outline = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(paper, outline);
    canvas.drawPath(Path()..moveTo(16, 1)..lineTo(16, 7)..lineTo(22, 7), outline);
    if (isPdf) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(0, 13, 24, 10), const Radius.circular(2)),
        Paint()..color = accent,
      );
      _label(canvas, 'PDF', 8, const Offset(12, 18));
    } else {
      final grid = Paint()..color = accent..strokeWidth = .8;
      canvas.drawRect(const Rect.fromLTWH(11, 10, 9, 12), outline);
      canvas.drawLine(const Offset(15.5, 10), const Offset(15.5, 22), grid);
      for (final y in [14.0, 18.0]) {
        canvas.drawLine(Offset(11, y), Offset(20, y), grid);
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(0, 9, 13, 14), const Radius.circular(1.5)),
        Paint()..color = accent,
      );
      _label(canvas, 'X', 12, const Offset(6.5, 16));
    }
    canvas.restore();
  }

  void _label(Canvas canvas, String label, double fontSize, Offset center) {
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'Arial',
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
    text.dispose();
  }

  @override
  bool shouldRepaint(covariant _ReportFilePainter oldDelegate) =>
      oldDelegate.isPdf != isPdf;
}

class _HeaderFilter<T> extends StatelessWidget {
  const _HeaderFilter({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.width,
  });
  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T>? onChanged;
  final double width;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '$label:',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: width,
        child: AppDropdown<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          fieldTextStyle: const TextStyle(
            fontFamily: 'Segoe UI',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: EdgeInsets.fromLTRB(12, 10, 0, 10),
          ),
        ),
      ),
    ],
  );
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.store});
  final FinanceStore store;
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  static const _reportType = 'Budget Utilization Report';
  int year = manilaNow().year;
  String program = '';
  String reportFormat = 'PDF';
  String? lastExportFolder;
  bool busy = false, preview = false;
  double? previewZoom;
  void change(VoidCallback fn) => setState(fn);

  String get dataProgram => program == summarySelection ? '' : program;

  void openPreview() {
    final rows = widget.store.records(year, program: dataProgram);
    if (rows.isEmpty) {
      showMessage(context, 'There are no records for this report.');
      return;
    }
    setState(() {
      preview = true;
      previewZoom = null;
    });
  }

  // Suggest the next copy in the last destination before opening Save As.
  // The exclusive writer still protects files if the destination changes.
  Future<String> _nextDownloadName(String name) async {
    final folder = lastExportFolder;
    if (folder == null) return name;
    try {
      return await nextExportName(folder, name);
    } on FileSystemException {
      return name;
    }
  }

  Future<void> _printReport() async {
    if (busy) return;
    final selectedYear = year;
    final selectedProgram = program;
    final isSummary = selectedProgram == summarySelection;
    final rows = widget.store.records(
      selectedYear, program: isSummary ? '' : selectedProgram,
    );
    if (rows.isEmpty) {
      showMessage(context, 'There are no records for this report.');
      return;
    }
    setState(() => busy = true);
    try {
      final bytes = isSummary
          ? await pdfSaobSummaryReport(rows, year: selectedYear)
          : await pdfAllProgramsReport(rows, year: selectedYear);
      if (bytes.isEmpty) {
        throw const FinanceError('The report could not be prepared for printing.');
      }
      final label = isSummary ? 'Summary'
          : selectedProgram.isEmpty ? 'All' : selectedProgram;
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ModernPrintPreview(
          bytes: bytes,
          reportName: 'NCSC-R1-$selectedYear-$label',
        ),
      );
      if (confirmed != true || !mounted) return;
      final submitted = await Printing.layoutPdf(
        name: 'NCSC-R1-$selectedYear-$label',
        onLayout: (_) async => bytes,
        dynamicLayout: false,
      );
      if (submitted && mounted) {
        showMessage(context, 'Report sent for printing.');
      }
    } catch (e) {
      if (mounted) {
        showMessage(context,
          e is FinanceError ? e.message
              : 'Unable to print the report. Check your printer and try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> generate(String fmt) async {
    if (busy) return;
    final selectedYear = year, selectedProgram = program;
    const selectedType = _reportType;
    final isSummary = selectedProgram == summarySelection;
    final rows = widget.store.records(
      selectedYear,
      program: isSummary ? '' : selectedProgram,
    );
    if (rows.isEmpty) {
      showMessage(context, 'There are no records for this report.');
      return;
    }
    setState(() => busy = true);
    try {
      final extension = fmt == 'PDF' ? 'pdf' : 'xlsx';
      final fileLabel = isSummary
          ? 'Summary'
          : selectedProgram.isEmpty
              ? 'All'
              : selectedProgram;
      final defaultName = 'NCSC-R1-$selectedYear-$fileLabel.$extension';
      final suggestedName = await _nextDownloadName(defaultName);
      final String? selectedPath;
      if (Platform.isWindows) {
        selectedPath = await const MethodChannel('ncsc/export_save_as')
            .invokeMethod<String>('select', {
              'initialDirectory': lastExportFolder ?? '',
              'suggestedName': suggestedName,
              'extension': extension,
            });
      } else {
        final location = await getSaveLocation(
          initialDirectory: lastExportFolder,
          suggestedName: suggestedName,
          acceptedTypeGroups: [
            XTypeGroup(label: fmt == 'PDF' ? 'PDF' : 'Excel', extensions: [extension]),
          ],
          confirmButtonText: 'Download',
        );
        selectedPath = location?.path;
      }
      if (selectedPath == null) return;
      final folderPath = path.dirname(selectedPath);
      lastExportFolder = folderPath;
      final chosenName = path.basename(selectedPath);
      final normalizedName = chosenName.toLowerCase().endsWith('.$extension')
          ? chosenName
          : '$chosenName.$extension';
      // Recalculate automatic numbering in the actual destination at save
      // time. Never carry a stale suggested suffix into an empty folder.
      final fileName = resolveExportRequest(
        defaultName: defaultName,
        suggestedName: suggestedName,
        chosenName: normalizedName,
      );
      // All Programs and one selected program share the exact same PDF
      // renderer, including letterhead, columns, TOTAL row and spacing.
      final bytes = fmt == 'PDF'
          ? isSummary
              ? await pdfSaobSummaryReport(rows, year: selectedYear)
              : await pdfAllProgramsReport(rows, year: selectedYear)
          : isSummary
          ? excelSaobSummaryReport(rows, year: selectedYear)
          : excelReport(
              rows,
              title: selectedType,
              year: selectedYear,
              program: selectedProgram,
            );
      if (bytes.isEmpty) {
        throw const FinanceError('The report file could not be created.');
      }
      final destination = await saveExportCopy(
        folderPath: folderPath,
        fileName: fileName,
        bytes: bytes,
      );
      if (mounted) {
        showMessage(
          context,
          fmt == 'PDF'
              ? 'PDF report downloaded to $destination'
              : 'Excel report downloaded to $destination',
        );
      }
      widget.store.logReport(
        selectedType,
        selectedYear,
        isSummary ? 'Summary' : selectedProgram,
        fmt,
      );
    } on FileSystemException {
      if (mounted) {
        showMessage(
          context,
          'The report could not be saved. Choose a writable folder and close any open copy of that file.',
          error: true,
        );
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e is FinanceError
              ? e.message
              : 'The report could not be generated. Please try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (program.isNotEmpty &&
        program != summarySelection &&
        !widget.store.programs.any((p) => p.code == program)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => program = '');
      });
    }
    final records = widget.store.records(year, program: dataProgram);
    final totals = Totals(records);
    final history = widget.store.filteredReportHistory(
      year: year,
      program: program == summarySelection ? 'Summary' : program,
    );
    if (preview) return _previewPage(records);
    const title = Text(
      'Reports',
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1,
      ),
    );
    const subtitle = Text(
      'Generate and download financial and budget reports.',
      style: TextStyle(fontSize: 14, color: muted, height: 1.35),
    );
    final actions = Wrap(
      spacing: 12,
      runSpacing: 14,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _HeaderFilter<int>(
          label: 'Fiscal Year',
          value: year,
          width: 108,
          items: [for (final y in widget.store.years) (y, '$y')],
          onChanged: busy ? null : (v) => change(() => year = v),
        ),
        _HeaderFilter<String>(
          label: 'Program',
          value: program,
          width: 160,
          items: [
            ('', 'All Programs'),
            for (final p in widget.store.programs)
              (p.code, p.code),
          ],
          onChanged: busy ? null : (v) => change(() => program = v),
        ),
        HoverScaleButton(
          enabled: !busy,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xff1e3a8a),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: Size.zero,
            ),
            onPressed: busy ? null : openPreview,
            icon: const AppIcon('file-text', size: 18),
            label: Text(busy ? 'Generating…' : 'Generate Report'),
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, viewport) => SingleChildScrollView(
        key: const ValueKey('reports-page-scroll'),
        primary: false,
        padding: const EdgeInsets.fromLTRB(28, 18, 28, 14),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, c) => c.maxWidth < 980
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 5),
                      subtitle,
                      const SizedBox(height: 16),
                      actions,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 5),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          subtitle,
                          const SizedBox(width: 16),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: actions,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              // Keep the wide layout compact enough for desktop windows;
              // narrower or shorter viewports scroll the complete page.
              final panelHeight = c.maxWidth >= 900
                  ? (viewport.maxHeight - (viewport.maxWidth >= 1036 ? 360 : 400)).clamp(282.0, 870.0).toDouble()
                  : 350.0;
              final summary = _SummaryCard(
                totals: totals,
                expand: true,
              );
              final chart = _UtilizationChart(
                year: year,
                records: records,
                expand: true,
              );
              if (c.maxWidth < 900) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: panelHeight, child: chart),
                    const SizedBox(height: 16),
                    SizedBox(height: panelHeight, child: summary),
                  ],
                );
              }
              return SizedBox(
                height: panelHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: chart),
                    const SizedBox(width: 16),
                    SizedBox(width: 360, child: summary),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _HistoryCard(
            key: ValueKey('report-history-$year-$program'),
            history: history,
          ),
        ],
        ),
      ),
    );
  }

  Widget _previewPage(List<BudgetRecord> records) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reports',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: ink,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Generate and download financial and budget reports.',
            style: TextStyle(fontSize: 14, color: muted, height: 1.35),
          ),
          const SizedBox(height: 22),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _previewCard(records)),
                const SizedBox(width: 16),
                SizedBox(width: 280, child: _parameterCard(records)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _parameterCard(List<BudgetRecord> records) {
    return Panel(
      child: SingleChildScrollView(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Report Parameters',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          SelectField<int>(
            label: 'Fiscal Year *',
            value: year,
            dense: true,
            matchFilterStyle: true,
            width: double.infinity,
            items: [for (final y in widget.store.years) (y, '$y')],
            onChanged: busy ? null : (v) => change(() => year = v),
          ),
          const SizedBox(height: 14),
          SelectField<String>(
            label: 'Program *',
            value: program,
            dense: true,
            matchFilterStyle: true,
            width: double.infinity,
            items: [
              ('', 'All Programs'),
              (summarySelection, 'Summary'),
              for (final p in widget.store.programs)
                (p.code, p.code),
            ],
            onChanged: busy ? null : (v) => change(() => program = v),
          ),
          const SizedBox(height: 18),
          const Text(
            'Report Format',
            style: TextStyle(
              color: ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Center(
            key: const ValueKey('reports-format-group'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(child: _formatOption('PDF')),
                const SizedBox(width: 8),
                Expanded(child: _formatOption('Excel')),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _printButton(records),
          const SizedBox(height: 10),
          _exportButton(records),
        ],
        ),
      ),
    );
  }

  Widget _formatOption(String format) {
    final selected = reportFormat == format;
    return OutlinedButton(
      key: ValueKey('reports-format-${format.toLowerCase()}'),
      onPressed: busy ? null : () => setState(() => reportFormat = format),
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        backgroundColor: selected ? const Color(0xffedf3ff) : Colors.white,
        side: BorderSide(color: selected ? blue : line, width: selected ? 1.5 : 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        minimumSize: const Size(0, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        // Compact density subtracts 8 px from the button's minimum height.
        // Use standard density so both PDF and Excel controls stay >= 44 px.
        visualDensity: VisualDensity.standard,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppIcon(
            selected ? 'circle-dot' : 'circle',
            size: 18,
            color: selected ? blue : muted,
          ),
          const SizedBox(width: 4),
          _ReportFileIcon(format: format),
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                format,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _printButton(List<BudgetRecord> records) {
    return HoverScaleButton(
      enabled: !busy && records.isNotEmpty,
      child: OutlinedButton.icon(
        key: const ValueKey('reports-print'),
        onPressed: busy || records.isEmpty ? null : _printReport,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xff1e3a8a),
          side: const BorderSide(color: Color(0xff1e3a8a)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        icon: const Icon(Icons.print_outlined, size: 18),
        label: const Text('Print'),
      ),
    );
  }

  Widget _exportButton(List<BudgetRecord> records) {
    return HoverScaleButton(
      enabled: !busy && records.isNotEmpty,
      child: FilledButton.icon(
        key: const ValueKey('reports-export'),
        onPressed: busy || records.isEmpty ? null : () => generate(reportFormat),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xff1e3a8a),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        icon: const AppIcon('download', size: 18),
        label: const Text('Export'),
      ),
    );
  }

  Widget _zoomButton(String label, IconData icon, double delta, bool enabled) {
    return IconButton(
      key: ValueKey(delta < 0 ? 'reports-zoom-out' : 'reports-zoom-in'),
      tooltip: label,
      icon: Icon(icon, size: 17),
      onPressed: enabled
          ? () => setState(() {
              previewZoom = ((previewZoom ?? _lastFitZoom) + delta).clamp(0.4, 1.25).toDouble();
            })
          : null,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  double _lastFitZoom = 1.0;

  Widget _scaledPreview(List<BudgetRecord> records) {
    final summary = program == summarySelection;
    final fingerprint = Object.hashAll(records.map((row) => Object.hash(
      row.program, row.fund, row.code, row.name, row.allotment,
      row.obligation, row.disbursement, row.remarks,
    )));
    if (reportFormat == 'PDF') {
      return LayoutBuilder(
        builder: (context, constraints) {
          _lastFitZoom = math.min(1.0, math.max(0.01, (constraints.maxWidth - 24) / 842));
          return _PdfReportPages(
            key: ValueKey('pdf-$year-$program-$fingerprint'),
            records: records,
            year: year,
            summary: summary,
            scale: previewZoom ?? _lastFitZoom,
          );
        },
      );
    }
    return ExcelReportPreview(
      key: ValueKey('excel-$year-$program-$fingerprint'),
      records: records,
      year: year,
      program: program,
      zoom: previewZoom,
      onFitScale: (scale) => _lastFitZoom = scale,
    );
  }

  Widget _previewCard(List<BudgetRecord> records) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton.outlined(
                key: const ValueKey('reports-back'),
                tooltip: 'Back to Reports',
                onPressed: busy
                    ? null
                    : () => setState(() {
                        preview = false;
                        if (program == summarySelection) program = '';
                      }),
                iconSize: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: const BorderSide(color: line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const AppIcon('arrow-left', size: 16),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Report Preview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              _zoomButton('Zoom out', Icons.remove, -0.1, records.isNotEmpty),
              _zoomButton('Zoom in', Icons.add, 0.1, records.isNotEmpty),
              TextButton(
                key: const ValueKey('reports-fit'),
                onPressed: records.isEmpty ? null : () => setState(() => previewZoom = null),
                child: const Text('Fit'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: line),
              ),
              child: records.isEmpty
                  ? const Center(
                      child: Text(
                        'No budget records for these filters.',
                        style: TextStyle(color: muted),
                      ),
                    )
                  : _scaledPreview(records),
            ),
          ),
        ],
      ),
    );
  }

}

/// Render the same PDF used by Export, with vertically stacked paper pages.
/// No additional page numbers or footer labels are drawn by the viewer.
class _PdfReportPages extends StatefulWidget {
  const _PdfReportPages({
    super.key,
    required this.records,
    required this.year,
    required this.summary,
    required this.scale,
  });

  final List<BudgetRecord> records;
  final int year;
  final bool summary;
  final double scale;

  @override
  State<_PdfReportPages> createState() => _PdfReportPagesState();
}

class _PdfReportPagesState extends State<_PdfReportPages> {
  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  late final Future<List<Uint8List>> _pages = _render();

  Future<List<Uint8List>> _render() async {
    final bytes = widget.summary
        ? await pdfSaobSummaryReport(widget.records, year: widget.year)
        : await pdfAllProgramsReport(widget.records, year: widget.year);
    final pages = <Uint8List>[];
    await for (final page in Printing.raster(bytes, dpi: 120)) {
      if (!mounted) break;
      pages.add(await page.toPng());
    }
    return pages;
  }

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Uint8List>>(
      future: _pages,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('PDF preview unavailable. You can still export the report.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('Preparing PDF preview…'));
        }
        final pages = snapshot.data!;
        if (pages.isEmpty) {
          return const Center(child: Text('No report pages.'));
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final paperWidth = 842.0 * widget.scale;
            final contentWidth = math.max(constraints.maxWidth, paperWidth + 24);
            return ColoredBox(
              color: const Color(0xffe8edf5),
              child: Scrollbar(
                controller: _horizontal,
                notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
                thumbVisibility: contentWidth > constraints.maxWidth,
                child: SingleChildScrollView(
                  controller: _horizontal,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: contentWidth,
                    height: constraints.maxHeight,
                    child: Scrollbar(
                      controller: _vertical,
                      thumbVisibility: true,
                      notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
                      child: ListView.builder(
                        controller: _vertical,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: pages.length,
                        itemBuilder: (context, index) => Center(
                          child: Container(
                            width: paperWidth,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: const Color(0xffccd6e3)),
                              boxShadow: const [
                                BoxShadow(color: Color(0x18000000), blurRadius: 5, offset: Offset(0, 2)),
                              ],
                            ),
                            child: Image.memory(pages[index], fit: BoxFit.fitWidth),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

const _disbursed = Color(0xff1e3a8a);
const _obligated = Color(0xff3b82f6);
const _balanceBar = Color(0xffbfdbfe);

class _BarHover {
  const _BarHover(this.program, this.label, this.amount, this.percent);
  final String program, label;
  final int amount;
  final double? percent;
}

class _UtilizationChart extends StatefulWidget {
  const _UtilizationChart({
    required this.year,
    required this.records,
    this.expand = false,
  });
  final int year;
  final List<BudgetRecord> records;
  final bool expand;

  @override
  State<_UtilizationChart> createState() => _UtilizationChartState();
}

class _UtilizationChartState extends State<_UtilizationChart> {
  _BarHover? hovered;
  Offset? hoverPoint;
  final _chartScroll = ScrollController();

  @override
  void dispose() {
    _chartScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<BudgetRecord>>{};
    for (final r in widget.records) {
      groups.putIfAbsent(r.program, () => []).add(r);
    }
    final totals = {for (final g in groups.entries) g.key: Totals(g.value)};
    final entries = totals.entries.toList()
      ..sort((a, b) => programLabel(a.key).compareTo(programLabel(b.key)));
    final byRecord = entries.length > 1;
    final plot = entries.isEmpty
        ? const Center(
            child: Text(
              'No budget records for these filters.',
              style: TextStyle(color: muted),
            ),
          )
        : LayoutBuilder(
            builder: (context, limits) {
              final axisWidth = byRecord ? 72.0 : 128.0;
              final viewportWidth = math.max(0.0, limits.maxWidth - axisWidth);
              // Keep the normal chart unscrollable while three bars fit per group.
              final minimumWidth = entries.length * 76.0 + 6;
              final needsScroll = entries.length > 1 && minimumWidth > viewportWidth + 1;
              final contentWidth = needsScroll ? minimumWidth : viewportWidth;
              final height = math.max(0.0, limits.maxHeight - (needsScroll ? 16 : 0));
              final painter = _UtilizationPainter(entries, byRecord: byRecord, paintAxis: false);
              final plotSize = Size(contentWidth, height);
              final bars = MouseRegion(
                onExit: (_) => setState(() {
                  hovered = null;
                  hoverPoint = null;
                }),
                onHover: (event) {
                  final next = painter.barAt(
                    event.localPosition,
                    plotSize,
                  );
                  if (next?.program == hovered?.program &&
                      next?.label == hovered?.label &&
                      next?.amount == hovered?.amount) {
                    return;
                  }
                  setState(() {
                    hovered = next;
                    hoverPoint = next == null ? null : event.localPosition;
                  });
                },
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(child: CustomPaint(painter: painter)),
                    if (hovered != null && hoverPoint != null)
                      Positioned(
                        left: (hoverPoint!.dx + 12).clamp(
                          0.0, math.max(0.0, contentWidth - 215),
                        ),
                        top: (hoverPoint!.dy - 78).clamp(
                          0.0, math.max(0.0, height - 78),
                        ),
                        child: IgnorePointer(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 215),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: navy,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  money(hovered!.amount),
                                  style: const TextStyle(
                                    color: Colors.white, fontSize: 12,
                                  ),
                                ),
                                if (hovered!.percent != null)
                                  Text(
                                    '${hovered!.percent!.toStringAsFixed(2)}%',
                                    style: const TextStyle(
                                      color: Colors.white, fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: axisWidth,
                    height: height,
                    child: CustomPaint(
                      painter: _UtilizationPainter(entries, byRecord: byRecord, axisOnly: true),
                    ),
                  ),
                  Expanded(
                    child: needsScroll
                        ? ScrollConfiguration(
                            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                            child: Scrollbar(
                              controller: _chartScroll,
                              thumbVisibility: true,
                              thickness: 4,
                              radius: const Radius.circular(4),
                              scrollbarOrientation: ScrollbarOrientation.bottom,
                              child: SingleChildScrollView(
                                controller: _chartScroll,
                                scrollDirection: Axis.horizontal,
                                primary: false,
                                child: SizedBox(
                                  width: contentWidth,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(height: height, child: bars),
                                      const SizedBox(height: 16),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                        : SizedBox(height: height, child: bars),
                  ),
                ],
              );
            },
          );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIcon('chart-no-axes-column-increasing', color: blue, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  byRecord
                      ? 'Budget Utilization – ${widget.year} (% of allotment)'
                      : 'Budget Utilization – ${widget.year}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const _LegendDot('Disbursed', _disbursed),
              const SizedBox(width: 12),
              const _LegendDot('Obligated', _obligated),
              const SizedBox(width: 12),
              const _LegendDot('Balance', _balanceBar),
            ],
          ),
          const SizedBox(height: 18),
          if (widget.expand)
            Expanded(child: plot)
          else
            SizedBox(height: 274, child: plot),
        ],
      ),
    );
  }
}

class _UtilizationPainter extends CustomPainter {
  _UtilizationPainter(this.groups, {required this.byRecord, this.paintAxis = true, this.axisOnly = false});
  final bool paintAxis, axisOnly;
  final List<MapEntry<String, Totals>> groups;

  /// All Programs: each bar is that program's own record
  /// (amount ÷ allotment). One program: absolute pesos.
  final bool byRecord;

  int _pesoPeak() => groups.fold<int>(0, (m, e) {
    final t = e.value;
    return math.max(
      m,
      math.max(t.disbursement, math.max(t.obligation, math.max(0, t.balance))),
    );
  });

  /// Percents of that program's allotment: disbursed, obligated, balance.
  List<double> _recordPercents(Totals t) {
    if (t.allotment <= 0) return const [0, 0, 0];
    double pct(int part) => part <= 0 ? 0 : part * 100 / t.allotment;
    return [
      pct(t.disbursement),
      pct(t.obligation),
      pct(math.max(0, t.balance)),
    ];
  }

  double _percentPeak() {
    var peak = 100.0;
    for (final e in groups) {
      for (final v in _recordPercents(e.value)) {
        if (v > peak) peak = v;
      }
    }
    return peak;
  }

  _BarHover? barAt(Offset cursor, Size size) {
    if (groups.isEmpty) return null;
    final percentTicks = _percentAxis(_percentPeak());
    final pesoTicks = _axisTicks(_pesoPeak() <= 0 ? 1 : _pesoPeak());
    final top = byRecord
        ? percentTicks.last.toDouble()
        : math.max(1, pesoTicks.last).toDouble();
    final plot = Rect.fromLTRB(
      paintAxis ? (byRecord ? 72.0 : 128.0) : 0.0,
      8.0,
      size.width - 6,
      size.height - 48,
    );
    if (plot.width <= 0 || plot.height <= 0 || !plot.contains(cursor)) {
      return null;
    }
    final slot = plot.width / groups.length;
    const labels = ['Disbursed', 'Obligated', 'Balance'];
    const gap = 4.0;
    final barWidth = math.min(22.0, math.max(10.0, (slot - 28 - gap * 2) / 3));
    final groupWidth = barWidth * 3 + gap * 2;
    for (var g = 0; g < groups.length; g++) {
      final t = groups[g].value;
      final amounts = [t.disbursement, t.obligation, math.max(0, t.balance)];
      final values = byRecord
          ? _recordPercents(t)
          : amounts.map((v) => v.toDouble()).toList();
      var x = plot.left + slot * g + (slot - groupWidth) / 2;
      for (var b = 0; b < 3; b++) {
        final value = values[b];
        final height = plot.height * (value / top).clamp(0.0, 1.0);
        if (value > 0 &&
            height >= 1 &&
            Rect.fromLTWH(x, plot.bottom - height, barWidth, height)
                .contains(cursor)) {
          return _BarHover(
            programLabel(groups[g].key),
            labels[b],
            amounts[b],
            t.allotment > 0 ? amounts[b] * 100 / t.allotment : null,
          );
        }
        x += barWidth + gap;
      }
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final percentTop = _percentPeak();
    final percentTicks = _percentAxis(percentTop);
    final pesoTicks = _axisTicks(_pesoPeak() <= 0 ? 1 : _pesoPeak());
    final top = byRecord
        ? percentTicks.last.toDouble()
        : math.max(1, pesoTicks.last).toDouble();

    const left = 72.0;
    const pesoLeft = 128.0;
    const bottom = 48.0;
    const topPad = 8.0;
    final axisLeft = paintAxis ? (byRecord ? left : pesoLeft) : 0.0;
    final plot = Rect.fromLTRB(
      axisLeft,
      topPad,
      axisOnly ? axisLeft + 1 : size.width - 6,
      size.height - bottom,
    );
    if (plot.width <= 0 || plot.height <= 0 || groups.isEmpty) return;

    final grid = Paint()
      ..color = const Color(0xffdce4ef)
      ..strokeWidth = .7;
    const axisStyle = TextStyle(
      fontSize: 11,
      color: Color(0xff8b97ab),
      fontFamily: 'Segoe UI',
    );

    final tickCount = byRecord ? percentTicks.length : pesoTicks.length;
    for (var i = 0; i < tickCount; i++) {
      final tick = byRecord ? percentTicks[i].toDouble() : pesoTicks[i].toDouble();
      final y = plot.bottom - plot.height * (tick / top).clamp(0.0, 1.0);
      if (!axisOnly) {
        const dash = 4.0;
        const gap = 4.0;
        for (var x = plot.left; x < plot.right; x += dash + gap) {
          canvas.drawLine(
            Offset(x, y),
            Offset(math.min(x + dash, plot.right), y),
            grid,
          );
        }
      }
      if (!paintAxis) continue;
      final label = TextPainter(
        text: TextSpan(
          text: byRecord ? '${tick.round()}%' : _axisMoney(pesoTicks[i]),
          style: axisStyle,
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      label.paint(
        canvas,
        Offset(plot.left - 10 - label.width, y - label.height / 2),
      );
    }

    if (axisOnly) return;
    final slot = plot.width / groups.length;
    const colors = [_disbursed, _obligated, _balanceBar];
    for (var g = 0; g < groups.length; g++) {
      final entry = groups[g];
      final t = entry.value;
      final values = byRecord
          ? _recordPercents(t)
          : [
              t.disbursement.toDouble(),
              t.obligation.toDouble(),
              math.max(0, t.balance).toDouble(),
            ];
      const gap = 4.0;
      final barWidth = math.min(22.0, math.max(10.0, (slot - 28 - gap * 2) / 3));
      final groupWidth = barWidth * 3 + gap * 2;
      var x = plot.left + slot * g + (slot - groupWidth) / 2;
      for (var b = 0; b < 3; b++) {
        final value = values[b];
        if (value > 0) {
          final height = plot.height * (value / top).clamp(0.0, 1.0);
          if (height >= 1) {
            final rect = Rect.fromLTWH(x, plot.bottom - height, barWidth, height);
            final base = colors[b];
            final radius = Radius.circular(math.min(5.0, math.min(barWidth / 2, height / 2)));
            final gradient = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                base,
                Color.lerp(base, Colors.white, .20)!,
              ],
            );
            canvas.drawRRect(
              RRect.fromRectAndRadius(rect, radius),
              Paint()..shader = gradient.createShader(rect),
            );
          }
        }
        x += barWidth + gap;
      }

      final parts = _chartLabelParts(entry.key);
      final maxLabel = math.max(0.0, slot - 4);
      final title = TextPainter(
        text: TextSpan(
          text: parts.$1,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: ink,
            fontFamily: 'Segoe UI',
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: maxLabel);
      final centerX = plot.left + slot * g + slot / 2;
      var labelY = plot.bottom + 8;
      title.paint(canvas, Offset(centerX - title.width / 2, labelY));
      if (parts.$2 != null) {
        labelY += title.height + 1;
        final sub = TextPainter(
          text: TextSpan(
            text: parts.$2,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xff8b97ab),
              fontFamily: 'Segoe UI',
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: maxLabel);
        sub.paint(canvas, Offset(centerX - sub.width / 2, labelY));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _UtilizationPainter oldDelegate) =>
      oldDelegate.byRecord != byRecord || oldDelegate.groups != groups ||
      oldDelegate.paintAxis != paintAxis || oldDelegate.axisOnly != axisOnly;
}

List<int> _percentAxis(double peak) {
  final top = math.max(100.0, peak);
  const step = 20;
  final count = (top / step).ceil().clamp(5, 10);
  return [for (var i = 0; i <= count; i++) step * i];
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12, color: muted)),
    ],
  );
}

/// Chart axis: ATOP_Continuing → ("ATOP", "Continuing").
(String, String?) _chartLabelParts(String code) {
  final trimmed = code.trim();
  final upper = trimmed.toUpperCase();
  if (upper.endsWith('CONTINUING')) {
    final prefix = upper
        .substring(0, upper.length - 'CONTINUING'.length)
        .replaceAll(RegExp(r'[_\s]+'), '');
    return (prefix.isEmpty ? trimmed : prefix, 'Continuing');
  }
  if (upper.endsWith('CURRENT')) {
    final prefix = upper
        .substring(0, upper.length - 'CURRENT'.length)
        .replaceAll(RegExp(r'[_\s]+'), '');
    return (prefix.isEmpty ? trimmed : prefix, 'Current');
  }
  return (trimmed.isEmpty ? code : trimmed, null);
}

List<int> _axisTicks(int peakCents) {
  if (peakCents <= 0) return [0, 10000];
  final headroom = peakCents * 1.1;
  final rough = headroom / 5;
  final mag = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
  final norm = rough / mag;
  final nice = norm <= 1
      ? 1.0
      : norm <= 2
      ? 2.0
      : norm <= 2.5
      ? 2.5
      : norm <= 5
      ? 5.0
      : 10.0;
  final step = nice * mag;
  final count = (headroom / step).ceil().clamp(2, 8);
  return [for (var i = 0; i <= count; i++) (step * i).round()];
}

String _axisMoney(int cents) => NumberFormat.currency(
  locale: 'en_PH',
  symbol: '₱',
  decimalDigits: 0,
).format(cents / 100);

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totals,
    this.expand = false,
  });
  final Totals totals;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final entries = <(String, String, Color?, Color?)>[
      ('Allotment', money(totals.allotment), null, null),
      ('Obligation', money(totals.obligation), null, null),
      (
        'Unobligated Allotment',
        money(totals.balance),
        const Color(0xffdcfce7),
        const Color(0xff15803d),
      ),
      (
        'Utilization Rate',
        rate(totals.obligation, totals.allotment),
        const Color(0xffdbeafe),
        blue,
      ),
      ('Disbursement', money(totals.disbursement), null, null),
      (
        'Disbursement Rate',
        rate(totals.disbursement, totals.obligation),
        const Color(0xffdbeafe),
        blue,
      ),
    ];
    Widget rowAt(int index) {
      final entry = entries[index];
      final badge = entry.$3;
      final valueStyle = TextStyle(
        color: entry.$4 ?? ink,
        fontWeight: badge == null ? FontWeight.w600 : FontWeight.w700,
        fontSize: 13,
        height: 1.15,
      );
      final value = badge == null
          ? Text(
              entry.$2,
              textAlign: TextAlign.right,
              softWrap: true,
              style: valueStyle,
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: badge,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entry.$2,
                textAlign: TextAlign.right,
                softWrap: true,
                style: valueStyle,
              ),
            );
      return DecoratedBox(
        decoration: BoxDecoration(
          color: index.isOdd ? const Color(0xfff3f7fc) : Colors.white,
          border: Border(
            bottom: BorderSide(
              color: index == entries.length - 1
                  ? Colors.transparent
                  : const Color(0xffdce6f5),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      entry.$1,
                      softWrap: true,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 6,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: value,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final table = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xffdce6f5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            for (var i = 0; i < entries.length; i++)
              expand ? Expanded(child: rowAt(i)) : rowAt(i),
          ],
        ),
      ),
    );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              AppIcon('clipboard-list', color: blue, size: 20),
              SizedBox(width: 8),
              Text(
                'Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (expand) Expanded(child: table) else table,
        ],
      ),
    );
  }
}

class _HistoryCard extends StatefulWidget {
  const _HistoryCard({super.key, required this.history});
  final List<DbRow> history;

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  final _historyScroll = ScrollController();

  @override
  void dispose() {
    _historyScroll.dispose();
    super.dispose();
  }

  String _reportName(DbRow report) => generatedReportName(
    (report['program'] as String? ?? ''),
    (report['format'] as String? ?? ''),
  );

  static const _rowHeight = 32.0;
  static const _border = BorderSide(color: Color(0xffc3d2e6));
  static const _columns = <int, TableColumnWidth>{
    0: FixedColumnWidth(48),
    1: FlexColumnWidth(3),
    2: FlexColumnWidth(1.2),
    3: FlexColumnWidth(2),
  };
  static const _header = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: navy,
  );
  static const _body = TextStyle(fontSize: 13, color: ink);

  Widget _cell(String text, {TextStyle style = _body, bool number = false, bool center = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(center ? 8 : 12, 3, 8, 3),
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.left,
        softWrap: true,
        style: number
            ? const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: blue,
                height: 1.3,
              )
            : style.copyWith(height: style.height ?? 1.3),
      ),
    );
  }

  TableRow _row(
    List<Widget> cells,
    Color color, {
    bool center = false,
    Set<int> centeredColumns = const {},
  }) => TableRow(
    decoration: BoxDecoration(color: color),
    children: [
      for (final (index, cell) in cells.indexed)
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _rowHeight),
            child: Align(
              alignment: center || centeredColumns.contains(index)
                  ? Alignment.center
                  : Alignment.centerLeft,
              child: cell,
            ),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 204),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                AppIcon('file-text', color: blue, size: 20),
                SizedBox(width: 8),
                Text(
                  'Generated Reports',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: widget.history.isEmpty
                ? const SizedBox(
                    height: 5 * _rowHeight,
                    child: Center(child: Text('No reports found for the selected filters.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: muted),
                    )),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Table(
                  border: const TableBorder(
                    verticalInside: _border,
                    bottom: _border,
                  ),
                  columnWidths: _columns,
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    _row([
                      _cell('#', style: _header, center: true),
                      _cell('Report Name', style: _header, center: true),
                      _cell('Fiscal Year', style: _header, center: true),
                      _cell('Date Generated', style: _header, center: true),
                    ], const Color(0xffcdddf4), center: true),
                  ],
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 4 * _rowHeight, maxHeight: 4 * _rowHeight),
                  child: Scrollbar(
                    controller: _historyScroll,
                    thumbVisibility: widget.history.length >= 5,
                    child: SingleChildScrollView(
                      controller: _historyScroll,
                      primary: false,
                      child: Table(
                        border: const TableBorder(
                          horizontalInside: _border,
                          verticalInside: _border,
                        ),
                        columnWidths: _columns,
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        children: [
                            for (var i = 0; i < widget.history.length; i++)
                              _row([
                                _cell('${i + 1}', number: true),
                                _cell(_reportName(widget.history[i])),
                                _cell('${widget.history[i]['year']}', center: true),
                                _cell(dateLabel(widget.history[i]['at']), center: true),
                              ], i.isOdd ? const Color(0xfff8fafc) : Colors.white,
                                  centeredColumns: const {2, 3}),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}


/// In-app print preview with the same report bytes sent to the printer.
class _ModernPrintPreview extends StatelessWidget {
  const _ModernPrintPreview({required this.bytes, required this.reportName});
  final Uint8List bytes;
  final String reportName;

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SizedBox(
        width: math.min(1040.0, viewport.width - 48),
        height: math.min(820.0, viewport.height - 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 14),
              child: Row(
                children: [
                  const Icon(Icons.print_outlined, color: navy, size: 25),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Print Preview', style: TextStyle(
                          color: navy, fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(reportName, style: const TextStyle(color: muted, fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close, color: muted),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ColoredBox(
                color: const Color(0xffedf2fa),
                child: PdfPreview(
                  build: (_) async => bytes,
                  useActions: false,
                  allowPrinting: false,
                  allowSharing: false,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  scrollViewDecoration: const BoxDecoration(color: Color(0xffedf2fa)),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Text('Review the report before choosing a printer.',
                      style: TextStyle(color: muted, fontSize: 12)),
                  ),
                  const SizedBox(width: 12),
                  HoverScaleButton(
                    enabled: true,
                    child: TextButton(
                      style: dialogCancelStyle(),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  HoverScaleButton(
                    enabled: true,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: navy, foregroundColor: Colors.white),
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: const Text('Print'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
