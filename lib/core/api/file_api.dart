/// 文件（图片）接口：上传、下载、删除。
///
/// 后端按 sha256 去重，同一张图重复上传返回同一个 id，
/// 所以客户端可以放心地「每次都传」，不用自己算哈希。
library;
import 'dart:io';

import 'package:dio/dio.dart';

import '../network/api_client.dart';
import 'dto.dart';

class FileApi {
  FileApi(this._dio);

  final Dio _dio;

  Future<FileDto> upload(String localPath) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(localPath),
      });
      final res = await _dio.post<dynamic>(
        '/api/files',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      final data = ApiClient.unwrap(res);
      return FileDto.fromJson(data);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> delete(String fileId) async {
    try {
      final res = await _dio.delete<dynamic>('/api/files/$fileId');
      ApiClient.unwrap(res);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  /// 下载到本地，返回写入路径。GET /api/files/{id} 不需要 token。
  Future<String> download(String fileId, String savePath) async {
    try {
      final res = await _dio.get<List<int>>(
        '/api/files/$fileId',
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = res.data;
      if (bytes == null || bytes.isEmpty) {
        throw ApiClient.toApiException(StateError('图片为空'));
      }
      final file = File(savePath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      return savePath;
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
