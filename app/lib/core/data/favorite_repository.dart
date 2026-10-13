import '../models/video.dart';
import '../network/api_client.dart';

/// 收藏。「稍后再看」与收藏合并为一个概念（PRD F-13）。
class FavoriteRepository {
  const FavoriteRepository(this._api);

  final ApiClient _api;

  Future<void> set(int videoId, bool isFavorite) =>
      _api.setFavorite(videoId, isFavorite);

  Future<List<({Video video, String favoritedAt})>> list({
    int limit = 50,
    String? cursor,
  }) =>
      _api.getFavorites(limit: limit, cursor: cursor);
}
