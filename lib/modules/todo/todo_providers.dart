import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/db/db_provider.dart';
import 'data/todo_repository.dart';

final todoRepositoryProvider = Provider<TodoRepository>(
  (ref) => TodoRepository(
    ref.watch(databaseProvider),
    sync: ref.watch(syncServiceProvider),
  ),
);

/// 首次进入时塞几条示例（仅离线模式；在线模式以服务端为准）。
final todoSeedProvider = FutureProvider<void>((ref) async {
  await ref.watch(todoRepositoryProvider).seedIfEmpty();
});

final todosProvider = StreamProvider<List<TodoItem>>((ref) {
  ref.watch(todoSeedProvider);
  return ref.watch(todoRepositoryProvider).watch();
});
