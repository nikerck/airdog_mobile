/// 待办的 CRUD 接口。
///
/// PATCH 的语义：只传要改的字段；`dueAt: null` 表示「清除到期时间」，
/// 而不是「不修改」—— 这两者在后端是不同分支。
library;
import 'package:dio/dio.dart';

import '../network/api_client.dart';
import 'dto.dart';

/// 待办接口。路径与字段见 docs/api/openapi.yaml。
class TodoApi {
  TodoApi(this._dio);

  final Dio _dio;

  Future<List<TodoDto>> list({
    required String spaceId,
    String status = 'all',
    int? since,
    int limit = 200,
  }) async {
    try {
      final params = <String, dynamic>{
        'spaceId': spaceId,
        'status': status,
        'limit': limit,
      };
      if (since != null) params['since'] = since;
      final res = await _dio.get<dynamic>('/api/todos', queryParameters: params);
      final data = ApiClient.unwrap(res);
      final items = data['items'];
      if (items is! List) return const [];
      return items
          .whereType<Map>()
          .map((e) => TodoDto.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<TodoDto> create({
    required String spaceId,
    required String title,
    String content = '',
    List<String> images = const [],
    int? dueAt,
  }) async {
    try {
      final res = await _dio.post<dynamic>('/api/todos', data: {
        'spaceId': spaceId,
        'title': title,
        'content': content,
        'images': images,
        'dueAt': dueAt,
      });
      return _item(res);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  /// changes 里只放要改的字段；rev 必须带。
  Future<TodoDto> patch(String id, Map<String, dynamic> changes) async {
    try {
      final res = await _dio.patch<dynamic>('/api/todos/$id', data: changes);
      return _item(res);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      final res = await _dio.delete<dynamic>('/api/todos/$id');
      ApiClient.unwrap(res);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  TodoDto _item(Response<dynamic> res) {
    final data = ApiClient.unwrap(res);
    final item = data['item'];
    if (item is Map) return TodoDto.fromJson(Map<String, dynamic>.from(item));
    throw ApiClient.toApiException(StateError('响应里没有 item'));
  }
}
