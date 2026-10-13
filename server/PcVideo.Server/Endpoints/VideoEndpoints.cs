using Microsoft.EntityFrameworkCore;
using PcVideo.Server.Data;
using PcVideo.Server.Services;

namespace PcVideo.Server.Endpoints;

/// <summary>
/// 视频列表 / 随机 / 流式 / 进度。随机池 = 启用文件夹并集（架构 §4.5 差异 1/7 定稿）。
/// </summary>
public static class VideoEndpoints
{
    public static void MapVideoEndpoints(this WebApplication app)
    {
        // 分页列表（管理/历史跳转用）。cursor 是裸 id，keyset 翻页
        app.MapGet("/api/videos", async (PcVideoDbContext db,
            int? folderId,
            bool? enabledOnly,
            string? cursor,
            int? limit,
            bool? includeMissing) =>
        {
            var take = Math.Clamp(limit ?? 20, 1, 100);
            IQueryable<Data.Entities.VideoEntity> query = db.Videos.AsNoTracking();

            if (folderId is not null)
            {
                query = query.Where(v => v.FolderId == folderId);
            }
            if (enabledOnly == true)
            {
                var enabledFolderIds = db.Folders.Where(f => f.Enabled).Select(f => f.Id);
                query = query.Where(v => enabledFolderIds.Contains(v.FolderId));
            }
            if (includeMissing != true)
            {
                query = query.Where(v => !v.Missing);
            }
            if (int.TryParse(cursor, out var afterId))
            {
                query = query.Where(v => v.Id > afterId);
            }

            // 多取一条判断有没有下一页
            var rows = await query.OrderBy(v => v.Id).Take(take + 1).ToListAsync();
            var hasNext = rows.Count > take;
            var page = hasNext ? rows.Take(take).ToList() : rows;

            var folderNames = await db.Folders.AsNoTracking()
                .ToDictionaryAsync(f => f.Id, f => f.Name);
            var items = page.Select(v => VideoDtoMapper.ToDto(v, folderNames.TryGetValue(v.FolderId, out var n) ? n : string.Empty));

            return Results.Ok(new
            {
                items,
                nextCursor = hasNext ? page[^1].Id.ToString() : null
            });
        });

        // 随机批量：信息流专用。folderIds 不传 = 全部启用文件夹
        app.MapGet("/api/videos/random", async (PcVideoDbContext db,
            int? limit,
            string? folderIds,
            string? exclude) =>
        {
            var take = Math.Clamp(limit ?? 20, 1, 50);

            IQueryable<Data.Entities.VideoEntity> query = db.Videos.AsNoTracking();

            var wanted = ParseIds(folderIds);
            if (wanted.Count > 0)
            {
                query = query.Where(v => wanted.Contains(v.FolderId));
            }
            else
            {
                var enabledFolderIds = db.Folders.Where(f => f.Enabled).Select(f => f.Id);
                query = query.Where(v => enabledFolderIds.Contains(v.FolderId));
            }

            // missing 的视频不进随机池（外接盘离线等，重新扫到文件后自动回来）
            query = query.Where(v => !v.Missing);

            var excluded = ParseIds(exclude);
            if (excluded.Count > 0)
            {
                query = query.Where(v => !excluded.Contains(v.Id));
            }

            var poolSize = await query.CountAsync();
            var rows = await query
                .OrderBy(v => EF.Functions.Random())
                .Take(take)
                .ToListAsync();

            var folderNames = await db.Folders.AsNoTracking()
                .ToDictionaryAsync(f => f.Id, f => f.Name);
            var items = rows.Select(v => VideoDtoMapper.ToDto(v, folderNames.TryGetValue(v.FolderId, out var n) ? n : string.Empty));

            // poolSize 供客户端做「小片库退化」判断（池 < 一袋就全量循环洗牌）
            return Results.Ok(new { items, poolSize });
        });

        // 流式播放 / 下载共用。206/416/304 全由框架 Range 处理，不手写字节范围
        app.MapGet("/api/videos/{id:int}/stream", async (int id, PcVideoDbContext db, VideoStreamService stream) =>
        {
            var video = await stream.GetByIdAsync(id);
            if (video is null)
            {
                return ApiErrors.Fail(404, "not_found", "没找到这个东西");
            }
            if (!File.Exists(Services.PathUtil.NormalizeLongPath(video.FilePath)))
            {
                return ApiErrors.Fail(404, "file_missing", "磁盘上找不到这个文件了，去电脑管理页重新扫描试试");
            }
            var fileStream = stream.OpenRead(video.FilePath);
            if (fileStream is null)
            {
                return ApiErrors.Fail(404, "file_missing", "磁盘上找不到这个文件了，去电脑管理页重新扫描试试");
            }
            var contentType = VideoStreamService.ContentTypeFor(video.FilePath);
            DateTimeOffset? lastModified = null;
            try
            {
                lastModified = new DateTimeOffset(File.GetLastWriteTimeUtc(video.FilePath));
            }
            catch
            {
                // 取不到修改时间就不带 If-Range 头，不影响播放
            }
            return Results.File(fileStream, contentType, enableRangeProcessing: true, lastModified: lastModified);
        });

        app.MapGet("/api/videos/{id:int}/progress", async (int id, PcVideoDbContext db) =>
        {
            var progress = await db.PlaybackProgress.AsNoTracking().FirstOrDefaultAsync(p => p.VideoId == id);
            if (progress is null)
            {
                return Results.Ok(new { positionSec = 0d, durationSec = 0d, completed = false });
            }
            // 看完的视频位置归一为 0（看完重刷规则，架构 §4.2）
            return Results.Ok(new
            {
                positionSec = progress.Completed ? 0d : progress.PositionSec,
                durationSec = progress.DurationSec,
                completed = progress.Completed
            });
        });

        app.MapPut("/api/videos/{id:int}/progress", async (int id, HttpRequest request, PcVideoDbContext db) =>
        {
            ProgressRequestBody? body;
            try
            {
                body = await request.ReadFromJsonAsync<ProgressRequestBody>();
            }
            catch (System.Text.Json.JsonException)
            {
                return ApiErrors.Fail(400, "invalid_request", "请求内容不对");
            }
            if (body is null || body.PositionSec < 0 || body.DurationSec < 0)
            {
                return ApiErrors.Fail(400, "invalid_request", "请求内容不对");
            }

            var videoExists = await db.Videos.AnyAsync(v => v.Id == id);
            if (!videoExists)
            {
                return ApiErrors.Fail(404, "not_found", "没找到这个东西");
            }

            // 看完判定：客户端显式 completed，或播放到 95% 以上
            var completed = body.Completed ?? false;
            if (!completed && body.DurationSec > 0 && body.PositionSec >= 0.95 * body.DurationSec)
            {
                completed = true;
            }

            var progress = await db.PlaybackProgress.FindAsync(id);
            if (progress is null)
            {
                progress = new Data.Entities.PlaybackProgressEntity { VideoId = id };
                db.PlaybackProgress.Add(progress);
            }
            else if (progress.Completed)
            {
                // 粘滞：只有明确说没看完、且进度不足一半才解除看完状态
                if (body.Completed == false && body.PositionSec < 0.5 * body.DurationSec)
                {
                    completed = false;
                }
                else
                {
                    completed = true;
                }
            }

            progress.PositionSec = completed ? 0 : body.PositionSec;
            progress.DurationSec = body.DurationSec;
            progress.Completed = completed;
            progress.LastPlayedAt = DateTime.UtcNow.ToString("o");
            await db.SaveChangesAsync();

            return Results.Ok(new { positionSec = progress.PositionSec, completed = progress.Completed });
        });
    }

    /// <summary>解析逗号分隔的 id 列表，非数字/超量的一概忽略（调用方已按上限截断）。</summary>
    private static List<int> ParseIds(string? raw)
    {
        var result = new List<int>();
        if (string.IsNullOrWhiteSpace(raw)) return result;
        foreach (var part in raw.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            if (int.TryParse(part, out var id) && id > 0)
            {
                result.Add(id);
            }
        }
        return result;
    }

    private record ProgressRequestBody(double PositionSec, double DurationSec, bool? Completed);
}
