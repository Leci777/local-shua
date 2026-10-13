import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../router/providers.dart';
import '../player/playback_controller.dart';
import '../player/video_surface.dart';

/// 信息流首页（UI-DESIGN §4.1）：全屏竖屏、上下滑切换、点击显隐控制层。
/// 一屏一个视频，全屏播放；下滑下一条、上调上一条。
class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  final _pageController = PageController();
  bool _controlsVisible = true;
  Timer? _hideTimer;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // 信息流页锁定竖屏（架构 §3.2）
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    Future.microtask(() {
      ref.read(playbackControllerProvider.notifier).start();
      _initialized = true;
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  /// 点屏幕：控制层显隐；显示后 3 秒自动淡出
  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controlsVisible) setState(() => _controlsVisible = false);
    });
  }

  /// 上滑（手指往上 → PageView index 增大）= 下一条
  void _onPageChanged(int index) {
    if (!_initialized || index == 0) return;
    unawaited(ref.read(playbackControllerProvider.notifier).playNext());
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playbackControllerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ===== 视频区 =====
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            onPageChanged: _onPageChanged,
            // 随机流没有确定长度；给个够滑的虚拟长度，滑到末尾回到中间
            itemCount: 1000,
            itemBuilder: (context, index) {
              // 只有当前页渲染播放器，其余页空壳（省内存）
              final isCurrent = index == _pageController.page?.round() ? true : index == 0;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControls,
                child: isCurrent && state.current != null
                    ? Stack(
                        children: [
                          Positioned.fill(child: VideoSurface(controller: controller)),
                          if (state.loading)
                            const Center(child: CircularProgressIndicator()),
                        ],
                      )
                    : const ColoredBox(color: Colors.black),
              );
            },
          ),

          // ===== 控制层 =====
          if (_controlsVisible && state.current != null)
            VideoOverlay(
              fileName: state.current!.fileName,
              folderName: state.folderName,
              videoId: state.current!.videoId,
              isPlaying: state.isPlaying,
              position: state.position,
              duration: state.duration,
              speed: state.speed,
              onPlayPause: controller.togglePlay,
              onSeek: (position) {
                unawaited(controller.seekTo(position));
              },
              onNext: () {
                _pageController.nextPage(
                  duration: AppTheme.motionStandard,
                  curve: AppTheme.easeStandard,
                );
              },
              onPrevious: () => unawaited(controller.playPrevious()),
              onSpeed: (value) => unawaited(controller.setSpeed(value)),
            ),

          // ===== 空态 / 错误 =====
          if (state.current == null && !state.loading)
            _FeedEmptyState(
              message: state.errorText ?? '还没有视频',
              onRetry: () => unawaited(controller.start()),
            ),

          // ===== 掉线横幅 =====
          if (_isOffline(state.errorText))
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: _OfflineBanner(onRetry: () => unawaited(controller.start())),
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

          // ===== 自动连播提示已内联到播放逻辑，这里放滑动提示（首次） =====
          if (_initialized && state.current == null && !state.loading && state.errorText == null)
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  bool _isOffline(String? error) =>
      error != null && (error.contains('连不上') || error.contains('超时') || error.contains('电脑'));

  void _openMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('播放历史'),
              // 路由交给 go_router 管；MaterialApp.router 下用 Navigator.pushNamed 会直接抛异常
              onTap: () {
                Navigator.pop(sheetContext);
                context.go('/history');
              },
            ),
            ListTile(
              leading: const Icon(Icons.star),
              title: const Text('收藏'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.go('/favorites');
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('文件夹'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.go('/folders');
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('下载管理'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.go('/downloads');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('设置'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.go('/settings');
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 空态：大图标 + 一句人话 + 重试
class _FeedEmptyState extends StatelessWidget {
  const _FeedEmptyState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.video_library_outlined, size: 56, color: AppTheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(message, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('重试')),
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