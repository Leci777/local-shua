using System.Diagnostics;
using System.Text;
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
            // 不设的话用父进程控制台代码页（中文 Windows 是 GBK），ffprobe 的 UTF-8 输出会被解成一锅粥
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
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
            // 直接读原始字节，不走「按代码页解码成字符串」那道关卡——
            // 中文路径的元数据在字符串解码里最容易出事，字节级解析一步到位
            var stdoutMs = new MemoryStream();
            var stderrMs = new MemoryStream();
            var copyOut = process.StandardOutput.BaseStream.CopyToAsync(stdoutMs, ct);
            var copyErr = process.StandardError.BaseStream.CopyToAsync(stderrMs, ct);
            await Task.WhenAll(copyOut, copyErr);

            // .NET 9 没有 (TimeSpan, CT) 重载，用经典毫秒重载；超时杀进程标 unplayable
            if (!process.WaitForExit((int)timeout.TotalMilliseconds))
            {
                try { process.Kill(entireProcessTree: true); } catch { /* 已退出就算了 */ }
                _logger.LogWarning("ffprobe 超时（{Timeout}s）：{File}", (int)timeout.TotalSeconds, filePath);
                return null;
            }

            var jsonBytes = stdoutMs.ToArray();
            if (process.ExitCode != 0 || jsonBytes.Length == 0)
            {
                var stderrText = Encoding.UTF8.GetString(stderrMs.ToArray());
                // 失败时把退出码和 stderr 尾巴记下来，不然「全是 unplayable」时两眼一黑
                _logger.LogWarning(
                    "ffprobe 探测失败：{File}，退出码 {ExitCode}，stderr：{Stderr}",
                    filePath, process.ExitCode, Truncate(stderrText));
                return null;
            }

            try
            {
                return Parse(jsonBytes);
            }
            catch (JsonException ex)
            {
                // 解析炸了把原始字节留证，排障时不用猜
                var dump = Path.Combine(Path.GetTempPath(), $"pcvideo-ffprobe-fail-{Guid.NewGuid():N}.bin");
                File.WriteAllBytes(dump, jsonBytes);
                _logger.LogWarning(ex,
                    "ffprobe 输出不是合法 JSON：{File}，原始字节已留证 {Dump}（前 64 字节：{Head}）",
                    filePath, dump, Convert.ToHexString(jsonBytes.AsSpan(0, Math.Min(64, jsonBytes.Length))));
                return null;
            }
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

    /// <summary>stderr 只留尾巴，避免日志被超长报错刷爆。</summary>
    private static string Truncate(string text, int maxLength = 300)
    {
        if (string.IsNullOrEmpty(text)) return "(空)";
        text = text.Trim();
        return text.Length <= maxLength ? text : text[^maxLength..];
    }

    /// <summary>从 ffprobe JSON 里取：format.duration/bit_rate、第一个视频流、第一个音频流。
    /// 直接吃字节：System.Text.Json 原生按 UTF-8 解析，不经过字符串解码。</summary>
    internal static ProbeResult? Parse(ReadOnlyMemory<byte> json)
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
