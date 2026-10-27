/// 愿望 provider：仓库、愿望流、攒钱记录流、按愿望分组的攒钱表。
///
/// 卡片上的「已攒 / 还差 / 百分比」都由 domain/wish_stats.dart 算，页面不参与。
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/db/db_provider.dart';
import 'data/wish_repository.dart';

final wishRepositoryProvider = Provider<WishRepository>(
  (ref) => WishRepository(
    ref.watch(databaseProvider),
    sync: ref.watch(syncServiceProvider),
  ),
);

final wishesProvider = StreamProvider<List<Wish>>(
  (ref) => ref.watch(wishRepositoryProvider).watch(),
);

final wishSavingsProvider = StreamProvider<List<WishSaving>>(
  (ref) => ref.watch(wishRepositoryProvider).watchSavings(),
);

/// 按 wishId 分组的攒钱记录，卡片和详情都用它。
final savingsByWishProvider =
    Provider<Map<String, List<WishSaving>>>((ref) {
  final savings = ref.watch(wishSavingsProvider).valueOrNull ?? const <WishSaving>[];
  final map = <String, List<WishSaving>>{};
  for (final s in savings) {
    (map[s.wishId] ??= []).add(s);
  }
  return map;
});
