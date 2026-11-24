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

  
  /// Update the signed-in administrator's own profile.
  void updateMyProfile(String name, String username) {
    require('settings');
    final current = user!;
    name = name.trim();
    username = username.trim();
    if (name.isEmpty || username.isEmpty) {
      throw const FinanceError('Enter both your full name and username.');
    }
    if (name.length > 120 ||
        username.length > 64 ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(username)) {
      throw const FinanceError(
        'Use a username of up to 64 letters, numbers, periods, hyphens, or underscores.',
      );
    }
    db.transaction(() {
      if (db.rows(
        'SELECT id FROM users WHERE username=? COLLATE NOCASE AND id<>?',
        [username, current.id],
      ).isNotEmpty) {
        throw const FinanceError('This username is already in use.');
      }
      db.connection.execute(
        'UPDATE users SET name=?, username=? WHERE id=? AND active=1',
        [name, username, current.id],
      );
      _audit('Updated', '', 'Account profile updated', year: manilaNow().year);
    });
    user = LocalUser(current.id, name, username, current.role);
    notifyListeners();
  }

  /// Confirm the old password before replacing its PBKDF2 hash.
  Future<void> changeMyPassword(
    String currentPassword,
    String newPassword,
  ) async {
    require('settings');
    final account = user!;
    final rows = db.rows(
      'SELECT password_hash FROM users WHERE id=? AND active=1',
      [account.id],
    );
    if (rows.isEmpty) {
      throw const FinanceError('Your account is no longer active.');
    }
    final oldHash = rows.single['password_hash'] as String;
    if (!await Passwords.verify(currentPassword, oldHash)) {
      throw const FinanceError('The current password is incorrect.');
    }
    if (newPassword.length < 12) {
      throw const FinanceError(
        'Use at least 12 characters for the new password.',
      );
    }
    if (newPassword == currentPassword) {
      throw const FinanceError(
        'Choose a new password that differs from the current one.',
      );
    }
    final newHash = await Passwords.hash(newPassword);
    db.transaction(() {
      final fresh = db.rows(
        'SELECT password_hash FROM users WHERE id=? AND active=1',
        [account.id],
      );
      if (fresh.isEmpty || fresh.single['password_hash'] != oldHash) {
        throw const FinanceError(
          'Account credentials changed. Sign in again before retrying.',
        );
      }
      db.connection.execute(
        'UPDATE users SET password_hash=? WHERE id=?',
        [newHash, account.id],
      );
      _audit('Updated', '', 'Account password changed', year: manilaNow().year);
    });
    notifyListeners();
  }


  /// Save changes to the profile, password, or both atomically.
  /// All three password fields may be left blank for profile-only updates.
  Future<bool> saveMyAccount({
    required String name,
    required String username,
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    require('settings');
    final account = user!;
    name = name.trim();
    username = username.trim();
    if (name.isEmpty || username.isEmpty) {
      throw const FinanceError('Enter both your full name and username.');
    }
    final usernameValid = username.length <= 64 &&
        RegExp(r'^[A-Za-z0-9]').hasMatch(username) &&
        !RegExp(r'[^A-Za-z0-9._-]').hasMatch(username);
    if (name.length > 120 || !usernameValid) {
      throw const FinanceError(
        'Use a username of up to 64 letters, numbers, periods, hyphens, or underscores.',
      );
    }

    final profileChanged = name != account.name || username != account.username;
    final passwordRequested = currentPassword.isNotEmpty ||
        newPassword.isNotEmpty ||
        confirmPassword.isNotEmpty;
    if (!profileChanged && !passwordRequested) return false;

    String? previousHash;
    String? newHash;
    if (passwordRequested) {
      if (currentPassword.isEmpty ||
          newPassword.isEmpty ||
          confirmPassword.isEmpty) {
        throw const FinanceError(
          'To change your password, complete all three password fields.',
        );
      }
      if (newPassword != confirmPassword) {
        throw const FinanceError('New passwords do not match.');
      }
      if (newPassword.length < 12) {
        throw const FinanceError(
          'Use at least 12 characters for the new password.',
        );
      }
      if (newPassword == currentPassword) {
        throw const FinanceError(
          'Choose a new password that differs from the current one.',
        );
      }
      final rows = db.rows(
        'SELECT password_hash FROM users WHERE id=? AND active=1',
        [account.id],
      );
      if (rows.isEmpty) {
        throw const FinanceError('Your account is no longer active.');
      }
      previousHash = rows.single['password_hash'] as String;
      if (!await Passwords.verify(currentPassword, previousHash)) {
        throw const FinanceError('The current password is incorrect.');
      }
      newHash = await Passwords.hash(newPassword);
    }

    require('settings');
    if (user!.id != account.id) {
      throw const FinanceError('Your login session changed. Please try again.');
    }
    db.transaction(() {
      if (db.rows(
        'SELECT id FROM users WHERE id=? AND active=1',
        [account.id],
      ).isEmpty) {
        throw const FinanceError('Your account is no longer active.');
      }
      if (profileChanged &&
          db.rows(
            'SELECT id FROM users WHERE username=? COLLATE NOCASE AND id<>?',
            [username, account.id],
          ).isNotEmpty) {
        throw const FinanceError('This username is already in use.');
      }
      if (passwordRequested) {
        final fresh = db.rows(
          'SELECT password_hash FROM users WHERE id=? AND active=1',
          [account.id],
        );
        if (fresh.isEmpty || fresh.single['password_hash'] != previousHash) {
          throw const FinanceError(
            'Account credentials changed. Sign in again before retrying.',
          );
        }
      }
      if (profileChanged) {
        db.connection.execute(
          'UPDATE users SET name=?, username=? WHERE id=?',
          [name, username, account.id],
        );
        _audit('Updated', '', 'Account profile updated', year: manilaNow().year);
      }
      if (passwordRequested) {
        db.connection.execute(
          'UPDATE users SET password_hash=? WHERE id=?',
          [newHash, account.id],
        );
        _audit('Updated', '', 'Account password changed', year: manilaNow().year);
      }
    });
    if (profileChanged) {
      user = LocalUser(account.id, name, username, account.role);
    }
    notifyListeners();
    return true;
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

  List<DbRow> references([String query = '']) {
    const real =
        "length(code) BETWEEN 8 AND 14 AND code NOT GLOB '*[^0-9]*'";
    return query.trim().isEmpty
        ? db.rows('SELECT * FROM uacs_refs WHERE $real ORDER BY code')
        : db.rows(
            'SELECT * FROM uacs_refs WHERE $real AND (code LIKE ? OR name LIKE ?) ORDER BY code',
            ['%${codeKey(query)}%', '%${query.trim()}%'],
          );
  }

  BudgetRecord? byId(int id) {
    final rows = db.rows('SELECT * FROM budget_records WHERE id=?', [id]);
    return rows.isEmpty ? null : BudgetRecord.fromMap(rows.first);
  }

  void _requireCurrentYear(int year) {
    final current = manilaNow().year;
    if (year != current) {
      throw FinanceError(
        'Encoding and Excel import are only allowed for the current fiscal year ($current).',
      );
    }
  }

  void _validate(
    BudgetRecord record, {
    BudgetRecord? previous,
    bool fromImport = false,
  }) {
    _requireCurrentYear(record.year);
    if (fromImport) {
      // Excel import keeps amounts as-is; only accept real UACS budget lines.
      final code = codeKey(record.code);
      if (!RegExp(r'^\d{8,14}$').hasMatch(code)) {
        throw const FinanceError(
          'A budget line must have an 8–14 digit UACS code.',
        );
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
    final uacs = codeKey(record.code);
    if (RegExp(r'^\d{8,14}$').hasMatch(uacs)) {
      db.connection.execute(
        'INSERT OR REPLACE INTO uacs_refs(code,name) VALUES (?,?)',
        [uacs, record.name.trim()],
      );
    }
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
      final identity =
          '${displayCode(codeKey(record.code))} - ${record.name.trim()}';
      var detail = identity;
      if (before != null) {
        final changes = <String>[];
        for (final e in {
          'Allotment': [before.allotment, record.allotment],
          'Obligation': [before.obligation, record.obligation],
          'Disbursement': [before.disbursement, record.disbursement],
        }.entries) {
          if (e.value[0] != e.value[1]) {
            changes.add(
              '${e.key} from ${money(e.value[0])} to ${money(e.value[1])}',
            );
          }
        }
        // Updated: show from→to only; Added: code + name.
        detail = changes.isEmpty ? identity : changes.join('; ');
      }
      _audit(
        record.id == null ? 'Added' : 'Updated',
        '',
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
      _requireCurrentYear(record.year);
      db.connection.execute('DELETE FROM budget_records WHERE id=?', [id]);
      _audit(
        'Deleted',
        '',
        '${displayCode(record.code)} - ${record.name.trim()}',
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
      final program = normalizeProgramCode(payload.first.program);
      final label = (programName ?? program).trim();
      final existing = db.rows('SELECT code FROM programs WHERE code=?', [
        program,
      ]);
      if (existing.isEmpty) {
        if (!validProgramCode(program)) {
          throw const FinanceError(
            'This worksheet name cannot be used as a program code.',
          );
        }
        db.connection.execute(
          'INSERT INTO programs(code,name,active) VALUES (?,?,1)',
          [program, label.isEmpty ? program : label],
        );
        // No per-program audit here — workbook import logs the Excel filename once.
        // An existing program keeps its name, so editing the name does not
        // change the code and a later import does not put them back together.
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
      // Workbook-level audit is written once by logWorkbookImport.
    });
    notifyListeners();
    return count;
  }

  /// One audit row for a whole Excel workbook — filename only in Details.
  void logWorkbookImport({
    required String filename,
    required int year,
  }) {
    require('import');
    final file = filename.trim().isEmpty ? 'workbook.xlsx' : filename.trim();
    _audit(
      'Imported',
      '',
      file,
      year: year,
      program: '',
    );
    notifyListeners();
  }

  void saveProgram(String code, String name, bool active, {String? original}) {
    require('settings');
    code = normalizeProgramCode(code);
    name = name.trim();
    if (!validProgramCode(code) || name.isEmpty) {
      throw const FinanceError(
        'Enter a program name and a code using letters, numbers, and spaces.',
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
      final label = programLabel(code, name);
      _audit(
        original == null ? 'Added' : 'Updated',
        '',
        active ? label : '$label (Inactive)',
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
        '',
        programLabel(code),
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
        original == null ? 'Added' : 'Updated',
        '',
        '${displayCode(code)} - $name',
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
        '',
        '$type ($format)',
        year: year,
        program: program,
      );
    });
    notifyListeners();
  }
}
