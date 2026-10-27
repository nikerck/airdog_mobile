/// 编辑待办（整页，不是弹层）。
///
/// 为什么用整页：字段多（标题、正文、图片、时间），弹层放不下，
/// 而且编辑过程中不希望被手势下滑关掉。
library;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/db/app_database.dart';
import '../../../core/media/todo_image_store.dart';
import '../todo_providers.dart';
import '../../../shared/widgets/run_guarded.dart';
import 'due_picker.dart';

/// 编辑待办：标题 / 正文 / 图片 / 时间。
///
/// 只有创建人能进来 —— 入口在详情页，那边已经判过权限，这里再判一次兜底。
class EditTodoPage extends ConsumerStatefulWidget {
  const EditTodoPage({super.key, required this.item});

  final TodoItem item;

  @override
  ConsumerState<EditTodoPage> createState() => _EditTodoPageState();
}

class _EditTodoPageState extends ConsumerState<EditTodoPage> {
  late final TextEditingController _title =
      TextEditingController(text: widget.item.title);
  late final TextEditingController _content =
      TextEditingController(text: widget.item.content);
  final _store = const TodoImageStore();

  late List<String> _images;
  DateTime? _due;
  bool _picking = false;
  bool _saving = false;

  static const _maxImages = 9;

  @override
  void initState() {
    super.initState();
    _images = parseImagesFromRow(widget.item.images);
    _due = widget.item.dueAt;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _addImages() async {
    if (_picking || _images.length >= _maxImages) return;
    setState(() => _picking = true);
    try {
      final paths = await _store.pickAndSave(limit: _maxImages - _images.length);
      if (!mounted) return;
      setState(() => _images.addAll(paths));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _removeImage(String path) async {
    setState(() => _images.remove(path));
    await _store.delete([path]);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);

    final ok = await runGuarded(
      context,
      () => ref.read(todoRepositoryProvider).updateAll(
            widget.item,
            title: title,
            content: _content.text.trim(),
            images: _images,
            dueAt: _due,
            clearDue: _due == null,
          ),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppTheme.muted(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑待办'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          TextField(
            controller: _title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              hintText: '标题',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          Divider(color: theme.dividerColor, height: 20),
          TextField(
            controller: _content,
            minLines: 4,
            maxLines: 12,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(fontSize: 14.5, height: 1.7),
            decoration: InputDecoration(
              hintText: '写点什么…',
              hintStyle: TextStyle(fontSize: 14, color: muted),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),

          const SizedBox(height: 12),
          Text('图片', style: TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final path in _images)
                _EditableThumb(path: path, onRemove: () => _removeImage(path)),
              if (_images.length < _maxImages)
                _AddThumb(
                  picking: _picking,
                  counter: '${_images.length}/$_maxImages',
                  onTap: _addImages,
                ),
            ],
          ),

          const SizedBox(height: 22),
          Text('提醒时间', style: TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final picked =
                  await showDueDateTimePicker(context, initial: _due);
              if (picked != null) setState(() => _due = picked);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  Icon(
                    _due == null ? Icons.notifications_off_outlined : Icons.event_available_rounded,
                    size: 17,
                    color: _due == null ? muted : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    dueFullLabel(_due),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _due == null ? muted : theme.colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (_due != null)
                    GestureDetector(
                      onTap: () => setState(() => _due = null),
                      child: Text(
                        '清除',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded, size: 18, color: muted),
                ],
              ),
            ),
          ),

          const SizedBox(height: 26),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('保存')),
        ],
      ),
    );
  }
}

List<String> parseImagesFromRow(String raw) {
  if (raw.isEmpty) return [];
  return raw
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

class _EditableThumb extends StatelessWidget {
  const _EditableThumb({required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(path),
            width: 84,
            height: 84,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 84,
              height: 84,
              color: AppTheme.softSurface(context),
              child: const Icon(Icons.broken_image_outlined, size: 20),
            ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, size: 13, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddThumb extends StatelessWidget {
  const _AddThumb({
    required this.picking,
    required this.counter,
    required this.onTap,
  });

  final bool picking;
  final String counter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppTheme.muted(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
          color: AppTheme.softSurface(context),
        ),
        child: picking
            ? const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 20, color: muted),
                  const SizedBox(height: 4),
                  Text(counter, style: TextStyle(fontSize: 9.5, color: muted)),
                ],
              ),
      ),
    );
  }
}
