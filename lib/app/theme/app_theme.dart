import 'package:flutter/material.dart';

import 'page_transitions.dart';

/// 主题色只有 6 个，明暗由用户单独选，两者组合成 12 套配色。
enum AccentColor {
  purple('紫', Color(0xFF6750A4)),
  blue('蓝', Color(0xFF2F6FED)),
  teal('青', Color(0xFF0E7C86)),
  green('绿', Color(0xFF3E7B52)),
  orange('橙', Color(0xFFB4730A)),
  rose('玫红', Color(0xFFB3325F));

  const AccentColor(this.label, this.seed);

  final String label;
  final Color seed;
}

class AppTheme {
  const AppTheme._();

  // 浅色 token
  static const _lightSurface = Color(0xFFFFFBFE);
  static const _lightBackground = Color(0xFFF7F5FA);
  static const _lightOutline = Color(0xFFE3E0E9);
  static const _lightText = Color(0xFF1C1B1F);
  static const _lightMuted = Color(0xFF6B6B75);

  // 深色 token
  static const _darkSurface = Color(0xFF171A21);
  static const _darkBackground = Color(0xFF0E1015);
  static const _darkOutline = Color(0xFF252A35);
  static const _darkText = Color(0xFFE7EAF2);
  static const _darkMuted = Color(0xFF98A2B3);

  static ThemeData light(AccentColor accent) =>
      _build(accent, Brightness.light);

  static ThemeData dark(AccentColor accent) => _build(accent, Brightness.dark);

  static ThemeData _build(AccentColor accent, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // 深色下种子色要提亮，否则在深底上发闷
    final seed = isDark ? Color.lerp(accent.seed, Colors.white, 0.28)! : accent.seed;

    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    ).copyWith(
      surface: isDark ? _darkSurface : _lightSurface,
      outline: isDark ? _darkOutline : _lightOutline,
      outlineVariant: isDark ? _darkOutline : _lightOutline,
      onSurface: isDark ? _darkText : _lightText,
    );

    final text = isDark ? _darkText : _lightText;
    final muted = isDark ? _darkMuted : _lightMuted;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? _darkBackground : _lightBackground,
      splashFactory: InkSparkle.splashFactory,
      textTheme: Typography.material2021(platform: TargetPlatform.iOS)
          .black
          .apply(bodyColor: text, displayColor: text),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? _darkBackground : _lightBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: text),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? _darkSurface : _lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isDark ? _darkOutline : _lightOutline,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 78,
        backgroundColor: isDark ? _darkSurface : _lightSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w400,
            color: states.contains(WidgetState.selected) ? scheme.primary : muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected) ? scheme.primary : muted,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF12151C) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? _darkOutline : _lightOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? _darkOutline : _lightOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        hintStyle: TextStyle(color: muted.withValues(alpha: 0.8), fontSize: 14),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SoftPageTransitionsBuilder(),
          TargetPlatform.iOS: SoftPageTransitionsBuilder(),
          TargetPlatform.macOS: SoftPageTransitionsBuilder(),
          TargetPlatform.windows: SoftPageTransitionsBuilder(),
          TargetPlatform.linux: SoftPageTransitionsBuilder(),
          TargetPlatform.fuchsia: SoftPageTransitionsBuilder(),
        },
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? _darkOutline : _lightOutline,
        thickness: 1,
        space: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.primary
              : (isDark ? const Color(0xFF3A404D) : const Color(0xFFD8D4DE)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? _darkSurface : _lightSurface,
        side: BorderSide(color: isDark ? _darkOutline : _lightOutline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        labelStyle: TextStyle(fontSize: 12, color: muted),
      ),
    );
  }

  // 模块用的中性色（不随主题色变）
  static Color muted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _darkMuted : _lightMuted;

  static Color softSurface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF12151C)
          : const Color(0xFFF1EEF7);
}
