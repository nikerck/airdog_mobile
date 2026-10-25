import 'package:flutter_test/flutter_test.dart';

import 'package:airdog_mobile/core/db/app_database.dart';
import 'package:airdog_mobile/modules/wish/domain/wish_stats.dart';

Wish wish({String id = 'w1', int price = 189900, int priority = 2}) => Wish(
      id: id,
      spaceId: 'sp_shared',
      title: '相机镜头',
      price: price,
      priority: priority,
      link: '',
      note: '',
      createdBy: 'u_me',
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
      rev: 1,
    );

WishSaving saving({
  String id = 's1',
  String wishId = 'w1',
  String memberId = 'u_me',
  required int amount,
}) =>
    WishSaving(
      id: id,
      wishId: wishId,
      memberId: memberId,
      amount: amount,
      savedAt: DateTime(2026, 10, 2),
      createdAt: DateTime(2026, 10, 2),
      updatedAt: DateTime(2026, 10, 2),
      rev: 1,
    );

void main() {
  group('金额格式化', () {
    test('整数元不带小数', () {
      expect(formatYuan(189900), '¥1,899');
      expect(formatYuan(100), '¥1');
      expect(formatYuan(0), '¥0');
    });

    test('有角分保留两位', () {
      expect(formatYuan(189950), '¥1,899.50');
      expect(formatYuan(1), '¥0.01');
    });

    test('千分位', () {
      expect(formatYuan(123456789), '¥1,234,567.89');
    });

    test('负数（撤回攒钱）', () {
      expect(formatYuan(-50000), '-¥500');
    });
  });

  group('输入解析', () {
    test('普通数字', () {
      expect(parseYuanToCents('1899'), 189900);
      expect(parseYuanToCents('18.99'), 1899);
    });

    test('带千分位和符号也能认', () {
      expect(parseYuanToCents('¥1,899.50'), 189950);
    });

    test('空或非法返回 null', () {
      expect(parseYuanToCents(''), isNull);
      expect(parseYuanToCents('abc'), isNull);
    });
  });

  group('进度计算', () {
    test('没有任何攒钱', () {
      final s = statsFor(wish(), const []);
      expect(s.saved, 0);
      expect(s.percent, 0);
      expect(s.remaining, 189900);
      expect(s.done, isFalse);
    });

    test('攒一半', () {
      final s = statsFor(wish(), [
        saving(id: 's1', amount: 50000),
        saving(id: 's2', amount: 44950),
      ]);
      expect(s.saved, 94950);
      expect(s.percent, 50);
      expect(s.remaining, 94950);
    });

    test('超额攒钱封顶 100%', () {
      final s = statsFor(wish(price: 10000), [saving(amount: 20000)]);
      expect(s.saved, 20000);
      expect(s.percent, 100);
      expect(s.remaining, 0);
      expect(s.done, isTrue);
    });

    test('按人拆分', () {
      final s = statsFor(wish(), [
        saving(id: 's1', memberId: 'u_me', amount: 70000),
        saving(id: 's2', memberId: 'u_momo', amount: 30000),
      ]);
      expect(s.byMember['u_me'], 70000);
      expect(s.byMember['u_momo'], 30000);
    });

    test('只统计属于这个愿望的记录', () {
      final s = statsFor(wish(), [
        saving(id: 's1', amount: 5000),
        saving(id: 's2', wishId: 'other', amount: 9000),
      ]);
      expect(s.saved, 5000);
    });
  });

  group('首页副标题', () {
    test('多个愿望汇总', () {
      final wishes = [wish(id: 'w1', price: 100000), wish(id: 'w2', price: 100000)];
      final savings = {
        'w1': [saving(id: 's1', wishId: 'w1', amount: 50000)],
        'w2': [saving(id: 's2', wishId: 'w2', amount: 22000)],
      };
      expect(wishTagline(wishes, savings), '2 件 · 攒 36%');
    });

    test('空列表', () {
      expect(wishTagline(const [], const {}), '还没有愿望');
    });
  });
}
