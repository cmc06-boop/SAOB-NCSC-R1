import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../data/models.dart';
import 'theme.dart';

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.accent = true,
    this.besideSubtitle,
    this.expand = false,
  });
  final String title, subtitle;
  final List<Widget> children;
  final bool accent;
  final Widget? besideSubtitle;
  final bool expand;
  @override
  Widget build(BuildContext context) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        if (accent) ...[
          const SizedBox(height: 8),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: red,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 10),
        ] else
          const SizedBox(height: 1),
        if (besideSubtitle == null)
          Text(subtitle, style: const TextStyle(color: muted, height: 1.35))
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  subtitle,
                  style: const TextStyle(color: muted, height: 1.35),
                ),
              ),
              const SizedBox(width: 16),
              besideSubtitle!,
            ],
          ),
        SizedBox(height: besideSubtitle == null ? 22 : 14),
        ...children,
      ],
    );
    if (expand)
      return Padding(padding: const EdgeInsets.all(26), child: column);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(26),
      child: column,
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = 20});
  final Widget child;
  final double padding;
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: line),
      boxShadow: cardShadow,
    ),
    child: Material(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: child,
    ),
  );
}

class SelectField<T> extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width = 180,
    this.dense = false,
    this.boxKey,
    this.labelStyle,
  });
  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T>? onChanged;
  final double width;
  final bool dense;
  final Key? boxKey;
  final TextStyle? labelStyle;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(label, style: labelStyle),
        SizedBox(height: dense ? 4 : 7),
        AppDropdown<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          dense: dense,
          decoratorKey: boxKey,
          fieldTextStyle: const TextStyle(
            fontFamily: 'Segoe UI',
            fontSize: 13,
            color: ink,
          ),
          decoration: InputDecoration(
            isDense: dense,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: dense ? 12 : 3,
            ),
          ),
        ),
      ],
    ),
  );
}

/// A compact, anchored select field: options open below the field rather
/// than covering the selected value. Used by filters and record editors.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.decoration,
    this.decoratorKey,
    this.dense = true,
    this.fieldTextStyle = const TextStyle(
      fontFamily: 'Segoe UI',
      fontSize: 13,
      color: ink,
    ),
  });

  final T value;
  final List<(T, String)> items;
  final ValueChanged<T>? onChanged;
  final InputDecoration decoration;
  final Key? decoratorKey;
  final bool dense;
  final TextStyle fieldTextStyle;

  @override
  Widget build(BuildContext context) {
    var selectedLabel = '';
    var longestLabel = 0;
    for (final option in items) {
      if (option.$1 == value) selectedLabel = option.$2;
      longestLabel = math.max(longestLabel, option.$2.length);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final fieldWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 180.0;
        // Wider menus let long UACS names wrap instead of being cut off.
        final menuWidth = math.max(
          fieldWidth,
          math.min(380.0, longestLabel * 6.5 + 48.0),
        );
        final menuHeight = math.min(
          320.0,
          MediaQuery.sizeOf(context).height * 0.6,
        );

        return PopupMenuButton<T>(
          enabled: onChanged != null && items.isNotEmpty,
          tooltip: 'Choose an option',
          position: PopupMenuPosition.under,
          offset: const Offset(0, 5),
          color: Colors.white,
          elevation: 6,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            side: BorderSide(color: line),
          ),
          constraints: BoxConstraints(
            minWidth: fieldWidth,
            maxWidth: menuWidth,
            maxHeight: menuHeight,
          ),
          onSelected: onChanged,
          itemBuilder: (context) => [
            for (final option in items)
              PopupMenuItem<T>(
                value: option.$1,
                child: Tooltip(
                  message: option.$2,
                  child: Text(
                    option.$2,
                    softWrap: true,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Segoe UI',
                      fontSize: 13,
                      height: 1.25,
                      color: ink,
                    ),
                  ),
                ),
              ),
          ],
          child: InputDecorator(
            key: decoratorKey,
            decoration: decoration,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: dense ? 24 : 44),
              child: Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: selectedLabel,
                      child: Text(
                        selectedLabel.isEmpty ? 'Select…' : selectedLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: fieldTextStyle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.label, {super.key, this.style});
  final String label;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) {
    final textStyle = style ?? const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: muted,
    );
    if (!label.endsWith(' *')) return Text(label, style: textStyle);
    return Text.rich(
      TextSpan(
        style: textStyle,
        children: [
          TextSpan(text: label.substring(0, label.length - 1)),
          const TextSpan(
            text: '*',
            style: TextStyle(color: red, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class SearchBox extends StatelessWidget {
  const SearchBox({
    super.key,
    required this.onChanged,
    this.hint = 'Search UACS Code or Expense…',
  });
  final ValueChanged<String> onChanged;
  final String hint;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 320,
    child: TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, size: 20),
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.text, this.detail = ''});
  final String text, detail;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xffe8eef8),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.folder_open_outlined,
              size: 30,
              color: blue,
            ),
          ),
          const SizedBox(height: 14),
          Text(text, style: Theme.of(context).textTheme.titleMedium),
          if (detail.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(detail, style: const TextStyle(color: muted)),
            ),
        ],
      ),
    ),
  );
}

