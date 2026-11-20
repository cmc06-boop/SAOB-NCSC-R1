import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

class LoginBackdrop extends StatefulWidget {
  const LoginBackdrop({super.key});
  @override
  State<LoginBackdrop> createState() => _LoginBackdropState();
}

class _LoginBackdropState extends State<LoginBackdrop> {
  ui.Picture? _scene;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Future<ui.Image> load(String path) async {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      return image;
    }

    final images = await Future.wait([
      load('assets/login-reference-background.png'),
      load('assets/login-senior.png'),
    ]);
    final backdrop = images[0], senior = images[1];
    final recorder = ui.PictureRecorder();
    // Use the supplied portrait unchanged; clip only its on-screen presentation.
    final c = Canvas(recorder);
    c.drawImageRect(
      backdrop,
      Rect.fromLTWH(
        0,
        0,
        backdrop.width.toDouble(),
        backdrop.height.toDouble(),
      ),
      const Rect.fromLTWH(0, 0, 1672, 941),
      Paint()..filterQuality = FilterQuality.high,
    );
    c.saveLayer(const Rect.fromLTWH(0, 0, 1672, 941), Paint());
    c.save();
    final clip = Path()..moveTo(0, 248);
    for (final p in const [
      Offset(64, 191),
      Offset(128, 145),
      Offset(192, 109),
      Offset(256, 90),
      Offset(320, 74),
      Offset(384, 57),
      Offset(448, 39),
      Offset(512, 23),
      Offset(576, 11),
      Offset(640, 2),
      Offset(640, 815),
      Offset(576, 802),
      Offset(512, 787),
      Offset(448, 771),
      Offset(384, 743),
      Offset(320, 719),
      Offset(256, 695),
      Offset(192, 672),
      Offset(128, 652),
      Offset(64, 637),
      Offset(0, 626),
    ]) {
      clip.lineTo(p.dx, p.dy);
    }
    clip.close();
    c.clipPath(clip);
    c.drawImageRect(
      senior,
      Rect.fromLTWH(0, 0, senior.width.toDouble(), senior.height.toDouble()),
      Rect.fromLTWH(-220, 115, 760, 760 * senior.height / senior.width),
      Paint()..filterQuality = FilterQuality.high,
    );
    c.restore();
    c.drawRect(
      const Rect.fromLTWH(0, 0, 1672, 941),
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          const Offset(360, 0),
          const Offset(560, 0),
          [Colors.black, Colors.transparent],
        ),
    );
    c.restore();
    final picture = recorder.endRecording();
    // The recorded picture owns its drawing references after these handles close.
    backdrop.dispose();
    senior.dispose();
    if (!mounted) {
      picture.dispose();
      return;
    }
    setState(() => _scene = picture);
  }

  @override
  void dispose() {
    _scene?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _scene == null
      ? const ColoredBox(color: Color(0xffeaf1fd))
      : CustomPaint(painter: _BackdropPainter(_scene!));
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.picture);
  final ui.Picture picture;
  @override
  void paint(Canvas c, Size size) {
    final scale = size.width / 1672, split = 520 * scale;
    if (size.height < 941 * scale && split < size.height - 100) {
      void segment(
        double sourceY,
        double sourceHeight,
        double y,
        double height,
      ) {
        c.save();
        c.clipRect(Rect.fromLTWH(0, y, size.width, height));
        c.translate(0, y);
        c.scale(scale, height / sourceHeight);
        c.translate(0, -sourceY);
        c.drawPicture(picture);
        c.restore();
      }

      segment(0, 520, 0, split);
      segment(520, 421, split, size.height - split);
    } else {
      final s = math.max(scale, size.height / 941);
      c.save();
      c.translate((size.width - 1672 * s) / 2, size.height - 941 * s);
      c.scale(s);
      c.drawPicture(picture);
      c.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) => old.picture != picture;
}
