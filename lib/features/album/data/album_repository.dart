import 'package:drift/drift.dart';

import '../../../core/api/file_api.dart';
import '../../../core/db/app_database.dart';
import '../../../core/media/photo_store.dart';

/// 相册仓库。
///
/// 图片文件放服务端（有网络时），索引放本地 drift；
/// 以后后端补了 /api/photos，把 add/remove 换成接口调用即可，UI 不用动。
class AlbumRepository {
  AlbumRepository(this._db, {this.fileApi, PhotoStore? store})
    : _store = store ?? PhotoStore();

  final AppDatabase _db;
  final FileApi? fileApi;
  final PhotoStore _store;

  bool get online => fileApi != null;

  Stream<List<Photo>> watch() {
    final query = _db.select(_db.photos)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.takenAt, mode: OrderingMode.desc),
      ]);
    return query.watch();
  }

  /// 选图 → 复制到本地 → 上传拿 fileId → 落库。
  /// 返回新增数量；上传失败也照样入库，只是没有 fileId。
  Future<int> addPicked() async {
    final paths = await _store.pick();
    if (paths.isEmpty) return 0;

    var added = 0;
    for (final path in paths) {
      final meta = await _store.readMeta(path);
      var fileId = '';

      if (fileApi != null) {
        try {
          fileId = (await fileApi!.upload(path)).id;
        } catch (_) {
          // 上传失败：照片仍然留在本地，之后再补传
        }
      }

      final now = DateTime.now();
      await _db
          .into(_db.photos)
          .insert(
            PhotosCompanion.insert(
              id: 'photo_${now.microsecondsSinceEpoch}_$added',
              fileId: Value(fileId),
              path: path,
              takenAt: now,
              width: Value(meta.width),
              height: Value(meta.height),
              sizeBytes: Value(meta.sizeBytes),
              createdAt: now,
              updatedAt: now,
            ),
          );
      added++;
    }
    return added;
  }

  Future<void> updateCaption(Photo photo, String caption) async {
    await (_db.update(_db.photos)..where((t) => t.id.equals(photo.id))).write(
      PhotosCompanion(
        caption: Value(caption),
        updatedAt: Value(DateTime.now()),
        rev: Value(photo.rev + 1),
      ),
    );
  }

  Future<void> remove(Photo photo) async {
    final now = DateTime.now();
    await (_db.update(_db.photos)..where((t) => t.id.equals(photo.id))).write(
      PhotosCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        rev: Value(photo.rev + 1),
      ),
    );

    // 服务端那份也删掉，省空间；删不掉不影响本地
    if (fileApi != null && photo.fileId.isNotEmpty) {
      try {
        await fileApi!.delete(photo.fileId);
      } catch (_) {}
    }
    await _store.deleteFiles([photo.path]);
  }
}
