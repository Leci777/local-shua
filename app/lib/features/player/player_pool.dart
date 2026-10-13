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

  VideoPlayerController? get activeOrNull => _active;
  bool get hasStandby => _standby != null;

  /// 当前正在播的控制器；没播过返回 null（不要凭空造一个占位的，那只会拿到无效地址）
  VideoPlayerController get active {
    final a = _active;
    if (a == null) {
      throw StateError('播放器还没打开，先调 acquire(url)');
    }
    return a;
  }

  /// 取控制器来播指定地址。
  ///
  /// video_player 的地址在构造时就定死，没法像 media_kit 那样 open(url) 改地址，
  /// 所以这里 acquire 时就把真实地址绑进去。
  /// standby 若已预载好这条（或干脆不管它，直接用新控制器）就用它，否则新建。
  Future<VideoPlayerController> acquire(String mediaUrl) async {
    final standby = _standby;
    if (standby != null) {
      _standby = null;
      final old = _active;
      _active = standby;
      if (old != null && !identical(old, standby)) {
        unawaited(old.dispose().catchError((Object _) {}));
      }
      return standby;
    }

    // standby 没有就直接换一个绑好地址的
    final ctrl = _make(mediaUrl);
    final old = _active;
    _active = ctrl;
    if (old != null && !identical(old, ctrl)) {
      unawaited(old.dispose().catchError((Object _) {}));
    }
    return ctrl;
  }

  /// 预载下一个视频到 standby（只初始化到首帧，不真正播放）
  void preload(String mediaUrl) {
    final old = _standby;
    final ctrl = _make(mediaUrl);
    _standby = ctrl;
    if (old != null) {
      unawaited(old.dispose().catchError((Object _) {}));
    }
    dLog('预载下一个：${mediaUrl.split('/').last}');
    // initialize 会走到 setSource + prepare，首帧解封装就绪；
    // 然后 pause() 让它停在首帧，避免自动往下播
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