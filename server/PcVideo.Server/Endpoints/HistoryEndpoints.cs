using Microsoft.EntityFrameworkCore;
using PcVideo.Server.Data;
using PcVideo.Server.Data.Entities;

namespace PcVideo.Server.Endpoints;

/// <summary>
/// 播放历史 = 进度表按 LastPlayedAt 倒序投影（架构 §2.2）。
/// 个人规模（千级行）内存分页可接受；片库大到内存分页成为瓶颈时再改纯 SQL keyset。
/// </summary>
public static class HistoryEndpoints
{
    private const int DefaultLimit = 50;

    public static void MapHistoryEndpoints(this WebApplication app)
    {
        app.MapGet("/api/history", async (PcVideoDbContext db, string? cursor, int? limit) =>
        {
            var take = Math.Clamp(limit ?? DefaultLimit, 1, 200);
            var (cursorKey, cursorId) = Cursor.Decode(cursor);

            var rows = await db.PlaybackProgress.AsNoTracking()
                .Include(p => p.Video)
                .OrderByDescending(p => p.LastPlayedAt)
                .ThenByDescending(p => p.VideoId)
                .ToListAsync();

            var folderNames = await db.Folders.AsNoTracking().ToDictionaryAsync(f => f.Id, f => f.Name);

            var filtered = rows.AsEnumerable();
            if (cursorKey is not null && cursorId is not null)
            {
                filtered = filtered.Where(p =>
                    string.CompareOrdinal(p.LastPlayedAt, cursorKey) < 0
                    || (p.LastPlayedAt == cursorKey && p.VideoId < cursorId));
            }

            var page = filtered.Take(take + 1).ToList();
            var hasNext = page.Count > take;
            var items = (hasNext ? page.Take(take) : page).Select(p =>
            {
                var video = p.Video!;
                return new
                {
                    video = VideoDtoMapper.ToDto(video, folderNames.TryGetValue(video.FolderId, out var n) ? n : string.Empty),
                    positionSec = p.Completed ? 0d : p.PositionSec,
                    durationSec = p.DurationSec,
                    completed = p.Completed,
                    lastPlayedAt = p.LastPlayedAt
                };
            });

            var last = (hasNext ? page.Take(take).Last() : page.LastOrDefault());
            return Results.Ok(new
            {
                items,
                nextCursor = hasNext && last is not null ? Cursor.Encode(last.LastPlayedAt, last.VideoId) : null
            });
        });

        app.MapDelete("/api/history/{videoId:int}", async (int videoId, PcVideoDbContext db) =>
        {
            var progress = await db.PlaybackProgress.FindAsync(videoId);
            if (progress is null) return ApiErrors.Fail(404, "not_found", "没找到这个东西");
            db.PlaybackProgress.Remove(progress);
            await db.SaveChangesAsync();
            return Results.NoContent();
        });

        app.MapDelete("/api/history", async (PcVideoDbContext db) =>
        {
            var all = await db.PlaybackProgress.ToListAsync();
            db.PlaybackProgress.RemoveRange(all);
            await db.SaveChangesAsync();
            return Results.NoContent();
        });
    }
}
