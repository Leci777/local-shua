# 编译环境排查结论（2026-10-13）

## 一句话结论

拦截者是 **Windows Defender 的行为监控**，不是火绒（火绒退出后问题依旧）。解除需要**管理员权限**加排除项。

---

## 排查过程

### 依次排除的可能

| 假设 | 验证方式 | 结果 |
| --- | --- | --- |
| 第三方杀软拦截 | 查进程列表 | 查到火绒（HipsDaemon 等 4 个进程），装在 `D:\huorong\Sysdiag` |
| 关掉杀软能解决 | 用户退出全部杀软 + 重启 | ❌ **仍报 231** |
| 只是没退出干净 | `tasklist` 复查 4 个火绒进程 | ✅ 全部已停止，但问题依旧 |
| Dart VM 自身 bug | Node 同机对照 spawn | ❌ **Node 也失败**（两个版本都是 EBUSY） |
| Windows 版本太新 | 查 OS 版本 | ❌ **Win11 Build 22000（21H2）**，Dart 官方支持，无兼容问题 |
| **Defender 行为监控** | `Get-MpComputerStatus` | ✅ **RealTimeProtection=True、BehaviorMonitor=True** |

### 关键证据

同一台机器、同一时刻，三个不同运行时创建管道的结果：

```
Dart VM  : CreateFile failed 231 (ERROR_PIPE_BUSY)
Node 22  : FAIL EBUSY
Node 24  : FAIL EBUSY
```

错误码对应关系：Dart 的 231 与 Node 的 `EBUSY` 是同一个 Windows 错误（`ERROR_PIPE_BUSY`，含义「管道实例都被占用」），说明**这不是某个运行时的实现 bug，而是系统层面所有程序创建管道都受影响**。

Defender 状态：
```
RealTimeProtection: True
BehaviorMonitor   : True
IsTamperProtected : False   ← 好消息：加排除项不需要额外授权，管理员即可
```

---

## 解决步骤（需管理员权限）

右键开始菜单 → 「终端(管理员)」或「PowerShell(管理员)」，粘贴执行：

```powershell
# 排除 Dart / Node 运行时进程
Add-MpPreference -ExclusionProcess "dart.exe"
Add-MpPreference -ExclusionProcess "dartaotruntime.exe"
Add-MpPreference -ExclusionProcess "node.exe"

# 排除工具链目录
Add-MpPreference -ExclusionPath "D:\flutter"
Add-MpPreference -ExclusionPath "D:\pub-cache"
Add-MpPreference -ExclusionPath "D:\android-sdk"
Add-MpPreference -ExclusionPath "D:\jdk"

# 确认
Get-MpPreference | Select-Object ExclusionPath, ExclusionProcess
```

### 如果排除项无效，用更强的开关（临时）

```powershell
Set-MpPreference -DisableRealtimeMonitoring $true
```

编译完恢复：

```powershell
Set-MpPreference -DisableRealtimeMonitoring $false
```

### 验证是否打通

```bash
cd /e/workbuddy/2026-10-12-23-50-24/pcvideo-app/app
/d/flutter/bin/cache/dart-sdk/bin/dart.exe run /d/dl/pipeprobe.dart
```

输出里「start 默认(管道)」应为 `OK`（原本是 `FAIL -> ERROR_PIPE_BUSY`）。

---

## 备选方案（若不便改 Defender）

1. **临时关掉实时防护**（上面的强开关），编译完恢复
2. **换一台机器编译**：代码与配置全部就绪，在干净环境执行
   ```bash
   cd app
   flutter pub get
   flutter build apk --release
   ```
3. **组策略例外**：企业环境可让 IT 把 `D:\flutter` 与开发工具目录加入 Defender 排除列表

---

## 环境现状（已就绪部分）

| 项 | 状态 |
| --- | --- |
| Flutter SDK 3.47.7 / Dart 3.13.5 | ✅ `D:\flutter` |
| JDK 17.0.2 | ✅ `D:\jdk\jdk-17.0.2` |
| Android SDK Platform 36 + build-tools 35 + NDK 28.2 | ✅ `D:\android-sdk` |
| Gradle 9.3.1（腾讯镜像） | ✅ 缓存 944M |
| 依赖解析（`pub get`） | ✅ `.dart_tool/package_config.json` |
| Gradle 构建链路 | ✅ 依赖下载、NDD 安装、libmpv jar 全部跑通 |
| 电脑端服务端 | ✅ 已发布并验证（866 视频） |
| App 源码 | ✅ 37 文件 / 3211 行，已修复 11 类编译错误 |

**唯一缺口**：Dart 编译器启动需要双向管道通信（frontend_server 用 stdin/stdout 传编译协议），这是硬性要求，无法用 inheritStdio 绕过（那是单向输出透传，读不回编译结果）。