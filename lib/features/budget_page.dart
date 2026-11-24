import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../data/finance_store.dart';
import '../data/models.dart';
import '../ui/common.dart';
import '../ui/theme.dart';
import 'import_page.dart';

ButtonStyle _outlineAction(Color color, Color hover) {
  const disabled = Color(0xffb0b6bf);
  Color fg(Set<WidgetState> states) =>
      states.contains(WidgetState.disabled) ? disabled : color;
  return ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith(fg),
    iconColor: WidgetStateProperty.resolveWith(fg),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      final active =
          states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.pressed) ||
          states.contains(WidgetState.focused);
      if (states.contains(WidgetState.disabled) || !active) {
        return Colors.white;
      }
      return hover;
    }),
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return Colors.transparent;
      if (states.contains(WidgetState.pressed)) {
        return color.withValues(alpha: 0.16);
      }
      if (states.contains(WidgetState.hovered)) {
        return color.withValues(alpha: 0.1);
      }
      return Colors.transparent;
    }),
    side: WidgetStateProperty.resolveWith(
      (states) => BorderSide(color: fg(states), width: 1.4),
    ),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key, required this.store});
  final FinanceStore store;
  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  final _actionsKey = GlobalKey();
  int year = manilaNow().year;
  String program = '', query = '';
  int? selectedId;
  double _searchWidth = 320;
  void _matchSearchWidth() {
    final box = _actionsKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final width = box.size.width;
    if ((_searchWidth - width).abs() > 0.5) {
      setState(() => _searchWidth = width);
    }
  }

  void change(VoidCallback fn) => setState(() {
    fn();
    selectedId = null;
  });
  Future<void> edit([BudgetRecord? record]) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RecordEditor(
        store: widget.store,
        record: record,
        year: year,
        program: program,
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
      if (mounted) {
        setState(() => selectedId = null);
        showMessage(context, 'Record deleted.');
      }
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (program.isNotEmpty &&
        !widget.store.programs.any((p) => p.code == program)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) change(() => program = '');
      });
    }
    final rows = widget.store.records(
          year,
          program: program,
          query: query,
        ),
        t = Totals(rows);
    BudgetRecord? selected;
    for (final row in rows) {
      if (row.id == selectedId) selected = row;
    }
    final chosen = selected;
    final currentYear = manilaNow().year;
    final canEncode = year == currentYear;
    final filters = Wrap(
      spacing: 18,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _InlineChoice(
          label: 'Fiscal Year',
          value: year,
          width: 108,
          items: [for (final y in widget.store.years) (y, '$y')],
          onChanged: (v) => change(() => year = v),
        ),
        _InlineChoice(
          label: 'Program',
          value: program,
          width: 160,
          items: [
            ('', 'All Programs'),
            for (final p in widget.store.programs)
              (p.code, p.code),
          ],
          onChanged: (v) => change(() => program = v),
        ),
        if (!canEncode)
          const Text(
            'Past years are view-only. Encode/import is for the current year only.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
      ],
    );
    final searchField = TextField(
      onChanged: (v) => change(() => query = v),
      style: const TextStyle(fontSize: 14),
      decoration: const InputDecoration(
        hintText: 'Search UACS Code or Expense...',
        prefixIcon: Icon(Icons.search, size: 20),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          onPressed: canEncode ? () => edit() : null,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Record'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          style: _outlineAction(blue, const Color(0xffe8f0fc)),
          onPressed: !canEncode
              ? null
              : () {
                  if (chosen == null) {
                    showMessage(context, 'Select a record to edit.');
                    return;
                  }
                  edit(chosen);
                },
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          style: _outlineAction(red, const Color(0xffffe8eb)),
          onPressed: !canEncode
              ? null
              : () {
                  if (chosen == null) {
                    showMessage(context, 'Select a record to delete.');
                    return;
                  }
                  remove(chosen);
                },
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Delete'),
        ),
      ],
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _matchSearchWidth());
    return PageFrame(
      title: 'Budget Utilization',
      subtitle:
          'Manage allotment, obligation, and disbursement records per program.',
      accent: false,
      besideSubtitle: SizedBox(width: _searchWidth, child: searchField),
      expand: true,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: filters),
            const SizedBox(width: 16),
            KeyedSubtree(key: _actionsKey, child: actions),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Panel(
            padding: 0,
            child: BudgetTable(
              records: rows,
              selectedId: selected?.id,
              total: t,
              totalLabel: program.isEmpty
                  ? 'All Programs'
                  : programLabel(program),
              onSelect: (record) => setState(
                () => selectedId = selectedId == record.id ? null : record.id,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineChoice<T> extends StatelessWidget {
  const _InlineChoice({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.width,
  });
  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  final double width;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '$label:',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: width,
        child: AppDropdown<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          fieldTextStyle: const TextStyle(
            fontFamily: 'Segoe UI',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: EdgeInsets.fromLTRB(12, 10, 0, 10),
          ),
        ),
      ),
    ],
  );
}

