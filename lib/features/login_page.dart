import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../data/finance_store.dart';
import '../ui/common.dart';
import '../ui/login_backdrop.dart';
import '../ui/svg_icon.dart';
import '../ui/theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.store});
  final FinanceStore store;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController(),
      _password = TextEditingController();
  bool _showPassword = false, _busy = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [_username, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.store.needsAccount) {
        throw const FinanceError(
          'This computer has no configured Admin account. Contact the system maintainer.',
        );
      }
      await widget.store.signIn(_username.text, _password.text);
      _password.clear();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String label,
    String icon,
    TextEditingController controller, {
    bool password = false,
  }) => SizedBox(
    height: LoginLayout.fieldHeight,
    child: TextField(
      key: ValueKey(label),
      controller: controller,
      enabled: !_busy && !widget.store.needsAccount,
      obscureText: password && !_showPassword,
      autofillHints: label == 'Username'
          ? const [AutofillHints.username]
          : null,
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        hintText: label,
        prefixIcon: AppIcon(icon, size: 20, color: navy),
        suffixIcon: password
            ? IconButton(
                tooltip: _showPassword ? 'Hide password' : 'Show password',
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: AppIcon(
                  _showPassword ? 'eye' : 'eye-off',
                  size: 20,
                  color: navy,
                ),
              )
            : null,
      ),
    ),
  );

  Widget _card() {
    final needsProvisioning = widget.store.needsAccount;
    return Container(
      width: LoginLayout.cardWidth,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(LoginLayout.cardRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2e061c52),
            blurRadius: 32,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LoginLayout.cardRadius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              height: 5,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [navy, blue, red]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(LoginLayout.cardPadding),
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        SizedBox(width: 22),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(
                              BorderSide(color: Color(0xffd5e1f5), width: 3),
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(3),
                            child: CircleAvatar(
                              radius: 32,
                              backgroundColor: Color(0xffe2e9fa),
                              child: AppIcon('user-round', size: 28, color: navy),
                            ),
                          ),
                        ),
                        SizedBox(width: 22),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'System Login',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Access your account to continue',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: muted),
                    ),
                    const SizedBox(height: 20),
                    if (needsProvisioning) ...[
                      const Text(
                        'No Admin account is configured on this computer. '
                        'Please contact the system maintainer before signing in.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: red),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _field('Username', 'user-round', _username),
                    const SizedBox(height: 12),
                    _field('Password', 'lock', _password, password: true),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: red, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: navy,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onPressed: _busy || needsProvisioning ? null : _submit,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const AppIcon('log-in', size: 22),
                        label: const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _brand({bool compact = false}) => LayoutBuilder(
    builder: (context, c) {
      final small = c.maxWidth < 490;
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            'assets/ncsc-logo-transparent.png',
            width: compact
                ? 76
                : small
                ? 118
                : 160,
            semanticLabel: 'National Commission of Senior Citizens logo',
            errorBuilder: (context, error, stackTrace) => const Text(
              'NCSC',
              style: TextStyle(
                color: navy,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            width: 2,
            height: compact ? 85 : 172,
            color: navy,
            margin: const EdgeInsets.symmetric(horizontal: 18),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'NCSC-R1',
                    style: TextStyle(
                      color: navy,
                      fontSize: compact
                          ? 36
                          : small
                          ? 46
                          : 62,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  productTitle,
                  style: TextStyle(
                    color: navy,
                    fontSize: compact
                        ? 16
                        : small
                        ? 19
                        : 24,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: 130,
                  height: 4,
                  decoration: BoxDecoration(
                    color: red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        const Positioned.fill(child: LoginBackdrop()),
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth < 1040) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: c.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: _brand(compact: true),
                          ),
                          const SizedBox(height: 26),
                          _card(),
                          const SizedBox(height: 26),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: c.maxWidth * 0.22,
                        right: 28,
                      ),
                      child: _brand(),
                    ),
                  ),
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: _card(),
                    ),
                  ),
                  SizedBox(width: c.maxWidth * 0.055),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
