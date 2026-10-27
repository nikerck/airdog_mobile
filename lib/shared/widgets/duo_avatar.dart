/// 小头像组：我 + 第一个伙伴，人再多折叠成「+N」。
library;
import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// 小圆形头像组：我 + 第一个伙伴，人再多就折叠成「+N」。
class DuoAvatar extends StatelessWidget {
  const DuoAvatar({
    super.key,
    required this.first,
    this.second,
    this.extra = 0,
  });

  /// 自己的头像字
  final String first;

  /// 第一个伙伴的头像字；没有伙伴时传 null，只画一个
  final String? second;

  /// 还有几个人没画出来
  final int extra;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(theme, first, theme.colorScheme.primary),
        if (second != null)
          Transform.translate(
            offset: const Offset(-6, 0),
            child: _dot(theme, second!, const Color(0xFFA6522E)),
          ),
        if (extra > 0)
          Transform.translate(
            offset: const Offset(-6, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? theme.colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: theme.dividerColor, width: 1),
              ),
              alignment: Alignment.center,
              child: Text(
                '+$extra',
                style: TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.muted(context),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _dot(ThemeData theme, String text, Color color) {
    return Container(
      width: 16,
      height: 16,
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
