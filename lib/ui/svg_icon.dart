import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Shared scalable icon rendered from the SVG assets bundled with the app.
/// Keep its size/color configurable without changing the source SVG files.
class AppSvgIcon extends StatelessWidget {
  const AppSvgIcon(
    this.name, {
    super.key,
    this.size = 18,
    this.color,
    this.semanticLabel,
  });

  final String name;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/$name.svg',
    width: size,
    height: size,
    fit: BoxFit.contain,
    colorFilter: ColorFilter.mode(
      color ?? IconTheme.of(context).color ?? const Color(0xff132951),
      BlendMode.srcIn,
    ),
    semanticsLabel: semanticLabel,
  );
}
