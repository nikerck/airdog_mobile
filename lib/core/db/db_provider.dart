/// 全局唯一的数据库实例。
///
/// 放成 provider 而不是单例：测试里可以 override 成内存库，
/// 也能让 Riverpod 在销毁时自动 close。
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// 全局唯一的数据库实例；Widget 树销毁时关闭。
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
