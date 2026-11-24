import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../data/finance_store.dart';
import '../ui/common.dart';
import '../ui/theme.dart';

/// Dedicated profile page reached from the profile control above Logout.
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
  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  String? _profileError;
  String? _passwordError;

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

  Future<void> _saveProfile() async {
    if (_savingProfile || _savingPassword) return;
    setState(() {
      _savingProfile = true;
      _profileError = null;
    });
    try {
      widget.store.updateMyProfile(_name.text, _username.text);
      if (mounted) showMessage(context, 'Account profile updated.');
    } catch (e) {
      if (mounted) setState(() => _profileError = friendlyError(e));
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _savePassword() async {
    if (_savingPassword || _savingProfile) return;
    setState(() {
      _savingPassword = true;
      _passwordError = null;
    });
    try {
      if (_newPassword.text != _confirmPassword.text) {
        throw const FinanceError('New passwords do not match.');
      }
      await widget.store.changeMyPassword(
        _currentPassword.text,
        _newPassword.text,
      );
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      if (mounted) showMessage(context, 'Password changed successfully.');
    } catch (e) {
      if (mounted) setState(() => _passwordError = friendlyError(e));
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
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
        controller: controller,
        enabled: !_savingProfile && !_savingPassword,
        obscureText: password && !visible,
        autocorrect: !password,
        enableSuggestions: !password,
        decoration: InputDecoration(
          isDense: true,
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

  @override
  Widget build(BuildContext context) => Panel(
    child: SingleChildScrollView(
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.manage_accounts_outlined, color: blue, size: 23),
                  SizedBox(width: 9),
                  Text(
                    'My Account',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Update your administrator profile and password.',
                style: TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 22),
              const Text(
                'Personal Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ink),
              ),
              const SizedBox(height: 12),
              _field('Full Name', _name),
              const SizedBox(height: 14),
              _field('Username', _username),
              if (_profileError != null) ...[
                const SizedBox(height: 10),
                Text(_profileError!, style: const TextStyle(color: red)),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _savingProfile || _savingPassword ? null : _saveProfile,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save Profile Changes'),
                ),
              ),
              const SizedBox(height: 26),
              const Divider(),
              const SizedBox(height: 18),
              const Text(
                'Change Password',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ink),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter your current password and a new password of at least 12 characters.',
                style: TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              _field(
                'Current Password',
                _currentPassword,
                password: true,
                visible: _showCurrent,
                toggleVisibility: () => setState(() => _showCurrent = !_showCurrent),
              ),
              const SizedBox(height: 14),
              _field(
                'New Password',
                _newPassword,
                password: true,
                visible: _showNew,
                toggleVisibility: () => setState(() => _showNew = !_showNew),
              ),
              const SizedBox(height: 14),
              _field(
                'Confirm New Password',
                _confirmPassword,
                password: true,
                visible: _showConfirm,
                toggleVisibility: () => setState(() => _showConfirm = !_showConfirm),
              ),
              if (_passwordError != null) ...[
                const SizedBox(height: 10),
                Text(_passwordError!, style: const TextStyle(color: red)),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _savingPassword || _savingProfile ? null : _savePassword,
                  icon: const Icon(Icons.lock_reset_outlined, size: 18),
                  label: const Text('Update Password'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
