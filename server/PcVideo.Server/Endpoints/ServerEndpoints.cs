using Microsoft.EntityFrameworkCore;
using PcVideo.Server.Data;
using PcVideo.Server.Services;

namespace PcVideo.Server.Endpoints;

/// <summary>GET /api/server/info：连接页探活 + 状态展示。公开接口，不需要 token。</summary>
public static class ServerEndpoints
{
    public static void MapServerEndpoints(this WebApplication app)
    {
        app.MapGet("/api/server/info", async (PcVideoDbContext db, SettingsService settings) =>
        {
            var videoCount = await db.Videos.CountAsync(v => !v.Missing);
            var folderCount = await db.Folders.CountAsync();
            var enabledFolderCount = await db.Folders.CountAsync(f => f.Enabled);
            var serverName = await settings.GetStringAsync("serverName");
            return Results.Ok(new
            {
                serverName,
                version = "1.0.0",
                videoCount,
                folderCount,
                enabledFolderCount
            });
        });

        // 重新生成配对码。公开——管理页与托盘同权（架构 §2.5：本机使用口径）。
        // 局域网其他人最多能恶心你换个码，够不成越权
        app.MapPost("/api/pairing/regenerate", (PairingService pairing) =>
            Results.Ok(new { code = pairing.Regenerate() }));
    }
}
