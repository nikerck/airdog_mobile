import 'package:dio/dio.dart';

import '../network/api_client.dart';
import '../network/api_exception.dart';

class LoginResult {
  const LoginResult({
    required this.token,
    required this.userName,
    this.userId,
  });

  final String token;
  final String userName;
  final String? userId;
}

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<LoginResult> login(String username, String password) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/auth/login',
        data: {'username': username, 'password': password},
      );
      final data = ApiClient.unwrap(response);
      final user = data['user'];
      return LoginResult(
        token: (data['token'] as String?) ?? '',
        userName: user is Map ? (user['name'] as String? ?? username) : username,
        userId: user is Map ? user['id'] as String? : null,
      );
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}

extension AuthApiLogout on AuthApi {
  Future<void> logout() async {
    try {
      await _dio.post<dynamic>('/api/auth/logout');
    } catch (_) {
      // 登出失败不影响本地清理
    }
  }
}

/// 给页面用：把异常转成一句能展示的话。
String readableAuthError(Object error) => ApiClient.toApiException(error).message;

extension ApiExceptionX on ApiException {
  bool get needsLogin => isAuth;
}