Widget tableText(Object? value, {double width = 200}) => Tooltip(
  message: (value ?? '').toString(),
  child: ConstrainedBox(
    constraints: BoxConstraints(maxWidth: width),
    child: Text(
      (value ?? '').toString(),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
  ),
);

class WideTable extends StatefulWidget {
  const WideTable({
    super.key,
    required this.columns,
    required this.rows,
    this.numeric = const {},
    this.empty = 'No records found.',
    this.selected = const {},
    this.onSelect,
  });
  final List<String> columns;
  final List<List<Widget>> rows;
  final Set<int> numeric;
  final String empty;
  final Set<int> selected;
  final ValueChanged<int>? onSelect;
  @override
  State<WideTable> createState() => _WideTableState();
}

class _WideTableState extends State<WideTable> {
  final controller = ScrollController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) return EmptyState(text: widget.empty);
    return LayoutBuilder(
      builder: (context, c) => Scrollbar(
        controller: controller,
        thumbVisibility: true,
        notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            controller: controller,
            primary: false,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: c.maxWidth),
              child: DataTable(
                showCheckboxColumn: false,
                columns: [
                  for (var i = 0; i < widget.columns.length; i++)
                    DataColumn(
                      label: Text(widget.columns[i]),
                      numeric: widget.numeric.contains(i),
                    ),
                ],
                rows: [
                  for (var i = 0; i < widget.rows.length; i++)
                    DataRow(
                      selected: widget.selected.contains(i),
                      onSelectChanged: widget.onSelect == null
                          ? null
                          : (_) => widget.onSelect!(i),
                      cells: widget.rows[i].map(DataCell.new).toList(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BudgetTable extends StatefulWidget {
  const BudgetTable({
    super.key,
    required this.records,
    this.startIndex = 0,
    this.selectedId,
    this.onSelect,
    this.total,
    this.totalLabel = '',
  });
  final List<BudgetRecord> records;
  final int startIndex;
  final int? selectedId;
  final ValueChanged<BudgetRecord>? onSelect;
  final Totals? total;
  final String totalLabel;
  @override
  State<BudgetTable> createState() => _BudgetTableState();
}

class _BudgetTableState extends State<BudgetTable> {
  final _scroll = ScrollController();
  final _horizontal = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  static const _border = BorderSide(color: Color(0xffd5e1f2));
  static const _pad = 24.0;

  double _textWidth(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  /// Grow each column to fit the widest header/body/total cell on this page.
  List<double> _measuredWidths(
    List<BudgetRecord> records,
    Totals? total,
    TextStyle measure,
  ) {
    final samples = <List<String>>[
      ['#', for (var i = 0; i < records.length; i++) '${widget.startIndex + i + 1}'],
      [
        'UACS Code',
        for (final r in records) displayCode(r.code),
      ],
      [
        'Expense (UACS Name)',
        for (final r in records) r.name,
        if (total != null) 'Program Total (${widget.totalLabel})',
      ],
      [
        'Allotment',
        for (final r in records) money(r.allotment),
        if (total != null) money(total.allotment),
      ],
      [
        'Obligation',
        for (final r in records) money(r.obligation),
        if (total != null) money(total.obligation),
      ],
      [
        'Obligation Rate',
        for (final r in records) rate(r.obligation, r.allotment),
        if (total != null) rate(total.obligation, total.allotment),
      ],
      [
        'Balance',
        for (final r in records) money(r.balance),
        if (total != null) money(total.balance),
      ],
      [
        'Disbursement',
        for (final r in records) money(r.disbursement),
        if (total != null) money(total.disbursement),
      ],
      [
        'Disbursement Rate',
        for (final r in records) rate(r.disbursement, r.obligation),
        if (total != null) rate(total.disbursement, total.obligation),
      ],
      [
        'Remarks',
        for (final r in records) r.remarks,
      ],
    ];
    const mins = [
      48.0,
      110.0,
      180.0,
      120.0,
      120.0,
      130.0,
      120.0,
      130.0,
      150.0,
      160.0,
    ];
    const caps = [
      56.0,
      160.0,
      420.0,
      280.0,
      280.0,
      170.0,
      280.0,
      280.0,
      180.0,
      360.0,
    ];
    return [
      for (var i = 0; i < samples.length; i++)
        () {
          var maxWidth = 0.0;
          for (final text in samples[i]) {
            if (text.isEmpty) continue;
            maxWidth = math.max(maxWidth, _textWidth(text, measure));
          }
          return math.max(mins[i], math.min(maxWidth + _pad, caps[i]));
        }(),
    ];
  }

  TableRow _row(List<Widget> cells, Color color, [VoidCallback? onTap]) =>
      TableRow(
        decoration: BoxDecoration(color: color),
        children: [
          for (final cell in cells)
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: cell,
              ),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final records = widget.records;
    final total = widget.total;
    const header = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: navy,
    );
    const body = TextStyle(fontSize: 13, color: ink);
    const amount = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: ink,
    );
    const totalStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w800,
      color: navy,
    );
    final measured = _measuredWidths(records, total, totalStyle);
    final contentWidth = measured.fold<double>(0, (sum, width) => sum + width);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(constraints.maxWidth, contentWidth);
        final widths = List<double>.from(measured);
        if (width > contentWidth + 1) {
          final extra = width - contentWidth;
          widths[2] += extra * 0.6;
          widths[9] += extra * 0.4;
        }
        final columns = <int, TableColumnWidth>{
          for (var i = 0; i < widths.length; i++) i: FixedColumnWidth(widths[i]),
        };
        final headerTable = Table(
          border: const TableBorder(verticalInside: _border, bottom: _border),
          columnWidths: columns,
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            _row([
              _BudgetCell('#', style: header),
              _BudgetCell('UACS Code', style: header),
              _BudgetCell('Expense (UACS Name)', style: header),
              _BudgetCell('Allotment', align: TextAlign.right, style: header),
              _BudgetCell('Obligation', align: TextAlign.right, style: header),
              _BudgetCell(
                'Obligation Rate',
                align: TextAlign.right,
                style: header,
              ),
              _BudgetCell('Balance', align: TextAlign.right, style: header),
              _BudgetCell(
                'Disbursement',
                align: TextAlign.right,
                style: header,
              ),
              _BudgetCell(
                'Disbursement Rate',
                align: TextAlign.right,
                style: header,
              ),
              _BudgetCell('Remarks', style: header),
            ], const Color(0xffeef3fb)),
          ],
        );
        final bodyTable = Table(
          border: const TableBorder(
            horizontalInside: _border,
            verticalInside: _border,
          ),
          columnWidths: columns,
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            if (records.isEmpty)
              _row([
                for (var i = 0; i < 10; i++)
                  i == 2
                      ? const _BudgetCell(
                          'No records found.',
                          style: TextStyle(fontSize: 13, color: muted),
                        )
                      : const _BudgetCell(''),
              ], Colors.white),
            for (final (i, r) in records.indexed)
              _row(
                [
                  _BudgetCell(
                    '${widget.startIndex + i + 1}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: blue,
                    ),
                  ),
                  _BudgetCell(displayCode(r.code), style: body, tip: true),
                  _BudgetCell(r.name, style: body, tip: true),
                  _BudgetCell(
                    money(r.allotment),
                    align: TextAlign.right,
                    style: amount,
                  ),
                  _BudgetCell(
                    money(r.obligation),
                    align: TextAlign.right,
                    style: amount,
                  ),
                  _BudgetCell(
                    rate(r.obligation, r.allotment),
                    align: TextAlign.right,
                    style: body,
                  ),
                  _BudgetCell(
                    money(r.balance),
                    align: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: navy,
                    ),
                  ),
                  _BudgetCell(
                    money(r.disbursement),
                    align: TextAlign.right,
                    style: amount,
                  ),
                  _BudgetCell(
                    rate(r.disbursement, r.obligation),
                    align: TextAlign.right,
                    style: body,
                  ),
                  _BudgetCell(r.remarks, style: body, tip: true),
                ],
                r.id == widget.selectedId
                    ? const Color(0xffe4edfb)
                    : i.isOdd
                    ? const Color(0xfff7f9fc)
                    : Colors.white,
                widget.onSelect == null ? null : () => widget.onSelect!(r),
              ),
            if (total != null)
              _row([
                const _BudgetCell(''),
                const _BudgetCell(''),
                _BudgetCell(
                  'Program Total (${widget.totalLabel})',
                  style: totalStyle,
                  tip: true,
                ),
                _BudgetCell(
                  money(total.allotment),
                  align: TextAlign.right,
                  style: totalStyle,
                ),
                _BudgetCell(
                  money(total.obligation),
                  align: TextAlign.right,
                  style: totalStyle,
                ),
                _BudgetCell(
                  rate(total.obligation, total.allotment),
                  align: TextAlign.right,
                  style: totalStyle,
                ),
                _BudgetCell(
                  money(total.balance),
                  align: TextAlign.right,
                  style: totalStyle,
                ),
                _BudgetCell(
                  money(total.disbursement),
                  align: TextAlign.right,
                  style: totalStyle,
                ),
                _BudgetCell(
                  rate(total.disbursement, total.obligation),
                  align: TextAlign.right,
                  style: totalStyle,
                ),
                const _BudgetCell(''),
              ], const Color(0xffe7eefc)),
          ],
        );
        return Scrollbar(
          controller: _scroll,
          thumbVisibility: true,
          notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
          child: Scrollbar(
            controller: _horizontal,
            thumbVisibility: width > constraints.maxWidth + 1,
            notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: Column(
                  children: [
                    headerTable,
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scroll,
                        child: bodyTable,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BudgetCell extends StatelessWidget {
  const _BudgetCell(
    this.text, {
    this.align = TextAlign.left,
    this.style,
    this.tip = false,
  });
  final String text;
  final TextAlign align;
  final TextStyle? style;
  final bool tip;
  @override
  Widget build(BuildContext context) {
    final label = Text(text, textAlign: align, softWrap: true, style: style);
    return Padding(
      padding: EdgeInsets.only(
        left: align == TextAlign.right ? 8 : 12,
        right: align == TextAlign.right ? 12 : 8,
        top: 8,
        bottom: 8,
      ),
      child: tip && text.isNotEmpty
          ? Tooltip(message: text, child: label)
          : label,
    );
  }
}

class Pager extends StatelessWidget {
  const Pager({
    super.key,
    required this.page,
    required this.count,
    required this.pageSize,
    required this.onChanged,
  });
  final int page, count, pageSize;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final maxPage = math.max(1, (count / pageSize).ceil());
    final p = page.clamp(1, maxPage),
        first = count == 0 ? 0 : (p - 1) * pageSize + 1;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Showing $first–${math.min(p * pageSize, count)} of $count',
              style: const TextStyle(fontSize: 12, color: muted),
            ),
          ),
          IconButton(
            tooltip: 'Previous page',
            onPressed: p > 1 ? () => onChanged(p - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('$p / $maxPage'),
          IconButton(
            tooltip: 'Next page',
            onPressed: p < maxPage ? () => onChanged(p + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

void showMessage(BuildContext context, String message, {bool error = false}) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? red : navy,
        behavior: SnackBarBehavior.floating,
      ),
    );

String friendlyError(Object error) => error is FinanceError
    ? error.message
    : 'The operation could not be completed. Close any other copy of the app and try again.';

Future<bool> confirm(BuildContext context, String title, String detail) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;
