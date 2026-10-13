import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'feed_controller.dart';

/// 信息流首页（UI-DESIGN §4.1）：全屏竖屏、上下滑切换、点击显隐控制层。
/// 播放器表面是占位（media_kit 在 W2-04 接入），先打通滑动手感和数据流。
class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  final _pageController = PageController();
  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();
    // 首帧：拉第一袋随机视频
    Future.microtask(() => ref.read(feedControllerProvider.notifier).start());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    final controller = ref.read(feedControllerProvider.notifier);
    // PageView 往上滑（手指往上，看到下一页）= index 增大 = 下一个随机视频
    // 具体方向由 controller 决定，这里只做「切了就更新」
    controller.playNext();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feedControllerProvider);

    return Scaffold(
      body: Stack(
        children: [
          // ===== 视频区（占位）=====
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            onPageChanged: _onPageChanged,
            itemCount: state.poolSize == 0 ? 1 : 100, // 占位：先允许滑动触发拉取
            itemBuilder: (context, index) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _controlsVisible = !_controlsVisible),
                child: Container(
                  color: AppTheme.surface,
                  alignment: Alignment.center,
                  child: state.loading
                      ? const CircularProgressIndicator()
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_circle_outline,
                                size: 64, color: AppTheme.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text(
                              state.current?.fileName ?? '还没有视频',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              state.current?.folderName ?? '去电脑管理页添加文件夹',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                ),
              );
            },
          ),

          // ===== 控制层（点击显隐，3 秒自动淡出）=====
          if (_controlsVisible && state.current != null)
            VideoOverlay(
              video: state.current!,
              onPlayNext: () => _pageController.nextPage(
                duration: AppTheme.motionStandard,
                curve: AppTheme.easeStandard,
              ),
            ),

          // ===== 掉线横幅（F-20）=====
          if (state.offline)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: _OfflineBanner(
                onRetry: () => ref.read(feedControllerProvider.notifier).retry(),
              ),
            ),

          // ===== 左上角功能菜单入口 =====
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.menu, color: AppTheme.onSurface),
              onPressed: () => _openMenu(context),
            ),
          ),
        ],
      ),
    );
  }

  void _openMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('播放历史'),
              onTap: () => Navigator.pushNamed(context, '/history'),
            ),
            ListTile(
              leading: const Icon(Icons.star),
              title: const Text('收藏'),
              onTap: () => Navigator.pushNamed(context, '/favorites'),
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('文件夹'),
              onTap: () => Navigator.pushNamed(context, '/folders'),
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('下载管理'),
              onTap: () => Navigator.pushNamed(context, '/downloads'),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('设置'),
              onTap: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 掉线横幅：出了什么事 + 该干嘛 + 重试
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: AppTheme.error, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('电脑那边没响应了，看看是不是睡了', style: TextStyle(fontSize: 14)),
          ),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
