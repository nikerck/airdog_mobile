import '../../../core/db/app_database.dart';

/// 金额一律用整数分存储和计算，展示时才转成元。
String formatYuan(int cents, {bool symbol = true}) {
  final negative = cents < 0;
  final abs = cents.abs();
  final yuan = abs ~/ 100;
  final fen = abs % 100;

  final buffer = StringBuffer();
  final digits = yuan.toString();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }

  final text = fen == 0
      ? buffer.toString()
      : '$buffer.${fen.toString().padLeft(2, '0')}';
  return '${negative ? '-' : ''}${symbol ? '¥' : ''}$text';
}

/// 输入框里的「1899」「1,899」「1899.5」都接受，返回分。
int? parseYuanToCents(String input) {
  final cleaned = input.replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty) return null;
  final value = double.tryParse(cleaned);
  if (value == null || value < 0) return null;
  return (value * 100).round();
}

class WishStats {
  const WishStats({
    required this.saved,
    required this.target,
    required this.byMember,
  });

  /// 已攒（分），等于所有攒钱记录求和
  final int saved;

  /// 目标价（分）
  final int target;

  /// 每人攒了多少（分）
  final Map<String, int> byMember;

  int get remaining => (target - saved).clamp(0, 1 << 62);

  /// 0–1，超额攒钱时封顶 1
  double get progress {
    if (target <= 0) return 0;
    return (saved / target).clamp(0, 1).toDouble();
  }

  int get percent => (progress * 100).round();

  bool get done => target > 0 && saved >= target;
}

WishStats statsFor(Wish wish, List<WishSaving> savings) {
  var saved = 0;
  final byMember = <String, int>{};
  for (final s in savings) {
    if (s.wishId != wish.id) continue;
    saved += s.amount;
    byMember[s.memberId] = (byMember[s.memberId] ?? 0) + s.amount;
  }
  return WishStats(saved: saved, target: wish.price, byMember: byMember);
}

/// 首页格子上的副标题：4 件 · 攒 36%
String wishTagline(List<Wish> wishes, Map<String, List<WishSaving>> savings) {
  if (wishes.isEmpty) return '还没有愿望';
  var target = 0;
  var saved = 0;
  for (final w in wishes) {
    target += w.price;
    for (final s in savings[w.id] ?? const <WishSaving>[]) {
      saved += s.amount;
    }
  }
  final percent = target <= 0
      ? 0
      : ((saved / target) * 100).round().clamp(0, 100).toInt();
  return '${wishes.length} 件 · 攒 $percent%';
}
