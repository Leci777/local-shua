namespace PcVideo.Server.Hosting;

/// <summary>
/// 单实例保护。第二个实例启动时唤醒第一个实例的托盘气泡，然后自己退出。
/// Mutex 判重 + 命名事件传「醒醒」信号，不引入 IPC 框架。
/// </summary>
public sealed class SingleInstanceGuard : IDisposable
{
    private const string MutexName = @"Local\PcVideo.Server.SingleInstance";
    private const string WakeEventName = @"Local\PcVideo.Server.Wake";

    private readonly Mutex _mutex;
    private readonly EventWaitHandle _wakeEvent;
    private bool _disposed;

    private SingleInstanceGuard(Mutex mutex, EventWaitHandle wakeEvent)
    {
        _mutex = mutex;
        _wakeEvent = wakeEvent;
    }

    /// <summary>尝试成为唯一实例。失败时已经顺手给第一个实例发了唤醒信号。</summary>
    public static bool TryAcquire(out SingleInstanceGuard? guard)
    {
        Mutex? mutex = null;
        bool owned;
        try
        {
            mutex = new Mutex(initiallyOwned: true, MutexName, out owned);
        }
        catch (AbandonedMutexException)
        {
            // 上一个实例异常退出留下了 mutex：算我们拿到
            owned = true;
        }

        if (!owned)
        {
            mutex?.Dispose();
            // 唤醒第一个实例：托盘重新弹气泡
            try
            {
                var existing = EventWaitHandle.OpenExisting(WakeEventName);
                existing.Set();
                existing.Dispose();
            }
            catch
            {
                // 第一个实例没在听就算了，不影响「退出自己」的结论
            }
            guard = null;
            return false;
        }

        var wakeEvent = new EventWaitHandle(false, EventResetMode.AutoReset, WakeEventName);
        guard = new SingleInstanceGuard(mutex!, wakeEvent);
        return true;
    }

    /// <summary>等待唤醒信号（第一个实例用）。返回 false 表示等待结束（取消/出错）。</summary>
    public async Task<bool> WaitForWakeAsync(CancellationToken ct)
    {
        try
        {
            while (!ct.IsCancellationRequested)
            {
                if (_wakeEvent.WaitOne(0)) return true;
                await Task.Delay(TimeSpan.FromSeconds(1), ct);
            }
        }
        catch (OperationCanceledException) { }
        catch (ObjectDisposedException) { }
        return false;
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        _wakeEvent.Dispose();
        _mutex.ReleaseMutex();
        _mutex.Dispose();
    }
}