const _recordEditorLabelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  color: Colors.black,
);

class RecordEditor extends StatefulWidget {
  const RecordEditor({
    super.key,
    required this.store,
    this.record,
    required this.year,
    required this.program,
  });
  final FinanceStore store;
  final BudgetRecord? record;
  final int year;
  final String program;
  @override
  State<RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<RecordEditor> {
  late int year;
  late String program;
  late final TextEditingController yearField,
      code,
      name,
      allotment,
      obligation,
      disbursement,
      remarks;
  final codeFocus = FocusNode();
  final nameFocus = FocusNode();
  final allotmentFocus = FocusNode();
  final obligationFocus = FocusNode();
  final disbursementFocus = FocusNode();
  final remarksFocus = FocusNode();
  final _focused = <FocusNode>{};
  String? error;
  final _inputKey = GlobalKey();
  double? _inputHeight;
  late final ImportController _imports;
  void _onImports() {
    if (mounted) setState(() {});
  }

  void _bindFocus(FocusNode node) {
    node.addListener(() {
      if (!mounted) return;
      final on = node.hasFocus;
      final changed = on ? _focused.add(node) : _focused.remove(node);
      if (changed) setState(() {});
    });
  }

  void _matchInputHeight() {
    final height = _inputKey.currentContext?.size?.height;
    if (!mounted || height == null || height == _inputHeight) return;
    setState(() => _inputHeight = height);
  }

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    // Encoding/import is always for the current fiscal year only.
    year = manilaNow().year;
    final active = widget.store.programs
        .where((p) => p.active)
        .map((p) => p.code)
        .toList();
    program =
        r?.program ??
        (active.contains(widget.program)
            ? widget.program
            : active.firstOrNull ?? '');
    yearField = TextEditingController(text: '$year');
    code = TextEditingController(text: r?.code ?? '');
    name = TextEditingController(text: r?.name ?? '');
    allotment = TextEditingController(
      text: r == null ? '' : (r.allotment / 100).toStringAsFixed(2),
    );
    obligation = TextEditingController(
      text: r == null ? '' : (r.obligation / 100).toStringAsFixed(2),
    );
    disbursement = TextEditingController(
      text: r == null ? '' : (r.disbursement / 100).toStringAsFixed(2),
    );
    remarks = TextEditingController(text: r?.remarks ?? '');
    for (final n in [
      codeFocus,
      nameFocus,
      allotmentFocus,
      obligationFocus,
      disbursementFocus,
      remarksFocus,
    ]) {
      _bindFocus(n);
    }
    _imports = ImportController(
      widget.store,
      year: year,
      onImported: () {
        if (mounted) Navigator.pop(context);
      },
    )..addListener(_onImports);
  }

