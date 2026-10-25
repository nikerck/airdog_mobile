import 'package:drift/drift.dart';

/// 待办表。
///
/// 字段刻意比「现在用到的」多三个：`updatedAt / deletedAt / rev`，
/// 等接后端做增量同步时不用改表。
class TodoItems extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get title => text()();

  /// 正文/备注，可多行。
  TextColumn get content => text().withDefault(const Constant(''))();

  /// 图片本地路径，换行分隔（顺序即展示顺序）。用于渲染。
  TextColumn get images => text().withDefault(const Constant(''))();

  /// 服务端 fileId，换行分隔，顺序与 images 一一对应。用于同步。
  TextColumn get imageIds => text().withDefault(const Constant(''))();

  DateTimeColumn get dueAt => dateTime().nullable()();
  DateTimeColumn get doneAt => dateTime().nullable()();
  TextColumn get doneBy => text().nullable()();
  TextColumn get createdBy => text().withDefault(const Constant('u_me'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get rev => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 经期记录。只写个人空间，永远不进共享空间。
class PeriodLogs extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  DateTimeColumn get startedOn => dateTime()();
  DateTimeColumn get endedOn => dateTime().nullable()();

  /// 0 无 / 1 少 / 2 中 / 3 多
  IntColumn get flow => integer().withDefault(const Constant(2))();

  /// 症状用逗号分隔：cramp,headache,fatigue...
  TextColumn get symptoms => text().withDefault(const Constant(''))();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get rev => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 服务端文件 id 与本地缓存路径的映射。
class FileCache extends Table {
  TextColumn get fileId => text()();
  TextColumn get localPath => text()();
  TextColumn get sha256 => text().withDefault(const Constant(''))();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {fileId};
}

/// 愿望。价格用整数分，避免浮点误差。
@DataClassName('Wish')
class Wishes extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get title => text()();
  IntColumn get price => integer().withDefault(const Constant(0))();
  IntColumn get priority => integer().withDefault(const Constant(1))();
  TextColumn get link => text().withDefault(const Constant(''))();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get createdBy => text().withDefault(const Constant('u_me'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get rev => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 攒钱记录。amount 是整数分，负数表示撤回。
class WishSavings extends Table {
  TextColumn get id => text()();
  TextColumn get wishId => text()();
  TextColumn get memberId => text()();
  IntColumn get amount => integer()();
  DateTimeColumn get savedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get rev => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}
