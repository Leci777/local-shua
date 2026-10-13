import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants.dart';
import '../../core/data/video_repository.dart';
import '../../core/logger.dart';
import '../../core/models/video.dart';
import '../../core/storage/preferences_store.dart';
import '../../router/providers.dart';
import '../feed/shuffle_bag.dart';
import 'player_pool.dart';

/// 播放状态：给 UI 用的不可变快照
class PlaybackState {
  final VideoRef? current;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double speed;
  final bool loading;
  final String? errorText;

  /// 当前视频所属文件夹名（信息流左上角显示）
  String get folderName => _folderName ?? '';

  String? _folderName;

  PlaybackState({
    this.current,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.loading = false,
    this.errorText,
    String? folderName,
  }) : _folderName = folderName;

  PlaybackState copyWith({
    VideoRef? current,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    double? speed,
    bool? loading,
    String? errorText,
    String? folderName,
  }) =>
      PlaybackState(
        current: current ?? this.current,
        isPlaying: isPlaying ?? this.isPlaying,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        speed: speed ?? this.speed,
        loading: loading ?? this.loading,
        errorText: errorText,
        folderName: folderName ?? _folderName,
      );
}

/// 播放控制器：串起「洗牌袋 → 播放 → 进度上报」这条主链。
/// 进度双触发（时间 + 事件，架构 §4.4），保证退出瞬间不丢进度。
class PlaybackController extends StateNotifier<PlaybackState> {
  PlaybackController(this._repo, this._prefs)
      : super(PlaybackState(speed: 1.0)) {
    _bag.onNeedMore = _fetchMore;
  }

  final VideoRepository _repo;
  final PreferencesStore _prefs;
  final ShuffleBag _bag = ShuffleBag();
  final PlayerPool _pool = PlayerPool();

  Timer? _progressTimer;
  DateTime _lastReportAt = DateTime.fromMillisecondsSinceEpoch(0);

  // ===== 生命周期 =====

  Future<void> start() async {
    if (state.current != null || state.loading) return;
    _startProgressTimer();
    await _fetchMore(initial: true);
  }

  // ===== 随机取视频 =====

  Future<void> _fetchMore({bool initial = false}) async {
    if (state.loading) return;
    state = state.copyWith(loading: true, errorText: null);
    try {
      final result = await _repo.random(
        limit: Constants.randomBatchSize,
        exclude: _bag.recentIds,
      );
      if (result.items.isEmpty) {
        state = state.copyWith(
          loading: false,
          errorText: result.poolSize == 0
              ? '还没有视频。去电脑管理页添加文件夹，再点「扫描」。'
              : null,
        );
        return;
      }
      _bag.refill(result.items);
      state = state.copyWith(loading: false);
      if (initial) await _playCurrent();
    } catch (e) {
      state = state.copyWith(loading: false, errorText: '$e');
    }
  }

  Future<void> _playCurrent() async {
    final video = _bag.nextRandom();
    if (video == null) {
      await _fetchMore();
      return;
    }
    await _open(video);
    _preloadNext();
  }

  /// 预载下一条：袋里还有就预载，否则先拉一批
  void _preloadNext() {
    if (_bag.remaining > 0) {
      final next = _bag.peekNext();
      if (next != null) {
        _pool.preload(_repo.streamUrl(next.id));
        return;
      }
    }
    // 袋空了，让 onNeedMore 补货；补完后再预载
    Future.microtask(() async {
      await _fetchMore();
      final next = _bag.peekNext();
      if (next != null) _pool.preload(_repo.streamUrl(next.id));
    });
  }

  // ===== 播放控制 =====

