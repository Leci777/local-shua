namespace PcVideo.Server.Data.Entities;

/// <summary>扫描入库的视频文件。ffprobe 读不到的字段留 null。</summary>
public class VideoEntity
{
    public int Id { get; set; }
    public int FolderId { get; set; }
    /// <summary>文件绝对路径，唯一。超过 260 字符的加 \\?\ 前缀归一化后存储。</summary>
    public string FilePath { get; set; } = string.Empty;
    public string FileName { get; set; } = string.Empty;
    /// <summary>字节数。</summary>
    public long FileSize { get; set; }
    /// <summary>秒，ffprobe 取不到为 null。</summary>
    public double? DurationSec { get; set; }
    public int? Width { get; set; }
    public int? Height { get; set; }
    public string? VideoCodec { get; set; }
    public string? AudioCodec { get; set; }
    public int? BitrateKbps { get; set; }
    /// <summary>容器格式，扩展名小写（含点），如 .mkv。</summary>
    public string Container { get; set; } = string.Empty;
    /// <summary>1=ffprobe 解析失败，前端标「可能无法播放」。</summary>
    public bool Unplayable { get; set; }
    /// <summary>1=磁盘上暂时找不到（外接盘离线）。missing 的视频不进随机池、不进默认列表，重新扫到文件后自动清标记。</summary>
    public bool Missing { get; set; }
    public string AddedAt { get; set; } = string.Empty;
    public string UpdatedAt { get; set; } = string.Empty;

    public FolderEntity? Folder { get; set; }
    public PlaybackProgressEntity? Progress { get; set; }
}
