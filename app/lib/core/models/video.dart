/// 视频。字段与电脑端 VideoDto 一一对应（架构 §4.2）。
class Video {
  final int id;
  final int folderId;
  final String folderName;
  final String fileName;
  final int fileSize;
  final double? durationSec;
  final int? width;
  final int? height;
  final String? videoCodec;
  final String? audioCodec;
  final int? bitrateKbps;
  final bool unplayable;
  final String addedAt;

  const Video({
    required this.id,
    required this.folderId,
    required this.folderName,
    required this.fileName,
    required this.fileSize,
    this.durationSec,
    this.width,
    this.height,
    this.videoCodec,
    this.audioCodec,
    this.bitrateKbps,
    this.unplayable = false,
    required this.addedAt,
  });

  factory Video.fromJson(Map<String, dynamic> json) => Video(
        id: json['id'] as int,
        folderId: json['folderId'] as int,
        folderName: json['folderName'] as String? ?? '',
        fileName: json['fileName'] as String,
        fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
        durationSec: (json['durationSec'] as num?)?.toDouble(),
        width: json['width'] as int?,
        height: json['height'] as int?,
        videoCodec: json['videoCodec'] as String?,
        audioCodec: json['audioCodec'] as String?,
        bitrateKbps: json['bitrateKbps'] as int?,
        unplayable: json['unplayable'] as bool? ?? false,
        addedAt: json['addedAt'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'folderId': folderId,
        'folderName': folderName,
        'fileName': fileName,
        'fileSize': fileSize,
        'durationSec': durationSec,
        'width': width,
        'height': height,
        'videoCodec': videoCodec,
        'audioCodec': audioCodec,
        'bitrateKbps': bitrateKbps,
        'unplayable': unplayable,
        'addedAt': addedAt,
      };
}
