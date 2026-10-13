using Microsoft.Win32;

namespace PcVideo.Server.Hosting;

/// <summary>
/// 开机自启：写 HKCU\...\Run 当前用户键。零管理员权限——
/// 计划任务需要更高权限，个人工具不值得（架构 ADR-07）。
/// 首次运行（注册表里既没有启用也没有禁用记录）默认开启，对应「默认开机自启」。
/// </summary>
public class AutoStartService
{
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "PcVideo";

    private readonly ILogger<AutoStartService> _logger;

    public AutoStartService(ILogger<AutoStartService> logger)
    {
        _logger = logger;
    }

    /// <summary>当前是否已登记自启。</summary>
    public bool IsEnabled() => ReadValue() is not null;

    private static string? ReadValue()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, writable: false);
        return key?.GetValue(ValueName) as string;
    }

    public void SetEnabled(bool enabled)
    {
        using var key = Registry.CurrentUser.CreateSubKey(RunKeyPath, writable: true);
        if (key is null)
        {
            _logger.LogWarning("打不开开机自启注册表键");
            return;
        }

        if (enabled)
        {
            var exePath = Environment.ProcessPath;
            if (exePath is null) return;
            // 路径带空格必须加引号，否则 Windows 启动时会截断
            key.SetValue(ValueName, $"\"{exePath}\"");
            _logger.LogInformation("已开启开机自启");
        }
        else
        {
            if (key.GetValue(ValueName) is not null)
            {
                key.DeleteValue(ValueName, throwOnMissingValue: false);
            }
            _logger.LogInformation("已关闭开机自启");
        }
    }

    /// <summary>启动时调用：第一次跑（无记录）就默认打开，之后完全听用户的。</summary>
    public void ApplyFirstRunDefault()
    {
        // dotnet run 调试时不碰注册表，免得把调试入口写进开机启动
        if (Environment.ProcessPath is { } exe && exe.Contains("dotnet", StringComparison.OrdinalIgnoreCase))
        {
            return;
        }
        if (ReadValue() is null)
        {
            SetEnabled(true);
        }
    }
}
