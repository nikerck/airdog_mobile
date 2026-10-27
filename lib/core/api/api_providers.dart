/// 依赖装配层：把「会话 → 网络 → 同步 → 数据」串成一张 provider 图。
///
/// 文件内有一张 ASCII 依赖图，改动前先看一眼，避免循环依赖。
/// 原则：上层（页面）只 watch 最末端的 provider，不直接碰 Dio。
library;
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_controller.dart';
import '../db/app_database.dart';
import '../db/db_provider.dart';
import '../network/api_client.dart';
import '../settings/appearance.dart';
import '../sync/sync_poller.dart';
import '../sync/sync_service.dart';
import 'media_url.dart';
import 'spaces_api.dart';

/// 这一层把「会话 → 网络 → 数据」串起来，页面只 watch 最终的数据流。
///
/// 依赖关系（箭头 = 谁依赖谁）：
///
/// ```
/// authProvider（登录状态：baseUrl + token + userId）
///      │
///      ├─► apiDioProvider         在线才有 Dio；离线/未登录是 null
///      │        │
///      │        ├─► syncServiceProvider   拉取 + 写穿
///      │        │        └─► startupSyncProvider   冷启动拉一次
///      │        │        └─► syncPollerProvider    前台每 30 秒拉一次
///      │        │
///      │        └─► spacesProvider   空间与成员（带 prefs 缓存）
///      │                 ├─► membersByIdProvider  id → 成员
///      │                 ├─► meMemberProvider     我自己
///      │                 └─► partnersProvider     共享给我的人
///      │
///      └─► currentUserIdProvider   改数据时写 doneBy / memberId 用
/// ```
///
/// 为什么要分层：登录/登出会让 [apiDioProvider] 变成 null 或重建，
/// 下面所有依赖它的 provider 会自动跟着重建，不需要手动清理状态。

/// 在线时才有 Dio；离线模式下为 null，仓库会走纯本地。
final apiDioProvider = Provider<Dio?>((ref) {
  final session = ref.watch(authProvider);
  if (session == null || session.offline) return null;
  return ApiClient.create(baseUrl: session.baseUrl, token: session.token);
});

final syncServiceProvider = Provider<SyncService?>((ref) {
  final dio = ref.watch(apiDioProvider);
  if (dio == null) return null;
  final session = ref.watch(authProvider);
  return SyncService(
    db: ref.watch(databaseProvider),
    dio: dio,
    prefs: ref.watch(sharedPreferencesProvider),
    meId: session?.userId ?? Members.me,
  );
});

/// 前台轮询器：App 在前台时每 30 秒拉一次增量。
///
/// 它依赖 [syncServiceProvider]：退出登录后 provider 重建，旧的轮询器
/// 会通过 onDispose 自动停掉。
final syncPollerProvider = Provider<SyncPoller>((ref) {
  final sync = ref.watch(syncServiceProvider);
  final poller = SyncPoller(
    pull: () async {
      if (sync == null) return 0;
      final pulled = await sync.pullAll();

      // 顺手刷新成员信息：对方改头像/昵称后，最多 30 秒这边就能看到。
      // 内容没变的话 refresh 内部会直接返回，不触发重建。
      await ref.read(spacesProvider.notifier).refresh();
      return pulled;
    },
  );
  ref.onDispose(poller.stop);
  return poller;
});

/// 登录后触发一次增量拉取；离线或失败时为 0 / 抛错。
final startupSyncProvider = FutureProvider<int>((ref) async {
  final sync = ref.watch(syncServiceProvider);
  if (sync == null) return 0;
  return sync.pullAll();
});

const _kSpacesCache = 'spaces.cache';

/// 空间与成员：以服务端为准，失败时退回上次缓存的副本。
///
/// 用 Notifier 而不是 FutureProvider，是因为**头像/昵称会变**：
/// 轮询要能主动拉一次，并且内容没变时不要触发全界面重建。
final spacesProvider =
    AsyncNotifierProvider<SpacesController, List<SpaceInfo>>(
  SpacesController.new,
);

class SpacesController extends AsyncNotifier<List<SpaceInfo>> {
  @override
  Future<List<SpaceInfo>> build() => _load(fallbackToCache: true);

  /// 拉一次最新的空间/成员信息。
  ///
  /// [silent] = true 时：失败不抛错、内容没变不更新状态（轮询用）；
  /// 手动改完头像后调用可以传 false，确保界面立刻用上新值。
  Future<void> refresh({bool silent = true}) async {
    try {
      final next = await _load(fallbackToCache: false);
      final prev = state.valueOrNull ?? const <SpaceInfo>[];
      if (spacesEqual(prev, next)) return;
      state = AsyncData(next);
    } catch (e) {
      if (!silent) rethrow;
    }
  }

  Future<List<SpaceInfo>> _load({required bool fallbackToCache}) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final dio = ref.read(apiDioProvider);
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
      if (!fallbackToCache) rethrow;
      return _readCache(prefs);
    }
  }
}

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

/// 当前登录账号在成员表里那一条。
final meMemberProvider = Provider<SpaceMember?>((ref) {
  for (final m in ref.watch(membersByIdProvider).values) {
    if (m.isMe) return m;
  }
  return null;
});

/// 当前登录用户 id（登录返回的 userId，兜底用成员表里的 isMe）。
final currentUserIdProvider = Provider<String>((ref) {
  final fromSession = ref.watch(authProvider)?.userId;
  if (fromSession != null && fromSession.isNotEmpty) return fromSession;
  for (final m in ref.watch(membersByIdProvider).values) {
    if (m.isMe) return m.id;
  }
  return '';
});

/// 我的头像地址（已换成当前 baseUrl 的主机，可直接给 Image.network）。
final myAvatarUrlProvider = Provider<String?>((ref) {
  final baseUrl = ref.watch(authProvider)?.baseUrl ?? '';
  return resolveMediaUrl(ref.watch(meMemberProvider)?.avatarUrl, baseUrl);
});

/// 共享空间里除我之外的所有人。
final partnersProvider = Provider<List<SpaceMember>>((ref) {
  final members = ref.watch(membersByIdProvider).values.toList();
  return pickPartners(members);
});

/// 第一个共享伙伴（单人场景用；没有就 null）。
final partnerProvider = Provider<SpaceMember?>((ref) {
  final partners = ref.watch(partnersProvider);
  return partners.isEmpty ? null : partners.first;
});
