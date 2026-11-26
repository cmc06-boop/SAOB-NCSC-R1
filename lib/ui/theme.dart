import 'package:material_ui/material_ui.dart';

const navy = Color(0xff061c52);
const blue = Color(0xff245cb6);
const red = Color(0xffd42035);
const ink = Color(0xff132951);
const muted = Color(0xff596d8d);
const background = Color(0xffedf3fe);
const line = Color(0xffdce4f3);
const cardShadow = [
  BoxShadow(color: Color(0x12061c52), blurRadius: 22, offset: Offset(0, 8)),
];

// Higher-contrast state layers for desktop mouse and keyboard interaction.
WidgetStateProperty<Color?> buttonInteraction(Color color) =>
    WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled)) return Colors.transparent;
      if (states.contains(WidgetState.pressed)) return color.withValues(alpha: 0.30);
      if (states.contains(WidgetState.hovered)) return color.withValues(alpha: 0.20);
      if (states.contains(WidgetState.focused)) return color.withValues(alpha: 0.20);
      return null;
    });

ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: blue,
    primary: blue,
    secondary: navy,
    error: red,
    surface: Colors.white,
  ),
  scaffoldBackgroundColor: background,
  fontFamily: 'Segoe UI',
  textTheme: const TextTheme(
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
    bodyMedium: TextStyle(fontSize: 14, color: ink),
    bodySmall: TextStyle(fontSize: 12, color: muted),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: blue, width: 1.5),
    ),
  ),
  hoverColor: const Color(0x33245cb6),
  textButtonTheme: TextButtonThemeData(
    style: ButtonStyle(overlayColor: buttonInteraction(blue)),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: ButtonStyle(overlayColor: buttonInteraction(blue)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(overlayColor: buttonInteraction(navy)),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ).copyWith(overlayColor: buttonInteraction(Colors.white)),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      side: const BorderSide(color: line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ).copyWith(overlayColor: buttonInteraction(blue)),
  ),
  dataTableTheme: DataTableThemeData(
    headingRowColor: const WidgetStatePropertyAll(Color(0xffcdddf4)),
    headingTextStyle: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: navy,
    ),
    dataTextStyle: const TextStyle(fontSize: 12, color: ink),
    columnSpacing: 24,
    horizontalMargin: 18,
    dataRowMinHeight: 56,
    dataRowMaxHeight: 68,
  ),
  dividerTheme: const DividerThemeData(color: line, space: 1),
  dialogTheme: DialogThemeData(
    alignment: Alignment.center,
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
);

/// Change these values, then save and Hot Reload to adjust the login card.
abstract final class LoginLayout {
  static const cardWidth = 360.0;
  static const cardPadding = 28.0;
  static const cardRadius = 28.0;
  static const fieldHeight = 48.0;
}
