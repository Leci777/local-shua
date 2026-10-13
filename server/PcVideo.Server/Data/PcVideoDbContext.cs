using Microsoft.EntityFrameworkCore;
using PcVideo.Server.Data.Entities;

namespace PcVideo.Server.Data;

/// <summary>
/// SQLite 上下文。时间一律 ISO 8601 UTC 字符串存储，客户端不做时区假设。
/// 库文件位置在 Program.cs 装配时决定（%LOCALAPPDATA%\PcVideo\pcvideo.db）。
/// </summary>
public class PcVideoDbContext(DbContextOptions<PcVideoDbContext> options) : DbContext(options)
{
    public DbSet<FolderEntity> Folders => Set<FolderEntity>();
    public DbSet<VideoEntity> Videos => Set<VideoEntity>();
    public DbSet<PlaybackProgressEntity> PlaybackProgress => Set<PlaybackProgressEntity>();
    public DbSet<FavoriteEntity> Favorites => Set<FavoriteEntity>();
    public DbSet<PairedDeviceEntity> PairedDevices => Set<PairedDeviceEntity>();
    public DbSet<SettingEntity> Settings => Set<SettingEntity>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<FolderEntity>(e =>
        {
            e.HasIndex(f => f.Path).IsUnique();
        });

        modelBuilder.Entity<VideoEntity>(e =>
        {
            // file_path 唯一键同时是扫描幂等的基础：重复扫不会产生重复行
            e.HasIndex(v => v.FilePath).IsUnique();
            e.HasIndex(v => v.FolderId);
            e.HasOne(v => v.Folder)
                .WithMany(f => f.Videos)
                .HasForeignKey(v => v.FolderId)
                // 删文件夹 → 其视频级联删除（架构 §2.2）
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<PlaybackProgressEntity>(e =>
        {
            e.HasKey(p => p.VideoId);
            // 历史页按 LastPlayedAt 倒序翻页，建索引
            e.HasIndex(p => p.LastPlayedAt);
            e.HasOne(p => p.Video)
                .WithOne(v => v.Progress)
                .HasForeignKey<PlaybackProgressEntity>(p => p.VideoId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<FavoriteEntity>(e =>
        {
            e.HasKey(f => f.VideoId);
            e.HasIndex(f => f.CreatedAt);
            e.HasOne(f => f.Video)
                .WithMany()
                .HasForeignKey(f => f.VideoId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<PairedDeviceEntity>(e =>
        {
            e.HasIndex(d => d.TokenHash).IsUnique();
        });

        modelBuilder.Entity<SettingEntity>(e =>
        {
            e.HasKey(s => s.Key);
        });
    }
}
