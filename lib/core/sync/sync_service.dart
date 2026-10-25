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

/// 在线模式下的读写入口：服务端是权威，drift 只是本地镜像。
///
/// - 拉：`/api/sync/changes` 增量同步，按 id upsert，墓碑行进 deletedAt。
/// - 写：先调接口，成功了再把服务端返回的对象写回本地。
/// - 图片：本地路径 ↔ fileId 通过 file_cache 表映射。
class SyncService {
  SyncService({
    required this.db,
    required this.dio,
    required this.prefs,
  });

  final AppDatabase db;
  final Dio dio;
  final SharedPreferences prefs;

  late final TodoApi _todoApi = TodoApi(dio);
  late final PeriodApi _periodApi = PeriodApi(dio);
  late final FileApi _fileApi = FileApi(dio);
  late final SyncApi _syncApi = SyncApi(dio);
  late final WishApi _wishApi = WishApi(dio);
  late final SavingApi _savingApi = SavingApi(dio);

  static const _kSince = 'sync.since';

  int get cursor => prefs.getInt(_kSince) ?? 0;

  // ---------------------------------------------------------------- 拉

  Future<int> pullAll() async {
    var since = cursor;
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

  // ---------------------------------------------------------------- 待办（写）

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

  Future<void> toggleTodo(TodoItem item) async {
    final done = item.doneAt == null;
    final now = DateTime.now().millisecondsSinceEpoch;
    final dto = await _guardConflict(() => _todoApi.patch(item.id, {
          'doneAt': done ? now : null,
          'doneBy': done ? Members.me : null,
          'rev': item.rev,
        }));
    await upsertTodo(dto);
  }

  Future<void> deleteTodo(TodoItem item) async {
    await _todoApi.delete(item.id);
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
    await _periodApi.delete(log.id);
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
    await _wishApi.delete(wish.id);
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
    String memberId = Members.me,
  }) async {
    final dto = await _savingApi.add(wish.id, amount: amount, memberId: memberId);
    await upsertSaving(dto);
  }

  Future<void> deleteSaving(Wish wish, WishSaving saving) async {
    await _savingApi.delete(wish.id, saving.id);
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

  /// fileId → 本地路径；没有缓存就下载一份。
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
