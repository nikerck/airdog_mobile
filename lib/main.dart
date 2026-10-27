/// 应用入口。
///
/// 这里只做三件事，按顺序：
/// 1. 初始化 Flutter 引擎
/// 2. 读 SharedPreferences（会话、主题、同步游标都存这里）
/// 3. 用 ProviderScope 注入这两个全局依赖，然后跑 [App]
///
/// 为什么在 main 里读会话：登录状态要在第一帧之前就确定，
/// 否则会先闪一下登录页再跳首页。
library;
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
