import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/db/app_database.dart';
import '../domain/todo_filter.dart';
import '../todo_providers.dart';
import 'confirm_delete.dart';
import '../../../shared/widgets/run_guarded.dart';

/// 详情：完整正文 + 图片 + 完成 / 编辑 / 删除。
///
/// 传 id 而不是整条数据 —— 编辑保存后，弹层里的内容会跟着流自动刷新。
Future<void> showTodoDetailSheet(
  BuildContext context, {
  required String todoId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardTheme.color,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => _DetailBody(todoId: todoId),
  );
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.todoId});

  final String todoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = AppTheme.muted(context);
    final todos = ref.watch(todosProvider).valueOrNull ?? const <TodoItem>[];

    TodoItem? item;
    for (final t in todos) {
      if (t.id == todoId) {
        item = t;
        break;
      }
    }
    if (item == null) {
      // 被删掉了（比如另一台设备），直接收起
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const SizedBox(height: 120);
    }

    final todo = item;
    final done = todo.doneAt != null;
    final images = parseImages(todo.images);
    final canEdit = canEditTodo(todo);
    final now = DateTime.now();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  todo.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
              if (done)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '已完成',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _metaLine(todo, now),
            style: TextStyle(fontSize: 11.5, color: muted),
          ),
          if (todo.content.isNotEmpty) ...[
            const SizedBox(height: 18),
            SelectableText(
              todo.content,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.75,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
          if (images.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final path in images)
                  GestureDetector(
                    onTap: () => _openViewer(context, path),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(path),
                        width: (MediaQuery.of(context).size.width - 64) / 3,
                        height: (MediaQuery.of(context).size.width - 64) / 3,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 100,
                          height: 100,
                          color: AppTheme.softSurface(context),
                          child: const Icon(Icons.broken_image_outlined, size: 18),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 26),

          // 主操作：完成 / 撤销完成
          FilledButton.icon(
            onPressed: () => runGuarded(
              context,
              () => ref.read(todoRepositoryProvider).toggle(todo),
            ),
            icon: Icon(
              done ? Icons.undo_rounded : Icons.check_rounded,
              size: 18,
            ),
            label: Text(done ? '撤销完成' : '标记为完成'),
          ),

          const SizedBox(height: 10),
          Row(
            children: [
              if (canEdit)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/todo/edit', extra: todo);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('编辑'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '只有 ${_name(todo.createdBy)} 能编辑这条',
                      style: TextStyle(fontSize: 11.5, color: muted),
                    ),
                  ),
                ),
              if (canEdit) const SizedBox(width: 10),
              IconButton(
                onPressed: () async {
                  final ok = await confirmDeleteTodo(context, todo.title);
                  if (!ok || !context.mounted) return;
                  final done = await runGuarded(
                    context,
                    () => ref.read(todoRepositoryProvider).remove(todo),
                  );
                  if (done && context.mounted) Navigator.of(context).pop();
                },
                icon: Icon(Icons.delete_outline_rounded,
                    color: theme.colorScheme.error),
                tooltip: '删除',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _name(String? id) => switch (id) {
      Members.momo => 'Momo',
      Members.me => 'Zyy',
      _ => '我',
    };

String _metaLine(TodoItem item, DateTime now) {
  final parts = <String>['${_name(item.createdBy)} 创建'];
  if (item.dueAt != null) {
    parts.add('${formatDue(item.dueAt!, now)} 到期');
  }
  if (item.doneAt != null) {
    parts.add('${_name(item.doneBy)} 完成');
  }
  return parts.join(' · ');
}

void _openViewer(BuildContext context, String path) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    builder: (context) => GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: InteractiveViewer(
        maxScale: 4,
        child: Center(
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              size: 48,
              color: Colors.white54,
            ),
          ),
        ),
      ),
    ),
  );
}
