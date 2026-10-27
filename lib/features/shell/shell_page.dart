/// 主界面外壳：三个 tab + 启动同步 + 前台轮询。
///
/// tab 切换用 PageView 而不是路由，所以：
/// - 路由表里没有 /me、/album
/// - 跨页切 tab 用 shellTabProvider（首页头像点一下就走这个）
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_providers.dart';
import '../../core/sync/sync_poller.dart';

import '../../features/album/album_page.dart';
import '../../features/home/home_page.dart';
import '../../features/me/me_page.dart';
import 'shell_tab.dart';

/// 三个 tab 的外壳。模块页是 push 上来的，不在这里。
class ShellPage extends ConsumerStatefulWidget {
  const ShellPage({super.key});

  @override
  ConsumerState<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends ConsumerState<ShellPage> {
  int _index = 0;

  /// 前台轮询器，见 sync_poller.dart
  late final SyncPoller _poller;

  @override
  void initState() {
    super.initState();
    // 进入主界面才开始轮询；退出登录（ShellPage 销毁）就停掉
    _poller = ref.read(syncPollerProvider);
    _poller.start();
  }

  late final PageController _controller = PageController(initialPage: _index);

  static const _pages = <Widget>[
    HomePage(),
    AlbumPage(),
    MePage(),
  ];

  @override
  void dispose() {
    _poller.stop();
    _controller.dispose();
    super.dispose();
  }

  void _go(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
    // 其它页面（比如首页头像）也能要求切 tab
    ref.read(shellTabProvider.notifier).state = i;
  }

  @override
  Widget build(BuildContext context) {
    // 冷启动/登录后拉一次全量增量。只有这一次会弹错误提示，
    // 后续的 30 秒轮询失败是静默的。
    ref.listen(startupSyncProvider, (previous, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败：${next.error}')),
        );
      }
    });
    ref.watch(startupSyncProvider);

    ref.listen<int>(shellTabProvider, (previous, next) {
      if (next != _index) _go(next);
    });

    return Scaffold(
      body: PageView(
        controller: _controller,
        // 只允许点导航切换，避免和列表横滑冲突
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) {
          setState(() => _index = i);
          ref.read(shellTabProvider.notifier).state = i;
        },
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '工作台',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library_rounded),
            label: '相册',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
