import '../../../core/db/app_database.dart';

/// 一次周期汇总：页面上那三个数字 + 日历高亮都从这里出。
class PeriodSummary {
  const PeriodSummary({
    this.lastStart,
    this.nextStart,
    required this.cycleLength,
    required this.periodLength,
    this.cycleDay,
    this.daysToNext,
    this.ongoing = false,
    this.ongoingDay,
    this.lastPeriodLength,
  });

  /// 最近一次开始日期（已归零到 00:00）
  final DateTime? lastStart;

  /// 预测的下次开始
  final DateTime? nextStart;

  /// 平均周期天数（无历史时 28）
  final int cycleLength;

  /// 平均经期天数（无历史时 5）
  final int periodLength;

  /// 今天处于本周期第几天（1 起）
  final int? cycleDay;

  /// 距下次还有几天（负数表示已推迟）
  final int? daysToNext;

  /// 是否正在经期
  final bool ongoing;

  /// 本次经期第几天
  final int? ongoingDay;

  /// 最近一次「已结束」的经期长度；正在经期时为 null
  final int? lastPeriodLength;

  bool get hasData => lastStart != null;
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int daysBetween(DateTime a, DateTime b) =>
    dayOnly(b).difference(dayOnly(a)).inDays;

/// 周期计算。
///
/// 规则（产品定义）：
/// - 周期长度 = 最近 3 个「开始日期间隔」的平均，没有历史按 28 天；
/// - 经期长度 = 最近 3 次「已结束」记录的时长平均，没有历史按 5 天；
/// - 下次开始 = 最近一次开始 + 周期长度；
/// - 若最近一次没有结束日期且距今 ≤ 10 天，视为「正在经期」。
PeriodSummary summarizePeriod(List<PeriodLog> logs, DateTime today) {
  final active = logs.where((l) => l.deletedAt == null).toList()
    ..sort((a, b) => a.startedOn.compareTo(b.startedOn));

  final cycleLength = _averageCycle(active);
  final periodLength = _averagePeriod(active);

  if (active.isEmpty) {
    return PeriodSummary(
      cycleLength: cycleLength,
      periodLength: periodLength,
    );
  }

  final last = active.last;
  final lastStart = dayOnly(last.startedOn);
  final todayOnly = dayOnly(today);

  final cycleDay = todayOnly.difference(lastStart).inDays + 1;
  final nextStart = lastStart.add(Duration(days: cycleLength));
  final daysToNext = nextStart.difference(todayOnly).inDays;

  final openEnd = last.endedOn == null;
  final ongoing = openEnd && cycleDay >= 1 && cycleDay <= 10;

  final lastEnd = last.endedOn;
  final lastPeriodLength =
      lastEnd == null ? null : daysBetween(lastStart, lastEnd) + 1;

  return PeriodSummary(
    lastStart: lastStart,
    nextStart: nextStart,
    cycleLength: cycleLength,
    periodLength: periodLength,
    cycleDay: cycleDay < 1 ? null : cycleDay,
    daysToNext: daysToNext,
    ongoing: ongoing,
    ongoingDay: ongoing ? cycleDay : null,
    lastPeriodLength: lastPeriodLength,
  );
}

int _averageCycle(List<PeriodLog> logs) {
  if (logs.length < 2) return 28;
  final gaps = <int>[];
  for (var i = logs.length - 1; i > 0 && gaps.length < 3; i--) {
    final gap = daysBetween(logs[i - 1].startedOn, logs[i].startedOn);
    if (gap >= 15 && gap <= 60) gaps.add(gap);
  }
  if (gaps.isEmpty) return 28;
  return (gaps.reduce((a, b) => a + b) / gaps.length).round();
}

int _averagePeriod(List<PeriodLog> logs) {
  final durations = <int>[];
  for (var i = logs.length - 1; i >= 0 && durations.length < 3; i--) {
    final end = logs[i].endedOn;
    if (end == null) continue;
    final d = daysBetween(logs[i].startedOn, end) + 1;
    if (d >= 1 && d <= 15) durations.add(d);
  }
  if (durations.isEmpty) return 5;
  return (durations.reduce((a, b) => a + b) / durations.length).round();
}

/// 某一天是否属于「已记录」的经期（用于日历实心圆）。
///
/// 未结束的记录只画到「今天」，不能把未来的日期也涂成经期。
bool isPeriodDay(PeriodLog log, DateTime day, {DateTime? today}) {
  final start = dayOnly(log.startedOn);
  final target = dayOnly(day);
  if (target.isBefore(start)) return false;

  final end = log.endedOn == null ? null : dayOnly(log.endedOn!);
  if (end != null) return !target.isAfter(end);

  final limit = today == null ? start : dayOnly(today);
  return !target.isAfter(limit);
}

/// 某一天是否属于「预测」的下次经期区间。
bool isPredictedDay(PeriodSummary summary, DateTime day) {
  final next = summary.nextStart;
  if (next == null) return false;
  final target = dayOnly(day);
  if (target.isBefore(next)) return false;
  return target.difference(next).inDays < summary.periodLength;
}
