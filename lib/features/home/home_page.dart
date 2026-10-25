import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../core/api/api_providers.dart';
import '../../core/auth/auth_controller.dart';
import '../../modules/module.dart';
import '../../modules/registry.dart';
import '../../shared/widgets/fade_slide_in.dart';
import 'dashboard.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = AppTheme.muted(context);
    final session = ref.watch(authProvider);
    final partner = ref.watch(partnerProvider);
    final dashboard = ref.watch(dashboardProvider);
    final recent = ref.watch(recentProvider);
    final taglines = ref.watch(moduleTaglinesProvider);
    final sharedModules =
        appModules.where((m) => m.space == SpaceKind.shared).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            // 顶部问候
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_greeting()}，${session?.userName ?? '我'}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dateLine(),
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _DuoAvatar(
                            first: (session?.userName ?? '我').characters.first,
                            second: partner?.initial ?? '·',
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              partner == null
                                  ? '自己用 · ${sharedModules.map((m) => m.name).join(' / ')}'
                                  : '与 ${partner.name} 共享 · ${sharedModules.map((m) => m.name).join(' / ')}',
                              style: TextStyle(fontSize: 11, color: muted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    (session?.userName ?? '我').characters.first,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            _TodayCard(summary: dashboard, onTap: () => context.push('/todo')),

            const SizedBox(height: 24),
            Row(
              children: [
                const Text(
                  '我的模块',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('在「我的 → 模块管理」里开关模块')),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      '管理',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 166 / 96,
              children: [
                for (var i = 0; i < appModules.length; i++)
                  FadeSlideIn(
                    delay: Duration(milliseconds: 40 + i * 55),
                    offset: 18,
                    child: _ModuleCard(
                      module: appModules[i],
                      tagline: taglines[appModules[i].id],
                      onTap: () => context.push(appModules[i].route),
                    ),
                  ),
                FadeSlideIn(
                  delay: Duration(milliseconds: 40 + appModules.length * 55),
                  offset: 18,
                  child: _AddModuleCard(onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('模块市场还在规划中')),
                    );
                  }),
                ),
              ],
            ),

            if (recent.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                '最近打开',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < recent.length; i++) ...[
                FadeSlideIn(
                  delay: Duration(milliseconds: 120 + i * 70),
                  child: _RecentTile(
                    entry: recent[i],
                    onTap: () {
                      final module = moduleById(recent[i].moduleId);
                      if (module != null) context.push(module.route);
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了';
    if (hour < 11) return '早上好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }

  String _dateLine() {
    final now = DateTime.now();
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return '${now.month}月${now.day}日 · 周${weekdays[now.weekday - 1]}';
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.summary, required this.onTap});

  final DashboardSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onCard = scheme.onPrimaryContainer;
    final onCardMuted = scheme.onPrimaryContainer.withValues(alpha: 0.68);
    final next = summary.nextTitle == null
        ? '今天没有待办了'
        : '已完成 ${summary.todayDone} · 下一项 ${summary.nextTitle} ${summary.nextTime ?? ''}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('今天', style: TextStyle(fontSize: 12, color: onCardMuted)),
                  const SizedBox(height: 4),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.25),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Text(
                      '${summary.left} 项待办',
                      key: ValueKey<int>(summary.left),
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        color: onCard,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    next,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: onCardMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: summary.progress),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => CircularProgressIndicator(
                        value: value,
                        strokeWidth: 7,
                        backgroundColor: onCard.withValues(alpha: 0.18),
                        color: onCard,
                      ),
                    ),
                  ),
                  Text(
                    '${summary.todayDone}/${summary.todayTotal}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: onCard,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.onTap,
    this.tagline,
  });

  final AppModule module;
  final VoidCallback onTap;
  final String? tagline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = module.accent(theme);

    return Material(
      color: theme.cardTheme.color,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: module.accentSoft(theme),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(module.icon, size: 19, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tagline ?? module.tagline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (module.space == SpaceKind.personal)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: module.accentSoft(theme),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '仅我',
                    style: TextStyle(fontSize: 9.5, color: accent),
                  ),
                )
              else
                _DuoAvatar(first: 'Z', second: 'M'),
            ],
          ),
        ),
      ),
    );
  }
}

class _DuoAvatar extends StatelessWidget {
  const _DuoAvatar({required this.first, required this.second});

  final String first;
  final String second;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(theme, first, theme.colorScheme.primary, 0),
        Transform.translate(
          offset: const Offset(-6, 0),
          child: _dot(theme, second, const Color(0xFFA6522E), 0),
        ),
      ],
    );
  }

  Widget _dot(ThemeData theme, String text, Color color, double inset) {
    return Container(
      width: 16,
      height: 16,
      margin: EdgeInsets.only(left: inset),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          width: 1.4,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _AddModuleCard extends StatelessWidget {
  const _AddModuleCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.muted(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.muted(context).withValues(alpha: 0.35),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 22, color: muted),
            const SizedBox(height: 6),
            Text('添加模块', style: TextStyle(fontSize: 11, color: muted)),
          ],
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.entry, required this.onTap});

  final RecentEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final module = moduleById(entry.moduleId);
    final accent = module?.accent(theme) ?? theme.colorScheme.primary;

    return Material(
      color: theme.cardTheme.color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.brightness == Brightness.dark
                  ? const Color(0xFF252A35)
                  : const Color(0xFFE3E0E9),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: module?.accentSoft(theme),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(module?.icon ?? Icons.circle, size: 19, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppTheme.muted(context).withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
