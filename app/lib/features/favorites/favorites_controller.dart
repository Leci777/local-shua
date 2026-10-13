import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/favorite_repository.dart';
import '../../router/providers.dart';

/// 收藏 id 集合 + 切换。信息流星星按钮和收藏列表页共用。
class FavoriteIdsNotifier extends StateNotifier<Set<int>> {
  // 初始空集合。用 <int>{} 而不是 const <int>{}——编译器在常量表达式里
  // 求值这个泛型字面量会报「返回类型 int 不允许 null」。
  // 这里本来也从不原地改它（toggle 每次都新建 Set），不需要 const。
  FavoriteIdsNotifier(this._repo) : super(<int>{});

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
    // 复制一份再改：直接 state..remove() 是原地改，Riverpod 靠比较引用决定要不要
    // 刷新界面，原地改界面不会重建，而且失败时也没法干净回滚。
    //
    // 注意括号：..add() 的优先级比 ?: 高，不括起来编译器会把三元表达式当级联的一部分解析。
    final next = Set<int>.of(state);
    if (favorite) {
      next.add(videoId);
    } else {
      next.remove(videoId);
    }
    state = next;
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
