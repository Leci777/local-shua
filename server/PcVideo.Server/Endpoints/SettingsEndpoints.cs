using System.Text.Json;
using PcVideo.Server.Services;

namespace PcVideo.Server.Endpoints;

/// <summary>
/// 设置：GET 全量 / PUT 部分更新合并。只认白名单键（SettingsService.Defaults），
/// 脏键直接忽略，不报错也不入库。
/// </summary>
public static class SettingsEndpoints
{
    public static void MapSettingsEndpoints(this WebApplication app)
    {
        app.MapGet("/api/settings", async (SettingsService settings) =>
            Results.Ok(await settings.GetAllAsync()));

        app.MapPut("/api/settings", async (HttpRequest request, SettingsService settings) =>
        {
            Dictionary<string, JsonElement>? patch;
            try
            {
                patch = await request.ReadFromJsonAsync<Dictionary<string, JsonElement>>();
            }
            catch (System.Text.Json.JsonException)
            {
                return ApiErrors.Fail(400, "invalid_request", "请求内容不对");
            }
            if (patch is null)
            {
                return ApiErrors.Fail(400, "invalid_request", "请求内容不对");
            }
            var merged = await settings.UpdateAsync(patch);
            return Results.Ok(merged);
        });
    }
}
