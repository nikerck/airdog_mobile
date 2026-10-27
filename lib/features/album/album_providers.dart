/// 相册 provider：仓库 + 照片流。
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/db/db_provider.dart';
import 'data/album_repository.dart';

final albumRepositoryProvider = Provider<AlbumRepository>(
  (ref) => AlbumRepository(
    ref.watch(databaseProvider),
    sync: ref.watch(syncServiceProvider),
  ),
);

final photosProvider = StreamProvider<List<Photo>>(
  (ref) => ref.watch(albumRepositoryProvider).watch(),
);
