import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// A shared full-screen background for Welcome and Login.
/// Detects the supplied group portrait in assets, even if its local filename
/// differs; falls back to the bundled reference background for other installs.
class LoginBackdrop extends StatefulWidget {
  const LoginBackdrop({super.key});

  @override
  State<LoginBackdrop> createState() => _LoginBackdropState();
}

class _LoginBackdropState extends State<LoginBackdrop> {
  String _photo = 'assets/login-reference-background.png';

  @override
  void initState() {
    super.initState();
    _choosePhoto();
  }

  Future<void> _choosePhoto() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final files = manifest.listAssets();
      final candidates = files.where((path) {
        final lower = path.toLowerCase();
        return path.startsWith('assets/') &&
            (lower.endsWith('.jpg') ||
                lower.endsWith('.jpeg') ||
                lower.endsWith('.png')) &&
            (lower.contains('group') ||
                lower.contains('portrait') ||
                lower.contains('flags')) &&
            !lower.contains('login-senior') &&
            !lower.contains('reference-background');
      }).toList();
      candidates.sort((a, b) {
        int priority(String path) {
          final name = path.toLowerCase();
          if (name.contains('group portrait')) return 0;
          if (name.contains('login-group')) return 1;
          if (name.contains('ncsc-group')) return 2;
          return 3;
        }
        final order = priority(a).compareTo(priority(b));
        return order != 0 ? order : a.compareTo(b);
      });
      if (mounted && candidates.isNotEmpty) {
        setState(() => _photo = candidates.first);
      }
    } catch (_) {
      // Keep the bundled image if the manifest cannot be read.
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
        child: Image.asset(
          _photo,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) =>
              const ColoredBox(color: Color(0xff142b78)),
        ),
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [0, 0.37, 0.61, 1],
            colors: [
              Color(0xee022b9d),
              Color(0xcd132e82),
              Color(0xca632261),
              Color(0xf0b4003c),
            ],
          ),
        ),
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x330b1847), Color(0x1a3b1744), Color(0x440b1857)],
          ),
        ),
      ),
    ],
  );
}
