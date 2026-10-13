import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/favorite_repository.dart';
import '../../router/providers.dart';

/// 收藏 id 集合 + 切换。信息流星星按钮和收藏列表页共用。
class FavoriteIdsNotifier extends StateNotifier<Set<int>> {
  FavoriteIdsNotifier(this._repo) : super const <int>{};

  final FavoriteRepository _repo;

  /// 进 App 时拉一次已收藏的 id
  Future<void> load() async {
    try {
      final items = await _repo.list(limit: 200);
      state = items.map((e) => e.video.id).toSet();
    } catch (_) {
      // 拉不到不影响主流程，星星状态默认未收藏
    }
  }

  /// 切换收藏。失败回滚本地状态，不装成功。
  Future<void> toggle(int videoId, bool favorite) async {
    final previous = state;
    state = favorite ? {...state, videoId} : (state..remove(videoId));
    try {
      await _repo.set(videoId, favorite);
    } catch (_) {
      state = previous;
    }
  }
}

final favoriteIdsProvider =
    StateNotifierProvider<FavoriteIdsNotifier, Set<int>>((ref) {
  return FavoriteIdsNotifier(ref.watch(favoriteRepositoryProvider));
});
