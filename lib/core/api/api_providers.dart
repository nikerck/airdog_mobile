import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../db/db_provider.dart';
import '../network/api_client.dart';
import '../settings/appearance.dart';
import '../sync/sync_service.dart';

/// 在线时才有 Dio；离线模式下为 null，仓库会走纯本地。
final apiDioProvider = Provider<Dio?>((ref) {
  final session = ref.watch(authProvider);
  if (session == null || session.offline) return null;
  return ApiClient.create(baseUrl: session.baseUrl, token: session.token);
});

final syncServiceProvider = Provider<SyncService?>((ref) {
  final dio = ref.watch(apiDioProvider);
  if (dio == null) return null;
  return SyncService(
    db: ref.watch(databaseProvider),
    dio: dio,
    prefs: ref.watch(sharedPreferencesProvider),
  );
});

/// 登录后触发一次增量拉取；离线或失败时为 0 / 抛错。
final startupSyncProvider = FutureProvider<int>((ref) async {
  final sync = ref.watch(syncServiceProvider);
  if (sync == null) return 0;
  return sync.pullAll();
});
