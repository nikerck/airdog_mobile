import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/wish_stats.dart';

/// 输入金额（元），返回分。
Future<int?> showMoneyInput(
  BuildContext context, {
  required Color accent,
  int? initialCents,
  String title = '攒一笔',
}) {
  return showDialog<int>(
    context: context,
    builder: (context) => _MoneyDialog(
      accent: accent,
      initialCents: initialCents,
      title: title,
    ),
  );
}

class _MoneyDialog extends StatefulWidget {
  const _MoneyDialog({
    required this.accent,
    required this.title,
    this.initialCents,
  });

  final Color accent;
  final String title;
  final int? initialCents;

  @override
  State<_MoneyDialog> createState() => _MoneyDialogState();
}

class _MoneyDialogState extends State<_MoneyDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialCents == null
        ? ''
        : (widget.initialCents! / 100).toStringAsFixed(
            widget.initialCents! % 100 == 0 ? 0 : 2),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final cents = parseYuanToCents(_controller.text);
    if (cents == null || cents <= 0) return;
    Navigator.of(context).pop(cents);
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.muted(context);

    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              prefixText: '¥ ',
              prefixStyle: TextStyle(fontSize: 20, color: muted),
              hintText: '0',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final quick in const [10000, 50000, 100000])
                ActionChip(
                  label: Text(formatYuan(quick)),
                  onPressed: () => setState(() {
                    _controller.text = (quick / 100).toStringAsFixed(0);
                  }),
                ),
            ],
          ),
        ],
      ),
      // 用 Row 包一层：AlertDialog 的 actions 是 OverflowBar，窄窗口下会把两个按钮竖着排
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            const SizedBox(width: 6),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(backgroundColor: widget.accent),
              child: const Text('确定'),
            ),
          ],
        ),
      ],
    );
  }
}
