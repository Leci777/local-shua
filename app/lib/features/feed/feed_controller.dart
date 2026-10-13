import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/data/video_repository.dart';
import '../../core/models/video.dart';
import '../../router/providers.dart';
import 'shuffle_bag.dart';

/// 信息流控制器：管洗牌袋、随机拉取、进度上报、掉线状态。
/// 播放内核（media_kit）是 W2-04 的事，先接网络和数据。
class FeedController extends StateNotifier<FeedState> {
  FeedController(this._videoRepo, this._prefs) : super(const FeedState()) {
    _bag.onNeedMore = _fetchMore;
  }

  final VideoRepository _videoRepo;
  final dynamic _prefs;

  final ShuffleBag _bag = ShuffleBag();

  FeedState get _current => state;

  /// 起播：先看本地有没有下载的文件，再决定走网络流（架构 §3.5）。
  /// 本地下载查询是 DownloadDb 的事，W4 接入；这里先走 streamUrl。

  Future<void> start() async {
    if (state.started) return;
    state = state.copyWith(started: true, loading: true);
    await _fetchMore(initial: true);
  }

  Future<void> _fetchMore({bool initial = false}) async {
    if (state.fetching) return;
    state = state.copyWith(fetching: true, errorText: null);
    try {
      final exclude = _bag.recentIds;
      final result = await _videoRepo.random(
        limit: Constants.randomBatchSize,
        exclude: exclude,
      );
      _bag.refill(result.items);
      state = state.copyWith(
        fetching: false,
        loading: false,
        poolSize: result.poolSize,
        offline: false,
      );
      // 池比一袋小：退化提示（全量循环洗牌，客户端自己扛重复）
      if (ShuffleBag.shouldDegradeToFullLoop(result.poolSize, Constants.randomBatchSize)) {
        state = state.copyWith(degraded: true);
      }
      if (initial) _playCurrent();
    } catch (e) {
      state = state.copyWith(
        fetching: false,
        loading: false,
        offline: true,
        errorText: e.toString(),
      );
    }
  }

  void _playCurrent() {
    final video = _bag.nextRandom();
    if (video == null) return;
    state = state.copyWith(current: video, remaining: _bag.remaining);
  }

  /// 下滑：下一个随机视频
  void playNext() {
    final video = _bag.nextRandom();
    if (video == null) {
      // 袋空了且没在拉取：手动催一次
      _fetchMore();
      return;
    }
    state = state.copyWith(current: video, remaining: _bag.remaining);
    _reportProgress();
  }

  /// 上滑：会话栈回退（架构 §4.5 差异 6）
  void playPrevious() {
    final video = _bag.previous();
    if (video != null) {
      state = state.copyWith(current: video, remaining: _bag.remaining);
    }
  }

  bool get hasPrevious => _bag.previous != null || true; // 由 UI 层调 previous 判空更直接

  /// 重试（掉线横幅用）
  Future<void> retry() => _fetchMore();

  /// 当前视频的流地址
  String streamUrlFor(Video video) => _videoRepo.streamUrl(video.id);

  void _reportProgress() {
    // 进度上报由播放器回调驱动（W2-04/W3-01），这里先埋钩子
  }
}

class FeedState {
  const FeedState({
    this.started = false,
    this.loading = false,
    this.fetching = false,
    this.current,
    this.remaining = 0,
    this.poolSize = 0,
    this.degraded = false,
    this.offline = false,
    this.errorText,
  });

  final bool started;
  final bool loading;
  final bool fetching;
  final Video? current;
  final int remaining;
  final int poolSize;
  final bool degraded;
  final bool offline;
  final String? errorText;

  FeedState copyWith({
    bool? started,
    bool? loading,
    bool? fetching,
    Video? current,
    int? remaining,
    int? poolSize,
    bool? degraded,
    bool? offline,
    String? errorText,
  }) =>
      FeedState(
        started: started ?? this.started,
        loading: loading ?? this.loading,
        fetching: fetching ?? this.fetching,
        current: current ?? this.current,
        remaining: remaining ?? this.remaining,
        poolSize: poolSize ?? this.poolSize,
        degraded: degraded ?? this.degraded,
        offline: offline ?? this.offline,
        errorText: errorText ?? this.errorText,
      );
}

final feedControllerProvider = StateNotifierProvider<FeedController, FeedState>((ref) {
  return FeedController(
    ref.watch(videoRepositoryProvider),
    ref.watch(preferencesProvider),
  );
});
