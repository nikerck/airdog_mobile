/// 新建待办弹层：标题、正文、图片（最多 9 张）、可选到期时间。
///
/// 到期的四个快捷选项（今天/明天/选日期时间/不设时间）都在这里，
/// 真正的日期选择在 due_picker.dart。
library;
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/media/todo_image_store.dart';

class NewTodoResult {
  const NewTodoResult({
    required this.title,
    required this.content,
    required this.images,
    required this.dueAt,
  });

  final String title;
  final String content;
  final List<String> images;
  final DateTime? dueAt;
}

/// 新建待办：标题 + 正文 + 图片 + 具体时间。
Future<NewTodoResult?> showAddTodoSheet(BuildContext context) {
  return showModalBottomSheet<NewTodoResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardTheme.color,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => const _AddTodoSheet(),
  );
}

class _AddTodoSheet extends StatefulWidget {
  const _AddTodoSheet();

  @override
  State<_AddTodoSheet> createState() => _AddTodoSheetState();
}

class _AddTodoSheetState extends State<_AddTodoSheet> {
  final _title = TextEditingController();
  final _titleFocus = FocusNode();
  final _content = TextEditingController();
  final _store = const TodoImageStore();

  final List<String> _images = [];
  DateTime? _due;
  bool _picking = false;

  static const _maxImages = 9;

  @override
  void initState() {
    super.initState();
    _due = _todayAt(20);
  }

  @override
  void dispose() {
    _title.dispose();
    _titleFocus.dispose();
    _content.dispose();
    super.dispose();
  }

  DateTime _todayAt(int hour) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour);
  }

  bool get _isToday {
    final due = _due;
    if (due == null) return false;
    final now = DateTime.now();
    return due.year == now.year && due.month == now.month && due.day == now.day;
  }

  bool get _isTomorrow {
    final due = _due;
    if (due == null) return false;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return due.year == tomorrow.year &&
        due.month == tomorrow.month &&
        due.day == tomorrow.day;
  }

  String _fullLabel() {
    final due = _due;
    if (due == null) return '不设时间';
    String two(int v) => v.toString().padLeft(2, '0');
    final hm = '${two(due.hour)}:${two(due.minute)}';
    if (_isToday) return '今天 $hm';
    if (_isTomorrow) return '明天 $hm';
    return '${due.month}月${due.day}日 $hm';
  }

  /// 先选日期，再选时刻；任一步取消就保持原样。
  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final base = _due ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '下一步',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      helpText: '选择时间',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (time == null) return;

    setState(() {
      _due = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickImages() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final paths =
          await _store.pickAndSave(limit: _maxImages - _images.length);
      if (!mounted) return;
      setState(() => _images.addAll(paths));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('选图失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _removeImage(String path) async {
    setState(() => _images.remove(path));
    await _store.delete([path]);
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      _titleFocus.requestFocus();
      return;
    }
    Navigator.of(context).pop(
      NewTodoResult(
        title: title,
        content: _content.text.trim(),
        images: List.unmodifiable(_images),
        dueAt: _due,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppTheme.muted(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '新建待办',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 2),

            // 标题
            TextField(
              controller: _title,
              focusNode: _titleFocus,
              autofocus: true,
              textInputAction: TextInputAction.next,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                hintText: '标题',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: theme.dividerColor, height: 1),
            const SizedBox(height: 8),

            // 正文
            TextField(
              controller: _content,
              minLines: 2,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(fontSize: 14, height: 1.6),
              decoration: InputDecoration(
                hintText: '写点什么…（可多行）',
                hintStyle: TextStyle(fontSize: 14, color: muted),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),

            // 图片
            if (_images.isNotEmpty || _images.length < _maxImages) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 76,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final path in _images)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _Thumb(
                          path: path,
                          onRemove: () => _removeImage(path),
                        ),
                      ),
                    if (_images.length < _maxImages)
                      _AddPhoto(
                        picking: _picking,
                        onTap: _pickImages,
                        counter: '${_images.length}/$_maxImages',
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // 时间
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 15, color: muted),
                const SizedBox(width: 6),
                Text('提醒时间', style: TextStyle(fontSize: 12, color: muted)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _dueChip('今天', _isToday, () => setState(() => _due = _todayAt(20))),
                _dueChip('明天', _isTomorrow, () {
                  setState(() =>
                      _due = DateTime.now().add(const Duration(days: 1)).copyWith(
                            hour: 20,
                            minute: 0,
                            second: 0,
                            millisecond: 0,
                            microsecond: 0,
                          ));
                }),
                _dueChip('选日期时间', _due != null && !_isToday && !_isTomorrow,
                    _pickDateTime),
                _dueChip('不设时间', _due == null, () => setState(() => _due = null)),
              ],
            ),

            // 具体时间 + 修改
            const SizedBox(height: 10),
            InkWell(
              onTap: _due == null ? null : _pickDateTime,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                child: Row(
                  children: [
                    Icon(
                      _due == null
                          ? Icons.notifications_off_outlined
                          : Icons.event_available_rounded,
                      size: 16,
                      color: _due == null
                          ? muted
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _fullLabel(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _due == null
                            ? muted
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (_due != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '修改',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: const Text('添加'),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '保存后会同步到你的服务器；离线模式下只存本地',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dueChip(String label, bool selected, VoidCallback onTap) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.14),
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected ? theme.colorScheme.primary : AppTheme.muted(context),
        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
      ),
      side: BorderSide(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.5)
            : theme.dividerColor,
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.path, required this.onRemove});

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
            width: 76,
            height: 76,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 76,
              height: 76,
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

class _AddPhoto extends StatelessWidget {
  const _AddPhoto({
    required this.picking,
    required this.onTap,
    required this.counter,
  });

  final bool picking;
  final VoidCallback onTap;
  final String counter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppTheme.muted(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 76,
        height: 76,
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
