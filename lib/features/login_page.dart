import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../data/finance_store.dart';
import '../ui/app_icon.dart';
import '../ui/common.dart';
import '../ui/login_building_data.dart';

// Reference artwork: 1672 x 941. The entire composition scales together,
// so the logo, large heading, diagonal, building and login card stay aligned.
const _designWidth = 1672.0;
const _designHeight = 941.0;
const _navy = Color(0xff102b57);
const _red = Color(0xffcb102b);
const _cardWhite = Color(0xfff8f9fe);

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

  Widget _input(String title, TextEditingController controller, {
    required String iconName,
    bool password = false,
  }) {
    return TextField(
      key: ValueKey(title),
      controller: controller,
      enabled: !_busy && !widget.store.needsAccount,
      obscureText: password && !_showPassword,
      autofillHints: title == 'Username'
          ? const [AutofillHints.username]
          : null,
      onSubmitted: (_) => _submit(),
      style: const TextStyle(
        fontSize: 20,
        color: Color(0xff27354d),
      ),
      decoration: InputDecoration(
        hintText: title,
        hintStyle: const TextStyle(
          fontSize: 19,
          color: Color(0xff616b7d),
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 17, right: 12),
          child: AppIcon(iconName, size: 27, color: Color(0xff586277)),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 58,
          minHeight: 46,
        ),
        suffixIcon: password
            ? IconButton(
                onPressed: () => setState(() => _showPassword = !_showPassword),
                tooltip: _showPassword ? 'Hide password' : 'Show password',
                icon: AppIcon(
                  _showPassword ? 'eye' : 'eye-off',
                  size: 26,
                  color: const Color(0xff586277),
                ),
              )
            : null,
        filled: true,
        fillColor: const Color(0xfffafbfe),
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xffc6cfdf)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xffbac7dd),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xff1b4c88),
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _agencyHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 108,
          height: 108,
          child: Image.asset(
            'assets/ncsc-logo-transparent.png',
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.account_balance,
              size: 80,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 18),
        SizedBox(
          width: 312,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Republic of the Philippines',
                style: TextStyle(
                  fontSize: 17,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'NATIONAL COMMISSION\nOF SENIOR CITIZENS',
                maxLines: 2,
                style: TextStyle(
                  fontSize: 25,
                  height: 1.08,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Container(
          width: 2,
          height: 75,
          color: const Color(0xfff3f5ff),
        ),
        const SizedBox(width: 27),
        const Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Regional Office 1',
              maxLines: 1,
              style: TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _financeLabel() => ClipPath(
    clipper: _FinanceTagClipper(),
    child: Container(
      width: 418,
      height: 61,
      padding: const EdgeInsets.fromLTRB(22, 0, 31, 0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xffe51c39), Color(0xff842248)],
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.storage_rounded, size: 31, color: Colors.white),
          SizedBox(width: 19),
          Expanded(
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                'FINANCE SYSTEM',
                maxLines: 1,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  letterSpacing: .3,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _loginCard() {
    final needsSetup = widget.store.needsAccount;
    return Container(
      width: 589,
      height: 667,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(38),
        boxShadow: const [
          BoxShadow(
            color: Color(0x481d3b77),
            offset: Offset(0, 16),
            blurRadius: 37,
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: 0,
            top: 0,
            width: 204,
            height: 130,
            child: IgnorePointer(
              child: CustomPaint(painter: _CardCornerPainter()),
            ),
          ),
          Positioned(
            top: 31,
            left: 225,
            width: 139,
            height: 115,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xffe9effb),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(
                      Icons.calculate_rounded,
                      size: 86,
                      color: Color(0xff173a75),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 9,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xffe9effb),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.storage_rounded,
                        color: Color(0xffd01432),
                        size: 39,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 40,
            top: 158,
            width: 509,
            child: Text(
              'NCSC Finance System',
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w800,
                color: Color(0xff0d2a62),
              ),
            ),
          ),
          const Positioned(
            left: 45,
            top: 206,
            width: 499,
            child: Text(
              'Log in to your account',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 23,
                color: Color(0xff596475),
              ),
            ),
          ),
          Positioned(
            left: 45,
            top: 269,
            width: 499,
            height: 60,
            child: _input(
              'Username',
              _username,
              iconName: 'user-round',
            ),
          ),
          Positioned(
            left: 45,
            top: 348,
            width: 499,
            height: 60,
            child: _input(
              'Password',
              _password,
              iconName: 'lock',
              password: true,
            ),
          ),
          if (needsSetup || _error != null)
            Positioned(
              left: 43,
              top: 415,
              width: 503,
              height: 66,
              child: Center(
                child: Text(
                  needsSetup
                      ? 'No Admin account is configured on this computer. '
                          'Please contact the system maintainer.'
                      : _error!,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  style: const TextStyle(
                    color: _red,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 45,
            top: 489,
            width: 499,
            height: 70,
            child: FilledButton.icon(
              onPressed: _busy || needsSetup ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xffbb0d29),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const AppIcon('log-in', size: 27),
              label: const Text(
                'Log In',
                style: TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const Positioned(
            left: 45,
            top: 601,
            width: 499,
            child: Row(
              children: [
                Expanded(child: Divider(color: Color(0xffaab5c6))),
                SizedBox(width: 18),
                Text(
                  'For authorized NCSC personnel only',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    color: Color(0xff4a5464),
                  ),
                ),
                SizedBox(width: 18),
                Expanded(child: Divider(color: Color(0xffaab5c6))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xffe6ecfa),
    body: SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.center,
        child: SizedBox(
          width: _designWidth,
          height: _designHeight,
          child: Stack(
            children: [
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _ReferenceBackdropPainter()),
                ),
              ),
              Positioned(
                left: 0,
                top: 513,
                width: 1056,
                height: 428,
                child: IgnorePointer(
                  child: Image.memory(
                    base64Decode(loginBuildingBase64),
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                  ),
                ),
              ),
              Positioned(
                left: 94,
                top: 91,
                width: 747,
                height: 112,
                child: _agencyHeader(),
              ),
              Positioned(
                left: 94,
                top: 270,
                width: 418,
                height: 61,
                child: _financeLabel(),
              ),
              const Positioned(
                left: 93,
                top: 342,
                width: 760,
                height: 139,
                child: FittedBox(
                  alignment: Alignment.topLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Financial Management\nInformation System',
                    maxLines: 2,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 67,
                      fontWeight: FontWeight.w800,
                      height: 1.035,
                      letterSpacing: -1.3,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: 94,
                top: 496,
                width: 716,
                height: 32,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Budgeting   •   Disbursement   •   Accounting   •   Reporting',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 24,
                      color: Color(0xffe2e8f7),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 979,
                top: 133,
                width: 589,
                height: 667,
                child: _loginCard(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ReferenceBackdropPainter extends CustomPainter {
  const _ReferenceBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xffe8eefb),
            Color(0xfff7f8ff),
            Color(0xffd5e2f9),
          ],
        ).createShader(rect),
    );

    final upperRight = Path()
      ..moveTo(size.width * .86, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width * .78, size.height * .41)
      ..lineTo(size.width * .69, size.height * .38)
      ..close();
    canvas.drawPath(upperRight, Paint()..color = const Color(0x66ffffff));

    final lowerRight = Path()
      ..moveTo(size.width * .84, size.height)
      ..lineTo(size.width, size.height * .68)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(lowerRight, Paint()..color = const Color(0x4afefeff));

    final navyPanel = Path()
      ..moveTo(0, 0)
      ..lineTo(1009, 0)
      ..lineTo(761, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      navyPanel,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff122a53),
            Color(0xff12315f),
            Color(0xff1e4780),
          ],
        ).createShader(rect),
    );

    final edge = Path()
      ..moveTo(935, 0)
      ..lineTo(1009, 0)
      ..lineTo(761, size.height)
      ..lineTo(711, size.height)
      ..close();
    canvas.drawPath(edge, Paint()..color = const Color(0x2b3c6da4));

    // Faint cool highlights in the dark-blue area.
    final glow = Path()
      ..moveTo(0, size.height * .55)
      ..lineTo(695, size.height * .84)
      ..lineTo(660, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(glow, Paint()..color = const Color(0x171c64af));
  }

  @override
  bool shouldRepaint(covariant _ReferenceBackdropPainter oldDelegate) =>
      false;
}

class _FinanceTagClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(10, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width * .96, size.height)
    ..lineTo(0, size.height)
    ..lineTo(0, 10)
    ..quadraticBezierTo(0, 0, 10, 0)
    ..close();

  @override
  bool shouldReclip(covariant _FinanceTagClipper oldClipper) => false;
}

class _CardCornerPainter extends CustomPainter {
  const _CardCornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final redCorner = Path()
      ..moveTo(size.width * .05, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..quadraticBezierTo(size.width * .79, size.height * .18, 0, 0)
      ..close();
    canvas.drawPath(redCorner, Paint()..color = const Color(0xffd21732));

    final whiteSweep = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(size.width * .74, 1, size.width, size.height * .89)
      ..lineTo(size.width * .93, size.height * .75)
      ..quadraticBezierTo(size.width * .60, size.height * .08, 0, 0)
      ..close();
    canvas.drawPath(whiteSweep, Paint()..color = _cardWhite);
  }

  @override
  bool shouldRepaint(covariant _CardCornerPainter oldDelegate) => false;
}
