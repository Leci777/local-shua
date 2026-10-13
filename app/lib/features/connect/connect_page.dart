import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme.dart';
import '../../router/providers.dart';

/// 连接页（UI-DESIGN §4.2，个人自用模式）。
/// 服务端默认不开鉴权（PcVideo:RequireToken=false），所以这里只要地址就能连；
/// 配对码留作可选——用户自己在 appsettings 里开了 RequireToken 才需要填。
class ConnectPage extends ConsumerStatefulWidget {
  const ConnectPage({super.key});

  @override
  ConsumerState<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends ConsumerState<ConnectPage> {
  final _addressController = TextEditingController();
  final _codeController = TextEditingController();
  bool _connecting = false;
  bool _needCode = false; // 服务端要求 token 时才显示配对码输入
  String? _errorText;

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

  /// 先探活再连：服务端能通就说明地址对、且大概率不需要配对码
  Future<void> _connect() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      setState(() => _errorText = '先把电脑地址填上');
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
      // 探活：公开接口，任何模式下都能通
      final info = await api.getServerInfo();
      await prefs.setBaseUrl(address);
      await prefs.setServerName(info.serverName);

      // 服务端若开了鉴权，列表接口会 401，这时才要配对码
      final code = _codeController.text.trim();
      if (code.isNotEmpty) {
        final token = await api.pair(code, '一加 Ace 6');
        await prefs.setToken(token);
      }

      if (!mounted) return;
      // 路由交给 go_router 管；MaterialApp.router 下用 Navigator.pushNamed 会直接抛异常
      context.go('/feed');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _errorText = e.message;
        // 401 说明服务端要 token → 露出配对码输入框
        if (e.code == 'token_invalid') _needCode = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _errorText = '连不上电脑。挨个看看：① 电脑开机了吗？② 服务启动了吗？③ 同一个 WiFi 吗？';
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
                '电脑和手机要连同一个 WiFi。地址在电脑托盘图标上能看到，'
                '形如 http://192.168.x.x:57821。',
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
                onSubmitted: (_) => _connect(),
              ),
              // 服务端默认不校验 token，只在它明确要 token 时才出现
              if (_needCode) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: '配对码',
                    hintText: '电脑屏幕上的 6 位数字',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
              ],
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  style: const TextStyle(color: AppTheme.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _connecting ? null : _connect,
                child: Text(_connecting ? '连接中…' : '连接'),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}