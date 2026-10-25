import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 相册的本地文件：把相册选的图复制进 App 目录，并读出尺寸。
class PhotoStore {
  /// 一次最多选几张（太多会卡，也吃流量）
  static const int pickLimit = 30;

  Future<List<String>> pick() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 88);
    if (files.isEmpty) return const [];

    final dir = await getApplicationDocumentsDirectory();
    final albumDir = Directory(p.join(dir.path, 'album'));
    await albumDir.create(recursive: true);

    final saved = <String>[];
    final stamp = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < files.length; i++) {
      final src = File(files[i].path);
      final ext = p.extension(src.path).isEmpty
          ? '.jpg'
          : p.extension(src.path);
      final dest = p.join(albumDir.path, '${stamp}_$i$ext');
      await src.copy(dest);
      saved.add(dest);
    }
    return saved;
  }

  /// 只选一张（头像用），复制进头像目录。
  Future<String?> pickSingle() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1080,
      maxHeight: 1080,
    );
    if (file == null) return null;

    final dir = await getApplicationDocumentsDirectory();
    final avatarDir = Directory(p.join(dir.path, 'avatars'));
    await avatarDir.create(recursive: true);
    final ext = p.extension(file.path).isEmpty ? '.jpg' : p.extension(file.path);
    final dest = p.join(
      avatarDir.path,
      '${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await File(file.path).copy(dest);
    return dest;
  }

  /// 读图片宽高和体积；读不出来就返回 0，不影响使用。
  Future<PhotoMeta> readMeta(String path) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      final descriptor = await ui.ImageDescriptor.encoded(
        await ui.ImmutableBuffer.fromUint8List(bytes),
      );
      final meta = PhotoMeta(
        width: descriptor.width,
        height: descriptor.height,
        sizeBytes: bytes.length,
      );
      descriptor.dispose();
      return meta;
    } catch (e) {
      debugPrint('readMeta failed: $e');
      return PhotoMeta(width: 0, height: 0, sizeBytes: File(path).lengthSync());
    }
  }

  Future<void> deleteFiles(Iterable<String> paths) async {
    for (final path in paths) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {
        // 删不掉就算了，别挡着用户操作
      }
    }
  }

  /// 读原始字节，给「保存到系统相册」用
  Future<Uint8List?> readBytes(String path) async {
    try {
      return await File(path).readAsBytes();
    } catch (_) {
      return null;
    }
  }
}

class PhotoMeta {
  const PhotoMeta({
    required this.width,
    required this.height,
    required this.sizeBytes,
  });

  final int width;
  final int height;
  final int sizeBytes;
}
