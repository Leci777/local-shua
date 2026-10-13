using System.IO.Compression;
using System.Reflection;
using Microsoft.Extensions.Options;

namespace PcVideo.Server.Services;

/// <summary>
/// ffprobe 的「找得到、用得上」。
/// 优先级：① 数据目录解压产物 → ② exe 旁边的 ffprobe 文件夹（兜底，ADR-06）→ ③ 内嵌 zip 现解压。
/// 三者都没有返回 null，扫描会把视频全标「可能无法播放」并写日志——不静默失败。
/// </summary>
public class FfprobeProvider
{
    private readonly PcVideoOptions _options;
    private readonly ILogger<FfprobeProvider> _logger;
    private readonly SemaphoreSlim _lock = new(1, 1);
    private string? _exePath;

    public FfprobeProvider(IOptions<PcVideoOptions> options, ILogger<FfprobeProvider> logger)
    {
        _options = options.Value;
        _logger = logger;
    }

    /// <summary>返回 ffprobe.exe 路径；找不到返回 null。</summary>
    public string? GetExePath()
    {
        if (_exePath is not null) return _exePath;

        _lock.Wait();
        try
        {
            if (_exePath is not null) return _exePath;

            // ① 数据目录里已解压的
            var inDataDir = AppPaths.FfprobeExe(_options);
            if (File.Exists(inDataDir))
            {
                _exePath = inDataDir;
                return _exePath;
            }

            // ② exe 旁边的 ffprobe 文件夹（发布时手工放置的兜底形态）
            var besideExe = Path.Combine(AppContext.BaseDirectory, "ffprobe", "ffprobe.exe");
            if (File.Exists(besideExe))
            {
                _exePath = besideExe;
                return _exePath;
            }

            // ③ 内嵌 zip 首启解压（仓库不放大文件，zip 见 server/tools/ffprobe/README.md）
            if (TryExtractEmbedded(inDataDir))
            {
                _exePath = inDataDir;
                return _exePath;
            }

            _logger.LogWarning("没找到 ffprobe.exe：数据目录、exe 旁边、内嵌 zip 都没有。扫描将把视频全部标记为「可能无法播放」");
            return null;
        }
        finally
        {
            _lock.Release();
        }
    }

    private bool TryExtractEmbedded(string targetExePath)
    {
        var assembly = Assembly.GetExecutingAssembly();
        const string logicalName = "ffprobe-win-x64.zip";
        using var stream = assembly.GetManifestResourceStream(logicalName);
        if (stream is null) return false;

        var targetDir = Path.GetDirectoryName(targetExePath)!;
        Directory.CreateDirectory(targetDir);
        var tempZip = Path.Combine(Path.GetTempPath(), $"pcvideo-ffprobe-{Guid.NewGuid():N}.zip");
        try
        {
            using (var file = File.Create(tempZip))
            {
                stream.CopyTo(file);
            }
            // overwriteFiles: 解压升级时直接覆盖旧文件
            ZipFile.ExtractToDirectory(tempZip, targetDir, overwriteFiles: true);
            _logger.LogInformation("ffprobe 已从内嵌 zip 解压到 {Dir}", targetDir);
            return File.Exists(targetExePath);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "解压内嵌 ffprobe zip 失败");
            return false;
        }
        finally
        {
            if (File.Exists(tempZip)) File.Delete(tempZip);
        }
    }
}
