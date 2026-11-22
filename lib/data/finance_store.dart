import 'package:flutter/foundation.dart';

import '../core/format.dart';
import 'database.dart';
import 'models.dart';
import 'passwords.dart';

class FinanceStore extends ChangeNotifier {
  FinanceStore(this.db);
  final FinanceDatabase db;
  LocalUser? user;
  bool get needsAccount => db.rows('SELECT id FROM users LIMIT 1').isEmpty;
  List<int> get years {
    db.ensureCurrentYear();
    return db
        .rows('SELECT year FROM fiscal_years ORDER BY year DESC')
        .map((r) => r['year'] as int)
        .toList();
  }

  List<Program> get programs => db
      .rows('SELECT * FROM programs ORDER BY code')
      .map(
        (r) =>
            Program(r['code'] as String, r['name'] as String, r['active'] == 1),
      )
      .toList();

  Future<void> createOwner(
    String name,
    String username,
    String password,
  ) async {
    if (!needsAccount) {
      throw const FinanceError('An account already exists. Please sign in.');
    }
    name = name.trim();
    username = username.trim();
    if (name.isEmpty || username.isEmpty) {
      throw const FinanceError('Enter your name and username.');
    }
    if (password.length < 8) {
      throw const FinanceError('Use at least 8 characters for your password.');
    }
    final hash = await Passwords.hash(password);
    db.transaction(() {
      if (!needsAccount) {
        throw const FinanceError('An account already exists. Please sign in.');
      }
      db.connection.execute(
        'INSERT INTO users(name,username,password_hash,role,active) VALUES (?,?,?,\'Admin\',1)',
        [name, username, hash],
      );
    });
    await signIn(username, password);
  }

  Future<void> signIn(String username, String password) async {
    final matches = db.rows(
      'SELECT * FROM users WHERE username=? COLLATE NOCASE',
      [username.trim()],
    );
    if (matches.isEmpty ||
        matches.first['active'] != 1 ||
        !await Passwords.verify(
          password,
          matches.first['password_hash'] as String,
        )) {
      throw const FinanceError(
        'Invalid username or password, or the account is inactive.',
      );
    }
    user = LocalUser.fromMap(matches.first);
    notifyListeners();
  }

  void signOut() {
    user = null;
    notifyListeners();
  }

  void require(String page) {
    if (user == null || !user!.can(page)) {
      throw const FinanceError(
        'Your account does not have access to this feature.',
      );
    }
  }

  List<BudgetRecord> records(
    int year, {
    String program = '',
    String fund = '',
    String query = '',
    String item = '',
  }) {
    var sql = 'SELECT * FROM budget_records WHERE year=?';
    final args = <Object?>[year];
    for (final entry in {
      'program': program,
      'fund_source': fund,
      'code': item,
    }.entries) {
      if (entry.value.isNotEmpty) {
        sql += ' AND ${entry.key}=?';
        args.add(entry.value);
      }
    }
    if (query.trim().isNotEmpty) {
      sql += ' AND (code LIKE ? OR name LIKE ?)';
      args.addAll(['%${codeKey(query)}%', '%${query.trim()}%']);
    }
    return db
        .rows('$sql ORDER BY program,fund_source,code', args)
        .map(BudgetRecord.fromMap)
        .toList();
  }

  List<DbRow> references([String query = '']) => query.trim().isEmpty
      ? db.rows('SELECT * FROM uacs_refs ORDER BY code')
      : db.rows(
          'SELECT * FROM uacs_refs WHERE code LIKE ? OR name LIKE ? ORDER BY code',
          ['%${codeKey(query)}%', '%${query.trim()}%'],
        );

  BudgetRecord? byId(int id) {
    final rows = db.rows('SELECT * FROM budget_records WHERE id=?', [id]);
    return rows.isEmpty ? null : BudgetRecord.fromMap(rows.first);
  }

  void _validate(
    BudgetRecord record, {
    BudgetRecord? previous,
    bool fromImport = false,
  }) {
    if (fromImport) {
      // Excel import keeps amounts/codes as-is; only reject unusable rows.
      if (codeKey(record.code).isEmpty) {
        throw const FinanceError('A budget line is missing a UACS code.');
      }
      if (record.name.trim().isEmpty) {
        throw const FinanceError('A budget line is missing an expense name.');
      }
      if ([record.allotment, record.obligation, record.disbursement].any(
        (v) => v < 0,
      )) {
        throw const FinanceError('Amounts cannot be negative.');
      }
    } else if (record.error != null) {
      throw FinanceError(record.error!);
    }
    if (!['CURRENT', 'CONTINUING'].contains(record.fund)) {
      throw const FinanceError('Select a valid fund source.');
    }
    if (db.rows('SELECT year FROM fiscal_years WHERE year=?', [
      record.year,
    ]).isEmpty) {
      throw const FinanceError('Select a valid fiscal year.');
    }
    final p = db.rows('SELECT * FROM programs WHERE code=?', [record.program]);
    if (p.isEmpty ||
        (p.first['active'] != 1 && record.program != previous?.program)) {
      throw const FinanceError('Select an active program.');
    }
  }

