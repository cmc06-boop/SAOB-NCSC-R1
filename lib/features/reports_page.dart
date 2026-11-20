import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:material_ui/material_ui.dart';
import 'package:printing/printing.dart';

import '../core/format.dart';
import '../data/finance_store.dart';
import '../data/models.dart';
import '../data/report_io.dart';
import '../ui/common.dart';
import '../ui/theme.dart';

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
          fontWeight: FontWeight.w600,
          color: muted,
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: width,
        child: InputDecorator(
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: EdgeInsets.fromLTRB(12, 12, 0, 12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              isDense: true,
              padding: const EdgeInsets.only(right: 2),
              value: items.any((e) => e.$1 == value) ? value : null,
              style: const TextStyle(
                fontFamily: 'Segoe UI',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
              items: [
                for (final e in items)
                  DropdownMenuItem<T>(
                    value: e.$1,
                    child: Text(
                      e.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: onChanged == null
                  ? null
                  : (v) {
                      if (v != null) onChanged!(v);
                    },
            ),
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
  String program = '', format = 'PDF';
  bool busy = false, preview = false;
  void change(VoidCallback fn) => setState(fn);
  void openPreview() {
    final rows = widget.store.records(year, program: program);
    if (rows.isEmpty) {
      showMessage(context, 'There are no records for this report.');
      return;
    }
    setState(() => preview = true);
  }

  Future<void> generate(String fmt) async {
    if (busy) return;
    final selectedYear = year, selectedProgram = program;
    const selectedType = _reportType;
    final rows = widget.store.records(selectedYear, program: selectedProgram);
    if (rows.isEmpty) {
      showMessage(context, 'There are no records for this report.');
      return;
    }
    setState(() => busy = true);
    try {
      final data = reportData(selectedType, rows);
      var completed = false;
      if (fmt == 'Print') {
        final bytes = await pdfReport(
          data,
          title: selectedType,
          year: selectedYear,
          program: selectedProgram,
        );
        completed = await Printing.layoutPdf(
          onLayout: (_) => bytes,
          name: 'NCSC Region I · $selectedType',
        );
      } else {
        final extension = fmt == 'PDF' ? 'pdf' : 'xlsx';
        final location = await getSaveLocation(
          suggestedName:
              'NCSC-R1-$selectedYear-${selectedProgram.isEmpty ? 'All' : selectedProgram}.$extension',
          acceptedTypeGroups: [
            XTypeGroup(label: fmt, extensions: [extension]),
          ],
        );
        if (location == null) return;
        final bytes = fmt == 'PDF'
            ? await pdfReport(
                data,
                title: selectedType,
                year: selectedYear,
                program: selectedProgram,
              )
            : excelReport(
                data,
                title: selectedType,
                year: selectedYear,
                program: selectedProgram,
              );
        final destination = location.path.toLowerCase().endsWith('.$extension')
            ? location.path
            : '${location.path}.$extension';
        await File(destination).writeAsBytes(bytes, flush: true);
        completed = true;
        if (mounted) showMessage(context, 'Report saved to $destination');
      }
      if (completed) {
        widget.store.logReport(
          selectedType,
          selectedYear,
          selectedProgram,
          fmt,
        );
      }
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
        !widget.store.programs.any((p) => p.code == program)) {
      program = '';
    }
    final records = widget.store.records(year, program: program);
    final totals = Totals(records);
    final history = widget.store.reportHistory;
    final utilization = totals.allotment == 0
        ? '—'
        : '${(totals.obligation * 100 / totals.allotment).toStringAsFixed(1)}%';
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
          width: 132,
          items: [for (final y in widget.store.years) (y, '$y')],
          onChanged: busy ? null : (v) => change(() => year = v),
        ),
        _HeaderFilter<String>(
          label: 'Program',
          value: program,
          width: 168,
          items: [
            ('', 'All Programs'),
            for (final p in widget.store.programs) (p.code, p.code),
          ],
          onChanged: busy ? null : (v) => change(() => program = v),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: Size.zero,
          ),
          onPressed: busy ? null : openPreview,
          icon: const Icon(Icons.description_outlined, size: 18),
          label: Text(busy ? 'Generating…' : 'Generate Report'),
        ),
      ],
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, c) => c.maxWidth < 980
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 8),
                      subtitle,
                      const SizedBox(height: 16),
                      actions,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 8),
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
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, c) {
              final chart = _UtilizationChart(year: year, records: records);
              final summary = _SummaryCard(
                totals: totals,
                utilization: utilization,
              );
              if (c.maxWidth < 860) {
                return Column(
                  children: [chart, const SizedBox(height: 16), summary],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 5, child: chart),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: summary),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _HistoryCard(history: history),
        ],
      ),
    );
  }

  Widget _previewPage(List<BudgetRecord> records) {
    final programLabel = program.isEmpty ? 'All Programs' : program;
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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Generate and download financial and budget reports.',
                  style: TextStyle(fontSize: 14, color: muted, height: 1.35),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => setState(() => preview = false),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Reports'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 280, child: _parameterCard()),
                const SizedBox(width: 16),
                Expanded(child: _previewCard(records, programLabel)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _parameterCard() {
    return Panel(
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
            width: double.infinity,
            items: [for (final y in widget.store.years) (y, '$y')],
            onChanged: busy ? null : (v) => change(() => year = v),
          ),
          const SizedBox(height: 14),
          SelectField<String>(
            label: 'Program *',
            value: program,
            dense: true,
            width: double.infinity,
            items: [
              ('', 'All Programs'),
              for (final p in widget.store.programs) (p.code, p.code),
            ],
            onChanged: busy ? null : (v) => change(() => program = v),
          ),
          const SizedBox(height: 16),
          const Text(
            'Report Format',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Radio<String>(
                value: 'PDF',
                groupValue: format,
                onChanged: busy
                    ? null
                    : (v) {
                        if (v != null) setState(() => format = v);
                      },
              ),
              const Icon(Icons.picture_as_pdf_outlined, size: 18, color: red),
              const SizedBox(width: 4),
              const Text('PDF'),
              Radio<String>(
                value: 'Excel',
                groupValue: format,
                onChanged: busy
                    ? null
                    : (v) {
                        if (v != null) setState(() => format = v);
                      },
              ),
              const Icon(
                Icons.grid_on_outlined,
                size: 18,
                color: Color(0xff15803d),
              ),
              const SizedBox(width: 4),
              const Text('Excel'),
            ],
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: busy ? null : openPreview,
            icon: const Icon(Icons.description_outlined, size: 18),
            label: Text(busy ? 'Generating…' : 'Generate Report'),
          ),
        ],
      ),
    );
  }

  Widget _previewCard(List<BudgetRecord> records, String programLabel) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Report Preview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: busy || records.isEmpty
                    ? null
                    : () => generate('Print'),
                icon: const Icon(Icons.print_outlined, size: 18),
                label: const Text('Print'),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                onSelected: records.isEmpty ? null : generate,
                enabled: !busy && records.isNotEmpty,
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'PDF', child: Text('Export PDF')),
                  PopupMenuItem(value: 'Excel', child: Text('Export Excel')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: blue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.download_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Export',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: Colors.white),
                    ],
                  ),
                ),
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
                  : SingleChildScrollView(
                      primary: false,
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      child: _ReportSheet(
                        title: _reportType,
                        year: year,
                        programLabel: programLabel,
                        table: _previewTable(records),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  _PreviewTable _previewTable(List<BudgetRecord> records) {
    return _PreviewTable(
      const [
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
            '${i + 1}',
            displayCode(records[i].code),
            records[i].name,
            money(records[i].allotment),
            money(records[i].obligation),
            rate(records[i].obligation, records[i].allotment),
            money(records[i].balance),
            money(records[i].disbursement),
            rate(records[i].disbursement, records[i].obligation),
          ],
      ],
      const {3, 4, 5, 6, 7, 8},
    );
  }
}

