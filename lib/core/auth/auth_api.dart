/// 认证相关的接口封装：登录、登出、设置头像、改密码。
///
/// 约定：4xx 不会抛 DioException（见 api_client 的 validateStatus），
/// 所以每个方法都必须调 ApiClient.unwrap(res)，否则失败会被当成成功。
library;
import 'package:dio/dio.dart';

import '../network/api_client.dart';
import '../network/api_exception.dart';

class LoginResult {
  const LoginResult({
    required this.token,
    required this.userName,
    this.userId,
    this.avatarUrl,
  });

  final String token;
  final String userName;
  final String? userId;
  final String? avatarUrl;
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
        avatarUrl: user is Map ? user['avatarUrl'] as String? : null,
      );
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}

extension AuthApiProfile on AuthApi {
  /// 设置或清除头像；fileId 为 null 表示清除。
  /// 返回更新后的 avatarUrl（可能为 null）。
  Future<String?> setAvatar(String? fileId) async {
    try {
      final res = await _dio.patch<dynamic>(
        '/api/auth/avatar',
        data: {'fileId': fileId},
      );
      final data = ApiClient.unwrap(res);
      final user = data['user'];
      return user is Map ? user['avatarUrl'] as String? : null;
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  /// 改密码。当前密码错了服务端返回 401 / 1001，token 仍然有效。
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final res = await _dio.post<dynamic>(
        '/api/auth/password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
      // 服务端 4xx 不会抛异常（validateStatus < 500），必须解包才能发现失败
      ApiClient.unwrap(res);
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
