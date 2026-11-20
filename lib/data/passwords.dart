import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// Match Python's pbkdf2_hmac('sha256', password, salt.encode(), 120000).
/// The salt is its hex TEXT, not decoded hex bytes.
class Passwords {
  static final _algorithm = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 120000,
    bits: 256,
  );
  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  static Future<String> hash(String password, {String? salt}) async {
    final random = Random.secure();
    salt ??= _hex(List.generate(16, (_) => random.nextInt(256)));
    final key = await _algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: utf8.encode(salt),
    );
    return '$salt\$${_hex(await key.extractBytes())}';
  }

  static Future<bool> verify(String password, String stored) async {
    final parts = stored.split(r'$');
    if (parts.length != 2 || !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(parts[1])) {
      return false;
    }
    final actual = await hash(password, salt: parts[0]);
    if (actual.length != stored.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual.codeUnitAt(i) ^ stored.codeUnitAt(i);
    }
    return diff == 0;
  }
}
