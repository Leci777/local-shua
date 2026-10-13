import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 视频显示面：包一层系统播放器的 Texture，首帧到达前显示黑底。
/// 不用 AutomaticKeepAlive——切视频时整棵 PageView item 会重建。
class VideoSurface extends StatelessWidget {
  const VideoSurface({super.key, required this.controller});

  final dynamic controller; // PlaybackController，避免循环 import

  @override
  Widget build(BuildContext context) {
    final player = controller.player as VideoPlayerController;
    return ColoredBox(
      color: Colors.black,
      child: player.value.isInitialized
          // cover 铺满：竖屏刷视频必须填满，contain 会留黑边
          ? FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: player.value.size.width,
                height: player.value.size.height,
                child: VideoPlayer(player),
              ),
            )
          // 首帧还没到，先占住黑屏免得闪一下白
          : const SizedBox.expand(),
    );
  }
}