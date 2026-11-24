import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../data/report_summary.dart';
import '../ui/theme.dart';

/// On-screen preview of the workbook-style SUMMARY before exporting.
class SummaryPreview extends StatelessWidget {
  const SummaryPreview({super.key, required this.records, required this.year});

  final List<BudgetRecord> records;
  final int year;

  @override
  Widget build(BuildContext context) {
    final sections = saobSummarySections(records);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image(
                    image: AssetImage('assets/ncsc-logo-transparent.png'),
                    width: 54,
                    height: 54,
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
                          ),
                        ),
                        Text(
                          'REGION I',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'SUMMARY',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              Text(
                'Fiscal Year: $year',
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: line),
        Expanded(
          child: LayoutBuilder(
            builder: (context, available) => SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: math.max(940.0, available.maxWidth),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final section in sections) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            color: navy,
                            child: Text(
                              section.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          _sectionTable(section),
                          const SizedBox(height: 18),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTable(SaobSummarySection section) {
    Widget cell(
      String value, {
      bool header = false,
      bool total = false,
      bool numeric = false,
    }) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Text(
            value,
            textAlign: numeric ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              fontSize: 11,
              fontWeight: header || total ? FontWeight.w700 : FontWeight.w400,
              color: ink,
            ),
          ),
        );

    final rows = [
      for (final entry in section.rows)
        summaryDisplayRow(entry.program, entry.totals),
      summaryDisplayRow('TOTAL', section.totals),
    ];
    return Table(
      key: ValueKey('summary-table-${section.fund.toLowerCase()}'),
      border: TableBorder.all(color: line, width: 0.6),
      columnWidths: const {
        0: FlexColumnWidth(),
        1: FixedColumnWidth(128),
        2: FixedColumnWidth(128),
        3: FixedColumnWidth(170),
        4: FixedColumnWidth(130),
        5: FixedColumnWidth(128),
        6: FixedColumnWidth(100),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xffeef3fb)),
          children: [
            for (var i = 0; i < summaryHeaders.length; i++)
              cell(summaryHeaders[i], header: true, numeric: i > 0),
          ],
        ),
        for (var i = 0; i < rows.length; i++)
          TableRow(
            decoration: BoxDecoration(
              color: i == rows.length - 1
                  ? const Color(0xffe7eefc)
                  : i.isOdd
                  ? const Color(0xfff7f9fc)
                  : Colors.white,
            ),
            children: [
              for (var col = 0; col < rows[i].length; col++)
                cell(
                  rows[i][col],
                  total: i == rows.length - 1,
                  numeric: col > 0,
                ),
            ],
          ),
      ],
    );
  }
}
