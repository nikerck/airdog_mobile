/// 同步核心：服务端权威，本地 drift 只是镜像。
///
/// 三条链路（拉 / 写 / 图片）和冲突策略都在类注释里写清楚了，
/// 第一次看这块代码建议先读 docs/同步机制.md。
library;
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/dto.dart';
import '../api/file_api.dart';
import '../api/period_api.dart';
import '../api/sync_api.dart';
import '../api/todo_api.dart';
import '../api/wish_api.dart';
import '../db/app_database.dart';
import '../network/api_exception.dart';

/// 在线模式下的读写入口：**服务端是权威，drift 只是本地镜像**。
///
/// 为什么这么设计：
/// 两个人共用一份数据，冲突不可避免。与其在两端各写一套合并逻辑，
/// 不如把「谁说了算」定死：服务端。客户端所有写操作都是「先请示，再更新本地」，
/// 本地只负责让界面能立刻响应（离线读、滚动不卡）。
///
/// 三条链路：
///
/// 1. **拉**（[_pullOnce]）：`/api/sync/changes?since=游标`，
///    服务端返回 `updatedAt > since` 的所有行（含墓碑），按 id `insertOnConflictUpdate`。
///    游标存在 SharedPreferences 的 `sync.since`，取的是服务端的 `serverTime`。
///
/// 2. **写**（create/update/toggle/delete）：先调接口拿返回的完整对象，
///    再把返回对象 upsert 进本地。接口失败就抛 [ApiException]，本地保持原样 —— 
///    这样不会出现「界面上改了但服务端没改」的假同步。
///
/// 3. **图片**：图片文件不进 JSON。先 `POST /api/files` 拿 `fileId`，
///    待办只存 id 列表；本地 `file_cache` 表维护 `fileId ↔ 本地路径`，
///    拉取时缺哪张图就按 id 下载一份。
///
/// 冲突策略：`rev` 乐观锁。服务端发现版本旧了返回 409/2003，
/// 客户端先补一次全量（[pullAll]）让本地变成最新，再提示用户重试 —— 即「后写覆盖」。
class SyncService {
  SyncService({
    required this.db,
    required this.dio,
    required this.prefs,
    required this.meId,
  });

  final AppDatabase db;
  final Dio dio;
  final SharedPreferences prefs;

  /// 当前登录用户 id。不要再写死 u_me —— 换个账号就错了。
  final String meId;

  late final TodoApi _todoApi = TodoApi(dio);
  late final PeriodApi _periodApi = PeriodApi(dio);
  late final FileApi _fileApi = FileApi(dio);
  late final SyncApi _syncApi = SyncApi(dio);
  late final WishApi _wishApi = WishApi(dio);
  late final SavingApi _savingApi = SavingApi(dio);

  static const _kSince = 'sync.since';

  int get cursor => prefs.getInt(_kSince) ?? 0;

  // ---------------------------------------------------------------- 拉

  /// 正在进行的拉取。启动同步、30 秒轮询、409 冲突补拉可能撞在一起，
  /// 这里让它们共用同一次请求，避免重复打接口、重复写库。
  Future<int>? _pulling;

  /// 拉增量。可以随便并发调，内部会合并。
  Future<int> pullAll() {
    final running = _pulling;
    if (running != null) return running;

    final future = _pullOnce();
    _pulling = future;
    return future.whenComplete(() {
      if (identical(_pulling, future)) _pulling = null;
    });
  }

  Future<int> _pullOnce() async {
    var since = cursor;

    // 本地被清空（重装/换机/异常）但游标还在的话，增量永远拉不到东西，
    // 这种情况退回全量。判断依据只看会被同步的表。
    if (since > 0 && await _localIsEmpty()) {
      since = 0;
    }
    var guard = 0;
    var pulled = 0;

    while (guard++ < 20) {
      final payload = await _syncApi.changes(since: since);
      for (final dto in payload.todos) {
        await upsertTodo(dto);
        pulled++;
      }
      for (final dto in payload.periodLogs) {
        await upsertPeriod(dto);
        pulled++;
      }
      for (final dto in payload.wishes) {
        await upsertWish(dto);
        pulled++;
      }
      for (final dto in payload.savings) {
        await upsertSaving(dto);
        pulled++;
      }

      if (!payload.hasMore) {
        since = payload.serverTime;
        break;
      }
      since = payload.nextSince ?? payload.serverTime;
    }

    await prefs.setInt(_kSince, since);
    return pulled;
  }

