/// 记录经期的弹层：开始日期、是否结束、流量、症状、备注。
library;
import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../data/period_repository.dart';
import '../domain/period_calculator.dart';

const periodSymptoms = <String, String>{
  'cramp': '痛经',
  'headache': '头痛',
  'fatigue': '乏力',
  'mood': '情绪',
  'backache': '腰酸',
  'insomnia': '失眠',
};

const flowLabels = <int, String>{1: '少', 2: '中', 3: '多'};

/// 记录一次经期：开始日期、是否已结束、流量、症状、备注。
Future<bool?> showRecordPeriodSheet(
  BuildContext context, {
  required PeriodRepository repo,
  DateTime? initialStart,
  bool ongoing = true,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardTheme.color,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => _RecordSheet(
      repo: repo,
      initialStart: initialStart,
      initialOngoing: ongoing,
    ),
  );
}

class _RecordSheet extends StatefulWidget {
  const _RecordSheet({
    required this.repo,
    this.initialStart,
    this.initialOngoing = true,
  });

  final PeriodRepository repo;
  final DateTime? initialStart;
  final bool initialOngoing;

  @override
  State<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<_RecordSheet> {
  late DateTime _start = dayOnly(widget.initialStart ?? DateTime.now());
  late bool _ongoing = widget.initialOngoing;
  DateTime? _end;
  int _flow = 2;
  final Set<String> _symptoms = {'cramp'};
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      helpText: '选择开始日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null) {
      setState(() {
        _start = dayOnly(picked);
        if (_end != null && _end!.isBefore(_start)) _end = null;
      });
    }
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end ?? _start,
      firstDate: _start,
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: '选择结束日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null) setState(() => _end = dayOnly(picked));
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await widget.repo.add(
      startedOn: _start,
      endedOn: _ongoing ? null : (_end ?? _start),
      flow: _flow,
      symptoms: _symptoms.toList(),
      note: _note.text.trim(),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppTheme.muted(context);
    final accent = theme.brightness == Brightness.dark
        ? const Color(0xFFF472B6)
        : const Color(0xFFB3325F);

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
                const Text(
                  '记录经期',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),

            _label('开始日期', muted),
            _pickerRow(
              theme: theme,
              icon: Icons.event_rounded,
              text: _dateText(_start),
              onTap: _pickStart,
            ),

            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.hourglass_bottom_rounded, size: 16, color: muted),
                const SizedBox(width: 8),
                Text('还在经期中', style: TextStyle(fontSize: 13, color: muted)),
                const Spacer(),
                Switch(
                  value: _ongoing,
                  activeTrackColor: accent,
                  onChanged: (v) => setState(() {
                    _ongoing = v;
                    _end = v ? null : (_end ?? dayOnly(DateTime.now()));
                  }),
                ),
              ],
            ),

            if (!_ongoing) ...[
              const SizedBox(height: 6),
              _label('结束日期', muted),
              _pickerRow(
                theme: theme,
                icon: Icons.event_available_rounded,
                text: _dateText(_end ?? _start),
                onTap: _pickEnd,
              ),
            ],

            const SizedBox(height: 16),
            _label('流量', muted),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final entry in flowLabels.entries) ...[
                  _choice(
                    label: entry.value,
                    selected: _flow == entry.key,
                    accent: accent,
                    onTap: () => setState(() => _flow = entry.key),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),

            const SizedBox(height: 16),
            _label('症状（可多选）', muted),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in periodSymptoms.entries)
                  _choice(
                    label: entry.value,
                    selected: _symptoms.contains(entry.key),
                    accent: accent,
                    onTap: () => setState(() {
                      if (_symptoms.contains(entry.key)) {
                        _symptoms.remove(entry.key);
                      } else {
                        _symptoms.add(entry.key);
                      }
                    }),
                  ),
              ],
            ),

            const SizedBox(height: 16),
            _label('备注', muted),
            const SizedBox(height: 6),
            TextField(
              controller: _note,
              minLines: 1,
              maxLines: 3,
              style: const TextStyle(fontSize: 14, height: 1.6),
              decoration: InputDecoration(
                hintText: '想记的都可以写在这里',
                hintStyle: TextStyle(fontSize: 13, color: muted),
              ),
            ),

            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: accent),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  String _dateText(DateTime d) => '${d.year}年${d.month}月${d.day}日';

  Widget _label(String text, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
        ),
      );

  Widget _pickerRow({
    required ThemeData theme,
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: AppTheme.muted(context)),
            const SizedBox(width: 10),
            Text(text, style: const TextStyle(fontSize: 14)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: AppTheme.muted(context)),
          ],
        ),
      ),
    );
  }

  Widget _choice({
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.14) : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.55) : Theme.of(context).dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? accent : AppTheme.muted(context),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
