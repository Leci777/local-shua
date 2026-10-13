import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 视频显示面：包一层 media_kit 的 Video，保证控制器唯一。
/// 不用 AutomaticKeepAlive——切视频时整棵 PageView item 会重建。
class VideoSurface extends StatelessWidget {
  const VideoSurface({super.key, required this.controller});

  final dynamic controller; // PlaybackController，避免循环 import

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Video(
        controller: controller.player,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        // 视频首帧到达前全黑屏，加个底色防闪白（media_kit 的参数叫 fill）
        fill: Colors.black,
      ),
    );
  }
}