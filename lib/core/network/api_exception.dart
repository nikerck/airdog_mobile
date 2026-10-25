/// 网络错误的统一出口：页面只需要展示 message，不需要认识 DioException。
enum ApiErrorKind { network, timeout, unauthorized, forbidden, notFound, server, badResponse }

class ApiException implements Exception {
  ApiException(this.kind, this.message, {this.code});

  final ApiErrorKind kind;
  final String message;
  final int? code;

  bool get isAuth => kind == ApiErrorKind.unauthorized;

  @override
  String toString() => 'ApiException($kind, $message)';
}
