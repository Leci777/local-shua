import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/video.dart';
import '../../core/theme.dart';
import '../../router/providers.dart';
import '../favorites/favorites_controller.dart';
import '../player/video_surface.dart';
import 'playback_controller.dart';

/// 播放页控制层（UI-DESIGN §4.1）：播放/暂停、进度条+时长、倍速、下载、收藏、更多。
class VideoOverlay extends ConsumerWidget {
  const VideoOverlay({
    super.key,
    required this.fileName,
    required this.folderName,
    required this.videoId,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.speed,
    this.onPlayPause,
    this.onSeek,
    this.onNext,
    this.onPrevious,
    this.onSpeed,
  });

  final String fileName;
  final String folderName;
  final int videoId;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double speed;
  final VoidCallback? onPlayPause;
  final ValueChanged<Duration>? onSeek;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final ValueChanged<double>? onSpeed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(favoriteIdsProvider).contains(videoId);

    return Stack(
      children: [
        // 上下渐变，保证白字可读
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
                fileName,
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(folderName, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),

        // 右下：功能按钮竖排
        Positioned(
          right: 8,
          bottom: 120,
          child: Column(
            children: [
              _CircleAction(
                icon: Icons.favorite,
                label: '收藏',
                active: isFavorite,
                activeColor: AppTheme.tertiary,
                onTap: () => ref
                    .read(favoriteIdsProvider.notifier)
                    .toggle(videoId, !isFavorite),
              ),
              const SizedBox(height: 12),
              const _CircleAction(icon: Icons.download, label: '下载'),
              const SizedBox(height: 12),
              const _CircleAction(icon: Icons.more_horiz, label: '更多'),
            ],
          ),
        ),

        // 底部控制条
        Positioned(
          left: 12,
          right: 12,
          bottom: 32,
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: AppTheme.onSurface,
                    ),
                    onPressed: onPlayPause,
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      ),
                      child: Slider(
                        // clamp 返回 num，Slider 只收 double，所以补一个 toDouble
                        value: position.inMilliseconds
                            .toDouble()
                            .clamp(
                              0,
                              duration.inMilliseconds > 0
                                  ? duration.inMilliseconds.toDouble()
                                  : 1,
                            )
                            .toDouble(),
                        max: duration.inMilliseconds > 0
                            ? duration.inMilliseconds.toDouble()
                            : 1,
                        onChanged: (value) => onSeek?.call(Duration(milliseconds: value.round())),
                      ),
                    ),
                  ),
                  Text(
                    '${_fmt(position)} / ${_fmt(duration)}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
              Row(
                children: [
                  // 倍速：点开选档
                  _SpeedChip(
                    speed: speed,
                    onSelected: (value) => onSpeed?.call(value),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.skip_previous, color: AppTheme.onSurface),
                    onPressed: onPrevious,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: AppTheme.onSurface),
                    onPressed: onNext,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _fmt(Duration d) {
    if (d <= Duration.zero) return '--:--';
    final total = d.inSeconds;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }
}

/// 倍速 chip：点开底部选择
class _SpeedChip extends StatelessWidget {
  const _SpeedChip({required this.speed, required this.onSelected});

  final double speed;
  final ValueChanged<double> onSelected;

  static const speeds = [0.5, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showModalBottomSheet<double>(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final value in speeds)
                  RadioListTile<double>(
                    value: value,
                    groupValue: speed,
                    title: Text('${value}x'),
                    onChanged: (v) => Navigator.pop(context, v),
                  ),
              ],
            ),
          ),
        );
        if (picked != null) onSelected(picked);
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '${speed}x',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
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