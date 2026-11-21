import 'dart:math' as math;
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/report_io.dart';
import '../ui/theme.dart';

enum _Pages { all, odd, even, custom }

Future<bool> showReportPrintDialog(
  BuildContext context, {
  required ReportData data,
  required String title,
  required int year,
  required String program,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _PrintDialog(
      data: data,
      title: title,
      year: year,
      program: program,
    ),
  ).then((printed) => printed ?? false);
}

class _PrintDialog extends StatefulWidget {
  const _PrintDialog({
    required this.data,
    required this.title,
    required this.year,
    required this.program,
  });

  final ReportData data;
  final String title;
  final int year;
  final String program;

  @override
  State<_PrintDialog> createState() => _PrintDialogState();
}

class _PrintDialogState extends State<_PrintDialog> {
  final _copies = TextEditingController(text: '1');
  final _range = TextEditingController();
  List<Printer> _printers = [];
  Printer? _printer;
  bool _landscape = true;
  _Pages _pages = _Pages.all;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Uint8List? _pdf;
  List<Uint8List> _preview = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _copies.dispose();
    _range.dispose();
    super.dispose();
  }

  PdfPageFormat get _format =>
      _landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final listed = await Printing.listPrinters();
      final bytes = await pdfReport(
        widget.data,
        title: widget.title,
        year: widget.year,
        program: widget.program,
        pageFormat: _format,
      );
      final images = <Uint8List>[];
      await for (final page in Printing.raster(bytes, dpi: 80)) {
        images.add(await page.toPng());
      }
      if (!mounted) return;
      final available = listed.where((printer) => printer.isAvailable).toList();
      Printer? selected = _printer;
      if (selected == null ||
          !available.any((printer) => printer.url == selected!.url)) {
        selected = available.cast<Printer?>().firstWhere(
          (printer) => printer!.isDefault,
          orElse: () => available.isEmpty ? null : available.first,
        );
      }
      setState(() {
        _printers = available;
        _printer = selected;
        _pdf = bytes;
        _preview = images;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'The print preview could not be prepared. Please try again.';
      });
    }
  }

  int get _copyCount {
    final count = int.tryParse(_copies.text.trim()) ?? 1;
    return count.clamp(1, 99);
  }

  List<int> get _selectedPages {
    final count = _preview.length;
    final all = [for (var page = 1; page <= count; page++) page];
    switch (_pages) {
      case _Pages.all:
        return all;
      case _Pages.odd:
        return all.where((page) => page.isOdd).toList();
      case _Pages.even:
        return all.where((page) => page.isEven).toList();
      case _Pages.custom:
        return _parseRange(_range.text, count);
    }
  }

  List<int> _parseRange(String input, int count) {
    final pages = <int>{};
    for (final part in input.split(',')) {
      final piece = part.trim();
      if (piece.isEmpty) continue;
      final bounds = piece.split('-');
      if (bounds.length == 1) {
        final page = int.tryParse(bounds[0]);
        if (page != null && page >= 1 && page <= count) pages.add(page);
      } else if (bounds.length == 2) {
        final start = int.tryParse(bounds[0].trim());
        final end = int.tryParse(bounds[1].trim());
        if (start == null || end == null) continue;
        for (var page = math.min(start, end);
            page <= math.max(start, end);
            page++) {
          if (page >= 1 && page <= count) pages.add(page);
        }
      }
    }
    final sorted = pages.toList()..sort();
    return sorted;
  }

  Future<Uint8List> _pdfForPages(List<int> pages) async {
    final source = _pdf!;
    if (pages.length == _preview.length) return source;
    final rasters = await Printing.raster(
      source,
      pages: [for (final page in pages) page - 1],
      dpi: 140,
    ).toList();
    final document = pw.Document();
    for (final raster in rasters) {
      final png = await raster.toPng();
      document.addPage(
        pw.Page(
          pageFormat: _format,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.fill),
        ),
      );
    }
    return document.save();
  }

  Future<void> _print() async {
    final pages = _selectedPages;
    if (_sending || pages.isEmpty || _pdf == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final bytes = await _pdfForPages(pages);
      final name = 'NCSC Region I · ${widget.title}';
      // The PDF is already in the orientation shown in the preview.
      // Passing that page format makes Windows select the same orientation.
      Future<Uint8List> layout(PdfPageFormat _) async => bytes;
      var printed = false;
      if (_printer == null) {
        printed = await Printing.layoutPdf(
          onLayout: layout,
          name: name,
          format: _format,
          dynamicLayout: true,
        );
      } else {
        for (var copy = 0; copy < _copyCount; copy++) {
          printed = await Printing.directPrintPdf(
            printer: _printer!,
            onLayout: layout,
            name: name,
            format: _format,
            dynamicLayout: true,
          );
          if (!printed) break;
        }
      }
      if (printed && mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'The report could not be printed. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheets = _selectedPages.length * (_preview.isEmpty ? 0 : _copyCount);
    final sheetLabel = sheets == 1 ? '1 sheet of paper' : '$sheets sheets of paper';
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 1100,
        height: 700,
        child: Row(
          children: [
            SizedBox(
              width: 300,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Print',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _loading ? 'Preparing preview…' : 'Total: $sheetLabel',
                      style: const TextStyle(fontSize: 13, color: muted),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Printer',
                      style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                    ),
                    const SizedBox(height: 6),
                    if (_printers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'No printer found. Print will open the system dialog.',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      )
                    else
                      DropdownButtonFormField<Printer>(
                        key: ValueKey(_printer?.url),
                        initialValue: _printer,
                        isExpanded: true,
                        decoration: const InputDecoration(isDense: true),
                        items: [
                          for (final printer in _printers)
                            DropdownMenuItem(
                              value: printer,
                              child: Text(
                                printer.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _loading || _sending
                            ? null
                            : (printer) => setState(() => _printer = printer),
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      'Copies',
                      style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _copies,
                      enabled: !_sending,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(isDense: true),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Layout',
                      style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                    ),
                    _option('Portrait', !_landscape, () {
                      if (_landscape && !_sending) {
                        setState(() => _landscape = false);
                        _load();
                      }
                    }),
                    _option('Landscape', _landscape, () {
                      if (!_landscape && !_sending) {
                        setState(() => _landscape = true);
                        _load();
                      }
                    }),
                    const SizedBox(height: 8),
                    const Text(
                      'Pages',
                      style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                    ),
                    _pageOption('All', _Pages.all),
                    _pageOption('Odd pages only', _Pages.odd),
                    _pageOption('Even pages only', _Pages.even),
                    _pageOption('Custom', _Pages.custom),
                    Padding(
                      padding: const EdgeInsets.only(left: 36),
                      child: TextField(
                        controller: _range,
                        enabled: _pages == _Pages.custom && !_sending,
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'e.g. 1-5, 8, 11-13',
                        ),
                        onTap: () => setState(() => _pages = _Pages.custom),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: red, fontSize: 12),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _loading ||
                                    _sending ||
                                    _pdf == null ||
                                    _selectedPages.isEmpty
                                ? null
                                : _print,
                            child: Text(_sending ? 'Printing…' : 'Print'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _sending
                                ? null
                                : () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1, color: line),
            Expanded(child: _previewPane()),
          ],
        ),
      ),
    );
  }

  Widget _option(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: _sending ? null : onTap,
      child: Row(
        children: [
          Radio<bool>(
            value: true,
            groupValue: selected,
            onChanged: _sending ? null : (_) => onTap(),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Text(label),
        ],
      ),
    );
  }

  Widget _pageOption(String label, _Pages value) {
    return InkWell(
      onTap: _sending ? null : () => setState(() => _pages = value),
      child: Row(
        children: [
          Radio<_Pages>(
            value: value,
            groupValue: _pages,
            onChanged: _sending
                ? null
                : (next) {
                    if (next != null) setState(() => _pages = next);
                  },
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Text(label),
        ],
      ),
    );
  }

  Widget _previewPane() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_preview.isEmpty) {
      return const Center(
        child: Text(
          'No pages to preview.',
          style: TextStyle(color: muted),
        ),
      );
    }
    final visible = _selectedPages;
    return ColoredBox(
      color: const Color(0xffeef1f4),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
        itemCount: visible.length,
        separatorBuilder: (_, _) => const SizedBox(height: 18),
        itemBuilder: (context, index) {
          final page = visible[index];
          return Center(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Image.memory(
                _preview[page - 1],
                width: _landscape ? 620 : 440,
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}
