using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using PcVideo.Server.Data;

namespace PcVideo.Server.Services;

/// <summary>
/// token 签发与校验。库里只存 SHA256 哈希，还原不出可用 token。
/// </summary>
public class TokenService
{
    private readonly PcVideoDbContext _db;

    public TokenService(PcVideoDbContext db)
    {
        _db = db;
    }

    /// <summary>生成新 token：32 随机字节，base64url 编码（去掉 +/= 避免 URL/头里转义）。</summary>
    public static string GenerateToken()
    {
        var bytes = RandomNumberGenerator.GetBytes(32);
        return Convert.ToBase64String(bytes)
            .Replace("+", "-").Replace("/", "_").TrimEnd('=');
    }

    /// <summary>token → SHA256 十六进制小写，与入库口径一致。</summary>
    public static string Hash(string token)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(token));
        return Convert.ToHexStringLower(bytes);
    }

    /// <summary>签发：登记设备并返回 token 明文（只此一次返回，之后库里只有哈希）。</summary>
    public async Task<string> IssueAsync(string deviceName)
    {
        var token = GenerateToken();
        _db.PairedDevices.Add(new Data.Entities.PairedDeviceEntity
        {
            TokenHash = Hash(token),
            DeviceName = deviceName,
            CreatedAt = DateTime.UtcNow.ToString("o"),
        });
        await _db.SaveChangesAsync();
        return token;
    }

    /// <summary>校验请求头带来的 token。命中返回设备名；last_used_at 每 5 分钟才写一次库。</summary>
    public async Task<string?> ValidateAsync(string? token)
    {
        if (string.IsNullOrWhiteSpace(token)) return null;
        var hash = Hash(token);
        var device = await _db.PairedDevices.FirstOrDefaultAsync(d => d.TokenHash == hash);
        if (device is null) return null;

        // 节流：/stream 一次播放会发几十个 Range 请求，每个都写库纯属浪费
        var stale = device.LastUsedAt is null
            || !DateTime.TryParse(device.LastUsedAt, out var last)
            || DateTime.UtcNow - last > TimeSpan.FromMinutes(5);
        if (stale)
        {
            device.LastUsedAt = DateTime.UtcNow.ToString("o");
            await _db.SaveChangesAsync();
        }
        return device.DeviceName;
    }
}
