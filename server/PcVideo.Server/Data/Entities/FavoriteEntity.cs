namespace PcVideo.Server.Data.Entities;

/// <summary>收藏。「稍后再看」与收藏合并为一个概念，数据模型已预留，后续要区分再加字段。</summary>
public class FavoriteEntity
{
    public int VideoId { get; set; }
    /// <summary>收藏时间，ISO 8601 UTC。</summary>
    public string CreatedAt { get; set; } = string.Empty;

    public VideoEntity? Video { get; set; }
}
