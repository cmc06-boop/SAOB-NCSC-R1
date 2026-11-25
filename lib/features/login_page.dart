import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../data/finance_store.dart';
import '../ui/app_icon.dart';
import '../ui/common.dart';
import '../ui/login_building_data.dart';

const _loginNavy = Color(0xff142d5a);
const _loginDeepRed = Color(0xffc5112a);
const _loginOffWhite = Color(0xfff8f9fe);

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
    String symbol,
    TextEditingController controller, {
    bool password = false,
    bool dense = false,
  }) => SizedBox(
    height: dense ? 48 : 56,
    child: TextField(
      key: ValueKey(name),
      controller: controller,
      enabled: !_busy && !widget.store.needsAccount,
      obscureText: password && !_showPassword,
      autofillHints: name == 'Username'
          ? const [AutofillHints.username]
          : null,
      onSubmitted: (_) => _submit(),
      style: const TextStyle(fontSize: 15, color: Color(0xff273447)),
      decoration: InputDecoration(
        hintText: name,
        hintStyle: const TextStyle(
          color: Color(0xff677084),
          fontSize: 15,
        ),
        filled: true,
        fillColor: const Color(0xfff9fafd),
        prefixIcon: AppIcon(symbol, size: 23, color: Color(0xff606b7f)),
        suffixIcon: password
            ? IconButton(
                tooltip: _showPassword ? 'Hide password' : 'Show password',
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: AppIcon(
                  _showPassword ? 'eye' : 'eye-off',
                  size: 21,
                  color: const Color(0xff59657b),
                ),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xffcdd3df)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xffcbd3e1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xff224d8c), width: 1.7),
        ),
      ),
    ),
  );

  Widget _card({required bool compact}) {
    final requiresSetup = widget.store.needsAccount;
    return Container(
      constraints: BoxConstraints(maxWidth: compact ? 480 : 590),
      decoration: BoxDecoration(
        color: _loginOffWhite,
        borderRadius: BorderRadius.circular(35),
        boxShadow: const [
          BoxShadow(
            blurRadius: 36,
            offset: Offset(0, 16),
            color: Color(0x2b1d3978),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned(
            top: 0,
            right: 0,
            width: 205,
            height: 155,
            child: CustomPaint(painter: _CardRedCorner()),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 30 : 43,
              compact ? 25 : 31,
              compact ? 30 : 43,
              compact ? 25 : 34,
            ),
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: compact ? 82 : 110,
                    height: compact ? 77 : 110,
                    decoration: BoxDecoration(
                      color: const Color(0xffeaf0fb),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Icon(
                            Icons.calculate_rounded,
                            size: compact ? 56 : 73,
                            color: const Color(0xff17427c),
                          ),
                        ),
                        Positioned(
                          right: 6,
                          bottom: 7,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: const Color(0xffeaf0fb),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              Icons.storage_rounded,
                              color: _loginDeepRed,
                              size: compact ? 27 : 36,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: compact ? 12 : 17),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'NCSC Finance System',
                      maxLines: 1,
                      style: TextStyle(
                        color: const Color(0xff102c5d),
                        fontSize: compact ? 25 : 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Log in to your account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      color: Color(0xff5f6676),
                    ),
                  ),
                  SizedBox(height: compact ? 20 : 29),
                  if (requiresSetup) ...[
                    const Text(
                      'No Admin account is configured on this computer. '
                      'Please contact the system maintainer.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: _loginDeepRed,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _field('Username', 'user-round', _username, dense: compact),
                  const SizedBox(height: 17),
                  _field(
                    'Password',
                    'lock',
                    _password,
                    password: true,
                    dense: compact,
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _loginDeepRed,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  SizedBox(height: compact ? 23 : 38),
                  SizedBox(
                    width: double.infinity,
                    height: compact ? 53 : 65,
                    child: FilledButton.icon(
                      onPressed: _busy || requiresSetup ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _loginDeepRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const AppIcon('log-in', size: 24),
                      label: const Text(
                        'Log In',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 20 : 33),
                  Row(
                    children: [
                      const Expanded(
                        child: Divider(color: Color(0xffc7ccd8)),
                      ),
                      const SizedBox(width: 11),
                      const Flexible(
                        flex: 10,
                        child: Text(
                          'For authorized NCSC personnel only',
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xff586272),
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      const Expanded(
                        child: Divider(color: Color(0xffc7ccd8)),
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

  // Keep the agency lockup readable at every desktop width.
  Widget _brand({required bool compact}) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Image.asset(
        'assets/ncsc-logo-transparent.png',
        width: compact ? 66 : 101,
        height: compact ? 66 : 101,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Icon(
          Icons.account_balance_outlined,
          size: 50,
          color: Colors.white,
        ),
      ),
      SizedBox(width: compact ? 11 : 18),
      Expanded(
        flex: 5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                'Republic of the Philippines',
                maxLines: 1,
                style: TextStyle(
                  fontSize: compact ? 11 : 15,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                'NATIONAL COMMISSION\nOF SENIOR CITIZENS',
                style: TextStyle(
                  fontSize: compact ? 17 : 23,
                  height: 1.10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
      SizedBox(width: compact ? 9 : 18),
      Container(
        height: compact ? 56 : 74,
        width: 2,
        color: Colors.white,
      ),
      SizedBox(width: compact ? 9 : 18),
      Expanded(
        flex: 3,
        child: FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Text(
            'Regional Office 1',
            maxLines: 1,
            style: TextStyle(
              fontSize: compact ? 18 : 25,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    ],
  );

  Widget _hero({required bool compact}) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ClipPath(
        clipper: _FinanceBadgeClipper(),
        child: Container(
          width: compact ? 305 : 417,
          height: compact ? 46 : 61,
          padding: const EdgeInsets.only(left: 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xffe71939), Color(0xff7a254f)],
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.storage_rounded,
                size: compact ? 22 : 28,
                color: Colors.white,
              ),
              SizedBox(width: compact ? 12 : 17),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'FINANCE SYSTEM',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .4,
                      fontSize: compact ? 19 : 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
            ],
          ),
        ),
      ),
      const SizedBox(height: 13),
      Text(
        'Financial Management\nInformation System',
        maxLines: 2,
        style: TextStyle(
          color: Colors.white,
          height: 1.04,
          fontWeight: FontWeight.w800,
          fontSize: compact ? 31 : 59,
          letterSpacing: -1.1,
        ),
      ),
      const SizedBox(height: 18),
      FittedBox(
        alignment: Alignment.centerLeft,
        fit: BoxFit.scaleDown,
        child: Text(
          'Budgeting   •   Disbursement   •   Accounting   •   Reporting',
          maxLines: 1,
          style: TextStyle(
            color: const Color(0xffe4e8f2),
            fontSize: compact ? 13 : 17,
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xffe6ecfa),
    body: LayoutBuilder(
      builder: (context, bounds) {
        final desktop = bounds.maxWidth >= 1160;
        if (!desktop) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xff142d5b), Color(0xffe7edfc)],
              ),
            ),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: bounds.maxHeight),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: const Color(0xff142d5b),
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _brand(compact: true),
                          const SizedBox(height: 22),
                          _hero(compact: true),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 22, 16, 26),
                      child: _card(compact: true),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Reference is 1672 x 941. Keep its diagonal, header and card
        // proportions, but use native text and fully functional form fields.
        final compact = bounds.maxWidth < 1500 || bounds.maxHeight < 790;
        final cardWidth = (bounds.maxWidth * .353).clamp(435.0, 591.0).toDouble();
        final cardRight = bounds.maxWidth * .05;
        return Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    Color(0xffe5ebfa),
                    Color(0xfff8f9ff),
                    Color(0xffd6e2f8),
                  ],
                ),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _ReferenceNavyPanelPainter()),
              ),
            ),
            // This is the actual building/ribbon section cropped from the
            // image the user provided, not the former login background asset.
            Positioned(
              left: 0,
              bottom: 0,
              width: bounds.maxWidth * .585,
              height: bounds.maxHeight * .43,
              child: IgnorePointer(
                child: Image.memory(
                  base64Decode(loginBuildingBase64),
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                ),
              ),
            ),
            Positioned(
              left: bounds.maxWidth * .055,
              top: bounds.maxHeight * .09,
              width: bounds.maxWidth * .47,
              child: _brand(compact: compact),
            ),
            Positioned(
              left: bounds.maxWidth * .055,
              top: bounds.maxHeight * .285,
              width: bounds.maxWidth * .475,
              child: _hero(compact: compact),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              right: cardRight,
              width: cardWidth,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: _card(compact: compact),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _ReferenceNavyPanelPainter extends CustomPainter {
  const _ReferenceNavyPanelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final panel = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * .606, 0)
      ..lineTo(size.width * .446, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xff142c56),
          Color(0xff193a6c),
          Color(0xff254e8d),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(panel, fill);

    final edge = Path()
      ..moveTo(size.width * .606, 0)
      ..lineTo(size.width * .621, 0)
      ..lineTo(size.width * .459, size.height)
      ..lineTo(size.width * .446, size.height)
      ..close();
    canvas.drawPath(
      edge,
      Paint()..color = const Color(0x43204c8b),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FinanceBadgeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(8, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width * .966, size.height)
    ..lineTo(0, size.height)
    ..lineTo(0, 9)
    ..quadraticBezierTo(0, 0, 8, 0)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _CardRedCorner extends CustomPainter {
  const _CardRedCorner();

  @override
  void paint(Canvas canvas, Size size) {
    final accent = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..quadraticBezierTo(size.width * .75, size.height * .11, 0, 0)
      ..close();
    canvas.drawPath(accent, Paint()..color = const Color(0xffd11c32));

    final whiteCurve = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(size.width * .73, 4, size.width, size.height * .9)
      ..lineTo(size.width * .87, size.height * .79)
      ..quadraticBezierTo(size.width * .57, size.height * .18, 0, 0)
      ..close();
    canvas.drawPath(
      whiteCurve,
      Paint()..color = _loginOffWhite,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
