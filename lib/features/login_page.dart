import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../data/finance_store.dart';
import '../ui/app_icon.dart';
import '../ui/common.dart';

/// Native Flutter login artwork and interactive form.
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
        fit: BoxFit.fill,
        alignment: Alignment.center,
        child: SizedBox(
          width: _designWidth,
          height: _designHeight,
          child: Stack(
            children: [
              const Positioned.fill(child: CustomPaint(key: ValueKey('login-native-background'), painter: _LoginArtwork())),
              Positioned(
                left: 0,
                top: 535,
                width: 920,
                height: 406,
                child: IgnorePointer(
                  child: ClipPath(
                    clipper: _BuildingPanelClipper(),
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Colors.white, Colors.white, Color(0x00ffffff)],
                        stops: [0, 0.72, 1],
                      ).createShader(bounds),
                      child: Image.asset(
                        'assets/ncsc-building.png',
                        key: const ValueKey('login-building-image'),
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomLeft,
                        color: const Color(0x55204480),
                        colorBlendMode: BlendMode.srcATop,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _LoginRibbons()))),
              Positioned(left: 94, top: 90, width: 108, height: 108,
                child: Image.asset('assets/ncsc-logo-transparent.png')),
              const Positioned(left: 220, top: 98, width: 330, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Republic of the Philippines', style: TextStyle(color: Colors.white, fontSize: 20)),
                  SizedBox(height: 6),
                  Text('NATIONAL COMMISSION\nOF SENIOR CITIZENS', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800, height: 1.2)),
                ],
              )),
              const Positioned(left: 558, top: 105, height: 73, child: VerticalDivider(color: Colors.white, width: 2, thickness: 2)),
              const Positioned(left: 586, top: 122, child: Text('Regional Office I', style: TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w800))),
              Positioned(left: 93, top: 272, width: 420, height: 62, child: ClipPath(
                clipper: _BannerClipper(),
                child: Container(
                  decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xffe5132c), Color(0xff72223c)])),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: const Row(children: [
                    AppIcon('database', size: 34, color: Colors.white),
                    SizedBox(width: 18),
                    Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('FINANCE SYSTEM', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)))),
                  ]),
                ),
              )),
              const Positioned(left: 92, top: 345, width: 780, child: Text('Financial Management\nInformation System', style: TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w800, height: 1.06, letterSpacing: -1.8))),
              const Positioned(left: 94, top: 499, child: Text('Budgeting  •  Disbursement  •  Accounting  •  Reporting', style: TextStyle(color: Color(0xffdce6fb), fontSize: 25))),
              Positioned(left: 979, top: 134, width: 590, height: 667, child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: _cardWhite, borderRadius: BorderRadius.circular(42), boxShadow: const [
                  BoxShadow(color: Color(0x30304c92), blurRadius: 40, offset: Offset(0, 20)),
                ]),
                child: const CustomPaint(painter: _CardAccent()),
              )),
              Positioned(left: 1205, top: 165, width: 138, height: 112, child: Container(
                decoration: BoxDecoration(color: const Color(0xffe8edf7), borderRadius: BorderRadius.circular(26)),
                child: const Stack(alignment: Alignment.center, children: [
                  Positioned(left: 16, top: 12, child: AppIcon('calculator', size: 82, color: _navy)),
                  Positioned(right: 12, bottom: 9, child: AppIcon('database', size: 55, color: _red)),
                ]),
              )),
              const Positioned(left: 1024, top: 728, width: 502, child: Row(children: [
                Expanded(child: Divider(color: Color(0xffaab5c9))),
                Expanded(flex: 8, child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: FittedBox(fit: BoxFit.scaleDown, child: Text('For authorized NCSC personnel only', style: TextStyle(color: Color(0xff545f73), fontSize: 19))))),
                Expanded(child: Divider(color: Color(0xffaab5c9))),
              ])),
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
                      'Sign in to your account',
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
                      'Sign In',
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

class _BannerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()..moveTo(0, 0)..lineTo(s.width, 0)..lineTo(s.width - 20, s.height)..lineTo(0, s.height)..close();
  @override
  bool shouldReclip(covariant _BannerClipper oldClipper) => false;
}

class _LoginArtwork extends CustomPainter {
  const _LoginArtwork();
  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xfffafbff), Color(0xffdce5f8)],
    ).createShader(rect));
    final blue = Path()..moveTo(0, 0)..lineTo(1030, 0)..lineTo(690, s.height)..lineTo(0, s.height)..close();
    canvas.drawPath(blue, Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xff11244a), Color(0xff204b85)],
    ).createShader(rect));
    canvas.drawPath(Path()..moveTo(952, 0)..lineTo(1030, 0)..lineTo(690, s.height)..lineTo(620, s.height)..close(), Paint()..color = const Color(0x223c72b1));
  }
  @override
  bool shouldRepaint(covariant _LoginArtwork oldDelegate) => false;
}

class _LoginRibbons extends CustomPainter {
  const _LoginRibbons();
  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    canvas.drawPath(Path()..moveTo(0, 724)..lineTo(730, s.height)..lineTo(0, s.height)..close(), Paint()..color = Colors.white);
    canvas.drawPath(Path()..moveTo(0, 731)..lineTo(707, s.height)..lineTo(0, s.height)..close(), Paint()..color = const Color(0xff102a59));
    canvas.drawPath(Path()..moveTo(0, 785)..lineTo(690, s.height)..lineTo(0, s.height)..close(), Paint()..shader = const LinearGradient(colors: [Color(0xffed1734), Color(0xff8f071d)]).createShader(rect));
  }
  @override
  bool shouldRepaint(covariant _LoginRibbons oldDelegate) => false;
}

class _CardAccent extends CustomPainter {
  const _CardAccent();
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()..moveTo(s.width - 190, 0)..lineTo(s.width, 0)..lineTo(s.width, 125)..quadraticBezierTo(s.width - 45, 35, s.width - 190, 0)..close();
    canvas.drawPath(path, Paint()..shader = const LinearGradient(colors: [Color(0xffe41531), Color(0xffa90c28)]).createShader(Offset.zero & s));
  }
  @override
  bool shouldRepaint(covariant _CardAccent oldDelegate) => false;
}

class _BuildingPanelClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(0, 0)
    ..lineTo(s.width * 0.91, 0)
    ..lineTo(s.width * 0.75, s.height)
    ..lineTo(0, s.height)
    ..close();

  @override
  bool shouldReclip(covariant _BuildingPanelClipper oldClipper) => false;
}
