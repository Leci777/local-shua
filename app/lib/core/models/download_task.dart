/// 下载状态。
enum DownloadStatus { queued, running, paused, done, failed }

/// 下载任务。本地表（sqflite downloads）的一行；断点续传靠 receivedBytes。
class DownloadTask {
  final int videoId;
  final String fileName;
  final String filePath;
  final int totalBytes;
  final int receivedBytes;
  final DownloadStatus status;
  final String? errorText;

  const DownloadTask({
    required this.videoId,
    required this.fileName,
    required this.filePath,
    required this.totalBytes,
    required this.receivedBytes,
    required this.status,
    this.errorText,
  });

  DownloadTask copyWith({
    int? totalBytes,
    int? receivedBytes,
    DownloadStatus? status,
    String? errorText,
  }) =>
      DownloadTask(
        videoId: videoId,
        fileName: fileName,
        filePath: filePath,
        totalBytes: totalBytes ?? this.totalBytes,
        receivedBytes: receivedBytes ?? this.receivedBytes,
        status: status ?? this.status,
        errorText: errorText ?? this.errorText,
      );

  /// 进度 0~1；totalBytes 未知（服务端没给 Content-Length）时返回 null
  double? get progress =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : null;

  Map<String, dynamic> toRow() => {
        'video_id': videoId,
        'file_name': fileName,
        'file_path': filePath,
        'total_bytes': totalBytes,
        'received_bytes': receivedBytes,
        'status': status.name,
        'error_text': errorText,
      };

  factory DownloadTask.fromRow(Map<String, Object?> row) => DownloadTask(
        videoId: row['video_id'] as int,
        fileName: row['file_name'] as String,
        filePath: row['file_path'] as String,
        totalBytes: row['total_bytes'] as int,
        receivedBytes: row['received_bytes'] as int,
        status: DownloadStatus.values.firstWhere(
          (s) => s.name == row['status'],
          orElse: () => DownloadStatus.queued,
        ),
        errorText: row['error_text'] as String?,
      );
}
