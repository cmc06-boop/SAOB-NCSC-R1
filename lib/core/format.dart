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
