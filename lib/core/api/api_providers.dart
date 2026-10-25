import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_controller.dart';
import '../db/db_provider.dart';
import '../network/api_client.dart';
import '../settings/appearance.dart';
import '../sync/sync_service.dart';
import 'spaces_api.dart';

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

const _kSpacesCache = 'spaces.cache';

/// 空间与成员：以服务端为准，失败时退回上次缓存的副本。
final spacesProvider = FutureProvider<List<SpaceInfo>>((ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  final dio = ref.watch(apiDioProvider);
  if (dio == null) return _readCache(prefs);

  try {
    final spaces = await SpacesApi(dio).list();
    if (spaces.isNotEmpty) {
      await prefs.setString(
        _kSpacesCache,
        jsonEncode(spaces.map((s) => s.toJson()).toList()),
      );
    }
    return spaces;
  } catch (_) {
    return _readCache(prefs);
  }
});

List<SpaceInfo> _readCache(SharedPreferences prefs) {
  try {
    final raw = prefs.getString(_kSpacesCache);
    if (raw == null || raw.isEmpty) return const [];
    final list = jsonDecode(raw);
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => SpaceInfo.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  } catch (_) {
    return const [];
  }
}

/// 共享空间的成员表：id → 成员。
final membersByIdProvider = Provider<Map<String, SpaceMember>>((ref) {
  final spaces = ref.watch(spacesProvider).valueOrNull ?? const <SpaceInfo>[];
  for (final space in spaces) {
    if (!space.isPersonal) {
      return {for (final m in space.members) m.id: m};
    }
  }
  return const {};
});

/// 共享给我的那个人（目前只支持一个人）。
final partnerProvider = Provider<SpaceMember?>((ref) {
  final members = ref.watch(membersByIdProvider).values.toList();
  return pickPartner(members);
});
