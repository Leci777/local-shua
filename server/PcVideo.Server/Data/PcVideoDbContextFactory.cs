using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace PcVideo.Server.Data;

/// <summary>
/// EF 迁移设计时工厂。dotnet ef 直接用它造上下文，
/// 不去执行 Program.cs 的整套宿主装配（托盘、Kestrel 那些设计时不该跑）。
/// 库文件路径与 Program.cs 保持一致：%LOCALAPPDATA%\PcVideo\pcvideo.db。
/// </summary>
public class PcVideoDbContextFactory : IDesignTimeDbContextFactory<PcVideoDbContext>
{
    public PcVideoDbContext CreateDbContext(string[] args)
    {
        var dataDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "PcVideo");
        Directory.CreateDirectory(dataDir);
        var options = new DbContextOptionsBuilder<PcVideoDbContext>()
            .UseSqlite($"Data Source={Path.Combine(dataDir, "pcvideo.db")}")
            .Options;
        return new PcVideoDbContext(options);
    }
}
