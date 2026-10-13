import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/folder.dart';
import '../../core/theme.dart';
import '../../router/providers.dart';

/// 文件夹管理页（UI-DESIGN §4.5）：手机端只读 + 启停开关。
/// 增删去电脑 Web 页（架构 §4.5 差异 5 定稿）。
class FoldersPage extends ConsumerWidget {
  const FoldersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(folderListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('文件夹')),
      body: Column(
        children: [
          // 顶部提示：增删去电脑
          Container(
            width: double.infinity,
            color: AppTheme.surfaceContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.computer, size: 18, color: AppTheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '加新文件夹、删文件夹，去电脑上的管理页面操作。这里只能开关「要不要刷」。',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: folders.when(
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
                    icon: Icons.folder_open,
                    text: '还没有文件夹。去电脑上打开管理页面，添加文件夹，再点「扫描」。',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(folderListProvider),
                  child: ListView.builder(
                    itemCount: items.length,
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (context, index) => _FolderCard(folder: items[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

final folderListProvider = FutureProvider<List<Folder>>(
  (ref) => ref.watch(folderRepositoryProvider).list(),
);

class _FolderCard extends ConsumerWidget {
  const _FolderCard({required this.folder});

  final Folder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Opacity(
      opacity: folder.enabled ? 1 : 0.6,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(folder.name, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Switch(
                    value: folder.enabled,
                    onChanged: (value) async {
                      await ref.read(folderRepositoryProvider).setEnabled(folder.id, value);
                      ref.invalidate(folderListProvider);
                    },
                  ),
                ],
              ),
              Text(
                folder.path,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${folder.videoCount} 个视频',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  if (folder.unplayableCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${folder.unplayableCount} 个可能无法播放',
                        style: const TextStyle(fontSize: 11, color: AppTheme.primary),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
