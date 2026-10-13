import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/video.dart';
import '../../core/theme.dart';
import '../../router/providers.dart';
import 'favorites_controller.dart';

/// 收藏列表页（UI-DESIGN §4.4）。
class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('收藏')),
      body: favorites.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e', style: const TextStyle(color: AppTheme.error)),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return _EmptyState(
              icon: Icons.star_border,
              text: '看到喜欢的，点播放页里的星星，就会出现在这。',
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = items[index];
              return _VideoListTile(
                video: entry.video,
                subtitle: '收藏于 ${_formatDate(entry.favoritedAt)}',
                trailing: IconButton(
                  icon: const Icon(Icons.star, color: AppTheme.tertiary),
                  onPressed: () => ref
                      .read(favoriteIdsProvider.notifier)
                      .toggle(entry.video.id, false),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

/// 收藏列表数据。FutureProvider：进页面拉一次，取消收藏后 invalidate 刷新。
final favoritesListProvider = FutureProvider<List<({Video video, String favoritedAt})>>(
  (ref) => ref.watch(favoriteRepositoryProvider).list(),
);

/// 空态：大图标 + 一句人话 + （有下一步时）文字按钮（UI-DESIGN §3）
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: AppTheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(text, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// 视频列表项：缩略图占位 + 文件名 + 副标题（UI-DESIGN §4.3）
class _VideoListTile extends StatelessWidget {
  const _VideoListTile({
    required this.video,
    required this.subtitle,
    this.trailing,
  });

  final Video video;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 80,
        height: 56,
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.play_circle_outline, color: AppTheme.onSurfaceVariant),
      ),
      title: Text(video.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
      trailing: trailing,
      onTap: () {
        // TODO(W2-05): 点击进信息流并定位到这个视频
      },
    );
  }
}
