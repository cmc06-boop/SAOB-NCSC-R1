import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../data/finance_store.dart';
import '../data/models.dart';
import '../ui/common.dart';
import '../ui/theme.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key, required this.store});
  final FinanceStore store;
  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  int year = manilaNow().year, page = 1;
  String program = '', fund = 'CURRENT', query = '';
  void change(VoidCallback fn) => setState(() {
    fn();
    page = 1;
  });
  Future<void> edit([BudgetRecord? record]) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => RecordEditor(
        store: widget.store,
        record: record,
        year: year,
        program: program,
        fund: fund,
      ),
    );
  }

  Future<void> remove(BudgetRecord record) async {
    if (!await confirm(
      context,
      'Delete budget record?',
      'Remove ${displayCode(record.code)} · ${record.name}?',
    )) {
      return;
    }
    try {
      widget.store.deleteRecord(record.id!);
      if (mounted) showMessage(context, 'Record deleted.');
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (program.isNotEmpty &&
        !widget.store.programs.any((p) => p.code == program)) {
      program = '';
    }
    final rows = widget.store.records(
          year,
          program: program,
          fund: fund,
          query: query,
        ),
        t = Totals(rows);
    page = page.clamp(1, math.max(1, (rows.length / 12).ceil()));
    final start = (page - 1) * 12;
    return PageFrame(
      title: 'Budget Utilization',
      subtitle: 'Manage allotments, obligations, disbursements, and balances.',
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
              label: 'Fund Source',
              value: fund,
              items: const [
                ('CURRENT', 'Current'),
                ('CONTINUING', 'Continuing'),
              ],
              onChanged: (v) => change(() => fund = v),
            ),
            SearchBox(onChanged: (v) => change(() => query = v)),
            FilledButton.icon(
              onPressed: () => edit(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Record'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 24,
                runSpacing: 10,
                children: [
                  Text('Allotment  ${money(t.allotment)}'),
                  Text('Obligation  ${money(t.obligation)}'),
                  Text('Disbursement  ${money(t.disbursement)}'),
                  Text(
                    'Balance  ${money(t.balance)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              BudgetTable(
                records: rows.skip(start).take(12).toList(),
                onEdit: edit,
                onDelete: remove,
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

class RecordEditor extends StatefulWidget {
  const RecordEditor({
    super.key,
    required this.store,
    this.record,
    required this.year,
    required this.program,
    required this.fund,
  });
  final FinanceStore store;
  final BudgetRecord? record;
  final int year;
  final String program, fund;
  @override
  State<RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<RecordEditor> {
  late int year;
  late String program, fund;
  late final TextEditingController code,
      name,
      allotment,
      obligation,
      disbursement,
      remarks;
  String? error;
  @override
  void initState() {
    super.initState();
    final r = widget.record;
    year = r?.year ?? widget.year;
    fund = r?.fund ?? widget.fund;
    final active = widget.store.programs
        .where((p) => p.active)
        .map((p) => p.code)
        .toList();
    program =
        r?.program ??
        (active.contains(widget.program)
            ? widget.program
            : active.firstOrNull ?? '');
    code = TextEditingController(text: r?.code ?? '');
    name = TextEditingController(text: r?.name ?? '');
    allotment = TextEditingController(
      text: r == null ? '' : (r.allotment / 100).toStringAsFixed(2),
    );
    obligation = TextEditingController(
      text: ((r?.obligation ?? 0) / 100).toStringAsFixed(2),
    );
    disbursement = TextEditingController(
      text: ((r?.disbursement ?? 0) / 100).toStringAsFixed(2),
    );
    remarks = TextEditingController(text: r?.remarks ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      code,
      name,
      allotment,
      obligation,
      disbursement,
      remarks,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> lookup() async {
    final r = await showDialog<DbRow>(
      context: context,
      builder: (ctx) => ReferencePicker(store: widget.store),
    );
    if (r != null && mounted) {
      setState(() {
        code.text = r['code'] as String;
        name.text = r['name'] as String;
      });
    }
  }

  void save() {
    try {
      final a = parseCents(allotment.text, required: true),
          o = parseCents(obligation.text),
          d = parseCents(disbursement.text);
      if (a == null || o == null || d == null) {
        throw const FinanceError(
          'Enter valid non-negative amounts with up to two decimal places.',
        );
      }
      widget.store.saveRecord(
        BudgetRecord(
          id: widget.record?.id,
          year: year,
          program: program,
          fund: fund,
          code: codeKey(code.text),
          name: name.text,
          allotment: a,
          obligation: o,
          disbursement: d,
          remarks: remarks.text,
        ),
      );
      Navigator.pop(context);
      showMessage(context, 'Budget record saved.');
    } catch (e) {
      setState(() => error = friendlyError(e));
    }
  }

  Widget field(
    String label,
    TextEditingController c, {
    bool amount = false,
    Widget? suffix,
    int lines = 1,
  }) => TextField(
    controller: c,
    maxLines: lines,
    onChanged: amount ? (_) => setState(() {}) : null,
    keyboardType: amount
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    decoration: InputDecoration(labelText: label, suffixIcon: suffix),
  );
  @override
  Widget build(BuildContext context) {
    final a = parseCents(allotment.text) ?? 0,
        o = parseCents(obligation.text) ?? 0,
        d = parseCents(disbursement.text) ?? 0;
    final programs = widget.store.programs
        .where((p) => p.active || p.code == widget.record?.program)
        .toList();
    return AlertDialog(
      title: Text(
        widget.record == null ? 'Add Budget Record' : 'Edit Budget Record',
      ),
      content: SizedBox(
        width: 820,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  SelectField(
                    label: 'Fiscal Year *',
                    value: year,
                    width: 150,
                    items: [for (final y in widget.store.years) (y, '$y')],
                    onChanged: (v) => setState(() => year = v),
                  ),
                  SelectField(
                    label: 'Program *',
                    value: program,
                    width: 220,
                    items: [for (final p in programs) (p.code, p.code)],
                    onChanged: (v) => setState(() => program = v),
                  ),
                  SelectField(
                    label: 'Fund Source *',
                    value: fund,
                    items: const [
                      ('CURRENT', 'Current'),
                      ('CONTINUING', 'Continuing'),
                    ],
                    onChanged: (v) => setState(() => fund = v),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              field(
                'UACS Code *',
                code,
                suffix: IconButton(
                  tooltip: 'Find UACS code',
                  onPressed: lookup,
                  icon: const Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 18),
              field('Expense (UACS Name) *', name),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, c) => Wrap(
                  spacing: 14,
                  runSpacing: 18,
                  children: [
                    for (final f in [
                      ('Allotment *', allotment),
                      ('Obligation', obligation),
                      ('Disbursement', disbursement),
                    ])
                      SizedBox(
                        width: c.maxWidth >= 650
                            ? (c.maxWidth - 28) / 3
                            : c.maxWidth,
                        child: field(f.$1, f.$2, amount: true),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              field('Remarks', remarks, lines: 3),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  spacing: 22,
                  runSpacing: 10,
                  children: [
                    Text(
                      'Balance: ${money(a - o)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text('Obligation Rate: ${rate(o, a)}'),
                    Text('Disbursement Rate: ${rate(d, o)}'),
                  ],
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(error!, style: const TextStyle(color: red)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: program.isEmpty ? null : save,
          child: const Text('Save Record'),
        ),
      ],
    );
  }
}

class ReferencePicker extends StatefulWidget {
  const ReferencePicker({super.key, required this.store});
  final FinanceStore store;
  @override
  State<ReferencePicker> createState() => _ReferencePickerState();
}

class _ReferencePickerState extends State<ReferencePicker> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final refs = widget.store.references(query);
    return AlertDialog(
      title: const Text('Select a UACS Code'),
      content: SizedBox(
        width: 600,
        height: 400,
        child: Column(
          children: [
            SearchBox(onChanged: (v) => setState(() => query = v)),
            const SizedBox(height: 16),
            Expanded(
              child: refs.isEmpty
                  ? const EmptyState(text: 'No UACS references found.')
                  : ListView.builder(
                      itemCount: refs.length,
                      itemBuilder: (ctx, i) => ListTile(
                        title: Text(displayCode(refs[i]['code'] as String)),
                        subtitle: Text(refs[i]['name'] as String),
                        onTap: () => Navigator.pop(context, refs[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
