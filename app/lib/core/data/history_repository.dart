import '../models/video.dart';
import '../network/api_client.dart';

/// 播放历史 = 服务端进度表按时间倒序（架构 §6）。
class HistoryRepository {
  const HistoryRepository(this._api);

  final ApiClient _api;

  Future<List<({Video video, double positionSec, bool completed, String lastPlayedAt})>> list({
    int limit = 50,
    String? cursor,
  }) async {
    final items = await _api.getHistory(limit: limit, cursor: cursor);
    return items
        .map((e) => (
              video: e.video,
              positionSec: e.progress.positionSec,
              completed: e.progress.completed,
              lastPlayedAt: e.lastPlayedAt,
            ))
        .toList();
  }

  Future<void> remove(int videoId) => _api.deleteHistoryItem(videoId);

  Future<void> clear() => _api.clearHistory();
}
