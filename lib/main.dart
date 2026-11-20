import 'package:material_ui/material_ui.dart';

import 'core/format.dart';
import 'data/database.dart';
import 'data/finance_store.dart';
import 'features/login_page.dart';
import 'ui/app_shell.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    runApp(FinanceApp(store: FinanceStore(FinanceDatabase.open())));
  } catch (e) {
    runApp(
      MaterialApp(
        title: windowTitle,
        theme: appTheme(),
        home: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_off_outlined, size: 48, color: red),
                    const SizedBox(height: 18),
                    const Text(
                      'The local database could not be opened.',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      e is FinanceError ? e.message : 'Close any other copy of the app, check that your local app data folder is writable, and reopen the application.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FinanceApp extends StatefulWidget {
  const FinanceApp({super.key, required this.store});
  final FinanceStore store;
  @override
  State<FinanceApp> createState() => _FinanceAppState();
}

class _FinanceAppState extends State<FinanceApp> {
  @override
  void dispose() {
    widget.store.dispose();
    widget.store.db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: windowTitle,
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    home: ListenableBuilder(
      listenable: widget.store,
      builder: (ctx, child) => widget.store.user == null
          ? LoginPage(store: widget.store)
          : AppShell(store: widget.store),
    ),
  );
}
