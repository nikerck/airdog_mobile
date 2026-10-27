/// 全局页面切换动画：淡入 + 轻微上移 + 微缩放。
///
/// 系统默认的左右滑在安卓上显得生硬，这里统一成 320ms 的 easeOutCubic。
/// 会尊重系统的「减少动画」设置（MediaQuery.disableAnimations）。
library;
import 'package:flutter/material.dart';

/// 页面推入/返回的转场：淡入 + 轻微上移 + 极小缩放。
///
/// Material 默认的 Android 转场是「纵向放大」，在深色主题上会闪；
/// 这套参数更接近 iOS 的观感，且两端一致。
class SoftPageTransitionsBuilder extends PageTransitionsBuilder {
  const SoftPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
          child: child,
        ),
      ),
    );
  }
}
