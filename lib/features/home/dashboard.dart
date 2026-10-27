/// 首页的派生数据：今日统计、模块副标题、最近打开。
///
/// 这些都是 Provider：输入是 todosProvider，输出是页面直接用的结构，
/// 数据一变首页自动重算。
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../modules/todo/domain/todo_filter.dart';
import '../../modules/todo/todo_providers.dart';
import '../../modules/wish/domain/wish_stats.dart';
import '../../modules/wish/wish_providers.dart';

/// 首页顶部「今天」卡片的数据：从待办实时聚合，不再是写死的数字。
class DashboardSummary {
  const DashboardSummary({
    required this.todayTotal,
    required this.todayDone,
    this.nextTitle,
    this.nextTime,
  });

  final int todayTotal;
  final int todayDone;
  final String? nextTitle;
  final String? nextTime;

  int get left => todayTotal - todayDone;
  double get progress => todayTotal == 0 ? 0 : todayDone / todayTotal;
}

final dashboardProvider = Provider<DashboardSummary>((ref) {
  final now = DateTime.now();
  final todos = ref.watch(todosProvider).valueOrNull ?? const <TodoItem>[];
  // 今日卡只算「到期时间在今天」的，未设日期的待办不进这张卡
  // （不然「今天」会变成「全部未完成」，失去意义）
  final today = todos
      .where((t) => t.dueAt != null && isSameDay(t.dueAt!, now))
      .toList();
  final done = today.where((t) => t.doneAt != null).length;
  // 「下一项」= 今天还没完成里，到期时间最早的那个
  final pending = today.where((t) => t.doneAt == null).toList()
    ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
  final next = pending.isEmpty ? null : pending.first;

  return DashboardSummary(
    todayTotal: today.length,
    todayDone: done,
    nextTitle: next?.title,
    nextTime: next?.dueAt == null
        ? null
        : '${next!.dueAt!.hour.toString().padLeft(2, '0')}:'
            '${next.dueAt!.minute.toString().padLeft(2, '0')}',
  );
});

/// 宫格里的副标题，由各模块按需覆盖（避免把模块塞进 provider）。
final moduleTaglinesProvider = Provider<Map<String, String>>((ref) {
  final todos = ref.watch(todosProvider).valueOrNull ?? const <TodoItem>[];
  final pending = todos.where((t) => t.doneAt == null).length;

  final wishes = ref.watch(wishesProvider).valueOrNull ?? const <Wish>[];
  final byWish = ref.watch(savingsByWishProvider);

  return {
    'todo': '$pending 项未完成',
    'wish': wishTagline(wishes, byWish),
  };
});

class RecentEntry {
  const RecentEntry({
    required this.moduleId,
    required this.title,
    required this.subtitle,
  });

  final String moduleId;
  final String title;
  final String subtitle;
}

/// 「最近打开」：现在只有待办有真实数据，取最近更新的两条。
final recentProvider = Provider<List<RecentEntry>>((ref) {
  final now = DateTime.now();
  final todos = ref.watch(todosProvider).valueOrNull ?? const <TodoItem>[];
  final sorted = [...todos]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return sorted.take(2).map((t) {
    final due = t.dueAt == null ? '未设日期' : formatDue(t.dueAt!, now);
    return RecentEntry(
      moduleId: 'todo',
      title: t.title,
      subtitle: t.doneAt != null ? '待办 · 已完成' : '待办 · $due 到期',
    );
  }).toList();
});
