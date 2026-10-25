import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/db/db_provider.dart';
import 'data/period_repository.dart';
import 'domain/period_calculator.dart';

final periodRepositoryProvider = Provider<PeriodRepository>(
  (ref) => PeriodRepository(
    ref.watch(databaseProvider),
    sync: ref.watch(syncServiceProvider),
  ),
);

/// 离线模式下塞三条示例；在线模式不塞，避免和服务器数据混在一起。
final periodSeedProvider = FutureProvider<void>((ref) async {
  if (ref.watch(syncServiceProvider) != null) return;

  final repo = ref.watch(periodRepositoryProvider);
  final db = ref.watch(databaseProvider);
  final existing = await db.select(db.periodLogs).get();
  if (existing.isNotEmpty) return;

  final today = dayOnly(DateTime.now());
  for (final offset in [79, 51, 23]) {
    final start = today.subtract(Duration(days: offset));
    await repo.add(
      startedOn: start,
      endedOn: start.add(const Duration(days: 4)),
      flow: 2,
      symptoms: const ['cramp'],
    );
  }
});

final periodLogsProvider = StreamProvider<List<PeriodLog>>((ref) {
  ref.watch(periodSeedProvider);
  return ref.watch(periodRepositoryProvider).watch();
});

final periodSummaryProvider = Provider<PeriodSummary>((ref) {
  final logs = ref.watch(periodLogsProvider).valueOrNull ?? const <PeriodLog>[];
  return summarizePeriod(logs, DateTime.now());
});
