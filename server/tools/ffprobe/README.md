# ffprobe 放置说明

服务靠 ffprobe 读视频元数据（时长/分辨率/编码/码率），它随服务一起分发，**不占 Git 仓库**。

## 下载

去 FFmpeg 官方 Windows 静态构建二选一：

- https://www.gyan.dev/ffmpeg/builds/ （取 release full 的 7z/zip）
- https://ffmpeg.org/download.html#build-windows （找 Windows builds 链接）

解压后只需要两个东西：`ffprobe.exe` 和同批 DLL（avcodec-*.dll 等，缺了 ffprobe 起不来）。

## 放置

把 `ffprobe.exe` 和所有 DLL 一起打成 zip，命名为：

```
ffprobe-win-x64.zip
```

放到本目录（`server/tools/ffprobe/`）。csproj 发现这个 zip 存在时，会把它作为嵌入资源编进 exe；服务首次启动自动解压到 `%LOCALAPPDATA%\PcVideo\bin\ffprobe-<版本号>\` 再用。

## 没有 zip 会怎样

服务照样启动，但扫描视频时拿不到时长/分辨率，视频会全部标记「可能无法播放」。所以联调前这个 zip 必须就位。

## 兜底（撤销条件，见架构 ADR-06）

若内嵌解压在某些环境下出问题，把 zip 解开，让 `ffprobe.exe` 和发布出来的 exe 放同一目录也行——程序会优先找旁边的。
