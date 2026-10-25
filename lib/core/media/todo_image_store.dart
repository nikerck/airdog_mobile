import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 待办图片的本地存储。
///
/// 图片复制进 App 私有目录（`<documents>/todo_images/`），数据库里存**绝对路径**。
/// 这样渲染时直接 `Image.file`，不用每次异步解析目录。
///
/// 接后端时要改成：上传 → 存远端 id/URL。当前阶段先本地。
class TodoImageStore {
  const TodoImageStore();

  static const _folder = 'todo_images';

  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _folder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 从相册选图（可多选），复制到私有目录，返回新路径。
  Future<List<String>> pickAndSave({int limit = 9}) async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 82);
    if (picked.isEmpty) return const [];

    final dir = await _dir();
    final saved = <String>[];
    for (var i = 0; i < picked.length && i < limit; i++) {
      final src = File(picked[i].path);
      final name =
          '${DateTime.now().microsecondsSinceEpoch}_$i${p.extension(src.path)}';
      final dest = File(p.join(dir.path, name));
      await src.copy(dest.path);
      saved.add(dest.path);
    }
    return saved;
  }

  Future<void> delete(Iterable<String> paths) async {
    for (final path in paths) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}

/// 选中但还没保存的图片（新建弹层里用）。
typedef PickedImages = List<String>;
