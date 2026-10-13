/// 播放进度。播放历史页 = 进度表按时间倒序，所以两者共用这个模型。
class PlaybackProgress {
  final double positionSec;
  final double durationSec;
  final bool completed;

  const PlaybackProgress({
    required this.positionSec,
    required this.durationSec,
    required this.completed,
  });

  factory PlaybackProgress.fromJson(Map<String, dynamic> json) => PlaybackProgress(
        positionSec: (json['positionSec'] as num?)?.toDouble() ?? 0,
        durationSec: (json['durationSec'] as num?)?.toDouble() ?? 0,
        completed: json['completed'] as bool? ?? false,
      );
}
