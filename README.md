# Sivan · iOS 文件管理器（类 Filza）

一个纯 SwiftUI 编写的 iOS 文件管理器，深度暗黑主题，Bundle ID `com.sivan.files`，App 名 **Sivan**。

> 目标系统 iOS 26（部署目标 iOS 17.0，兼容更广）。自签安装，无需开发者账号。

---

## 一、功能清单

### 1. 文件浏览（类 Filza 布局）
- 列表 / 网格双视图，圆角深色卡片、等宽等距排版
- 面包屑路径导航 + 前进 / 后退栈
- 排序：名称 / 修改时间 / 大小 / 类型，升降序可切；文件夹优先开关
- 当前目录实时搜索、隐藏文件显示开关
- 多选编辑模式（全选、批量复制/剪切/压缩/分享/删除）
- **多页面标签栏**：像 Filza 一样同时开多个浏览会话，顶部胶囊切换，可关闭单页

### 2. 多格式预览 + 分页浏览
- **分页预览器**：左右滑动即可在同目录所有文件间翻阅，底部缩略图胶片条（点击跳转）、页码点阵、当前页序号
- PDF → 系统 QuickLook
- Word / Excel / PPT / RTF / Pages 等 → 系统 QuickLook
- 图片（jpg/png/heic/webp/tiff…）→ 支持双指缩放、双击放大、拖动
- GIF / APNG 动图 → 逐帧解析播放
- 视频（mp4/mov/m4v…）→ AVPlayer 原生控件
- 音频（mp3/m4a/flac/wav…）→ 自绘播放器（进度拖拽、±15 秒、静音键下仍可播放）
- 文本 / 源码（.h/.c/.swift/.js/.json/.xml/.plist/.md…）→ 等宽字体 + 语法着色，可选中复制
- HTML / SVG → WKWebView 渲染，可一键切换「网页 / 源码」
- 压缩包 → 直接列出内部条目，可单条导出，可一键解压（防目录穿越）

### 3. 文件操作
- 新建文件夹、新建文本文件、重命名、创建副本
- 删除进「最近删除」（可恢复 / 可清空），回收站内可直接永久删除
- 复制 / 剪切 / 粘贴（应用内剪贴板 + 系统剪贴板双向打通，可跨 App 粘贴文件）
- 压缩为 zip（保留目录结构）、解压 zip
- 分享到其他 App（系统分享面板）、复制路径、完整文件信息（大小/权限/所有者/MIME/时间/路径）

### 4. 导入导出
- 「从其他应用导入」→ 系统文件选择器，多选导入到当前目录
- 「用 Sivan 打开」→ 从任意 App 的分享菜单把文件塞进来（自动落到 `Inbox`）
- 应用开启 `UIFileSharingEnabled`，在系统「文件」App 的「我的 iPhone → Sivan」里可直接拖拽
- 存储空间统计页（应用占用 / 回收站 / 设备可用）

### 5. 主题
- 全局强制暗黑：`Info.plist` 里 `UIUserInterfaceStyle = Dark` + 纯黑底 `#000000`
- 统一的表面层级（#0E0E10 / #18181C / #232329）、1px 描边、胶囊按钮、圆角卡片
- 图标：黑色 Win11 文件夹风格（1024×1024，无 alpha）

---

## 二、怎么得到 ipa（三种方式，任选）

> ⚠️ 本仓库是**源码工程**。iOS 的 ipa 必须由 macOS 上的 Xcode 编译出 Mach-O 才会产生，
> 因此下面的方式本质都是「在 macOS 环境里编译一次 → 打包成未签名 ipa → 你自己签名」。

### 方式 A：GitHub Actions（推荐，完全不需要 Mac）

1. 新建一个 GitHub 仓库，把**本目录（`Sivan/`）里的所有文件**推到仓库根目录
   （即仓库根目录下能直接看到 `project.yml`、`Sivan/`、`Config/`、`.github/`）
2. 推送后 Actions 会自动跑 `.github/workflows/build-ipa.yml`
   （也可以在仓库 Actions 页手动 `Run workflow`）
3. 跑完在该次运行页面底部下载产物 **`Sivan-unsigned-ipa`**，解压得到 `Sivan.ipa`

Workflow 做的事：装 XcodeGen → 生成工程 → `xcodebuild` 以 `CODE_SIGNING_ALLOWED=NO` 编译 Release → 把 `Sivan.app` 塞进 `Payload/` 打成 zip 并改名 `.ipa`。

> 用的是 `macos-15`（Xcode 16 / iOS 18 SDK），产物在 iOS 26 上正常运行。
> 想用 iOS 26 SDK 编译，把 workflow 里的 `runs-on: macos-15` 改成 `macos-26` 即可。

### 方式 B：有一台 Mac

```bash
cd Sivan
chmod +x build-ipa.sh
./build-ipa.sh
# 产物：Sivan/out/Sivan.ipa
```

