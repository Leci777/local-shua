using Microsoft.EntityFrameworkCore;
using PcVideo.Server.Data;

namespace PcVideo.Server.Endpoints;

/// <summary>
/// 收藏。「稍后再看」与收藏合并为一个概念，数据模型已预留字段，后续要区分再加。
/// </summary>
public static class FavoriteEndpoints
{
    private const int DefaultLimit = 50;

    public static void MapFavoriteEndpoints(this WebApplication app)
    {
        // 幂等切换：重复收藏同一视频不会产生两行
        app.MapPut("/api/videos/{id:int}/favorite", async (int id, HttpRequest request, PcVideoDbContext db) =>
        {
            FavoriteRequestBody? body;
            try
            {
                body = await request.ReadFromJsonAsync<FavoriteRequestBody>();
            }
            catch (System.Text.Json.JsonException)
            {
                return ApiErrors.Fail(400, "invalid_request", "请求内容不对");
            }
            if (body is null) return ApiErrors.Fail(400, "invalid_request", "请求内容不对");

            var videoExists = await db.Videos.AnyAsync(v => v.Id == id);
            if (!videoExists)
            {
                return ApiErrors.Fail(404, "not_found", "没找到这个东西");
            }

            var existing = await db.Favorites.FindAsync(id);
            if (body.IsFavorite)
            {
                if (existing is null)
                {
                    db.Favorites.Add(new Data.Entities.FavoriteEntity
                    {
                        VideoId = id,
                        CreatedAt = DateTime.UtcNow.ToString("o")
                    });
                    await db.SaveChangesAsync();
                }
            }
            else if (existing is not null)
            {
                db.Favorites.Remove(existing);
                await db.SaveChangesAsync();
            }

            return Results.Ok(new { isFavorite = body.IsFavorite });
        });

        app.MapGet("/api/favorites", async (PcVideoDbContext db, string? cursor, int? limit) =>
        {
            var take = Math.Clamp(limit ?? DefaultLimit, 1, 200);
            var (cursorKey, cursorId) = Cursor.Decode(cursor);

            var rows = await db.Favorites.AsNoTracking()
                .Include(f => f.Video)
                .OrderByDescending(f => f.CreatedAt)
                .ThenByDescending(f => f.VideoId)
                .ToListAsync();

            var folderNames = await db.Folders.AsNoTracking().ToDictionaryAsync(f => f.Id, f => f.Name);

            var filtered = rows.AsEnumerable();
            if (cursorKey is not null && cursorId is not null)
            {
                filtered = filtered.Where(f =>
                    string.CompareOrdinal(f.CreatedAt, cursorKey) < 0
                    || (f.CreatedAt == cursorKey && f.VideoId < cursorId));
            }

            var page = filtered.Take(take + 1).ToList();
            var hasNext = page.Count > take;
            var items = (hasNext ? page.Take(take) : page).Select(f =>
            {
                var video = f.Video!;
                return new
                {
                    video = VideoDtoMapper.ToDto(video, folderNames.TryGetValue(video.FolderId, out var n) ? n : string.Empty),
                    favoritedAt = f.CreatedAt
                };
            });

            var last = (hasNext ? page.Take(take).Last() : page.LastOrDefault());
            return Results.Ok(new
            {
                items,
                nextCursor = hasNext && last is not null ? Cursor.Encode(last.CreatedAt, last.VideoId) : null
            });
        });
    }

    private record FavoriteRequestBody(bool IsFavorite);
}
