using System.Drawing;
using System.Net;
using System.Net.Sockets;
using System.Windows.Forms;
using Microsoft.Extensions.Options;
using PcVideo.Server.Services;

namespace PcVideo.Server.Hosting;

/// <summary>
/// 托盘图标 + 气泡。NotifyIcon 必须跑在 STA 线程的消息循环里（WinForms 的老规矩）。
/// 启动气泡把地址和配对码放大显示——手机配对时照着电脑屏幕输就行（PRD §4.4）。
/// </summary>
public class TrayIconService : IDisposable
{
    private readonly PcVideoOptions _options;
    private readonly PairingService _pairing;
    private readonly AutoStartService _autoStart;
    private readonly IHostApplicationLifetime _lifetime;
    private readonly ILogger<TrayIconService> _logger;

    private Thread? _staThread;
    private NotifyIcon? _notifyIcon;
    private ToolStripMenuItem? _autoStartItem;
    // STA 线程的同步上下文：别的线程要弹气泡，得扔回这个线程执行
    private SynchronizationContext? _uiContext;
    private bool _disposed;

    public TrayIconService(
        IOptions<PcVideoOptions> options,
        PairingService pairing,
        AutoStartService autoStart,
        IHostApplicationLifetime lifetime,
        ILogger<TrayIconService> logger)
    {
        _options = options.Value;
        _pairing = pairing;
        _autoStart = autoStart;
        _lifetime = lifetime;
        _logger = logger;
    }

    public void Start()
    {
        _staThread = new Thread(RunMessageLoop)
        {
            IsBackground = true, // 主进程退出时不拖后腿；正常退出走 StopApplication
            Name = "TrayIconThread"
        };
        _staThread.SetApartmentState(ApartmentState.STA);
        _staThread.Start();
    }

    private void RunMessageLoop()
    {
        _uiContext = SynchronizationContext.Current;
        _notifyIcon = new NotifyIcon
        {
            // 没单独做 .ico 资源，先用系统自带的应用图标；功能不受影响
            Icon = SystemIcons.Application,
            Visible = true,
            Text = $"{_options.ServerName} · 本地刷服务"
        };

        var menu = new ContextMenuStrip();

        var openItem = new ToolStripMenuItem("打开管理页", null, (_, _) => OpenAdminPage());
        var regenItem = new ToolStripMenuItem("重新生成配对码", null, (_, _) => RegenerateCode());
        _autoStartItem = new ToolStripMenuItem("开机自启", null, (_, _) => ToggleAutoStart())
        {
            CheckOnClick = true,
            Checked = _autoStart.IsEnabled()
        };
        var quitItem = new ToolStripMenuItem("退出", null, (_, _) => Quit());

        menu.Items.AddRange(new ToolStripItem[] { openItem, regenItem, _autoStartItem, new ToolStripSeparator(), quitItem });
        _notifyIcon.ContextMenuStrip = menu;

        ShowStartupBalloon();
        Application.Run(); // STA 消息循环，Quit 里 Application.ExitThread 结束它
    }

    /// <summary>启动气泡：地址（所有本机 IPv4）+ 当前配对码。允许从任意线程调用。</summary>
    public void ShowStartupBalloon()
    {
        // NotifyIcon 只能被创建它的 STA 线程操作，跨线程调用要扔回去
        if (_uiContext is not null && SynchronizationContext.Current != _uiContext)
        {
            _uiContext.Post(_ => ShowBalloonCore(), null);
            return;
        }
        ShowBalloonCore();
    }

    private void ShowBalloonCore()
    {
        var addresses = GetLocalIPv4Addresses();
        var addressText = addresses.Count > 0
            ? string.Join(" / ", addresses.Select(a => $"http://{a}:57821"))
            : "没找到本机 IP，看看是不是没连网";
        _notifyIcon?.ShowBalloonTip(
            15000,
            "本地刷服务已启动",
            $"地址：{addressText}\n配对码：{_pairing.CurrentCode}（5 分钟内有效）",
            ToolTipIcon.Info);
    }

    private static List<string> GetLocalIPv4Addresses()
    {
        var result = new List<string>();
        try
        {
            foreach (var address in Dns.GetHostEntry(Dns.GetHostName()).AddressList)
            {
                if (address.AddressFamily == AddressFamily.InterNetwork)
                {
                    result.Add(address.ToString());
                }
            }
        }
        catch
        {
            // 取不到 IP 不阻塞启动，气泡里会给提示
        }
        return result;
    }

    private void OpenAdminPage()
    {
        try
        {
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo("http://localhost:57821")
            {
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "打开管理页失败");
        }
    }

    private void RegenerateCode()
    {
        var code = _pairing.Regenerate();
        _notifyIcon?.ShowBalloonTip(15000, "配对码已更新", $"新配对码：{code}（5 分钟内有效）", ToolTipIcon.Info);
    }

    private void ToggleAutoStart()
    {
        var enabled = _autoStartItem?.Checked ?? false;
        _autoStart.SetEnabled(enabled);
        if (_autoStartItem is not null)
        {
            _autoStartItem.Checked = _autoStart.IsEnabled();
        }
    }

    private void Quit()
    {
        if (_notifyIcon is not null) _notifyIcon.Visible = false;
        _lifetime.StopApplication();
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        try
        {
            _notifyIcon?.Dispose();
            Application.ExitThread();
        }
        catch
        {
            // 退出阶段的清理失败不值得让进程崩
        }
    }
}
