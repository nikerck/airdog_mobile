/// 登录状态机（Riverpod Notifier）。
///
/// 对外只有三个动作：signIn / signOut / 以及 state 变化。
/// state 是 null 表示未登录，restore 完成前 router 会等它。
///
/// 注意：登录失败不抛异常，而是返回一句可展示的中文错误，
/// 页面直接显示即可（异常留给「网络/数据」层）。
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../settings/appearance.dart';
import 'auth_api.dart';
import 'session.dart';
import 'session_store.dart';

class AuthController extends Notifier<Session?> {
  @override
  Session? build() => ref.watch(initialSessionProvider);

  SessionStore get _store => SessionStore(ref.read(sharedPreferencesProvider));

  /// 返回 null 表示成功，否则是给用户看的错误信息。
  Future<String?> signIn({
    required String server,
    required String username,
    required String password,
  }) async {
    final baseUrl = ApiClient.normalizeBaseUrl(server);
    if (baseUrl.isEmpty) return '请填写服务器地址';

    try {
      final dio = ApiClient.create(baseUrl: baseUrl);
      final result = await AuthApi(dio).login(username, password);
      final session = Session(
        baseUrl: baseUrl,
        userName: result.userName,
        userId: result.userId,
        token: result.token,
        offline: false,
      );
      await _store.save(session);
      state = session;
      return null;
    } catch (e) {
      return readableAuthError(e);
    }
  }

  Future<void> signOut() async {
    final session = state;
    if (session != null && !session.offline && session.token != null) {
      try {
        await AuthApi(
          ApiClient.create(baseUrl: session.baseUrl, token: session.token),
        ).logout();
      } catch (_) {
        // 服务端不可达也要能退出
      }
    }
    await _store.clear();
    state = null;
  }
}

final authProvider = NotifierProvider<AuthController, Session?>(
  AuthController.new,
);