  void _write(BudgetRecord record, {int? id}) {
    if (id == null) {
      db.connection.execute('''INSERT INTO budget_records
        (year,program,fund_source,code,name,allotment,obligation,disbursement,remarks)
        VALUES (?,?,?,?,?,?,?,?,?)''', record.values);
    } else {
      db.connection.execute(
        '''UPDATE budget_records SET year=?,program=?,fund_source=?,
        code=?,name=?,allotment=?,obligation=?,disbursement=?,remarks=? WHERE id=?''',
        [...record.values, id],
      );
    }
    db.connection.execute(
      'INSERT OR REPLACE INTO uacs_refs(code,name) VALUES (?,?)',
      [codeKey(record.code), record.name.trim()],
    );
  }

  void saveRecord(BudgetRecord record) {
    require('budget');
    db.transaction(() {
      final before = record.id == null ? null : byId(record.id!);
      if (record.id != null && before == null) {
        throw const FinanceError('This record no longer exists.');
      }
      _validate(record, previous: before);
      final clash = db.rows(
        '''SELECT id FROM budget_records WHERE year=? AND program=?
        AND fund_source=? AND code=? AND id<>?''',
        [
          record.year,
          record.program,
          record.fund,
          codeKey(record.code),
          record.id ?? 0,
        ],
      );
      if (clash.isNotEmpty) {
        throw const FinanceError(
          'This UACS code already exists for this year and program.',
        );
      }
      _write(record, id: record.id);
      var detail = '${displayCode(codeKey(record.code))} · ${record.name}';
      if (before != null) {
        for (final e in {
          'Allotment': [before.allotment, record.allotment],
          'Obligation': [before.obligation, record.obligation],
          'Disbursement': [before.disbursement, record.disbursement],
        }.entries) {
          if (e.value[0] != e.value[1]) {
            detail +=
                ' · ${e.key}: ${money(e.value[0])} → ${money(e.value[1])}';
          }
        }
      }
      _audit(
        record.id == null ? 'Added' : 'Updated',
        record.id == null ? 'Added new record' : 'Updated record',
        detail,
        year: record.year,
        program: record.program,
      );
    });
    notifyListeners();
  }

  void deleteRecord(int id) {
    require('budget');
    db.transaction(() {
      final record = byId(id);
      if (record == null) {
        throw const FinanceError('This record no longer exists.');
      }
      db.connection.execute('DELETE FROM budget_records WHERE id=?', [id]);
      _audit(
        'Deleted',
        'Deleted record',
        '${displayCode(record.code)} · ${record.name}',
        year: record.year,
        program: record.program,
      );
    });
    notifyListeners();
  }

  int importRecords(
    List<BudgetRecord> payload, {
    required bool updateExisting,
    String? programName,
  }) {
    require('import');
    if (payload.isEmpty) {
      throw const FinanceError(
        'There are no valid new or changed records to import.',
      );
    }
    var count = 0;
    db.transaction(() {
      final program = payload.first.program.trim().toUpperCase();
      final label = (programName ?? programLabel(program)).trim();
      final existing = db.rows('SELECT code FROM programs WHERE code=?', [
        program,
      ]);
      if (existing.isEmpty) {
        if (!RegExp(r'^[A-Z0-9]{2,32}$').hasMatch(program)) {
          throw const FinanceError(
            'This worksheet name cannot be used as a program code.',
          );
        }
        db.connection.execute(
          'INSERT INTO programs(code,name,active) VALUES (?,?,1)',
          [program, label.isEmpty ? programLabel(program) : label],
        );
        _audit(
          'Added',
          'Added program from Excel worksheet',
          '$program · ${label.isEmpty ? programLabel(program) : label}',
          year: payload.first.year,
          program: program,
        );
      } else if (label.isNotEmpty) {
        db.connection.execute('UPDATE programs SET name=? WHERE code=?', [
          label,
          program,
        ]);
      }
      final seen = <String>{};
      for (final record in payload) {
        _validate(record, fromImport: true);
        final identity =
            '${record.year}/${record.program}/${record.fund}/${codeKey(record.code)}';
        if (!seen.add(identity)) {
          throw const FinanceError(
            'Duplicate UACS codes were found in the selected worksheet.',
          );
        }
        final rows = db.rows(
          '''SELECT * FROM budget_records WHERE year=? AND program=?
          AND fund_source=? AND code=?''',
          [record.year, record.program, record.fund, codeKey(record.code)],
        );
        final previous = rows.isEmpty ? null : BudgetRecord.fromMap(rows.first);
        if (previous != null &&
            (!updateExisting || previous.sameAmountsAndText(record))) {
          continue;
        }
        _write(record, id: previous?.id);
        count++;
      }
      if (count > 0) {
        _audit(
          'Imported',
          'Imported records from Excel',
          '$count records (${payload.first.program})',
          year: payload.first.year,
          program: payload.first.program,
        );
      }
    });
    notifyListeners();
    return count;
  }

