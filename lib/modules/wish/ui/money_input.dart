import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/wish_stats.dart';

/// 输入金额（单位：元），返回「分」；取消返回 null。
///
/// 用底部弹层而不是 AlertDialog：
/// 安卓上带输入框的 AlertDialog 在部分设备会被键盘顶到看不见，
/// 连「确定」都摸不到（密码弹层踩过同样的坑）。
Future<int?> showMoneyInput(
  BuildContext context, {
  required Color accent,
  int? initialCents,
  String title = '攒一笔',
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardTheme.color,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _MoneySheet(
      accent: accent,
      initialCents: initialCents,
      title: title,
    ),
  );
}

class _MoneySheet extends StatefulWidget {
  const _MoneySheet({
    required this.accent,
    required this.title,
    this.initialCents,
  });

  final Color accent;
  final String title;
  final int? initialCents;

  @override
  State<_MoneySheet> createState() => _MoneySheetState();
}

class _MoneySheetState extends State<_MoneySheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialCents == null
        ? ''
        : (widget.initialCents! / 100)
            .toStringAsFixed(widget.initialCents! % 100 == 0 ? 0 : 2),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final cents = parseYuanToCents(_controller.text);
    if (cents == null || cents <= 0) {
      setState(() => _error = '请输入大于 0 的金额');
      return;
    }
    Navigator.of(context).pop(cents);
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.muted(context);

    return Padding(
      // 键盘弹起时整个弹层往上抬，按钮始终可见
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                prefixText: '¥ ',
                prefixStyle: TextStyle(fontSize: 22, color: muted),
                hintText: '0',
                hintStyle: TextStyle(fontSize: 28, color: muted),
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                for (final quick in const [10000, 50000, 100000])
                  ActionChip(
                    label: Text(formatYuan(quick)),
                    onPressed: () => setState(() {
                      _controller.text = (quick / 100).toStringAsFixed(0);
                      _error = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.accent,
                    ),
                    child: const Text('确定'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
