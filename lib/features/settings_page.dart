import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../data/finance_store.dart';
import '../data/models.dart';
import '../ui/common.dart';
import '../ui/theme.dart';

/// Two independent sidebar pages sharing the existing management forms.
class ProgramsPage extends StatelessWidget {
  const ProgramsPage({super.key, required this.store});
  final FinanceStore store;

  @override
  Widget build(BuildContext context) =>
      _ReferenceManagementPage(store: store, references: false);
}

class UacsReferencePage extends StatelessWidget {
  const UacsReferencePage({super.key, required this.store});
  final FinanceStore store;

  @override
  Widget build(BuildContext context) =>
      _ReferenceManagementPage(store: store, references: true);
}

class _ReferenceManagementPage extends StatefulWidget {
  const _ReferenceManagementPage({
    required this.store,
    required this.references,
  });
  final FinanceStore store;
  final bool references;

  @override
  State<_ReferenceManagementPage> createState() =>
      _ReferenceManagementPageState();
}

class _ReferenceManagementPageState extends State<_ReferenceManagementPage> {
  bool get refs => widget.references;
  String query = '';
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

  Future<void> removeProgram(Program program) async {
    if (!await confirm(
      context,
      'Delete program?',
      'Remove ${program.code} · ${program.name}?',
    )) {
      return;
    }
    try {
      widget.store.deleteProgram(program.code);
      if (mounted) showMessage(context, 'Program deleted.');
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final programs = widget.store.programs,
        referenceRows = refs ? widget.store.references(query) : <DbRow>[];
    final title = Text(
      refs ? 'UACS Reference' : 'Programs',
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1,
      ),
    );
    final subtitle = Text(
      refs
          ? 'Browse and search UACS reference codes and expense names.'
          : 'Manage programs and their associated names.',
      style: TextStyle(fontSize: 14, color: muted, height: 1.35),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 8),
          subtitle,
          const SizedBox(height: 22),
          Expanded(
            child: Panel(
              padding: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      children: [
                        Icon(
                          refs
                              ? Icons.menu_book_outlined
                              : Icons.category_outlined,
                          color: blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          refs ? 'UACS Reference' : 'Program Management',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        if (refs)
                          SizedBox(
                            width: 320,
                            height: 40,
                            child: TextField(
                              onChanged: (v) => setState(() => query = v),
                              style: const TextStyle(fontSize: 14, color: ink),
                              decoration: const InputDecoration(
                                hintText: 'Search UACS Code or Expense…',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                prefixIcon: Icon(Icons.search, size: 18),
                                prefixIconConstraints: BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 36,
                                ),
                              ),
                            ),
                          )
                        else
                          FilledButton.icon(
                            onPressed: () => editProgram(),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Program'),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: refs
                          ? _SettingsTable(
                              key: const ValueKey('uacs'),
                              columns: const [
                                'UACS Code',
                                'Expense (UACS Name)',
                              ],
                              widths: const {
                                0: FixedColumnWidth(140),
                                1: FlexColumnWidth(),
                              },
                              rows: [
                                for (final r in referenceRows)
                                  [
                                    Text(
                                      displayCode(r['code'] as String),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text('${r['name']}'),
                                  ],
                              ],
                            )
                          : _SettingsTable(
                              key: const ValueKey('programs'),
                              columns: const [
                                'Code',
                                'Program Name',
                                'Actions',
                              ],
                              widths: const {
                                0: FixedColumnWidth(200),
                                1: FlexColumnWidth(),
                                2: FixedColumnWidth(96),
                              },
                              rows: [
                                for (final p in programs)
                                  [
                                    Text(
                                      p.code,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(p.name),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _boxedIcon(
                                          tooltip: 'Edit',
                                          color: blue,
                                          icon: Icons.edit_outlined,
                                          onPressed: () => editProgram(p),
                                        ),
                                        const SizedBox(width: 8),
                                        _boxedIcon(
                                          tooltip: 'Delete',
                                          color: red,
                                          icon: Icons.delete_outline,
                                          onPressed: () => removeProgram(p),
                                        ),
                                      ],
                                    ),
                                  ],
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


Widget _boxedIcon({
  required String tooltip,
  required Color color,
  required IconData icon,
  required VoidCallback onPressed,
}) => Tooltip(
  message: tooltip,
  child: Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
      side: BorderSide(color: color),
    ),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 34,
        height: 34,
        child: Icon(icon, size: 18, color: color),
      ),
    ),
  ),
);

class _SettingsTable extends StatelessWidget {
  const _SettingsTable({
    super.key,
    required this.columns,
    required this.widths,
    required this.rows,
  });
  final List<String> columns;
  final Map<int, TableColumnWidth> widths;
  final List<List<Widget>> rows;

  static const _border = BorderSide(color: Color(0xffd5e1f2));
  static const _header = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: navy,
  );
  static const _body = TextStyle(fontSize: 13, color: ink);
  static const _number = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: blue,
  );

  Map<int, TableColumnWidth> get _widths => {
    0: const FixedColumnWidth(48),
    for (final e in widths.entries) e.key + 1: e.value,
  };

  Widget _text(String text, {TextStyle style = _body}) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
    child: Text(text, style: style),
  );

  Widget _padded(Widget child) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
    child: DefaultTextStyle(style: _body, child: child),
  );

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
    final headerTable = Table(
      border: const TableBorder(verticalInside: _border, bottom: _border),
      columnWidths: _widths,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _row([
          _text('#', style: _header),
          for (final name in columns) _text(name, style: _header),
        ], const Color(0xffeef3fb)),
      ],
    );
    final bodyTable = Table(
      border: const TableBorder(
        horizontalInside: _border,
        verticalInside: _border,
      ),
      columnWidths: _widths,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        if (rows.isEmpty)
          _row([
            _text(''),
            _text(
              'No records found.',
              style: const TextStyle(fontSize: 13, color: muted),
            ),
            for (var i = 1; i < columns.length; i++) _text(''),
          ], Colors.white)
        else
          for (var i = 0; i < rows.length; i++)
            _row([
              _text('${i + 1}', style: _number),
              for (final cell in rows[i]) _padded(cell),
            ], i.isOdd ? const Color(0xfff7f9fc) : Colors.white),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        headerTable,
        Expanded(child: _SettingsScroller(child: bodyTable)),
      ],
    );
  }
}

class _SettingsScroller extends StatefulWidget {
  const _SettingsScroller({required this.child});
  final Widget child;
  @override
  State<_SettingsScroller> createState() => _SettingsScrollerState();
}

class _SettingsScrollerState extends State<_SettingsScroller> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: _scroll,
    thumbVisibility: true,
    child: SingleChildScrollView(
      controller: _scroll,
      child: widget.child,
    ),
  );
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
  String? error;
  @override
  void initState() {
    super.initState();
    final program = widget.program;
    code = TextEditingController(
      text: widget.isProgram
          ? program?.code
          : widget.reference?['code'] as String?,
    );
    name = TextEditingController(
      text: widget.isProgram
          ? widget.program?.name
          : widget.reference?['name'] as String?,
    );
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
          widget.program?.active ?? true,
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
