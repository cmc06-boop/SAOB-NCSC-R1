import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../data/finance_store.dart';
import '../data/models.dart';
import '../ui/common.dart';
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
  const DashboardPage({super.key, required this.store});
  final FinanceStore store;
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int year = manilaNow().year;
  String program = '', item = '';
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
    final filters = Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _InlineFilter(
          label: 'Fiscal Year',
          value: year,
          fieldWidth: 112,
          items: [for (final y in widget.store.years) (y, '$y')],
          onChanged: (v) => setState(() {
            year = v;
            item = '';
          }),
        ),
        _InlineFilter(
          label: 'Program',
          value: program,
          fieldWidth: 146,
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
                      filters,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 1),
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
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 1000
                  ? 4
                  : c.maxWidth >= 520
                  ? 2
                  : 1;
              const metrics = [
                ('Total Allotment', Icons.storage_outlined),
                ('Total Obligation', Icons.assignment_turned_in_outlined),
                ('Total Disbursement', Icons.account_balance_wallet_outlined),
                ('Remaining Balance', Icons.bar_chart_rounded),
              ];
              final amounts = [
                t.allotment,
                t.obligation,
                t.disbursement,
                t.balance,
              ];
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (var i = 0; i < metrics.length; i++)
                    SizedBox(
                      width: (c.maxWidth - (cols - 1) * 14) / cols,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                        decoration: BoxDecoration(
                          color: const Color(0xffe7eefc),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xffd5e2f6)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(metrics[i].$2, size: 32, color: blue),
                            const SizedBox(height: 18),
                            Text(
                              metrics[i].$1,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: navy,
                              ),
                            ),
                            const SizedBox(height: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                money(amounts[i]),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: navy,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) {
              const gap = 16.0;
              final sideBySide = c.maxWidth >= 1000;
              final cardWidth = sideBySide
                  ? (c.maxWidth - gap) / 2
                  : c.maxWidth;
              const donutSize = 220.0;
              final legendWidth = math.max(
                96.0,
                cardWidth - 52 - donutSize - 20,
              );
              final amountWidth = math.min(168.0, legendWidth * 0.58);
              final nameWidth = math.max(
                40.0,
                legendWidth - 10 - 8 - 12 - amountWidth,
              );
              final chart = Panel(
                padding: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Utilization by Program',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: navy,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Builder(
                      builder: (context) {
                        final donut = SizedBox(
                          width: donutSize,
                          height: donutSize,
                          child: Semantics(
                            label: 'Total allotment ${money(t.allotment)}',
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _DonutPainter(
                                      shares.values.toList(),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 124,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          money(t.allotment),
                                          maxLines: 1,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: navy,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          'Total Allotment',
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: muted,
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
                        final legend = Column(
                          children: [
                            for (final e in shares.entries.indexed)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 9,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color:
                                            chartColors[e.$1 %
                                                chartColors.length],
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: nameWidth,
                                      child: Text(
                                        e.$2.key,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: amountWidth,
                                      child: Text(
                                        '${money(e.$2.value)} (${rate(e.$2.value, t.allotment)})',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: muted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            donut,
                            const SizedBox(width: 20),
                            SizedBox(width: legendWidth, child: legend),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              );
              final rates = Panel(
                padding: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Budget Utilization Rate',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: navy,
                      ),
                    ),
                    const SizedBox(height: 36),
                    _Rate('Obligation Rate', t.obligation, t.allotment, blue),
                    const SizedBox(height: 32),
                    _Rate(
                      'Disbursement Rate',
                      t.disbursement,
                      t.allotment,
                      navy,
                    ),
                  ],
                ),
              );
              return sideBySide
                  ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: cardWidth, child: chart),
                          const SizedBox(width: gap),
                          SizedBox(width: cardWidth, child: rates),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        chart,
                        const SizedBox(height: 18),
                        SizedBox(width: double.infinity, child: rates),
                      ],
                    );
            },
          ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 18),
              child: Text(
                'No budget records for these filters. Add a record, or import an Excel file from Add Record.',
                style: TextStyle(color: muted),
              ),
            ),
        ],
      ),
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
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: muted,
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: fieldWidth,
        child: InputDecorator(
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: EdgeInsets.fromLTRB(12, 11, 0, 11),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              isDense: true,
              padding: const EdgeInsets.only(right: 2),
              value: items.any((e) => e.$1 == value) ? value : null,
              style: const TextStyle(
                fontFamily: 'Segoe UI',
                fontSize: 15,
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
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ),
    ],
  );
}

class _Rate extends StatelessWidget {
  const _Rate(this.label, this.value, this.total, this.color);
  final String label;
  final int value, total;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: navy,
        ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : (value / total).clamp(0, 1),
                minHeight: 18,
                color: color,
                backgroundColor: const Color(0xffe6ebf3),
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 78,
            child: Text(
              rate(value, total),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xff4d5e7a),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.amounts);
  final List<int> amounts;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: math.min(size.width, size.height) / 2 - 16,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 28;
    canvas.drawOval(rect, paint..color = line);
    final total = amounts.fold<int>(0, (a, b) => a + math.max(0, b));
    if (total == 0) return;
    var start = -math.pi / 2;
    for (var i = 0; i < amounts.length; i++) {
      final sweep = math.max(0, amounts[i]) / total * math.pi * 2;
      if (sweep > 0) {
        canvas.drawArc(
          rect,
          start,
          math.max(0, sweep - 0.012),
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
