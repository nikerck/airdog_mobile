import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme/app_theme.dart';

/// 在 main() 里 override 成真实实例。
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider 未初始化'),
);

@immutable
class Appearance {
  const Appearance({required this.accent, required this.brightness});

  final AccentColor accent;
  final Brightness brightness;

  Appearance copyWith({AccentColor? accent, Brightness? brightness}) =>
      Appearance(
        accent: accent ?? this.accent,
        brightness: brightness ?? this.brightness,
      );
}

class AppearanceController extends Notifier<Appearance> {
  static const _kAccent = 'appearance.accent';
  static const _kDark = 'appearance.dark';

  @override
  Appearance build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final accentName = prefs.getString(_kAccent);
    final accent = AccentColor.values.firstWhere(
      (a) => a.name == accentName,
      orElse: () => AccentColor.purple,
    );
    return Appearance(
      accent: accent,
      brightness: (prefs.getBool(_kDark) ?? false)
          ? Brightness.dark
          : Brightness.light,
    );
  }

  void setAccent(AccentColor accent) {
    state = state.copyWith(accent: accent);
    ref.read(sharedPreferencesProvider).setString(_kAccent, accent.name);
  }

  void setBrightness(Brightness brightness) {
    state = state.copyWith(brightness: brightness);
    ref
        .read(sharedPreferencesProvider)
        .setBool(_kDark, brightness == Brightness.dark);
  }
}

final appearanceProvider =
    NotifierProvider<AppearanceController, Appearance>(AppearanceController.new);
