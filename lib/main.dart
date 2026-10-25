import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/auth/session.dart';
import 'core/auth/session_store.dart';
import 'core/settings/appearance.dart';

/// 应用启动：
/// 1. 读本地偏好（主题、服务器地址）
/// 2. 读安全存储里的 token，恢复登录态
/// 3. 把结果注入 ProviderScope，再 runApp
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final restored = await SessionStore(prefs).restore();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        initialSessionProvider.overrideWithValue(restored),
      ],
      child: const WorkbenchApp(),
    ),
  );
}
