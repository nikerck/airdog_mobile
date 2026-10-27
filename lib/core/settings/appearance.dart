/// 外观设置：主题色（6 选 1）+ 明暗（light/dark），都存在 SharedPreferences。
///
/// 不跟随系统，产品上要求手动控制；启动时读一次，之后由 UI 修改。
library;
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
