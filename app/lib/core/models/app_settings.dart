/// 设置。字段与 GET /api/settings 一致；数字/布尔原样存 JSON，
/// 所以这里直接用对应类型，不搞字符串中转。
class AppSettings {
  final String serverName;
  final double defaultSpeed;
  final bool autoPlayNext;
  final int recentExcludeCount;
  final int longVideoThresholdSec;
  final int downloadLimitGb;

  const AppSettings({
    required this.serverName,
    required this.defaultSpeed,
    required this.autoPlayNext,
    required this.recentExcludeCount,
    required this.longVideoThresholdSec,
    required this.downloadLimitGb,
  });

  static const AppSettings defaults = AppSettings(
    serverName: '我的电脑',
    defaultSpeed: 1.0,
    autoPlayNext: true,
    recentExcludeCount: 10,
    longVideoThresholdSec: 1800,
    downloadLimitGb: 10,
  );

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        serverName: json['serverName'] as String? ?? defaults.serverName,
        defaultSpeed: (json['defaultSpeed'] as num?)?.toDouble() ?? defaults.defaultSpeed,
        autoPlayNext: json['autoPlayNext'] as bool? ?? defaults.autoPlayNext,
        recentExcludeCount: json['recentExcludeCount'] as int? ?? defaults.recentExcludeCount,
        longVideoThresholdSec: json['longVideoThresholdSec'] as int? ?? defaults.longVideoThresholdSec,
        downloadLimitGb: json['downloadLimitGb'] as int? ?? defaults.downloadLimitGb,
      );

  Map<String, dynamic> toPatch() => {
        'serverName': serverName,
        'defaultSpeed': defaultSpeed,
        'autoPlayNext': autoPlayNext,
        'recentExcludeCount': recentExcludeCount,
        'longVideoThresholdSec': longVideoThresholdSec,
        'downloadLimitGb': downloadLimitGb,
      };
}
