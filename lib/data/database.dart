import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../core/format.dart';
import 'models.dart';

class FinanceDatabase {
  FinanceDatabase._(this.connection, this.path);
  final Database connection;
  final String path;
  static const tables = [
    'users',
    'programs',
    'fiscal_years',
    'uacs_refs',
    'budget_records',
    'audit_log',
    'report_history',
    'settings',
  ];

  static FinanceDatabase open({
    String? path,
    String? legacyPath,
    DateTime? today,
  }) {
    final local =
        Platform.environment['LOCALAPPDATA'] ??
        p.join(
          Platform.environment['HOME'] ?? Directory.current.path,
          '.local',
          'share',
        );
    final target =
        path ?? p.join(local, 'NCSC Region I Finance Flutter', 'finance.db');
    final legacy =
        legacyPath ??
        (path == null && Platform.isWindows
            ? p.join(local, 'NCSC Region I Finance', 'finance.db')
            : null);
    final isNew = target == ':memory:' || !File(target).existsSync();
    if (target != ':memory:') {
      Directory(p.dirname(target)).createSync(recursive: true);
    }
    final db = FinanceDatabase._(sqlite3.open(target), target);
    try {
      db.connection.execute('PRAGMA foreign_keys=ON');
      db.connection.execute('PRAGMA journal_mode=WAL');
      db.connection.execute('PRAGMA busy_timeout=5000');
      db.connection.execute(_schema);
      // One-time legacy copy for on-disk DBs. Marker prevents old programs /
      // 2026 rows from coming back after finance.db is deleted.
      // In-memory test DBs still migrate when legacyPath is passed.
      if (isNew && legacy != null && File(legacy).existsSync()) {
        final marker = target == ':memory:'
            ? null
            : File('$target.legacy_migrated');
        if (marker == null || !marker.existsSync()) {
          db._copyLegacy(legacy);
          marker?.writeAsStringSync(legacy);
        }
      }
      db.transaction(() {
        // Programs come only from Excel import or Settings — never seeded.
        db._underscoreProgramCodes();
        db.ensureCurrentYear(today: today);
      });
      return db;
    } catch (_) {
      db.close();
      // Only remove a newly-created, failed destination. Never alter the source.
      if (isNew && target != ':memory:') {
        for (final suffix in ['', '-wal', '-shm']) {
          final file = File('$target$suffix');
          if (file.existsSync()) file.deleteSync();
        }
      }
      rethrow;
    }
  }

