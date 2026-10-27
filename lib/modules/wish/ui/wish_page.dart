/// 愿望单主页：总览卡 + 愿望卡片列表 + 新建按钮。
///
/// 排序：优先级高的在前，同优先级按创建时间。
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/db/app_database.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/run_guarded.dart';
import '../domain/wish_stats.dart';
import '../wish_providers.dart';
import 'wish_detail_sheet.dart';
import 'wish_sheet.dart';

class WishPage extends ConsumerWidget {
  const WishPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = AppTheme.muted(context);
    final accent = theme.brightness == Brightness.dark
        ? const Color(0xFFF0B23E)
        : const Color(0xFF9A6A12);

    final wishes = ref.watch(wishesProvider).valueOrNull ?? const <Wish>[];
    final byWish = ref.watch(savingsByWishProvider);

    // 顶部总览：把所有愿望的价格和攒钱各自求和。
    // 百分比按「总已攒 / 总目标」算，不是各愿望百分比的平�均。
    var target = 0;
    var saved = 0;
    for (final w in wishes) {
      target += w.price;
      for (final s in byWish[w.id] ?? const <WishSaving>[]) {
        saved += s.amount;
      }
    }
    final percent = target <= 0
        ? 0
        : ((saved / target) * 100).round().clamp(0, 100).toInt();

    return Scaffold(
      appBar: AppBar(
        title: const Text('愿望单'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: accent.withValues(alpha: 0.18),
                  child: Text('Z', style: TextStyle(fontSize: 10, color: accent)),
                ),
                const SizedBox(width: 4),
                CircleAvatar(
                  radius: 11,
                  backgroundColor: muted.withValues(alpha: 0.18),
                  child: Text('M', style: TextStyle(fontSize: 10, color: muted)),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _add(context, ref, accent),
        backgroundColor: accent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 100),
          children: [
            FadeSlideIn(
              child: _SummaryCard(
                count: wishes.length,
                target: target,
                saved: saved,
                percent: percent,
                accent: accent,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text(
                  '愿望',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Text('${wishes.length} 个', style: TextStyle(fontSize: 12, color: muted)),
              ],
            ),
            const SizedBox(height: 10),
            if (wishes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Column(
                  children: [
                    Icon(Icons.card_giftcard_rounded, size: 40, color: muted),
                    const SizedBox(height: 12),
                    Text(
                      '还没有愿望，点右下角记一个',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              )
            else
              for (var i = 0; i < wishes.length; i++)
                FadeSlideIn(
                  delay: Duration(milliseconds: 40 * i.clamp(0, 6)),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _WishCard(
                      wish: wishes[i],
                      savings: byWish[wishes[i].id] ?? const <WishSaving>[],
                      accent: accent,
                      onTap: () => showWishDetail(
                        context,
                        wishId: wishes[i].id,
                        accent: accent,
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, Color accent) async {
    final draft = await showWishSheet(context, accent: accent);
    if (draft == null || !context.mounted) return;
    await runGuarded(
      context,
      () => ref.read(wishRepositoryProvider).add(
            title: draft.title,
            price: draft.price,
            priority: draft.priority,
            link: draft.link,
            note: draft.note,
          ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.count,
    required this.target,
    required this.saved,
    required this.percent,
    required this.accent,
  });

  final int count;
  final int target;
  final int saved;
  final int percent;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppTheme.muted(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: theme.brightness == Brightness.dark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$count 个愿望', style: TextStyle(fontSize: 12, color: accent)),
              const Spacer(),
              Text('目标 ${formatYuan(target)}', style: TextStyle(fontSize: 12, color: muted)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatYuan(saved),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('已攒 · $percent%', style: TextStyle(fontSize: 11, color: muted)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: percent / 100),
              duration: const Duration(milliseconds: 620),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: accent.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WishCard extends StatelessWidget {
  const _WishCard({
    required this.wish,
    required this.savings,
    required this.accent,
    required this.onTap,
  });

  final Wish wish;
  final List<WishSaving> savings;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppTheme.muted(context);
    final stats = statsFor(wish, savings);

    return Material(
      color: theme.cardTheme.color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      stats.done ? Icons.check_rounded : Icons.card_giftcard_rounded,
                      size: 16,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      wish.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    formatYuan(wish.price),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: stats.progress),
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 5,
                    backgroundColor: accent.withValues(alpha: 0.14),
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '已攒 ${formatYuan(stats.saved)}',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                  const Spacer(),
                  Text(
                    stats.done ? '达成 ✓' : '还差 ${formatYuan(stats.remaining)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: stats.done ? accent : muted,
                      fontWeight: stats.done ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
