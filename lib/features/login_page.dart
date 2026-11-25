import 'package:material_ui/material_ui.dart';

import '../data/finance_store.dart';
import '../ui/app_icon.dart';
import '../ui/common.dart';
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
    String label,
    String icon,
    TextEditingController controller, {
    bool password = false,
  }) => SizedBox(
    height: 54,
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
        hintStyle: const TextStyle(color: Color(0xff717d92), fontSize: 15),
        filled: true,
        fillColor: const Color(0xfffafbfe),
        prefixIcon: AppIcon(icon, size: 21, color: muted),
        suffixIcon: password
            ? IconButton(
                tooltip: _showPassword ? 'Hide password' : 'Show password',
                onPressed: () => setState(
                  () => _showPassword = !_showPassword,
                ),
                icon: AppIcon(
                  _showPassword ? 'eye' : 'eye-off',
                  size: 20,
                  color: muted,
                ),
              )
            : null,
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xffcad3e3)),
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xffcbd4e5)),
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: blue, width: 1.7),
          borderRadius: BorderRadius.circular(14),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 15,
        ),
      ),
    ),
  );

  Widget _card({bool compact = false}) {
    final needsProvisioning = widget.store.needsAccount;
    return Container(
      width: compact ? 470 : 475,
      decoration: BoxDecoration(
        color: const Color(0xfffcfdff),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x29041c57),
            blurRadius: 38,
            offset: Offset(0, 18),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -118,
            right: -111,
            child: Container(
              width: 275,
              height: 205,
              decoration: const BoxDecoration(
                color: Color(0xffd31c35),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(220),
                ),
              ),
            ),
          ),
          Positioned(
            top: -108,
            right: -117,
            child: Container(
              width: 258,
              height: 184,
              decoration: const BoxDecoration(
                color: Color(0xfffcfdff),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(220),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 28 : 36,
              compact ? 26 : 32,
              compact ? 28 : 36,
              compact ? 25 : 30,
            ),
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 94,
                    height: 88,
                    decoration: BoxDecoration(
                      color: const Color(0xffeaf0fb),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Center(
                      child: AppIcon(
                        'wallet',
                        size: 52,
                        color: navy,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'NCSC Finance System',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Log in to your account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xff5b6477),
                    ),
                  ),
                  const SizedBox(height: 25),
                  if (needsProvisioning) ...[
                    const Text(
                      'No Admin account is configured on this computer. '
                      'Please contact the system maintainer.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: red),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _field('Username', 'user-round', _username),
                  const SizedBox(height: 13),
                  _field('Password', 'lock', _password, password: true),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: red, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xffc9112e),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _busy || needsProvisioning ? null : _submit,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const AppIcon('log-in', size: 22),
                      label: const Text(
                        'Log In',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      const Expanded(
                        child: Divider(color: Color(0xffcdd5e3)),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'For authorized NCSC personnel only',
                        style: TextStyle(
                          color: muted,
                          fontSize: compact ? 11 : 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Divider(color: Color(0xffcdd5e3)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leftContent({bool compact = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          Image.asset(
            'assets/ncsc-logo-transparent.png',
            width: compact ? 64 : 75,
            height: compact ? 64 : 75,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Text(
              'NCSC',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Republic of the Philippines',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'NATIONAL COMMISSION\nOF SENIOR CITIZENS',
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      SizedBox(height: compact ? 24 : 45),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 9, 30, 9),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xffe01938), Color(0xff8c234f)],
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(9),
            bottomLeft: Radius.circular(9),
          ),
        ),
        child: const Text(
          'FINANCE SYSTEM',
          style: TextStyle(
            fontSize: 17,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Financial Management\nInformation System',
        style: TextStyle(
          fontSize: compact ? 28 : 39,
          fontWeight: FontWeight.w800,
          height: 1.1,
          color: Colors.white,
        ),
      ),
      const SizedBox(height: 17),
      Text(
        'Budgeting  •  Disbursement  •  Accounting  •  Reporting',
        style: TextStyle(
          fontSize: compact ? 12 : 15,
          color: const Color(0xffe2e9f7),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1100;
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xffe9effe)),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Color(0xffe5edfc),
                      Color(0xfff5f7ff),
                      Color(0xffd6e3f7),
                    ],
                  ),
                ),
              ),
            ),
            if (wide) ...[
              Positioned(
                right: -110,
                top: -210,
                child: Transform.rotate(
                  angle: -0.30,
                  child: Container(
                    width: 600,
                    height: 420,
                    color: const Color(0x55ffffff),
                  ),
                ),
              ),
              Positioned.fill(
                child: ClipPath(
                  clipper: _FinanceLoginClipper(),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xff102d60),
                              Color(0xff0b2858),
                              Color(0xff214d88),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        bottom: -50,
                        right: constraints.maxWidth * 0.36,
                        height: constraints.maxHeight * 0.51,
                        child: Opacity(
                          opacity: 0.40,
                          child: Image.asset(
                            'assets/login-reference-background.png',
                            fit: BoxFit.cover,
                            alignment: Alignment.bottomLeft,
                            errorBuilder: (_, _, _) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0xff061d49).withValues(alpha: .10),
                                const Color(0xff092758).withValues(alpha: .03),
                                const Color(0xff051a45).withValues(alpha: .40),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 105,
                        child: CustomPaint(
                          painter: _FinanceRibbonPainter(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: constraints.maxWidth * .052,
                top: constraints.maxHeight * .095,
                width: constraints.maxWidth * .49,
                child: _leftContent(),
              ),
              Positioned(
                right: constraints.maxWidth * .06,
                top: 0,
                bottom: 0,
                width: 475,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: _card(),
                  ),
                ),
              ),
            ] else
              SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(28, 25, 28, 28),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xff0a2558), Color(0xff24518c)],
                          ),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 570),
                            child: _leftContent(compact: true),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 25),
                        child: _card(compact: true),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _FinanceLoginClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width * 0.63, 0)
    ..lineTo(size.width * 0.44, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant _FinanceLoginClipper oldClipper) => false;
}

class _FinanceRibbonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strip = Path()
      ..moveTo(0, size.height * .38)
      ..lineTo(size.width * .24, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(strip, Paint()..color = const Color(0xffd61631));
    canvas.drawLine(
      Offset(0, size.height * .34),
      Offset(size.width * .24, size.height),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _FinanceRibbonPainter oldDelegate) => false;
}
