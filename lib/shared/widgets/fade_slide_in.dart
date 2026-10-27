/// 进入动画：淡入 + 上移，带可选延迟（用来做列表的错峰出现）。
///
/// 会尊重系统的「减少动画」设置，无障碍场景下直接显示。
library;
import 'package:flutter/material.dart';

/// 入场动画：淡入 + 上移。用于列表分块出现、卡片依次浮现。
///
/// - 系统开了「减弱动态效果」时自动只做淡入，不做位移。
/// - 默认时长 380ms，easeOutCubic，位移 14px，足够明显但不拖沓。
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 380),
    this.offset = 14,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) {
        final t = curve.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, reduceMotion ? 0 : widget.offset * (1 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