  @override
  void dispose() {
    _imports.removeListener(_onImports);
    _imports.dispose();
    for (final c in [
      yearField,
      code,
      name,
      allotment,
      obligation,
      disbursement,
      remarks,
    ]) {
      c.dispose();
    }
    for (final n in [
      codeFocus,
      nameFocus,
      allotmentFocus,
      obligationFocus,
      disbursementFocus,
      remarksFocus,
    ]) {
      n.dispose();
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
      // Empty amounts count as 0 — same as Excel lines with blank cells.
      final a = parseCents(allotment.text),
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
          fund: widget.record?.fund ?? 'CURRENT',
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
    bool readOnly = false,
    Key? boxKey,
    FocusNode? focusNode,
    String? hint,
    Widget? suffix,
    bool expand = false,
  }) {
    final box = _inputHeight;
    final focused = focusNode != null && _focused.contains(focusNode);
    final empty = c.text.isEmpty;
    // Amount sample: "₱ 0.00". On click/type, keep ₱ only.
    final showAmountSample = amount && !readOnly && empty && !focused;
    final showPesoPrefix = amount && !showAmountSample;
    final showHint =
        !readOnly &&
        empty &&
        !focused &&
        (amount ? true : hint != null);
    final input = TextField(
      key: boxKey,
      controller: c,
      focusNode: focusNode,
      readOnly: readOnly,
      enableInteractiveSelection: !readOnly,
      expands: expand,
      minLines: expand ? null : 1,
      maxLines: expand ? null : 1,
      textAlignVertical: expand
          ? TextAlignVertical.top
          : TextAlignVertical.center,
      onChanged: (_) => setState(() {}),
      keyboardType: amount
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        hintText: showHint ? (amount ? '₱  0.00' : hint) : null,
        hintStyle: const TextStyle(color: Color(0xff9aabbf), fontSize: 13),
        prefix: showPesoPrefix
            ? const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Text(
                  '₱',
                  style: TextStyle(
                    color: muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              )
            : null,
        suffixIcon: suffix,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(label, style: _recordEditorLabelStyle),
        const SizedBox(height: 4),
        if (expand)
          Expanded(child: input)
        else
          SizedBox(height: box, child: input),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _matchInputHeight());
    final a = parseCents(allotment.text) ?? 0,
        o = parseCents(obligation.text) ?? 0,
        d = parseCents(disbursement.text) ?? 0;
    final programs = widget.store.programs
        .where((p) => p.active || p.code == widget.record?.program)
        .toList();
    const gap = SizedBox(height: 14);
    Widget columnFields(List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) gap,
          children[i],
        ],
      ],
    );
    Widget metric(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: ink)),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
      ],
    );
    return PopScope(
      canPop: false,
      child: Dialog(
        key: const ValueKey('budget-record-dialog'),
        alignment: const Alignment(0.45, 0),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: ConstrainedBox(
          key: const ValueKey('budget-record-dialog-size'),
          constraints: const BoxConstraints(maxWidth: 920, minHeight: 500),
          child: SingleChildScrollView(
            key: const ValueKey('budget-record-dialog-scroll'),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      widget.record == null
                          ? 'Add Budget Record'
                          : 'Edit Budget Record',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _AlignedRecordColumns(
                  identity: columnFields([
                    field(
                      'Fiscal Year *',
                      yearField,
                      readOnly: true,
                      boxKey: _inputKey,
                    ),
                    SelectField(
                      label: 'Program *',
                      labelStyle: _recordEditorLabelStyle,
                      value: program,
                      dense: true,
                      width: double.infinity,
                      items: [
                        for (final p in programs)
                          (p.code, p.code),
                      ],
                      onChanged: (v) => setState(() => program = v),
                    ),
                    field(
                      'UACS Code *',
                      code,
                      focusNode: codeFocus,
                      hint: 'e.g. 5020101000',
                      suffix: IconButton(
                        tooltip: 'Find UACS code',
                        onPressed: lookup,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.search, size: 18),
                      ),
                    ),
                    field(
                      'Expense (UACS Name) *',
                      name,
                      focusNode: nameFocus,
                      hint: 'e.g. Traveling Expenses - Local',
                    ),
                  ]),
                  amounts: columnFields([
                    field(
                      'Allotment',
                      allotment,
                      amount: true,
                      focusNode: allotmentFocus,
                    ),
                    field(
                      'Obligation',
                      obligation,
                      amount: true,
                      focusNode: obligationFocus,
                    ),
                    field(
                      'Disbursement',
                      disbursement,
                      amount: true,
                      focusNode: disbursementFocus,
                    ),
                  ]),
                  remarks: remarks,
                  remarksFocus: remarksFocus,
                  showRemarksHint:
                      remarks.text.isEmpty &&
                      !_focused.contains(remarksFocus),
                  summary: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: const Color(0xffe7f0fb),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Calculated Values\n(Automatic)',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: blue,
                          ),
                        ),
                        const SizedBox(height: 14),
                        metric('Obligation Rate', rate(o, a)),
                        const SizedBox(height: 12),
                        metric('Balance', money(a - o)),
                        const SizedBox(height: 12),
                        metric('Disbursement Rate', rate(d, o)),
                      ],
                    ),
                  ),
                  importZone: ExcelDropZone(session: _imports),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(error!, style: const TextStyle(color: red)),
                  ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: program.isEmpty ? null : save,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlignedRecordColumns extends StatefulWidget {
  const _AlignedRecordColumns({
    required this.identity,
    required this.amounts,
    required this.remarks,
    required this.remarksFocus,
    required this.showRemarksHint,
    required this.summary,
    required this.importZone,
  });
  final Widget identity, amounts, summary, importZone;
  final TextEditingController remarks;
  final FocusNode remarksFocus;
  final bool showRemarksHint;
  @override
  State<_AlignedRecordColumns> createState() => _AlignedRecordColumnsState();
}

