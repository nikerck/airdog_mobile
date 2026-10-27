/// 生理期主页：自绘月历 + 统计卡 + 最近周期。
///
/// 日历没用第三方库：需要同时表达「已记录（实心）/ 今天（描边）/ 预测（虚线圈）」
/// 三种状态，现成组件的样式钩子不够细。
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/db/app_database.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../domain/period_calculator.dart';
import '../period_providers.dart';
import 'record_sheet.dart';
import '../../../shared/widgets/run_guarded.dart';

class PeriodPage extends ConsumerStatefulWidget {
  const PeriodPage({super.key});

  @override
  ConsumerState<PeriodPage> createState() => _PeriodPageState();
}

class _PeriodPageState extends ConsumerState<PeriodPage> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppTheme.muted(context);
    final accent = theme.brightness == Brightness.dark
        ? const Color(0xFFF472B6)
        : const Color(0xFFB3325F);
    final accentSoft = theme.brightness == Brightness.dark
        ? const Color(0xFF2A1A24)
        : const Color(0xFFFBE7EF);

    final logs = ref.watch(periodLogsProvider).valueOrNull ?? const <PeriodLog>[];
    final summary = ref.watch(periodSummaryProvider);
    final today = dayOnly(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('生理期'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: accentSoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 12, color: accent),
                  const SizedBox(width: 4),
                  Text('仅我可见', style: TextStyle(fontSize: 10, color: accent)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
          children: [
            FadeSlideIn(
              child: Text(
                _statusLine(summary),
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ),
            const SizedBox(height: 12),

            FadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: _Calendar(
                month: _month,
                today: today,
                logs: logs,
                summary: summary,
                accent: accent,
                onPrev: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
                onNext: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1),
                ),
                onPickDay: (day) => _record(initialStart: day),
              ),
            ),

            const SizedBox(height: 6),
            Row(
              children: [
                _legendDot(accent),
                Text('经期', style: TextStyle(fontSize: 11, color: muted)),
                const SizedBox(width: 14),
                _legendRing(accent),
                Text('今天', style: TextStyle(fontSize: 11, color: muted)),
                const SizedBox(width: 14),
                _legendDashed(accent),
                Text('预测', style: TextStyle(fontSize: 11, color: muted)),
                const Spacer(),
                Text('点日期可补记', style: TextStyle(fontSize: 11, color: muted)),
              ],
            ),

            const SizedBox(height: 18),
            FadeSlideIn(
              delay: const Duration(milliseconds: 120),
              child: _StatsCard(summary: summary, accent: accent),
            ),

            const SizedBox(height: 14),
            if (summary.ongoing)
              FilledButton(
                onPressed: () => _finishToday(logs, today),
                style: FilledButton.styleFrom(backgroundColor: accent),
                child: const Text('今天结束了'),
              )
            else
              FilledButton(
                onPressed: () => _record(),
                style: FilledButton.styleFrom(backgroundColor: accent),
                child: const Text('记录今天的状况'),
              ),

            const SizedBox(height: 24),
            const Text(
              '最近周期',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (logs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  '还没有记录，点上面的按钮开始',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              )
            else
              for (final log in logs.reversed.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _LogRow(
                    log: log,
                    onDelete: () => _delete(log),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  String _statusLine(PeriodSummary s) {
    if (!s.hasData) return '还没有记录';
    if (s.ongoing) {
      return '经期第 ${s.ongoingDay} 天 · 记得休息';
    }
    final toNext = s.daysToNext ?? 0;
    final tail = toNext > 0 ? '距下次 $toNext 天' : (toNext == 0 ? '预计今天开始' : '已推迟 ${-toNext} 天');
    return '周期第 ${s.cycleDay} 天 · $tail';
  }

  Widget _legendDot(Color accent) => Padding(
        padding: const EdgeInsets.only(right: 5),
        child: Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        ),
      );

  Widget _legendRing(Color accent) => Padding(
        padding: const EdgeInsets.only(right: 5),
        child: Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accent, width: 1.6),
          ),
        ),
      );

  Widget _legendDashed(Color accent) => Padding(
        padding: const EdgeInsets.only(right: 5),
        child: Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.2),
          ),
        ),
      );

  Future<void> _record({DateTime? initialStart}) async {
    final ok = await showRecordPeriodSheet(
      context,
      repo: ref.read(periodRepositoryProvider),
      initialStart: initialStart,
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已记录')));
    }
  }

  Future<void> _finishToday(List<PeriodLog> logs, DateTime today) async {
    final open = logs.where((l) => l.endedOn == null).toList();
    if (open.isEmpty) return;
    await runGuarded(
      context,
      () => ref.read(periodRepositoryProvider).finish(open.last, today),
      successMessage: '已记录结束日期',
    );
  }

  Future<void> _delete(PeriodLog log) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: const Text('删除后周期统计会重新计算。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await runGuarded(
      context,
      () => ref.read(periodRepositoryProvider).remove(log),
    );
  }
}

