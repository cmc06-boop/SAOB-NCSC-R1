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
      }
      expect(find.text('Settings'), findsNothing);
      expect(find.text('Users'), findsNothing);
      expect(find.text('System'), findsNothing);
      // Audit Trail filters should remain usable after repositioning.
      await tester.tap(find.byKey(const ValueKey('nav-audit')));
      await tester.pumpAndSettle();
      expect(find.text('Fiscal Year:'), findsOneWidget);
      expect(find.text('Program:'), findsOneWidget);
      expect(find.text('Action:'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('nav-programs')));
      await tester.pumpAndSettle();
      expect(find.text('Program Management'), findsNothing);
      expect(find.text('Add Program'), findsOneWidget);
      expect(find.byKey(const ValueKey('programs-table')), findsOneWidget);
      // The action is now aligned with the page subtitle, above the table.
      final programSubtitle = tester.getCenter(
        find.text('Manage programs and their associated names.'),
      );
      final addButton = tester.getCenter(find.text('Add Program'));
      expect((programSubtitle.dy - addButton.dy).abs(), lessThan(26));
      await tester.tap(find.byKey(const ValueKey('nav-uacs')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('uacs-table')), findsOneWidget);
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
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
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

  testWidgets('Profile button above Logout opens My Account form', (
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
    expect(find.text('Personal Information'), findsOneWidget);
    expect(find.text('Change Password'), findsOneWidget);
    expect(find.text('Update your administrator profile and password.'), findsNothing);
    expect(find.byKey(const ValueKey('account-two-columns')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-save')), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Save Profile Changes'), findsNothing);
    expect(find.text('Update Password'), findsNothing);
    expect(
      tester.getCenter(find.text('Personal Information')).dx,
      lessThan(tester.getCenter(find.text('Change Password')).dx),
    );
    // The account form is now two columns with no nested scrolling.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('account-two-columns')),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-name')),
      'New Finance Officer',
    );
    await tester.tap(find.byKey(const ValueKey('account-save')));
    await tester.pumpAndSettle();
    expect(store.user!.name, 'New Finance Officer');
    expect(store.db.rows('SELECT name FROM users').single['name'], 'New Finance Officer');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
