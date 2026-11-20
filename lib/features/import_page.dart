import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../data/finance_store.dart';
import '../data/models.dart';
import '../data/workbook_io.dart';
import '../ui/common.dart';
import '../ui/theme.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({super.key, required this.store});
  final FinanceStore store;
  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  String filename = '', program = '', fund = 'CURRENT';
  int year = manilaNow().year, sheetIndex = 0, page = 1;
  bool busy = false, updateExisting = false;
  List<ImportSheet> sheets = [];
  Future<void> browse() async {
    if (busy) return;
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Excel Workbook', extensions: ['xlsx']),
        ],
      );
      if (file == null || !mounted) return;
      setState(() => busy = true);
      if (await file.length() > 25 * 1024 * 1024) {
        throw const FinanceError('Choose an Excel file smaller than 25 MB.');
      }
      final parsed = await compute(parseWorkbook, await file.readAsBytes());
      if (!mounted) return;
      setState(() {
        sheets = parsed;
        filename = file.name;
        sheetIndex = math.max(0, sheets.indexWhere((s) => s.error.isEmpty));
        syncSheet();
      });
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e is FinanceError ? e.message : 'The Excel file could not be read. Check that it is a valid .xlsx workbook.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void syncSheet() {
    final sheet = sheets[sheetIndex],
        active = widget.store.programs
            .where((p) => p.active)
            .map((p) => p.code)
            .toList();
    program = active.contains(sheet.program)
        ? sheet.program
        : active.firstOrNull ?? '';
    fund = sheet.fund;
    page = 1;
  }

  List<(ImportLine, BudgetRecord, String, String)> classified() {
    if (sheets.isEmpty) return [];
    final lines = sheets[sheetIndex].lines;
    final previous = {
      for (final r in widget.store.records(year, program: program, fund: fund))
        r.code: r,
    };
    final counts = <String, int>{};
    for (final line in lines) {
      counts[line.code] = (counts[line.code] ?? 0) + 1;
    }
    return [
      for (final line in lines)
        (() {
          final record = line.record(year, program, fund),
              before = previous[line.code];
          final error = line.parseError.isNotEmpty
              ? line.parseError
              : (record.error ??
                    ((counts[line.code] ?? 0) > 1
                        ? 'This code appears more than once in this worksheet.'
                        : ''));
          final status = error.isNotEmpty
              ? 'Invalid'
              : before == null
              ? 'Added'
              : before.sameAmountsAndText(record)
              ? 'Unchanged'
              : 'Updated';
          return (line, record, status, error);
        })(),
    ];
  }

  Future<void> apply() async {
    if (busy || sheets.isEmpty) return;
    final payload = classified()
        .where((r) => r.$3 == 'Added' || (r.$3 == 'Updated' && updateExisting))
        .map((r) => r.$2)
        .toList();
    try {
      final count = widget.store.importRecords(
        payload,
        updateExisting: updateExisting,
      );
      if (!mounted) return;
      setState(() => page = 1);
      showMessage(context, '$count budget record(s) imported.');
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = classified(), counts = <String, int>{};
    for (final row in rows) {
      counts[row.$3] = (counts[row.$3] ?? 0) + 1;
    }
    final eligible =
        (counts['Added'] ?? 0) +
        (updateExisting ? (counts['Updated'] ?? 0) : 0);
    page = page.clamp(1, math.max(1, (rows.length / 25).ceil()));
    return PageFrame(
      title: 'Import Records',
      subtitle: 'Review and import budget lines from an Excel workbook.',
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.upload_file_outlined, color: blue, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Select an Excel File (.xlsx)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Required columns: UACS Code, UACS Name, Allotment, Obligation, and Disbursement. Remarks is optional.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Worksheet names such as GAS-REG_CURRENT help identify the program and fund. Review these selections before importing.',
                style: TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 18,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: busy ? null : browse,
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: Text(busy ? 'Reading workbook…' : 'Browse File'),
                  ),
                  Text(
                    filename.isEmpty ? 'No workbook selected.' : filename,
                    style: const TextStyle(color: muted),
                  ),
                ],
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (sheets.isNotEmpty) ...[
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              SelectField(
                label: 'Fiscal Year',
                value: year,
                width: 130,
                items: [for (final y in widget.store.years) (y, '$y')],
                onChanged: (v) => setState(() {
                  year = v;
                  page = 1;
                }),
              ),
              SelectField(
                label: 'Worksheet',
                value: sheetIndex,
                width: 270,
                items: [
                  for (var i = 0; i < sheets.length; i++) (i, sheets[i].name),
                ],
                onChanged: (v) => setState(() {
                  sheetIndex = v;
                  syncSheet();
                }),
              ),
              SelectField(
                label: 'Program',
                value: program,
                items: [
                  for (final p in widget.store.programs.where((p) => p.active))
                    (p.code, p.code),
                ],
                onChanged: (v) => setState(() {
                  program = v;
                  page = 1;
                }),
              ),
              SelectField(
                label: 'Fund Source',
                value: fund,
                items: const [
                  ('CURRENT', 'Current'),
                  ('CONTINUING', 'Continuing'),
                ],
                onChanged: (v) => setState(() {
                  fund = v;
                  page = 1;
                }),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Import Preview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (sheets[sheetIndex].error.isNotEmpty)
                  Text(
                    sheets[sheetIndex].error,
                    style: const TextStyle(color: red),
                  )
                else
                  Text(
                    'Added ${counts['Added'] ?? 0}   ·   Updated ${counts['Updated'] ?? 0}   ·   Unchanged ${counts['Unchanged'] ?? 0}   ·   Invalid ${counts['Invalid'] ?? 0}',
                    style: const TextStyle(color: muted),
                  ),
                const SizedBox(height: 14),
                WideTable(
                  columns: const [
                    'Excel Row',
                    'UACS Code',
                    'Expense',
                    'Allotment',
                    'Obligation',
                    'Disbursement',
                    'Status',
                  ],
                  numeric: const {3, 4, 5},
                  rows: [
                    for (final r in rows.skip((page - 1) * 25).take(25))
                      [
                        Text('${r.$1.number}'),
                        tableText(displayCode(r.$2.code)),
                        tableText(r.$2.name, width: 230),
                        Text(money(r.$2.allotment)),
                        Text(money(r.$2.obligation)),
                        Text(money(r.$2.disbursement)),
                        Tooltip(
                          message: r.$4,
                          child: tableText(
                            '${r.$3}${r.$4.isEmpty ? '' : ' · ${r.$4}'}',
                            width: 330,
                          ),
                        ),
                      ],
                  ],
                ),
                Pager(
                  page: page,
                  count: rows.length,
                  pageSize: 25,
                  onChanged: (v) => setState(() => page = v),
                ),
                const Divider(),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: updateExisting,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'Apply updates to existing records',
                    style: TextStyle(fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Replace the amounts, expense name, and remarks of matching lines.',
                    style: TextStyle(fontSize: 12),
                  ),
                  onChanged: (v) => setState(() => updateExisting = v ?? false),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 18,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: eligible > 0 && program.isNotEmpty && !busy
                          ? apply
                          : null,
                      icon: const Icon(Icons.file_download_done, size: 18),
                      label: Text(
                        'Import $eligible Record${eligible == 1 ? '' : 's'}',
                      ),
                    ),
                    const Text(
                      'Invalid and unchanged rows are skipped.',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
