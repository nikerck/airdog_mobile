import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airdog_mobile/core/sync/sync_poller.dart';

void main() {
  // SyncPoller 要往 WidgetsBinding 注册生命周期监听
  TestWidgetsFlutterBinding.ensureInitialized();

  test('每 30 秒拉一次', () {
    fakeAsync((async) {
      var count = 0;
      final poller = SyncPoller(
        pull: () async {
          count++;
          return 0;
        },
      );
      poller.start();

      // 启动时先等一个周期，不立即拉（启动那次由 startupSyncProvider 负责）
      async.elapse(const Duration(seconds: 29));
      expect(count, 0);

      async.elapse(const Duration(seconds: 2));
      expect(count, 1);

      async.elapse(const Duration(seconds: 30));
      expect(count, 2);

      poller.stop();
      async.elapse(const Duration(minutes: 5));
      expect(count, 2, reason: '停止后不应该再拉');
    });
  });

  test('切到后台就停，回到前台立刻拉一次', () {
    fakeAsync((async) {
      var count = 0;
      final poller = SyncPoller(
        pull: () async {
          count++;
          return 0;
        },
      );
      poller.start();
      async.elapse(const Duration(seconds: 30));
      expect(count, 1);

      poller.didChangeAppLifecycleState(AppLifecycleState.paused);
      async.elapse(const Duration(minutes: 5));
      expect(count, 1, reason: '后台不轮询');

      poller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      async.flushMicrotasks();
      expect(count, 2, reason: '切回前台立刻拉一次');

      async.elapse(const Duration(seconds: 30));
      expect(count, 3, reason: '恢复定时器');

      poller.stop();
    });
  });

  test('上一轮没回来就跳过这一轮', () {
    fakeAsync((async) {
      var started = 0;
      final poller = SyncPoller(
        pull: () {
          started++;
          // 永远不完成，模拟网络很慢
          return Future<int>.delayed(const Duration(minutes: 10), () => 0);
        },
      );
      poller.start();

      async.elapse(const Duration(minutes: 2));
      expect(started, 1, reason: '不能叠加请求');

      poller.stop();
    });
  });

  test('拉取失败不抛出去，只记录', () {
    fakeAsync((async) {
      final poller = SyncPoller(
        pull: () async => throw Exception('网络炸了'),
      );
      poller.start();
      async.elapse(const Duration(seconds: 31));

      expect(poller.lastError, isNotNull);
      expect(poller.tickCount, 0);

      poller.stop();
    });
  });

  test('stop 之后生命周期回调也不干活', () {
    fakeAsync((async) {
      var count = 0;
      final poller = SyncPoller(
        pull: () async {
          count++;
          return 0;
        },
      );
      poller.start();
      poller.stop();

      poller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      async.elapse(const Duration(minutes: 2));
      expect(count, 0);
    });
  });
}
