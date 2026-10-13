using System.Text.Json;
using PcVideo.Server.Data.Entities;

namespace PcVideo.Server.Endpoints;

/// <summary>
/// 错误响应统一格式 {code, message}——message 是小白口吻中文（架构 §4.1/§4.3）。
/// 新增错误码必须同步更新这里引用的 §4.3 表和 App 端 api_exception.dart，两处不一致即 bug。
/// </summary>
public static class ApiErrors
{
    public static IResult Fail(int statusCode, string code, string message) =>
        Results.Json(new { code, message }, statusCode: statusCode);
}

/// <summary>视频 DTO，与架构 §4.2 定稿一致。folderName 由调用方带上。</summary>
public record VideoDto(
    int Id,
    int FolderId,
    string FolderName,
    string FileName,
    long FileSize,
    double? DurationSec,
    int? Width,
    int? Height,
    string? VideoCodec,
    string? AudioCodec,
    int? BitrateKbps,
    bool Unplayable,
    string AddedAt);

public static class VideoDtoMapper
{
    public static VideoDto ToDto(VideoEntity v, string folderName) => new(
        v.Id, v.FolderId, folderName, v.FileName, v.FileSize,
        v.DurationSec, v.Width, v.Height, v.VideoCodec, v.AudioCodec,
        v.BitrateKbps, v.Unplayable, v.AddedAt);
}

/// <summary>
/// keyset 游标编解码。videos 用裸 id；history/favorites 用「排序键|id」复合游标，
/// 排序键倒序翻页时把上一页最后一条的排序键原样带回（架构 §4.1）。
/// </summary>
public static class Cursor
{
    public static string Encode(string sortKey, int id) => $"{sortKey}|{id}";

    /// <summary>解析失败返回 (null, null)，调用方按「从第一页开始」处理。</summary>
    public static (string? SortKey, int? Id) Decode(string? cursor)
    {
        if (string.IsNullOrWhiteSpace(cursor)) return (null, null);
        var separatorIndex = cursor.LastIndexOf('|');
        if (separatorIndex <= 0) return (null, null);
        var sortKey = cursor[..separatorIndex];
        if (int.TryParse(cursor[(separatorIndex + 1)..], out var id)) return (sortKey, id);
        return (null, null);
    }
}