/// 自己画的月历，不引第三方的表格组件。
class _Calendar extends StatelessWidget {
  const _Calendar({
    required this.month,
    required this.today,
    required this.logs,
    required this.summary,
    required this.accent,
    required this.onPrev,
    required this.onNext,
    required this.onPickDay,
  });

  final DateTime month;
  final DateTime today;
  final List<PeriodLog> logs;
  final PeriodSummary summary;
  final Color accent;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onPickDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppTheme.muted(context);

    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // 周一为一周第一天
    final leading = (first.weekday + 6) % 7;
    final rows = ((leading + daysInMonth) / 7).ceil();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  '${month.year}年${month.month}月',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              for (final w in ['一', '二', '三', '四', '五', '六', '日'])
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: _cell(
                      r * 7 + c - leading + 1,
                      daysInMonth,
                      theme,
                      muted,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(int dayNumber, int daysInMonth, ThemeData theme, Color muted) {
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 44);
    }
    final day = DateTime(month.year, month.month, dayNumber);
    final isToday = daysBetween(day, today) == 0;
    final recorded = logs.any((l) => isPeriodDay(l, day, today: today));
    final predicted = !recorded && isPredictedDay(summary, day);
    final isFuture = day.isAfter(today);

    Color textColor = isFuture ? muted : theme.colorScheme.onSurface;
    if (recorded) textColor = Colors.white;

    return InkWell(
      onTap: () => onPickDay(day),
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 44,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: recorded ? accent : null,
              shape: BoxShape.circle,
              border: Border.all(
                color: isToday
                    ? accent
                    : (predicted
                        ? accent.withValues(alpha: 0.45)
                        : Colors.transparent),
                width: isToday ? 1.8 : 1.2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$dayNumber',
              style: TextStyle(
                fontSize: 13.5,
                color: textColor,
                fontWeight: (isToday || recorded) ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.summary, required this.accent});

  final PeriodSummary summary;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppTheme.muted(context);

    final periodText = summary.ongoing
        ? '第 ${summary.ongoingDay} 天'
        : (summary.lastPeriodLength == null
            ? '—'
            : '${summary.lastPeriodLength} 天');
    final cycleText = summary.hasData ? '${summary.cycleLength} 天' : '默认 28 天';
    final nextText = summary.hasData
        ? ((summary.daysToNext ?? 0) > 0
            ? '${summary.daysToNext} 天后'
            : ((summary.daysToNext ?? 0) == 0 ? '今天' : '已推迟'))
        : '—';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          _stat('本次经期', periodText, muted),
          _divider(theme),
          _stat('周期长度', cycleText, muted),
          _divider(theme),
          _stat('下次预计', nextText, muted, valueColor: accent),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color muted, {Color? valueColor}) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: muted)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(ThemeData theme) => Container(
        width: 1,
        height: 34,
        color: theme.dividerColor,
      );
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.log, required this.onDelete});

  final PeriodLog log;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppTheme.muted(context);
    final start = dayOnly(log.startedOn);
    final end = log.endedOn == null ? null : dayOnly(log.endedOn!);
    final length = end == null ? null : daysBetween(start, end) + 1;

    final rangeText = end == null
        ? '${start.month}月${start.day}日 – 至今'
        : '${start.month}月${start.day}日 – ${end.month}月${end.day}日';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rangeText, style: const TextStyle(fontSize: 13.5)),
                const SizedBox(height: 3),
                Text(
                  [
                    if (length != null) '$length 天',
                    '流量 ${flowLabels[log.flow] ?? '中'}',
                    if (log.symptoms.isNotEmpty)
                      log.symptoms
                          .split(',')
                          .map((s) => periodSymptoms[s] ?? s)
                          .join('、'),
                  ].join(' · '),
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline_rounded,
                size: 18, color: theme.colorScheme.error.withValues(alpha: 0.8)),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
