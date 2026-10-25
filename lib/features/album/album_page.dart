import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

class AlbumPage extends StatelessWidget {
  const AlbumPage({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.muted(context);
    final outline = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF252A35)
        : const Color(0xFFE3E0E9);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            const Text(
              '相册',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text('照片 · 时间线 · 共享', style: TextStyle(fontSize: 12, color: muted)),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 44),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: outline, width: 1.2),
              ),
              child: Column(
                children: [
                  Icon(Icons.photo_library_outlined,
                      size: 52, color: muted.withValues(alpha: 0.7)),
                  const SizedBox(height: 16),
                  const Text(
                    '相册还没开始做',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '计划：按时间线浏览、自动按月份分组、\n和 Momo 共享的相册、原图备份',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, height: 1.9, color: muted),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.softSurface(context),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text('规划中', style: TextStyle(fontSize: 10, color: muted)),
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
