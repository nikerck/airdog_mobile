/// 经期仓库：写操作走 SyncService，读走本地流。
///
/// 服务端强制个人空间，所以这里的 spaceId 写死 personal。
library;
import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/sync/sync_service.dart';

/// 经期记录的数据入口。只写个人空间。
class PeriodRepository {
  PeriodRepository(this._db, {this.sync});

  final AppDatabase _db;
  final SyncService? sync;

  bool get online => sync != null;

  Stream<List<PeriodLog>> watch({String spaceId = Spaces.personal}) {
    final query = _db.select(_db.periodLogs)
      ..where((t) => t.spaceId.equals(spaceId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm(expression: t.startedOn)]);
    return query.watch();
  }

  Future<void> add({
    required DateTime startedOn,
    DateTime? endedOn,
    int flow = 2,
    List<String> symptoms = const [],
    String note = '',
  }) async {
    if (sync != null) {
      await sync!.createPeriod(
        startedOn: startedOn,
        endedOn: endedOn,
        flow: flow,
        symptoms: symptoms,
        note: note,
      );
      return;
    }
    final now = DateTime.now();
    await _db.into(_db.periodLogs).insert(
          PeriodLogsCompanion.insert(
            id: 'period_${now.microsecondsSinceEpoch}',
            spaceId: Spaces.personal,
            startedOn: startedOn,
            endedOn: Value(endedOn),
            flow: Value(flow),
            symptoms: Value(symptoms.join(',')),
            note: Value(note),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  /// 给「还没结束」的那条补上结束日期。
  Future<void> finish(PeriodLog log, DateTime endedOn) async {
    if (sync != null) {
      await sync!.finishPeriod(log, endedOn);
      return;
    }
    final now = DateTime.now();
    await (_db.update(_db.periodLogs)..where((t) => t.id.equals(log.id))).write(
      PeriodLogsCompanion(
        endedOn: Value(endedOn),
        updatedAt: Value(now),
        rev: Value(log.rev + 1),
      ),
    );
  }

  Future<void> updateLog(
    PeriodLog log, {
    DateTime? startedOn,
    DateTime? endedOn,
    bool clearEnd = false,
    int? flow,
    List<String>? symptoms,
    String? note,
  }) async {
    final now = DateTime.now();
    await (_db.update(_db.periodLogs)..where((t) => t.id.equals(log.id))).write(
      PeriodLogsCompanion(
        startedOn: startedOn == null ? const Value.absent() : Value(startedOn),
        endedOn:
            clearEnd ? const Value(null) : (endedOn == null ? const Value.absent() : Value(endedOn)),
        flow: flow == null ? const Value.absent() : Value(flow),
        symptoms: symptoms == null ? const Value.absent() : Value(symptoms.join(',')),
        note: note == null ? const Value.absent() : Value(note),
        updatedAt: Value(now),
        rev: Value(log.rev + 1),
      ),
    );
  }

  Future<void> remove(PeriodLog log) async {
    if (sync != null) {
      await sync!.deletePeriod(log);
      return;
    }
    final now = DateTime.now();
    await (_db.update(_db.periodLogs)..where((t) => t.id.equals(log.id))).write(
      PeriodLogsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        rev: Value(log.rev + 1),
      ),
    );
  }
}
