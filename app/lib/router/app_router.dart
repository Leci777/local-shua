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
/// 启动规则：没配对过 → /connect；配对过 → /feed（探活失败显示掉线横幅，不跳走）。
final routerProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(preferencesProvider);
  final paired = prefs.isPaired;

  return GoRouter(
    initialLocation: paired ? '/feed' : '/connect',
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
