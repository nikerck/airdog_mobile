import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'mock_interceptor.dart';

/// 全局网络入口。baseUrl 只有一个来源：登录页输入的地址。
class ApiClient {
  ApiClient._();

  /// 默认直连真实后端；需要假数据时用 --dart-define=USE_MOCK=true。
  static const bool useMock = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: false,
  );

  /// 允许 `192.168.1.10`、`192.168.1.10:8080`、`https://host` 三种写法。
  static String normalizeBaseUrl(String input) {
    var value = input.trim();
    if (value.isEmpty) return '';
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  static Dio create({
    required String baseUrl,
    String? token,
    bool? mock,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          options.headers['X-Client'] = 'airdog-mobile/0.1';
          return handler.next(options);
        },
      ),
    );

    if (mock ?? useMock) {
      dio.interceptors.add(MockInterceptor());
    }

    return dio;
  }

  /// 统一解包 `{code, message, data}`。
  static Map<String, dynamic> unwrap(Response<dynamic> response) {
    final body = response.data;
    if (body is Map) {
      final code = body['code'];
      if (code is int && code == 0) {
        final data = body['data'];
        return data is Map<String, dynamic> ? data : <String, dynamic>{};
      }
      throw ApiException(
        _kindForStatus(response.statusCode),
        (body['message'] as String?) ?? '请求失败',
        code: code is int ? code : null,
      );
    }
    throw ApiException(ApiErrorKind.badResponse, '服务器返回了无法识别的数据');
  }

  static ApiErrorKind _kindForStatus(int? status) {
    switch (status) {
      case 401:
        return ApiErrorKind.unauthorized;
      case 403:
        return ApiErrorKind.forbidden;
      case 404:
        return ApiErrorKind.notFound;
      case 500 || 502 || 503:
        return ApiErrorKind.server;
      default:
        return ApiErrorKind.badResponse;
    }
  }

  /// 把 Dio 的异常翻译成人话。
  static ApiException toApiException(Object error) {
    if (error is ApiException) return error;
    if (error is! DioException) {
      return ApiException(ApiErrorKind.badResponse, '出了点问题：$error');
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiException(ApiErrorKind.timeout, '连接超时，请检查 IP 和端口');
      case DioExceptionType.connectionError:
        return ApiException(ApiErrorKind.network, '连不上服务器，请检查 IP 和端口');
      case DioExceptionType.cancel:
        return ApiException(ApiErrorKind.network, '请求已取消');
      case DioExceptionType.badCertificate:
        return ApiException(ApiErrorKind.network, '证书校验失败，请用 http 或配置证书');
      case DioExceptionType.badResponse:
        final res = error.response;
        final body = res?.data;
        final message = body is Map ? body['message'] as String? : null;
        final kind = _kindForStatus(res?.statusCode);
        return ApiException(
          kind,
          message ??
              switch (kind) {
                ApiErrorKind.unauthorized => '账号或密码错误',
                ApiErrorKind.forbidden => '没有权限',
                ApiErrorKind.notFound => '接口不存在',
                ApiErrorKind.server => '服务器出错了',
                _ => '请求失败',
              },
          code: res?.statusCode,
        );
      case DioExceptionType.unknown:
        final msg = error.message ?? '';
        if (msg.contains('SocketException') || msg.contains('Failed host lookup')) {
          return ApiException(ApiErrorKind.network, '连不上服务器，请检查 IP 和端口');
        }
        return ApiException(ApiErrorKind.network, '网络异常：$msg');
    }
  }
}
