using System.Diagnostics;
using System.Text.Json;
using Microsoft.Extensions.Options;

namespace PcVideo.Server.Services;

/// <summary>ffprobe 探出来的元数据。字段对应 VideoEntity 的可空列。</summary>
public record ProbeResult(
    double? DurationSec,
    int? Width,
    int? Height,
    string? VideoCodec,
    string? AudioCodec,
    int? BitrateKbps);

/// <summary>
/// ffprobe 进程调用 + JSON 解析。
/// 超时（默认 15s）或非 0 退出都返回 null——调用方据此标 unplayable，不让一个坏文件拖死整库。
/// </summary>
public class FfprobeRunner
{
    private readonly FfprobeProvider _provider;
    private readonly PcVideoOptions _options;
    private readonly ILogger<FfprobeRunner> _logger;

    public FfprobeRunner(FfprobeProvider provider, IOptions<PcVideoOptions> options, ILogger<FfprobeRunner> logger)
    {
        _provider = provider;
        _options = options.Value;
        _logger = logger;
    }

    public async Task<ProbeResult?> ProbeAsync(string filePath, CancellationToken ct = default)
    {
        var exePath = _provider.GetExePath();
        if (exePath is null) return null;

        var normalized = PathUtil.NormalizeLongPath(filePath);
        var psi = new ProcessStartInfo
        {
            FileName = exePath,
            // -v quiet 关掉横幅；只要 format 和 streams 两段
            Arguments = $"-v quiet -print_format json -show_format -show_streams \"{normalized}\"",
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
        };

        using var process = new Process { StartInfo = psi };
        try
        {
            process.Start();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "ffprobe 启动失败：{File}", filePath);
            return null;
        }

        var timeout = TimeSpan.FromSeconds(Math.Max(5, _options.Scan.FfprobeTimeoutSeconds));
        try
        {
            var stdoutTask = process.StandardOutput.ReadToEndAsync(ct);
            // .NET 9 没有 (TimeSpan, CT) 重载，用经典毫秒重载；超时杀进程标 unplayable
            if (!process.WaitForExit((int)timeout.TotalMilliseconds))
            {
                try { process.Kill(entireProcessTree: true); } catch { /* 已退出就算了 */ }
                _logger.LogWarning("ffprobe 超时（{Timeout}s）：{File}", (int)timeout.TotalSeconds, filePath);
                return null;
            }
            var json = await stdoutTask;
            if (process.ExitCode != 0 || string.IsNullOrWhiteSpace(json)) return null;
            return Parse(json);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "ffprobe 执行异常：{File}", filePath);
            return null;
        }
    }

    /// <summary>从 ffprobe JSON 里取：format.duration/bit_rate、第一个视频流、第一个音频流。</summary>
    internal static ProbeResult? Parse(string json)
    {
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        double? duration = null;
        int? bitrateKbps = null;
        if (root.TryGetProperty("format", out var format))
        {
            if (format.TryGetProperty("duration", out var d)
                && double.TryParse(d.GetString(), out var durationSec))
            {
                duration = durationSec;
            }
            if (format.TryGetProperty("bit_rate", out var br)
                && long.TryParse(br.GetString(), out var bits))
            {
                bitrateKbps = (int)(bits / 1000);
            }
        }

        int? width = null;
        int? height = null;
        string? videoCodec = null;
        string? audioCodec = null;
        if (root.TryGetProperty("streams", out var streams) && streams.ValueKind == JsonValueKind.Array)
        {
            foreach (var stream in streams.EnumerateArray())
            {
                var type = stream.TryGetProperty("codec_type", out var t) ? t.GetString() : null;
                if (type == "video" && videoCodec is null)
                {
                    videoCodec = stream.TryGetProperty("codec_name", out var c) ? c.GetString() : null;
                    width = stream.TryGetProperty("width", out var w) ? w.GetInt32() : (int?)null;
                    height = stream.TryGetProperty("height", out var h) ? h.GetInt32() : (int?)null;
                }
                else if (type == "audio" && audioCodec is null)
                {
                    audioCodec = stream.TryGetProperty("codec_name", out var c) ? c.GetString() : null;
                }
            }
        }

        // 取不到视频流视为解析失败（音频文件混进视频库的情况）
        if (videoCodec is null) return null;
        return new ProbeResult(duration, width, height, videoCodec, audioCodec, bitrateKbps);
    }
}