  Future<bool> _localIsEmpty() async {
    final todos = await db.select(db.todoItems).get();
    if (todos.isNotEmpty) return false;
    final logs = await db.select(db.periodLogs).get();
    if (logs.isNotEmpty) return false;
    final wishes = await db.select(db.wishes).get();
    return wishes.isEmpty;
  }

  // ---------------------------------------------------------------- 待办（写）

  /// 新建待办：先传图 → 创建 → 用服务端返回的对象回写本地。
  ///
  /// 图片必须排在前面：服务端只接受 fileId，不认本地路径。
  Future<void> createTodo({
    required String title,
    String content = '',
    List<String> localImages = const [],
    DateTime? dueAt,
    String spaceId = Spaces.shared,
  }) async {
    final ids = await _uploadImages(localImages);
    final dto = await _todoApi.create(
      spaceId: spaceId,
      title: title,
      content: content,
      images: ids,
      dueAt: dueAt?.millisecondsSinceEpoch,
    );
    await upsertTodo(dto, localPaths: localImages);
  }

  /// 修改待办。`images` 传的是本地路径列表，方法内部会换成 fileId。
  ///
  /// 注意 `dueAt: null` 在 PATCH 里表示「清除到期时间」，
  /// 所以这里直接把 null 传下去，不能省略字段。
  Future<void> updateTodo(
    TodoItem item, {
    required String title,
    required String content,
    required List<String> localImages,
    DateTime? dueAt,
  }) async {
    final ids = await _uploadImages(localImages);
    final dto = await _guardConflict(() => _todoApi.patch(item.id, {
          'title': title,
          'content': content,
          'images': ids,
          'dueAt': dueAt?.millisecondsSinceEpoch,
          'rev': item.rev,
        }));
    await upsertTodo(dto, localPaths: localImages);
  }

  /// 勾选/取消完成。只有这个操作允许非创建人做，所以单独一个方法。
  Future<void> toggleTodo(TodoItem item) async {
    final done = item.doneAt == null;
    final now = DateTime.now().millisecondsSinceEpoch;
    final dto = await _guardConflict(() => _todoApi.patch(item.id, {
          'doneAt': done ? now : null,
          'doneBy': done ? meId : null,
          'rev': item.rev,
        }));
    await upsertTodo(dto);
  }

  /// 删除待办。服务端删成功后本地做软删（置 deletedAt），
  /// 这样界面立刻消失，但墓碑行还留着，下次同步能和服务端对上。
  Future<void> deleteTodo(TodoItem item) async {
    try {
      await _todoApi.delete(item.id);
    } on ApiException catch (e) {
      // 服务端已经没有这条（别的设备删过 / 本地残留）就当删成功，
      // 否则本地这条会永远删不掉：每次重试都 404。
      if (!isAlreadyGone(e)) rethrow;
    }
    await _softDeleteLocalTodo(item);
  }

  // ---------------------------------------------------------------- 经期（写）

  Future<void> createPeriod({
    required DateTime startedOn,
    DateTime? endedOn,
    int flow = 2,
    List<String> symptoms = const [],
    String note = '',
  }) async {
    final dto = await _periodApi.create(
      startedOn: startedOn.millisecondsSinceEpoch,
      endedOn: endedOn?.millisecondsSinceEpoch,
      flow: flow,
      symptoms: symptoms,
      note: note,
    );
    await upsertPeriod(dto);
  }

  Future<void> finishPeriod(PeriodLog log, DateTime endedOn) async {
    final dto = await _guardConflict(() => _periodApi.patch(log.id, {
          'endedOn': endedOn.millisecondsSinceEpoch,
          'rev': log.rev,
        }));
    await upsertPeriod(dto);
  }