class _AlignedRecordColumnsState extends State<_AlignedRecordColumns> {
  final _importKey = GlobalKey();
  final _amountsKey = GlobalKey();
  final _summaryKey = GlobalKey();
  final _labelKey = GlobalKey();
  double _inputHeight = 160;
  double _topPad = 0;

  void _sync() {
    if (!mounted) return;
    final importHeight = _importKey.currentContext?.size?.height;
    final amountsHeight = _amountsKey.currentContext?.size?.height;
    final summaryHeight = _summaryKey.currentContext?.size?.height;
    final labelHeight = _labelKey.currentContext?.size?.height;
    if (importHeight == null ||
        amountsHeight == null ||
        summaryHeight == null ||
        labelHeight == null) {
      return;
    }
    // Align Remarks input top with Import top; same height as Import box.
    final remarksChrome = 14.0 + labelHeight + 4.0;
    final targetTop = summaryHeight + 12;
    final currentTop = amountsHeight + remarksChrome;
    final topPad = (targetTop - currentTop).clamp(0.0, 400.0);
    if ((importHeight - _inputHeight).abs() > 0.5 ||
        (topPad - _topPad).abs() > 0.5) {
      setState(() {
        _inputHeight = importHeight;
        _topPad = topPad;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: widget.identity),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KeyedSubtree(key: _amountsKey, child: widget.amounts),
              if (_topPad > 0) SizedBox(height: _topPad),
              const SizedBox(height: 14),
              KeyedSubtree(
                key: _labelKey,
                child: const FieldLabel(
                  'Remarks',
                  style: _recordEditorLabelStyle,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: _inputHeight,
                child: TextField(
                  controller: widget.remarks,
                  focusNode: widget.remarksFocus,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    hintText: widget.showRemarksHint
                        ? 'e.g. Supporting notes or reference'
                        : null,
                    hintStyle: const TextStyle(
                      color: Color(0xff9aabbf),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KeyedSubtree(key: _summaryKey, child: widget.summary),
              const SizedBox(height: 12),
              KeyedSubtree(key: _importKey, child: widget.importZone),
            ],
          ),
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
