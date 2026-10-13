# 开发环境记录（ENV）

实际安装的工具链与版本。换机器/重装时按这份对齐。**全部装在 D 盘，不占 C 盘。**

## 工具链

| 工具 | 版本 | 位置 | 说明 |
| --- | --- | --- | --- |
| .NET SDK | 9.0.318 | `D:\dotnet-sdk` | 电脑端服务编译 |
| dotnet-ef | 9.0.0 | `D:\dotnet-tools` | EF 迁移工具 |
| Flutter SDK | 3.47.7 (Dart 3.13.5) | `D:\flutter` | 手机 App |
| JDK | OpenJDK 17.0.2 | `D:\jdk\jdk-17.0.2` | Gradle 构建必需 |
| Android SDK | Platform 36 + build-tools 35 | `D:\android-sdk` | cmdline-tools 已装 |
| ffprobe | FFmpeg 静态版 | 随服务分发 | 首次运行自动解压到 `%LOCALAPPDATA%\PcVideo\bin\ffprobe\` |

## 环境变量（用户级，已持久化）

| 变量 | 值 |
| --- | --- |
| `FLUTTER_ROOT` | `D:\flutter` |
| `JAVA_HOME` | `D:\jdk\jdk-17.0.2` |
| `ANDROID_HOME` / `ANDROID_SDK_ROOT` | `D:\android-sdk` |
| `PUB_CACHE` | `D:\pub-cache` |
| `GRADLE_USER_HOME` | `D:\gradle` |
| `NUGET_PACKAGES` | `D:\nuget-packages` |
| `PUB_HOSTED_URL` | `https://mirrors.cloud.tencent.com/dart-pub` |
| `FLUTTER_STORAGE_BASE_URL` | `https://mirrors.cloud.tencent.com/flutter` |

## 网络镜像（重要）

本机直连不通国外源，必须走国内镜像：

| 用途 | 可用 | 不可用 |
| --- | --- | --- |
| pub 包 | `mirrors.cloud.tencent.com/dart-pub` | `pub.flutter-io.cn`（包归档返回 301，pub 会卡死） |
| Flutter SDK | `storage.flutter-io.cn` | `storage.googleapis.com`（不通）、GitHub git 协议（克隆卡死） |
| Android SDK | `dl.google.com`（可用） | — |
| JDK | `download.java.net`、`mirrors.tuna.tsinghua.edu.cn/Adoptium` | `api.adoptium.net`（不通） |

## 本机环境适配（换机器可全部丢弃）

本机安全软件拦截 dart 的**命名管道**创建，管道模式 spawn 必失败：

```
CreateFile failed 231 (所有的管道范例都在使用中)
```

由此产生两处必要适配：

1. **`C:\Users\Administrator\AppData\Local\Pub\Cache\hosted\pub.dev\process-5.0.5\lib\src\interface\local_process_manager.dart`**
   改了 `runSync` 和 `run`：用 `cmd /c` + 临时文件重定向 + `.exit` 文件取退出码，绕开 dart 命名管道。
   原文件备份为 `.bak`。
   > 注意：实际加载的是 **C 盘这份**，不是 `PUB_CACHE`（D 盘）里的那份。改错地方不生效。

2. **`app/vendor/` + `pubspec.yaml` 的 `dependency_overrides`**
   dart 官方文档：`sdk: flutter` 依赖需要「pub 运行在 flutter 可执行文件上下文中」才可满足，
   本机这条链路断裂，pub 拒绝一切 Flutter 包。
   解法：SDK 包和全部第三方 Flutter 插件都用 `path` 绑到本地，绕开该判定。
   - SDK 包 → `D:/flutter/packages/...` 和 `D:/flutter/bin/cache/pkg/...`
   - 第三方包 → `app/vendor/<包名>/`（由 `app/tool/vendorize_loop.py` 自动追平依赖图生成）
   - 换到正常机器时可整段删除 `dependency_overrides`，删掉 `app/vendor/`

3. **Flutter 工具另有两处本地补丁**（因 git 版本检测在无管道环境下不可用）：
   - `D:\flutter\packages\flutter_tools\lib\src\version.dart` — FlutterVersion 工厂返回静态版本
   - `D:\flutter\packages\flutter_tools\lib\src\base\os.dart` — `_which` 改纯 Dart PATH 查找（绕过 where.exe）

## 因上述限制暂时移除的功能（换正常环境可加回）

| 包 | 影响的功能 |
| --- | --- |
| `audio_service` | 锁屏/后台继续播放（PRD F-11）。当前 App 退到后台会暂停 |
| `permission_handler` | 通知权限运行时申请（随 audio_service 一起移除） |
| `flutter_displaymode` | 165Hz 高刷请求。App 默认跟随系统刷新率，滑动仍跟手 |

## 构建命令

```bash
# 电脑端服务（发布版）
cd server
dotnet publish PcVideo.Server/PcVideo.Server.csproj -c Release -r win-x64 \
  --self-contained true -p:PublishSingleFile=true \
  -p:IncludeNativeLibrariesForSelfExtract=true -p:EnableCompressionInSingleFile=true \
  -o D:/pcvideo-release

# 手机 App
cd app
flutter pub get          # 首次或依赖变动后（会重新生成 vendor override）
flutter build apk --debug
```

## 本机验证命令

```bash
dotnet --info          # 9.0.318
flutter doctor -v      # Android toolchain 应全绿
adb devices            # 连手机后能识别
```
