import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import 'audit_page.dart' show auditDetailSentence, AuditActionBadge;
import '../data/finance_store.dart';
import '../data/models.dart';
import '../ui/common.dart';
import '../ui/app_icon.dart';
import '../ui/theme.dart';

const chartColors = [
  blue,
  Color(0xff80a6e1),
  navy,
  red,
  Color(0xff527dcc),
  Color(0xff6878b2),
];

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.store,
    this.onViewAuditTrail,
  });
  final FinanceStore store;
  final VoidCallback? onViewAuditTrail;
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int year = manilaNow().year;
  String program = '', item = '';
  // Keep the donut center readable even for large regional totals.
  // The KPI card and accessibility label continue to show exact pesos.
  String _compactAllotment(int cents) {
    final pesos = cents / 100;
    final absolute = pesos.abs();
    if (absolute < 100000) return money(cents);

    String amount(double divisor, String suffix) {
      final scaled = pesos / divisor;
      final decimals = scaled.abs() < 10 ? 2 : scaled.abs() < 100 ? 1 : 0;
      var value = scaled.toStringAsFixed(decimals);
      if (value.contains('.')) {
        while (value.endsWith('0')) {
          value = value.substring(0, value.length - 1);
        }
        if (value.endsWith('.')) {
          value = value.substring(0, value.length - 1);
        }
      }
      return '₱$value$suffix';
    }

    if (absolute >= 1e15) return amount(1e15, 'Q');
    if (absolute >= 1e12) return amount(1e12, 'T');
    if (absolute >= 1e9) return amount(1e9, 'B');
    if (absolute >= 1e6) return amount(1e6, 'M');
    return amount(1e3, 'K');
  }

  // Dashboard filters are independent of the Audit Trail page's filters.
  // Older amount-only Updated logs cannot always be attributed to a UACS item.
  List<DbRow> _dashboardAuditRows() {
    final audit = widget.store.auditRows(year, program: program);
    if (item.isEmpty) return audit;
    final parts = item.split('\u0001');
    if (parts.length != 2) return audit;
    final selectedCode = codeKey(parts[1]);
    final selectedRecord = widget.store
        .records(year, program: parts[0])
        .where((r) => codeKey(r.code) == selectedCode)
        .toList();
    final selectedName = selectedRecord.isEmpty
        ? ''
        : selectedRecord.first.name.toLowerCase().trim();
    return audit.where((entry) {
      final detail = '${entry['detail'] ?? ''}'.toLowerCase();
      return detail.contains(selectedCode) ||
          (selectedName.isNotEmpty && detail.contains(selectedName));
    }).toList();
  }

  Widget _programDonut(Map<String, int> shares, int allotment, double size, int annualAllotment) {
    return SizedBox(
      width: size,
      height: size,
      child: Semantics(
        label: 'Total allotment ${money(allotment)}',
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _DonutPainter(shares.values.toList(), annualAllotment),
              ),
            ),
            SizedBox(
              width: size * 0.66,
              height: size * 0.66,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _compactAllotment(allotment),
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: size < 180 ? 13 : 15,
                        fontWeight: FontWeight.w800,
                        color: navy,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Total Allotment',
                      maxLines: 1,
                      style: TextStyle(fontSize: 12, color: muted),
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

  Widget _programLegend(
    Map<String, int> shares,
    int allotment, {
    int? limit,
    Map<String, int>? selectedShares,
    String? selectedKey,
  }) {
    final entries = shares.entries.toList();
    final ordered = selectedKey != null
        ? [...entries.where((e) => e.key == selectedKey), ...entries.where((e) => e.key != selectedKey)]
        : limit != null && (program.isNotEmpty || item.isNotEmpty)
            ? [...entries.where((e) => (selectedShares?[e.key] ?? 0) != 0), ...entries.where((e) => (selectedShares?[e.key] ?? 0) == 0)]
            : entries;
    final shown = limit == null ? ordered : ordered.take(limit).toList();
    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: chartColors[entries.indexOf(entry) % chartColors.length],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Tooltip(
                      message: entry.key,
                      child: Text(
                        entry.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Tooltip(
                      message: '${money(entry.value)} (${rate(entry.value, allotment)})',
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${money(entry.value)} (${rate(entry.value, allotment)})',
                            maxLines: 1,
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 12, color: muted),
                          ),
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

  void _showAllPrograms(Map<String, int> shares, int allotment, int annualAllotment, Map<String, int> annualShares, {required String chartTitle, String? selectedKey}) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final screen = MediaQuery.sizeOf(dialogContext);
        final width = math.min(480.0, screen.width - 48);
        final columns = width >= 340 ? 2 : 1;
        final legendHeight = math.max(48.0, (annualShares.length / columns).ceil() * 48.0);
        final desiredHeight = math.min(490.0, 260.0 + legendHeight);
        final height = math.min(desiredHeight, screen.height - 64);
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chartTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: navy,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const AppIcon('x', size: 19),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final donutSize = math.max(0.0, math.min(
                          174.0,
                          math.min(constraints.maxWidth, constraints.maxHeight * 0.65),
                        ));
                        return Column(
                          children: [
                            Center(
                              child: _programDonut(
                                shares,
                                allotment,
                                donutSize,
                                annualAllotment,
                              ),
                            ),
                            const SizedBox(height: 22),
                            Expanded(
                              child: annualShares.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No allotment records found.',
                                        style: TextStyle(color: muted),
                                      ),
                                    )
                                  : SingleChildScrollView(
                                      primary: false,
                                      child: LayoutBuilder(
                                        builder: (context, legendConstraints) {
                                          final entries = annualShares.entries.toList();
                                          final ordered = selectedKey == null
                                              ? entries
                                              : [
                                                  ...entries.where((e) => e.key == selectedKey),
                                                  ...entries.where((e) => e.key != selectedKey),
                                                ];
                                          final count = legendConstraints.maxWidth >= 308 ? 2 : 1;
                                          const gap = 42.0;
                                          final groupWidth = math.min(404.0, legendConstraints.maxWidth);
                                          final cellWidth = (groupWidth - (count - 1) * gap) / count;
                                          return Align(
                                            alignment: Alignment.topCenter,
                                            child: SizedBox(
                                              width: groupWidth,
                                              child: Wrap(
                                            alignment: WrapAlignment.center,
                                            spacing: gap,
                                            runSpacing: 10,
                                            children: [
                                              for (final entry in ordered)
                                                SizedBox(
                                                  width: cellWidth,
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 4),
                                                        child: Container(
                                                          width: 10,
                                                          height: 10,
                                                          decoration: BoxDecoration(
                                                            color: chartColors[entries.indexOf(entry) % chartColors.length],
                                                            borderRadius: BorderRadius.circular(3),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Tooltip(
                                                              message: entry.key,
                                                              child: Text(
                                                                entry.key,
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                                              ),
                                                            ),
                                                            const SizedBox(height: 3),
                                                            Tooltip(
                                                              message: '${money(entry.value)} (${rate(entry.value, annualAllotment)})',
                                                              child: Text(
                                                                '${money(entry.value)} (${rate(entry.value, annualAllotment)})',
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                                style: const TextStyle(fontSize: 12, color: muted),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (program.isNotEmpty &&
        !widget.store.programs.any((p) => p.code == program)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => program = '');
      });
    }
    final all = widget.store.records(year, program: program);
    // One dropdown entry per budget line (program + UACS), so All Items
    // matches every row shown in Budget Utilization.
    final items = <String, String>{
      for (final r in all)
        '${r.program}\u0001${r.code}': program.isEmpty
            ? '${r.name} (${displayCode(r.code)}) · ${programLabel(r.program)}'
            : '${r.name} (${displayCode(r.code)})',
    };
    if (!items.containsKey(item)) item = '';
    final rows = all.where((r) {
          if (item.isEmpty) return true;
          return item == '${r.program}\u0001${r.code}';
        }).toList(),
        t = Totals(rows);
    final shares = <String, int>{
      for (final p in widget.store.programs) p.code: 0,
    };
    for (final r in rows) {
      shares[r.program] = (shares[r.program] ?? 0) + r.allotment;
    }
    final annualRows = program.isEmpty && item.isEmpty
        ? rows
        : widget.store.records(year);
    final annualAllotment = Totals(annualRows).allotment;
    final annualShares = <String, int>{for (final code in shares.keys) code: 0};
    for (final r in annualRows) {
      annualShares[r.program] = (annualShares[r.program] ?? 0) + r.allotment;
    }
    // Item mode compares against the selected program's entire allotment,
    // or the entire fiscal year's allotment when All Programs is selected.
    final itemMode = item.isNotEmpty;
    final itemShares = <String, int>{};
    String? selectedItemLabel;
    if (itemMode) {
      for (final r in all) {
        final key = '${r.program}\u0001${r.code}';
        final label = items[key] ?? '${r.name} (${displayCode(r.code)})';
        itemShares[label] = (itemShares[label] ?? 0) + r.allotment;
        if (key == item) selectedItemLabel = label;
      }
    }
    final chartBase = itemMode ? Totals(all).allotment : annualAllotment;
    final chartLegend = itemMode ? itemShares : annualShares;
    // Use exactly the legend order in the painter so segment colors agree.
    final chartShares = <String, int>{
      for (final entry in chartLegend.entries)
        entry.key: itemMode
            ? (entry.key == selectedItemLabel ? t.allotment : 0)
            : (shares[entry.key] ?? 0),
    };
    final chartTitle = itemMode ? 'Allotment by Item' : 'Utilization by Program';
    final selectedLegendKey = itemMode
        ? selectedItemLabel
        : program.isNotEmpty ? program : null;
    final filters = Wrap(
      spacing: 18,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _InlineFilter(
          label: 'Fiscal Year',
          value: year,
          fieldWidth: 108,
          items: [for (final y in widget.store.years) (y, '$y')],
          onChanged: (v) => setState(() {
            year = v;
            item = '';
          }),
        ),
        _InlineFilter(
          label: 'Program',
          value: program,
          fieldWidth: 160,
          items: [
            ('', 'All Programs'),
            for (final p in widget.store.programs)
              (p.code, p.code),
          ],
          onChanged: (v) => setState(() {
            program = v;
            item = '';
          }),
        ),
        _InlineFilter(
          label: 'Item',
          value: item,
          fieldWidth: 280,
          items: [
            ('', 'All Items (${all.length})'),
            for (final e in items.entries) (e.key, e.value),
          ],
          onChanged: (v) => setState(() => item = v),
        ),
      ],
    );
    const title = Text(
      'Dashboard',
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1,
      ),
    );
    const subtitle = Text(
      'Overview of Budget Utilization',
      style: TextStyle(fontSize: 14, color: muted, height: 1.35),
    );
    Widget buildCharts(double chartHeight) =>
      LayoutBuilder(
        builder: (context, c) {
          const gap = 10.0;
          final sideBySide = c.maxWidth >= 1000;
          final cardWidth = sideBySide
              ? (c.maxWidth - gap) / 2
              : c.maxWidth;
          // Keep the preview short; the dialog shows every program.
          // Both dashboard panels use identical dimensions.
          // Give the six primary cards priority over the Audit Trail.
          // Fill the remaining desktop height without scaling the page.
          final panelHeight = chartHeight;
          final dense = panelHeight <= 240;
          final compactRates = panelHeight < 230;
          final previewDonutSize = math.min(
            200.0,
            math.max(90.0, panelHeight - (dense ? 82.0 : 90.0)),
          );
          final chart = Panel(
            padding: dense ? 7 : 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    chartTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: navy,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Transform.translate(
                        offset: Offset(10, dense ? 0 : 9),
                        child: _programDonut(
                          chartShares,
                          t.allotment,
                          previewDonutSize,
                          chartBase,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, limits) => SingleChildScrollView(
                            primary: false,
                            child: _programLegend(
                              chartLegend,
                              chartBase,
                              limit: 5,
                              selectedShares: chartShares,
                              selectedKey: selectedLegendKey,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (chartLegend.length > 5)
                  Align(
                  alignment: Alignment.centerRight,
                  child: Transform.translate(
                    offset: const Offset(-8, -4),
                    child: HoverScaleButton(
                    enabled: true,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        overlayColor: Colors.transparent,
                      ).copyWith(
                        textStyle: WidgetStateProperty.resolveWith<TextStyle?>(
                          (states) => TextStyle(
                            fontWeight: FontWeight.w700,
                            decoration: states.contains(WidgetState.hovered) &&
                                !states.contains(WidgetState.disabled)
                                ? TextDecoration.underline : TextDecoration.none,
                          ),
                        ),
                      ),
                      onPressed: () => _showAllPrograms(chartShares, t.allotment, chartBase, chartLegend, chartTitle: chartTitle, selectedKey: selectedLegendKey),
                      child: const Text('See All'),
                    ),
                    ),
                  ),
                ),
              ],
            ),
          );
          Widget rateInset(Widget child) => Transform.translate(
            offset: const Offset(-4, 0),
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: child,
            ),
          );
          final rates = Panel(
            padding: dense ? 8 : 12,
            child: LayoutBuilder(
              builder: (context, available) => SingleChildScrollView(
                primary: false,
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    'Budget Utilization Rate',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: navy,
                    ),
                  ),
                ),
                SizedBox(height: compactRates ? 6 : 16),
                rateInset(_Rate(
                  'Obligation Rate',
                  t.obligation,
                  t.allotment,
                  blue,
                  compact: compactRates,
                )),
                SizedBox(height: compactRates ? 7 : 14),
                rateInset(_Rate(
                  'Disbursement Rate',
                  t.disbursement,
                  t.obligation,
                  navy,
                  compact: compactRates,
                )),
              ],
                ),
              ),
            ),
          );
          return sideBySide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      height: panelHeight,
                      child: chart,
                    ),
                    const SizedBox(width: gap),
                    SizedBox(
                      width: cardWidth,
                      height: panelHeight,
                      child: rates,
                    ),
                  ],
                )
              : Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: panelHeight,
                      child: chart,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: panelHeight,
                      child: rates,
                    ),
                  ],
                );
        },
      );

    Widget buildContent(bool fillHeight) => Column(
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
                      const SizedBox(height: 8),
                      filters,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 0),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          subtitle,
                          const SizedBox(width: 16),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: filters,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 1000
                  ? 4
                  : c.maxWidth >= 520
                  ? 2
                  : 1;
              const metrics = [
                ('Total Allotment', 'database'),
                ('Total Obligation', 'clipboard-check'),
                ('Total Disbursement', 'wallet'),
                ('Remaining Balance', 'chart-no-axes-column-increasing'),
              ];
              final amounts = [
                t.allotment,
                t.obligation,
                t.disbursement,
                t.balance,
              ];
              return Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < metrics.length; i++)
                    SizedBox(
                      width: (c.maxWidth - (cols - 1) * 10) / cols,
                      child: _DashboardMetricCard(
                        label: metrics[i].$1,
                        icon: metrics[i].$2,
                        amount: money(amounts[i]),
                        accent: const [
                          Color(0xff2875c7),
                          Color(0xff245cb6),
                          Color(0xff1e3a8a),
                          red,
                        ][i],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          if (fillHeight)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) =>
                    buildCharts(constraints.maxHeight),
              ),
            )
          else
            buildCharts(255.0),
          const SizedBox(height: 12),
          // Keep the Audit Trail compact and steady. Only the chart row
          // grows with the desktop viewport, not the activity preview.
          SizedBox(
            width: double.infinity,
            height: fillHeight ? 215 : 230,
            child: _DashboardAuditPreview(
              rows: _dashboardAuditRows(),
              onSeeAll: widget.onViewAuditTrail,
            ),
          ),
        ],
      );
    return LayoutBuilder(
      builder: (context, viewport) {
        // Use the entire available width. Only fall back to scrolling
        // when the window cannot comfortably contain the dashboard.
        final compactDesktop =
            viewport.maxHeight >= 690 && viewport.maxWidth >= 1044;
        return compactDesktop
            ? Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 10),
                child: buildContent(true),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 10),
                child: buildContent(false),
              );
      },
    );
  }
}

