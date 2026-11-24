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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => program = '');
      });
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
              (p.code, p.code),
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
          LayoutBuilder(
            builder: (context, constraints) {
              // Keep filters beside the subtitle when there's enough room.
              // Compact layouts wrap the controls to prevent horizontal overflow.
              if (constraints.maxWidth < 980) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    subtitle,
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: filters,
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: subtitle),
                  const SizedBox(width: 16),
                  filters,
                ],
              );
            },
          ),
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
    1: FixedColumnWidth(112),
    2: FixedColumnWidth(168),
    3: FlexColumnWidth(),
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
          const _AuditCell('Date', style: header),
          const _AuditCell('Time', style: header),
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
            const _AuditCell(''),
            const _AuditCell(
              'No records found.',
              style: TextStyle(fontSize: 13, color: muted),
            ),
          ], Colors.white)
        else
          for (final (i, r) in rows.indexed)
            _row([
              _AuditCell(dateOnly(r['at']), style: body),
              _AuditCell(timeOnly(r['at']), style: body),
              _AuditCell('${r['action']}', style: body),
              _AuditCell(
                _auditDetailText(
                  '${r['detail'] ?? ''}',
                  action: '${r['action'] ?? ''}',
                ),
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

/// Display-only cleanup for older audit rows. New rows already store short details.
String _auditDetailText(String raw, {String action = ''}) {
  var text = raw.trim();
  if (text.isEmpty) return '';

  // Filename only (current import format), or extract from older long import text.
  final fileOnly = RegExp(r'^([^\\/:*?"<>|]+\.xlsx)$', caseSensitive: false);
  if (fileOnly.hasMatch(text)) return text;
  final fileInText = RegExp(
    r'([^\\/:*?"<>|\s,]+\.xlsx)',
    caseSensitive: false,
  ).firstMatch(text);
  if (fileInText != null && action == 'Imported') {
    return fileInText.group(1)!;
  }

  // Old import without filename: "29 records (ATOPCONTINUING)" / "29 lines · ATOP Current"
  final oldRecords = RegExp(
    r'^(\d+)\s+records\s+\(([^)]+)\)$',
  ).firstMatch(text);
  if (oldRecords != null) {
    return programLabel(oldRecords.group(2)!);
  }
  final oldLines = RegExp(
    r'^(\d+)\s+lines?\s*[·;]\s*(.+)$',
  ).firstMatch(text);
  if (oldLines != null) {
    return oldLines.group(2)!.trim();
  }

  // Old program rows: "ATOPCONTINUING · ATOP-REG_CONT · Active"
  final prog = RegExp(
    r'^([A-Z0-9]{2,32})\s[·;]\s(.+?)(?:\s[·;]\s(Active|Inactive))?$',
  ).firstMatch(text);
  if (prog != null) {
    final label = programLabel(prog.group(1)!, prog.group(2));
    return prog.group(3) == 'Inactive' ? '$label (Inactive)' : label;
  }

  // Old report: "TYPE · CODE (PDF)"
  final report = RegExp(r'^(.+?)\s·\s(.+?)\s\(([^)]+)\)$').firstMatch(text);
  if (report != null) {
    return '${report.group(1)} (${report.group(3)})';
  }

  text = text.replaceAllMapped(
    RegExp(
      r'\b(Allotment|Obligation|Disbursement):\s*(₱[^\s·;]+)(?:\s*→\s*(₱[^\s·;]+))?',
    ),
    (m) {
      if (m[3] != null) return '${m[1]} from ${m[2]} to ${m[3]}';
      return '${m[1]} ${m[2]}';
    },
  );
  return text;
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
        child: AppDropdown<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          fieldTextStyle: const TextStyle(
            fontFamily: 'Segoe UI',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: EdgeInsets.fromLTRB(12, 11, 0, 11),
          ),
        ),
      ),
    ],
  );
}
