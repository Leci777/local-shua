import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../router/providers.dart';

/// 设置页（UI-DESIGN §4.7）：服务器信息、播放默认、缓存、电池引导、关于。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          _SectionTitle('服务器'),
          ListTile(
            leading: const Icon(Icons.computer),
            title: Text(prefs.serverName ?? '我的电脑'),
            subtitle: Text(prefs.baseUrl ?? '未连接'),
            trailing: TextButton(
              onPressed: () async {
                await prefs.clearConnection();
                if (!context.mounted) return;
                Navigator.of(context).pushReplacementNamed('/connect');
              },
              child: const Text('重新配对'),
            ),
          ),
          const Divider(height: 1),
          _SectionTitle('播放'),
          SwitchListTile(
            secondary: const Icon(Icons.playlist_play),
            title: const Text('自动连播'),
            subtitle: const Text('一个视频看完自动播下一个'),
            value: prefs.autoPlayNext,
            onChanged: (value) => prefs.setAutoPlayNext(value),
          ),
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('默认倍速'),
            subtitle: Text('${prefs.speed.toStringAsFixed(2)}x'),
            onTap: () => _pickSpeed(context, ref),
          ),
          const Divider(height: 1),
          _SectionTitle('下载'),
          ListTile(
            leading: const Icon(Icons.sd_storage),
            title: const Text('缓存上限'),
            subtitle: Text('${prefs.downloadLimitGb} GB'),
            onTap: () => _pickLimit(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services),
            title: const Text('清理缓存'),
            subtitle: const Text('删掉手机本地的下载视频'),
            onTap: () {
              // TODO(W4-02): 接入下载管理器的清理
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('清理功能还没做，等下载管理上线')),
              );
            },
          ),
          const Divider(height: 1),
          _SectionTitle('其他'),
          ListTile(
            leading: const Icon(Icons.battery_saver),
            title: const Text('怎么让锁屏不断播'),
            subtitle: const Text('ColorOS 电池优化的设置引导'),
            onTap: () {
              // TODO(W3-04): 电池优化引导页
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('引导页还没做，先手动把「本地刷」加进电池白名单')),
              );
            },
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('关于'),
            subtitle: Text('本地刷 1.0.0 · 个人自用'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _pickSpeed(BuildContext context, WidgetRef ref) async {
    final current = ref.read(preferencesProvider).speed;
    final picked = await showDialog<double>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('默认倍速'),
        children: [0.5, 1.0, 1.25, 1.5, 2.0].map((speed) {
          return RadioListTile<double>(
            value: speed,
            groupValue: current,
            title: Text('${speed}x'),
            onChanged: (value) => Navigator.pop(context, value),
          );
        }).toList(),
      ),
    );
    if (picked != null) {
      await ref.read(preferencesProvider).setSpeed(picked);
    }
  }

  Future<void> _pickLimit(BuildContext context, WidgetRef ref) async {
    final current = ref.read(preferencesProvider).downloadLimitGb;
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('缓存上限'),
        children: [5, 10, 20, 50, 100].map((gb) {
          return RadioListTile<int>(
            value: gb,
            groupValue: current,
            title: Text('$gb GB'),
            onChanged: (value) => Navigator.pop(context, value),
          );
        }).toList(),
      ),
    );
    if (picked != null) {
      await ref.read(preferencesProvider).setDownloadLimitGb(picked);
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.secondary),
      ),
    );
  }
}
