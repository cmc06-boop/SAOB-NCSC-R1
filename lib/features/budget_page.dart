import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../data/finance_store.dart';
import '../data/models.dart';
import '../ui/common.dart';
import '../ui/svg_icon.dart';
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
        prefixIcon: AppSvgIcon('search', size: 20),
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
          icon: const AppSvgIcon('plus', size: 18),
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
          icon: const AppSvgIcon('pencil', size: 18),
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
          icon: const AppSvgIcon('trash-2', size: 18),
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
  final _fieldErrors = <TextEditingController, String>{};

  void _invalidInput(TextEditingController controller, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _fieldErrors[controller] = message;
        error = null;
      });
    });
  }

  bool get _duplicateUacs {
    final uacs = codeKey(code.text);
    if (!RegExp(r'^\d{8,14}$').hasMatch(uacs) || program.isEmpty) {
      return false;
    }
    final fund = widget.record?.fund ?? 'CURRENT';
    return widget.store.records(year, program: program, item: uacs).any(
      (record) => record.fund == fund && record.id != widget.record?.id,
    );
  }

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

  void save() {
    final validation = <TextEditingController, String>{};
    if (!RegExp(r'^\d{8,14}$').hasMatch(codeKey(code.text))) {
      validation[code] = 'UACS Code must contain 8–14 digits.';
    }
    if (_duplicateUacs) {
      validation[code] =
          'This UACS Code already exists for the selected year, program and fund.';
    }
    if (name.text.trim().isEmpty) {
      validation[name] = 'Expense name is required.';
    }
    for (final entry in <(TextEditingController, String)>[
      (allotment, 'Allotment'),
      (obligation, 'Obligation'),
      (disbursement, 'Disbursement'),
    ]) {
      if (parseCents(entry.$1.text) == null) {
        validation[entry.$1] =
            '${entry.$2} must be a non-negative number with up to 2 decimals.';
      }
    }
    if (validation.isNotEmpty) {
      setState(() {
        _fieldErrors
          ..clear()
          ..addAll(validation);
        error = 'Please correct the highlighted fields.';
      });
      return;
    }
    try {
      // Empty amounts count as 0 — same as Excel lines with blank cells.
      final a = parseCents(allotment.text)!,
          o = parseCents(obligation.text)!,
          d = parseCents(disbursement.text)!;
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
      final message = friendlyError(e);
      setState(() {
        if (message.contains('UACS code already exists')) {
          _fieldErrors[code] = message;
          error = null;
        } else {
          error = message;
        }
      });
    }
  }

  Widget field(
    String label,
    TextEditingController c, {
    bool amount = false,
    bool digitsOnly = false,
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
    final fieldError = identical(c, code) && _duplicateUacs
        ? 'This UACS Code already exists for the selected year, program and fund.'
        : _fieldErrors[c];
    // Advisory only: some valid source records can exceed the recorded
    // allotment. Never prevent saving solely because of this difference.
    final enteredAllotment = parseCents(allotment.text);
    final enteredObligation = parseCents(obligation.text);
    final excessObligation = identical(c, obligation) &&
            allotment.text.trim().isNotEmpty &&
            obligation.text.trim().isNotEmpty &&
            enteredAllotment != null &&
            enteredObligation != null &&
            enteredObligation > enteredAllotment
        ? enteredObligation - enteredAllotment
        : null;
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
      onChanged: (_) => setState(() {
        _fieldErrors.remove(c);
        error = null;
      }),
      inputFormatters: [
        if (amount || digitsOnly)
          TextInputFormatter.withFunction((oldValue, newValue) {
            final valid = amount
                ? RegExp(r'^\d{0,13}(?:\.\d{0,2})?$')
                    .hasMatch(newValue.text)
                : RegExp(r'^\d{0,14}$').hasMatch(newValue.text);
            if (valid) return newValue;
            _invalidInput(
              c,
              amount
                  ? 'Numbers only, with up to 2 decimal places (no negatives).'
                  : 'Digits only, maximum 14 for UACS Code.',
            );
            return oldValue;
          }),
      ],
      keyboardType: amount
          ? const TextInputType.numberWithOptions(decimal: true)
          : digitsOnly
              ? TextInputType.number
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
          minWidth: 36,
          minHeight: 24,
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
        if (fieldError != null) ...[
          const SizedBox(height: 4),
          Text(
            fieldError,
            style: const TextStyle(color: red, fontSize: 12),
          ),
        ],
        if (excessObligation != null) ...[
          const SizedBox(height: 4),
          Text(
            'Obligation exceeds the recorded allotment by ${money(excessObligation)}. Please verify the amounts.',
            style: const TextStyle(
              color: Color(0xffb45309),
              fontSize: 12,
            ),
          ),
        ],
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
    final uacsReferences = widget.store.references();
    final availableUacs = <String, String>{
      for (final ref in uacsReferences)
        ref['code'] as String: ref['name'] as String,
    };
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
                        icon: const AppSvgIcon('x'),
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
                      arrowRightPadding: 0,
                      arrowShiftRight: 9,
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
                      digitsOnly: true,
                      focusNode: codeFocus,
                      hint: 'e.g. 5020101000',
                      suffix: PopupMenuButton<String>(
                        tooltip: 'Choose an existing UACS Code',
                        position: PopupMenuPosition.under,
                        constraints: const BoxConstraints(
                          minWidth: 320,
                          maxWidth: 440,
                          maxHeight: 320,
                        ),
                        onSelected: (selected) => setState(() {
                          code.text = selected;
                          name.text = availableUacs[selected]!;
                          _fieldErrors.remove(code);
                          _fieldErrors.remove(name);
                          error = null;
                        }),
                        itemBuilder: (context) => [
                          if (availableUacs.isEmpty)
                            const PopupMenuItem<String>(
                              enabled: false,
                              child: Text('No existing UACS Codes'),
                            ),
                          for (final ref in availableUacs.entries)
                            PopupMenuItem<String>(
                              value: ref.key,
                              child: Text(
                                '${displayCode(ref.key)} - ${ref.value}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        child: const SizedBox(
                          width: 36,
                          height: 24,
                          child: Center(
                            child: AppSvgIcon(
                              'chevron-down',
                              size: 18,
                              color: muted,
                            ),
                          ),
                        ),
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
