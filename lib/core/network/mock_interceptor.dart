import 'package:dio/dio.dart';

/// 直接在拦截器层返回假数据，不走网络。
///
/// 好处：dio / 序列化 / 错误码 / 解包这一整条链路都被真实走了一遍，
/// 等后端好了，只要 `--dart-define=USE_MOCK=false` 就能切过去。
class MockInterceptor extends Interceptor {
  MockInterceptor({
    this.latency = const Duration(milliseconds: 320),
    this.enabled = true,
  });

  final Duration latency;
  final bool enabled;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!enabled) return handler.next(options);

    final route = '${options.method.toUpperCase()} ${options.path}';
    final handlerFor = _routes[route];

    await Future<void>.delayed(latency);

    if (handlerFor == null) {
      // Mock 模式下没实现的接口也返回结构化错误，方便页面提前处理
      return handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: 404,
          data: {'code': 404, 'message': '接口还没实现：$route', 'data': null},
        ),
      );
    }

    final result = handlerFor(options);
    return handler.resolve(
      Response<dynamic>(
        requestOptions: options,
        statusCode: result.statusCode,
        data: result.body,
      ),
    );
  }

  static final Map<String, _MockResult Function(RequestOptions)> _routes = {
    'POST /api/auth/login': (options) {
      final data = options.data;
      final username =
          (data is Map ? data['username'] as String? : null)?.trim() ?? '';
      final password = data is Map ? data['password'] as String? : null;

      if (username.isEmpty) {
        return _MockResult(400, {
          'code': 1002,
          'message': '请输入账号',
          'data': null,
        });
      }
      if (password != '123456') {
        return _MockResult(401, {
          'code': 1001,
          'message': '账号或密码错误',
          'data': null,
        });
      }
      return _MockResult(200, {
        'code': 0,
        'message': 'ok',
        'data': {
          'token': 'mock-token-${DateTime.now().millisecondsSinceEpoch}',
          'user': {
            'id': 'u_me',
            'name': 'Zyy',
            'initial': 'Z',
            'color': 'primary',
          },
        },
      });
    },
    'GET /api/auth/me': (options) => _MockResult(200, {
          'code': 0,
          'message': 'ok',
          'data': {
            'id': 'u_me',
            'name': 'Zyy',
            'initial': 'Z',
          },
        }),
  };
}

class _MockResult {
  const _MockResult(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;
}
