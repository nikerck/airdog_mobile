import 'package:dio/dio.dart';

import '../network/api_client.dart';
import 'dto.dart';

class WishApi {
  WishApi(this._dio);

  final Dio _dio;

  Future<List<WishDto>> list({required String spaceId}) async {
    try {
      final res = await _dio.get<dynamic>('/api/wishes', queryParameters: {
        'spaceId': spaceId,
      });
      final data = ApiClient.unwrap(res);
      final items = data['items'];
      if (items is! List) return const [];
      return items
          .whereType<Map>()
          .map((e) => WishDto.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<WishDto> create({
    required String spaceId,
    required String title,
    required int price,
    int priority = 1,
    String link = '',
    String note = '',
  }) async {
    try {
      final res = await _dio.post<dynamic>('/api/wishes', data: {
        'spaceId': spaceId,
        'title': title,
        'price': price,
        'priority': priority,
        'link': link,
        'note': note,
      });
      return _item(res);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<WishDto> patch(String id, Map<String, dynamic> changes) async {
    try {
      final res = await _dio.patch<dynamic>('/api/wishes/$id', data: changes);
      return _item(res);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      final res = await _dio.delete<dynamic>('/api/wishes/$id');
      ApiClient.unwrap(res);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  WishDto _item(Response<dynamic> res) {
    final data = ApiClient.unwrap(res);
    final item = data['item'];
    if (item is Map) return WishDto.fromJson(Map<String, dynamic>.from(item));
    throw ApiClient.toApiException(StateError('响应里没有 item'));
  }
}

class SavingApi {
  SavingApi(this._dio);

  final Dio _dio;

  Future<List<SavingDto>> list(String wishId) async {
    try {
      final res = await _dio.get<dynamic>('/api/wishes/$wishId/savings');
      final data = ApiClient.unwrap(res);
      final items = data['items'];
      if (items is! List) return const [];
      return items
          .whereType<Map>()
          .map((e) => SavingDto.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<SavingDto> add(String wishId, {required int amount, String memberId = 'u_me'}) async {
    try {
      final res = await _dio.post<dynamic>('/api/wishes/$wishId/savings', data: {
        'amount': amount,
        'memberId': memberId,
      });
      final data = ApiClient.unwrap(res);
      final item = data['item'];
      if (item is Map) return SavingDto.fromJson(Map<String, dynamic>.from(item));
      throw ApiClient.toApiException(StateError('响应里没有 item'));
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> delete(String wishId, String savingId) async {
    try {
      final res = await _dio.delete<dynamic>('/api/wishes/$wishId/savings/$savingId');
      ApiClient.unwrap(res);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
