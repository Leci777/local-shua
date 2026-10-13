import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/video.dart';
import '../../core/theme.dart';
import '../../router/providers.dart';

/// 播放页控制层（UI-DESIGN §4.1）：播放/暂停、进度条+时长、倍速、下载、收藏、更多。
/// 点击屏幕显隐，3 秒无操作自动淡出（淡出逻辑在 Page 层配合）。
class VideoOverlay extends ConsumerWidget {
  const VideoOverlay({
    super.key,
    required this.video,
    required this.onPlayNext,
  });

  final Video video;
  final VoidCallback onPlayNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(favoriteIdsProvider).contains(video.id);

    return Stack(
      children: [
        // 底部渐变，保证白字可读
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x8C000000), Colors.transparent, Color(0x99000000)],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
        // 左上：文件名 + 文件夹名
        Positioned(
          top: MediaQuery.of(context).padding.top + 56,
          left: 16,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                video.fileName,
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(video.folderName, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
        // 右下：功能按钮竖排（倍速/下载/收藏）
        Positioned(
          right: 12,
          bottom: 120,
          child: Column(
            children: [
              _CircleAction(
                icon: Icons.favorite,
                active: isFavorite,
                activeColor: AppTheme.tertiary,
                label: '收藏',
                onTap: () async {
                  await ref.read(favoriteIdsProvider.notifier).toggle(video.id, !isFavorite);
                },
              ),
              const SizedBox(height: 16),
              const _CircleAction(icon: Icons.download, label: '下载', onTap: null),
              const SizedBox(height: 16),
              const _CircleAction(icon: Icons.more_horiz, label: '更多', onTap: null),
            ],
          ),
        ),
        // 底部：播放控制条
        Positioned(
          left: 16,
          right: 16,
          bottom: 40,
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.pause, color: AppTheme.onSurface),
                    onPressed: () {}, // W2-04 接播放器
                  ),
                  Expanded(
                    child: Slider(
                      value: 0,
                      onChanged: (_) {}, // W2-04 接播放器
                    ),
                  ),
                  Text('--:-- / --:--', style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
              Row(
                children: [
                  Chip(
                    label: const Text('1.0x'),
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) {}, // W3-03 倍速
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 圆形图标按钮：48dp 热区（UI-DESIGN §5）
class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
    this.activeColor = AppTheme.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppTheme.minTouchTarget,
      height: AppTheme.minTouchTarget + 16,
      child: Column(
        children: [
          IconButton(
            icon: Icon(icon, color: active ? activeColor : AppTheme.onSurface),
            onPressed: onTap,
          ),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
