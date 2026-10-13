import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/logger.dart';

/// UDP 发现：向局域网广播问一句「有没有本地刷服务」，服务端回 {name, port}。
/// 只是省得手输 IP 的辅助手段——部分路由器/ColorOS 禁广播，失败就手动输（架构 §3.8）。
class DiscoveryService {
  DiscoveryService();

  /// 返回发现的地址列表（形如 http://192.168.1.23:57821）。
  /// 广播没人应答时返回空列表，不抛异常。
  Future<List<String>> discover({Duration timeout = const Duration(seconds: 2)}) async {
    final results = <String>{};
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final completer = Completer<List<String>>();
      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket?.receive();
          if (datagram != null) {
            try {
              final json = jsonDecode(utf8.decode(datagram.data));
              final port = json['port'] as int?;
              if (port != null) {
                results.add('http://${datagram.address.address}:$port');
              }
            } catch (e) {
              dLog('发现应答解析失败：$e');
            }
          }
        }
      });

      // 问两遍，提高送达率（UDP 不可靠）
      for (var i = 0; i < 2; i++) {
        socket.send(const [0x50, 0x43], InternetAddress('255.255.255.255'), Constants.discoveryPort);
        await Future.delayed(const Duration(milliseconds: 300));
      }

      Timer(timeout, () {
        if (!completer.isCompleted) completer.complete(results.toList());
      });
      return await completer.future;
    } catch (e) {
      dLog('UDP 发现失败：$e');
      return results.toList();
    } finally {
      socket?.close();
    }
  }
}

final discoveryServiceProvider = Provider<DiscoveryService>((ref) => DiscoveryService());