  Future<void> deletePeriod(PeriodLog log) async {
    try {
      await _periodApi.delete(log.id);
    } on ApiException catch (e) {
      if (!isAlreadyGone(e)) rethrow;
    }
    await (db.update(db.periodLogs)..where((t) => t.id.equals(log.id))).write(
      PeriodLogsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ---------------------------------------------------------------- 愿望（写）

  Future<void> createWish({
    required String title,
    required int price,
    int priority = 1,
    String link = '',
    String note = '',
    String spaceId = Spaces.shared,
  }) async {
    final dto = await _wishApi.create(
      spaceId: spaceId,
      title: title,
      price: price,
      priority: priority,
      link: link,
      note: note,
    );
    await upsertWish(dto);
  }

  Future<void> updateWish(
    Wish wish, {
    required String title,
    required int price,
    required int priority,
    String link = '',
    String note = '',
  }) async {
    final dto = await _guardConflict(() => _wishApi.patch(wish.id, {
          'title': title,
          'price': price,
          'priority': priority,
          'link': link,
          'note': note,
          'rev': wish.rev,
        }));
    await upsertWish(dto);
  }

  Future<void> deleteWish(Wish wish) async {
    try {
      await _wishApi.delete(wish.id);
    } on ApiException catch (e) {
      if (!isAlreadyGone(e)) rethrow;
    }
    final now = DateTime.now();
    await (db.update(db.wishes)..where((t) => t.id.equals(wish.id))).write(
      WishesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        rev: Value(wish.rev + 1),
      ),
    );
  }

  Future<void> addSaving(
    Wish wish, {
    required int amount,
    String? memberId,
  }) async {
    final dto = await _savingApi.add(
      wish.id,
      amount: amount,
      memberId: memberId ?? meId,
    );
    await upsertSaving(dto);
  }

  Future<void> deleteSaving(Wish wish, WishSaving saving) async {
    try {
      await _savingApi.delete(wish.id, saving.id);
    } on ApiException catch (e) {
      if (!isAlreadyGone(e)) rethrow;
    }
    final now = DateTime.now();
    await (db.update(db.wishSavings)..where((t) => t.id.equals(saving.id))).write(
      WishSavingsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        rev: Value(saving.rev + 1),
      ),
    );
  }

  // ---------------------------------------------------------------- 映射

  /// 把服务端的一条待办写进本地。
  ///
  /// [localPaths] 是「刚创建/刚编辑」时已知的本地图片路径，传了就不需要再下载；
  /// 从服务端拉取时不传，会按 fileId 去找缓存或下载。
  Future<void> upsertTodo(TodoDto dto, {List<String>? localPaths}) async {
    final idList = dto.images;
    final paths = localPaths ?? await resolveImages(idList);

    await db.into(db.todoItems).insertOnConflictUpdate(
          TodoItemsCompanion.insert(
            id: dto.id,
            spaceId: dto.spaceId,
            title: dto.title,
            content: Value(dto.content),
            images: Value(paths.join('\n')),
            imageIds: Value(idList.join('\n')),
            dueAt: Value(_dt(dto.dueAt)),
            doneAt: Value(_dt(dto.doneAt)),
            doneBy: Value(dto.doneBy),
            createdBy: Value(dto.createdBy),
            createdAt: _dt(dto.createdAt) ?? DateTime.now(),
            updatedAt: _dt(dto.updatedAt) ?? DateTime.now(),
            deletedAt: Value(_dt(dto.deletedAt)),
            rev: Value(dto.rev),
          ),
        );
  }

  Future<void> upsertPeriod(PeriodLogDto dto) async {
    await db.into(db.periodLogs).insertOnConflictUpdate(
          PeriodLogsCompanion.insert(
            id: dto.id,
            spaceId: Spaces.personal,
            startedOn: _dt(dto.startedOn) ?? DateTime.now(),
            endedOn: Value(_dt(dto.endedOn)),
            flow: Value(dto.flow),
            symptoms: Value(dto.symptoms.join(',')),
            note: Value(dto.note),
            createdAt: _dt(dto.createdAt) ?? DateTime.now(),
            updatedAt: _dt(dto.updatedAt) ?? DateTime.now(),
            deletedAt: Value(_dt(dto.deletedAt)),
            rev: Value(dto.rev),
          ),
        );
  }

