import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ncsc_region1_finance/core/format.dart';
import 'package:ncsc_region1_finance/data/database.dart';
import 'package:ncsc_region1_finance/data/finance_store.dart';
import 'package:ncsc_region1_finance/data/models.dart';
import 'package:ncsc_region1_finance/main.dart';
import 'package:ncsc_region1_finance/ui/common.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  FinanceStore createStore() {
    final db = FinanceDatabase.open(path: ':memory:');
    db.connection.execute(
      "INSERT INTO users(name,username,password_hash,role,active) VALUES ('AO','ao','test-only','Admin',1)",
    );
    return FinanceStore(db);
  }

  for (final message in [
    'Select a record to edit.',
    'This is a longer instruction explaining that a valid record must be selected before an action can be completed in the finance system.',
  ]) {
    testWidgets('notifications are white, wider, and raised at lower right: $message', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1366, 720);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showMessage(context, message),
                child: const Text('Show instruction'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show instruction'));
      await tester.pump();
      final toast = tester.widget<SnackBar>(find.byType(SnackBar));
      final margin = toast.margin! as EdgeInsets;
      final viewportWidth = tester.getSize(find.byType(Scaffold)).width;
      expect(viewportWidth, 1366);
      final toastWidth = viewportWidth - margin.left - margin.right;
      expect(toast.behavior, SnackBarBehavior.floating);
      expect(toast.backgroundColor, Colors.white);
      expect(toast.elevation, 5);
      expect(margin.right, 48);
      expect(margin.bottom, 48);
      expect(toastWidth, inInclusiveRange(320, 540));
      expect(
        toast.padding,
        const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      );
      final content = toast.content as Text;
      expect(content.style?.color, const Color(0xff132951));
      // Flutter widget tests use the Ahem font, so even a short message
      // can measure wider than the 320 px minimum.
      if (message == 'Select a record to edit.') {
        expect(toastWidth, lessThan(400));
      } else {
        expect(toastWidth, greaterThan(400));
      }
      expect(margin.left + toastWidth + margin.right, viewportWidth);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('notification uses compact side spacing on narrower windows', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 640);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMessage(context, 'Please select a record.', error: true),
              child: const Text('Show error'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show error'));
    await tester.pump();
    final toast = tester.widget<SnackBar>(find.byType(SnackBar));
    final margin = toast.margin! as EdgeInsets;
    expect(tester.getSize(find.byType(Scaffold)).width, 400);
    expect(margin.left, greaterThanOrEqualTo(16));
    expect(margin.right, 20);
    expect(margin.bottom, 48);
    expect(toast.backgroundColor, Colors.white);
    expect((toast.content as Text).style?.color, const Color(0xffd42035));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

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
      expect(
        TooltipVisibility.of(
          tester.element(find.byKey(const ValueKey('Password'))),
        ),
        isFalse,
      );
      expect(password.obscureText, isTrue);
      // TooltipVisibility is disabled globally; locate the actual icon.
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
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
      // All hover tooltips stay hidden in the app (including its sidebar,
      // dropdowns, table cells, and icon controls).
      expect(
        TooltipVisibility.of(
          tester.element(find.byKey(const ValueKey('nav-budget'))),
        ),
        isFalse,
      );
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
      // Hover labels are hidden, so use visible action icons instead.
      final edit = find.descendant(
        of: programsTable,
        matching: find.byIcon(Icons.edit_outlined),
      ).first;
      final delete = find.descendant(
        of: programsTable,
        matching: find.byIcon(Icons.delete_outline),
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

      // The back arrow precedes Report Preview, and Export occupies
      // the previous back-arrow position at the far right of the heading.
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
      final backPosition = tester.getCenter(
        find.byKey(const ValueKey('reports-back')),
      );
      final previewTitlePosition = tester.getCenter(find.text('Report Preview'));
      final exportPosition = tester.getCenter(
        find.byKey(const ValueKey('reports-export')),
      );
      expect(backPosition.dx, lessThan(previewTitlePosition.dx));
      expect(exportPosition.dx, greaterThan(previewTitlePosition.dx));
      expect((backPosition.dy - previewTitlePosition.dy).abs(), lessThan(24));
      expect((exportPosition.dy - previewTitlePosition.dy).abs(), lessThan(24));
      expect(exportPosition.dx, greaterThan(tester.getCenter(find.text('Report Parameters')).dx));
      await tester.tap(find.byKey(const ValueKey('reports-back')));
      await tester.pumpAndSettle();
      expect(find.text('Generate Report'), findsOneWidget);
      expect(find.byKey(const ValueKey('reports-export')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('nav-budget')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Record'));
      await tester.pumpAndSettle();
      expect(find.text('Add Budget Record'), findsOneWidget);
      expect(find.byKey(const ValueKey('budget-record-dialog')), findsOneWidget);
      final recordScroll = tester.widget<SingleChildScrollView>(
        find.byKey(const ValueKey('budget-record-dialog-scroll')),
      );
      final recordPadding = recordScroll.padding! as EdgeInsets;
      expect(recordPadding.bottom, 24);
      final recordMinSize = tester.widget<ConstrainedBox>(
        find.byKey(const ValueKey('budget-record-dialog-size')),
      );
      expect(recordMinSize.constraints.minHeight, 500);
      expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
      expect(find.text('Save Record'), findsNothing);
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
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('sidebar-account-name'))).data,
      'Finance AO',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('sidebar-account-username'))).data,
      'ao',
    );
    expect(find.text('My Account'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('nav-account')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    // Target the dialog heading itself, not the sidebar's profile labels.
    final accountTitle = find.byKey(const ValueKey('account-title'));
    expect(accountTitle, findsOneWidget);
    expect(tester.widget<Text>(accountTitle).textAlign, TextAlign.center);
    expect(
      (tester.getCenter(accountTitle).dx -
              tester.getCenter(find.byType(AlertDialog)).dx)
          .abs(),
      lessThan(8),
    );
    expect(find.byKey(const ValueKey('account-close')), findsOneWidget);
    expect(find.text('Personal Information'), findsNothing);
    final nameField = tester.widget<TextField>(
      find.byKey(const ValueKey('account-name')),
    );
    final usernameField = tester.widget<TextField>(
      find.byKey(const ValueKey('account-username')),
    );
    expect(nameField.decoration?.hintText, 'Juan Dela Cruz');
    expect(usernameField.decoration?.hintText, 'juandelacruz');
    expect(nameField.decoration?.hintStyle?.color, const Color(0xff888888));
    expect(usernameField.decoration?.hintStyle?.color, const Color(0xff888888));
    // Hints appear only when blank, never replace the user's saved values.
    expect(nameField.controller?.text, 'Finance AO');
    expect(usernameField.controller?.text, 'ao');
    for (final key in [
      'account-current-password',
      'account-new-password',
      'account-confirm-password',
    ]) {
      final field = tester.widget<TextField>(find.byKey(ValueKey(key)));
      expect(field.decoration?.hintText, '••••••••');
      expect(field.obscureText, isTrue);
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
    expect(find.byKey(const ValueKey('account-cancel')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    expect(
      tester.widget<AlertDialog>(find.byType(AlertDialog)).actionsAlignment,
      MainAxisAlignment.end,
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('account-cancel'))).dx,
      lessThan(tester.getCenter(find.byKey(const ValueKey('account-save'))).dx),
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('account-save'))).dy,
      greaterThan(tester.getCenter(find.byKey(const ValueKey('account-confirm-password'))).dy),
    );
    expect(find.text('Save Changes'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byKey(const ValueKey('account-save'))).child,
      isA<Text>(),
    );
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

  testWidgets('My Account Cancel closes without saving changes', (tester) async {
    await binding.setSurfaceSize(const Size(1366, 720));
    addTearDown(() => binding.setSurfaceSize(null));
    final store = createStore()
      ..user = const LocalUser(1, 'Finance AO', 'ao', 'Admin');
    await tester.pumpWidget(FinanceApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-account')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('account-name')),
      'Unsaved Name',
    );
    await tester.tap(find.byKey(const ValueKey('account-cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(store.user!.name, 'Finance AO');
    expect(
      store.db.rows('SELECT name FROM users').single['name'],
      'AO',
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
    expect(find.byKey(const ValueKey('sidebar-account-name')), findsNothing);
    expect(find.byKey(const ValueKey('sidebar-account-username')), findsNothing);
    expect(find.byKey(const ValueKey('account-save')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('account-close')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Logout modal matches the centered gradient reference layout', (
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

    final dialog = find.byKey(const ValueKey('logout-dialog'));
    expect(dialog, findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Log Out?'), findsOneWidget);
    expect(find.text('Are you sure you want to log out?'), findsOneWidget);
    expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
    expect(find.byKey(const ValueKey('logout-cancel')), findsOneWidget);
    expect(find.byKey(const ValueKey('logout-accept')), findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.text('Logout')),
      findsOneWidget,
    );
    final surface = tester.widget<Container>(
      find.byKey(const ValueKey('logout-surface')),
    );
    expect((surface.decoration as BoxDecoration).gradient, isA<LinearGradient>());
    expect(tester.widget<Text>(find.text('Log Out?')).textAlign,
        TextAlign.center);
    expect(
      tester.getCenter(find.byKey(const ValueKey('logout-cancel'))).dx,
      lessThan(tester.getCenter(find.byKey(const ValueKey('logout-accept'))).dx),
    );

    // Cancel leaves the current session active.
    await tester.tap(find.byKey(const ValueKey('logout-cancel')));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(store.user, isNotNull);

    // Dismissing the popup also keeps the session active.
    await tester.tap(find.byKey(const ValueKey('sidebar-logout')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(12, 12));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(store.user, isNotNull);

    // Only the blue Logout button ends the session.
    await tester.tap(find.byKey(const ValueKey('sidebar-logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('logout-accept')));
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
    final codeField = tester.widget<TextField>(
      find.byKey(const ValueKey('reference-editor-code')),
    );
    final nameField = tester.widget<TextField>(
      find.byKey(const ValueKey('reference-editor-name')),
    );
    expect(codeField.decoration?.hintText, 'GAS');
    expect(nameField.decoration?.hintText, 'General Administrative Services');
    expect(codeField.decoration?.hintStyle?.color, const Color(0xff888888));
    expect(nameField.decoration?.hintStyle?.color, const Color(0xff888888));
    expect(codeField.controller?.text, isEmpty);
    expect(nameField.controller?.text, isEmpty);
    expect(find.byKey(const ValueKey('reference-editor-cancel')), findsOneWidget);
    expect(find.byKey(const ValueKey('reference-editor-save')), findsOneWidget);
    final programDialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(programDialog.actionsAlignment, MainAxisAlignment.end);
    final dialogTitle = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Add Program'),
    );
    expect(tester.widget<Text>(dialogTitle).textAlign, TextAlign.center);
    final programSave = find.byKey(const ValueKey('reference-editor-save'));
    expect(tester.widget<FilledButton>(programSave).child, isA<Text>());
    expect(
      tester.getCenter(find.byKey(const ValueKey('reference-editor-cancel'))).dx,
      lessThan(tester.getCenter(programSave).dx),
    );
    expect(
      tester.getCenter(programSave).dy,
      greaterThan(tester.getCenter(find.byKey(const ValueKey('reference-editor-name'))).dy),
    );
    expect(find.byIcon(Icons.save_outlined), findsNothing);

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
