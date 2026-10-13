using PcVideo.Server.Services;

namespace PcVideo.Server.Middleware;

/// <summary>
/// token 鉴权。POST /api/pair 和 GET /api/server/info 公开（连接页要能在配对前探活），
/// 其余 /api/* 全部要 X-Api-Token；静态文件和 / 放行（Web 管理页）。
/// </summary>
public class ApiTokenMiddleware
{
    private readonly RequestDelegate _next;

    public ApiTokenMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(HttpContext context, TokenService tokens)
    {
        var path = context.Request.Path.Value ?? string.Empty;

        // 公开接口（连接页要能在配对前探活；管理页与托盘同权可重新生成配对码，架构 §2.5）
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

        await _next(context);
    }
}
