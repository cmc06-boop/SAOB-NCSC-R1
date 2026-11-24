import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ncsc_region1_finance/core/format.dart';
import 'package:ncsc_region1_finance/data/database.dart';
import 'package:ncsc_region1_finance/data/finance_store.dart';
import 'package:ncsc_region1_finance/data/models.dart';
import 'package:ncsc_region1_finance/main.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  FinanceStore createStore() {
    final db = FinanceDatabase.open(path: ':memory:');
    db.connection.execute(
      "INSERT INTO users(name,username,password_hash,role,active) VALUES ('AO','ao','test-only','Admin',1)",
    );
    return FinanceStore(db);
  }

  for (final size in const [
    Size(1000, 620),
    Size(1366, 720),
    Size(1920, 1080),
  ]) {
    testWidgets('login fits ${size.width} × ${size.height}', (tester) async {
      await binding.setSurfaceSize(size);
      addTearDown(() => binding.setSurfaceSize(null));
      final store = createStore();
      await tester.pumpWidget(FinanceApp(store: store));
      await tester.pumpAndSettle();
      expect(find.text('System Login'), findsOneWidget);
      expect(find.text('Set Up Account'), findsNothing);
      expect(find.text('Create Account'), findsNothing);
      expect(find.text('Forgot Password?'), findsNothing);
      expect(find.text('NCSC-R1'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      final password = tester.widget<TextField>(
        find.byKey(const ValueKey('Password')),
      );
      expect(password.obscureText, isTrue);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('Password')))
            .obscureText,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final size in const [
    Size(1000, 650),
    Size(1366, 720),
    Size(1920, 1080),
  ]) {
    testWidgets('all menus render populated records at ${size.width}', (
      tester,
    ) async {
      await binding.setSurfaceSize(size);
      addTearDown(() => binding.setSurfaceSize(null));
      final store = createStore()
        ..user = const LocalUser(1, 'Finance AO', 'ao', 'Admin');
      store.db.connection.execute(
        "INSERT INTO programs(code,name,active) VALUES ('GAS','GAS',1),('ECA','ECA',1)",
      );
      for (var i = 0; i < 16; i++) {
        store.saveRecord(
          BudgetRecord(
            year: manilaNow().year,
            program: i.isEven ? 'GAS' : 'ECA',
            code: '502010${(1000 + i).toString()}',
            name: 'Expense item $i',
            allotment: 10000000 + i,
            obligation: 3000000,
            disbursement: 2000000,
          ),
        );
      }
      store.logReport('Budget Utilization Report', manilaNow().year, '', 'PDF');
      await tester.pumpWidget(FinanceApp(store: store));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Sidebar Logout has no filled background at wide or compact widths.
      expect(find.byKey(const ValueKey('sidebar-logout')), findsOneWidget);
      expect(
        tester.widget<Material>(
          find.byKey(const ValueKey('sidebar-logout')),
        ).color,
        Colors.transparent,
      );
      // The Programs and UACS Reference views are separate sidebar pages.
      // Stable keys also work when the sidebar is collapsed.
      for (final page in [
        'budget',
        'reports',
        'audit',
        'programs',
        'uacs',
      ]) {
        await tester.tap(find.byKey(ValueKey('nav-$page')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final header = switch (page) {
          'budget' => 'UACS Code',
          'reports' => 'Report Name',
          'audit' => 'Details',
          'programs' => 'Program Name',
          'uacs' => 'UACS Code',
          _ => '',
        };
        expect(
          tester.widget<Text>(find.text(header)).textAlign,
          TextAlign.center,
          reason: '$page table header should be centered',
        );
      }
      // Verify that generated report values, not only headers, are centered.
      await tester.tap(find.byKey(const ValueKey('nav-reports')));
      await tester.pumpAndSettle();
      final reportEntry = store.reportHistory.first;
      final reportBody = find.byType(Table).last;
      final yearValue = find.descendant(
        of: reportBody,
        matching: find.text('${reportEntry['year']}'),
      );
      final generatedAt = find.descendant(
        of: reportBody,
        matching: find.text(dateLabel(reportEntry['at'])),
      );
      expect(tester.widget<Text>(yearValue).textAlign, TextAlign.center);
      expect(tester.widget<Text>(generatedAt).textAlign, TextAlign.center);
      expect(find.text('Settings'), findsNothing);
      expect(find.text('Users'), findsNothing);
      expect(find.text('System'), findsNothing);
      // Audit Trail filters should remain usable after repositioning.
      await tester.tap(find.byKey(const ValueKey('nav-audit')));
      await tester.pumpAndSettle();
      expect(find.text('Fiscal Year:'), findsOneWidget);
      expect(find.text('Program:'), findsOneWidget);
      expect(find.text('Action:'), findsOneWidget);
      final firstAudit = store.auditRows(manilaNow().year).first;
      expect(
        tester.widget<Text>(find.text(dateOnly(firstAudit['at'])).first).textAlign,
        TextAlign.center,
      );
      expect(
        tester.widget<Text>(find.text(timeOnly(firstAudit['at'])).first).textAlign,
        TextAlign.center,
      );
      expect(
        tester.widget<Text>(find.text('${firstAudit['action']}').first).textAlign,
        TextAlign.center,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('nav-programs')));
      await tester.pumpAndSettle();
      expect(find.text('Program Management'), findsNothing);
      expect(find.text('Add Program'), findsOneWidget);
      expect(find.byKey(const ValueKey('programs-table')), findsOneWidget);
      final programsTable = find.byKey(const ValueKey('programs-table'));
      final firstProgramCode = find.descendant(
        of: programsTable,
        matching: find.text(store.programs.first.code),
      ).first;
      final programNumber = find.descendant(
        of: programsTable,
        matching: find.text('1'),
      ).first;
      expect(
        (tester.getCenter(firstProgramCode).dx -
                tester.getCenter(find.text('Code')).dx)
            .abs(),
        lessThan(8),
      );
      expect(
        (tester.getCenter(programNumber).dx -
                tester.getCenter(find.text('#')).dx)
            .abs(),
        lessThan(8),
      );
      final edit = find.descendant(
        of: programsTable,
        matching: find.byTooltip('Edit'),
      ).first;
      final delete = find.descendant(
        of: programsTable,
        matching: find.byTooltip('Delete'),
      ).first;
      final actionsCenter =
          (tester.getCenter(edit).dx + tester.getCenter(delete).dx) / 2;
      expect(
        (actionsCenter - tester.getCenter(find.text('Actions')).dx).abs(),
        lessThan(8),
      );
      final programHeader = tester.widget<Table>(
        find.descendant(of: programsTable, matching: find.byType(Table)).first,
      );
      expect(
        (programHeader.columnWidths![3] as FixedColumnWidth).value,
        160,
      );
      // Programs must keep its original compact number column.
      expect(
        (programHeader.columnWidths![0] as FixedColumnWidth).value,
        48,
      );
      // The action is now aligned with the page subtitle, above the table.
      final programSubtitle = tester.getCenter(
        find.text('Manage programs and their associated names.'),
      );
      final addButton = tester.getCenter(find.text('Add Program'));
      expect((programSubtitle.dy - addButton.dy).abs(), lessThan(26));
      await tester.tap(find.byKey(const ValueKey('nav-uacs')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('uacs-table')), findsOneWidget);
      final uacsTable = find.byKey(const ValueKey('uacs-table'));
      final uacsHeader = tester.widget<Table>(
        find.descendant(of: uacsTable, matching: find.byType(Table)).first,
      );
      expect(
        (uacsHeader.columnWidths![0] as FixedColumnWidth).value,
        80,
      );
      expect(
        (uacsHeader.columnWidths![1] as FixedColumnWidth).value,
        240,
      );
      final firstUacs = find.descendant(
        of: uacsTable,
        matching: find.text(
          displayCode(store.references().first['code'] as String),
        ),
      ).first;
      final uacsNumber = find.descendant(
        of: uacsTable,
        matching: find.text('1'),
      ).first;
      expect(
        (tester.getCenter(firstUacs).dx -
                tester.getCenter(find.text('UACS Code')).dx)
            .abs(),
        lessThan(8),
      );
      expect(
        (tester.getCenter(uacsNumber).dx -
                tester.getCenter(find.text('#')).dx)
            .abs(),
        lessThan(8),
      );
      expect(find.byKey(const ValueKey('uacs-search')), findsOneWidget);
      final uacsSubtitle = tester.getCenter(
        find.text('Browse and search UACS reference codes and expense names.'),
      );
      final searchPosition = tester.getCenter(
        find.byKey(const ValueKey('uacs-search')),
      );
      expect((uacsSubtitle.dy - searchPosition.dy).abs(), lessThan(34));
      expect(searchPosition.dx, greaterThan(uacsSubtitle.dx));

      // Preview export is at the bottom of Report Parameters. The old
      // export location is now an icon-only back control.
      await tester.tap(find.byKey(const ValueKey('nav-reports')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate Report'));
      await tester.pumpAndSettle();
      expect(find.text('Report Parameters'), findsOneWidget);
      expect(find.text('Report Preview'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Expense (UACS Name)')).textAlign,
        TextAlign.center,
      );
      expect(find.byKey(const ValueKey('reports-export')), findsOneWidget);
      expect(find.byKey(const ValueKey('reports-back')), findsOneWidget);
      expect(
        tester.getCenter(find.byKey(const ValueKey('reports-export'))).dy,
        greaterThan(tester.getCenter(find.text('Report Parameters')).dy + 60),
      );
      expect(
        tester.getCenter(find.byKey(const ValueKey('reports-export'))).dx,
        lessThan(tester.getCenter(find.text('Report Preview')).dx),
      );
      await tester.tap(find.byKey(const ValueKey('reports-back')));
      await tester.pumpAndSettle();
      expect(find.text('Generate Report'), findsOneWidget);
      expect(find.byKey(const ValueKey('reports-export')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('nav-budget')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Record'));
      await tester.pumpAndSettle();
      expect(find.text('Add Budget Record'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // On compact windows the dialog body scrolls, so bring Cancel
      // on-screen before tapping it rather than tapping an obscured widget.
      final cancel = find.widgetWithText(TextButton, 'Cancel');
      await tester.ensureVisible(cancel);
      await tester.pumpAndSettle();
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.text('Add Budget Record'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Fresh installation shows maintenance notice, not sign up', (
    tester,
  ) async {
    await binding.setSurfaceSize(const Size(1366, 720));
    addTearDown(() => binding.setSurfaceSize(null));
    final store = FinanceStore(FinanceDatabase.open(path: ':memory:'));
    await tester.pumpWidget(FinanceApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('System Login'), findsOneWidget);
    expect(
      find.textContaining('No Admin account is configured'),
      findsOneWidget,
    );
    expect(find.text('Create Account'), findsNothing);
    expect(find.text('Forgot Password?'), findsNothing);
    final login = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Login'),
    );
    expect(login.onPressed, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Profile button opens a single-column My Account dialog', (
    tester,
  ) async {
    await binding.setSurfaceSize(const Size(1366, 720));
    addTearDown(() => binding.setSurfaceSize(null));
    final store = createStore()
      ..user = const LocalUser(1, 'Finance AO', 'ao', 'Admin');
    await tester.pumpWidget(FinanceApp(store: store));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('nav-account')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-account')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Personal Information'), findsNothing);
    for (final key in [
      'account-name',
      'account-username',
      'account-current-password',
      'account-new-password',
      'account-confirm-password',
    ]) {
      final field = tester.widget<TextField>(find.byKey(ValueKey(key)));
      expect(field.decoration?.hintText, '••••••••');
    }
    expect(find.text('Change Password'), findsNothing);
    expect(
      find.textContaining('Leave these fields blank'),
      findsNothing,
    );
    expect(
      find.textContaining('Use at least 12 characters for a new password'),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('account-two-columns')), findsNothing);
    expect(find.byKey(const ValueKey('account-save')), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Save Profile Changes'), findsNothing);
    expect(find.text('Update Password'), findsNothing);

    final namePosition =
        tester.getCenter(find.byKey(const ValueKey('account-name')));
    final usernamePosition =
        tester.getCenter(find.byKey(const ValueKey('account-username')));
    final passwordPosition =
        tester.getCenter(find.byKey(const ValueKey('account-current-password')));
    expect(namePosition.dy, lessThan(usernamePosition.dy));
    expect(usernamePosition.dy, lessThan(passwordPosition.dy));

    // Validation is shown in red on the dialog, rather than as a permanent
    // password-length helper. The modal stays open if the save fails.
    await tester.enterText(
      find.byKey(const ValueKey('account-current-password')),
      'current-pass',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-new-password')),
      'short',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-confirm-password')),
      'short',
    );
    await tester.tap(find.byKey(const ValueKey('account-save')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byKey(const ValueKey('account-error')), findsOneWidget);
    expect(find.textContaining('at least 12 characters'), findsOneWidget);
    expect(store.user!.name, 'Finance AO');

    // A profile-only change still saves when password fields are left blank.
    for (final key in [
      'account-current-password',
      'account-new-password',
      'account-confirm-password',
    ]) {
      await tester.enterText(find.byKey(ValueKey(key)), '');
    }
    await tester.enterText(
      find.byKey(const ValueKey('account-name')),
      'New Finance Officer',
    );
    await tester.tap(find.byKey(const ValueKey('account-save')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(store.user!.name, 'New Finance Officer');
    expect(
      store.db.rows('SELECT name FROM users').single['name'],
      'New Finance Officer',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Account dialog opens and closes in compact window', (
    tester,
  ) async {
    await binding.setSurfaceSize(const Size(1000, 650));
    addTearDown(() => binding.setSurfaceSize(null));
    final store = createStore()
      ..user = const LocalUser(1, 'Finance AO', 'ao', 'Admin');
    await tester.pumpWidget(FinanceApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-account')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byKey(const ValueKey('account-save')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('account-close')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Logout uses the consistent modal with Close, Cancel, and Log out', (
    tester,
  ) async {
    await binding.setSurfaceSize(const Size(1366, 720));
    addTearDown(() => binding.setSurfaceSize(null));
    final store = createStore()
      ..user = const LocalUser(1, 'Finance AO', 'ao', 'Admin');
    await tester.pumpWidget(FinanceApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sidebar-logout')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Log out?'), findsOneWidget);
    expect(find.text('Return to the login screen?'), findsOneWidget);
    expect(find.byKey(const ValueKey('confirm-close')), findsOneWidget);
    expect(find.byKey(const ValueKey('confirm-cancel')), findsOneWidget);
    expect(find.byKey(const ValueKey('confirm-accept')), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);

    // Cancel keeps the user signed in.
    await tester.tap(find.byKey(const ValueKey('confirm-cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(store.user, isNotNull);

    // Closing with X also keeps the session.
    await tester.tap(find.byKey(const ValueKey('sidebar-logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-close')));
    await tester.pumpAndSettle();
    expect(store.user, isNotNull);
    expect(find.byType(AlertDialog), findsNothing);

    // Confirming signs the user out.
    await tester.tap(find.byKey(const ValueKey('sidebar-logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-accept')));
    await tester.pumpAndSettle();
    expect(store.user, isNull);
    expect(find.text('System Login'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Add Program popup matches account layout and saves a program', (
    tester,
  ) async {
    await binding.setSurfaceSize(const Size(1366, 720));
    addTearDown(() => binding.setSurfaceSize(null));
    final store = createStore()
      ..user = const LocalUser(1, 'Finance AO', 'ao', 'Admin');
    await tester.pumpWidget(FinanceApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-programs')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Program'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byKey(const ValueKey('reference-editor-close')), findsOneWidget);
    expect(find.byKey(const ValueKey('reference-editor-code')), findsOneWidget);
    expect(find.byKey(const ValueKey('reference-editor-name')), findsOneWidget);
    expect(find.byKey(const ValueKey('reference-editor-cancel')), findsOneWidget);
    expect(find.byKey(const ValueKey('reference-editor-save')), findsOneWidget);

    // Close without saving, then reopen to validate and save.
    await tester.tap(find.byKey(const ValueKey('reference-editor-close')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text('Add Program'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reference-editor-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reference-editor-error')), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('reference-editor-code')),
      'TESTP',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reference-editor-name')),
      'Test Program',
    );
    await tester.tap(find.byKey(const ValueKey('reference-editor-save')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(store.programs.any((p) => p.code == 'TESTP'), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
