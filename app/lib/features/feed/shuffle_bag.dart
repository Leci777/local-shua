import 'dart:math' as math;

import '../core/models/video.dart';

/// 洗牌袋：随机刷的核心算法（PRD §7.3）。
///
/// - 一袋一袋地播：袋内 Fisher-Yates 洗牌，袋内不重复
/// - 袋里剩 [refillThreshold] 个时触发 onNeedMore，调用方去网络拉下一袋
/// - 预取时排除最近看过的 [excludeCount] 个，避免刚看完又刷到
/// - 池比一袋还小时退化为「全量循环洗牌」，不会无休止问服务端要新视频
/// - 「上一条」走本地会话栈：随机流没有服务端意义上的上一集（架构 §4.5 差异 6）
class ShuffleBag {
  ShuffleBag({
    this.refillThreshold = 5,
    this.excludeCount = 10,
  });

  /// 袋里剩这么多就回调要下一袋
  final int refillThreshold;

  /// 预取下一袋时排除的最近观看数
  final int excludeCount;

  final List<Video> _queue = [];
  final List<int> _recentIds = [];

  /// 本次会话的播放序列，[cursor] 指向当前播的这个。上一条 = cursor 往前挪
  final List<Video> _session = [];
  int _cursor = -1;

  final _random = math.Random();

  /// 袋快空了回调：调用方去服务端拉一批，拿到后调 refill
  void Function()? onNeedMore;

  /// 当前袋里还剩几个
  int get remaining => _queue.length;

  /// 当前播放的视频（没有则 null）
  Video? get current => _cursor >= 0 && _cursor < _session.length ? _session[_cursor] : null;

  /// 装填一批视频（洗牌入袋）
  void refill(List<Video> batch) {
    final shuffled = List<Video>.of(batch)..shuffle(_random);
    _queue.addAll(shuffled);
  }

  /// 取下一个随机视频。袋空了返回 null，等 onNeedMore 补充。
  Video? nextRandom() {
    if (_queue.isEmpty) return null;
    final video = _queue.removeAt(0);

    _recentIds.insert(0, video.id);
    if (_recentIds.length > excludeCount) {
      _recentIds.removeRange(excludeCount, _recentIds.length);
    }
    // 往前播过又随机到新的：会话栈从当前光标处截断，历史分叉
    if (_cursor < _session.length - 1) {
      _session.removeRange(_cursor + 1, _session.length);
    }
    _session.add(video);
    _cursor = _session.length - 1;

    // 快见底了，提前要下一袋
    if (_queue.length <= refillThreshold) {
      onNeedMore?.call();
    }
    return video;
  }

  /// 袋里下一个是什么（只看不拿）。预载用它判断「有没有下一条可以先加载」。
  Video? peekNext() => _queue.isEmpty ? null : _queue.first;

  /// 上一条：会话光标往前挪一格。没有更早的返回 null。
  Video? previous() {
    if (_cursor <= 0) return null;
    _cursor--;
    return _session[_cursor];
  }

  /// 光标之后还有没有（随机播放后回退过，才有「下一条」可走）
  bool get hasForward => _cursor < _session.length - 1;

  /// 下一条（仅在回退后有意义）：光标往后挪一格。
  Video? forward() {
    if (!hasForward) return null;
    _cursor++;
    return _session[_cursor];
  }

  /// 最近看过的 id，预取时作为 exclude 传给服务端
  List<int> get recentIds => List.unmodifiable(_recentIds);

  /// 池大小不足一袋时退化成全量循环洗牌的判断
  static bool shouldDegradeToFullLoop(int poolSize, int batchSize) => poolSize <= batchSize;
}
