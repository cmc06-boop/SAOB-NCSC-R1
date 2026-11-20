import 'package:material_ui/material_ui.dart';

import '../data/finance_store.dart';
import '../features/audit_page.dart';
import '../features/budget_page.dart';
import '../features/dashboard_page.dart';
import '../features/import_page.dart';
import '../features/reports_page.dart';
import '../features/settings_page.dart';
import 'common.dart';
import 'theme.dart';

const _menus = [
  ('dashboard', 'Dashboard', Icons.dashboard_outlined),
  ('budget', 'Budget Utilization', Icons.account_balance_wallet_outlined),
  ('import', 'Import Records', Icons.upload_file_outlined),
  ('reports', 'Reports', Icons.description_outlined),
  ('audit', 'Audit Trail', Icons.history_outlined),
  ('settings', 'Settings', Icons.settings_outlined),
];

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store});
  final FinanceStore store;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String selected = 'dashboard';
  Future<void> logout() async {
    if (await confirm(context, 'Log out?', 'Return to the login screen?')) {
      widget.store.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.store.user!,
        visible = _menus.where((m) => user.can(m.$1)).toList();
    final widgets = <String, Widget>{
      'dashboard': DashboardPage(store: widget.store),
      'budget': BudgetPage(store: widget.store),
      'import': ImportPage(store: widget.store),
      'reports': ReportsPage(store: widget.store),
      'audit': AuditPage(store: widget.store),
      'settings': SettingsPage(store: widget.store),
    };
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, c) {
          final expanded = c.maxWidth >= 1060;
          return Row(
            children: [
              Container(
                width: expanded ? 226 : 82,
                color: navy,
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: expanded ? 20 : 12,
                          vertical: 24,
                        ),
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/ncsc-logo-transparent.png',
                              width: 48,
                              height: 48,
                            ),
                            if (expanded) ...[
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'NCSC-R1',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      'Budget and Finance',
                                      style: TextStyle(
                                        color: Color(0xffaabedf),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(height: 1, color: Colors.white12),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView(
                          children: [
                            for (final m in visible)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                child: Tooltip(
                                  message: expanded ? '' : m.$2,
                                  child: Material(
                                    color: selected == m.$1
                                        ? blue
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () =>
                                          setState(() => selected = m.$1),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: selected == m.$1
                                              ? const Border(
                                                  left: BorderSide(
                                                    color: red,
                                                    width: 3,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: expanded ? 14 : 13,
                                          vertical: 18,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              m.$3,
                                              color: Colors.white,
                                              size: 21,
                                            ),
                                            if (expanded) ...[
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  m.$2,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight: selected == m.$1
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: TextButton(
                          onPressed: logout,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.logout,
                                size: 20,
                                color: Colors.white,
                              ),
                              if (expanded) ...[
                                const SizedBox(width: 12),
                                const Text(
                                  'Logout',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 62,
                      padding: const EdgeInsets.symmetric(horizontal: 26),
                      color: Colors.white,
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Statement of Allotments, Obligations, and Balances',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: navy,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            Icons.account_circle_outlined,
                            color: blue,
                            size: 26,
                          ),
                          const SizedBox(width: 9),
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: IndexedStack(
                        index: visible.indexWhere((m) => m.$1 == selected),
                        children: [
                          for (final m in visible)
                            KeyedSubtree(
                              key: ValueKey(m.$1),
                              child: widgets[m.$1]!,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
