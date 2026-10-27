/// 全屏看图：左右滑、双指缩放、底部改说明、右上角删除。
library;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../shared/widgets/run_guarded.dart';
import '../album_providers.dart';
import '../domain/photo_group.dart';

/// 全屏看图：左右滑切换，底部改说明。
class PhotoViewer extends ConsumerStatefulWidget {
  const PhotoViewer({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  final List<Photo> photos;
  final int initialIndex;

  @override
  ConsumerState<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends ConsumerState<PhotoViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  late final TextEditingController _caption = TextEditingController(
    text: widget.photos[widget.initialIndex].caption,
  );
  bool _showChrome = true;

  Photo get _current => widget.photos[_index];

  @override
  void dispose() {
    _controller.dispose();
    _caption.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final photo = _current;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这张照片？'),
        content: const Text('本地和服务器上的都会删掉。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final done = await runGuarded(
      context,
      () => ref.read(albumRepositoryProvider).remove(photo),
    );
    if (done && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showChrome = !_showChrome),
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.photos.length,
              onPageChanged: (i) {
                setState(() {
                  _index = i;
                  _caption.text = widget.photos[i].caption;
                });
              },
              itemBuilder: (context, i) => InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Image.file(
                    File(widget.photos[i].path),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),

            AnimatedOpacity(
              opacity: _showChrome ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: IgnorePointer(
                ignoring: !_showChrome,
                child: Column(
                  children: [
                    SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_index + 1} / ${widget.photos.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _delete,
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _bottomBar(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context) {
    final meta = [
      formatSize(_current.width, _current.height),
      formatBytes(_current.sizeBytes),
      '${_current.takenAt.month}月${_current.takenAt.day}日',
    ].where((e) => e.isNotEmpty).join(' · ');

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 说明目前只读：后端还没提供 PATCH /api/photos/{id}，
            // 本地改了会在下次同步时被服务端的空值覆盖，索性先不给编辑。
            if (_current.caption.isNotEmpty)
              Text(
                _current.caption,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  meta,
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
                const Spacer(),
                if (_current.fileId.isNotEmpty)
                  const Row(
                    children: [
                      Icon(
                        Icons.cloud_done_outlined,
                        size: 13,
                        color: Colors.white38,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '已上传',
                        style: TextStyle(fontSize: 11, color: Colors.white38),
                      ),
                    ],
                  )
                else
                  const Row(
                    children: [
                      Icon(
                        Icons.cloud_off_outlined,
                        size: 13,
                        color: Colors.white38,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '仅本机',
                        style: TextStyle(fontSize: 11, color: Colors.white38),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
