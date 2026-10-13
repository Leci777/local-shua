import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../router/providers.dart';

/// 连接/配对页（UI-DESIGN §4.2）。
/// 地址输入 + 6 位配对码 + 失败时的三项检查引导卡。
class ConnectPage extends ConsumerStatefulWidget {
  const ConnectPage({super.key});

  @override
  ConsumerState<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends ConsumerState<ConnectPage> {
  final _addressController = TextEditingController();
  final _codeController = TextEditingController();
  bool _connecting = false;
  String? _errorText;
  bool _checkedOfflineGuide = false;

  @override
  void initState() {
    super.initState();
    // 回填上次的地址，省得每次重输
    final saved = ref.read(preferencesProvider).baseUrl;
    if (saved != null) _addressController.text = saved;
  }

  @override
  void dispose() {
    _addressController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final address = _addressController.text.trim();
    final code = _codeController.text.trim();
    if (address.isEmpty || code.isEmpty) {
      setState(() => _errorText = '地址和配对码都要填');
      return;
    }

    setState(() {
      _connecting = true;
      _errorText = null;
    });

    final prefs = ref.read(preferencesProvider);
    final api = ref.read(apiClientProvider);
    api.setBaseUrl(address);

    try {
      final token = await api.pair(code, '一加 Ace 6');
      await prefs.setToken(token);
      await prefs.setBaseUrl(address);
      if (!mounted) return;
      // 配对成功，去信息流
      Navigator.of(context).pushReplacementNamed('/feed');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _errorText = e.toString();
        _checkedOfflineGuide = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Text('连一下你的电脑', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                '电脑和手机要连同一个 WiFi。打开电脑上的「本地刷服务」，'
                '把屏幕上显示的地址和配对码填进来。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: '电脑地址',
                  hintText: 'http://192.168.x.x:57821',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: '配对码',
                  hintText: '6 位数字',
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(_errorText!, style: const TextStyle(color: AppTheme.error, fontSize: 13)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _connecting ? null : _connect,
                child: Text(_connecting ? '连接中…' : '连接'),
              ),
              if (_checkedOfflineGuide) ...[
                const SizedBox(height: 24),
                _OfflineGuideCard(),
              ],
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

/// 连不上时的三项检查引导（UI-DESIGN §4.2 / PRD F-20）
class _OfflineGuideCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi_off, color: AppTheme.onSurfaceVariant, size: 20),
              const SizedBox(width: 8),
              Text('连不上电脑。挨个看看：', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '① 电脑开机了吗？\n② 电脑上的「本地刷服务」启动了吗？\n③ 手机和电脑连的是同一个 WiFi 吗？',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
