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
          const _AuditCell('Date', style: header, align: TextAlign.center),
          const _AuditCell('Time', style: header, align: TextAlign.center),
          const _AuditCell('Action', style: header, align: TextAlign.center),
          const _AuditCell('Details', style: header, align: TextAlign.center),
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
                auditDetailSentence(
                  '${r['detail'] ?? ''}',
                  action: '${r['action'] ?? ''}',
                  program: '${r['program'] ?? ''}',
                ),
                style: body,
                tip: true,
                tooltip: '${r['detail'] ?? ''}',
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
  const _AuditCell(
    this.text, {
    this.style,
    this.tip = false,
    this.tooltip,
    this.align = TextAlign.left,
  });
  final String text;
  final TextStyle? style;
  final bool tip;
  final String? tooltip;
  final TextAlign align;
  @override
  Widget build(BuildContext context) {
    final label = Text(text, textAlign: align, softWrap: true, style: style);
    return Padding(
      padding: EdgeInsets.fromLTRB(align == TextAlign.center ? 8 : 12, 8, 8, 8),
      child: tip && text.isNotEmpty
          ? Tooltip(message: tooltip ?? text, child: label)
          : label,
    );
  }
}

/// A short display sentence; the original audit detail stays in SQLite and
/// remains available from the Details tooltip for accounting traceability.
String auditDetailSentence(
  String raw, {
  String action = '',
  String program = '',
}) {
  final detail = raw.trim();
  if (detail.isEmpty) {
    return 'No additional details.';
  }
  final kind = action.trim().toLowerCase();

  // One successful Excel workbook import produces one audit entry.
  // Display the filename, never a list of workbook sheets.
  if (kind == 'imported') {
    // The new format is just the filename. Preserve spaces, commas and
    // other valid filename characters rather than trying to parse sheets.
    final basename = detail.split(RegExp(r'[\\/]')).last.trim();
    if (basename.toLowerCase().endsWith('.xlsx')) {
      return basename.replaceFirst(
        RegExp(
          r'^(?:Imported\b.*?\bfrom|Workbook\s*:|File\s*:)\s*',
          caseSensitive: false,
        ),
        '',
      );
    }
    final matches = RegExp(
      r'([^\\/:;,"<>|\r\n]+\.xlsx)\b',
      caseSensitive: false,
    ).allMatches(detail).toList();
    if (matches.isNotEmpty) {
      var file = matches.last.group(1)!.trim();
      file = file.replaceFirst(
        RegExp(
          r'^(?:Imported\b.*?\bfrom|Workbook\s*:?|File\s*:?)\s+',
          caseSensitive: false,
        ),
        '',
      );
      return file;
    }
    // Older per-sheet rows may not contain a filename: do not invent one.
    return 'Imported budget records.';
  }

  if (detail == 'Account profile updated') {
    return 'Updated account profile.';
  }
  if (detail == 'Account password changed') {
    return 'Changed account password.';
  }

  // Budget amount changes preserve a full detail tooltip, but one
  // short human-readable sentence is shown in the table.
  final amount = RegExp(
    r'^(Allotment|Obligation|Disbursement)\s+from\s+',
    caseSensitive: false,
  );
  final parts = detail.split(';').map((part) => part.trim()).toList();
  if (kind == 'updated' &&
      parts.isNotEmpty &&
      parts.every((part) => amount.hasMatch(part))) {
    if (parts.length == 1) {
      final item = parts.single;
      return 'Updated ${item[0].toLowerCase()}${item.substring(1)}.';
    }
    final labels = [
      for (final part in parts) amount.firstMatch(part)!.group(1)!.toLowerCase(),
    ];
    return 'Updated ${labels.join(', ')} amounts.';
  }

  if (kind == 'updated' &&
      RegExp(r'\b(Allotment|Obligation|Disbursement):').hasMatch(detail)) {
    return 'Updated budget amounts.';
  }

  // The original record detail includes its UACS code and long expense name.
  final record = RegExp(
    r'^(\d{8}(?:\s?\d{0,6}))\s+-\s+.+$',
  ).firstMatch(detail);
  if (record != null) {
    final code = codeKey(record.group(1));
    final verb = switch (kind) {
      'added' => 'Added',
      'updated' => 'Updated',
      'deleted' => 'Deleted',
      _ => 'Changed',
    };
    return '$verb UACS ${displayCode(code)}.';
  }

  if (kind == 'generated') {
    return detail.endsWith('.') ? 'Generated $detail' : 'Generated $detail.';
  }

  // Program operations also preserve their longer original details.
  if (program.isNotEmpty &&
      (kind == 'added' || kind == 'updated' || kind == 'deleted')) {
    final verb = switch (kind) {
      'added' => 'Added',
      'updated' => 'Updated',
      _ => 'Deleted',
    };
    return '$verb program ${programLabel(program)}.';
  }

  final verb = switch (kind) {
    'added' => 'Added',
    'updated' => 'Updated',
    'deleted' => 'Deleted',
    _ => '',
  };
  final sentence = verb.isEmpty ? detail : '$verb $detail';
  return sentence.endsWith('.') ? sentence : '$sentence.';
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
