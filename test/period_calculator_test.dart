import 'package:flutter_test/flutter_test.dart';

import 'package:airdog_mobile/core/db/app_database.dart';
import 'package:airdog_mobile/modules/period/domain/period_calculator.dart';

PeriodLog log({
  required String id,
  required DateTime start,
  DateTime? end,
}) {
  return PeriodLog(
    id: id,
    spaceId: Spaces.personal,
    startedOn: start,
    endedOn: end,
    flow: 2,
    symptoms: '',
    note: '',
    createdAt: start,
    updatedAt: start,
    rev: 1,
  );
}

void main() {
  final today = DateTime(2026, 10, 25);

  group('没有历史', () {
    test('默认 28 / 5，没有预测', () {
      final s = summarizePeriod(const [], today);
      expect(s.hasData, isFalse);
      expect(s.cycleLength, 28);
      expect(s.periodLength, 5);
      expect(s.nextStart, isNull);
      expect(s.ongoing, isFalse);
    });
  });

  group('单次记录', () {
    final logs = [
      log(
        id: '1',
        start: DateTime(2026, 10, 2),
        end: DateTime(2026, 10, 6),
      ),
    ];

    test('周期第几天 / 下次预测', () {
      final s = summarizePeriod(logs, today);
      expect(s.cycleDay, 24); // 10/2 + 23 天
      expect(s.cycleLength, 28);
      expect(s.periodLength, 5);
      expect(s.nextStart, DateTime(2026, 10, 30));
      expect(s.daysToNext, 5);
      expect(s.ongoing, isFalse);
    });

    test('未结束的记录只画到今天', () {
      final open = log(id: '9', start: DateTime(2026, 10, 23));
      expect(isPeriodDay(open, DateTime(2026, 10, 25), today: today), isTrue);
      expect(isPeriodDay(open, DateTime(2026, 10, 26), today: today), isFalse);
    });

    test('经期内的日子被标记', () {
      expect(isPeriodDay(logs.first, DateTime(2026, 10, 2)), isTrue);
      expect(isPeriodDay(logs.first, DateTime(2026, 10, 6)), isTrue);
      expect(isPeriodDay(logs.first, DateTime(2026, 10, 7)), isFalse);
      expect(isPeriodDay(logs.first, DateTime(2026, 10, 1)), isFalse);
    });

    test('预测区间是下次开始起的 5 天', () {
      final s = summarizePeriod(logs, today);
      expect(isPredictedDay(s, DateTime(2026, 10, 30)), isTrue);
      expect(isPredictedDay(s, DateTime(2026, 11, 3)), isTrue);
      expect(isPredictedDay(s, DateTime(2026, 11, 4)), isFalse);
    });
  });

  group('多次记录', () {
    test('周期长度取最近三次间隔的平均', () {
      final logs = [
        log(id: '1', start: DateTime(2026, 7, 1), end: DateTime(2026, 7, 5)),
        log(id: '2', start: DateTime(2026, 7, 30), end: DateTime(2026, 8, 3)), // 29
        log(id: '3', start: DateTime(2026, 8, 28), end: DateTime(2026, 9, 1)), // 29
        log(id: '4', start: DateTime(2026, 9, 26), end: DateTime(2026, 9, 30)), // 29
      ];
      final s = summarizePeriod(logs, today);
      expect(s.cycleLength, 29);
      expect(s.nextStart, DateTime(2026, 10, 25));
      expect(s.daysToNext, 0);
    });

    test('经期长度取已结束记录的平均', () {
      final logs = [
        log(id: '1', start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 4)), // 4
        log(id: '2', start: DateTime(2026, 9, 29), end: DateTime(2026, 10, 4)), // 6
      ];
      final s = summarizePeriod(logs, today);
      expect(s.periodLength, 5);
    });
  });

  group('正在经期', () {
    test('未结束且 10 天内 -> ongoing', () {
      final logs = [
        log(id: '1', start: DateTime(2026, 10, 22)),
      ];
      final s = summarizePeriod(logs, today);
      expect(s.ongoing, isTrue);
      expect(s.ongoingDay, 4);
    });

    test('未结束但超过 10 天 -> 不算在经期', () {
      final logs = [
        log(id: '1', start: DateTime(2026, 10, 1)),
      ];
      final s = summarizePeriod(logs, today);
      expect(s.ongoing, isFalse);
      expect(s.cycleDay, 25);
    });
  });
}
