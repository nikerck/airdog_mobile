import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/appearance.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class WorkbenchApp extends ConsumerWidget {
  const WorkbenchApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: '小窝',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light(appearance.accent),
      darkTheme: AppTheme.dark(appearance.accent),
      // 明暗完全由用户手动选，不跟随系统
      themeMode: appearance.brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      // 换主题色 / 明暗时做 320ms 的平滑过渡，而不是硬切
      themeAnimationDuration: const Duration(milliseconds: 320),
      themeAnimationCurve: Curves.easeOutCubic,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