/// A scrollable read-only view of the filtered Audit Trail records.
class _DashboardAuditPreview extends StatelessWidget {
  const _DashboardAuditPreview({
    required this.rows,
    required this.onSeeAll,
  });

  final List<DbRow> rows;
  final VoidCallback? onSeeAll;

  static const _border = BorderSide(color: Color(0xffc3d2e6));
  static const _columns = <int, TableColumnWidth>{
    0: FixedColumnWidth(48),
    1: FixedColumnWidth(188),
    2: FixedColumnWidth(112),
    3: FixedColumnWidth(210),
    4: FlexColumnWidth(),
  };
  static const _header = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: navy,
  );
  static const _body = TextStyle(fontSize: 13, color: ink);

  TableRow _row(List<Widget> cells, Color background) => TableRow(
    decoration: BoxDecoration(color: background),
    children: [
      for (final cell in cells)
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: cell,
        ),
    ],
  );

  Widget _cell(
    String value, {
    TextStyle style = _body,
    bool center = false,
    String? tooltip,
  }) {
    final label = Text(
      value,
      textAlign: center ? TextAlign.center : TextAlign.left,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: style,
    );
    return Container(
      padding: EdgeInsets.fromLTRB(center ? 8 : 12, 3, 8, 3),
      alignment: center ? Alignment.center : Alignment.centerLeft,
      child: tooltip == null || value.isEmpty
          ? label
          : Tooltip(message: tooltip, child: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, bounds) {
        // Keep the table header fixed while the records scroll.
        Widget cell(
          String value, {
          TextStyle style = _body,
          bool center = false,
          String? tooltip,
        }) => _cell(
          value,
          style: style,
          center: center,
          tooltip: tooltip,
        );
        return Panel(
      padding: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 3),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Audit Trail',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: navy,
                    ),
                  ),
                ),
                HoverScaleButton(
                  enabled: onSeeAll != null,
                  child: TextButton(
                    key: const ValueKey('dashboard-audit-see-all'),
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      overlayColor: Colors.transparent,
                    ).copyWith(
                      textStyle: WidgetStateProperty.resolveWith<TextStyle?>(
                        (states) => TextStyle(
                          fontWeight: FontWeight.w700,
                          decoration: states.contains(WidgetState.hovered) &&
                              !states.contains(WidgetState.disabled)
                              ? TextDecoration.underline : TextDecoration.none,
                        ),
                      ),
                    ),
                    onPressed: onSeeAll,
                    child: const Text('See All'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 3, 16, 5),
              child: rows.isEmpty
                  ? const Center(child: Text('No audit records found.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: muted),
                    ))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: math.max(698.0, constraints.maxWidth),
                    height: constraints.maxHeight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Table(
                          border: const TableBorder(
                            verticalInside: _border,
                            bottom: _border,
                          ),
                          columnWidths: _columns,
                          children: [
                            _row([
                              cell('#', style: _header, center: true),
                              cell('Date', style: _header, center: true),
                              cell('Time', style: _header, center: true),
                              cell('Action', style: _header, center: true),
                              cell('Details', style: _header, center: true),
                            ], const Color(0xffcdddf4)),
                          ],
                        ),
                        Expanded(
                          child: ListView.builder(
                            key: const ValueKey('dashboard-audit-records'),
                            primary: false,
                            padding: EdgeInsets.zero,
                            itemCount: rows.length,
                            itemBuilder: (context, i) {
                              final record = rows[i];
                              return Table(
                                border: const TableBorder(
                                  verticalInside: _border,
                                  bottom: _border,
                                ),
                                columnWidths: _columns,
                                children: [
                                    _row([
                                      cell('${i + 1}', center: true, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: blue)),
                                      cell(dateOnly(record['at']), center: true),
                                      cell(timeOnly(record['at']), center: true),
                                      AuditActionBadge('${record['action'] ?? ''}'),
                                      cell(
                                        auditDetailSentence(
                                          '${record['detail'] ?? ''}',
                                          action: '${record['action'] ?? ''}',
                                          program: '${record['program'] ?? ''}',
                                        ),
                                        tooltip: '${record['detail'] ?? ''}',
                                      ),
                                    ], i.isOdd
                                        ? const Color(0xfff8fafc)
                                        : Colors.white),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ),
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}

class _InlineFilter<T> extends StatelessWidget {
  const _InlineFilter({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.fieldWidth,
  });
  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  final double fieldWidth;
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
        width: fieldWidth,
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

/// Full-color financial cards with translucent decorative bubbles.
class _DashboardMetricCard extends StatelessWidget {
  const _DashboardMetricCard({
    required this.label,
    required this.icon,
    required this.amount,
    required this.accent,
  });

  final String label, icon, amount;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    height: 126,
    decoration: BoxDecoration(
      color: accent,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: .16)),
      boxShadow: const [
        BoxShadow(color: Color(0x12061c52), blurRadius: 8, offset: Offset(0, 3)),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Stack(
        children: [
          Positioned.fill(
            child: const CustomPaint(painter: _MetricBubblePainter()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 15, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 39,
                      height: 39,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white.withValues(alpha: .16),
                        border: Border.all(color: Colors.white.withValues(alpha: .25)),
                      ),
                      alignment: Alignment.center,
                      child: AppIcon(icon, size: 23, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Text(label, maxLines: 1, style: const TextStyle(
                          fontFamily: 'Arial', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white,
                        )),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Text(amount, maxLines: 1, style: const TextStyle(
                        fontSize: 23, fontWeight: FontWeight.w800, color: Colors.white,
                        letterSpacing: -.4,
                      )),
                    ),
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

class _MetricBubblePainter extends CustomPainter {
  const _MetricBubblePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = Colors.white.withValues(alpha: .13);
    canvas.drawCircle(Offset(w - 8, 5), 52, paint);
    canvas.drawCircle(Offset(w - 76, 19), 18, paint);
    paint.color = Colors.white.withValues(alpha: .10);
    canvas.drawCircle(Offset(w - 28, h - 19), 36, paint);
    canvas.drawCircle(Offset(w - 70, h - 48), 14, paint);
    paint.color = Colors.white.withValues(alpha: .08);
    canvas.drawCircle(Offset(14, h + 2), 33, paint);
  }

  @override
  bool shouldRepaint(covariant _MetricBubblePainter oldDelegate) => false;
}

class _Rate extends StatelessWidget {
  const _Rate(this.label, this.value, this.total, this.color, {this.compact = false});
  final bool compact;
  final String label;
  final int value, total;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 15 : 18,
                  fontWeight: FontWeight.w800,
                  color: navy,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              rate(value, total),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: compact ? 13 : 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xff4d5e7a),
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 4 : 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : (value / total).clamp(0, 1),
            minHeight: compact ? 10 : 14,
            color: color,
            backgroundColor: const Color(0xffe6ebf3),
          ),
        ),
      ],
    ),
  );
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.amounts, this.annualAllotment);
  final List<int> amounts;
  final int annualAllotment;
  @override
  void paint(Canvas canvas, Size size) {
    final diameter = math.min(size.width, size.height);
    if (diameter < 12) return;
    final stroke = math.min(diameter / 4, diameter <= 170 ? 20.0 : 24.0);
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: diameter / 2 - stroke / 2 - 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawOval(rect, paint..color = line);
    final selectedTotal = amounts.fold<int>(0, (a, b) => a + math.max(0, b));
    if (annualAllotment <= 0 || selectedTotal > annualAllotment || amounts.any((a) => a < 0)) return;
    var start = -math.pi / 2;
    for (var i = 0; i < amounts.length; i++) {
      final sweep = math.max(0, amounts[i]) / annualAllotment * math.pi * 2;
      if (sweep > 0) {
        canvas.drawArc(
          rect,
          start,
          sweep >= 2 * math.pi - 0.001 ? sweep : math.max(0, sweep - 0.012),
          false,
          paint..color = chartColors[i % chartColors.length],
        );
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => true;
}
