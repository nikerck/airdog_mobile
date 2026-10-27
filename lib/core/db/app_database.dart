/// 本地 SQLite（drift）与表结构注册。
///
/// 角色：**服务端数据的本地镜像**，不是权威。界面永远读这里（所以离线也能看），
/// 写操作由 SyncService 负责把变更同步到服务端。
///
/// 所有业务表都带四个同步字段：
/// - `updatedAt`：服务端生成，增量拉取的依据
/// - `deletedAt`：软删除（墓碑），否则别的设备不知道「这条被删了」
/// - `rev`：乐观锁版本，PATCH 时带上，冲突会被拒
/// - `spaceId`：属于个人空间还是共享空间（生理期永远 personal）
///
/// schemaVersion 每次改表都要 +1 并写 migration，见下方 onUpgrade。
library;
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [TodoItems, PeriodLogs, FileCache, Wishes, WishSavings, Photos])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'xiaowo'));

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // v1 → v2：待办增加「正文」和「图片」两列
          if (from < 2) {
            await m.addColumn(todoItems, todoItems.content);
            await m.addColumn(todoItems, todoItems.images);
          }
          // v2 → v3：新增经期记录表
          if (from < 3) {
            await m.createTable(periodLogs);
          }
          // v3 → v4：图片 fileId 映射 + 本地缓存表
          if (from < 4) {
            await m.addColumn(todoItems, todoItems.imageIds);
            await m.createTable(fileCache);
          }
          // v4 → v5：愿望单 + 攒钱记录
          if (from < 5) {
            await m.createTable(wishes);
            await m.createTable(wishSavings);
          }
          // v5 → v6：相册
          if (from < 6) {
            await m.createTable(photos);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

/// 空间 id：v0.1 只有个人空间和共享空间两个常量。
class Spaces {
  const Spaces._();

  static const personal = 'sp_personal';
  static const shared = 'sp_shared';
}

/// 成员 id：接后端之前先用固定值。
class Members {
  const Members._();

  static const me = 'u_me';
  static const momo = 'u_momo';
}
