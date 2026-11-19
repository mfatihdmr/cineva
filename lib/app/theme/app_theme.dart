import 'package:flutter/material.dart';

/// Cineva tasarım sistemi — koyu ağırlıklı, sinematik, Material 3.
class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF00CDB0);
  static const Color secondary = Color(0xFFFF5A5F);
  static const Color accentGold = Color(0xFFF5C518);
  static const Color darkBg = Color(0xFF0B0F14);
  static const Color darkSurface = Color(0xFF141A22);
  static const Color darkElevated = Color(0xFF1C242E);
  static const Color lightBg = Color(0xFFF6F7F9);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primary,
      secondary: secondary,
      surface: darkSurface,
      error: const Color(0xFFFF6B6B),
    );
    return _base(scheme, isDark: true);
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(primary: const Color(0xFF009B87), secondary: secondary);
    return _base(scheme, isDark: false);
  }

  static ThemeData _base(ColorScheme scheme, {required bool isDark}) {
    final onColor = isDark ? Colors.white : const Color(0xFF101418);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? darkBg : lightBg,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? darkBg : lightBg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: onColor,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: onColor,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? darkSurface : Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        side: BorderSide.none,
        labelStyle: TextStyle(color: onColor, fontSize: 12.5, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      dividerTheme: DividerThemeData(
        color: onColor.withValues(alpha: 0.07),
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? darkSurface : Colors.white,
        indicatorColor: primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected) ? primary : onColor.withValues(alpha: 0.6),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: BorderSide(color: onColor.withValues(alpha: 0.2)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? darkElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? darkSurface : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: onColor.withValues(alpha: 0.75),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary.withValues(alpha: 0.7)),
        ),
      ),
      sliderTheme: const SliderThemeData(showValueIndicator: ShowValueIndicator.never),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      textTheme: Typography.whiteCupertino.apply(
        displayColor: onColor,
        bodyColor: onColor,
      ),
    );
  }

  static final Gradient heroScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.black.withValues(alpha: 0.05), Colors.black.withValues(alpha: 0.55), Color(0xFF0B0F14)],
    stops: const [0.25, 0.7, 1],
  );

  static final Gradient cardScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
    stops: const [0.45, 1],
  );
}
