/// 会话的持久化：token 走安全存储，其余走 SharedPreferences。
///
/// 为什么分开：token 泄漏等于账号被盗，不该和「上次选的服务器地址」放同一个文件。
/// 读取失败时返回 null（当未登录处理），不让损坏的数据把 App 卡死。
library;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'session.dart';

/// token 进安全存储，其余进普通偏好。
class SessionStore {
  SessionStore(this._prefs);

  final SharedPreferences _prefs;
  static const _secure = FlutterSecureStorage();

  static const _kToken = 'session.token';
  static const _kBaseUrl = 'session.baseUrl';
  static const _kUserName = 'session.userName';
  static const _kUserId = 'session.userId';
  static const _kOffline = 'session.offline';

  Future<Session?> restore() async {
    // 离线模式已移除：旧版本留下的会话一律视为未登录。

    final offline = _prefs.getBool(_kOffline) ?? false;
    String? token;
    try {
      token = await _secure.read(key: _kToken);
    } catch (e) {
      // 某些平台（如未配置的桌面端）安全存储不可用，降级为未登录
      debugPrint('读取 token 失败：$e');
    }

    final baseUrl = _prefs.getString(_kBaseUrl);
    if (token == null && !offline) return null;
    if (offline && (baseUrl == null || baseUrl.isEmpty)) return null;

    return Session(
      baseUrl: baseUrl ?? '',
      userName: _prefs.getString(_kUserName) ?? '我',
      userId: _prefs.getString(_kUserId),
      offline: offline,
      token: token,
    );
  }

  Future<void> save(Session session) async {
    await _prefs.setString(_kBaseUrl, session.baseUrl);
    await _prefs.setString(_kUserName, session.userName);
    await _prefs.setBool(_kOffline, session.offline);
    if (session.userId != null) {
      await _prefs.setString(_kUserId, session.userId!);
    }
    if (session.token != null) {
      try {
        await _secure.write(key: _kToken, value: session.token);
      } catch (e) {
        debugPrint('写入 token 失败：$e');
      }
    }
  }

  Future<void> clear() async {
    await _prefs.remove(_kBaseUrl);
    await _prefs.remove(_kUserName);
    await _prefs.remove(_kUserId);
    await _prefs.remove(_kOffline);
    try {
      await _secure.delete(key: _kToken);
    } catch (_) {}
  }
}
