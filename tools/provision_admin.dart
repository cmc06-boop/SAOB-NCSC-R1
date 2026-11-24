import 'dart:io';

import 'package:ncsc_region1_finance/core/format.dart';
import 'package:ncsc_region1_finance/data/database.dart';
import 'package:ncsc_region1_finance/data/passwords.dart';

// Maintainer-only tool. Run with Dart/Flutter installed on the target Windows
// account BEFORE handing the desktop application to its administrator.
// This script never prints, stores in source, or accepts passwords in CLI args.
String _ask(String label) {
  stdout.write('$label: ');
  return stdin.readLineSync()?.trim() ?? '';
}

String _secret(String label) {
  stdout.write('$label: ');
  final originalEcho = stdin.echoMode;
  stdin.echoMode = false;
  try {
    return stdin.readLineSync() ?? '';
  } finally {
    stdin.echoMode = originalEcho;
    stdout.writeln();
  }
}

Future<void> main(List<String> args) async {
  if (args.isNotEmpty || !stdin.hasTerminal) {
    stderr.writeln(
      'Run interactively with no arguments: dart run tools/provision_admin.dart',
    );
    exitCode = 1;
    return;
  }
  final db = FinanceDatabase.open();
  try {
    if (db.rows('SELECT id FROM users LIMIT 1').isNotEmpty) {
      stdout.writeln(
        'An account already exists. No changes were made. '
        'Use Settings > My Account after signing in.',
      );
      return;
    }

    stdout.writeln('Initialize the Admin account for this Windows user.');
    final name = _ask('Full name');
    final username = _ask('Username');
    if (name.isEmpty || username.isEmpty ||
        name.length > 120 ||
        username.length > 64 ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(username)) {
      throw const FinanceError(
        'Enter a full name and a valid username (letters, digits, ., _, -).',
      );
    }
    final password = _secret('Password (at least 12 characters)');
    final confirm = _secret('Confirm password');
    if (password.length < 12) {
      throw const FinanceError('Password must be at least 12 characters.');
    }
    if (password != confirm) {
      throw const FinanceError('Passwords do not match.');
    }

    final hash = await Passwords.hash(password);
    db.transaction(() {
      if (db.rows('SELECT id FROM users LIMIT 1').isNotEmpty) {
        throw const FinanceError('An account was already configured.');
      }
      db.connection.execute(
        "INSERT INTO users(name,username,password_hash,role,active) "
        "VALUES (?,?,?,'Admin',1)",
        [name, username, hash],
      );
    });
    stdout.writeln(
      'Admin account configured. You can now sign in to the application.',
    );
  } on FinanceError catch (e) {
    stderr.writeln(e.message);
    exitCode = 1;
  } finally {
    db.close();
  }
}
