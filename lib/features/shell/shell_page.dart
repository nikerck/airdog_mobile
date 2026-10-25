import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_providers.dart';

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
  late final PageController _controller = PageController(initialPage: _index);

  static const _pages = <Widget>[
    HomePage(),
    AlbumPage(),
    MePage(),
  ];

  @override
  void dispose() {
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
