import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../data/finance_store.dart';
import '../data/models.dart';
import '../ui/common.dart';
import '../ui/theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.store});
  final FinanceStore store;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool refs = false;
  String query = '';
  int page = 1;
  Future<void> editProgram([Program? program]) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => ReferenceEditor(
        store: widget.store,
        program: program,
        isProgram: true,
      ),
    );
  }

  Future<void> editReference([DbRow? row]) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => ReferenceEditor(
        store: widget.store,
        reference: row,
        isProgram: false,
      ),
    );
  }

  void toggle(Program p, bool active) {
    try {
      widget.store.saveProgram(p.code, p.name, active, original: p.code);
    } catch (e) {
      showMessage(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final programs = widget.store.programs,
        referenceRows = widget.store.references(query);
    page = page.clamp(1, math.max(1, (referenceRows.length / 15).ceil()));
    return PageFrame(
      title: 'Settings',
      subtitle: 'Manage programs and UACS reference data.',
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('Programs'),
              icon: Icon(Icons.category_outlined),
            ),
            ButtonSegment(
              value: true,
              label: Text('UACS Reference'),
              icon: Icon(Icons.menu_book_outlined),
            ),
          ],
          selected: {refs},
          onSelectionChanged: (v) => setState(() {
            refs = v.first;
            page = 1;
          }),
        ),
        const SizedBox(height: 20),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 20,
                runSpacing: 14,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    refs ? 'UACS Reference' : 'Program Management',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: refs
                        ? () => editReference()
                        : () => editProgram(),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(refs ? 'Add UACS Code' : 'Add Program'),
                  ),
                  if (refs)
                    SearchBox(
                      onChanged: (v) => setState(() {
                        query = v;
                        page = 1;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                refs
                    ? 'Maintain the UACS codes and expense names used in budget records.'
                    : 'Active programs are available for new records. Deactivated programs keep their existing records and remain visible in reports.',
                style: const TextStyle(fontSize: 13, color: muted),
              ),
              const SizedBox(height: 18),
              if (refs) ...[
                WideTable(
                  columns: const [
                    'UACS Code',
                    'Expense (UACS Name)',
                    'Actions',
                  ],
                  rows: [
                    for (final r
                        in referenceRows.skip((page - 1) * 15).take(15))
                      [
                        Text(displayCode(r['code'] as String)),
                        tableText(r['name'], width: 520),
                        TextButton.icon(
                          onPressed: () => editReference(r),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit'),
                        ),
                      ],
                  ],
                ),
                Pager(
                  page: page,
                  count: referenceRows.length,
                  pageSize: 15,
                  onChanged: (v) => setState(() => page = v),
                ),
              ] else
                WideTable(
                  columns: const ['Code', 'Program Name', 'Status', 'Actions'],
                  rows: [
                    for (final p in programs)
                      [
                        Text(
                          p.code,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        tableText(p.name, width: 400),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: p.active,
                              onChanged: (v) => toggle(p, v),
                            ),
                            const SizedBox(width: 8),
                            Text(p.active ? 'Active' : 'Inactive'),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () => editProgram(p),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit'),
                        ),
                      ],
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class ReferenceEditor extends StatefulWidget {
  const ReferenceEditor({
    super.key,
    required this.store,
    required this.isProgram,
    this.program,
    this.reference,
  });
  final FinanceStore store;
  final bool isProgram;
  final Program? program;
  final DbRow? reference;
  @override
  State<ReferenceEditor> createState() => _ReferenceEditorState();
}

class _ReferenceEditorState extends State<ReferenceEditor> {
  late final TextEditingController code, name;
  late bool active;
  String? error;
  @override
  void initState() {
    super.initState();
    code = TextEditingController(
      text: widget.isProgram
          ? widget.program?.code
          : widget.reference?['code'] as String?,
    );
    name = TextEditingController(
      text: widget.isProgram
          ? widget.program?.name
          : widget.reference?['name'] as String?,
    );
    active = widget.program?.active ?? true;
  }

  @override
  void dispose() {
    code.dispose();
    name.dispose();
    super.dispose();
  }

  void save() {
    try {
      if (widget.isProgram) {
        widget.store.saveProgram(
          code.text,
          name.text,
          active,
          original: widget.program?.code,
        );
      } else {
        widget.store.saveReference(
          code.text,
          name.text,
          original: widget.reference?['code'] as String?,
        );
      }
      Navigator.pop(context);
      showMessage(context, 'Reference saved.');
    } catch (e) {
      setState(() => error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.isProgram ? 'Program' : 'UACS Reference'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: code,
              decoration: InputDecoration(
                labelText: widget.isProgram ? 'Program Code' : 'UACS Code',
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: name,
              decoration: InputDecoration(
                labelText: widget.isProgram
                    ? 'Program Name'
                    : 'Expense (UACS Name)',
              ),
            ),
            if (widget.isProgram)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: active,
                onChanged: (v) => setState(() => active = v ?? true),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
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
      FilledButton(onPressed: save, child: const Text('Save')),
    ],
  );
}
