import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../data/finance_store.dart';
import '../ui/common.dart';
import '../ui/login_backdrop.dart';
import '../ui/theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.store});
  final FinanceStore store;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _showForm = false;
  bool _showPassword = false;
  bool _busy = false;
  String? _error;
  String? _bagongAsset;

  @override
  void initState() {
    super.initState();
    _findBagongPilipinasLogo();
  }

  Future<void> _findBagongPilipinasLogo() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final matches = manifest.listAssets().where((path) {
        final lower = path.toLowerCase();
        // Only use a PNG explicitly marked as transparent. Otherwise the
        // painter below avoids the opaque background around the mark.
        return lower.startsWith('assets/') &&
            lower.contains('bagong') &&
            lower.contains('transparent') &&
            lower.endsWith('.png');
      }).toList()
        ..sort();
      if (mounted && matches.isNotEmpty) {
        setState(() => _bagongAsset = matches.first);
      }
    } catch (_) {
      // Use the small illustrated fallback when no logo asset is available.
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _openForm() {
    if (_showForm) return;
    setState(() {
      _showForm = true;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.store.needsAccount) {
        _usernameFocus.requestFocus();
      }
    });
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

  Widget _bagongMark(double size) {
    if (_bagongAsset != null) {
      return Image.asset(
        _bagongAsset!,
        width: size * 1.33,
        height: size * 1.16,
        fit: BoxFit.contain,
      );
    }
    return SizedBox(
      key: const ValueKey('bagong-transparent-logo'),
      width: size * 1.4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size * 0.85,
            child: CustomPaint(painter: const _BagongMarkPainter()),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'BAGONG PILIPINAS',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.115,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _welcomeContent(double width, double height) {
    final compact = height < 730 || width < 1000;
    final verySmall = width < 590;
    final logoSize = verySmall ? 68.0 : compact ? 96.0 : 132.0;
    final brandSize = verySmall ? 18.0 : compact ? 24.0 : 32.0;
    final titleSize = verySmall ? 22.0 : compact ? 30.0 : 42.0;

    return ConstrainedBox(
      key: const ValueKey('login-welcome'),
      constraints: const BoxConstraints(maxWidth: 1200),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/ncsc-logo-transparent.png',
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.contain,
                  semanticLabel: 'National Commission of Senior Citizens logo',
                ),
                SizedBox(width: verySmall ? 12 : compact ? 22 : 34),
                _bagongMark(logoSize),
              ],
            ),
            SizedBox(height: compact ? 14 : 20)
            Text(
              'National Commission of Senior Citizens',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: brandSize,
                height: 1.13,
              ),
            ),
            SizedBox(height: compact ? 3 : 8),
            Text(
              'Region I',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.93),
                fontWeight: FontWeight.w400,
                fontSize: brandSize * 0.86,
              ),
            ),
            SizedBox(height: compact ? 24 : 38),
            Text(
              productTitle,
              maxLines: 3,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: titleSize,
                fontWeight: FontWeight.w800,
                height: 1.18,
              ),
            ),
            SizedBox(height: compact ? 28 : 46),
            SizedBox(
              width: verySmall ? 210 : compact ? 245 : 330,
              height: compact ? 54 : 68,
              child: FilledButton(
                key: const ValueKey('login-welcome-sign-in'),
                onPressed: _openForm,
                style: FilledButton.styleFrom(
                  foregroundColor: const Color(0xff082c87),
                  backgroundColor: Colors.white,
                  elevation: 7,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Sign in',
                      style: TextStyle(
                        fontSize: compact ? 20 : 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.arrow_forward,
                      size: compact ? 22 : 30,
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

  Widget _field(
    String label,
    String hint,
    IconData icon,
    TextEditingController controller,
    FocusNode focusNode, {
    bool password = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xff102458),
        ),
      ),
      const SizedBox(height: 6),
      SizedBox(
        height: 52,
        child: TextField(
          key: ValueKey(label),
          focusNode: focusNode,
          controller: controller,
          enabled: !_busy && !widget.store.needsAccount,
          obscureText: password && !_showPassword,
          autofillHints: label == 'Username'
              ? const [AutofillHints.username]
              : const [AutofillHints.password],
          textInputAction: password ? TextInputAction.done : TextInputAction.next,
          onSubmitted: (_) {
            if (password) {
              _submit();
            } else {
              _passwordFocus.requestFocus();
            }
          },
          style: const TextStyle(fontSize: 14, color: Color(0xff102458)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xff69748d),
              fontSize: 14,
            ),
            filled: true,
            fillColor: const Color(0xfff5f7fc),
            prefixIcon: Icon(icon, size: 21, color: navy),
            suffixIcon: password
                ? IconButton(
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: navy,
                      size: 21,
                    ),
                  )
                : null,
            border: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xffa9b9d6)),
              borderRadius: BorderRadius.circular(13),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(
                color: Color(0xffa9b9d6),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: blue, width: 2),
              borderRadius: BorderRadius.circular(13),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
          ),
        ),
      ),
    ],
  );

  Widget _loginCard(double height) {
    final compact = height < 730;
    final needsProvisioning = widget.store.needsAccount;
    return Container(
      key: const ValueKey('login-form'),
      width: 430,
      decoration: BoxDecoration(
        color: const Color(0xfffbfcff).withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55051846),
            blurRadius: 34,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 25 : 32,
          compact ? 18 : 24,
          compact ? 25 : 32,
          compact ? 25 : 32,
        ),
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/ncsc-logo-transparent.png',
                width: compact ? 92 : 122,
                height: compact ? 92 : 122,
                fit: BoxFit.contain,
                semanticLabel: 'NCSC logo',
              ),
              SizedBox(height: compact ? 5 : 8),
              const Text(
                'NCSC-R1',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: navy,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'Log in',
                style: TextStyle(
                  fontSize: compact ? 31 : 39,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xff092766),
                  height: 1.1,
                ),
              ),
              SizedBox(height: compact ? 14 : 20)
              if (needsProvisioning) ...[
                const Text(
                  'No Admin account is configured on this computer. '
                  'Please contact the system maintainer before signing in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: red),
                ),
                const SizedBox(height: 12),
              ],
              _field(
                'Username',
                'Enter your username',
                Icons.person_outline,
                _username,
                _usernameFocus,
              ),
              SizedBox(height: compact ? 14 : 18),
              _field(
                'Password',
                'Enter your password',
                Icons.lock_outline,
                _password,
                _passwordFocus,
                password: true,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: red, fontSize: 12),
                ),
              ],
              SizedBox(height: compact ? 19 : 26),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  key: const ValueKey('login-submit'),
                  onPressed: _busy || needsProvisioning ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff073ab6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          height: 23,
                          width: 23,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Log in',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        const Positioned.fill(child: LoginBackdrop()),
        Positioned.fill(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, dimensions) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: dimensions.maxHeight,
                  ),
                  child: Center(
                    child: _showForm
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 20,
                            ),
                            child: _loginCard(dimensions.maxHeight),
                          )
                        : Focus(
                            autofocus: true,
                            onKeyEvent: (node, event) {
                              if (event is KeyDownEvent &&
                                  (event.logicalKey == LogicalKeyboardKey.enter ||
                                      event.logicalKey ==
                                          LogicalKeyboardKey.numpadEnter)) {
                                _openForm();
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: _welcomeContent(
                              dimensions.maxWidth,
                              dimensions.maxHeight,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// A small decorative fallback. When an official Bagong Pilipinas logo asset
/// exists in assets, that image is displayed instead of this illustration.
class _BagongMarkPainter extends CustomPainter {
  const _BagongMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 160, size.height / 145);
    const gold = Color(0xffffd30a);
    final ray = Paint()
      ..color = gold
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 9; i++) {
      final theta = math.pi + (i * math.pi / 8);
      final x1 = 80 + math.cos(theta) * 34;
      final y1 = 77 + math.sin(theta) * 34;
      final x2 = 80 + math.cos(theta) * 62;
      final y2 = 77 + math.sin(theta) * 62;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), ray);
    }
    canvas.drawCircle(
      const Offset(80, 77),
      27,
      Paint()..color = gold,
    );
    final blueRibbon = Path()
      ..moveTo(18, 80)
      ..cubicTo(15, 133, 66, 158, 125, 130)
      ..cubicTo(103, 131, 63, 116, 43, 91);
    canvas.drawPath(
      blueRibbon,
      Paint()
        ..color = const Color(0xff0732df)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 19
        ..strokeCap = StrokeCap.round,
    );
    final redRibbon = Path()
      ..moveTo(142, 82)
      ..cubicTo(148, 119, 115, 148, 55, 135)
      ..cubicTo(93, 137, 118, 119, 121, 92);
    canvas.drawPath(
      redRibbon,
      Paint()
        ..color = const Color(0xffec1234)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 17
        ..strokeCap = StrokeCap.round,
    );

    void star(double x, double y) {
      final p = Path();
      for (var j = 0; j < 10; j++) {
        final angle = -math.pi / 2 + j * math.pi / 5;
        final radius = j.isEven ? 8.0 : 3.7;
        final pt = Offset(
          x + math.cos(angle) * radius,
          y + math.sin(angle) * radius,
        );
        if (j == 0) {
          p.moveTo(pt.dx, pt.dy);
        } else {
          p.lineTo(pt.dx, pt.dy);
        }
      }
      p.close();
      canvas.drawPath(p, Paint()..color = gold);
    }

    star(31, 22);
    star(80, 7);
    star(130, 22);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BagongMarkPainter oldDelegate) => false;
}
