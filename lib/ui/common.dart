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
  });
  final String title, subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(26),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 5),
        Text(subtitle, style: const TextStyle(color: muted)),
        const SizedBox(height: 24),
        ...children,
      ],
    ),
  );
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = 20});
  final Widget child;
  final double padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: line),
    ),
    child: child,
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
  });
  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T>? onChanged;
  final double width;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: muted,
          ),
        ),
        const SizedBox(height: 7),
        InputDecorator(
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              value: items.any((e) => e.$1 == value) ? value : null,
              style: const TextStyle(
                fontFamily: 'Segoe UI',
                fontSize: 13,
                color: ink,
              ),
              items: items
                  .map(
                    (e) => DropdownMenuItem<T>(
                      value: e.$1,
                      child: Tooltip(
                        message: e.$2,
                        child: Text(
                          e.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged == null
                  ? null
                  : (v) {
                      if (v != null) onChanged!(v);
                    },
            ),
          ),
        ),
      ],
    ),
  );
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
          const Icon(Icons.folder_open_outlined, size: 42, color: muted),
          const SizedBox(height: 12),
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
  });
  final List<String> columns;
  final List<List<Widget>> rows;
  final Set<int> numeric;
  final String empty;
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
                columns: [
                  for (var i = 0; i < widget.columns.length; i++)
                    DataColumn(
                      label: Text(widget.columns[i]),
                      numeric: widget.numeric.contains(i),
                    ),
                ],
                rows: [
                  for (final row in widget.rows)
                    DataRow(cells: row.map(DataCell.new).toList()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BudgetTable extends StatelessWidget {
  const BudgetTable({
    super.key,
    required this.records,
    this.onEdit,
    this.onDelete,
  });
  final List<BudgetRecord> records;
  final ValueChanged<BudgetRecord>? onEdit, onDelete;
  @override
  Widget build(BuildContext context) => WideTable(
    columns: [
      'Program',
      'Fund',
      'UACS Code',
      'Expense (UACS Name)',
      'Allotment',
      'Obligation',
      'Obligation Rate',
      'Balance',
      'Disbursement',
      'Disbursement Rate',
      'Remarks',
      if (onEdit != null) 'Actions',
    ],
    numeric: const {4, 5, 6, 7, 8, 9},
    rows: [
      for (final r in records)
        [
          tableText(r.program),
          tableText(r.fund),
          tableText(displayCode(r.code)),
          tableText(r.name, width: 250),
          Text(money(r.allotment)),
          Text(money(r.obligation)),
          Text(rate(r.obligation, r.allotment)),
          Text(money(r.balance)),
          Text(money(r.disbursement)),
          Text(rate(r.disbursement, r.obligation)),
          tableText(r.remarks),
          if (onEdit != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit record',
                  onPressed: () => onEdit!(r),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
                IconButton(
                  tooltip: 'Delete record',
                  onPressed: () => onDelete!(r),
                  icon: const Icon(Icons.delete_outline, color: red, size: 18),
                ),
              ],
            ),
        ],
    ],
  );
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
