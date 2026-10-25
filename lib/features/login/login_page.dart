import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/api_client.dart';
import '../../app/theme/app_theme.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  // 桌面版直连本机；Android 模拟器用 10.0.2.2 指向宿主机。
  final _server = TextEditingController(
    text: Platform.isWindows || Platform.isLinux || Platform.isMacOS
        ? '127.0.0.1:8080'
        : '10.0.2.2:8080',
  );
  final _username = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _server.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_busy) return;

    if (_server.text.trim().isEmpty) {
      setState(() => _error = '请填写服务器地址');
      return;
    }
    if (_username.text.trim().isEmpty) {
      setState(() => _error = '请填写账号');
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = '请填写密码');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final error = await ref.read(authProvider.notifier).signIn(
          server: _server.text,
          username: _username.text.trim(),
          password: _password.text,
        );

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppTheme.muted(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.home_rounded,
                    color: Colors.white, size: 30),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '小窝',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '登录到你的服务器，数据由你自己保管',
              style: TextStyle(fontSize: 13, color: muted),
            ),
            const SizedBox(height: 32),

            _label('服务器地址', muted),
            TextField(
              controller: _server,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                hintText: '例如 192.168.31.27:8080',
                prefixIcon: Icon(Icons.dns_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS))
                  _quickFill('模拟器 10.0.2.2:8080', '10.0.2.2:8080', muted),
                _quickFill(
                  Platform.isWindows ? '本机 127.0.0.1:8080' : 'USB 真机 127.0.0.1:8080',
                  '127.0.0.1:8080',
                  muted,
                ),
              ],
            ),
            const SizedBox(height: 16),

            _label('账号', muted),
            TextField(
              controller: _username,
              autocorrect: false,
              decoration: const InputDecoration(
                hintText: '用户名',
                prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 16),

            _label('密码', muted),
            TextField(
              controller: _password,
              obscureText: _obscure,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: '密码',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 18, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('登录'),
            ),

            if (ApiClient.useMock) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.softSurface(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.science_outlined, size: 18, color: muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mock 模式：不会真的联网。任意账号 + 密码 123456 即可登录。',
                        style: TextStyle(fontSize: 12, height: 1.6, color: muted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _quickFill(String label, String value, Color color) {
    return GestureDetector(
      onTap: () => setState(() {
        _server.text = value;
        _error = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10.5, color: color),
        ),
      ),
    );
  }

  Widget _label(String text, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
        ),
      );
}
