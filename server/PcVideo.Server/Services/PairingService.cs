using System.Security.Cryptography;

namespace PcVideo.Server.Services;

/// <summary>
/// 配对码管理。纯内存态：启动时生成，重启即失效，不落库。
/// TTL 默认 5 分钟（appsettings PcVideo:Pairing:CodeTtlSeconds）。
/// </summary>
public class PairingService
{
    private readonly object _lock = new();
    private string _code = string.Empty;
    private DateTime _expiresAt;

    public PairingService(Microsoft.Extensions.Options.IOptions<PcVideoOptions> options)
    {
        CodeLength = Math.Clamp(options.Value.Pairing.CodeLength, 4, 8);
        CodeTtl = TimeSpan.FromSeconds(Math.Max(30, options.Value.Pairing.CodeTtlSeconds));
        Regenerate();
    }

    private int CodeLength { get; }
    private TimeSpan CodeTtl { get; }

    /// <summary>当前配对码（托盘气泡和 Web 页显示用）。</summary>
    public string CurrentCode
    {
        get { lock (_lock) { return _code; } }
    }

    public DateTime ExpiresAt
    {
        get { lock (_lock) { return _expiresAt; } }
    }

    /// <summary>重新生成一个配对码，重置 TTL。托盘菜单「重新生成配对码」调它。</summary>
    public string Regenerate()
    {
        lock (_lock)
        {
            var max = (int)Math.Pow(10, CodeLength);
            var min = max / 10;
            _code = RandomNumberGenerator.GetInt32(min, max).ToString();
            _expiresAt = DateTime.UtcNow.Add(CodeTtl);
            return _code;
        }
    }

    /// <summary>校验配对码。成功返回 true 并立即作废（一次性，防重放）。</summary>
    public bool TryConsume(string code)
    {
        lock (_lock)
        {
            if (string.IsNullOrWhiteSpace(code)) return false;
            if (DateTime.UtcNow >= _expiresAt) return false;
            if (!string.Equals(code.Trim(), _code, StringComparison.Ordinal)) return false;
            // 一次性作废，用一次就得重新生成，缩小被蹭连的窗口
            _code = string.Empty;
            _expiresAt = DateTime.MinValue;
            return true;
        }
    }
}
