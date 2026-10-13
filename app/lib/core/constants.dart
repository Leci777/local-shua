/// 全 App 的默认值和魔法数字唯一来源。
/// 每个常量注释标了出处（PRD 条目号 / 架构章节），改之前先想想为什么是这个值。
class Constants {
  Constants._();

  // ===== 服务器 =====
  /// 默认端口，与 server/appsettings.json 的 Urls 一致
  static const int defaultPort = 57821;

  /// UDP 发现广播端口，与服务端 DiscoveryResponder 一致
  static const int discoveryPort = 57822;

  // ===== 播放 =====
  /// 进度上报定时触发间隔（架构 §4.4 双触发设计的时间触发）
  static const Duration progressReportInterval = Duration(seconds: 10);

  /// 同一视频两次上报最小间隔，防止暂停瞬间的补报把服务端刷爆
  static const Duration progressThrottle = Duration(seconds: 2);

  /// 看到这个比例算看完（PRD F-08）
  static const double completedThreshold = 0.95;

  /// 长视频提示阈值：时长超过它且上次有进度时，弹「继续看/重头看」（PRD F-08，架构 §4.2 settings.longVideoThresholdSec 默认值）
  static const int longVideoThresholdSec = 1800;

  /// 随机一袋的数量（架构 §3.5 洗牌袋）
  static const int randomBatchSize = 20;

  /// 袋里剩这么多就静默预取下一袋
  static const int shuffleRefillThreshold = 5;

  /// 随机时排除最近看过的个数（settings.recentExcludeCount 默认值）
  static const int recentExcludeCount = 10;

  // ===== 下载 =====
  /// 下载并发（架构 §3.7）
  static const int downloadConcurrency = 2;

  /// 缓存默认上限 GB（PRD A7，设置页可改）
  static const int defaultDownloadLimitGb = 10;

  // ===== 网络 =====
  static const Duration connectTimeout = Duration(seconds: 5);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ===== 偏好设置键（统一 pcvideo. 前缀，架构 §8.5）=====
  static const String keyBaseUrl = 'pcvideo.base_url';
  static const String keyToken = 'pcvideo.token';
  static const String keyServerName = 'pcvideo.server_name';
  static const String keySpeed = 'pcvideo.speed';
  static const String keyAutoPlayNext = 'pcvideo.auto_play_next';
  static const String keyDownloadLimitGb = 'pcvideo.download_limit_gb';
  static const String keyRecentExcludeCount = 'pcvideo.recent_exclude_count';
  static const String keyLongThresholdSec = 'pcvideo.long_threshold_sec';
}
