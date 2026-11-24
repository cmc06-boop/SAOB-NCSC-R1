import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../data/finance_store.dart';
import '../ui/common.dart';
import '../ui/theme.dart';

/// Accessible from the profile button above Logout.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.store});
  final FinanceStore store;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Account',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: ink,
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Manage your profile details and password.',
          style: TextStyle(fontSize: 14, color: muted, height: 1.35),
        ),
        const SizedBox(height: 22),
        Expanded(child: _AccountSettings(store: store)),
      ],
    ),
  );
}

class _AccountSettings extends StatefulWidget {
  const _AccountSettings({required this.store});
  final FinanceStore store;

  @override
  State<_AccountSettings> createState() => _AccountSettingsState();
}

class _AccountSettingsState extends State<_AccountSettings> {
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
    if (_saving) return;
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
      if (!mounted) return;
      if (changed) {
        _name.text = widget.store.user!.name;
        _username.text = widget.store.user!.username;
        _currentPassword.clear();
        _newPassword.clear();
        _confirmPassword.clear();
      }
      showMessage(context, changed ? 'Account changes saved.' : 'No changes to save.');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
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
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          hintText: label,
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

  Widget _personalInformation() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Personal Information',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ink),
      ),
      const SizedBox(height: 18),
      _field('Full Name', _name, key: const ValueKey('account-name')),
      const SizedBox(height: 16),
      _field('Username', _username, key: const ValueKey('account-username')),
    ],
  );

  Widget _passwordInformation() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Change Password',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ink),
      ),
      const SizedBox(height: 7),
      const Text(
        'Leave these fields blank if you are only updating your profile.',
        style: TextStyle(fontSize: 12, color: muted),
      ),
      const SizedBox(height: 16),
      _field(
        'Current Password',
        _currentPassword,
        key: const ValueKey('account-current-password'),
        password: true,
        visible: _showCurrent,
        toggleVisibility: () => setState(() => _showCurrent = !_showCurrent),
      ),
      const SizedBox(height: 13),
      _field(
        'New Password',
        _newPassword,
        key: const ValueKey('account-new-password'),
        password: true,
        visible: _showNew,
        toggleVisibility: () => setState(() => _showNew = !_showNew),
      ),
      const SizedBox(height: 13),
      _field(
        'Confirm New Password',
        _confirmPassword,
        key: const ValueKey('account-confirm-password'),
        password: true,
        visible: _showConfirm,
        toggleVisibility: () => setState(() => _showConfirm = !_showConfirm),
      ),
      const SizedBox(height: 10),
      const Text(
        'Use at least 12 characters for a new password.',
        style: TextStyle(fontSize: 12, color: muted),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Panel(
    padding: 24,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Row(
            key: const ValueKey('account-two-columns'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _personalInformation()),
              const SizedBox(width: 28),
              Container(width: 1, color: line),
              const SizedBox(width: 28),
              Expanded(child: _passwordInformation()),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: red, fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        Center(
          child: FilledButton.icon(
            key: const ValueKey('account-save'),
            onPressed: _saving ? null : _saveChanges,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save Changes'),
          ),
        ),
      ],
    ),
  );
}
