import '../../../core/db/app_database.dart';

/// 按月分组，月份从新到旧；组内按拍摄时间从新到旧。
class PhotoMonth {
  const PhotoMonth({required this.label, required this.photos});

  final String label;
  final List<Photo> photos;
}

String monthLabel(DateTime d) => '${d.year}年${d.month}月';

/// 给「本月 / 上月」加个前缀，跨年的情况也能对上。
String monthLabelRelative(DateTime d, DateTime now) {
  final base = monthLabel(d);
  final sameYear = d.year == now.year;
  if (sameYear && d.month == now.month) return '本月 · $base';
  final prev = DateTime(now.year, now.month - 1);
  if (d.year == prev.year && d.month == prev.month) return '上月 · $base';
  return base;
}

List<PhotoMonth> groupByMonth(List<Photo> photos, {DateTime? now}) {
  final sorted = [...photos]..sort((a, b) => b.takenAt.compareTo(a.takenAt));
  final map = <String, List<Photo>>{};
  final order = <String>[];

  for (final photo in sorted) {
    final key = '${photo.takenAt.year}-${photo.takenAt.month}';
    if (!map.containsKey(key)) {
      map[key] = [];
      order.add(key);
    }
    map[key]!.add(photo);
  }

  final clock = now ?? DateTime.now();
  return [
    for (final key in order)
      PhotoMonth(
        label: monthLabelRelative(map[key]!.first.takenAt, clock),
        photos: map[key]!,
      ),
  ];
}

/// "1.2 MB" / "860 KB"
String formatBytes(int bytes) {
  if (bytes <= 0) return '—';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

/// "1080 × 1440"，读不出尺寸时返回空串
String formatSize(int width, int height) =>
    width <= 0 || height <= 0 ? '' : '$width × $height';
