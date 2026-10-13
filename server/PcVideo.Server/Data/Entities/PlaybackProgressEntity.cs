namespace PcVideo.Server.Data.Entities;

/// <summary>
/// 播放进度与播放历史共用一张表（历史页 = 本表按 LastPlayedAt 倒序投影）。
/// 服务端是进度/历史的唯一事实源；手机本地镜像只服务已下载视频的离线场景。
/// </summary>
public class PlaybackProgressEntity
{
    public int VideoId { get; set; }
    /// <summary>最近播放位置，秒。</summary>
    public double PositionSec { get; set; }
    /// <summary>上报时客户端给的时长，秒。</summary>
    public double DurationSec { get; set; }
    /// <summary>1=已看到 95% 以上。粘滞：只有收到 completed=false 且 position 不足一半才解除。</summary>
    public bool Completed { get; set; }
    /// <summary>上次播放时间，ISO 8601 UTC，历史排序键。</summary>
    public string LastPlayedAt { get; set; } = string.Empty;

    public VideoEntity? Video { get; set; }
}