  Future<void> _open(Video video, {Duration startAt = Duration.zero}) async {
    final ref = VideoRef.fromVideo(video, _repo.streamUrl(video.id));
    state = state.copyWith(
      current: ref,
      position: startAt,
      loading: true,
      errorText: null,
      folderName: video.folderName,
    );

    // 系统播放器不支持「先 open 再 seek」，得先 initialize 再跳进度
    final player = _pool.acquire();
    _bindStreams(player);

    try {
      await player.initialize();
      if (startAt > Duration.zero) {
        await player.seekTo(startAt);
      }
      await player.play();
      state = state.copyWith(
        loading: false,
        isPlaying: true,
        duration: player.value.duration,
      );
    } catch (e) {
      dLog('打开视频失败：$e');
      state = state.copyWith(loading: false, errorText: '这条没加载上，滑走试试');
    }
  }

  void _bindStreams(VideoPlayerController player) {
    player.addListener(_onTick);
  }

  /// video_player 只有单一流，没有 media_kit 那样分开的 playing/position/duration 流，
  /// 所以挂一个 listener 按需轮询。这样也不需要额外的 Timer。
  void _onTick() {
    final player = _pool.activeOrNull;
    if (player == null || !player.value.isInitialized) return;
    final v = player.value;

    if (state.isPlaying != v.isPlaying) {
      state = state.copyWith(isPlaying: v.isPlaying);
      if (!v.isPlaying) _reportProgress(force: true); // 暂停立刻上报
    }
    if (state.position != v.position) {
      state = state.copyWith(position: v.position);
    }
    if (state.duration != v.duration) {
      state = state.copyWith(duration: v.duration);
    }
  }

  /// 下一条（下滑）
  Future<void> playNext() async {
    _reportProgress(force: true);
    await _playCurrent();
  }

  /// 上一条（上调，会话栈回退）
  Future<void> playPrevious() async {
    final previous = _bag.previous();
    if (previous == null) return;
    final progress = await _repo.progress(previous.id);
    await _open(previous, startAt: Duration(milliseconds: (progress.positionSec * 1000).round()));
  }

  void togglePlay() {
    final player = _pool.activeOrNull;
    if (player == null) return;
    if (state.isPlaying) {
      unawaited(player.pause());
    } else {
      unawaited(player.play());
    }
  }

  Future<void> seekTo(Duration position) async {
    final player = _pool.activeOrNull;
    if (player == null) return;
    await player.seekTo(position);
    state = state.copyWith(position: position);
    _reportProgress(force: true);
  }

  /// 倍速：0.5 / 1.0 / 1.25 / 1.5 / 2.0（PRD F-10）
  Future<void> setSpeed(double speed) async {
    final player = _pool.activeOrNull;
    if (player != null) {
      await player.setPlaybackSpeed(speed);
    }
    state = state.copyWith(speed: speed);
    await _prefs.setSpeed(speed);
  }

  VideoPlayerController get player => _pool.active;

  // ===== 进度上报（时间 + 事件双触发，架构 §4.4）=====

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(Constants.progressReportInterval, (_) {
      _reportProgress();
    });
  }

  void _reportProgress({bool force = false}) {
    final current = state.current;
    if (current == null || state.duration <= Duration.zero) return;

    final now = DateTime.now();
    if (!force && now.difference(_lastReportAt) < Constants.progressThrottle) return;
    _lastReportAt = now;

    final positionSec = state.position.inMilliseconds / 1000.0;
    final durationSec = state.duration.inMilliseconds / 1000.0;

    unawaited(_repo.reportProgress(
      current.videoId,
      positionSec: positionSec,
      durationSec: durationSec,
    ));
  }

  /// UI 明确触发（拖动结束、切走、退后台）
  void reportProgressNow() => _reportProgress(force: true);

  @override
  void dispose() {
    _progressTimer?.cancel();
    _pool.activeOrNull?.removeListener(_onTick);
    unawaited(_pool.releaseAll());
    super.dispose();
  }
}

final playbackControllerProvider =
    StateNotifierProvider<PlaybackController, PlaybackState>((ref) {
  return PlaybackController(
    ref.watch(videoRepositoryProvider),
    ref.watch(preferencesProvider),
  );
});