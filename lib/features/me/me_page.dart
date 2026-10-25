import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../core/api/api_providers.dart';
import '../../core/api/spaces_api.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/settings/appearance.dart';
import '../../modules/module.dart';
import '../../modules/registry.dart';

class MePage extends ConsumerStatefulWidget {
  const MePage({super.key});

  @override
  ConsumerState<MePage> createState() => _MePageState();
}

class _MePageState extends ConsumerState<MePage> {
  final Set<String> _disabled = <String>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppTheme.muted(context);
    final session = ref.watch(authProvider);
    final appearance = ref.watch(appearanceProvider);
    final partners = ref
        .watch(membersByIdProvider)
        .values
        .where((m) => !m.isMe)
        .toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            const Text(
              '我的',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),

            // 账号
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF252A35)
                      : const Color(0xFFE3E0E9),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      (session?.userName ?? '我').characters.first,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session?.userName ?? '我',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          session?.offline == true
                              ? '离线模式 · 数据仅在本机'
                              : '已连接 ${session?.baseUrl ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 外观
            _sectionTitle('外观', muted),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF252A35)
                      : const Color(0xFFE3E0E9),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('主题色', style: TextStyle(fontSize: 12, color: muted)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final accent in AccentColor.values)
                        _AccentDot(
                          accent: accent,
                          selected: appearance.accent == accent,
                          onTap: () => ref
                              .read(appearanceProvider.notifier)
                              .setAccent(accent),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text('明暗', style: TextStyle(fontSize: 12, color: muted)),
                  const SizedBox(height: 10),
                  SegmentedButton<Brightness>(
                    segments: const [
                      ButtonSegment(
                        value: Brightness.light,
                        icon: Icon(Icons.light_mode_outlined, size: 16),
                        label: Text('浅色'),
                      ),
                      ButtonSegment(
                        value: Brightness.dark,
                        icon: Icon(Icons.dark_mode_outlined, size: 16),
                        label: Text('深色'),
                      ),
                    ],
                    selected: {appearance.brightness},
                    onSelectionChanged: (values) => ref
                        .read(appearanceProvider.notifier)
                        .setBrightness(values.first),
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      textStyle: WidgetStateProperty.all(
                        const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 共享
            _sectionTitle('共享', muted),
            Container(
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF252A35)
                      : const Color(0xFFE3E0E9),
                ),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < partners.length; i++) ...[
                    _row(
                      context,
                      leading: _initialDot(
                        context,
                        partners[i].initial.isEmpty
                            ? partners[i].name.substring(0, 1)
                            : partners[i].initial,
                        _memberColor(i),
                      ),
                      title: partners[i].name,
                      subtitle: '已加入 · 可见待办、愿望单',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '成员',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                  if (partners.isEmpty)
                    _row(
                      context,
                      leading: Icon(Icons.group_outlined, size: 20, color: muted),
                      title: '还没有共享成员',
                      subtitle: '对方登录同一个服务器，就能看到共享模块',
                    ),
                  if (partners.isEmpty) const Divider(height: 1),
                  _row(
                    context,
                    leading: Icon(Icons.person_add_alt_1_outlined,
                        size: 20, color: muted),
                    title: '邀请成员',
                    subtitle: '生成邀请码，对方加入后可共享模块',
                    onTap: () => _toast('需要后端支持，等接口好了再做'),
                  ),
                ],
              ),
            ),

            // 模块管理
            _sectionTitle('模块管理', muted),
            Container(
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF252A35)
                      : const Color(0xFFE3E0E9),
                ),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < appModules.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _moduleRow(context, appModules[i], partners),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () async {
                await ref.read(authProvider.notifier).signOut();
                if (context.mounted) context.go('/login');
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.4)),
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text('退出登录'),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '小窝 v0.1.0 · M0',
                style: TextStyle(fontSize: 11, color: muted.withValues(alpha: 0.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, Color color) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Text(text, style: TextStyle(fontSize: 12, color: color)),
      );

  Widget _moduleRow(
    BuildContext context,
    AppModule module,
    List<SpaceMember> partners,
  ) {
    final theme = Theme.of(context);
    final enabled = !_disabled.contains(module.id);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: module.accentSoft(theme),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(module.icon, size: 18, color: module.accent(theme)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '${enabled ? '已启用' : '已关闭'} · '
                  '${module.space == SpaceKind.personal ? '仅自己' : (partners.isEmpty ? '共享' : '与 ${partners.map((m) => m.name).join('、')} 共享')}',
                  style: TextStyle(fontSize: 11, color: AppTheme.muted(context)),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (v) => setState(() {
              if (v) {
                _disabled.remove(module.id);
              } else {
                _disabled.add(module.id);
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required Widget leading,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.muted(context),
                    ),
                  ),
                ],
              ),
            ),
            trailing ?? const SizedBox.shrink(),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppTheme.muted(context).withValues(alpha: 0.6),
              ),
          ],
        ),
      ),
    );
  }

  Color _memberColor(int index) {
    const palette = [
      Color(0xFFA6522E),
      Color(0xFF2F6FED),
      Color(0xFF0E7C86),
      Color(0xFF6750A4),
    ];
    return palette[index % palette.length];
  }

  Widget _initialDot(BuildContext context, String text, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AccentDot extends StatelessWidget {
  const _AccentDot({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final AccentColor accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? Color.lerp(accent.seed, Colors.white, 0.28)!
        : accent.seed;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 2.4,
              ),
            ),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              scale: selected ? 1 : 0,
              child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            accent.label,
            style: TextStyle(
              fontSize: 9.5,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : AppTheme.muted(context),
            ),
          ),
        ],
      ),
    );
  }
}
