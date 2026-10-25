import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// 全局唯一的数据库实例；Widget 树销毁时关闭。
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
