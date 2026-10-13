# 本地刷（pcvideo）

个人自用：手机像刷抖音一样，上下滑动随机播放**你电脑上自选文件夹**里的视频。仅家庭局域网使用。

```
┌─────────────┐   WiFi    ┌──────────────────────────┐
│  手机 App    │ ───────► │  电脑端服务（ASP.NET Core） │ ──► 你的视频文件夹
│  (Flutter)   │  HTTP    │  端口 57821 + 托盘 + Web 页 │
└─────────────┘           └──────────────────────────┘
```

## 快速开始

### 1. 启动电脑端服务

```bash
cd server
dotnet run --project PcVideo.Server
```

启动后托盘气泡会显示 `http://<电脑IP>:57821` 和一个 6 位配对码（5 分钟有效）。
浏览器打开 `http://localhost:57821` 是管理页：加文件夹、扫描、看配对码。

> 首次启动如果 Windows 防火墙弹窗，选「允许」。

### 2. 手机装 App

App 源码在 `app/`（开发中）。装好后：
1. 手机和电脑连同一个 WiFi
2. 打开 App，输入电脑地址和配对码
3. 开始刷

## 目录

```
pcvideo-app/
├─ docs/          # PRD / 架构 / UI 规范 / ENV
├─ server/        # 电脑端服务（C#，发布成一个自包含 exe）
└─ app/           # 手机 App（Flutter）
```

## 常见问题

- **连不上**：电脑开机了吗、服务启动了吗、手机电脑同一个 WiFi 吗——App 里也有这三步引导。
- **视频标记「可能无法播放」**：ffprobe 读不出该文件信息，格式太偏或文件损坏；播放器仍会尝试播。
- **端口被占用**：改 `server/PcVideo.Server/appsettings.json` 里的 `Urls`。

详细设计见 `docs/PRD.md`（需求）和 `docs/ARCHITECTURE.md`（架构）。
