import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_providers.dart';
import '../../core/api/file_api.dart';
import '../../core/db/app_database.dart';
import '../../core/db/db_provider.dart';
import 'data/album_repository.dart';

final albumRepositoryProvider = Provider<AlbumRepository>((ref) {
  final dio = ref.watch(apiDioProvider);
  return AlbumRepository(
    ref.watch(databaseProvider),
    fileApi: dio == null ? null : FileApi(dio),
  );
});

final photosProvider = StreamProvider<List<Photo>>(
  (ref) => ref.watch(albumRepositoryProvider).watch(),
);
