import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Local test-data utility only. Never called by the application.
void main(List<String> args) {
  if (!Platform.isWindows || args.length != 1 || args.single != '--confirm-reset') {
    stderr.writeln('Close the app, then run: dart run tool/reset_test_records.dart --confirm-reset');
    exitCode = 2;
    return;
  }
  final local = Platform.environment['LOCALAPPDATA'];
  if (local == null || local.isEmpty) {
    stderr.writeln('LOCALAPPDATA is unavailable. No records changed.');
    exitCode = 1;
    return;
  }
  final path = p.join(local, 'NCSC Region I Finance Flutter', 'finance.db');
  if (!File(path).existsSync()) {
    stderr.writeln('Database not found: $path. No records changed.');
    exitCode = 1;
    return;
  }
  const clear = ['budget_records', 'report_history', 'audit_log'];
  const retain = ['programs', 'uacs_refs', 'users', 'fiscal_years', 'settings'];
  Database? db;
  var inTransaction = false;
  try {
    final connection = sqlite3.open(path, mode: OpenMode.readWrite);
    db = connection;
    connection.execute('PRAGMA busy_timeout=5000');
    final tables = connection.select("SELECT name FROM sqlite_master WHERE type='table'")
        .map((row) => row['name']).toSet();
    if (!tables.containsAll([...clear, ...retain])) {
      throw StateError('Unexpected database schema; refusing reset.');
    }
    int count(String table) =>
        connection.select('SELECT COUNT(*) AS n FROM $table').single['n'] as int;
    stdout.writeln('Database: $path');
    stdout.writeln('Records to clear:');
    for (final table in clear) {
      stdout.writeln('  $table: ${count(table)}');
    }
    stdout.writeln('Type RESET to confirm this is your local TEST database:');
    if (stdin.readLineSync() != 'RESET') {
      stdout.writeln('Cancelled. No records changed.');
      return;
    }
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backup = p.join(p.dirname(path), 'finance-before-reset-$stamp.db');
    // VACUUM INTO snapshots committed data, including data in the WAL.
    connection.execute('VACUUM INTO ?', [backup]);
    final snapshot = sqlite3.open(backup, mode: OpenMode.readOnly);
    try {
      if (snapshot.select('PRAGMA quick_check').single.values.first != 'ok') {
        throw StateError('Backup integrity check failed; refusing reset.');
      }
    } finally {
      snapshot.close();
    }
    stdout.writeln('Backup saved: $backup');
    connection.execute('BEGIN IMMEDIATE');
    inTransaction = true;
    final before = {for (final table in retain) table: count(table)};
    for (final table in clear) {
      connection.execute('DELETE FROM $table');
    }
    for (final table in clear) {
      if (count(table) != 0) throw StateError('Reset verification failed: $table');
    }
    for (final table in retain) {
      if (count(table) != before[table]) {
        throw StateError('Retained table changed: $table');
      }
    }
    connection.execute('COMMIT');
    inTransaction = false;
    stdout.writeln('Reset successful.');
    for (final table in [...clear, ...retain]) {
      stdout.writeln('  $table: ${count(table)}');
    }
  } catch (error) {
    if (inTransaction) db?.execute('ROLLBACK');
    stderr.writeln('Reset error: $error');
    exitCode = 1;
  } finally {
    db?.close();
  }
}
