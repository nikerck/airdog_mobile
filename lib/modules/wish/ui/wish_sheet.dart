/// 新建/编辑愿望的弹层：标题、价格、优先级、链接、备注。
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/db/app_database.dart';
import '../domain/wish_stats.dart';

const wishPriorities = <int, String>{1: '一般', 2: '想要', 3: '很想要'};

class WishDraft {
  const WishDraft({
    required this.title,
    required this.price,
    required this.priority,
    required this.link,
    required this.note,
  });

  final String title;
  final int price;
  final int priority;
  final String link;
  final String note;
}

/// 新建 / 编辑愿望。传 wish 就是编辑。
Future<WishDraft?> showWishSheet(
  BuildContext context, {
  required Color accent,
  Wish? wish,
}) {
  return showModalBottomSheet<WishDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardTheme.color,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => _WishSheet(accent: accent, wish: wish),
  );
}

class _WishSheet extends StatefulWidget {
  const _WishSheet({required this.accent, this.wish});

  final Color accent;
  final Wish? wish;

  @override
  State<_WishSheet> createState() => _WishSheetState();
}

class _WishSheetState extends State<_WishSheet> {
  late final _title = TextEditingController(text: widget.wish?.title ?? '');
  late final _price = TextEditingController(
    text: widget.wish == null
        ? ''
        : (widget.wish!.price / 100).toStringAsFixed(
            widget.wish!.price % 100 == 0 ? 0 : 2),
  );
  late final _link = TextEditingController(text: widget.wish?.link ?? '');
  late final _note = TextEditingController(text: widget.wish?.note ?? '');
  late int _priority = widget.wish?.priority ?? 2;

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _link.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    final cents = parseYuanToCents(_price.text);
    if (title.isEmpty || cents == null) return;
    Navigator.of(context).pop(
      WishDraft(
        title: title,
        price: cents,
        priority: _priority,
        link: _link.text.trim(),
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.muted(context);
    final isEdit = widget.wish != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  isEdit ? '编辑愿望' : '记一个愿望',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _title,
              autofocus: !isEdit,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(hintText: '想要什么？'),
            ),
            const SizedBox(height: 18),
            _label('价格', muted),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                prefixText: '¥ ',
                prefixStyle: TextStyle(fontSize: 18, color: muted),
                hintText: '0',
              ),
            ),
            const SizedBox(height: 18),
            _label('有多想要', muted),
            const SizedBox(height: 2),
            Row(
              children: [
                for (final entry in wishPriorities.entries) ...[
                  _choice(
                    label: entry.value,
                    selected: _priority == entry.key,
                    onTap: () => setState(() => _priority = entry.key),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 18),
            _label('链接（可选）', muted),
            TextField(
              controller: _link,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'https://',
                hintStyle: TextStyle(fontSize: 13, color: muted),
              ),
            ),
            const SizedBox(height: 14),
            _label('备注（可选）', muted),
            TextField(
              controller: _note,
              minLines: 1,
              maxLines: 3,
              style: const TextStyle(fontSize: 14, height: 1.6),
              decoration: InputDecoration(
                hintText: '尺寸、颜色、买给谁…',
                hintStyle: TextStyle(fontSize: 13, color: muted),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(backgroundColor: widget.accent),
              child: Text(isEdit ? '保存' : '添加'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
        ),
      );

  Widget _choice({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? widget.accent.withValues(alpha: 0.14) : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? widget.accent.withValues(alpha: 0.55)
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? widget.accent : AppTheme.muted(context),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
