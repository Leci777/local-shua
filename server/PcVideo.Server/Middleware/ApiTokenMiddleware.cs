using Microsoft.Extensions.Options;
using PcVideo.Server.Services;

namespace PcVideo.Server.Middleware;

/// <summary>
/// token 鉴权（可选）。
///
/// 默认关闭（appsettings 的 PcVideo:RequireToken = false）：个人自用、不对外公布，
/// 局域网里要防的是误连不是恶意，关掉最省心，也省掉每请求一次 SQLite 查询。
/// 打开后：POST /api/pair 与 GET /api/server/info 公开，其余 /api/* 需带 X-Api-Token。
/// </summary>
public class ApiTokenMiddleware
{
    private readonly RequestDelegate _next;
    private readonly bool _requireToken;

    public ApiTokenMiddleware(RequestDelegate next, IOptions<PcVideoOptions> options)
    {
        _next = next;
        _requireToken = options.Value.RequireToken;
    }

    public async Task InvokeAsync(HttpContext context, TokenService tokens)
    {
        if (_requireToken)
        {
            var path = context.Request.Path.Value ?? string.Empty;

            if (path.StartsWith("/api/", StringComparison.OrdinalIgnoreCase)
                && !path.Equals("/api/pair", StringComparison.OrdinalIgnoreCase)
                && !path.Equals("/api/server/info", StringComparison.OrdinalIgnoreCase)
                && !path.Equals("/api/pairing/regenerate", StringComparison.OrdinalIgnoreCase))
            {
                var token = context.Request.Headers["X-Api-Token"].FirstOrDefault();
                var device = await tokens.ValidateAsync(token);
                if (device is null)
                {
                    context.Response.StatusCode = 401;
                    context.Response.ContentType = "application/json";
                    await context.Response.WriteAsJsonAsync(new
                    {
                        code = "token_invalid",
                        message = "和电脑的配对过期了，去设置里重新配对"
                    });
                    return;
                }
            }
        }

        await _next(context);
    }
}