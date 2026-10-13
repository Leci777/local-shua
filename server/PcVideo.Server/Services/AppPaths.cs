namespace PcVideo.Server.Services;

/// <summary>
/// 全程序共用的路径口径：数据目录、库文件、日志、ffprobe 解压位置。
/// appsettings 的 PcVideo:DataDir 可改；为空则用 %LOCALAPPDATA%\PcVideo。
/// </summary>
public static class AppPaths
{
    public static string DataRoot(PcVideoOptions options)
    {
        if (!string.IsNullOrWhiteSpace(options.DataDir)) return options.DataDir;
        return Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "PcVideo");
    }

    public static string DbFile(PcVideoOptions options) =>
        Path.Combine(DataRoot(options), "pcvideo.db");

    public static string LogsDir(PcVideoOptions options) =>
        Path.Combine(DataRoot(options), "logs");

    public static string FfprobeDir(PcVideoOptions options) =>
        Path.Combine(DataRoot(options), "bin", "ffprobe");

    public static string FfprobeExe(PcVideoOptions options) =>
        Path.Combine(FfprobeDir(options), "ffprobe.exe");
}
