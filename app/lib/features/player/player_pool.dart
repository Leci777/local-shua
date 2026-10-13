import 'dart:async';

import 'package:media_kit/media_kit.dart';

import '../../core/logger.dart';
import '../../core/models/video.dart';

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

  /// media_kit 的播放地址：本地绝对路径或网络 URL
  String get mediaUrl => localPath ?? streamUrl;

  bool get isLocal => localPath != null;

  VideoRef withLocalPath(String? path) => VideoRef(
        videoId: videoId,
        fileName: fileName,
        streamUrl: streamUrl,
        localPath: path,
      );
}

/// 播放器池：最多同时持有 2 个 Player（active 当前播 + standby 预载下一个）。
/// 2 个是内存与预加载效果的折中——架构 §3.5。
class PlayerPool {
  Player? _active;
  Player? _standby;

  Player get active => _active ??= Player(configuration: const PlayerConfiguration());
  bool get hasStandby => _standby != null;

  /// 取可用 Player 来播。standby 优先提升为 active（它已经预载好了，起播最快）。
  Player acquire() {
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

  /// 预载下一个视频到 standby（不播，只解封装 + 首段缓冲）
  void preload(String mediaUrl) {
    final old = _standby;
    _standby = Player(configuration: const PlayerConfiguration());
    if (old != null) {
      unawaited(old.dispose().catchError((Object _) {}));
    }
    dLog('预载下一个：${mediaUrl.split('/').last}');
    unawaited(_standby!.open(Media(mediaUrl), play: false));
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