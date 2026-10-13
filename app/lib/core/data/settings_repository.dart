import '../models/app_settings.dart';
import '../network/api_client.dart';

/// 设置仓库。服务端设置是「新设备/新会话默认」，客户端本地值优先（架构 §4.5 差异 8）。
class SettingsRepository {
  const SettingsRepository(this._api);

  final ApiClient _api;

  Future<AppSettings> get() => _api.getSettings();

  Future<AppSettings> save(AppSettings settings) => _api.putSettings(settings);
}