  void _copyLegacy(String sourcePath) {
    final source = sqlite3.open(sourcePath, mode: OpenMode.readOnly);
    try {
      source.execute('BEGIN');
      final names = source
          .select("SELECT name FROM sqlite_master WHERE type='table'")
          .map((r) => r['name'])
          .toSet();
      if (!names.containsAll(['users', 'budget_records', 'programs'])) {
        throw const FinanceError(
          'The existing database is not a supported NCSC finance database.',
        );
      }
      if (source.select('PRAGMA quick_check').first.values.first != 'ok') {
        throw const FinanceError(
          'The existing database could not be read correctly.',
        );
      }
      transaction(() {
        for (final table in tables.where(names.contains)) {
          final targetCols = rows('PRAGMA table_info($table)')
              .map((r) => r['name'])
              .toSet();
          final columns = source
              .select('PRAGMA table_info($table)')
              .map((r) => r['name'] as String)
              .where(targetCols.contains)
              .toList();
          final colSql = columns
              .map((c) => '"${c.replaceAll('"', '""')}"')
              .join(',');
          final placeholders = List.filled(columns.length, '?').join(',');
          for (final row in source.select('SELECT $colSql FROM $table')) {
            connection.execute(
              'INSERT INTO $table($colSql) VALUES ($placeholders)',
              columns.map((c) => row[c]).toList(),
            );
          }
        }
        connection.execute(
          "INSERT OR REPLACE INTO settings(key,value) VALUES ('flutter_migrated_from',?)",
          [sourcePath],
        );
      });
      source.execute('COMMIT');
    } finally {
      source.close();
    }
  }

  List<DbRow> rows(String sql, [List<Object?> params = const []]) => connection
      .select(sql, params)
      .map((r) => Map<String, Object?>.from(r))
      .toList();

  T transaction<T>(T Function() operation) {
    connection.execute('BEGIN IMMEDIATE');
    try {
      final result = operation();
      connection.execute('COMMIT');
      return result;
    } catch (_) {
      connection.execute('ROLLBACK');
      rethrow;
    }
  }

  /// ATOPCONTINUING and "ATOP Continuing" → ATOP_Continuing on the program key
  /// and every row that points at it. Names are left as stored.
  void _underscoreProgramCodes() {
    for (final row in rows('SELECT code FROM programs')) {
      final code = row['code'] as String;
      final next = readableProgramCode(code);
      if (next == null || next == code) continue;
      if (rows('SELECT code FROM programs WHERE code=?', [next]).isNotEmpty) {
        continue;
      }
      connection.execute('UPDATE programs SET code=? WHERE code=?', [
        next,
        code,
      ]);
      connection.execute(
        'UPDATE budget_records SET program=? WHERE program=?',
        [next, code],
      );
      connection.execute('UPDATE audit_log SET program=? WHERE program=?', [
        next,
        code,
      ]);
      connection.execute(
        'UPDATE report_history SET program=? WHERE program=?',
        [next, code],
      );
    }
  }

  void ensureCurrentYear({DateTime? today}) {
    final current = (today ?? manilaNow()).year;
    final known = rows('SELECT year FROM fiscal_years')
        .map((r) => r['year'] as int)
        .toList();
    var start = known.isEmpty
        ? (current < 2024 ? current : 2024)
        : known.reduce((a, b) => a < b ? a : b);
    if (start > current) start = current;
    for (var year = start; year <= current; year++) {
      connection.execute(
        "INSERT OR IGNORE INTO fiscal_years(year,active,remarks) VALUES (?,0,'')",
        [year],
      );
    }
    connection.execute('UPDATE fiscal_years SET active=(year=?)', [current]);
  }

  void close() => connection.close();
}

const _schema = '''
CREATE TABLE IF NOT EXISTS users (
 id INTEGER PRIMARY KEY, name TEXT NOT NULL, username TEXT NOT NULL UNIQUE,
 password_hash TEXT NOT NULL, role TEXT NOT NULL CHECK(role IN ('Admin','Encoder','Viewer')),
 active INTEGER NOT NULL DEFAULT 1);
CREATE TABLE IF NOT EXISTS programs (
 code TEXT PRIMARY KEY, name TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 1);
CREATE TABLE IF NOT EXISTS fiscal_years (
 year INTEGER PRIMARY KEY, active INTEGER NOT NULL DEFAULT 0, remarks TEXT NOT NULL DEFAULT '');
CREATE TABLE IF NOT EXISTS uacs_refs (code TEXT PRIMARY KEY, name TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS budget_records (
 id INTEGER PRIMARY KEY, year INTEGER NOT NULL, program TEXT NOT NULL,
 fund_source TEXT NOT NULL DEFAULT 'CURRENT', code TEXT NOT NULL, name TEXT NOT NULL,
 allotment REAL NOT NULL DEFAULT 0, obligation REAL NOT NULL DEFAULT 0,
 disbursement REAL NOT NULL DEFAULT 0, remarks TEXT NOT NULL DEFAULT '',
 UNIQUE(year,program,fund_source,code));
CREATE TABLE IF NOT EXISTS audit_log (
 id INTEGER PRIMARY KEY, at TEXT NOT NULL, username TEXT NOT NULL,
 action TEXT NOT NULL, title TEXT NOT NULL, detail TEXT NOT NULL DEFAULT '',
 year INTEGER, program TEXT NOT NULL DEFAULT '');
CREATE TABLE IF NOT EXISTS report_history (
 id INTEGER PRIMARY KEY, at TEXT NOT NULL, type TEXT NOT NULL,
 year INTEGER NOT NULL, program TEXT NOT NULL DEFAULT '', format TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
''';