class _PreviewTable {
  const _PreviewTable(this.headers, this.rows, this.numeric);
  final List<String> headers;
  final List<List<String>> rows;
  final Set<int> numeric;
}

class _ReportSheet extends StatelessWidget {
  const _ReportSheet({
    required this.title,
    required this.year,
    required this.programLabel,
    required this.table,
  });
  final String title, programLabel;
  final int year;
  final _PreviewTable table;

  @override
  Widget build(BuildContext context) {
    Widget cell(String text, {bool header = false, bool right = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(
          text,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            fontSize: header ? 11 : 12,
            fontWeight: header ? FontWeight.w700 : FontWeight.w500,
            color: header ? navy : ink,
          ),
        ),
      );
    }

    return Column(
      children: [
        Image.asset('assets/ncsc-logo-transparent.png', width: 64, height: 64),
        const SizedBox(height: 8),
        const Text(
          'NATIONAL COMMISSION OF SENIOR CITIZENS',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const Text(
          'REGION I',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Program: $programLabel  |  Fiscal Year: $year',
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: const TableBorder(
              horizontalInside: BorderSide(color: line),
              bottom: BorderSide(color: line),
            ),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xffe7f0fb)),
                children: [
                  for (var i = 0; i < table.headers.length; i++)
                    cell(
                      table.headers[i],
                      header: true,
                      right: table.numeric.contains(i),
                    ),
                ],
              ),
              for (final row in table.rows)
                TableRow(
                  children: [
                    for (var i = 0; i < row.length; i++)
                      cell(row[i], right: table.numeric.contains(i)),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

const _disbursed = Color(0xff1e3a8a);
const _obligated = Color(0xff3b82f6);
const _balanceBar = Color(0xffbfdbfe);

class _UtilizationChart extends StatelessWidget {
  const _UtilizationChart({required this.year, required this.records});
  final int year;
  final List<BudgetRecord> records;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<BudgetRecord>>{};
    for (final r in records) {
      groups.putIfAbsent(r.program, () => []).add(r);
    }
    final totals = {for (final g in groups.entries) g.key: Totals(g.value)};
    final peak = totals.values.fold<int>(0, (m, t) {
      return math.max(
        m,
        math.max(t.disbursement, math.max(t.obligation, t.balance)),
      );
    });
    final ticks = _axisTicks(peak);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: blue, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Budget Utilization – $year',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const _LegendDot('Disbursed', _disbursed),
              const SizedBox(width: 12),
              const _LegendDot('Obligated', _obligated),
              const SizedBox(width: 12),
              const _LegendDot('Balance', _balanceBar),
            ],
          ),
          const SizedBox(height: 18),
          if (totals.isEmpty)
            const SizedBox(
              height: 220,
              child: Center(
                child: Text(
                  'No budget records for these filters.',
                  style: TextStyle(color: muted),
                ),
              ),
            )
          else
            SizedBox(
              height: 260,
              width: double.infinity,
              child: CustomPaint(
                painter: _UtilizationPainter(totals.entries.toList(), ticks),
              ),
            ),
        ],
      ),
    );
  }
}

