/// 待办列表页。
///
/// 结构：顶部计数 + 三个筛选 chip + 按「今天 / 其他」分组的卡片列表。
/// 卡片点击进详情；左滑删除（带二次确认，见 confirm_delete.dart）。
library;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/api/api_providers.dart';
import '../../../shared/widgets/duo_avatar.dart';
import '../../../core/api/spaces_api.dart';
import '../../../core/db/app_database.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../domain/todo_filter.dart';
import '../todo_providers.dart';
import 'add_todo_sheet.dart';
import 'confirm_delete.dart';
import 'todo_detail_sheet.dart';
import '../../../shared/widgets/run_guarded.dart';

class TodoPage extends ConsumerStatefulWidget {
  const TodoPage({super.key});

  @override
  ConsumerState<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends ConsumerState<TodoPage> {
  TodoFilter _filter = TodoFilter.all;

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.muted(context);
    final now = DateTime.now();
    final async = ref.watch(todosProvider);
    final all = async.valueOrNull ?? const <TodoItem>[];

    // 顶部那句「N 项未完成」：不受筛选影响，永远统计全部
    final pending = all.where((t) => t.doneAt == null).length;

    // 先按 chip 过滤，再按「今天 / 其他」分组。两步都是纯函数，
    // 定义在 domain/todo_filter.dart，有单测覆盖。
    final visible = applyFilter(all, _filter, now);
    final groups = groupByDay(visible, now);

    // 右上角的头像组：谁跟我共享（原来写死成 Z/M，换账号就不对了）
    final me = ref.watch(meMemberProvider);
    final partners = ref.watch(partnersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('待办'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                DuoAvatar(
                  first: (me?.initial.isNotEmpty ?? false) ? me!.initial : '我',
                  second: partners.isEmpty
                      ? null
                      : (partners.first.initial.isNotEmpty
                          ? partners.first.initial
                          : partners.first.name.substring(0, 1)),
                  extra: partners.length > 1 ? partners.length - 1 : 0,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddSheet,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Text(
                '$pending 项未完成',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
              child: Row(
                children: [
                  _chip('全部', TodoFilter.all),
                  const SizedBox(width: 8),
                  _chip('今天', TodoFilter.today),
                  const SizedBox(width: 8),
                  _chip('已完成', TodoFilter.done),
                ],
              ),
            ),
            Expanded(
              child: async.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : visible.isEmpty
                      ? _emptyState(muted)
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
                          children: [
                            for (final entry in groups.entries) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: 10, bottom: 8),
                                child: Text(
                                  entry.key,
                                  style: TextStyle(fontSize: 12, color: muted),
                                ),
                              ),
                              for (var i = 0; i < entry.value.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: FadeSlideIn(
                                    delay: Duration(milliseconds: i * 45),
                                    offset: 12,
                                    child: _TodoTile(
                                      item: entry.value[i],
                                      now: now,
                                      members: ref.watch(membersByIdProvider),
                                      onTap: () =>
                                          _openDetail(entry.value[i].id),
                                      onDelete: () => runGuarded(
                                        context,
                                        () => ref
                                            .read(todoRepositoryProvider)
                                            .remove(entry.value[i]),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, TodoFilter filter) {
    final theme = Theme.of(context);
    final selected = _filter == filter;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() => _filter = filter),
      selectedColor: theme.colorScheme.primary,
      backgroundColor: theme.cardTheme.color,
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected ? Colors.white : AppTheme.muted(context),
        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
      ),
      side: BorderSide(
        color: selected ? theme.colorScheme.primary : theme.dividerColor,
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _emptyState(Color muted) {
    final text = switch (_filter) {
      TodoFilter.all => '还没有待办',
      TodoFilter.today => '今天没有待办',
      TodoFilter.done => '还没有完成的事',
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 44, color: muted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(fontSize: 13, color: muted)),
        ],
      ),
    );
  }

  Future<void> _openAddSheet() async {
    final result = await showAddTodoSheet(context);
    if (result == null || !mounted) return;
    await runGuarded(
      context,
      () => ref.read(todoRepositoryProvider).add(
            title: result.title,
            content: result.content,
            images: result.images,
            dueAt: result.dueAt,
          ),
    );
  }

  Future<void> _openDetail(String todoId) =>
      showTodoDetailSheet(context, todoId: todoId);
}

class _TodoTile extends StatelessWidget {
  const _TodoTile({
    required this.item,
    required this.now,
    required this.members,
    required this.onTap,
    required this.onDelete,
  });

  final TodoItem item;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  final Map<String, SpaceMember> members;

  String _name(String? id) => memberName(members, id);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppTheme.muted(context);
    final done = item.doneAt != null;
    final due = item.dueAt == null ? null : formatDue(item.dueAt!, now);
    final lead = done ? '${_name(item.doneBy)} 已完成 · ' : '';
    final meta = '$lead${_name(item.createdBy)}${due == null ? '' : ' · $due'}';
    final images = parseImages(item.images);
    final hasExtra = item.content.isNotEmpty || images.isNotEmpty;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirmDeleteTodo(context, item.title),
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline_rounded,
            size: 20, color: theme.colorScheme.error),
      ),
      child: Material(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (done)
                            Padding(
                              padding: const EdgeInsets.only(right: 6, top: 2),
                              child: Icon(Icons.check_circle_rounded,
                                  size: 16, color: theme.colorScheme.primary),
                            ),
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: done
                                    ? muted.withValues(alpha: 0.75)
                                    : theme.colorScheme.onSurface,
                                decoration: done
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                decorationColor: muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item.content.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: done ? muted.withValues(alpha: 0.6) : muted,
                          ),
                        ),
                      ],
                      if (images.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _ThumbStrip(paths: images),
                      ],
                      const SizedBox(height: 4),
                      Text(meta, style: TextStyle(fontSize: 11, color: muted)),
                    ],
                  ),
                ),
                if (hasExtra)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 2),
                    child: Icon(Icons.chevron_right_rounded,
                        size: 18, color: muted.withValues(alpha: 0.5)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 列表里的缩略图：最多显示 3 张，多的用 +N 收起。
class _ThumbStrip extends StatelessWidget {
  const _ThumbStrip({required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    const size = 52.0;
    final shown = paths.take(3).toList();
    final rest = paths.length - shown.length;

    return Row(
      children: [
        for (final path in shown)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(path),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: size,
                  height: size,
                  color: AppTheme.softSurface(context),
                  child: Icon(Icons.broken_image_outlined,
                      size: 16, color: AppTheme.muted(context)),
                ),
              ),
            ),
          ),
        if (rest > 0)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppTheme.softSurface(context),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              '+$rest',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.muted(context),
              ),
            ),
          ),
      ],
    );
  }
}
