import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../data/finance_store.dart';
import '../data/models.dart';
import '../data/report_io.dart';
import '../ui/common.dart';
import '../ui/theme.dart';
import 'print_dialog.dart';

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
  String program = '';
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
        if (mounted) setState(() => busy = false);
        completed = await showReportPrintDialog(
          context,
          data: data,
          title: selectedType,
          year: selectedYear,
          program: selectedProgram,
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
                rows,
                title: selectedType,
                year: selectedYear,
                program: selectedProgram,
              );
        if (bytes.isEmpty) {
          throw const FinanceError('The report file could not be created.');
        }
        final destination = location.path.toLowerCase().endsWith('.$extension')
            ? location.path
            : '${location.path}.$extension';
        await File(destination).writeAsBytes(bytes, flush: true);
        completed = true;
        if (mounted) {
          showMessage(
            context,
            fmt == 'PDF'
                ? 'PDF report saved to $destination'
                : 'Excel report saved to $destination',
          );
        }
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => program = '');
      });
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
            for (final p in widget.store.programs)
              (p.code, programLabel(p.code, p.name)),
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
              const panelHeight = 378.0;
              final summary = _SummaryCard(
                totals: totals,
                utilization: utilization,
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
                    SizedBox(
                      height: panelHeight,
                      child: _SummaryCard(
                        totals: totals,
                        utilization: utilization,
                        expand: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: panelHeight,
                      child: _UtilizationChart(
                        year: year,
                        records: records,
                        expand: true,
                      ),
                    ),
                  ],
                );
              }
              return SizedBox(
                height: panelHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 360, child: summary),
                    const SizedBox(width: 16),
                    Expanded(child: chart),
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
              for (final p in widget.store.programs)
                (p.code, programLabel(p.code, p.name)),
            ],
            onChanged: busy ? null : (v) => change(() => program = v),
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
                  : _ReportSheet(
                      title: _reportType,
                      year: year,
                      programLabel: programLabel,
                      table: _previewTable(records),
                      totals: Totals(records),
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

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({
    required this.title,
    required this.year,
    required this.programLabel,
    required this.table,
    required this.totals,
  });
  final String title, programLabel;
  final int year;
  final _PreviewTable table;
  final Totals totals;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _vertical = ScrollController();
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  static const _border = BorderSide(color: Color(0xffd5e1f2));

  double _textWidth(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  /// Size every column from its widest header/body/total cell. Extra space goes
  /// to the expense name; if content is wider than the panel, scroll sideways.
  (double, List<double>) _fit(double available, TextStyle base) {
    const pad = 16.0;
    const size = 12.0;
    const nameIndex = 2;
    final table = widget.table;
    final totals = widget.totals;
    final measure = base.copyWith(
      fontSize: size,
      fontWeight: FontWeight.w800,
    );
    final samples = <List<String>>[
      for (var i = 0; i < table.headers.length; i++)
        [
          table.headers[i],
          for (final row in table.rows) row[i],
        ],
    ];
    if (samples.length > nameIndex) {
      samples[nameIndex].add('Total (${widget.programLabel})');
    }
    if (samples.length > 3) {
      samples[3].add(money(totals.allotment));
      samples[4].add(money(totals.obligation));
      samples[5].add(rate(totals.obligation, totals.allotment));
      samples[6].add(money(totals.balance));
      samples[7].add(money(totals.disbursement));
      samples[8].add(rate(totals.disbursement, totals.obligation));
    }
    final widths = <double>[
      for (var i = 0; i < samples.length; i++)
        () {
          var maxWidth = 0.0;
          for (final text in samples[i]) {
            maxWidth = math.max(maxWidth, _textWidth(text, measure));
          }
          // Expense names may wrap; keep a readable column without crushing others.
          if (i == nameIndex) {
            return math.max(180.0, math.min(maxWidth + pad, 420.0));
          }
          return maxWidth + pad;
        }(),
    ];
    final needed = widths.fold<double>(0, (sum, width) => sum + width);
    if (needed < available && nameIndex < widths.length) {
      widths[nameIndex] += available - needed;
    }
    return (size, widths);
  }

  Widget _cell(
    String text, {
    required TextAlign align,
    required TextStyle style,
    required bool wrap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Text(
        text,
        textAlign: align,
        softWrap: wrap,
        maxLines: wrap ? null : 1,
        style: style,
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
    final table = widget.table;
    final totals = widget.totals;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image(
                    image: AssetImage('assets/ncsc-logo-transparent.png'),
                    width: 58,
                    height: 58,
                  ),
                  SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NATIONAL COMMISSION OF SENIOR CITIZENS',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        Text(
                          'REGION I',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Program: ${widget.programLabel}  |  Fiscal Year: ${widget.year}',
                style: const TextStyle(color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: line),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final base = DefaultTextStyle.of(context).style;
              final available = math.max(0.0, constraints.maxWidth);
              final fit = _fit(available, base);
              final size = fit.$1;
              final colWidths = fit.$2;
              final tableWidth = math.max(
                available,
                colWidths.fold<double>(0, (sum, width) => sum + width),
              );
              final columns = <int, TableColumnWidth>{
                for (var i = 0; i < colWidths.length; i++)
                  i: FixedColumnWidth(colWidths[i]),
              };
              final headerStyle = base.copyWith(
                fontSize: size,
                fontWeight: FontWeight.w700,
                color: navy,
              );
              final bodyStyle = base.copyWith(fontSize: size, color: ink);
              final totalStyle = base.copyWith(
                fontSize: size,
                fontWeight: FontWeight.w800,
                color: navy,
              );
              Widget dataCell(String text, int index, TextStyle style) =>
                  _cell(
                    text,
                    align: table.numeric.contains(index)
                        ? TextAlign.right
                        : TextAlign.left,
                    style: style,
                    wrap: index == 2,
                  );
              final headerTable = Table(
                border: const TableBorder(
                  verticalInside: _border,
                  bottom: _border,
                ),
                columnWidths: columns,
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  _row([
                    for (var i = 0; i < table.headers.length; i++)
                      dataCell(table.headers[i], i, headerStyle),
                  ], const Color(0xffeef3fb)),
                ],
              );
              final bodyTable = Table(
                border: const TableBorder(
                  horizontalInside: _border,
                  verticalInside: _border,
                  bottom: _border,
                ),
                columnWidths: columns,
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  for (var r = 0; r < table.rows.length; r++)
                    _row([
                      for (var i = 0; i < table.rows[r].length; i++)
                        dataCell(table.rows[r][i], i, bodyStyle),
                    ], r.isOdd ? const Color(0xfff7f9fc) : Colors.white),
                  _row([
                    dataCell('', 0, totalStyle),
                    dataCell('', 1, totalStyle),
                    dataCell('Total (${widget.programLabel})', 2, totalStyle),
                    dataCell(money(totals.allotment), 3, totalStyle),
                    dataCell(money(totals.obligation), 4, totalStyle),
                    dataCell(
                      rate(totals.obligation, totals.allotment),
                      5,
                      totalStyle,
                    ),
                    dataCell(money(totals.balance), 6, totalStyle),
                    dataCell(money(totals.disbursement), 7, totalStyle),
                    dataCell(
                      rate(totals.disbursement, totals.obligation),
                      8,
                      totalStyle,
                    ),
                  ], const Color(0xffe7eefc)),
                ],
              );
              final needsHorizontal = tableWidth > available + 1;
              return Scrollbar(
                controller: _horizontal,
                thumbVisibility: needsHorizontal,
                notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  controller: _horizontal,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Scrollbar(
                      controller: _vertical,
                      thumbVisibility: true,
                      notificationPredicate: (n) =>
                          n.metrics.axis == Axis.vertical,
                      child: Column(
                        children: [
                          headerTable,
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _vertical,
                              child: bodyTable,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
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
  const _UtilizationChart({
    required this.year,
    required this.records,
    this.expand = false,
  });
  final int year;
  final List<BudgetRecord> records;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<BudgetRecord>>{};
    for (final r in records) {
      groups.putIfAbsent(r.program, () => []).add(r);
    }
    final totals = {for (final g in groups.entries) g.key: Totals(g.value)};
    // Sorted labels so every program keeps a stable slot on the axis.
    final entries = totals.entries.toList()
      ..sort((a, b) => programLabel(a.key).compareTo(programLabel(b.key)));
    // Absolute pesos when one program is filtered. For All Programs, ECA (~₱225M)
    // would crush every other bar — use % of each program's allotment instead.
    final usePercent = entries.length > 1;
    final peak = entries.fold<int>(0, (m, e) {
      final t = e.value;
      if (usePercent) {
        if (t.allotment <= 0) return m;
        final d = (t.disbursement * 10000 / t.allotment).round();
        final o = (t.obligation * 10000 / t.allotment).round();
        final b = (t.balance * 10000 / t.allotment).round().clamp(0, 1 << 30);
        return math.max(m, math.max(d, math.max(o, b)));
      }
      return math.max(
        m,
        math.max(
          t.disbursement,
          math.max(t.obligation, math.max(0, t.balance)),
        ),
      );
    });
    final ticks = usePercent
        ? _percentTicks(peak <= 0 ? 10000 : peak)
        : _axisTicks(peak);
    final plot = entries.isEmpty
        ? const Center(
            child: Text(
              'No budget records for these filters.',
              style: TextStyle(color: muted),
            ),
          )
        : CustomPaint(
            painter: _UtilizationPainter(entries, ticks, usePercent),
            child: const SizedBox.expand(),
          );
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
                  usePercent
                      ? 'Budget Utilization – $year (% of allotment)'
                      : 'Budget Utilization – $year',
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
          if (expand) Expanded(child: plot) else SizedBox(height: 274, child: plot),
        ],
      ),
    );
  }
}

class _UtilizationPainter extends CustomPainter {
  _UtilizationPainter(this.groups, this.ticks, this.usePercent);
  final List<MapEntry<String, Totals>> groups;
  final List<int> ticks;
  final bool usePercent;

  List<double> _barValues(Totals t) {
    if (!usePercent) {
      return [
        t.disbursement.toDouble(),
        t.obligation.toDouble(),
        math.max(0, t.balance).toDouble(),
      ];
    }
    if (t.allotment <= 0) return [0, 0, 0];
    return [
      t.disbursement * 10000 / t.allotment,
      t.obligation * 10000 / t.allotment,
      math.max(0, t.balance) * 10000 / t.allotment,
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 112.0;
    const bottom = 44.0;
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
    final top = ticks.last.toDouble();
    final steps = math.max(1, ticks.length - 1);
    canvas.drawLine(
      Offset(plot.left, plot.top),
      Offset(plot.left, plot.bottom),
      grid,
    );
    for (var i = 0; i < ticks.length; i++) {
      final y = plot.bottom - plot.height * i / steps;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final text = usePercent
          ? '${(ticks[i] / 100).toStringAsFixed(ticks[i] % 100 == 0 ? 0 : 1)}%'
          : _axisMoney(ticks[i]);
      final label = TextPainter(
        text: TextSpan(text: text, style: axisStyle),
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
      final values = _barValues(entry.value);
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
      final parts = _chartLabelParts(entry.key);
      final maxLabel = math.max(0.0, slot - 8);
      const titleStyle = TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: ink,
        fontFamily: 'Segoe UI',
      );
      const subStyle = TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: muted,
        fontFamily: 'Segoe UI',
      );
      final title = TextPainter(
        text: TextSpan(text: parts.$1, style: titleStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: maxLabel);
      final centerX = plot.left + slot * g + slot / 2;
      var labelY = plot.bottom + 6;
      title.paint(canvas, Offset(centerX - title.width / 2, labelY));
      labelY += title.height + 1;
      if (parts.$2 != null) {
        final sub = TextPainter(
          text: TextSpan(text: parts.$2, style: subStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: maxLabel);
        sub.paint(canvas, Offset(centerX - sub.width / 2, labelY));
      }
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

/// Chart axis: ATOPCURRENT → ("ATOP", "Current"), else (code, null).
(String, String?) _chartLabelParts(String code) {
  final upper = code.trim().toUpperCase();
  if (upper.endsWith('CONTINUING')) {
    final prefix = upper.substring(0, upper.length - 'CONTINUING'.length);
    return (prefix.isEmpty ? upper : prefix, 'Continuing');
  }
  if (upper.endsWith('CURRENT')) {
    final prefix = upper.substring(0, upper.length - 'CURRENT'.length);
    return (prefix.isEmpty ? upper : prefix, 'Current');
  }
  return (code.trim().isEmpty ? code : code.trim(), null);
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

/// Units: 10000 = 100%. Always covers at least 100%.
List<int> _percentTicks(int peakUnits) {
  final top = math.max(10000, peakUnits);
  const step = 2000; // 20%
  final count = (top / step).ceil().clamp(2, 10);
  return [for (var i = 0; i <= count; i++) step * i];
}

String _axisMoney(int cents) => NumberFormat.currency(
  locale: 'en_PH',
  symbol: '₱',
  decimalDigits: 0,
).format(cents / 100);

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totals,
    required this.utilization,
    this.expand = false,
  });
  final Totals totals;
  final String utilization;
  final bool expand;
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
      final valueStyle = TextStyle(
        color: entry.$4 ?? ink,
        fontWeight: badge == null ? FontWeight.w600 : FontWeight.w700,
        fontSize: 14,
        height: 1.25,
      );
      final value = badge == null
          ? Text(
              entry.$2,
              textAlign: TextAlign.right,
              softWrap: true,
              style: valueStyle,
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
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
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
              Icon(Icons.assignment_outlined, color: blue, size: 20),
              SizedBox(width: 8),
              Text(
                'Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (expand) Expanded(child: table) else table,
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
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Text(
        text,
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
