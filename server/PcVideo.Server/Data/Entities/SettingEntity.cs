namespace PcVideo.Server.Data.Entities;

/// <summary>
/// 用户习惯类设置，key-value，value 存 JSON。
/// 只放「用户会改的」：serverName/defaultSpeed/autoPlayNext/recentExcludeCount/longVideoThresholdSec/downloadLimitGb。
/// 运行参数（扫描并发、ffprobe 超时）归 appsettings.json，不进这里。
/// </summary>
public class SettingEntity
{
    public string Key { get; set; } = string.Empty;
    public string Value { get; set; } = string.Empty;
}
