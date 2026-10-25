import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/sync/sync_service.dart';

/// 待办的数据入口。
///
/// 现在是纯本地：UI → Repository → drift。
/// 接后端时在这里加 RemoteDataSource，UI 不用动。
class TodoRepository {
  TodoRepository(this._db, {this.sync});

  final AppDatabase _db;

  /// 非 null 表示在线模式：写操作先打服务端，成功后落本地。
  final SyncService? sync;

  bool get online => sync != null;

  /// 只暴露未删除的行；未完成在前，已完成在后。
  Stream<List<TodoItem>> watch({String spaceId = Spaces.shared}) {
    final query = _db.select(_db.todoItems)
      ..where((t) => t.spaceId.equals(spaceId) & t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.doneAt, nulls: NullsOrder.first),
        (t) => OrderingTerm(expression: t.dueAt, nulls: NullsOrder.last),
        (t) => OrderingTerm(expression: t.createdAt),
      ]);
    return query.watch();
  }

  Future<void> add({
    required String title,
    String content = '',
    List<String> images = const [],
    DateTime? dueAt,
    String spaceId = Spaces.shared,
    String createdBy = Members.me,
  }) async {
    if (sync != null) {
      await sync!.createTodo(
        title: title,
        content: content,
        localImages: images,
        dueAt: dueAt,
        spaceId: spaceId,
      );
      return;
    }
    final now = DateTime.now();
    await _db.into(_db.todoItems).insert(
          TodoItemsCompanion.insert(
            id: 'todo_${now.microsecondsSinceEpoch}',
            spaceId: spaceId,
            title: title.trim(),
            content: Value(content.trim()),
            images: Value(images.join('\n')),
            dueAt: Value(dueAt),
            createdBy: Value(createdBy),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  /// 勾选 / 取消勾选。记录是谁完成的。
  Future<void> toggle(TodoItem item, {String by = Members.me}) async {
    if (sync != null) {
      await sync!.toggleTodo(item);
      return;
    }
    final now = DateTime.now();
    final done = item.doneAt == null;
    await (_db.update(_db.todoItems)..where((t) => t.id.equals(item.id))).write(
      TodoItemsCompanion(
        doneAt: Value(done ? now : null),
        doneBy: Value(done ? by : null),
        updatedAt: Value(now),
        rev: Value(item.rev + 1),
      ),
    );
  }

  Future<void> updateContent(
    TodoItem item, {
    String? title,
    String? content,
    List<String>? images,
  }) async {
    final now = DateTime.now();
    await (_db.update(_db.todoItems)..where((t) => t.id.equals(item.id))).write(
      TodoItemsCompanion(
        title: title == null ? const Value.absent() : Value(title.trim()),
        content: content == null ? const Value.absent() : Value(content.trim()),
        images: images == null ? const Value.absent() : Value(images.join('\n')),
        updatedAt: Value(now),
        rev: Value(item.rev + 1),
      ),
    );
  }

  /// 编辑页保存：标题 / 正文 / 图片 / 时间 一起写。
  Future<void> updateAll(
    TodoItem item, {
    required String title,
    required String content,
    required List<String> images,
    DateTime? dueAt,
    bool clearDue = false,
  }) async {
    if (sync != null) {
      await sync!.updateTodo(
        item,
        title: title,
        content: content,
        localImages: images,
        dueAt: clearDue ? null : dueAt,
      );
      return;
    }
    final now = DateTime.now();
    await (_db.update(_db.todoItems)..where((t) => t.id.equals(item.id))).write(
      TodoItemsCompanion(
        title: Value(title.trim()),
        content: Value(content.trim()),
        images: Value(images.join('\n')),
        dueAt: clearDue ? const Value(null) : Value(dueAt),
        updatedAt: Value(now),
        rev: Value(item.rev + 1),
      ),
    );
  }

  /// 软删除：留墓碑行，同步时能告诉后端「这条没了」。
  Future<void> remove(TodoItem item) async {
    if (sync != null) {
      await sync!.deleteTodo(item);
      return;
    }
    final now = DateTime.now();
    await (_db.update(_db.todoItems)..where((t) => t.id.equals(item.id))).write(
      TodoItemsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        rev: Value(item.rev + 1),
      ),
    );
  }

  /// 清掉早期版本塞进来的示例数据（id 以 seed_ 开头）。
  ///
  /// 这些行只存在于本地，服务端没有，删除时必然 404；
  /// 留着就是「怎么删都删不掉」的那几条。启动时顺手清掉。
  Future<int> purgeDemoRows() async {
    return (_db.delete(_db.todoItems)..where((t) => t.id.like('seed_%'))).go();
  }
}
