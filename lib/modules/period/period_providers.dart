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

final periodLogsProvider = StreamProvider<List<PeriodLog>>(
  (ref) => ref.watch(periodRepositoryProvider).watch(),
);

final periodSummaryProvider = Provider<PeriodSummary>((ref) {
  final logs = ref.watch(periodLogsProvider).valueOrNull ?? const <PeriodLog>[];
  return summarizePeriod(logs, DateTime.now());
});
