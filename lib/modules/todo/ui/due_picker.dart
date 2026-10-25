import 'package:flutter/material.dart';

/// 日期 + 时间两步选择：先选哪天，再选几点。
/// 任一步取消都返回 null（调用方保持原值）。
Future<DateTime?> showDueDateTimePicker(
  BuildContext context, {
  DateTime? initial,
}) async {
  final now = DateTime.now();
  final base = initial ?? DateTime(now.year, now.month, now.day, 20);

  final date = await showDatePicker(
    context: context,
    initialDate: base,
    firstDate: DateTime(now.year - 1),
    lastDate: DateTime(now.year + 10),
    helpText: '选择日期',
    cancelText: '取消',
    confirmText: '下一步',
  );
  if (date == null || !context.mounted) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(base),
    helpText: '选择时间',
    cancelText: '取消',
    confirmText: '确定',
  );
  if (time == null) return null;

  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// 「今天 20:00」「10月28日 20:00」「不设时间」
String dueFullLabel(DateTime? due) {
  if (due == null) return '不设时间';
  String two(int v) => v.toString().padLeft(2, '0');
  final hm = '${two(due.hour)}:${two(due.minute)}';

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(due.year, due.month, due.day);
  final diff = day.difference(today).inDays;

  if (diff == 0) return '今天 $hm';
  if (diff == 1) return '明天 $hm';
  return '${due.month}月${due.day}日 $hm';
}