class _UtilizationPainter extends CustomPainter {
  _UtilizationPainter(this.groups, this.ticks);
  final List<MapEntry<String, Totals>> groups;
  final List<int> ticks;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 112.0;
    const bottom = 30.0;
    const topPad = 8.0;
    final plot = Rect.fromLTRB(
      left,
      topPad,
      size.width - 4,
      size.height - bottom,
    );
    final grid = Paint()
      ..color = line
      ..strokeWidth = 1;
    const axisStyle = TextStyle(
      fontSize: 11,
      color: muted,
      fontFamily: 'Segoe UI',
    );
    final top = ticks.last;
    final steps = math.max(1, ticks.length - 1);
    canvas.drawLine(
      Offset(plot.left, plot.top),
      Offset(plot.left, plot.bottom),
      grid,
    );
    for (var i = 0; i < ticks.length; i++) {
      final y = plot.bottom - plot.height * i / steps;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final label = TextPainter(
        text: TextSpan(text: _axisMoney(ticks[i]), style: axisStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: left - 12);
      label.paint(
        canvas,
        Offset(plot.left - 8 - label.width, y - label.height / 2),
      );
    }
    if (groups.isEmpty || plot.width <= 0 || top <= 0) return;
    final slot = plot.width / groups.length;
    for (var g = 0; g < groups.length; g++) {
      final entry = groups[g];
      final values = [
        entry.value.disbursement,
        entry.value.obligation,
        entry.value.balance,
      ];
      const colors = [_disbursed, _obligated, _balanceBar];
      const gap = 6.0;
      final barWidth = math.min(40.0, math.max(4.0, (slot - 16 - gap * 2) / 3));
      final groupWidth = barWidth * 3 + gap * 2;
      var x = plot.left + slot * g + (slot - groupWidth) / 2;
      for (var b = 0; b < 3; b++) {
        final ratio = (values[b] / top).clamp(0.0, 1.0);
        final height = plot.height * ratio;
        if (height > 0.5) {
          final rect = Rect.fromLTWH(x, plot.bottom - height, barWidth, height);
          canvas.drawRRect(
            RRect.fromRectAndCorners(
              rect,
              topLeft: const Radius.circular(3),
              topRight: const Radius.circular(3),
            ),
            Paint()..color = colors[b],
          );
        }
        x += barWidth + gap;
      }
      final name = TextPainter(
        text: TextSpan(
          text: entry.key,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: ink,
            fontFamily: 'Segoe UI',
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: math.max(0, slot - 8));
      name.paint(
        canvas,
        Offset(plot.left + slot * g + (slot - name.width) / 2, plot.bottom + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _UtilizationPainter oldDelegate) => true;
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
  const _SummaryCard({required this.totals, required this.utilization});
  final Totals totals;
  final String utilization;
  @override
  Widget build(BuildContext context) {
    final entries = <(String, String, Color?, Color?)>[
      ('Total Budget', money(totals.allotment), null, null),
      ('Total Disbursed', money(totals.disbursement), null, null),
      ('Total Obligated', money(totals.obligation), null, null),
      (
        'Balance',
        money(totals.balance),
        const Color(0xffdcfce7),
        const Color(0xff15803d),
      ),
      ('Utilization Rate', utilization, const Color(0xffdbeafe), blue),
    ];
    Widget rowAt(int index) {
      final entry = entries[index];
      final badge = entry.$3;
      final value = badge == null
          ? Text(entry.$2, style: const TextStyle(fontWeight: FontWeight.w600))
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badge,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entry.$2,
                style: TextStyle(color: entry.$4, fontWeight: FontWeight.w700),
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
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.$1,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  value,
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.assignment_outlined, color: blue, size: 20),
              SizedBox(width: 8),
              Text(
                'Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xffdce6f5)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [for (var i = 0; i < entries.length; i++) rowAt(i)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history});
  final List<DbRow> history;

  static const _border = BorderSide(color: Color(0xffd5e1f2));
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

  Widget _cell(String text, {TextStyle style = _body, bool number = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Text(
        text,
        style: number
            ? const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: blue,
              )
            : style,
      ),
    );
  }

  TableRow _row(List<Widget> cells, Color color) => TableRow(
    decoration: BoxDecoration(color: color),
    children: [
      for (final cell in cells)
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: cell,
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(Icons.description_outlined, color: blue, size: 20),
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
                _cell('#', style: _header),
                _cell('Report Name', style: _header),
                _cell('Fiscal Year', style: _header),
                _cell('Date Generated', style: _header),
              ], const Color(0xffeef3fb)),
            ],
          ),
          Table(
            border: const TableBorder(
              horizontalInside: _border,
              verticalInside: _border,
            ),
            columnWidths: _columns,
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              if (history.isEmpty)
                _row([
                  _cell(''),
                  _cell(
                    'No reports generated yet.',
                    style: const TextStyle(fontSize: 13, color: muted),
                  ),
                  _cell(''),
                  _cell(''),
                ], Colors.white)
              else
                for (var i = 0; i < history.length; i++)
                  _row([
                    _cell('${i + 1}', number: true),
                    _cell(
                      '${history[i]['type']}${(history[i]['program'] as String).isEmpty ? '' : ' – ${history[i]['program']}'}',
                    ),
                    _cell('${history[i]['year']}'),
                    _cell(dateLabel(history[i]['at'])),
                  ], i.isOdd ? const Color(0xfff7f9fc) : Colors.white),
            ],
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
