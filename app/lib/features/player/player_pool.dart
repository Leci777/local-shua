import 'dart:async';
import 'dart:io';

import '../../core/logger.dart';
import '../../core/models/video.dart';
import 'package:video_player/video_player.dart';

/// 要播的一个视频：优先本地文件，其次网络流（架构 §3.5「起播前查本地」）。
class VideoRef {
  final int videoId;
  final String fileName;
  final String streamUrl;
  final String? localPath;

  const VideoRef({
    required this.videoId,
    required this.fileName,
    required this.streamUrl,
    this.localPath,
  });

  factory VideoRef.fromVideo(Video video, String streamUrl, {String? localPath}) => VideoRef(
        videoId: video.id,
        fileName: video.fileName,
        streamUrl: streamUrl,
        localPath: localPath,
      );

  /// 播放地址：本地绝对路径或网络 URL
  String get mediaUrl => localPath ?? streamUrl;

  bool get isLocal => localPath != null;

  VideoRef withLocalPath(String? path) => VideoRef(
        videoId: videoId,
        fileName: fileName,
        streamUrl: streamUrl,
        localPath: path,
      );
}

/// 播放器池：最多同时持有 2 个控制器（active 当前播 + standby 预载下一个）。
/// 2 个是内存与预加载效果的折中——架构 §3.5。
///
/// 用系统播放器（video_player，Android 走 ExoPlayer 原生解码）而不是 libmpv：
/// libmpv 的原生库要从 GitHub 下载，国内网络不稳会导致构建失败，且每次构建多等好几分钟。
class PlayerPool {
  VideoPlayerController? _active;
  VideoPlayerController? _standby;

  VideoPlayerController get active =>
      _active ??= VideoPlayerController.networkUrl(Uri.parse(_placeholderUrl));
  VideoPlayerController? get activeOrNull => _active;
  bool get hasStandby => _standby != null;

  /// 站位地址：真正的地址在 open 时才给，这个只是让类型完整
  static const _placeholderUrl = 'http://127.0.0.1/placeholder';

  /// 取可用控制器来播。standby 优先提升为 active（它已经预载好了，起播最快）。
  VideoPlayerController acquire() {
    if (_standby != null) {
      final promoted = _standby!;
      _standby = null;
      final old = _active;
      _active = promoted;
      if (old != null && !identical(old, promoted)) {
        unawaited(old.dispose().catchError((Object _) {}));
      }
      return promoted;
    }
    return active;
  }

  /// 预载下一个视频到 standby（只初始化 + 起播到首帧，不真正播放）
  void preload(String mediaUrl) {
    final old = _standby;
    final ctrl = _make(mediaUrl);
    _standby = ctrl;
    if (old != null) {
      unawaited(old.dispose().catchError((Object _) {}));
    }
    dLog('预载下一个：${mediaUrl.split('/').last}');
    // initialize 会走到 setSource + prepare，首帧解封装就绪；
    // play() 再 pause() 是为了让 ExoPlayer 停在首帧，避免自动往下播
    unawaited(() async {
      try {
        await ctrl.initialize();
        await ctrl.pause();
      } catch (e) {
        dLog('预载失败：$e');
      }
    }());
  }

  static VideoPlayerController _make(String mediaUrl) {
    final uri = Uri.tryParse(mediaUrl);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return VideoPlayerController.networkUrl(uri);
    }
    // 本地绝对路径（Windows 风格 C:\...），用 file 协议交给 ExoPlayer
    return VideoPlayerController.file(File(mediaUrl));
  }

  Future<void> releaseAll() async {
    final a = _active;
    final s = _standby;
    _active = null;
    _standby = null;
    await a?.dispose();
    await s?.dispose();
  }
}