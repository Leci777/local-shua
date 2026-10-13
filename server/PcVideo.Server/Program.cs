using Microsoft.EntityFrameworkCore;
using PcVideo.Server.Data;
using PcVideo.Server.Endpoints;
using PcVideo.Server.Hosting;
using PcVideo.Server.Middleware;
using PcVideo.Server.Services;
using Serilog;

// ===== 数据目录 =====
// 日志要最早初始化，但目录取决于配置里的 DataDir——先单独读一遍 appsettings 把它定下来。
// appsettings 的 PcVideo:DataDir 可改；为空则 %LOCALAPPDATA%\PcVideo（库、日志、ffprobe 都在它下面）
var earlyConfig = new ConfigurationBuilder()
    .SetBasePath(AppContext.BaseDirectory)
    .AddJsonFile("appsettings.json", optional: true)
    .AddEnvironmentVariables()
    .Build();
var configuredDataDir = earlyConfig["PcVideo:DataDir"];
var dataRoot = string.IsNullOrWhiteSpace(configuredDataDir)
    ? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PcVideo")
    : configuredDataDir;
Directory.CreateDirectory(Path.Combine(dataRoot, "logs"));

// WinExo 没有控制台窗口，日志只进文件；排障加 --verbose 升 Debug
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .WriteTo.File(
        Path.Combine(dataRoot, "logs", "pcvideo-.log"),
        rollingInterval: RollingInterval.Day,
        outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff} [{Level:u3}] {Message:lj}{NewLine}{Exception}")
    .CreateLogger();

try
{
    Log.Information("本地刷服务启动中，数据目录 {DataRoot}", dataRoot);

    var builder = WebApplication.CreateBuilder(args);
    builder.Host.UseSerilog();

    builder.Services.Configure<PcVideoOptions>(builder.Configuration.GetSection("PcVideo"));
    builder.Services.AddDbContext<PcVideoDbContext>(o =>
        o.UseSqlite($"Data Source={Path.Combine(dataRoot, "pcvideo.db")}"));

    // 不碰数据库的单例
    builder.Services.AddSingleton<PairingService>();
    builder.Services.AddSingleton<FfprobeProvider>();
    builder.Services.AddSingleton<FfprobeRunner>();
    builder.Services.AddSingleton<AutoStartService>();
    builder.Services.AddSingleton<TrayIconService>();

    // ScanService 单例：扫描状态和单飞锁是跨请求的内存态（见其类注释）。
    // 它内部用 scope factory 自建 DbContext，不 captive 请求级上下文
    builder.Services.AddSingleton<ScanService>();

    // 其余请求级服务：都只做短操作
    builder.Services.AddScoped<TokenService>();
    builder.Services.AddScoped<SettingsService>();
    builder.Services.AddScoped<VideoStreamService>();

    builder.Services.AddHostedService<DiscoveryResponder>();

    var app = builder.Build();

    // 单实例：第二个实例给第一个发唤醒信号，然后自己退出
    if (!SingleInstanceGuard.TryAcquire(out var instanceGuard))
    {
        Log.Warning("已经有一个本地刷服务在运行，本实例退出");
        return;
    }

    // 建库/迁移。迁移由 dotnet ef 生成（InitialCreate），没有迁移时这里不建表
    using (var initScope = app.Services.CreateScope())
    {
        var db = initScope.ServiceProvider.GetRequiredService<PcVideoDbContext>();
        await db.Database.MigrateAsync();
        Log.Information("数据库就绪");
    }

    app.UseMiddleware<ApiTokenMiddleware>();
    app.UseStaticFiles();

    // 管理页首页：把当前配对码注入 HTML 再返回（架构 §2.7）。
    // 这里必须自己接 "/"——UseDefaultFiles 会把路径改写成 /index.html，
    // 静态文件中间件直接吐带占位符的原文，注入就失效了
    app.MapGet("/", async (HttpContext context, PairingService pairing) =>
    {
        var filePath = Path.Combine(app.Environment.WebRootPath ?? "wwwroot", "index.html");
        if (!File.Exists(filePath)) return Results.Text("管理页文件缺失", "text/plain");
        var html = await File.ReadAllTextAsync(filePath);
        html = html.Replace("{{PAIR_CODE}}", pairing.CurrentCode, StringComparison.Ordinal);
        return Results.Text(html, "text/html");
    });

    app.MapServerEndpoints();
    app.MapPairEndpoints();
    app.MapFolderEndpoints();
    app.MapVideoEndpoints();
    app.MapHistoryEndpoints();
    app.MapFavoriteEndpoints();
    app.MapSettingsEndpoints();
    app.MapFallbackToFile("index.html");

    // 开机自启：第一次跑默认打开，之后完全听托盘菜单的
    app.Services.GetRequiredService<AutoStartService>().ApplyFirstRunDefault();

    var tray = app.Services.GetRequiredService<TrayIconService>();
    tray.Start();

    // 第二个实例的唤醒信号 → 重新弹气泡（地址 + 配对码）
    var lifetime = app.Services.GetRequiredService<IHostApplicationLifetime>();
    _ = Task.Run(async () =>
    {
        while (await instanceGuard!.WaitForWakeAsync(lifetime.ApplicationStopping))
        {
            tray.ShowStartupBalloon();
        }
    });

    await app.RunAsync();

    tray.Dispose();
}
catch (Exception ex)
{
    Log.Fatal(ex, "服务启动失败");
    throw; // 双击起不来的时候，Windows 错误报告能看到线索
}
finally
{
    Log.CloseAndFlush();
}
