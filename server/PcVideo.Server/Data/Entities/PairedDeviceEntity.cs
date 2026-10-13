namespace PcVideo.Server.Data.Entities;

/// <summary>
/// 配对成功的设备。库里只存 token 的 SHA256 哈希——库文件被拷走也还原不出可用 token。
/// 局域网低威胁场景做到这个程度即可，不做过期/刷新（PRD A6）。
/// </summary>
public class PairedDeviceEntity
{
    public int Id { get; set; }
    /// <summary>token 的 SHA256 十六进制小写，唯一。</summary>
    public string TokenHash { get; set; } = string.Empty;
    /// <summary>配对时客户端上报的设备名，如「一加 Ace 6」。</summary>
    public string DeviceName { get; set; } = string.Empty;
    public string CreatedAt { get; set; } = string.Empty;
    public string? LastUsedAt { get; set; }
}
