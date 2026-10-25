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

/// 启动时清掉早期版本留下的示例数据，只跑一次。
final demoCleanupProvider = FutureProvider<void>((ref) async {
  await ref.watch(todoRepositoryProvider).purgeDemoRows();
});

final todosProvider = StreamProvider<List<TodoItem>>((ref) {
  ref.watch(demoCleanupProvider);
  return ref.watch(todoRepositoryProvider).watch();
});
