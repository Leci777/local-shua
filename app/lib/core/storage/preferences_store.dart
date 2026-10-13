import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';

///  token / baseUrl / 播放设置 的 KV 存储。
/// 威胁模型是「同 WiFi 误连」，不放 Keystore（架构 §3.4/ADR-02）。
class PreferencesStore {
  PreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<PreferencesStore> open() async =>
      PreferencesStore(await SharedPreferences.getInstance());

  // ===== 连接 =====

  String? get baseUrl => _prefs.getString(Constants.keyBaseUrl);
  Future<void> setBaseUrl(String url) => _prefs.setString(Constants.keyBaseUrl, url);

  String? get token => _prefs.getString(Constants.keyToken);
  Future<void> setToken(String token) => _prefs.setString(Constants.keyToken, token);

  String? get serverName => _prefs.getString(Constants.keyServerName);
  Future<void> setServerName(String name) => _prefs.setString(Constants.keyServerName, name);

  /// 退出连接：清地址和 token，回连接页。
  /// 个人自用模式（服务端默认不校验 token）下，光清地址就够回到连接页
  Future<void> clearConnection() async {
    await _prefs.remove(Constants.keyToken);
    await _prefs.remove(Constants.keyBaseUrl);
    await _prefs.remove(Constants.keyServerName);
  }

  /// 有地址就能用（token 只在服务端开了鉴权时才必需）
  bool get isConnected => (baseUrl ?? '').isNotEmpty;

  // ===== 播放设置（客户端会话值优先，服务端设置为新设备默认，架构 §4.5 差异 8）=====

  double get speed => _prefs.getDouble(Constants.keySpeed) ?? 1.0;
  Future<void> setSpeed(double speed) => _prefs.setDouble(Constants.keySpeed, speed);

  bool get autoPlayNext => _prefs.getBool(Constants.keyAutoPlayNext) ?? true;
  Future<void> setAutoPlayNext(bool value) => _prefs.setBool(Constants.keyAutoPlayNext, value);

  int get downloadLimitGb => _prefs.getInt(Constants.keyDownloadLimitGb) ?? Constants.defaultDownloadLimitGb;
  Future<void> setDownloadLimitGb(int gb) => _prefs.setInt(Constants.keyDownloadLimitGb, gb);

  int get recentExcludeCount => _prefs.getInt(Constants.keyRecentExcludeCount) ?? Constants.recentExcludeCount;
  Future<void> setRecentExcludeCount(int count) => _prefs.setInt(Constants.keyRecentExcludeCount, count);

  int get longThresholdSec => _prefs.getInt(Constants.keyLongThresholdSec) ?? Constants.longVideoThresholdSec;
  Future<void> setLongThresholdSec(int sec) => _prefs.setInt(Constants.keyLongThresholdSec, sec);
}
