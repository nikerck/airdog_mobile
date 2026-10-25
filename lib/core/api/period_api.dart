import 'package:dio/dio.dart';

import '../network/api_client.dart';
import 'dto.dart';

/// 经期接口。服务端强制个人空间，不接受 spaceId。
class PeriodApi {
  PeriodApi(this._dio);

  final Dio _dio;

  Future<List<PeriodLogDto>> list({int? since, int limit = 200}) async {
    try {
      final params = <String, dynamic>{'limit': limit};
      if (since != null) params['since'] = since;
      final res =
          await _dio.get<dynamic>('/api/period/logs', queryParameters: params);
      final data = ApiClient.unwrap(res);
      final items = data['items'];
      if (items is! List) return const [];
      return items
          .whereType<Map>()
          .map((e) => PeriodLogDto.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<PeriodLogDto> create({
    required int startedOn,
    int? endedOn,
    int flow = 2,
    List<String> symptoms = const [],
    String note = '',
  }) async {
    try {
      final res = await _dio.post<dynamic>('/api/period/logs', data: {
        'spaceId': 'sp_personal',
        'startedOn': startedOn,
        'endedOn': endedOn,
        'flow': flow,
        'symptoms': symptoms,
        'note': note,
      });
      return _item(res);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<PeriodLogDto> patch(String id, Map<String, dynamic> changes) async {
    try {
      final res = await _dio.patch<dynamic>('/api/period/logs/$id', data: changes);
      return _item(res);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete<dynamic>('/api/period/logs/$id');
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  PeriodLogDto _item(Response<dynamic> res) {
    final data = ApiClient.unwrap(res);
    final item = data['item'];
    if (item is Map) return PeriodLogDto.fromJson(Map<String, dynamic>.from(item));
    throw ApiClient.toApiException(StateError('响应里没有 item'));
  }
}
