using System.Diagnostics;

namespace PcVideo.Server.Services;

/// <summary>
/// Windows 长路径归一化。超过 260 字符的路径加 \\?\ 前缀——.NET 默认不开启长路径，
/// 真实片库（深层目录 + 长文件名）一定会踩到这个坑。
/// FfprobeRunner 与 VideoStreamService 共用这一个方法，保证两边口径一致。
/// </summary>
public static class PathUtil
{
    public static string NormalizeLongPath(string path)
    {
        if (string.IsNullOrEmpty(path)) return path;
        if (path.StartsWith(@"\\?\", StringComparison.Ordinal)) return path;
        // UNC 长路径用 \\?\UNC\ 前缀；本地路径用 \\?\ 前缀
        if (path.StartsWith(@"\\", StringComparison.Ordinal))
        {
            return @"\\?\UNC\" + path.Substring(2);
        }
        return path.Length >= 260 ? @"\\?\" + path : path;
    }

    /// <summary>入库用的唯一键口径：归一化 + 统一小写盘符（Windows 路径大小写不敏感）。</summary>
    public static string CanonicalKey(string path)
    {
        var normalized = NormalizeLongPath(path);
        if (normalized.Length >= 2 && normalized[1] == ':')
        {
            normalized = char.ToUpperInvariant(normalized[0]) + normalized.Substring(1);
        }
        return normalized;
    }
}
