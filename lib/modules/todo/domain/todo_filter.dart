import '../../../core/db/app_database.dart';

enum TodoFilter { all, today, done }

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 只有创建人能编辑（分享给对方的待办，对方只能看和完成）。
bool canEditTodo(TodoItem item, {String me = 'u_me'}) =>
    item.createdBy == me;

/// 图片路径存在一列里用换行分隔，这里解析。
List<String> parseImages(String raw) {
  if (raw.isEmpty) return const [];
  return raw
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

/// 纯函数，方便单测。
List<TodoItem> applyFilter(
  List<TodoItem> items,
  TodoFilter filter,
  DateTime now,
) {
  switch (filter) {
    case TodoFilter.all:
      return items;
    case TodoFilter.today:
      return items
          .where((t) =>
              t.doneAt == null && t.dueAt != null && isSameDay(t.dueAt!, now))
          .toList();
    case TodoFilter.done:
      return items.where((t) => t.doneAt != null).toList();
  }
}

/// 「今天」和「其他」两组；已完成的留在原组里（设计上是划掉，不是移走）。
Map<String, List<TodoItem>> groupByDay(List<TodoItem> items, DateTime now) {
  final today = <TodoItem>[];
  final others = <TodoItem>[];
  for (final item in items) {
    if (item.dueAt != null && isSameDay(item.dueAt!, now)) {
      today.add(item);
    } else {
      others.add(item);
    }
  }
  return {
    if (today.isNotEmpty) '今天': today,
    if (others.isNotEmpty) '其他': others,
  };
}

/// 今天未完成的条数，首页和标题都用它。
int pendingTodayCount(List<TodoItem> items, DateTime now) => items
    .where((t) => t.doneAt == null && t.dueAt != null && isSameDay(t.dueAt!, now))
    .length;

/// 时间显示：今天只给时刻，其余带上日期/星期和时刻。
String formatDue(DateTime due, DateTime now) {
  String two(int v) => v.toString().padLeft(2, '0');
  final hm = '${two(due.hour)}:${two(due.minute)}';

  if (isSameDay(due, now)) return hm;

  final diff = DateTime(due.year, due.month, due.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
  const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  if (diff == 1) return '明天 $hm';
  if (diff > 1 && diff < 7) return '周${weekdays[due.weekday - 1]} $hm';
  if (diff < 0) return '已过期';
  return '${due.month}月${due.day}日 $hm';
}
