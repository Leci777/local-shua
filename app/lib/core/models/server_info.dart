/// GET /api/server/info 的返回。
class ServerInfo {
  final String serverName;
  final String version;
  final int videoCount;
  final int folderCount;
  final int enabledFolderCount;

  const ServerInfo({
    required this.serverName,
    required this.version,
    required this.videoCount,
    required this.folderCount,
    required this.enabledFolderCount,
  });

  factory ServerInfo.fromJson(Map<String, dynamic> json) => ServerInfo(
        serverName: json['serverName'] as String? ?? '我的电脑',
        version: json['version'] as String? ?? '1.0.0',
        videoCount: json['videoCount'] as int? ?? 0,
        folderCount: json['folderCount'] as int? ?? 0,
        enabledFolderCount: json['enabledFolderCount'] as int? ?? 0,
      );
}
