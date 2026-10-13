using PcVideo.Server.Services;

namespace PcVideo.Server.Endpoints;

/// <summary>
/// POST /api/pair：6 位配对码换 token。公开接口；配对码一次性，5 分钟有效。
/// </summary>
public static class PairEndpoints
{
    public static void MapPairEndpoints(this WebApplication app)
    {
        app.MapPost("/api/pair", async (HttpRequest request, PairingService pairing, TokenService tokens, SettingsService settings) =>
        {
            PairRequestBody? body;
            try
            {
                body = await request.ReadFromJsonAsync<PairRequestBody>();
            }
            catch (System.Text.Json.JsonException)
            {
                return ApiErrors.Fail(400, "invalid_request", "请求内容不对");
            }

            if (body is null || string.IsNullOrWhiteSpace(body.Code))
            {
                return ApiErrors.Fail(400, "invalid_request", "请求内容不对");
            }

            if (!pairing.TryConsume(body.Code))
            {
                return ApiErrors.Fail(403, "pair_code_invalid", "配对码不对或过期了，看看电脑屏幕上的数字");
            }

            var deviceName = string.IsNullOrWhiteSpace(body.DeviceName) ? "未命名设备" : body.DeviceName;
            var token = await tokens.IssueAsync(deviceName);
            var serverName = await settings.GetStringAsync("serverName");
            return Results.Ok(new { token, serverName, version = "1.0.0" });
        });
    }

    private record PairRequestBody(string Code, string? DeviceName);
}
