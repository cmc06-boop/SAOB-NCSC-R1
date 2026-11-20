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
      program = '';
    }
    final all = widget.store.records(year, program: program);
    final items = <String, String>{
      for (final r in all) r.code: '${r.name} (${displayCode(r.code)})',
    };
    if (!items.containsKey(item)) item = '';
    final rows = all.where((r) => item.isEmpty || r.code == item).toList(),
        t = Totals(rows);
    final shares = <String, int>{
      for (final p in widget.store.programs) p.code: 0,
    };
    for (final r in rows) {
      shares[r.program] = (shares[r.program] ?? 0) + r.allotment;
    }
    return PageFrame(
      title: 'Dashboard',
      subtitle: 'Overview of Budget Utilization',
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            SelectField(
              label: 'Fiscal Year',
              value: year,
              width: 130,
              items: [for (final y in widget.store.years) (y, '$y')],
              onChanged: (v) => setState(() {
                year = v;
                item = '';
              }),
            ),
            SelectField(
              label: 'Program',
              value: program,
              items: [
                ('', 'All Programs'),
                for (final p in widget.store.programs) (p.code, p.code),
              ],
              onChanged: (v) => setState(() {
                program = v;
                item = '';
              }),
            ),
            SelectField(
              label: 'Item',
              value: item,
              width: 320,
              items: [
                ('', 'All Items'),
                for (final e in items.entries) (e.key, e.value),
              ],
              onChanged: (v) => setState(() => item = v),
            ),
          ],
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 1000
                ? 4
                : c.maxWidth >= 520
                ? 2
                : 1;
            final metrics = [
              (
                'Total Allotment',
                t.allotment,
                Icons.account_balance_wallet_outlined,
                blue,
              ),
              (
                'Total Obligation',
                t.obligation,
                Icons.receipt_long_outlined,
                navy,
              ),
              (
                'Total Disbursement',
                t.disbursement,
                Icons.payments_outlined,
                blue,
              ),
              ('Remaining Balance', t.balance, Icons.savings_outlined, red),
            ];
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final m in metrics)
                  SizedBox(
                    width: (c.maxWidth - (cols - 1) * 14) / cols,
                    child: Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  m.$1,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: muted,
                                  ),
                                ),
                              ),
                              Icon(m.$3, size: 20, color: m.$4),
                            ],
                          ),
                          const SizedBox(height: 18),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              money(m.$2),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: navy,
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
            final chart = Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Utilization by Program',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Share of total allotment',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                  const SizedBox(height: 22),
                  LayoutBuilder(
                    builder: (context, k) {
                      final donut = SizedBox(
                        width: 220,
                        height: 220,
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
                                width: 152,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FittedBox(
                                      child: Text(
                                        money(t.allotment),
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: navy,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    const Text(
                                      'Total Allotment',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: muted,
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
                              padding: const EdgeInsets.symmetric(vertical: 9),
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
                                  Text(
                                    e.$2.key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '${money(e.$2.value)} (${rate(e.$2.value, t.allotment)})',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                      return k.maxWidth >= 500
                          ? Row(
                              children: [
                                donut,
                                const SizedBox(width: 22),
                                Expanded(child: legend),
                              ],
                            )
                          : Column(
                              children: [
                                donut,
                                const SizedBox(height: 16),
                                legend,
                              ],
                            );
                    },
                  ),
                ],
              ),
            );
            final rates = Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Budget Utilization Rate',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 30),
                  _Rate('Obligation Rate', t.obligation, t.allotment, blue),
                  const SizedBox(height: 28),
                  _Rate('Disbursement Rate', t.disbursement, t.allotment, red),
                  const SizedBox(height: 24),
                  const Text(
                    'Both rates use total allotment as the base.',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            );
            return c.maxWidth >= 1000
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: chart),
                      const SizedBox(width: 18),
                      Expanded(flex: 2, child: rates),
                    ],
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
              'No budget records for these filters. Add a record or use Import Records.',
              style: TextStyle(color: muted),
            ),
          ),
      ],
    );
  }
}

class _Rate extends StatelessWidget {
  const _Rate(this.label, this.value, this.total, this.color);
  final String label;
  final int value, total;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(
            rate(value, total),
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: total == 0 ? 0 : (value / total).clamp(0, 1),
          minHeight: 12,
          color: color,
          backgroundColor: line,
        ),
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
      ..strokeWidth = 23;
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
