import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../data/finance_store.dart';
import '../ui/common.dart';

class AuditPage extends StatefulWidget {
  const AuditPage({super.key, required this.store});
  final FinanceStore store;
  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage> {
  int year = manilaNow().year, page = 1;
  String program = '', action = '';
  DateTimeRange? dates;
  void change(VoidCallback fn) => setState(() {
    fn();
    page = 1;
  });
  Future<void> pickDates() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(manilaNow().year + 1, 12, 31),
      initialDateRange: dates,
      builder: (ctx, child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 650),
          child: child!,
        ),
      ),
    );
    if (result != null && mounted) change(() => dates = result);
  }

  @override
  Widget build(BuildContext context) {
    if (program.isNotEmpty &&
        !widget.store.programs.any((p) => p.code == program)) {
      program = '';
    }
    String day(DateTime date) => date.toIso8601String().split('T').first;
    final rows = widget.store.auditRows(
      year,
      program: program,
      action: action,
      from: dates == null ? '' : day(dates!.start),
      through: dates == null ? '' : day(dates!.end),
    );
    page = page.clamp(1, math.max(1, (rows.length / 12).ceil()));
    return PageFrame(
      title: 'Audit Trail',
      subtitle: 'Record of changes made to budget records and reference data.',
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
              onChanged: (v) => change(() => year = v),
            ),
            SelectField(
              label: 'Program',
              value: program,
              items: [
                ('', 'All Programs'),
                for (final p in widget.store.programs) (p.code, p.code),
              ],
              onChanged: (v) => change(() => program = v),
            ),
            SelectField(
              label: 'Action',
              value: action,
              items: const [
                ('', 'All Actions'),
                ('Added', 'Added'),
                ('Updated', 'Updated'),
                ('Imported', 'Imported'),
                ('Generated', 'Generated'),
                ('Deleted', 'Deleted'),
              ],
              onChanged: (v) => change(() => action = v),
            ),
            OutlinedButton.icon(
              onPressed: pickDates,
              icon: const Icon(Icons.date_range_outlined, size: 18),
              label: Text(
                dates == null
                    ? 'Select Date Range'
                    : '${day(dates!.start)} – ${day(dates!.end)}',
              ),
            ),
            if (dates != null)
              TextButton(
                onPressed: () => change(() => dates = null),
                child: const Text('All dates'),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Panel(
          child: Column(
            children: [
              WideTable(
                columns: const ['Date & Time', 'Action', 'Details'],
                rows: [
                  for (final r in rows.skip((page - 1) * 12).take(12))
                    [
                      Text(dateLabel(r['at'])),
                      Text('${r['action']}'),
                      tableText('${r['title']} · ${r['detail']}', width: 650),
                    ],
                ],
              ),
              Pager(
                page: page,
                count: rows.length,
                pageSize: 12,
                onChanged: (v) => setState(() => page = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
