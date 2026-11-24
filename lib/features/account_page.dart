import 'package:material_ui/material_ui.dart';

import '../data/finance_store.dart';
import '../ui/common.dart';
import '../ui/theme.dart';

/// Account editor shown over the current page when the profile is clicked.
class AccountDialog extends StatefulWidget {
  const AccountDialog({super.key, required this.store});
  final FinanceStore store;

  @override
  State<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<AccountDialog> {
  late final TextEditingController _name;
  late final TextEditingController _username;
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _saving = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = widget.store.user!;
    _name = TextEditingController(text: user.name);
    _username = TextEditingController(text: user.username);
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _username,
      _currentPassword,
      _newPassword,
      _confirmPassword,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final changed = await widget.store.saveMyAccount(
        name: _name.text,
        username: _username.text,
        currentPassword: _currentPassword.text,
        newPassword: _newPassword.text,
        confirmPassword: _confirmPassword.text,
      );
      if (!mounted) {
        return;
      }
      showMessage(
        context,
        changed ? 'Account changes saved.' : 'No changes to save.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _error = friendlyError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    required Key key,
    bool password = false,
    bool visible = false,
    VoidCallback? toggleVisibility,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FieldLabel(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      ),
      const SizedBox(height: 6),
      TextField(
        key: key,
        controller: controller,
        enabled: !_saving,
        obscureText: password && !visible,
        autocorrect: !password,
        enableSuggestions: !password,
        onChanged: (_) {
          if (_error != null) {
            setState(() => _error = null);
          }
        },
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          hintText: '••••••••',
          suffixIcon: password
              ? IconButton(
                  tooltip: visible ? 'Hide $label' : 'Show $label',
                  onPressed: toggleVisibility,
                  icon: Icon(
                    visible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 19,
                  ),
                )
              : null,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    titlePadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
    title: Stack(
      alignment: Alignment.center,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 44),
          child: Text(
            'My Account',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            key: const ValueKey('account-close'),
            tooltip: 'Close account',
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ),
      ],
    ),
    contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field('Full Name', _name, key: const ValueKey('account-name')),
            const SizedBox(height: 12),
            _field(
              'Username',
              _username,
              key: const ValueKey('account-username'),
            ),
            const SizedBox(height: 14),
            _field(
              'Current Password',
              _currentPassword,
              key: const ValueKey('account-current-password'),
              password: true,
              visible: _showCurrent,
              toggleVisibility: () => setState(() => _showCurrent = !_showCurrent),
            ),
            const SizedBox(height: 12),
            _field(
              'New Password',
              _newPassword,
              key: const ValueKey('account-new-password'),
              password: true,
              visible: _showNew,
              toggleVisibility: () => setState(() => _showNew = !_showNew),
            ),
            const SizedBox(height: 12),
            _field(
              'Confirm New Password',
              _confirmPassword,
              key: const ValueKey('account-confirm-password'),
              password: true,
              visible: _showConfirm,
              toggleVisibility: () => setState(() => _showConfirm = !_showConfirm),
            ),
          ],
        ),
      ),
    ),
    actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
    actionsAlignment: MainAxisAlignment.end,
    actions: [
      SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              Text(
                _error!,
                key: const ValueKey('account-error'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: red, fontSize: 12),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const ValueKey('account-cancel'),
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const ValueKey('account-save'),
                  onPressed: _saving ? null : _saveChanges,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}
