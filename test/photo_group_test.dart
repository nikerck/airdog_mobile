import 'package:flutter_test/flutter_test.dart';

import 'package:airdog_mobile/core/db/app_database.dart';
import 'package:airdog_mobile/features/album/domain/photo_group.dart';

Photo photo({
  required String id,
  required DateTime takenAt,
  String caption = '',
  int width = 1080,
  int height = 1440,
  int size = 300000,
}) =>
    Photo(
      id: id,
      fileId: 'file_$id',
      path: '/tmp/$id.jpg',
      caption: caption,
      takenAt: takenAt,
      width: width,
      height: height,
      sizeBytes: size,
      createdAt: takenAt,
      updatedAt: takenAt,
      rev: 1,
    );

void main() {
  final now = DateTime(2026, 10, 25);

  group('按月分组', () {
    test('月份从新到旧，组内也倒序', () {
      final groups = groupByMonth([
        photo(id: 'a', takenAt: DateTime(2026, 9, 3)),
        photo(id: 'b', takenAt: DateTime(2026, 10, 20)),
        photo(id: 'c', takenAt: DateTime(2026, 10, 5)),
        photo(id: 'd', takenAt: DateTime(2026, 8, 31)),
      ], now: now);

      expect(groups.length, 3);
      expect(groups[0].label, '本月 · 2026年10月');
      expect(groups[0].photos.map((p) => p.id), ['b', 'c']);
      expect(groups[1].label, '上月 · 2026年9月');
      expect(groups[2].label, '2026年8月');
    });

    test('空列表', () {
      expect(groupByMonth(const [], now: now), isEmpty);
    });

    test('跨年也算得对', () {
      final groups = groupByMonth([
        photo(id: 'a', takenAt: DateTime(2025, 12, 31)),
        photo(id: 'b', takenAt: DateTime(2026, 1, 1)),
      ], now: DateTime(2026, 1, 2));
      expect(groups[0].label, '本月 · 2026年1月');
      // 跨年也要认出「上个月」
      expect(groups[1].label, '上月 · 2025年12月');
    });
  });

  group('体积格式化', () {
    test('三种量级', () {
      expect(formatBytes(512), '512 B');
      expect(formatBytes(12 * 1024), '12 KB');
      expect(formatBytes((1.2 * 1024 * 1024).round()), '1.2 MB');
    });

    test('未知体积', () {
      expect(formatBytes(0), '—');
    });
  });

  group('尺寸文案', () {
    test('有尺寸', () {
      expect(formatSize(1080, 1440), '1080 × 1440');
    });

    test('读不出尺寸就不显示', () {
      expect(formatSize(0, 0), '');
    });
  });
}
