/// 所有表的字段定义。
///
/// 几个贯穿全项目的约定：
/// - 主键 id 是字符串，服务端生成（本地写的行用时间戳拼一个）
/// - 时间统一存 DateTime（drift 会转成毫秒时间戳），和服务端一致
/// - 金额一律整数「分」，不用 double，避免 0.1+0.2 那种误差
/// - 一对多的小数据（图片路径、症状）用换行/逗号拼在一列里，
///   不做关联表 —— 这些数据量小，联表反而更慢更麻烦
library;
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

/// 相册照片（和 /api/photos 一一对应）。
///
/// 图片文件本身走 /api/files，这里存的是「哪张图属于相册 + 说明 + 拍摄时间」。
/// 服务端已经有相册表了，所以这张表是**共享数据的本地镜像**：
/// 换设备、对方账号都能看到同一批照片。
///
/// 只多出一个本地字段 [path]：照片的本地副本路径，用来渲染缩略图；
/// 换设备时它为空，拉取后按 fileId 下载补上（见 SyncService.resolveImages）。
class Photos extends Table {
  TextColumn get id => text()();

  /// 属于哪个空间（目前固定共享空间）
  TextColumn get spaceId => text().withDefault(const Constant('sp_shared'))();

  /// 服务端文件 id；离线添加时为空
  TextColumn get fileId => text().withDefault(const Constant(''))();

  /// 本地副本，渲染用（换设备后由下载补上）
  TextColumn get path => text()();
  TextColumn get caption => text().withDefault(const Constant(''))();
  DateTimeColumn get takenAt => dateTime()();
  IntColumn get width => integer().withDefault(const Constant(0))();
  IntColumn get height => integer().withDefault(const Constant(0))();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  TextColumn get createdBy => text().withDefault(const Constant('u_me'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get rev => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}
