import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
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

  // Visual language mirrors the supplied NCSC Finance System reference.
  // Authentication, password handling, and error feedback remain unchanged.
  Widget _card({bool compact = false}) {
    final needsProvisioning = widget.store.needsAccount;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxWidth: compact ? 440 : 540),
      decoration: BoxDecoration(
        color: const Color(0xfff9faff),
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30072658),
            blurRadius: 42,
            offset: Offset(0, 16),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // The red quarter-circle motif belongs to the card itself.
          const Positioned(
            right: 0,
            top: 0,
            child: SizedBox(
              width: 192,
              height: 132,
              child: CustomPaint(painter: _LoginCardCorner()),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 26 : 40,
              compact ? 25 : 31,
              compact ? 26 : 40,
              compact ? 26 : 32,
            ),
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: compact ? 82 : 100,
                    height: compact ? 78 : 96,
                    decoration: BoxDecoration(
                      color: const Color(0xffe9effb),
                      borderRadius: BorderRadius.circular(21),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Positioned(
                          left: 15,
                          top: 12,
                          child: Icon(
                            Icons.calculate_outlined,
                            size: 61,
                            color: Color(0xff153d7c),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 9,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: const Color(0xffe9effb),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.storage_rounded,
                              size: 31,
                              color: Color(0xffc91434),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: compact ? 12 : 16),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'NCSC Finance System',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: compact ? 25 : 29,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xff102c60),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Log in to your account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xff5e6575),
                    ),
                  ),
                  SizedBox(height: compact ? 23 : 29),
                  if (needsProvisioning) ...[
                    const Text(
                      'No Admin account is configured on this computer. '
                      'Please contact the system maintainer.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: red),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _field('Username', 'user-round', _username),
                  const SizedBox(height: 14),
                  _field('Password', 'lock', _password, password: true),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: red, fontSize: 12),
                      ),
                    ),
                  SizedBox(height: compact ? 28 : 38),
                  SizedBox(
                    width: double.infinity,
                    height: compact ? 54 : 61,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xffcc0f2d),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
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
                          : const AppIcon('log-in', size: 23),
                      label: const Text(
                        'Log In',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 23 : 31),
                  Row(
                    children: [
                      const Expanded(
                        child: Divider(color: Color(0xffbec8d9)),
                      ),
                      const SizedBox(width: 10),
                      const Flexible(
                        flex: 9,
                        child: Text(
                          'For authorized NCSC personnel only',
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xff576478),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Divider(color: Color(0xffbec8d9)),
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

  Widget _agencyBrand({bool compact = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/ncsc-logo-transparent.png',
          width: compact ? 63 : 92,
          height: compact ? 63 : 92,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(
            Icons.account_balance_outlined,
            size: 55,
            color: Colors.white,
          ),
        ),
        SizedBox(width: compact ? 12 : 17),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Republic of the Philippines',
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 10 : 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'NATIONAL COMMISSION\nOF SENIOR CITIZENS',
              style: TextStyle(
                color: Colors.white,
                height: 1.08,
                fontWeight: FontWeight.w800,
                fontSize: compact ? 15 : 22,
              ),
            ),
          ],
        ),
        SizedBox(width: compact ? 13 : 25),
        Container(
          height: compact ? 55 : 73,
          width: 2,
          color: Colors.white.withValues(alpha: 0.88),
        ),
        SizedBox(width: compact ? 13 : 26),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Regional Office 1',
              maxLines: 1,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 19 : 25,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroCopy({bool compact = false}) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ClipPath(
        clipper: _FinanceBannerClipper(),
        child: Container(
          height: compact ? 47 : 59,
          width: compact ? 303 : 410,
          padding: const EdgeInsets.only(left: 18),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xffed1533), Color(0xff78265a)],
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.storage_rounded, size: 26, color: Colors.white),
              const SizedBox(width: 17),
              Text(
                'FINANCE SYSTEM',
                style: TextStyle(
                  color: Colors.white,
                  letterSpacing: .4,
                  fontSize: compact ? 19 : 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 13),
      Text(
        'Financial Management\nInformation System',
        style: TextStyle(
          fontSize: compact ? 31 : 48,
          height: 1.05,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      const SizedBox(height: 20),
      Text(
        'Budgeting   •   Disbursement   •   Accounting   •   Reporting',
        style: TextStyle(
          color: const Color(0xffe2e9f7),
          fontSize: compact ? 12 : 17,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, bounds) {
        final desktop = bounds.maxWidth >= 1160;
        final narrowDesktop = bounds.maxWidth < 1500;
        if (!desktop) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xff112e62), Color(0xffdbe6fa)],
              ),
            ),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: bounds.maxHeight),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                      decoration: const BoxDecoration(
                        color: Color(0xff122c5b),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _agencyBrand(compact: true),
                          const SizedBox(height: 23),
                          _heroCopy(compact: true),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 22, 16, 30),
                      child: _card(compact: true),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    Color(0xffe4ebfb),
                    Color(0xfff3f6ff),
                    Color(0xffcbdaf6),
                  ],
                ),
              ),
            ),
            const Positioned.fill(
              child: CustomPaint(painter: _FinanceLoginPanel()),
            ),
            Positioned(
              left: 0,
              bottom: -18,
              width: bounds.maxWidth * .60,
              height: bounds.maxHeight * .45,
              child: ClipPath(
                clipper: _BuildingClipper(),
                child: Opacity(
                  opacity: .48,
                  child: Image.asset(
                    'assets/login-reference-background.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.bottomCenter,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _FinanceBottomRibbon()),
              ),
            ),
            Positioned(
              left: bounds.maxWidth * .056,
              top: bounds.maxHeight * .095,
              width: bounds.maxWidth * .51,
              child: _agencyBrand(compact: narrowDesktop),
            ),
            Positioned(
              left: bounds.maxWidth * .056,
              top: bounds.maxHeight * .287,
              width: bounds.maxWidth * .48,
              child: _heroCopy(compact: narrowDesktop),
            ),
            Positioned(
              right: bounds.maxWidth * .05,
              top: 0,
              bottom: 0,
              width: narrowDesktop ? 435 : bounds.maxWidth * .357,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: _card(compact: narrowDesktop),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _FinanceLoginPanel extends CustomPainter {
  const _FinanceLoginPanel();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * .613, 0)
      ..lineTo(size.width * .452, size.height)
      ..lineTo(0, size.height)
      ..close();
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff142d5b), Color(0xff183967), Color(0xff0d2a57)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BuildingClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width * .88, 0)
    ..lineTo(size.width * .70, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _FinanceBottomRibbon extends CustomPainter {
  const _FinanceBottomRibbon();

  @override
  void paint(Canvas canvas, Size size) {
    final bottom = size.height;
    final redRibbon = Path()
      ..moveTo(0, bottom * .841)
      ..lineTo(size.width * .42, bottom)
      ..lineTo(0, bottom)
      ..close();
    canvas.drawPath(
      redRibbon,
      Paint()..color = const Color(0xffd40e2c),
    );
    canvas.drawLine(
      Offset(0, bottom * .797),
      Offset(size.width * .45, bottom),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FinanceBannerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width * .96, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _LoginCardCorner extends CustomPainter {
  const _LoginCardCorner();

  @override
  void paint(Canvas canvas, Size size) {
    final background = Path()
      ..moveTo(size.width * .06, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..cubicTo(
        size.width * .95,
        size.height * .36,
        size.width * .58,
        size.height * .02,
        size.width * .06,
        0,
      )
      ..close();
    canvas.drawPath(background, Paint()..color = const Color(0xffd61130));
    final whiteSweep = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(
        size.width * .75,
        size.height * .02,
        size.width,
        size.height * .90,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * .77, size.height * .78)
      ..quadraticBezierTo(size.width * .50, size.height * .22, 0, 0)
      ..close();
    canvas.drawPath(whiteSweep, Paint()..color = const Color(0xfff9faff));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
