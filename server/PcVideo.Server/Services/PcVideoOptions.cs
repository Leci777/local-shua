namespace PcVideo.Server.Services;

/// <summary>
/// appsettings PcVideo 节的强类型视图。Program.cs 里绑定，各处注入。
/// </summary>
public class PcVideoOptions
{
    public string ServerName { get; set; } = "我的电脑";
    public string DataDir { get; set; } = string.Empty;

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
