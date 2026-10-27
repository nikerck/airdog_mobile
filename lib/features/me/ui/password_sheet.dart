/// 修改密码弹层：当前密码 / 新密码 / 再确认。
///
/// 本地先校验（6 位、两次一致、不能和旧密码相同），再交给服务端；
/// 当前密码错时服务端返回 401，客户端只提示、不掉线。
library;
import 'package:flutter/material.dart';

/// 改密码弹层。返回 (当前密码, 新密码)；取消返回 null。
///
/// 用 bottom sheet 而不是 AlertDialog：安卓上带多个输入框的对话框在部分设备
/// 会被键盘顶出可视区，底部弹层更稳，也和项目里其它表单一致。
Future<({String current, String next})?> showChangePasswordSheet(
  BuildContext context,
) {
  return showModalBottomSheet<({String current, String next})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardTheme.color,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => const ChangePasswordSheet(),
  );
}

class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final current = _current.text;
    final next = _next.text;

    if (current.isEmpty) {
      setState(() => _error = '请输入当前密码');
      return;
    }
    if (next.length < 6) {
      setState(() => _error = '新密码至少 6 位');
      return;
    }
    if (next != _confirm.text) {
      setState(() => _error = '两次输入的新密码不一致');
      return;
    }
    if (next == current) {
      setState(() => _error = '新密码不能和当前密码一样');
      return;
    }
    Navigator.of(context).pop((current: current, next: next));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final errorColor = theme.colorScheme.error;

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
                  '修改密码',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            _label('当前密码', muted),
            _field(_current, '登录用的密码'),
            const SizedBox(height: 14),
            _label('新密码', muted),
            _field(_next, '至少 6 位'),
            const SizedBox(height: 14),
            _label('再输一次', muted),
            _field(_confirm, '两次要一致', onSubmitted: _submit),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 14, color: errorColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(fontSize: 12, color: errorColor),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: const Text('保存')),
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

  Widget _field(
    TextEditingController controller,
    String hint, {
    VoidCallback? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: _obscure,
      style: const TextStyle(fontSize: 14),
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18,
          ),
        ),
      ),
    );
  }
}
