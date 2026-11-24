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
    if (!refs) {
      final programs = widget.store.programs;
      return PageFrame(
        title: 'Programs',
        subtitle: 'Manage programs and their associated names.',
        accent: false,
        expand: true,
        besideSubtitle: FilledButton.icon(
          onPressed: () => editProgram(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Program'),
        ),
        children: [
          Expanded(
            // Same table surface as Budget Utilization: no extra
            // 'Program Management' heading inside the table container.
            child: Panel(
              padding: 0,
              child: _SettingsTable(
                key: const ValueKey('programs-table'),
                centeredColumns: const {0, 1, 3},
                columns: const ['Code', 'Program Name', 'Actions'],
                widths: const {
                  0: FixedColumnWidth(200),
                  1: FlexColumnWidth(),
                  2: FixedColumnWidth(160),
                },
                rows: [
                  for (final p in programs)
                    [
                      Text(
                        p.code,
                        style: const TextStyle(fontWeight: FontWeight.w700),
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
      );
    }

    final referenceRows = widget.store.references(query);
    return PageFrame(
      title: 'UACS Reference',
      subtitle: 'Browse and search UACS reference codes and expense names.',
      accent: false,
      expand: true,
      besideSubtitle: SizedBox(
        width: 320,
        child: TextField(
          key: const ValueKey('uacs-search'),
          onChanged: (v) => setState(() => query = v),
          style: const TextStyle(fontSize: 14, color: ink),
          decoration: const InputDecoration(
            hintText: 'Search UACS Code or Expense…',
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            prefixIcon: Icon(Icons.search, size: 18),
          ),
        ),
      ),
      children: [
        Expanded(
          // The table starts directly in the same full-height panel
          // used by Budget Utilization, with no duplicate page heading.
          child: Panel(
            padding: 0,
            child: _SettingsTable(
              key: const ValueKey('uacs-table'),
              centeredColumns: const {0, 1},
              numberColumnWidth: 80,
              columns: const [
                'UACS Code',
                'Expense (UACS Name)',
              ],
              widths: const {
                0: FixedColumnWidth(240),
                1: FlexColumnWidth(),
              },
              rows: [
                for (final r in referenceRows)
                  [
                    Text(
                      displayCode(r['code'] as String),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text('${r['name']}'),
                  ],
              ],
            ),
          ),
        ),
      ],
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
    this.centeredColumns = const {},
    this.numberColumnWidth = 48,
  });
  final Set<int> centeredColumns;
  final double numberColumnWidth;
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
    0: FixedColumnWidth(numberColumnWidth),
    for (final e in widths.entries) e.key + 1: e.value,
  };

  Widget _text(String text, {TextStyle style = _body, TextAlign align = TextAlign.left}) => Padding(
    padding: EdgeInsets.fromLTRB(align == TextAlign.center ? 8 : 12, 8, 8, 8),
    child: Text(text, style: style, textAlign: align),
  );

  Widget _padded(Widget child, {bool center = false}) => Padding(
    padding: EdgeInsets.fromLTRB(center ? 8 : 12, 8, 8, 8),
    child: DefaultTextStyle(
      style: _body,
      child: center ? Center(child: child) : child,
    ),
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
          _text('#', style: _header, align: TextAlign.center),
          for (final name in columns)
            _text(name, style: _header, align: TextAlign.center),
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
              _text(
                '${i + 1}',
                style: _number,
                align: centeredColumns.contains(0)
                    ? TextAlign.center
                    : TextAlign.left,
              ),
              for (var column = 0; column < rows[i].length; column++)
                _padded(
                  rows[i][column],
                  center: centeredColumns.contains(column + 1),
                ),
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
      showMessage(
        context,
        widget.isProgram ? 'Program saved.' : 'UACS reference saved.',
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final heading = widget.isProgram
        ? (widget.program == null ? 'Add Program' : 'Edit Program')
        : (widget.reference == null ? 'Add UACS Reference' : 'Edit UACS Reference');
    Widget field(String label, TextEditingController controller, Key key) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FieldLabel(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              key: key,
              controller: controller,
              onChanged: (_) {
                if (error != null) {
                  setState(() => error = null);
                }
              },
              decoration: InputDecoration(
                hintText: label,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
              ),
            ),
          ],
        );

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      titlePadding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
      title: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 44),
            child: Text(
              heading,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              key: const ValueKey('reference-editor-close'),
              tooltip: 'Close editor',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              field(
                widget.isProgram ? 'Program Code' : 'UACS Code',
                code,
                const ValueKey('reference-editor-code'),
              ),
              const SizedBox(height: 14),
              field(
                widget.isProgram ? 'Program Name' : 'Expense (UACS Name)',
                name,
                const ValueKey('reference-editor-name'),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  key: const ValueKey('reference-editor-error'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: red, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        TextButton(
          key: const ValueKey('reference-editor-cancel'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('reference-editor-save'),
          onPressed: save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
