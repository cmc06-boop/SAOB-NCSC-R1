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
      // Side menu icons work both in expanded and compact navigation.
      for (final icon in [
        Icons.account_balance_wallet_outlined,
        Icons.description_outlined,
        Icons.history_outlined,
        Icons.settings_outlined,
      ]) {
        await tester.tap(find.byIcon(icon).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Users'), findsNothing);
      expect(find.text('System'), findsNothing);
      await tester.tap(
        find.byIcon(Icons.account_balance_wallet_outlined).first,
      );
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
}
