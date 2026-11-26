import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../data/finance_store.dart';
import '../data/models.dart';
import '../ui/common.dart';
import '../ui/app_icon.dart';
import '../ui/theme.dart';
import 'import_page.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key, required this.store});
  final FinanceStore store;
  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  int year = manilaNow().year;
  String program = '', query = '';

  void change(VoidCallback fn) => setState(fn);
  Future<void> edit([BudgetRecord? record]) async {
    if (year != manilaNow().year ||
        (record != null && record.year != manilaNow().year)) {
      return;
    }
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
    if (year != manilaNow().year || record.year != manilaNow().year) return;
    if (!await confirm(
      context,
      'Delete budget record?',
      'Are you sure to delete this record?',
    )) {
      return;
    }
    try {
      widget.store.deleteRecord(record.id!);
      if (mounted) {
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
        prefixIcon: AppIcon('search', size: 22),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
    const actionWidth = 320.0;
    final actions = SizedBox(
      width: actionWidth,
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onPressed: canEncode ? () => edit() : null,
              icon: const AppIcon('plus', size: 18),
              label: const Text('Add Record'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              key: const ValueKey('budget-import'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff217346),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onPressed: canEncode ? () {
                if (year != manilaNow().year) return;
                showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => ExcelImportDialog(store: widget.store, year: year),
                );
              } : null,
              icon: const AppIcon('upload', size: 18),
              label: const Text('Import'),
            ),
          ),
        ],
      ),
    );
    return PageFrame(
      title: 'Budget Utilization',
      subtitle:
          'Manage allotment, obligation, and disbursement records per program.',
      accent: false,
      besideSubtitle: SizedBox(width: actionWidth, child: searchField),
      expand: true,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: filters),
            const SizedBox(width: 16),
            actions,
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Panel(
            padding: 0,
            child: BudgetTable(
              records: rows,
              total: t,
              totalLabel: program.isEmpty
                  ? 'All Programs'
                  : programLabel(program),
              showActions: true,
              actionsEnabled: canEncode,
              onEdit: (record) => edit(record),
              onDelete: (record) => remove(record),
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
  }

  @override
  void dispose() {
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
        alignment: Alignment.center,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: ConstrainedBox(
          key: const ValueKey('budget-record-dialog-size'),
          constraints: const BoxConstraints(maxWidth: 660, minHeight: 500),
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
                        icon: const AppIcon('x'),
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
                            child: AppIcon(
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
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
  });
  final Widget identity, amounts, summary;
  final TextEditingController remarks;
  final FocusNode remarksFocus;
  final bool showRemarksHint;
  @override
  State<_AlignedRecordColumns> createState() => _AlignedRecordColumnsState();
}

class _AlignedRecordColumnsState extends State<_AlignedRecordColumns> {
  final _leftKey = GlobalKey();
  final _remarksLabelKey = GlobalKey();
  double _leftHeight = 450;
  double _labelHeight = 16;

  void _syncHeight() {
    if (!mounted) return;
    final left = _leftKey.currentContext?.size?.height;
    final label = _remarksLabelKey.currentContext?.size?.height;
    if (left == null || label == null) return;
    if ((left - _leftHeight).abs() > .5 ||
        (label - _labelHeight).abs() > .5) {
      setState(() {
        _leftHeight = left;
        _labelHeight = label;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncHeight());
    final available = (_leftHeight - _labelHeight - 18).clamp(410.0, double.infinity).toDouble();
    final summaryHeight = (available * .57).clamp(255.0, available - 150).toDouble();
    final remarksHeight = available - summaryHeight;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            key: _leftKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              widget.identity,
              const SizedBox(height: 14),
              widget.amounts,
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KeyedSubtree(
                key: _remarksLabelKey,
                child: const FieldLabel('Remarks', style: _recordEditorLabelStyle),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: remarksHeight,
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
              const SizedBox(height: 14),
              SizedBox(height: summaryHeight, child: widget.summary),
            ],
          ),
        ),
      ],
    );
  }
}
