import 'package:flutter/material.dart';

/// 圆形头像：有图就显示图，没有就显示首字，加载失败也回落到首字。
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.initial,
    this.imageUrl,
    this.size = 42,
    this.background,
    this.foreground,
    this.onTap,
  });

  final String initial;
  final String? imageUrl;
  final double size;
  final Color? background;
  final Color? foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = background ?? theme.colorScheme.primary.withValues(alpha: 0.15);
    final fg = foreground ?? theme.colorScheme.primary;

    final fallback = Container(
      color: bg,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );

    final avatar = SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: imageUrl == null || imageUrl!.isEmpty
            ? fallback
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : fallback,
              ),
      ),
    );

    if (onTap == null) return avatar;
    return GestureDetector(onTap: onTap, child: avatar);
  }
}
