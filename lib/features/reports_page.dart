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
        child: AppDropdown<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          fieldTextStyle: const TextStyle(
            fontFamily: 'Segoe UI',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: EdgeInsets.fromLTRB(12, 12, 0, 12),
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
      if (mounted) {
        showMessage(
          context,
          fmt == 'PDF'
              ? 'PDF report saved to $destination'
              : 'Excel report saved to $destination',
        );
      }
      widget.store.logReport(
        selectedType,
        selectedYear,
        selectedProgram,
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
        !widget.store.programs.any((p) => p.code == program)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => program = '');
      });
    }
    final records = widget.store.records(year, program: program);
    final totals = Totals(records);
    final history = widget.store.reportHistory;
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
              (p.code, p.code),
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
                    SizedBox(height: panelHeight, child: summary),
                    const SizedBox(height: 16),
                    SizedBox(height: panelHeight, child: chart),
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
          const Text(
            'Generate and download financial and budget reports.',
            style: TextStyle(fontSize: 14, color: muted, height: 1.35),
          ),
          const SizedBox(height: 22),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 280, child: _parameterCard(records)),
                const SizedBox(width: 16),
                Expanded(child: _previewCard(records, programLabel)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _parameterCard(List<BudgetRecord> records) {
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
                (p.code, p.code),
            ],
            onChanged: busy ? null : (v) => change(() => program = v),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomCenter,
            child: PopupMenuButton<String>(
                                key: const ValueKey('reports-export'),
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
              IconButton.outlined(
                key: const ValueKey('reports-back'),
                tooltip: 'Back to Reports',
                onPressed: busy ? null : () => setState(() => preview = false),
                icon: const Icon(Icons.arrow_back, size: 20),
              ),,
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
        : CustomPaint(
            painter: _UtilizationPainter(entries, byRecord: byRecord),
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
                  byRecord
                      ? 'Budget Utilization – $year (% of allotment)'
                      : 'Budget Utilization – $year',
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
          if (expand)
            Expanded(child: plot)
          else
            SizedBox(height: 274, child: plot),
        ],
      ),
    );
  }
}

class _UtilizationPainter extends CustomPainter {
  _UtilizationPainter(this.groups, {required this.byRecord});
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
    final axisLeft = byRecord ? left : pesoLeft;
    final plot = Rect.fromLTRB(
      axisLeft,
      topPad,
      size.width - 6,
      size.height - bottom,
    );
    if (plot.width <= 0 || plot.height <= 0 || groups.isEmpty) return;

    final grid = Paint()
      ..color = const Color(0xffe6edf6)
      ..strokeWidth = 1;
    const axisStyle = TextStyle(
      fontSize: 11,
      color: Color(0xff8b97ab),
      fontFamily: 'Segoe UI',
    );

    final tickCount = byRecord ? percentTicks.length : pesoTicks.length;
    for (var i = 0; i < tickCount; i++) {
      final tick = byRecord ? percentTicks[i].toDouble() : pesoTicks[i].toDouble();
      final y = plot.bottom - plot.height * (tick / top).clamp(0.0, 1.0);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
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
            canvas.drawRRect(
              RRect.fromRectAndCorners(
                Rect.fromLTWH(x, plot.bottom - height, barWidth, height),
                topLeft: const Radius.circular(3),
                topRight: const Radius.circular(3),
              ),
              Paint()..color = colors[b],
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
      oldDelegate.byRecord != byRecord || oldDelegate.groups != groups;
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
              padding: const EdgeInsets.symmetric(vertical: 8),
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
                        fontSize: 13.5,
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

class _HistoryCard extends StatefulWidget {
  const _HistoryCard({required this.history});
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

  String _reportName(DbRow report) {
    final program = (report['program'] as String? ?? '').trim();
    final name = program.isEmpty ? 'All' : program;
    final storedFormat = (report['format'] as String? ?? '').trim();
    final format = switch (storedFormat.toUpperCase()) {
      'PDF' => 'PDF',
      'EXCEL' || 'XLSX' => 'Excel',
      _ => storedFormat,
    };
    return '${name}_Current ($format)';
  }

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
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Align(alignment: Alignment.centerLeft, child: cell),
          ),
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
                ConstrainedBox(
                  // Keep four rows visible; scroll the history from five on.
                  constraints: const BoxConstraints(maxHeight: 4 * 48.0),
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
                          if (widget.history.isEmpty)
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
                            for (var i = 0; i < widget.history.length; i++)
                              _row([
                                _cell('${i + 1}', number: true),
                                _cell(_reportName(widget.history[i])),
                                _cell('${widget.history[i]['year']}'),
                                _cell(dateLabel(widget.history[i]['at'])),
                              ], i.isOdd ? const Color(0xfff7f9fc) : Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
