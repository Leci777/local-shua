namespace PcVideo.Server.Data.Entities;

/// <summary>用户添加的视频文件夹。enabled=0 的视频不进随机池。</summary>
public class FolderEntity
{
    public int Id { get; set; }
    /// <summary>文件夹绝对路径，唯一。Windows 下统一大写盘符后比较，避免大小写重复添加。</summary>
    public string Path { get; set; } = string.Empty;
    /// <summary>显示名，空则取目录名。</summary>
    public string Name { get; set; } = string.Empty;
    /// <summary>1=参与随机播放，0=停用。</summary>
    public bool Enabled { get; set; } = true;
    /// <summary>冗余统计：入库视频数（含 unplayable，不含 missing）。</summary>
    public int VideoCount { get; set; }
    /// <summary>冗余统计：其中标记「可能无法播放」的数量。</summary>
    public int UnplayableCount { get; set; }
    /// <summary>最近一次扫描完成时间，ISO 8601 UTC；没扫过为 null。</summary>
    public string? LastScanAt { get; set; }
    public string CreatedAt { get; set; } = string.Empty;

    public List<VideoEntity> Videos { get; set; } = new();
}
