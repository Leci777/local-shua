import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/video.dart';
import '../../core/theme.dart';
import '../../router/providers.dart';

/// 播放历史页（UI-DESIGN §4.3）：倒序、带进度、可删除。
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('播放历史'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空',
            onPressed: () async {
              final ok = await _confirmClear(context);
              if (!ok) return;
              await ref.read(historyRepositoryProvider).clear();
              ref.invalidate(historyListProvider);
            },
          ),
        ],
      ),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e', style: const TextStyle(color: AppTheme.error)),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyState(
              icon: Icons.history,
              text: '还没看过片。回到首页刷几下，这里就有记录了。',
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = items[index];
              return Dismissible(
                key: ValueKey(entry.video.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: AppTheme.error,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) async {
                  await ref.read(historyRepositoryProvider).remove(entry.video.id);
                  ref.invalidate(historyListProvider);
                },
                child: _HistoryTile(
                  video: entry.video,
                  positionSec: entry.positionSec,
                  completed: entry.completed,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<bool> _confirmClear(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空历史？'),
        content: const Text('所有播放记录都会删掉，收藏不受影响。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

final historyListProvider = FutureProvider<List<({Video video, double positionSec, bool completed, String lastPlayedAt})>>(
  (ref) => ref.watch(historyRepositoryProvider).list(),
);

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.video,
    required this.positionSec,
    required this.completed,
  });

  final Video video;
  final double positionSec;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final duration = video.durationSec ?? 0;
    // clamp 返回 num，这里统一转 double，LinearProgressIndicator 只收 double
    final progress = duration > 0 && !completed
        ? (positionSec / duration).clamp(0.0, 1.0).toDouble()
        : (completed ? 1.0 : 0.0);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 80,
        height: 56,
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.play_circle_outline, color: AppTheme.onSurfaceVariant),
      ),
      title: Text(video.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: AppTheme.outlineVariant,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                completed ? '看完了' : '看到 ${_format(positionSec)} / ${_format(duration)}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              if (completed) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('看完', style: TextStyle(fontSize: 11, color: AppTheme.primary)),
                ),
              ],
            ],
          ),
        ],
      ),
      onTap: () {
        // TODO(W3-01): 点击进信息流并从进度处续播
      },
    );
  }

  static String _format(double seconds) {
    if (seconds <= 0) return '--:--';
    final total = seconds.round();
    final minutes = total ~/ 60;
    final secs = total % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: AppTheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(text, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