  Future<void> upsertWish(WishDto dto) async {
    await db.into(db.wishes).insertOnConflictUpdate(
          WishesCompanion.insert(
            id: dto.id,
            spaceId: dto.spaceId,
            title: dto.title,
            price: Value(dto.price),
            priority: Value(dto.priority),
            link: Value(dto.link),
            note: Value(dto.note),
            createdBy: Value(dto.createdBy),
            createdAt: _dt(dto.createdAt) ?? DateTime.now(),
            updatedAt: _dt(dto.updatedAt) ?? DateTime.now(),
            deletedAt: Value(_dt(dto.deletedAt)),
            rev: Value(dto.rev),
          ),
        );
  }

  Future<void> upsertSaving(SavingDto dto) async {
    await db.into(db.wishSavings).insertOnConflictUpdate(
          WishSavingsCompanion.insert(
            id: dto.id,
            wishId: dto.wishId,
            memberId: dto.memberId,
            amount: dto.amount,
            savedAt: _dt(dto.savedAt) ?? DateTime.now(),
            createdAt: _dt(dto.createdAt) ?? DateTime.now(),
            updatedAt: _dt(dto.updatedAt) ?? DateTime.now(),
            deletedAt: Value(_dt(dto.deletedAt)),
            rev: Value(dto.rev),
          ),
        );
  }

  DateTime? _dt(int? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);

  // ---------------------------------------------------------------- 图片

  /// 本地路径 → 服务端 fileId。服务端按 sha256 去重，重复上传不会产生新文件。
  Future<List<String>> _uploadImages(List<String> localPaths) async {
    final ids = <String>[];
    for (final path in localPaths) {
      if (path.isEmpty) continue;
      final cached = await (db.select(db.fileCache)
            ..where((t) => t.localPath.equals(path)))
          .getSingleOrNull();
      if (cached != null) {
        ids.add(cached.fileId);
        continue;
      }
      final dto = await _fileApi.upload(path);
      await db.into(db.fileCache).insertOnConflictUpdate(
            FileCacheCompanion.insert(
              fileId: dto.id,
              localPath: path,
              sha256: Value(dto.sha256),
              syncedAt: DateTime.now(),
            ),
          );
      ids.add(dto.id);
    }
    return ids;
  }

  /// fileId → 本地路径。
  ///
  /// 顺序：先查 file_cache → 文件还在就直接用；否则按 id 下载到
  /// `<App目录>/todo_images/srv_<fileId>` 并写回缓存。
  /// 下载失败只是少一张图，绝不能因此丢掉整条待办，所以这里吞掉异常。
  Future<List<String>> resolveImages(List<String> fileIds) async {
    final paths = <String>[];
    for (final id in fileIds) {
      final cached = await (db.select(db.fileCache)
            ..where((t) => t.fileId.equals(id)))
          .getSingleOrNull();
      if (cached != null && await File(cached.localPath).exists()) {
        paths.add(cached.localPath);
        continue;
      }
      try {
        final dir = await getApplicationDocumentsDirectory();
        final savePath = p.join(dir.path, 'todo_images', 'srv_$id');
        await _fileApi.download(id, savePath);
        await db.into(db.fileCache).insertOnConflictUpdate(
              FileCacheCompanion.insert(
                fileId: id,
                localPath: savePath,
                syncedAt: DateTime.now(),
              ),
            );
        paths.add(savePath);
      } catch (_) {
        // 下载失败就留空，UI 会渲染成破图占位，不影响文字同步
      }
    }
    return paths;
  }

  // ---------------------------------------------------------------- 辅助

  Future<void> _softDeleteLocalTodo(TodoItem item) async {
    final now = DateTime.now();
    await (db.update(db.todoItems)..where((t) => t.id.equals(item.id))).write(
      TodoItemsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        rev: Value(item.rev + 1),
      ),
    );
  }

  /// 409 说明本地版本旧了：先拉一次，再把错误抛给 UI 提示刷新。
  Future<T> _guardConflict<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException catch (e) {
      if (e.code == 2003 || e.code == 9002) {
        await pullAll();
        throw ApiException(ApiErrorKind.badResponse, '数据已被更新，已为你刷新');
      }
      rethrow;
    }
  }
}
