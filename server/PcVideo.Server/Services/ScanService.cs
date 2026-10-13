using System.Collections.Concurrent;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using PcVideo.Server.Data;
using PcVideo.Server.Data.Entities;

namespace PcVideo.Server.Services;

/// <summary>一次扫描的状态快照。Web 页轮询 /scan/latest 看它。</summary>
public class ScanState
{
    public string Status { get; set; } = "running"; // running / done / failed
    public int Found { get; set; }
    public int Added { get; set; }
    public int Removed { get; set; }
    public int Unplayable { get; set; }
    public string? StartedAt { get; set; }
    public string? FinishedAt { get; set; }
    public string? Error { get; set; }
}

/// <summary>
/// 扫描编排：枚举文件 → 对比差异 → 并发 ffprobe → 更新统计。
/// 单文件夹单飞（同时只跑一个）；服务重启中断后下次扫描自动补齐（DB 以 file_path 唯一键幂等）。
///
/// 必须是单例：扫描状态和单飞锁是跨请求的内存态（触发扫描的请求早就返回了，
/// 轮询进度的请求要能看到同一个状态）。数据库访问一律走 scope factory 自建 scope，
/// 不 captive 请求级的 DbContext。
/// </summary>
public class ScanService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly FfprobeRunner _runner;
    private readonly PcVideoOptions _options;
    private readonly ILogger<ScanService> _logger;

    // 每个文件夹一把锁，保证「同文件夹已在扫则拒绝」；不同文件夹可并行
    private readonly ConcurrentDictionary<int, SemaphoreSlim> _folderLocks = new();
    private readonly ConcurrentDictionary<int, ScanState> _latest = new();

    public ScanService(
        IServiceScopeFactory scopeFactory,
        FfprobeRunner runner,
        IOptions<PcVideoOptions> options,
        ILogger<ScanService> logger)
    {
        _scopeFactory = scopeFactory;
        _runner = runner;
        _options = options.Value;
        _logger = logger;
    }

    public ScanState? GetLatest(int folderId) =>
        _latest.TryGetValue(folderId, out var state) ? state : null;

    /// <summary>
    /// 启动一次扫描。同文件夹已在跑返回 null（调用方回 409 scan_in_progress）；
    /// 文件夹不存在返回 false。
    /// </summary>
    public async Task<(bool started, ScanState? state)> TryStartAsync(int folderId)
    {
        // 快速确认文件夹存在（短 scope，用完就放）
        using (var checkScope = _scopeFactory.CreateScope())
        {
            var db = checkScope.ServiceProvider.GetRequiredService<PcVideoDbContext>();
            if (!await db.Folders.AnyAsync(f => f.Id == folderId))
            {
                return (false, null);
            }
        }

        var folderLock = _folderLocks.GetOrAdd(folderId, _ => new SemaphoreSlim(1, 1));
        if (!await folderLock.WaitAsync(TimeSpan.Zero))
        {
            var running = GetLatest(folderId);
            return (false, running?.Status == "running" ? running : new ScanState());
        }

        var state = new ScanState { StartedAt = DateTime.UtcNow.ToString("o") };
        _latest[folderId] = state;

        // 后台跑，HTTP 立刻返回 202
        _ = Task.Run(async () =>
        {
            try
            {
                // 扫描可能跑几分钟，用自己的 scope；文件夹可能在启动后被删，重新取一次
                using var scope = _scopeFactory.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<PcVideoDbContext>();
                var folder = await db.Folders.FindAsync(folderId);
                if (folder is null)
                {
                    state.Status = "failed";
                    state.Error = "文件夹已被删除";
                    return;
                }
                await RunAsync(db, folder, state);
            }
            catch (Exception ex)
            {
                state.Status = "failed";
                state.Error = ex.Message;
                _logger.LogError(ex, "扫描失败：文件夹 {FolderId}", folderId);
            }
            finally
            {
                folderLock.Release();
            }
        });

        return (true, state);
    }

    private async Task RunAsync(PcVideoDbContext db, FolderEntity folder, ScanState state)
    {
        var extensions = _options.Scan.Extensions.ToHashSet(StringComparer.OrdinalIgnoreCase);

        // 1. 枚举磁盘上的视频文件（手动递归，跳过无权限目录——EnumerateFiles 会在整个枚举上抛）
        var onDisk = new List<string>();
        foreach (var file in EnumerateSafe(folder.Path))
        {
            if (extensions.Contains(Path.GetExtension(file))) onDisk.Add(file);
        }
        state.Found = onDisk.Count;

        // 2. 对比 DB 差异。file_path 是唯一键（CanonicalKey 口径），重复扫不产生重复行
        var existing = await db.Videos
            .Where(v => v.FolderId == folder.Id)
            .ToListAsync();
        var byPath = existing.ToDictionary(v => v.FilePath, StringComparer.OrdinalIgnoreCase);

        var diskKeys = new HashSet<string>(onDisk.Select(PathUtil.CanonicalKey), StringComparer.OrdinalIgnoreCase);

        var newFiles = new List<VideoEntity>();
        foreach (var file in onDisk)
        {
            var key = PathUtil.CanonicalKey(file);
            if (byPath.ContainsKey(key))
            {
                // 外接盘重新上线：清 missing 标记
                var row = byPath[key];
                if (row.Missing) row.Missing = false;
                continue;
            }
            newFiles.Add(new VideoEntity
            {
                FolderId = folder.Id,
                FilePath = key,
                FileName = Path.GetFileName(file),
                FileSize = SafeFileSize(file),
                Container = Path.GetExtension(file).ToLowerInvariant(),
                AddedAt = DateTime.UtcNow.ToString("o"),
                UpdatedAt = DateTime.UtcNow.ToString("o"),
            });
        }

        // 消失的文件标 missing，不删数据（PRD R4：外接盘临时离线不能误删）
        var removed = 0;
        foreach (var (key, row) in byPath)
        {
            if (!diskKeys.Contains(key))
            {
                if (!row.Missing)
                {
                    row.Missing = true;
                    removed++;
                }
            }
        }
        state.Removed = removed;

        if (newFiles.Count > 0)
        {
            db.Videos.AddRange(newFiles);
            await db.SaveChangesAsync();
            state.Added = newFiles.Count;

            // 3. 并发 ffprobe 探元数据（默认并发 4，appsettings 可调）
            using var limiter = new SemaphoreSlim(Math.Max(1, _options.Scan.Concurrency));
            var tasks = newFiles.Select(async video =>
            {
                await limiter.WaitAsync();
                try
                {
                    var probe = await _runner.ProbeAsync(video.FilePath);
                    if (probe is null)
                    {
                        video.Unplayable = true;
                    }
                    else
                    {
                        video.DurationSec = probe.DurationSec;
                        video.Width = probe.Width;
                        video.Height = probe.Height;
                        video.VideoCodec = probe.VideoCodec;
                        video.AudioCodec = probe.AudioCodec;
                        video.BitrateKbps = probe.BitrateKbps;
                    }
                }
                finally
                {
                    limiter.Release();
                }
            });
            await Task.WhenAll(tasks);
            await db.SaveChangesAsync();
        }

        // 4. 更新文件夹冗余统计
        var videos = await db.Videos.Where(v => v.FolderId == folder.Id).ToListAsync();
        folder.VideoCount = videos.Count(v => !v.Missing);
        folder.UnplayableCount = videos.Count(v => !v.Missing && v.Unplayable);
        folder.LastScanAt = DateTime.UtcNow.ToString("o");
        state.Unplayable = folder.UnplayableCount;
        await db.SaveChangesAsync();

        state.Status = "done";
        state.FinishedAt = DateTime.UtcNow.ToString("o");
        _logger.LogInformation(
            "扫描完成：文件夹 {Folder}，发现 {Found}，新增 {Added}，消失 {Removed}，无法播放 {Unplayable}",
            folder.Path, state.Found, state.Added, state.Removed, state.Unplayable);
    }

    /// <summary>递归枚举文件，单个目录没权限就跳过，不影响整体。</summary>
    private static IEnumerable<string> EnumerateSafe(string root)
    {
        var pending = new Stack<string>();
        pending.Push(root);
        while (pending.Count > 0)
        {
            var dir = pending.Pop();
            string[] files;
            try
            {
                files = Directory.GetFiles(dir);
            }
            catch (Exception)
            {
                continue; // 无权限/路径不存在：跳过这个目录
            }
            foreach (var f in files) yield return f;

            string[] subDirs;
            try
            {
                subDirs = Directory.GetDirectories(dir);
            }
            catch (Exception)
            {
                continue;
            }
            foreach (var d in subDirs) pending.Push(d);
        }
    }

    private static long SafeFileSize(string path)
    {
        try
        {
            return new FileInfo(path).Length;
        }
        catch
        {
            return 0;
        }
    }
}
