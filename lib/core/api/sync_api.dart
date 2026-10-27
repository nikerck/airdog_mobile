/// 增量同步接口 `/api/sync/changes`。
///
/// 一次请求拉齐所有表（含墓碑），客户端按 id upsert。
/// 游标语义见 docs/同步机制.md。
library;
import 'package:dio/dio.dart';

import '../network/api_client.dart';
import 'dto.dart';

/// 增量同步：一次拉齐所有表（含墓碑）。
///
/// 服务端约定（docs/api/接口约定.md 第 8 节）：
/// - 返回 `updatedAt > since` 的所有行，按 updatedAt 升序
/// - 墓碑行也会返回（deletedAt 有值），否则客户端删不掉东西
/// - `hasMore=false` 时 `serverTime` 就是下次的游标
/// - `hasMore=true` 时用 `nextSince` 接着拉，一页最多 limit 条
class SyncApi {
  SyncApi(this._dio);

  final Dio _dio;

  Future<SyncPayload> changes({required int since, int limit = 500}) async {
    try {
      final res = await _dio.get<dynamic>('/api/sync/changes', queryParameters: {
        'since': since,
        'limit': limit,
      });
      final data = ApiClient.unwrap(res);
      List<T> read<T>(String key, T Function(Map<String, dynamic>) f) {
        final raw = data[key];
        if (raw is! List) return const [];
        return raw
            .whereType<Map>()
            .map((e) => f(Map<String, dynamic>.from(e)))
            .toList();
      }

      return SyncPayload(
        serverTime: (data['serverTime'] as num?)?.toInt() ?? 0,
        hasMore: data['hasMore'] == true,
        nextSince: (data['nextSince'] as num?)?.toInt(),
        todos: read('todos', TodoDto.fromJson),
        periodLogs: read('periodLogs', PeriodLogDto.fromJson),
        wishes: read('wishes', WishDto.fromJson),
        savings: read('savings', SavingDto.fromJson),
      );
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}

class SyncPayload {
  const SyncPayload({
    required this.serverTime,
    required this.hasMore,
    required this.todos,
    required this.periodLogs,
    required this.wishes,
    required this.savings,
    this.nextSince,
  });

  final int serverTime;
  final bool hasMore;
  final int? nextSince;
  final List<TodoDto> todos;
  final List<PeriodLogDto> periodLogs;
  final List<WishDto> wishes;
  final List<SavingDto> savings;
}
