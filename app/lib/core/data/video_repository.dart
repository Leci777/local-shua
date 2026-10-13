import '../models/playback_progress.dart';
import '../models/video.dart';
import '../network/api_client.dart';

/// 视频仓库：列表、随机、流地址、进度。
/// 进度上报失败一律静默——下一次上报会覆盖，不弹错不重试（架构 §4.4）。
class VideoRepository {
  const VideoRepository(this._api);

  final ApiClient _api;

  Future<List<Video>> list({int limit = 20, String? cursor, int? folderId}) =>
      _api.getVideos(limit: limit, cursor: cursor, folderId: folderId);

  Future<({List<Video> items, int poolSize})> random({
    int limit = 20,
    List<int> folderIds = const [],
    List<int> exclude = const [],
  }) =>
      _api.getRandomVideos(limit: limit, folderIds: folderIds, exclude: exclude);

  String streamUrl(int videoId) => _api.streamUrl(videoId);

  Future<PlaybackProgress> progress(int videoId) => _api.getProgress(videoId);

  Future<void> reportProgress(
    int videoId, {
    required double positionSec,
    required double durationSec,
    bool? completed,
  }) async {
    try {
      await _api.putProgress(
        videoId,
        positionSec: positionSec,
        durationSec: durationSec,
        completed: completed,
      );
    } catch (_) {
      // 静默：离线或服务重启时进度丢了无所谓，下次上报补上
    }
  }
}
