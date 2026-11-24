import 'package:material_ui/material_ui.dart';

import '../data/finance_store.dart';
import '../features/account_page.dart';
import '../features/audit_page.dart';
import '../features/budget_page.dart';
import '../features/dashboard_page.dart';
import '../features/reports_page.dart';
import '../features/settings_page.dart';
import 'common.dart';
import 'theme.dart';

const _menus = [
  ('dashboard', 'Dashboard', Icons.dashboard_outlined),
  ('budget', 'Budget Utilization', Icons.account_balance_wallet_outlined),
  ('reports', 'Reports', Icons.description_outlined),
  ('audit', 'Audit Trail', Icons.history_outlined),
  ('programs', 'Programs', Icons.category_outlined),
  ('uacs', 'UACS Reference', Icons.menu_book_outlined),
];

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store});
  final FinanceStore store;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String selected = 'dashboard';

  Future<void> openAccount() async {
    if (!widget.store.user!.can('settings')) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AccountDialog(store: widget.store),
    );
  }

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
      'reports': ReportsPage(store: widget.store),
      'audit': AuditPage(store: widget.store),
      'programs': ProgramsPage(store: widget.store),
      'uacs': UacsReferencePage(store: widget.store),
    };
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, c) {
          final expanded = c.maxWidth >= 1060;
          final sideWidth = expanded ? 236.0 : 82.0;
          return Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: EdgeInsets.only(left: sideWidth),
                child: IndexedStack(
                  index: visible.indexWhere((m) => m.$1 == selected),
                  children: [
                    for (final m in visible)
                      KeyedSubtree(key: ValueKey(m.$1), child: widgets[m.$1]!),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: sideWidth,
                child: Container(
                  width: sideWidth,
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(28),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xff0c2a78), navy, Color(0xff04143c)],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            expanded ? 16 : 12,
                            20,
                            expanded ? 16 : 12,
                            16,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 45,
                                height: 45,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Image.asset(
                                  'assets/ncsc-logo-transparent.png',
                                  width: 40,
                                  height: 40,
                                ),
                              ),
                              if (expanded) ...[
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'National Commission of Senior Citizens Region I',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          color: Colors.white12,
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            children: [
                              for (final m in visible)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  child: Tooltip(
                                    message: expanded ? '' : m.$2,
                                    child: Material(
                                      color: selected == m.$1
                                          ? Colors.white.withValues(alpha: 0.14)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        key: ValueKey('nav-${m.$1}'),
                                        borderRadius: BorderRadius.circular(12),
                                        hoverColor: Colors.white.withValues(
                                          alpha: 0.08,
                                        ),
                                        onTap: () =>
                                            setState(() => selected = m.$1),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: expanded ? 12 : 0,
                                            vertical: 13,
                                          ),
                                          child: Row(
                                            mainAxisAlignment: expanded
                                                ? MainAxisAlignment.start
                                                : MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 3,
                                                height: 18,
                                                decoration: BoxDecoration(
                                                  color: selected == m.$1
                                                      ? red
                                                      : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(3),
                                                ),
                                              ),
                                              SizedBox(
                                                width: expanded ? 10 : 0,
                                              ),
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
                                                      fontWeight:
                                                          selected == m.$1
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
                        if (user.can('settings'))
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                            child: Tooltip(
                              message: 'My Account',
                              child: Material(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  key: const ValueKey('nav-account'),
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: openAccount,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 11,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: expanded
                                          ? MainAxisAlignment.start
                                          : MainAxisAlignment.center,
                                      children: [
                                        CircleAvatar(
                                          radius: 15,
                                          backgroundColor: Colors.white,
                                          child: Text(
                                            user.name.trim().isEmpty
                                                ? '?'
                                                : user.name.trim()[0]
                                                    .toUpperCase(),
                                            style: const TextStyle(
                                              color: navy,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        if (expanded) ...[
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  user.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                const Text(
                                                  'My Account',
                                                  style: TextStyle(
                                                    color: Color(0xffc5d4ef),
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            Icons.chevron_right,
                                            color: Colors.white70,
                                            size: 18,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                          child: Material(
                            key: const ValueKey('sidebar-logout'),
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: logout,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.logout,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    if (expanded) ...[
                                      const SizedBox(width: 10),
                                      const Text(
                                        'Logout',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
