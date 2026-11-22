import 'package:intl/intl.dart';

const windowTitle =
    'National Commission of Senior Citizens Region I | Budget and Finance System';
const productTitle =
    'Statement of Allotments, Obligations, and Balances System';

DateTime manilaNow() => DateTime.now().toUtc().add(const Duration(hours: 8));
String nowStamp() => '${manilaNow().toIso8601String().split('.').first}+08:00';
String money(int cents) => NumberFormat.currency(
  locale: 'en_PH',
  symbol: '₱',
  decimalDigits: 2,
).format(cents / 100);
String rate(int amount, int base) =>
    base == 0 ? '—' : '${(amount * 100 / base).toStringAsFixed(2)}%';
String codeKey(Object? value) =>
    (value ?? '').toString().trim().replaceAll(RegExp(r'[\s-]+'), '');
String displayCode(String value) => value.length == 10
    ? '${value.substring(0, 8)} ${value.substring(8)}'
    : value;

/// Dropdown label: ATOPCURRENT → "ATOP Current", ATOPCONTINUING → "ATOP Continuing".
String programLabel(String code, [String? name]) {
  final upper = code.trim().toUpperCase();
  if (upper.endsWith('CONTINUING')) {
    final prefix = upper.substring(0, upper.length - 'CONTINUING'.length);
    return prefix.isEmpty ? 'Continuing' : '$prefix Continuing';
  }
  if (upper.endsWith('CURRENT')) {
    final prefix = upper.substring(0, upper.length - 'CURRENT'.length);
    return prefix.isEmpty ? 'Current' : '$prefix Current';
  }
  final fallback = (name ?? '').trim();
  if (fallback.isNotEmpty && fallback.toUpperCase() != upper) return fallback;
  return code.trim().isEmpty ? fallback : code.trim();
}

/// Stored program name from a sheet tab, e.g. ATOP-REG_CONT → "ATOP Continuing".
String programNameFromSheet(String sheetName) {
  final tokens = sheetName
      .trim()
      .toUpperCase()
      .split(RegExp(r'[^A-Z0-9]+'))
      .where((t) => t.isNotEmpty && t != 'REG')
      .map((t) => t == 'CONT' ? 'CONTINUING' : t)
      .toList();
  if (tokens.isEmpty) return sheetName.trim();
  return tokens
      .map((t) {
        if (t == 'CURRENT') return 'Current';
        if (t == 'CONTINUING') return 'Continuing';
        return t;
      })
      .join(' ');
}
String dateLabel(Object? value) {
  var text = (value ?? '').toString();
  if (text.isEmpty) return '';
  text = text.replaceFirst(' ', 'T');
  if (!RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(text)) text += '+08:00';
  final d = DateTime.tryParse(text)?.toUtc().add(const Duration(hours: 8));
  return d == null ? text : DateFormat('MMM d, yyyy  h:mm a').format(d);
}

/// Parse decimal text without binary floating point or silent rounding.
int? parseCents(String input, {bool required = false}) {
  final text = input.trim().replaceAll(RegExp(r'[₱,\s]'), '');
  if (text.isEmpty) return required ? null : 0;
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) return null;
  final parts = text.split('.');
  final whole = int.tryParse(parts[0]);
  if (whole == null || whole > 9000000000000) return null;
  return whole * 100 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
}

class FinanceError implements Exception {
  const FinanceError(this.message);
  final String message;
  @override
  String toString() => message;
}
