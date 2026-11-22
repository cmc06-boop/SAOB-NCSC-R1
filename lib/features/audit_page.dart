import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../data/finance_store.dart';
import '../data/models.dart';
import '../ui/common.dart';
import '../ui/theme.dart';

class AuditPage extends StatefulWidget {
  const AuditPage({super.key, required this.store});
  final FinanceStore store;
  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage> {
  int year = manilaNow().year;
  String program = '', action = '';
  void change(VoidCallback fn) => setState(fn);

  @override
  Widget build(BuildContext context) {
    if (program.isNotEmpty &&
        !widget.store.programs.any((p) => p.code == program)) {
      program = '';
    }
    final rows = widget.store.auditRows(year, program: program, action: action);
    const title = Text(
      'Audit Trail',
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1,
      ),
    );
    const subtitle = Text(
      'Record of changes made to budget records and reference data.',
      style: TextStyle(fontSize: 14, color: muted, height: 1.35),
    );
    final filters = Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _AuditFilter<int>(
          label: 'Fiscal Year',
          value: year,
          fieldWidth: 112,
          items: [for (final y in widget.store.years) (y, '$y')],
          onChanged: (v) => change(() => year = v),
        ),
        _AuditFilter<String>(
          label: 'Program',
          value: program,
          fieldWidth: 146,
          items: [
            ('', 'All Programs'),
            for (final p in widget.store.programs)
              (p.code, programLabel(p.code, p.name)),
          ],
          onChanged: (v) => change(() => program = v),
        ),
        _AuditFilter<String>(
          label: 'Action',
          value: action,
          fieldWidth: 150,
          items: const [
            ('', 'All Actions'),
            ('Added', 'Added'),
            ('Updated', 'Updated'),
            ('Imported', 'Imported'),
            ('Generated', 'Generated'),
            ('Deleted', 'Deleted'),
          ],
          onChanged: (v) => change(() => action = v),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 8),
          subtitle,
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight, child: filters),
          const SizedBox(height: 22),
          Expanded(
            child: Panel(padding: 0, child: _AuditTable(rows: rows)),
          ),
        ],
      ),
    );
  }
}

class _AuditTable extends StatefulWidget {
  const _AuditTable({required this.rows});
  final List<DbRow> rows;
  @override
  State<_AuditTable> createState() => _AuditTableState();
}

class _AuditTableState extends State<_AuditTable> {
  final _scroll = ScrollController();
  static const _border = BorderSide(color: Color(0xffd5e1f2));
  static const _columns = <int, TableColumnWidth>{
    0: FixedColumnWidth(188),
    1: FixedColumnWidth(140),
    2: FlexColumnWidth(),
  };

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

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
    const header = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: navy,
    );
    const body = TextStyle(fontSize: 13, color: ink);
    final rows = widget.rows;
    final headerTable = Table(
      border: const TableBorder(verticalInside: _border, bottom: _border),
      columnWidths: _columns,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _row([
          const _AuditCell('Date & Time', style: header),
          const _AuditCell('Action', style: header),
          const _AuditCell('Details', style: header),
        ], const Color(0xffeef3fb)),
      ],
    );
    final bodyTable = Table(
      border: const TableBorder(
        horizontalInside: _border,
        verticalInside: _border,
      ),
      columnWidths: _columns,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        if (rows.isEmpty)
          _row([
            const _AuditCell(''),
            const _AuditCell(''),
            const _AuditCell(
              'No records found.',
              style: TextStyle(fontSize: 13, color: muted),
            ),
          ], Colors.white)
        else
          for (final (i, r) in rows.indexed)
            _row([
              _AuditCell(dateLabel(r['at']), style: body),
              _AuditCell('${r['action']}', style: body),
              _AuditCell(
                '${r['title']} · ${r['detail']}',
                style: body,
                tip: true,
              ),
            ], i.isOdd ? const Color(0xfff7f9fc) : Colors.white),
      ],
    );
    return Column(
      children: [
        headerTable,
        Expanded(
          child: Scrollbar(
            controller: _scroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scroll,
              child: bodyTable,
            ),
          ),
        ),
      ],
    );
  }
}

class _AuditCell extends StatelessWidget {
  const _AuditCell(this.text, {this.style, this.tip = false});
  final String text;
  final TextStyle? style;
  final bool tip;
  @override
  Widget build(BuildContext context) {
    final label = Text(text, softWrap: true, style: style);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: tip && text.isNotEmpty
          ? Tooltip(message: text, child: label)
          : label,
    );
  }
}

class _AuditFilter<T> extends StatelessWidget {
  const _AuditFilter({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.fieldWidth,
  });
  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  final double fieldWidth;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '$label:',
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: muted,
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: fieldWidth,
        child: InputDecorator(
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: EdgeInsets.fromLTRB(12, 11, 0, 11),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              isDense: true,
              padding: const EdgeInsets.only(right: 2),
              value: items.any((e) => e.$1 == value) ? value : null,
              style: const TextStyle(
                fontFamily: 'Segoe UI',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
              items: [
                for (final e in items)
                  DropdownMenuItem<T>(
                    value: e.$1,
                    child: Text(
                      e.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ),
    ],
  );
}
