import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../core/format.dart';
import 'database.dart';

/// Create consistent SQLite snapshots without copying the live WAL files.
class FinanceBackup {
  FinanceBackup(this.db);
  final FinanceDatabase db;

  static const lastBackupKey = 'last_backup_at';

  String? get lastBackup {
    final rows = db.rows('SELECT value FROM settings WHERE key=?', [lastBackupKey]);
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  String create(String folder, {bool safety = false}) {
    if (db.path == ':memory:') {
      throw const FinanceError('Backups require an on-disk database.');
    }
    final stamp = manilaNow().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final name = 'NCSC-R1-${safety ? 'Before-Restore' : 'Backup'}-$stamp.db';
    final temporary = Directory(folder).createTempSync('.ncsc-backup-');
    File? destination;
    try {
      final snapshot = p.join(temporary.path, 'snapshot.db');
      db.connection.execute('VACUUM INTO ?', [snapshot]);
      final source = sqlite3.open(snapshot, mode: OpenMode.readOnly);
      try {
        _validate(source);
      } finally {
        source.close();
      }
      final output = File(p.join(folder, name));
      output.createSync(exclusive: true);
      destination = output;
      File(snapshot).copySync(output.path);
      final handle = output.openSync(mode: FileMode.append);
      try {
        handle.flushSync();
      } finally {
        handle.closeSync();
      }
      if (!safety) {
        db.connection.execute(
          'INSERT OR REPLACE INTO settings(key,value) VALUES (?,?)',
          [lastBackupKey, manilaNow().toIso8601String()],
        );
      }
      return output.path;
    } catch (_) {
      if (destination != null) {
        try { destination.deleteSync(); } on FileSystemException { /* retain original error */ }
      }
      rethrow;
    } finally {
      try { temporary.deleteSync(recursive: true); } on FileSystemException { /* cleanup best effort */ }
    }
  }

  /// Restore all known tables inside one transaction; never replace an open DB.
  /// A failed import rolls back the live database. A safety copy remains on disk.
  String restore(String path) {
    if (db.path == ':memory:' || !File(path).existsSync()) {
      throw const FinanceError('Select an existing backup database.');
    }
    if (FileSystemEntity.identicalSync(path, db.path)) {
      throw const FinanceError('Select a backup, not the active database.');
    }
    final source = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      source.execute('PRAGMA trusted_schema=OFF');
      source.execute('BEGIN');
      _validate(source);
      final folder = Directory(p.join(p.dirname(db.path), 'restore-safety'));
      folder.createSync(recursive: true);
      final safetyPath = create(folder.path, safety: true);
      db.transaction(() {
        for (final table in FinanceDatabase.tables.reversed) {
          db.connection.execute('DELETE FROM "$table"');
        }
        for (final table in FinanceDatabase.tables) {
          final columns = db.rows('PRAGMA table_info($table)')
              .map((row) => '"${row['name']}"').join(',');
          final count = db.rows('PRAGMA table_info($table)').length;
          final placeholders = List.filled(count, '?').join(',');
          for (final row in source.select('SELECT $columns FROM "$table"')) {
            db.connection.execute(
              'INSERT INTO "$table" ($columns) VALUES ($placeholders)',
              row.values.toList(),
            );
          }
        }
        db.ensureCurrentYear();
        db.connection.execute(
          'INSERT OR REPLACE INTO settings(key,value) VALUES (?,?)',
          [lastBackupKey, manilaNow().toIso8601String()],
        );
        if (db.rows('PRAGMA quick_check').any((row) => row.values.first != 'ok')) {
          throw const FinanceError('Restored database failed integrity verification.');
        }
      });
      return safetyPath;
    } finally {
      source.close();
    }
  }

  void _validate(Database source) {
    if (source.select('PRAGMA quick_check').any((row) => row.values.first != 'ok')) {
      throw const FinanceError('The backup is damaged or unreadable.');
    }
    final tables = source.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    ).map((row) => row['name']).toSet();
    if (tables.length != FinanceDatabase.tables.length ||
        !tables.containsAll(FinanceDatabase.tables)) {
      throw const FinanceError('This is not a compatible NCSC finance backup.');
    }
    for (final table in FinanceDatabase.tables) {
      final expected = db.rows('PRAGMA table_info($table)')
          .map((row) => "${row['name']}:${row['type']}").join('|');
      final actual = source.select('PRAGMA table_info($table)')
          .map((row) => "${row['name']}:${row['type']}").join('|');
      if (actual != expected) {
        throw const FinanceError('The backup uses an incompatible database version.');
      }
    }
    final admins = source.select("SELECT password_hash FROM users WHERE role='Admin' AND active=1");
    if (!admins.any((row) {
      final hash = row['password_hash'];
      return hash is String && RegExp(r'^[0-9a-fA-F]+\$[0-9a-fA-F]{64}$').hasMatch(hash);
    })) {
      throw const FinanceError('The backup has no valid active administrator account.');
    }
  }
}
