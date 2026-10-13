import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/data/favorite_repository.dart';
import '../core/data/folder_repository.dart';
import '../core/data/history_repository.dart';
import '../core/data/server_repository.dart';
import '../core/data/settings_repository.dart';
import '../core/data/video_repository.dart';
import '../core/network/api_client.dart';
import '../core/storage/preferences_store.dart';

/// 全局依赖。长生命对象用全局 Provider 常驻（架构 §3.3）。

/// SharedPreferences 在 main 里打开后 override 进来
final preferencesProvider = Provider<PreferencesStore>((ref) {
  throw UnimplementedError('preferencesProvider 必须在 main 里 override');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(preferencesProvider));
});

// ===== 仓库 =====
final serverRepositoryProvider = Provider((ref) => ServerRepository(ref.watch(apiClientProvider)));
final videoRepositoryProvider = Provider((ref) => VideoRepository(ref.watch(apiClientProvider)));
final folderRepositoryProvider = Provider((ref) => FolderRepository(ref.watch(apiClientProvider)));
final historyRepositoryProvider = Provider((ref) => HistoryRepository(ref.watch(apiClientProvider)));
final favoriteRepositoryProvider = Provider((ref) => FavoriteRepository(ref.watch(apiClientProvider)));
final settingsRepositoryProvider = Provider((ref) => SettingsRepository(ref.watch(apiClientProvider)));
