import 'package:flutter/material.dart';

/// 删除前的二次确认，列表左滑和详情页共用。
Future<bool> confirmDeleteTodo(BuildContext context, String title) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        title: const Text('删除这条待办？'),
        content: Text(
          '「$title」将被删除，不能恢复。',
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
