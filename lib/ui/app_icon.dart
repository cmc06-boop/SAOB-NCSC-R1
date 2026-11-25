import 'package:material_ui/material_ui.dart';

/// Consistent Material icons without external SVG assets.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.name, {
    super.key,
    this.size = 18,
    this.color,
    this.semanticLabel,
  });

  final String name;
  final double size;
  final Color? color;
  final String? semanticLabel;

  IconData get _symbol => switch (name) {
    'layout-dashboard' => Icons.dashboard_outlined,
    'wallet' => Icons.account_balance_wallet_outlined,
    'file-text' => Icons.description_outlined,
    'history' => Icons.history_rounded,
    'layers-3' => Icons.layers_outlined,
    'book-open' => Icons.menu_book_outlined,
    'database' => Icons.storage_outlined,
    'clipboard-check' => Icons.assignment_turned_in_outlined,
    'clipboard-list' => Icons.assignment_outlined,
    'chart-no-axes-column-increasing' => Icons.bar_chart_rounded,
    'folder-open' => Icons.folder_open_outlined,
    'folder' => Icons.folder_outlined,
    'hourglass' => Icons.hourglass_empty_outlined,
    'eye' => Icons.visibility_outlined,
    'eye-off' => Icons.visibility_off_outlined,
    'log-in' => Icons.login_outlined,
    'log-out' => Icons.logout_outlined,
    'user-round' => Icons.person_outline_rounded,
    'plus' => Icons.add_rounded,
    'pencil' => Icons.edit_outlined,
    'trash-2' => Icons.delete_outline_rounded,
    'download' => Icons.file_download_outlined,
    'search' => Icons.search_rounded,
    'chevron-down' => Icons.keyboard_arrow_down_rounded,
    'chevron-left' => Icons.chevron_left_rounded,
    'chevron-right' => Icons.chevron_right_rounded,
    'arrow-left' => Icons.arrow_back_rounded,
    'x' => Icons.close_rounded,
    'circle' => Icons.radio_button_unchecked,
    'circle-dot' => Icons.radio_button_checked,
    'file-check' => Icons.task_alt_outlined,
    'file-warning' => Icons.report_problem_outlined,
    'lock' => Icons.lock_outline,
    _ => Icons.circle_outlined,
  };

  @override
  Widget build(BuildContext context) => Icon(
    _symbol,
    size: size,
    color: color,
    semanticLabel: semanticLabel,
  );
}
