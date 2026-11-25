import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../data/finance_store.dart';
import '../ui/app_icon.dart';
import '../ui/common.dart';

/// Original user-supplied design is the background asset. Interactive widgets
/// are positioned over its form at reference resolution, then the entire stage
/// scales as a unit so controls never drift away from the image.
const _designWidth = 1672.0;
const _designHeight = 941.0;
const _cardWhite = Color(0xfff8f9fe);
const _navy = Color(0xff142f61);
const _red = Color(0xffc20d2a);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.store});

  final FinanceStore store;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
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
    String name,
    String icon,
    TextEditingController controller, {
    bool password = false,
  }) => TextField(
    key: ValueKey(name),
    controller: controller,
    enabled: !_busy && !widget.store.needsAccount,
    obscureText: password && !_showPassword,
    autofillHints: name == 'Username'
        ? const [AutofillHints.username]
        : const [AutofillHints.password],
    textInputAction: password ? TextInputAction.done : TextInputAction.next,
    onSubmitted: (_) {
      if (password) _submit();
    },
    style: const TextStyle(color: Color(0xff29374e), fontSize: 20),
    decoration: InputDecoration(
      hintText: name,
      hintStyle: const TextStyle(color: Color(0xff697182), fontSize: 19),
      filled: true,
      fillColor: const Color(0xfffafbff),
      prefixIcon: AppIcon(icon, size: 26, color: Color(0xff586377)),
      suffixIcon: password
          ? IconButton(
              tooltip: _showPassword ? 'Hide password' : 'Show password',
              onPressed: () => setState(
                () => _showPassword = !_showPassword,
              ),
              icon: AppIcon(
                _showPassword ? 'eye' : 'eye-off',
                size: 24,
                color: const Color(0xff586377),
              ),
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: Color(0xffc7cfde)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(
          color: Color(0xffc4cddd),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: _navy, width: 2),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xffe6ecfb),
    body: SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.center,
        child: SizedBox(
          width: _designWidth,
          height: _designHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/login-design-reference.webp',
                  key: const ValueKey('login-reference-background'),
                  fit: BoxFit.fill,
                  semanticLabel:
                      'National Commission of Senior Citizens, Regional '
                      'Office 1. Financial Management Information System.',
                ),
              ),

              // Retain the exact original design's logo, building, colors,
              // panel shadows and card. Repaint only the title and form areas
              // that must be native Flutter widgets.
              const Positioned(
                left: 1066,
                top: 284,
                width: 457,
                height: 52,
                child: ColoredBox(
                  color: _cardWhite,
                  child: Center(
                    child: Text(
                      'NCSC Finance System',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: Color(0xff102e60),
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: 1120,
                top: 336,
                width: 356,
                height: 43,
                child: ColoredBox(
                  color: _cardWhite,
                  child: Center(
                    child: Text(
                      'Log in to your account',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 23,
                        color: Color(0xff545f73),
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 1023,
                top: 400,
                width: 502,
                height: 61,
                child: _field('Username', 'user-round', _username),
              ),
              Positioned(
                left: 1023,
                top: 480,
                width: 502,
                height: 61,
                child: _field(
                  'Password',
                  'lock',
                  _password,
                  password: true,
                ),
              ),

              // The screenshot says "Forgot password?". Replace that entire
              // line with clean card surface: this single-account system
              // intentionally has no password-reset link.
              Positioned(
                left: 1280,
                top: 547,
                width: 258,
                height: 62,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xfff8f9fe),
                          const Color(0xfff6f7fc),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.store.needsAccount || _error != null)
                Positioned(
                  left: 1024,
                  top: 553,
                  width: 503,
                  height: 56,
                  child: Center(
                    child: Text(
                      widget.store.needsAccount
                          ? 'No Admin account is configured on this computer. '
                              'Please contact the system maintainer.'
                          : _error!,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      style: const TextStyle(
                        fontSize: 14,
                        color: _red,
                        backgroundColor: _cardWhite,
                      ),
                    ),
                  ),
                ),

              // Fully opaque native button covers the screenshot's "Sign In".
              Positioned(
                left: 1023,
                top: 622,
                width: 502,
                height: 70,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xffdf102f), Color(0xffa90a25)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: FilledButton.icon(
                    key: const ValueKey('login-submit'),
                    onPressed: _busy || widget.store.needsAccount
                        ? null
                        : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: _busy
                        ? const SizedBox(
                            width: 23,
                            height: 23,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.3,
                              color: Colors.white,
                            ),
                          )
                        : const AppIcon('log-in', size: 27),
                    label: const Text(
                      'Log In',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
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
  );
}
