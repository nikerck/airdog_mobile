import 'package:flutter_test/flutter_test.dart';

import 'package:airdog_mobile/core/db/app_database.dart';
import 'package:airdog_mobile/modules/todo/domain/todo_filter.dart';

TodoItem todo({
  required String id,
  required String title,
  DateTime? dueAt,
  DateTime? doneAt,
}) {
  final now = DateTime(2026, 10, 25, 12);
  return TodoItem(
    id: id,
    spaceId: Spaces.shared,
    title: title,
    content: '',
    images: '',
    imageIds: '',
    dueAt: dueAt,
    doneAt: doneAt,
    doneBy: doneAt == null ? null : Members.momo,
    createdBy: Members.me,
    createdAt: now,
    updatedAt: now,
    rev: 1,
  );
}

void main() {
  final now = DateTime(2026, 10, 25, 12);

  group('筛选', () {
    final items = [
      todo(id: '1', title: '今天未完成', dueAt: DateTime(2026, 10, 25, 18)),
      todo(
        id: '2',
        title: '今天已完成',
        dueAt: DateTime(2026, 10, 25, 9),
        doneAt: DateTime(2026, 10, 25, 10),
      ),
      todo(id: '3', title: '三天后', dueAt: DateTime(2026, 10, 28, 9)),
      todo(id: '4', title: '没日期'),
    ];

    test('全部：一条不少', () {
      expect(applyFilter(items, TodoFilter.all, now).length, 4);
    });

    test('今天：只要今天且未完成', () {
      final result = applyFilter(items, TodoFilter.today, now);
      expect(result.map((e) => e.id), ['1']);
    });

    test('已完成：只要做完的', () {
      final result = applyFilter(items, TodoFilter.done, now);
      expect(result.map((e) => e.id), ['2']);
    });

    test('今天未完成计数', () {
      expect(pendingTodayCount(items, now), 1);
    });
  });

  group('分组', () {
    final items = [
      todo(id: '1', title: '今天的', dueAt: DateTime(2026, 10, 25, 18)),
      todo(id: '2', title: '其他的', dueAt: DateTime(2026, 10, 30, 9)),
      todo(id: '3', title: '没日期的'),
    ];

    test('分成今天 / 其他', () {
      final groups = groupByDay(items, now);
      expect(groups.keys, ['今天', '其他']);
      expect(groups['今天']!.map((e) => e.id), ['1']);
      expect(groups['其他']!.map((e) => e.id), ['2', '3']);
    });

    test('只有一组时不出现空分组', () {
      final groups = groupByDay(
        [todo(id: '9', title: '只有今天', dueAt: DateTime(2026, 10, 25, 8))],
        now,
      );
      expect(groups.keys, ['今天']);
    });
  });

  group('编辑权限', () {
    test('创建人可以编辑', () {
      final item = todo(id: '1', title: '自己建的');
      expect(canEditTodo(item), isTrue);
    });

    test('对方建的不可以编辑', () {
      final item = TodoItem(
        id: '2',
        spaceId: Spaces.shared,
        title: 'Momo 建的',
        content: '',
        images: '',
        imageIds: '',
        createdBy: Members.momo,
        createdAt: DateTime(2026, 10, 25),
        updatedAt: DateTime(2026, 10, 25),
        rev: 1,
      );
      expect(canEditTodo(item), isFalse);
    });
  });

  group('日期显示', () {
    test('今天显示时分', () {
      expect(formatDue(DateTime(2026, 10, 25, 18, 5), now), '18:05');
    });

    test('明天', () {
      expect(formatDue(DateTime(2026, 10, 26, 9), now), '明天 09:00');
    });

    test('一周内显示周几', () {
      expect(formatDue(DateTime(2026, 10, 28, 9), now), '周三 09:00');
    });

    test('更远显示月日', () {
      expect(formatDue(DateTime(2026, 11, 2, 9), now), '11月2日 09:00');
    });

    test('过期', () {
      expect(formatDue(DateTime(2026, 10, 20, 9), now), '已过期');
    });
  });
}
