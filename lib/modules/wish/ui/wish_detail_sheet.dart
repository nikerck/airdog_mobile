/// 愿望详情：进度、按人拆分的攒钱、攒钱记录、编辑/删除。
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/db/app_database.dart';
import '../../../shared/widgets/run_guarded.dart';
import '../domain/wish_stats.dart';
import '../wish_providers.dart';
import 'money_input.dart';
import 'wish_sheet.dart';

/// 详情用 id 打开，内部的流会跟着数据变化刷新。
Future<void> showWishDetail(
  BuildContext context, {
  required String wishId,
  required Color accent,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardTheme.color,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => _WishDetail(wishId: wishId, accent: accent),
  );
}

class _WishDetail extends ConsumerWidget {
  const _WishDetail({required this.wishId, required this.accent});

  final String wishId;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = AppTheme.muted(context);
    final wishes = ref.watch(wishesProvider).valueOrNull ?? const <Wish>[];
    final wish = wishes.where((w) => w.id == wishId).firstOrNull;
    if (wish == null) {
      return const SizedBox(height: 200, child: Center(child: Text('这个愿望不见了')));
    }

    final savings = ref.watch(savingsByWishProvider)[wishId] ?? const <WishSaving>[];
    final stats = statsFor(wish, savings);
    final meId = ref.watch(currentUserIdProvider);
    final repo = ref.read(wishRepositoryProvider);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    wish.title,
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                  ),
                ),
                _priorityPill(wish.priority),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatYuan(wish.price),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    stats.done ? '已达成' : '攒了 ${stats.percent}%',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _ProgressBar(value: stats.progress, accent: accent, height: 8),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '已攒 ${formatYuan(stats.saved)}',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                const Spacer(),
                Text(
                  stats.done ? '够了' : '还差 ${formatYuan(stats.remaining)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: stats.done ? accent : muted,
                    fontWeight: stats.done ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),

            if (stats.byMember.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final entry in stats.byMember.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _memberChip(entry.key, entry.value, muted, meId),
                    ),
                ],
              ),
            ],

            if (wish.note.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                wish.note,
                style: TextStyle(fontSize: 13, height: 1.7, color: muted),
              ),
            ],
            if (wish.link.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                wish.link,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: accent),
              ),
            ],

            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      final amount = await showMoneyInput(
                        context,
                        accent: accent,
                        title: '攒一笔 · ${wish.title}',
                      );
                      if (amount == null || !context.mounted) return;
                      await runGuarded(
                        context,
                        () => repo.addSaving(wish, amount: amount),
                        successMessage: '已攒 ${formatYuan(amount)}',
                      );
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('攒一笔'),
                    style: FilledButton.styleFrom(backgroundColor: accent),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () async {
                    final draft = await showWishSheet(context, accent: accent, wish: wish);
                    if (draft == null || !context.mounted) return;
                    await runGuarded(
                      context,
                      () => repo.update(
                        wish,
                        title: draft.title,
                        price: draft.price,
                        priority: draft.priority,
                        link: draft.link,
                        note: draft.note,
                      ),
                    );
                  },
                  child: const Text('编辑'),
                ),
                IconButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('删除这个愿望？'),
                        content: const Text('攒钱记录会一起删除。'),
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
                    if (ok != true || !context.mounted) return;
                    final done = await runGuarded(context, () => repo.remove(wish));
                    if (done && context.mounted) Navigator.of(context).pop();
                  },
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 20, color: theme.colorScheme.error),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Text(
              '攒钱记录',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (savings.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text('还没有记录', style: TextStyle(fontSize: 12, color: muted)),
              )
            else
              for (final s in savings.take(12))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SavingRow(
                    saving: s,
                    meId: meId,
                    accent: accent,
                    onDelete: () async {
                      await runGuarded(
                        context,
                        () => repo.removeSaving(wish, s),
                      );
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _priorityPill(int priority) {
    final label = wishPriorities[priority] ?? '一般';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: accent, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _memberChip(String memberId, int amount, Color muted, String meId) {
    final isMe = memberId == meId;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 9,
          backgroundColor: isMe ? accent.withValues(alpha: 0.18) : muted.withValues(alpha: 0.18),
          child: Text(
            isMe ? 'Z' : 'M',
            style: TextStyle(fontSize: 9, color: isMe ? accent : muted),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          formatYuan(amount),
          style: TextStyle(fontSize: 11, color: muted),
        ),
      ],
    );
  }
}

class _SavingRow extends StatelessWidget {
  const _SavingRow({
    required this.saving,
    required this.meId,
    required this.accent,
    required this.onDelete,
  });

  final WishSaving saving;
  final String meId;
  final Color accent;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppTheme.muted(context);
    final isMe = saving.memberId == meId;
    final d = saving.savedAt;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: isMe ? accent.withValues(alpha: 0.18) : muted.withValues(alpha: 0.18),
            child: Text(
              isMe ? 'Z' : 'M',
              style: TextStyle(fontSize: 10, color: isMe ? accent : muted),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${d.month}月${d.day}日 ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
          Text(
            '+${formatYuan(saving.amount)}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: accent),
          ),
          IconButton(
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, size: 15, color: muted),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.value,
    required this.accent,
    this.height = 6,
  });

  final double value;
  final Color accent;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: accent.withValues(alpha: 0.14),
          valueColor: AlwaysStoppedAnimation(accent),
        ),
      ),
    );
  }
}
