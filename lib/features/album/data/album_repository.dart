/// 相册仓库：界面唯一的数据入口。
///
/// 两段式存储：
/// - **图片文件** → `/api/files`（上传后拿 fileId）
/// - **相册记录**（哪张图、什么时候、说明）→ `/api/photos`
///
/// 所以相册是真正共享的：换设备、对方账号都能看到同一批照片，
/// 本地 drift 只是镜像，拉取时按 fileId 把图片下载到 `album/` 目录。
library;
import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/media/photo_store.dart';
import '../../../core/sync/sync_service.dart';

class AlbumRepository {
  AlbumRepository(this._db, {this.sync, PhotoStore? store})
    : _store = store ?? PhotoStore();

  final AppDatabase _db;

  /// 不为 null 表示在线：增删都走接口，成功后回写本地。
  /// 为 null 是历史遗留的纯本地模式（登录后才能进主界面，实际走不到）。
  final SyncService? sync;
  final PhotoStore _store;

  bool get online => sync != null;

  /// 相册列表：只取没删的，按拍摄时间倒序。
  /// 界面按这个 Stream 自动刷新，不需要手动 setState。
  Stream<List<Photo>> watch() {
    final query = _db.select(_db.photos)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.takenAt, mode: OrderingMode.desc),
      ]);
    return query.watch();
  }

  /// 选图并加入相册，返回新增数量。
  ///
  /// 在线时每一步都是「上传 → 登记 → 回写本地」，中途失败会抛给页面提示；
  /// 已选中的文件仍留在本地，不会因为失败丢图。
  Future<int> addPicked() async {
    final paths = await _store.pick();
    if (paths.isEmpty) return 0;

    var added = 0;
    for (final path in paths) {
      if (sync != null) {
        await sync!.createPhoto(localPath: path);
      } else {
        final meta = await _store.readMeta(path);
        final now = DateTime.now();
        await _db.into(_db.photos).insert(
              PhotosCompanion.insert(
                id: 'photo_${now.microsecondsSinceEpoch}_$added',
                path: path,
                takenAt: now,
                width: Value(meta.width),
                height: Value(meta.height),
                sizeBytes: Value(meta.sizeBytes),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
      added++;
    }
    return added;
  }

  /// 删除照片：服务端软删 + 本地软删 + 删本地文件副本。
  Future<void> remove(Photo photo) async {
    if (sync != null) {
      await sync!.deletePhoto(photo);
      return;
    }

    final now = DateTime.now();
    await (_db.update(_db.photos)..where((t) => t.id.equals(photo.id))).write(
      PhotosCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        rev: Value(photo.rev + 1),
      ),
    );
    await _store.deleteFiles([photo.path]);
  }
}
