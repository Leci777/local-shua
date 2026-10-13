using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using PcVideo.Server.Data;
using PcVideo.Server.Data.Entities;

namespace PcVideo.Server.Services;

/// <summary>
/// 用户习惯类设置的读写 + 内存缓存。
/// 只放用户会改的项；运行参数（扫描并发等）归 appsettings.json，不进这里。
/// </summary>
public class SettingsService
{
    private readonly PcVideoDbContext _db;
    private readonly Dictionary<string, string> _cache = new(StringComparer.Ordinal);
    private readonly SemaphoreSlim _initLock = new(1, 1);
    private bool _loaded;

    // 默认值。所有值一律以 JSON 文本存储（字符串带引号、数字/布尔裸写），
    // GetAllAsync 直接 JsonDocument.Parse，不搞「有的带引号有的不带」的双口径
    private static readonly Dictionary<string, string> Defaults = new(StringComparer.Ordinal)
    {
        ["defaultSpeed"] = "1.0",
        ["autoPlayNext"] = "true",
        ["recentExcludeCount"] = "10",
        ["longVideoThresholdSec"] = "1800",
        ["downloadLimitGb"] = "10",
    };

    public SettingsService(PcVideoDbContext db, IOptions<PcVideoOptions> options)
    {
        _db = db;
        // serverName 是字符串，序列化成带引号的 JSON 文本，与库里口径一致
        Defaults["serverName"] = JsonSerializer.Serialize(options.Value.ServerName);
    }

    private async Task EnsureLoadedAsync()
    {
        if (_loaded) return;
        await _initLock.WaitAsync();
        try
        {
            if (_loaded) return;
            var rows = await _db.Settings.ToListAsync();
            _cache.Clear();
            foreach (var (key, value) in Defaults)
            {
                _cache[key] = value;
            }
            foreach (var row in rows)
            {
                _cache[row.Key] = row.Value;
            }
            _loaded = true;
        }
        finally
        {
            _initLock.Release();
        }
    }

    public async Task<Dictionary<string, JsonElement>> GetAllAsync()
    {
        await EnsureLoadedAsync();
        var result = new Dictionary<string, JsonElement>(StringComparer.Ordinal);
        foreach (var (key, value) in _cache)
        {
            result[key] = JsonDocument.Parse(value).RootElement.Clone();
        }
        return result;
    }

    public async Task<string> GetRawAsync(string key)
    {
        await EnsureLoadedAsync();
        return _cache.TryGetValue(key, out var value) ? value : Defaults[key];
    }

    /// <summary>取字符串设置（如 serverName）。值在库里是 JSON 字符串，这里脱掉引号。</summary>
    public async Task<string> GetStringAsync(string key)
    {
        var raw = await GetRawAsync(key);
        try
        {
            return JsonDocument.Parse(raw).RootElement.GetString() ?? raw;
        }
        catch (JsonException)
        {
            return raw; // 脏数据原样返回，不让设置页崩
        }
    }

    public async Task<int> GetIntAsync(string key)
    {
        var raw = await GetRawAsync(key);
        return int.TryParse(raw, out var n) ? n : int.Parse(Defaults[key]);
    }

    public async Task<double> GetDoubleAsync(string key)
    {
        var raw = await GetRawAsync(key);
        return double.TryParse(raw, out var n) ? n : double.Parse(Defaults[key]);
    }

    public async Task<bool> GetBoolAsync(string key)
    {
        var raw = await GetRawAsync(key);
        return bool.TryParse(raw, out var b) ? b : bool.Parse(Defaults[key]);
    }

    /// <summary>部分更新合并：只改传入的键，其余保持原值。</summary>
    public async Task<Dictionary<string, JsonElement>> UpdateAsync(Dictionary<string, JsonElement> patch)
    {
        await EnsureLoadedAsync();
        foreach (var (key, element) in patch)
        {
            if (!Defaults.ContainsKey(key)) continue; // 白名单，防止写脏键
            // GetRawText 保留 JSON 原样（字符串带引号）；ToString 会把引号弄丢，口径就不一致了
            var raw = element.GetRawText();
            _cache[key] = raw;
            var row = await _db.Settings.FindAsync(key);
            if (row is null)
            {
                _db.Settings.Add(new SettingEntity { Key = key, Value = raw });
            }
            else
            {
                row.Value = raw;
            }
        }
        await _db.SaveChangesAsync();
        return await GetAllAsync();
    }
}
