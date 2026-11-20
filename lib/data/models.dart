import '../core/format.dart';

typedef DbRow = Map<String, Object?>;

class BudgetRecord {
  const BudgetRecord({
    this.id,
    required this.year,
    required this.program,
    this.fund = 'CURRENT',
    required this.code,
    required this.name,
    required this.allotment,
    this.obligation = 0,
    this.disbursement = 0,
    this.remarks = '',
  });
  final int? id;
  final int year;
  final String program, fund, code, name, remarks;
  final int allotment, obligation, disbursement;
  int get balance => allotment - obligation;

  factory BudgetRecord.fromMap(DbRow r) => BudgetRecord(
    id: r['id'] as int?,
    year: r['year'] as int,
    program: r['program'] as String,
    fund: r['fund_source'] as String,
    code: r['code'] as String,
    name: r['name'] as String,
    allotment: ((r['allotment'] as num) * 100).round(),
    obligation: ((r['obligation'] as num) * 100).round(),
    disbursement: ((r['disbursement'] as num) * 100).round(),
    remarks: (r['remarks'] as String?) ?? '',
  );

  List<Object?> get values => [
    year,
    program,
    fund,
    codeKey(code),
    name.trim(),
    allotment / 100,
    obligation / 100,
    disbursement / 100,
    remarks.trim(),
  ];

  String? get error {
    if (!RegExp(r'^\d{8,14}$').hasMatch(codeKey(code))) {
      return 'Enter an 8–14 digit UACS code.';
    }
    if (name.trim().isEmpty) return 'Enter an expense name.';
    if ([allotment, obligation, disbursement].any((v) => v < 0)) {
      return 'Amounts cannot be negative.';
    }
    if (obligation > allotment) return 'Obligation exceeds the allotment.';
    if (disbursement > obligation) {
      return 'Disbursement exceeds the obligation.';
    }
    return null;
  }

  bool sameAmountsAndText(BudgetRecord other) =>
      name == other.name &&
      allotment == other.allotment &&
      obligation == other.obligation &&
      disbursement == other.disbursement &&
      remarks == other.remarks;
}

class Totals {
  Totals(Iterable<BudgetRecord> rows) {
    for (final row in rows) {
      allotment += row.allotment;
      obligation += row.obligation;
      disbursement += row.disbursement;
    }
  }
  int allotment = 0, obligation = 0, disbursement = 0;
  int get balance => allotment - obligation;
}

class Program {
  const Program(this.code, this.name, this.active);
  final String code, name;
  final bool active;
}

class LocalUser {
  const LocalUser(this.id, this.name, this.username, this.role);
  final int id;
  final String name, username, role;
  factory LocalUser.fromMap(DbRow row) => LocalUser(
    row['id'] as int,
    row['name'] as String,
    row['username'] as String,
    row['role'] as String,
  );
  bool can(String page) =>
      role == 'Admin' ||
      (role == 'Encoder' &&
          [
            'dashboard',
            'budget',
            'import',
            'reports',
            'audit',
          ].contains(page)) ||
      ['dashboard', 'reports', 'audit'].contains(page);
}
