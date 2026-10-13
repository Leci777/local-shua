/// 文件夹。enabled=false 的视频不进随机池（PRD F-04）。
class Folder {
  final int id;
  final String name;
  final String path;
  final bool enabled;
  final int videoCount;
  final int unplayableCount;
  final int missingCount;
  final String? lastScanAt;
  final String createdAt;

  const Folder({
    required this.id,
    required this.name,
    required this.path,
    required this.enabled,
    required this.videoCount,
    required this.unplayableCount,
    required this.missingCount,
    this.lastScanAt,
    required this.createdAt,
  });

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        path: json['path'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
        videoCount: json['videoCount'] as int? ?? 0,
        unplayableCount: json['unplayableCount'] as int? ?? 0,
        missingCount: json['missingCount'] as int? ?? 0,
        lastScanAt: json['lastScanAt'] as String?,
        createdAt: json['createdAt'] as String? ?? '',
      );
}
