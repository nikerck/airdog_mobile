/// 相册接口 `/api/photos`。
///
/// 相册的「照片」其实是两段：图片文件在 /api/files，这里登记的是
/// 「哪张图属于相册、什么时候拍的、说明写了什么」。
/// 服务端目前只提供增 / 查 / 删，没有 PATCH —— 所以说明暂时改不了。
library;

import 'package:dio/dio.dart';

import '../network/api_client.dart';
import 'dto.dart';

class PhotoApi {
  PhotoApi(this._dio);

  final Dio _dio;

  /// 把已上传的图片加入相册。[fileId] 必须是自己上传且未删除的文件。
  Future<PhotoDto> create({
    required String spaceId,
    required String fileId,
    String caption = '',
    int? takenAt,
  }) async {
    try {
      final res = await _dio.post<dynamic>('/api/photos', data: {
        'spaceId': spaceId,
        'fileId': fileId,
        'caption': caption,
        'takenAt': takenAt,
      });
      return _item(res);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  /// 照片列表。不传 since 时不返回墓碑，按拍摄时间倒序。
  Future<List<PhotoDto>> list({String? spaceId, int? since, int limit = 200}) async {
    try {
      final params = <String, dynamic>{'limit': limit};
      if (spaceId != null) params['spaceId'] = spaceId;
      if (since != null) params['since'] = since;
      final res = await _dio.get<dynamic>('/api/photos', queryParameters: params);
      final data = ApiClient.unwrap(res);
      final items = data['items'];
      if (items is! List) return const [];
      return items
          .whereType<Map>()
          .map((e) => PhotoDto.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      final res = await _dio.delete<dynamic>('/api/photos/$id');
      ApiClient.unwrap(res);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  PhotoDto _item(Response<dynamic> res) {
    final data = ApiClient.unwrap(res);
    final item = data['item'];
    if (item is Map) return PhotoDto.fromJson(Map<String, dynamic>.from(item));
    throw ApiClient.toApiException(StateError('响应里没有 item'));
  }
}
