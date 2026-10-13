# ffprobe 放置说明

服务靠 ffprobe 读视频元数据（时长/分辨率/编码/码率），它随服务一起分发，**不占 Git 仓库**。

## 下载

去 FFmpeg 官方 Windows 静态构建二选一：

- https://www.gyan.dev/ffmpeg/builds/ （取 release essentials 的 zip）
- https://ffmpeg.org/download.html#build-windows （找 Windows builds 链接）

**版本说明**：gyan.dev 9.x 的 essentials 构建是静态链接——`bin/` 下只有 `ffmpeg.exe` / `ffplay.exe` / `ffprobe.exe` 三个大文件（各约 105MB），没有 DLL，`ffprobe.exe` 单文件即可运行。早期动态链接构建才需要连 DLL 一起拷。

## 放置

把 `ffprobe.exe` 打成 zip，命名为：

```
ffprobe-win-x64.zip
```

放到本目录（`server/tools/ffprobe/`）。csproj 发现这个 zip 存在时，会把它作为嵌入资源编进 exe；服务首次启动自动解压到 `%LOCALAPPDATA%\PcVideo\bin\ffprobe-<版本号>\` 再用。

## 没有 zip 会怎样

服务照样启动，但扫描视频时拿不到时长/分辨率，视频会全部标记「可能无法播放」。所以联调前这个 zip 必须就位。

## 兜底（撤销条件，见架构 ADR-06）

若内嵌解压在某些环境下出问题，把 zip 解开，让 `ffprobe.exe` 和发布出来的 exe 放同一目录也行——程序会优先找旁边的。
