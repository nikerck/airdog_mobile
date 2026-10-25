import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/db/app_database.dart';
import '../../shared/widgets/run_guarded.dart';
import 'domain/photo_group.dart';
import 'album_providers.dart';
import 'ui/photo_viewer.dart';

class AlbumPage extends ConsumerWidget {
  const AlbumPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = AppTheme.muted(context);
    final photos = ref.watch(photosProvider).valueOrNull ?? const <Photo>[];
    final groups = groupByMonth(photos);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
        label: const Text('添加照片'),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  '相册',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    photos.isEmpty ? '' : '${photos.length} 张',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '照片存在你的服务器，索引在本机',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 18),
            if (photos.isEmpty)
              _EmptyState(onTap: () => _add(context, ref))
            else
              for (final group in groups) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: Row(
                    children: [
                      Text(
                        group.label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${group.photos.length}',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ),
                ),
                _Grid(
                  photos: group.photos,
                  all: photos,
                  onTap: (index) =>
                      _open(context, ref, photos: group.photos, index: index),
                ),
                const SizedBox(height: 14),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(albumRepositoryProvider);
    await runGuarded(context, () async {
      final added = await repo.addPicked();
      if (added > 0 && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已添加 $added 张')));
      }
    });
  }

  void _open(
    BuildContext context,
    WidgetRef ref, {
    required List<Photo> photos,
    required int index,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: animation,
          child: PhotoViewer(photos: photos, initialIndex: index),
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.photos, required this.all, required this.onTap});

  final List<Photo> photos;
  final List<Photo> all;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: photos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, i) =>
          _Tile(photo: photos[i], onTap: () => onTap(i)),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.photo, required this.onTap});

  final Photo photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.dividerColor, width: 0.8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Container(
            color: theme.dividerColor.withValues(alpha: 0.4),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(photo.path),
                  fit: BoxFit.cover,
                  cacheWidth: 320,
                  errorBuilder: (_, _, _) => Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 20,
                      color: AppTheme.muted(context),
                    ),
                  ),
                ),
                if (photo.caption.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 10, 6, 5),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black54, Colors.transparent],
                        ),
                      ),
                      child: Text(
                        photo.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.muted(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 46),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerColor, width: 1.2),
        ),
        child: Column(
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 52,
              color: muted.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            const Text(
              '还没有照片',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              '从相册选几张，原图会上传到你的服务器，\n手机和电脑都能看',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, height: 1.9, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
