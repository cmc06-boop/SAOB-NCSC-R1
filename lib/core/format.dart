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

/// Readable program code. Compact or spaced keys become ATOP_Continuing.
/// A custom program name is never used in place of the code.
String programLabel(String code, [String? name]) {
  final trimmed = code.trim();
  final underscored = readableProgramCode(trimmed);
  if (underscored != null) return underscored;
  final fallback = (name ?? '').trim();
  final upper = trimmed.toUpperCase();
  if (fallback.isNotEmpty && fallback.toUpperCase() != upper) return fallback;
  return trimmed.isEmpty ? fallback : trimmed;
}

/// ATOPCONTINUING, "ATOP Continuing", or ATOP_Continuing → "ATOP_Continuing".
/// Null when the code is not a Current/Continuing key.
String? readableProgramCode(String code) {
  final compact = code.trim().toUpperCase().replaceAll(RegExp(r'[\s_]+'), '');
  if (compact.length <= 'CURRENT'.length) return null;
  String? suffix;
  if (compact.endsWith('CONTINUING')) {
    suffix = 'Continuing';
  } else if (compact.endsWith('CURRENT')) {
    suffix = 'Current';
  }
  if (suffix == null) return null;
  final prefix = compact.substring(0, compact.length - suffix.length);
  if (prefix.isEmpty) return null;
  return '${prefix}_$suffix';
}

bool validProgramCode(String code) =>
    code.length >= 2 &&
    code.length <= 40 &&
    RegExp(r'^[A-Za-z0-9]+(?:_[A-Za-z0-9]+)*$').hasMatch(code);

String normalizeProgramCode(String value) => value
    .trim()
    .replaceAll(RegExp(r'[\s_]+'), '_')
    .replaceAll(RegExp(r'^_|_$'), '');

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
DateTime? _manilaStamp(Object? value) {
  var text = (value ?? '').toString();
  if (text.isEmpty) return null;
  text = text.replaceFirst(' ', 'T');
  if (!RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(text)) text += '+08:00';
  return DateTime.tryParse(text)?.toUtc().add(const Duration(hours: 8));
}

String dateLabel(Object? value) {
  final d = _manilaStamp(value);
  if (d == null) return (value ?? '').toString();
  return DateFormat('MMM d, yyyy  h:mm a').format(d);
}

String dateOnly(Object? value) {
  final d = _manilaStamp(value);
  if (d == null) return (value ?? '').toString();
  return DateFormat('MMMM d, yyyy').format(d);
}

String timeOnly(Object? value) {
  final d = _manilaStamp(value);
  if (d == null) return '';
  return DateFormat('h:mm a').format(d);
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
