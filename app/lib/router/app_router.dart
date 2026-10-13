import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/connect/connect_page.dart';
import '../features/downloads/downloads_page.dart';
import '../features/favorites/favorites_page.dart';
import '../features/feed/feed_page.dart';
import '../features/folders/folders_page.dart';
import '../features/history/history_page.dart';
import '../features/settings/settings_page.dart';
import '../core/storage/preferences_store.dart';
import 'providers.dart';

/// 路由表。七个页面对应 PRD §7.1 清单。
/// 启动规则：填过地址 → /feed（探活失败显示掉线横幅，不跳走）；没填过 → /connect。
/// 服务端默认不开 token 鉴权，所以「有没有 token」不再决定去哪——有地址就能用。
final routerProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(preferencesProvider);
  final hasAddress = (prefs.baseUrl ?? '').isNotEmpty;

  return GoRouter(
    initialLocation: hasAddress ? '/feed' : '/connect',
    routes: [
      GoRoute(path: '/connect', builder: (_, __) => const ConnectPage()),
      GoRoute(path: '/feed', builder: (_, __) => const FeedPage()),
      GoRoute(path: '/history', builder: (_, __) => const HistoryPage()),
      GoRoute(path: '/favorites', builder: (_, __) => const FavoritesPage()),
      GoRoute(path: '/folders', builder: (_, __) => const FoldersPage()),
      GoRoute(path: '/downloads', builder: (_, __) => const DownloadsPage()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
    ],
  );
});
