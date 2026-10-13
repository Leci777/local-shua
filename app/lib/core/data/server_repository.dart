import '../models/server_info.dart';
import '../network/api_client.dart';

/// 服务器仓库：探活 + 配对。
class ServerRepository {
  const ServerRepository(this._api);

  final ApiClient _api;

  Future<ServerInfo> info() => _api.getServerInfo();

  Future<String> pair(String code, String deviceName) => _api.pair(code, deviceName);

  /// 连接页探活用：不抛异常的 info 调用，失败返回 null
  Future<ServerInfo?> tryInfo() async {
    try {
      return await info();
    } catch (_) {
      return null;
    }
  }
}
