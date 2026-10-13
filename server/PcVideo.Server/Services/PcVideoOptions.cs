namespace PcVideo.Server.Services;

/// <summary>
/// appsettings PcVideo 节的强类型视图。Program.cs 里绑定，各处注入。
/// </summary>
public class PcVideoOptions
{
    public string ServerName { get; set; } = "我的电脑";
    public string DataDir { get; set; } = string.Empty;

    /// <summary>
    /// 是否要求 token 鉴权。默认 false——个人自用、不对外公布，
    /// 局域网里防的是误连不是恶意，关掉后省掉每请求一次 SQLite 查询（更快更省）。
    /// 想开的话把 appsettings.json 的 PcVideo:RequireToken 改成 true。
    /// </summary>
    public bool RequireToken { get; set; }

    public PairingOptions Pairing { get; set; } = new();
    public ScanOptions Scan { get; set; } = new();
    public DiscoveryOptions Discovery { get; set; } = new();
    public RandomOptions Random { get; set; } = new();

    public class PairingOptions
    {
        public int CodeLength { get; set; } = 6;
        public int CodeTtlSeconds { get; set; } = 300;
    }

    public class ScanOptions
    {
        public string[] Extensions { get; set; } = [".mp4", ".mkv", ".flv", ".avi", ".ts", ".wmv", ".mov", ".rmvb", ".webm", ".m4v", ".mpg", ".mpeg", ".3gp"];
        public int Concurrency { get; set; } = 4;
        public int FfprobeTimeoutSeconds { get; set; } = 15;
    }

    public class DiscoveryOptions
    {
        public int UdpPort { get; set; } = 57822;
    }

    public class RandomOptions
    {
        public int MaxExcludeIds { get; set; } = 50;
        public int DefaultLimit { get; set; } = 20;
    }
}
