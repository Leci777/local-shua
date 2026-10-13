using Microsoft.EntityFrameworkCore;
using PcVideo.Server.Data;

namespace PcVideo.Server.Services;

/// <summary>
/// 视频流式响应。播放与下载走同一接口：播放是顺序 Range 读，下载是客户端算偏移的 Range 读，
/// 服务端零区分、零新增接口（PRD §2.4）。
/// </summary>
public class VideoStreamService
{
    private readonly PcVideoDbContext _db;

    // Content-Type 按扩展名映射。libmpv 会自行嗅探真实格式，这个值主要给 curl/浏览器用
    private static readonly Dictionary<string, string> ContentTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        [".mp4"] = "video/mp4",
        [".m4v"] = "video/mp4",
        [".mkv"] = "video/x-matroska",
        [".webm"] = "video/webm",
        [".flv"] = "video/x-flv",
        [".avi"] = "video/x-msvideo",
        [".ts"] = "video/mp2t",
        [".wmv"] = "video/x-ms-wmv",
        [".mov"] = "video/quicktime",
        [".rmvb"] = "application/vnd.rn-realmedia-vbr",
        [".mpg"] = "video/mpeg",
        [".mpeg"] = "video/mpeg",
        [".3gp"] = "video/3gpp",
    };

    public VideoStreamService(PcVideoDbContext db)
    {
        _db = db;
    }

    public async Task<Data.Entities.VideoEntity?> GetByIdAsync(int id) =>
        await _db.Videos.AsNoTracking().FirstOrDefaultAsync(v => v.Id == id);

    public static string ContentTypeFor(string filePath)
    {
        var ext = Path.GetExtension(filePath);
        return ContentTypes.TryGetValue(ext, out var ct) ? ct : "application/octet-stream";
    }

    /// <summary>
    /// 打开文件流。用 FileShare.Read：播放和下载可以同时进行，
    /// 用户用别的播放器打开同一文件也不会被我们挡住（架构 §2.4）。
    /// 返回 null 表示磁盘上文件没了（调用方回 404 file_missing）。
    /// </summary>
    public FileStream? OpenRead(string filePath)
    {
        var normalized = PathUtil.NormalizeLongPath(filePath);
        try
        {
            return new FileStream(normalized, FileMode.Open, FileAccess.Read, FileShare.Read);
        }
        catch (Exception)
        {
            return null;
        }
    }
}
