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

/// 服务端说「这条不存在」时，删除操作可以直接当成功。
///
/// 典型场景：别的设备已经删了，本机还留着索引；不加这个判断的话，
/// 每次删除都会 404，本地那条永远清不掉。
bool isAlreadyGone(ApiException e) =>
    e.kind == ApiErrorKind.notFound || e.code == 9004 || e.code == 404;
