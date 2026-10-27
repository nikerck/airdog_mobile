/// 前台轮询器：App 在前台时每 30 秒拉一次增量。
///
/// 只负责「什么时候拉」，真正拉数据的是 SyncService.pullAll()。
library;
import 'dart:async';

import 'package:flutter/widgets.dart';

/// 前台轻量轮询：App 回到前台后，每隔 [interval] 拉一次增量。
///
/// 为什么需要它：
/// 之前只在冷启动和写冲突时拉数据，另一台设备改了什么，这边要杀掉 App
/// 重开才看得到。加个 30 秒的轮询，双方基本能「准实时」看到彼此。
///
/// 几个设计上的取舍：
/// - **只在前台跑**：切到后台就停，不然白耗电、白费流量。
/// - **不重叠**：上一轮还没回来就跳过这一轮（[pull] 内部也会合并并发调用）。
/// - **失败不打扰用户**：轮询是后台行为，出错只记日志，不弹 SnackBar；
///   真正需要用户知道的错误（比如手动操作失败）由页面各自提示。
/// - **回到前台立刻拉一次**：用户切回来通常就是想看最新状态，不该再等 30 秒。
class SyncPoller with WidgetsBindingObserver {
  SyncPoller({
    required this.pull,
    this.interval = const Duration(seconds: 30),
  });

  /// 拉一次增量，返回拉到的条数（返回值这里不关心，只为可测试）
  final Future<int> Function() pull;

  /// 轮询间隔
  final Duration interval;

  Timer? _timer;

  /// 是否已经 start 过（防止重复注册生命周期监听）
  bool _started = false;

  /// 一轮拉取是否还在进行中
  bool _busy = false;

  /// App 当前是否在前台
  bool _foreground = true;

  /// 主动停止后不再自动恢复
  bool _stopped = false;

  /// 最近一次轮询的结果，排查问题时看
  Object? lastError;

  /// 已经成功轮询的次数
  int tickCount = 0;

  /// 开始轮询（可重复调用，只有第一次生效）
  void start() {
    if (_started) return;
    _started = true;
    _stopped = false;
    WidgetsBinding.instance.addObserver(this);

    // App 刚启动时可能已经拉过一次（startupSyncProvider），
    // 这里只启动定时器，不立刻再拉一遍。
    _schedule();
  }

  /// 停止轮询并注销监听（退出登录、离开主界面时调用）
  void stop() {
    _stopped = true;
    _timer?.cancel();
    _timer = null;
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      _started = false;
    }
  }

  /// 手动触发一次（下拉刷新之类的场景可以复用）
  Future<void> kick() => _tick();

  void _schedule() {
    _timer?.cancel();
    if (_stopped) return;
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  Future<void> _tick() async {
    // 后台、已停止、或上一轮还没回来 → 跳过
    if (_stopped || !_foreground || _busy) return;

    _busy = true;
    try {
      await pull();
      tickCount++;
      lastError = null;
    } catch (e) {
      // 轮询失败静默处理：网络抖一下不该弹窗打扰
      lastError = e;
      debugPrint('轮询同步失败：$e');
    } finally {
      _busy = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_stopped) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _foreground = true;
        _schedule();
        // 切回来立刻拉一次，别让用户等下一个 30 秒
        unawaited(_tick());
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _foreground = false;
        _timer?.cancel();
        _timer = null;
    }
  }

  /// 测试里用：判断定时器是否在跑
  @visibleForTesting
  bool get isRunning => _timer?.isActive ?? false;
}
