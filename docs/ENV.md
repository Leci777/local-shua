# 开发环境记录（ENV）

实际安装的工具链与版本。换机器/重装时按这份对齐。

| 工具 | 版本 | 安装位置 | 说明 |
| --- | --- | --- | --- |
| .NET SDK | 9.0.318 | `D:\dotnet-sdk` | global.json 锁 9.0.100 + latestFeature；dotnet-ef 工具在 `D:\dotnet-tools` |
| Flutter SDK | stable（见 `flutter --version`） | `D:\flutter` | git clone --depth 1 -b stable |
| Android SDK | Platform 36 + build-tools + platform-tools | `D:\android-sdk` | JDK 17 随工具链装到 D 盘 |
| JDK | 17 | `D:\jdk17`（或 Android Studio 自带 JBR） | Flutter Android 构建需要 |
| ffprobe | FFmpeg 官方 Windows 静态构建 | 随服务分发：`server/tools/ffprobe/ffprobe-win-x64.zip` | 来源见该目录 README；首启解压到 `%LOCALAPPDATA%\PcVideo\bin\ffprobe\` |

## 环境变量（都指向 D 盘，不占 C）

| 变量 | 值 | 用途 |
| --- | --- | --- |
| `NUGET_PACKAGES` | `D:\nuget-packages` | NuGet 包缓存 |
| `PUB_CACHE` | `D:\pub-cache` | Dart pub 缓存 |
| `GRADLE_USER_HOME` | `D:\gradle` | Gradle 缓存 |
| `PATH` | 追加 `D:\dotnet-sdk`、`D:\flutter\bin`、`D:\android-sdk\platform-tools`、`D:\dotnet-tools` | 命令行可达 |

## 本机验证命令

```bash
dotnet --info          # 应见 9.0.318
flutter doctor -v      # Android toolchain 全绿
adb devices            # 能识别一加 Ace 6（开发者选项 + USB 调试）
```

## 备注

- WorkBuddy 自带的 managed Python/Node（`C:\Users\Administrator\.workbuddy\binaries\`）不动，与本项目工具链无关。
- 服务数据目录默认 `%LOCALAPPDATA%\PcVideo\`（pcvideo.db、logs、ffprobe 解压产物），appsettings 的 `PcVideo:DataDir` 可改。
- Windows 防火墙首次监听 57821 会弹窗，需放行（README 也写了这一步）。