  void saveProgram(String code, String name, bool active, {String? original}) {
    require('settings');
    code = code.trim().toUpperCase();
    name = name.trim();
    if (!RegExp(r'^[A-Z0-9]{2,32}$').hasMatch(code) || name.isEmpty) {
      throw const FinanceError(
        'Enter a program name and a code with 2–32 letters or numbers.',
      );
    }
    db.transaction(() {
      if (db.rows('SELECT code FROM programs WHERE code=? AND code<>?', [
        code,
        original ?? '',
      ]).isNotEmpty) {
        throw const FinanceError('This program code already exists.');
      }
      if (original == null) {
        db.connection.execute(
          'INSERT INTO programs(code,name,active) VALUES (?,?,?)',
          [code, name, active ? 1 : 0],
        );
      } else {
        db.connection.execute(
          'UPDATE programs SET code=?,name=?,active=? WHERE code=?',
          [code, name, active ? 1 : 0, original],
        );
        if (original != code) {
          db.connection.execute(
            'UPDATE budget_records SET program=? WHERE program=?',
            [code, original],
          );
          db.connection.execute(
            'UPDATE audit_log SET program=? WHERE program=?',
            [code, original],
          );
          db.connection.execute(
            'UPDATE report_history SET program=? WHERE program=?',
            [code, original],
          );
        }
      }
      _audit(
        'Updated',
        'Updated program',
        '$code · $name · ${active ? 'Active' : 'Inactive'}',
        year: manilaNow().year,
        program: code,
      );
    });
    notifyListeners();
  }

  void deleteProgram(String code) {
    require('settings');
    db.transaction(() {
      if (db.rows('SELECT code FROM programs WHERE code=?', [code]).isEmpty) {
        throw const FinanceError('This program no longer exists.');
      }
      if (db
          .rows('SELECT id FROM budget_records WHERE program=? LIMIT 1', [
            code,
          ])
          .isNotEmpty) {
        throw const FinanceError(
          'This program still has budget records and cannot be deleted.',
        );
      }
      db.connection.execute('DELETE FROM programs WHERE code=?', [code]);
      _audit(
        'Deleted',
        'Deleted program',
        code,
        year: manilaNow().year,
        program: code,
      );
    });
    notifyListeners();
  }

  void saveReference(String code, String name, {String? original}) {
    require('settings');
    code = codeKey(code);
    name = name.trim();
    if (!RegExp(r'^\d{8,14}$').hasMatch(code) || name.isEmpty) {
      throw const FinanceError(
        'Enter an expense name and an 8–14 digit UACS code.',
      );
    }
    db.transaction(() {
      if (db.rows('SELECT code FROM uacs_refs WHERE code=? AND code<>?', [
        code,
        original ?? '',
      ]).isNotEmpty) {
        throw const FinanceError('This UACS code already exists.');
      }
      if (original == null) {
        db.connection.execute('INSERT INTO uacs_refs(code,name) VALUES (?,?)', [
          code,
          name,
        ]);
      } else {
        db.connection.execute(
          'UPDATE uacs_refs SET code=?,name=? WHERE code=?',
          [code, name, original],
        );
      }
      _audit(
        'Updated',
        'Updated UACS reference',
        '${displayCode(code)} · $name',
        year: manilaNow().year,
      );
    });
    notifyListeners();
  }

  void _audit(
    String action,
    String title,
    String detail, {
    required int year,
    String program = '',
  }) {
    db.connection.execute(
      '''INSERT INTO audit_log(at,username,action,title,detail,year,program)
      VALUES (?,?,?,?,?,?,?)''',
      [nowStamp(), user!.username, action, title, detail, year, program],
    );
  }

  List<DbRow> auditRows(
    int year, {
    String program = '',
    String action = '',
    String from = '',
    String through = '',
  }) {
    var sql = 'SELECT * FROM audit_log WHERE year=?';
    final args = <Object?>[year];
    for (final e in {'program': program, 'action': action}.entries) {
      if (e.value.isNotEmpty) {
        sql += ' AND ${e.key}=?';
        args.add(e.value);
      }
    }
    // Compare the stored Manila calendar date; SQLite date() converts offsets to UTC.
    if (from.isNotEmpty) {
      sql += ' AND substr(at,1,10)>=?';
      args.add(from);
    }
    if (through.isNotEmpty) {
      sql += ' AND substr(at,1,10)<=?';
      args.add(through);
    }
    return db.rows('$sql ORDER BY id DESC', args);
  }

  List<DbRow> get reportHistory =>
      db.rows('SELECT * FROM report_history ORDER BY id DESC LIMIT 20');
  void logReport(String type, int year, String program, String format) {
    require('reports');
    db.transaction(() {
      db.connection.execute(
        'INSERT INTO report_history(at,type,year,program,format) VALUES (?,?,?,?,?)',
        [nowStamp(), type, year, program, format],
      );
      _audit(
        'Generated',
        'Generated report',
        '$type · ${program.isEmpty ? 'All Programs' : program} ($format)',
        year: year,
        program: program,
      );
    });
    notifyListeners();
  }
}
