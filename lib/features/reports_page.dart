import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';
import 'package:printing/printing.dart';

import '../core/format.dart';
import '../data/finance_store.dart';
import '../data/models.dart';
import '../data/report_io.dart';
import '../ui/common.dart';
import '../ui/theme.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.store});
  final FinanceStore store;
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  int year = manilaNow().year, page = 1;
  String program = '', type = reportTypes.first, format = 'PDF';
  bool busy = false;
  void change(VoidCallback fn) => setState(() {
    fn();
    page = 1;
  });
  Future<void> generate(String fmt) async {
    if (busy) return;
    final selectedYear = year, selectedProgram = program, selectedType = type;
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
    final records = widget.store.records(year, program: program),
        totals = Totals(records),
        data = reportData(type, records);
    final count = records.isEmpty ? 0 : data.rows.length;
    page = page.clamp(1, math.max(1, (count / 12).ceil()));
    final history = widget.store.reportHistory;
    return PageFrame(
      title: 'Reports',
      subtitle: 'Generate, save, and print financial and budget reports.',
      children: [
        Panel(
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              SelectField<String>(
                label: 'Report Type',
                value: type,
                width: 260,
                items: [for (final t in reportTypes) (t, t)],
                onChanged: busy ? null : (v) => change(() => type = v),
              ),
              SelectField<int>(
                label: 'Fiscal Year',
                value: year,
                width: 120,
                items: [for (final y in widget.store.years) (y, '$y')],
                onChanged: busy ? null : (v) => change(() => year = v),
              ),
              SelectField<String>(
                label: 'Program',
                value: program,
                items: [
                  ('', 'All Programs'),
                  for (final p in widget.store.programs) (p.code, p.code),
                ],
                onChanged: busy ? null : (v) => change(() => program = v),
              ),
              SelectField<String>(
                label: 'Format',
                value: format,
                width: 115,
                items: const [('PDF', 'PDF'), ('Excel', 'Excel')],
                onChanged: busy ? null : (v) => setState(() => format = v),
              ),
              FilledButton.icon(
                onPressed: busy || records.isEmpty
                    ? null
                    : () => generate(format),
                icon: const Icon(Icons.description_outlined, size: 18),
                label: Text(busy ? 'Generating…' : 'Generate Report'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Panel(
          child: Wrap(
            spacing: 28,
            runSpacing: 14,
            children: [
              Text('Allotment  ${money(totals.allotment)}'),
              Text('Obligation  ${money(totals.obligation)}'),
              Text('Disbursement  ${money(totals.disbursement)}'),
              Text(
                'Balance  ${money(totals.balance)}',
                style: const TextStyle(
                  color: blue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ReportProgramChart(records: records),
        const SizedBox(height: 18),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Report Preview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy || records.isEmpty
                        ? null
                        : () => generate('Print'),
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('Print'),
                  ),
                  OutlinedButton(
                    onPressed: busy || records.isEmpty
                        ? null
                        : () => generate('PDF'),
                    child: const Text('Save as PDF'),
                  ),
                  OutlinedButton(
                    onPressed: busy || records.isEmpty
                        ? null
                        : () => generate('Excel'),
                    child: const Text('Export Excel'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              WideTable(
                columns: data.headers,
                numeric: {...data.moneyColumns, ...data.rateColumns},
                rows: records.isEmpty
                    ? []
                    : [
                        for (final row
                            in data.rows.skip((page - 1) * 12).take(12))
                          [
                            for (var i = 0; i < row.length; i++)
                              tableText(
                                data.display(row[i], i),
                                width: i == 3 ? 250 : 190,
                              ),
                          ],
                      ],
              ),
              Pager(
                page: page,
                count: count,
                pageSize: 12,
                onChanged: (v) => setState(() => page = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Generated Reports',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              WideTable(
                columns: const [
                  'Report Name',
                  'Fiscal Year',
                  'Format',
                  'Date Generated',
                ],
                rows: [
                  for (final r in history)
                    [
                      tableText(
                        '${r['type']}${(r['program'] as String).isEmpty ? '' : ' · ${r['program']}'}',
                        width: 400,
                      ),
                      Text('${r['year']}'),
                      Text('${r['format']}'),
                      Text(dateLabel(r['at'])),
                    ],
                ],
                empty: 'No reports generated yet.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ReportProgramChart extends StatelessWidget {
  const ReportProgramChart({super.key, required this.records});
  final List<BudgetRecord> records;
  @override
  Widget build(BuildContext context) {
    final groups = <String, List<BudgetRecord>>{};
    for (final r in records) {
      groups.putIfAbsent(r.program, () => []).add(r);
    }
    final totals = {for (final g in groups.entries) g.key: Totals(g.value)};
    final maximum = totals.values.fold<int>(
      1,
      (m, t) => math.max(m, t.allotment),
    );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Budget Utilization by Program',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              for (final e in [
                ('Obligated', blue),
                ('Disbursed', red),
                ('Balance', navy),
              ])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, color: e.$2),
                    const SizedBox(width: 7),
                    Text(
                      e.$1,
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (totals.isEmpty)
            const Text(
              'No budget records for these filters.',
              style: TextStyle(color: muted),
            )
          else
            Wrap(
              spacing: 24,
              runSpacing: 20,
              children: [
                for (final e in totals.entries)
                  SizedBox(
                    width: 120,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 120,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (final bar in [
                                ('Obligated', e.value.obligation, blue),
                                ('Disbursed', e.value.disbursement, red),
                                ('Balance', e.value.balance, navy),
                              ])
                                Tooltip(
                                  message:
                                      '${e.key} · ${bar.$1}: ${money(bar.$2)}',
                                  child: Container(
                                    width: 22,
                                    height: math
                                        .max(2, bar.$2 / maximum * 120)
                                        .clamp(2, 120)
                                        .toDouble(),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: bar.$3,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          e.key,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
