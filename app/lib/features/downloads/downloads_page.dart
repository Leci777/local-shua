import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// 下载管理页（UI-DESIGN §4.6）。下载管理器是 W4-01 的事，先搭页面骨架。
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('下载管理'),
          bottom: const TabBar(
            tabs: [Tab(text: '下载中'), Tab(text: '已完成')],
            indicatorColor: AppTheme.primary,
          ),
        ),
        body: const TabBarView(
          children: [
            _EmptyState(
              icon: Icons.download_outlined,
              text: '想把视频存到手机？播放页点下载。',
            ),
            _EmptyState(
              icon: Icons.offline_pin_outlined,
              text: '下载完的视频没网也能播。',
            ),
          ],
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