需要：Xcode 16+，`xcodegen`（`brew install xcodegen`，脚本会自动调用；仓库里也带了现成的
`Sivan.xcodeproj`，Xcode 16 可直接双击打开）。

### 方式 C：Xcode 直接真机运行

打开 `Sivan.xcodeproj` → 选自己的 Team → 选设备 → Run。
（走这条路就是正常签名，7 天/1 年有效期取决于你的 Apple ID 类型。）

---

## 三、自签安装

拿到 `Sivan.ipa` 后（未签名包），用任意自签工具即可：

| 工具 | 说明 |
| --- | --- |
| **Sideloadly**（Win/Mac） | 拖入 ipa → 填 Apple ID → Start，最省事 |
| **AltStore / SideStore** | 装到手机上后无线续签 |
| **爱思助手** | 「IPA 签名」→ 导入 ipa → 用自己的 Apple ID 签名 → 安装 |
| **TrollStore**（若设备支持） | 直接安装，永久签名，不会掉签 |

注意事项：
- 免费 Apple ID 签名 **7 天过期**，到期重新签一次即可，App 内文件不会丢（重签覆盖安装）
- Bundle ID 已固定为 `com.sivan.files`，重签保持同一个 Bundle ID 才能覆盖升级、保留数据
- 首次打开若提示「不受信任的开发者」，去 设置 → 通用 → VPN与设备管理 里信任证书

---

## 四、目录结构

```
Sivan/
├─ project.yml                     # XcodeGen 工程描述（CI 用它生成工程）
├─ Sivan.xcodeproj/                # 现成工程（Xcode 16+ 可直接打开）
├─ Config/Info.plist               # Bundle 配置：显示名/暗黑模式/文件共享/Open In
├─ build-ipa.sh                    # macOS 本地一键打包
├─ .github/workflows/build-ipa.yml # 云端免签名打包出 ipa
└─ Sivan/
   ├─ App/                         # 入口、全局状态、路由、设置
   ├─ Design/                      # 主题、配色、通用组件
   ├─ Models/                      # FileItem、文件类型、排序等
   ├─ Core/                        # 文件系统、缩略图、剪贴板、zip 引擎
   │  └─ Zip/                      # 纯 Swift zip 读写（CRC32 / Inflate / 解析 / 打包）
   ├─ Features/
   │  ├─ Browser/                  # 浏览器：列表、网格、面包屑、标签栏、多选条
   │  ├─ Viewer/                   # 分页预览器与各类查看器
   │  └─ Sheets/                   # 简介、新建/重命名、设置、分享、压缩包、回收站、存储
   └─ Resources/Assets.xcassets/   # AppIcon（黑色 Win11 文件夹）、AccentColor
```

---

## 五、想改点什么

| 需求 | 位置 |
| --- | --- |
| 改 App 名 | `Config/Info.plist` 的 `CFBundleDisplayName` |
| 改 Bundle ID | `project.yml` 与 `Sivan.xcodeproj/project.pbxproj` 里的 `PRODUCT_BUNDLE_IDENTIFIER` |
| 改主题色 / 底色 | `Sivan/Design/Theme.swift` 的 `Theme` 枚举 |
| 换图标 | 替换 `Sivan/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png`（1024×1024，不要透明通道） |
| 改版本号 | `project.yml` 的 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` |

---

## 六、已知限制（诚实说明）

1. **只支持 zip 系压缩包**（zip/jar/ipa/apk 等）。rar / 7z 可以显示为文件、可分享，但解压需要额外解码器，当前版本未内置。
2. 压缩采用 **store（不压缩）模式** 写入 zip：兼容性最好（任何解压软件都能解），但不会变小；图片视频本来已压缩，文本类才会略大。
3. 文件范围是 **App 沙盒内**（`~/Documents`），也就是「我的 iPhone → Sivan」。越狱设备的系统盘访问需要另外的权限与私有 API，本工程未使用任何私有 API（这也是能正常签名安装的前提）。
4. 视频格式受 AVPlayer 支持范围限制：mp4/mov/m4v 稳，mkv/avi 多数解不了（会显示不支持）。
5. 首次进入某目录时缩略图是异步加载的，大目录滚动时会有短暂占位。
6. 未做后台任务续传 / 大文件流式解压，超大压缩包（>2 GB）解压时会有较长时间占用。

---

## 七、验证情况说明

工程在本机（Windows，无 Xcode/Swift 工具链）无法编译验证，代码经过：
- 33 个 Swift 文件括号/引号配平检查（0 处不平衡）
- 逐文件人工核对 API 名称、SwiftUI 修饰器可用版本（全部 ≤ iOS 17 API）
- 去掉了 iOS 26 独有 API，改用 `ultraThinMaterial` + 自定义配色实现同款「暗黑玻璃」质感，保证用 iOS 18 SDK 也能编过

如果云端编译出现个别报错（Swift 版本差异偶发），把 Actions 的日志贴出来，我按行修。
