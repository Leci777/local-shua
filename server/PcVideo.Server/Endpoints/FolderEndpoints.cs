using Microsoft.EntityFrameworkCore;
using PcVideo.Server.Data;
using PcVideo.Server.Data.Entities;
using PcVideo.Server.Services;

namespace PcVideo.Server.Endpoints;

/// <summary>文件夹 DTO，与架构 §4.2 一致。</summary>
public record FolderDto(
    int Id,
    string Name,
    string Path,
    bool Enabled,
    int VideoCount,
    int UnplayableCount,
    int MissingCount,
    string? LastScanAt,
    string CreatedAt);

/// <summary>
/// 文件夹管理。增删只在 Web 管理页做；App 端只读 + 启停开关（架构 §4.5 差异 5 定稿）。
/// </summary>
public static class FolderEndpoints
{
    public static void MapFolderEndpoints(this WebApplication app)
    {
        app.MapGet("/api/folders", async (PcVideoDbContext db) =>
        {
            var folders = await db.Folders.AsNoTracking().OrderBy(f => f.Id).ToListAsync();
            var counts = await db.Videos
                .Where(v => folders.Select(f => f.Id).Contains(v.FolderId))
                .GroupBy(v => v.FolderId)
                .Select(g => new
                {
                    FolderId = g.Key,
                    Total = g.Count(v => !v.Missing),
                    Unplayable = g.Count(v => !v.Missing && v.Unplayable),
                    Missing = g.Count(v => v.Missing)
                })
                .ToListAsync();
            var byId = counts.ToDictionary(c => c.FolderId);
            var items = folders.Select(f => new FolderDto(
                f.Id,
                f.Name,
                f.Path,
                f.Enabled,
                byId.TryGetValue(f.Id, out var c) ? c.Total : 0,
                byId.TryGetValue(f.Id, out var c2) ? c2.Unplayable : 0,
                byId.TryGetValue(f.Id, out var c3) ? c3.Missing : 0,
                f.LastScanAt,
                f.CreatedAt));
            return Results.Ok(items);
        });

        app.MapPost("/api/folders", async (HttpRequest request, PcVideoDbContext db) =>
        {
            AddFolderRequestBody? body;
            try
            {
                body = await request.ReadFromJsonAsync<AddFolderRequestBody>();
            }
            catch (System.Text.Json.JsonException)
            {
                return ApiErrors.Fail(400, "invalid_request", "请求内容不对");
            }

            if (body is null || string.IsNullOrWhiteSpace(body.Path))
            {
                return ApiErrors.Fail(400, "invalid_request", "请求内容不对");
            }

            // 路径必须是已存在的目录，错误原因直显（PRD R4）
            var trimmed = body.Path.Trim().Trim('"');
            if (!Directory.Exists(trimmed))
            {
                return ApiErrors.Fail(400, "invalid_request", "这个路径不存在，或者不是文件夹");
            }

            var key = Services.PathUtil.CanonicalKey(Path.GetFullPath(trimmed));
            var exists = await db.Folders.AnyAsync(f => f.Path == key);
            if (exists)
            {
                return ApiErrors.Fail(409, "folder_already_exists", "这个文件夹已经加过了");
            }

            var name = string.IsNullOrWhiteSpace(body.Name)
                ? Path.GetFileName(key.TrimEnd('\\'))
                : body.Name;
            var folder = new FolderEntity
            {
                Path = key,
                Name = name,
                Enabled = true,
                CreatedAt = DateTime.UtcNow.ToString("o")
            };
            db.Folders.Add(folder);
            await db.SaveChangesAsync();

            var dto = new FolderDto(folder.Id, folder.Name, folder.Path, folder.Enabled, 0, 0, 0, null, folder.CreatedAt);
            return Results.Created($"/api/folders/{folder.Id}", dto);
        });

        app.MapDelete("/api/folders/{id:int}", async (int id, PcVideoDbContext db) =>
        {
            var folder = await db.Folders.FindAsync(id);
            if (folder is null) return ApiErrors.Fail(404, "not_found", "没找到这个东西");
            // 只解除管理，不删磁盘文件；其视频/进度/收藏级联删除（DbContext 已配）
            db.Folders.Remove(folder);
            await db.SaveChangesAsync();
            return Results.NoContent();
        });

        app.MapPut("/api/folders/{id:int}/enabled", async (int id, HttpRequest request, PcVideoDbContext db) =>
        {
            SetEnabledRequestBody? body;
            try
            {
                body = await request.ReadFromJsonAsync<SetEnabledRequestBody>();
            }
            catch (System.Text.Json.JsonException)
            {
                return ApiErrors.Fail(400, "invalid_request", "请求内容不对");
            }
            if (body is null) return ApiErrors.Fail(400, "invalid_request", "请求内容不对");

            var folder = await db.Folders.FindAsync(id);
            if (folder is null) return ApiErrors.Fail(404, "not_found", "没找到这个东西");
            folder.Enabled = body.Enabled;
            await db.SaveChangesAsync();

            // 冗余统计已存在文件夹行上，直接返回
            var dto = new FolderDto(
                folder.Id, folder.Name, folder.Path, folder.Enabled,
                folder.VideoCount, folder.UnplayableCount, 0, folder.LastScanAt, folder.CreatedAt);
            return Results.Ok(dto);
        });

        app.MapPost("/api/folders/{id:int}/scan", async (int id, ScanService scan) =>
        {
            var (started, state) = await scan.TryStartAsync(id);
            if (!started)
            {
                if (state is null) return ApiErrors.Fail(404, "not_found", "没找到这个东西");
                return ApiErrors.Fail(409, "scan_in_progress", "正在扫描中，稍等一下");
            }
            return Results.Accepted($"/api/folders/{id}/scan/latest", new
            {
                scanId = Guid.NewGuid().ToString("N"),
                status = "running",
                startedAt = state!.StartedAt
            });
        });

        app.MapGet("/api/folders/{id:int}/scan/latest", async (int id, PcVideoDbContext db, ScanService scan) =>
        {
            if (!await db.Folders.AnyAsync(f => f.Id == id))
            {
                return ApiErrors.Fail(404, "not_found", "没找到这个东西");
            }
            var state = scan.GetLatest(id);
            if (state is null)
            {
                // 还没扫过：给个「never」态，Web 页不必特判
                return Results.Ok(new
                {
                    status = "never",
                    found = 0,
                    added = 0,
                    removed = 0,
                    unplayable = 0,
                    startedAt = (string?)null,
                    finishedAt = (string?)null,
                    error = (string?)null
                });
            }
            return Results.Ok(state);
        });
    }

    private record AddFolderRequestBody(string Path, string? Name);
    private record SetEnabledRequestBody(bool Enabled);
}
