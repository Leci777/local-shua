using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;
using PcVideo.Server.Services;

namespace PcVideo.Server.Hosting;

/// <summary>
/// UDP 发现应答：手机连不上时广播「有没有本地刷服务」，这里听到就回一句 {name, port}。
/// 只是省得手输 IP 的辅助手段——部分路由器/ColorOS 会禁广播，失败就手动输地址，
/// 属于已知限制（架构 §3.8）。
/// </summary>
public class DiscoveryResponder : IHostedService, IDisposable
{
    private readonly PcVideoOptions _options;
    private readonly ILogger<DiscoveryResponder> _logger;
    private UdpClient? _client;
    private CancellationTokenSource? _cts;

    public DiscoveryResponder(IOptions<PcVideoOptions> options, ILogger<DiscoveryResponder> logger)
    {
        _options = options.Value;
        _logger = logger;
    }

    public Task StartAsync(CancellationToken cancellationToken)
    {
        _cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        try
        {
            // 绑 0.0.0.0：任何网卡收到的广播都能收到
            _client = new UdpClient(new IPEndPoint(IPAddress.Any, _options.Discovery.UdpPort));
        }
        catch (Exception ex)
        {
            // 端口被占用之类：发现功能不可用而已，主服务不受影响
            _logger.LogWarning(ex, "UDP 发现端口 {Port} 监听失败，自动发现不可用", _options.Discovery.UdpPort);
            _client?.Dispose();
            _client = null;
            return Task.CompletedTask;
        }

        _ = Task.Run(async () =>
        {
            while (!_cts.IsCancellationRequested && _client is not null)
            {
                try
                {
                    var result = await _client.ReceiveAsync();
                    var payload = JsonSerializer.SerializeToUtf8Bytes(new
                    {
                        name = _options.ServerName,
                        port = 57821 // 主服务端口，与 appsettings Urls 一致
                    });
                    await _client.SendAsync(payload, result.RemoteEndPoint);
                }
                catch (ObjectDisposedException)
                {
                    break;
                }
                catch (Exception ex)
                {
                    _logger.LogDebug(ex, "UDP 应答循环出错");
                    await Task.Delay(500, _cts.Token);
                }
            }
        }, _cts.Token);

        _logger.LogInformation("UDP 发现应答已在端口 {Port} 监听", _options.Discovery.UdpPort);
        return Task.CompletedTask;
    }

    public Task StopAsync(CancellationToken cancellationToken)
    {
        _cts?.Cancel();
        _client?.Dispose();
        _client = null;
        return Task.CompletedTask;
    }

    public void Dispose()
    {
        _cts?.Dispose();
        _client?.Dispose();
    }
}
