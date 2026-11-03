# Sivan · iOS 文件管理器（类 Filza）

一个纯 SwiftUI 编写的 iOS 文件管理器，Bundle ID `com.sivan.files`，App 名 **Sivan**。
界面自带深 / 浅两套配色，默认跟随 iOS 深色模式。

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
- **分页预览器**：左右滑动只在**同一文件夹、同一类型**的文件之间翻阅（看图只翻图、看视频只翻视频），底部不显示任何文件列表
- **预览页顶栏**：左上「返回」回文件夹，右上「⋯」打开快捷栏
- **快捷栏**：文件属性（名称/大小/类型/时间/位置）+ 快捷操作（分享、从其他 App 导入、复制、复制全文、解压、重命名、复制路径、删除）
- **图库**：识别到图片 / 动图 / 视频时，快捷栏多一个「存入图库」，直接写进系统相册
- PDF → 系统 QuickLook
- Word / Excel / PPT / RTF / Pages 等 → 系统 QuickLook
- 图片（jpg/png/heic/webp/tiff…）→ 支持双指缩放、双击放大、拖动
- GIF / APNG 动图 → 逐帧解析播放
- 视频（mp4/mov/m4v…）→ AVPlayer 原生控件
- 音频（mp3/m4a/flac/wav…）→ 自绘播放器（进度拖拽、±15 秒、静音键下仍可播放）
- 文本 / 源码（.h/.c/.swift/.js/.json/.xml/.plist…）→ 等宽字体 + **按语言语法着色**，可选中复制
- **语法高亮**：按后缀自动识别语言（C / C++ / ObjC / Swift / Java / Kotlin / Go / Rust / Python / JS / TS / JSON /
  HTML / XML / CSS / Shell / SQL / YAML …），关键词加粗、注释斜体；纯文本后缀（txt/log/csv/md…）默认不高亮。
  识别不对时在「⋯」快捷栏里点「语言」手动指定，按后缀记住选择
- **内容搜索**：文本 / 源码 / HTML 源码页右上角放大镜 → 搜索栏带模糊材质底衬、按钮加大，
  支持默认、区分大小写、全字匹配、正则四种规则；命中处高亮、**当前命中整行加淡色底**，
  上一条 / 下一条与结果列表点选都会**精确滚动到那一行并居中**（前后内容不足时自然贴顶 / 贴底）
- HTML / SVG → WKWebView **铺满整屏**（安全区不留黑边），并自动探测网页背景色填充上下边缘；
  右上「⋯」→「预览源代码」切换到源码视图（长按页面也有同样入口），源码模式右下角浮「网页」胶囊切回
- **编辑**：文本 / 源码 / HTML 源码页，右上「⋯」→「编辑」进入编辑模式，顶栏出现「取消 / 保存」；
  保存写回磁盘，新建的空白文本文件打开后**自动进入编辑**，退出预览页自动关闭编辑
- 压缩包 → zip 系直接列出内部条目、可单条导出；rar / 7z 等可一键解压（防目录穿越）

### 3. 文件操作
- 新建文件夹、新建文本文件、重命名、创建副本
- 删除进「最近删除」（可恢复 / 可清空），回收站内可直接永久删除
- **回收站是独立分页**：从文件页滑入的整页列表，带返回键，不是弹窗
- 复制 / 剪切 / 粘贴（应用内剪贴板 + 系统剪贴板双向打通，可跨 App 粘贴文件）
- 压缩为 zip（保留目录结构，唯一压缩格式）
- 解压：**zip / rar / 7z / tar / gz / tgz / bz2 / xz / zst / lz / lzma / cab / iso** 等
- 分享到其他 App（系统分享面板）、复制路径、完整文件信息（大小/权限/所有者/MIME/时间/路径）

### 4. 导入导出
- 「从其他应用导入」→ 系统文件选择器，多选导入到当前目录
- 「用 Sivan 打开」→ 从任意 App 的分享菜单把文件塞进来（自动落到 `Inbox`）
- 应用开启 `UIFileSharingEnabled`，在系统「文件」App 的「我的 iPhone → Sivan」里可直接拖拽
- 存储空间统计页（应用占用 / 回收站 / 设备可用）

### 5. 主题（深 / 浅色自适应）
- `Theme` 里所有颜色都是动态色：深色纯黑 `#000000`、浅色 `#F4F4F7`，切换外观时整棵树立刻重新取色
- 设置 → 外观：**跟随系统 / 浅色 / 深色**；选择「跟随系统」时，打开 iOS 深色模式 App 自动变暗
- 统一的表面层级、1px 描边、胶囊按钮、圆角卡片；代码高亮的配色也分深浅两套
- 启动屏背景色随深浅色切换（Asset 里带 dark 变体）
- 图标：黑色 Win11 文件夹风格（1024×1024，无 alpha）

---

## 二、怎么得到 ipa（三种方式，任选）

> ⚠️ 本仓库是**源码工程**。iOS 的 ipa 必须由 macOS 上的 Xcode 编译出 Mach-O 才会产生，
> 因此下面的方式本质都是「在 macOS 环境里编译一次 → 打包成未签名 ipa → 你自己签名」。

### 方式 A：GitHub Actions（推荐，完全不需要 Mac）

本目录**已经是初始化好的 git 仓库**（分支 `main`，已有首个 commit），只差推到你的 GitHub。

**三步：**

1. 双击上一层的 **`push-to-github.bat`**
   - 脚本会先打开 https://github.com/new ，你建一个**空仓库**（名字随意，比如 `Sivan`）；
     **不要**勾选 README / .gitignore / license（否则会跟本地 commit 冲突）
   - 回到黑窗口，粘贴仓库地址（`https://github.com/你的用户名/Sivan.git`）回车
   - 首次推送会自动弹浏览器让你登录 GitHub，登录完等它推完
2. Actions 自动开始跑 `Build unsigned IPA`（约 3–6 分钟）
3. 跑绿后进入该次运行页面，底部 **Artifacts** 下载 `Sivan-unsigned-ipa`，
   解压得到 `Sivan.ipa`

**如果编译失败**：同一页面底部会有一个 `build-log` 产物（workflow 里专门加了失败时上传日志 + 汇总 `error:` 行），
把里面报错的那几行发给我，我按行改。

**仓库里还有两条回传分支**（CI 自动维护，不用手动碰）：

| 分支 | 内容 | 用途 |
| --- | --- | --- |
| `ci-logs` | `ci-log/errors.txt`（去重后的 `error:` 行）、`ci-log/build.log` | 编译失败时直接看报错，不用登录下载 artifact |
| `build-output` | `dist/Sivan.ipa` + `dist/BUILD-INFO.txt` | 编译成功后直接拿 ipa，浏览器打开该分支点 Download 即可 |

这两条分支都是每次构建 **force push** 覆盖的，只保留最新一次结果，不会无限增长。

> 实测记录：2026-11-03 首次推送后 run #1 失败，报错为 `ImageViewer.swift` 两处
> `extraneous argument label 'url:'`（`ImageLoader.load/animated` 首参数无标签），
> 修正后 run #4 编译通过并产出 `Sivan.ipa`（2.2 MB，arm64，`com.sivan.files`）。


Workflow 做的事：装 XcodeGen → 生成工程 → `xcodebuild` 以 `CODE_SIGNING_ALLOWED=NO` 编译 Release → 把 `Sivan.app` 塞进 `Payload/` 打成 zip 并改名 `.ipa`。

> 用的是 `macos-15`（Xcode 16 / iOS 18 SDK），产物在 iOS 26 上正常运行。
> 想用 iOS 26 SDK 编译，把 workflow 里的 `runs-on: macos-15` 改成 `macos-26` 即可。

**手动推送（不想用脚本时）**：

```bash
cd Sivan
git remote add origin https://github.com/你的用户名/Sivan.git
git branch -M main
git push -u origin main
```

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
├─ Config/Info.plist               # Bundle 配置：显示名/文件共享/Open In/相册权限
├─ build-ipa.sh                    # macOS 本地一键打包
├─ .gitattributes                  # 强制 LF（否则 Windows 推送后 shell 脚本会在 macOS 报 bad interpreter）
├─ .github/workflows/build-ipa.yml # 云端免签名打包出 ipa（失败时同时上传日志）
├─ tools/                          # 自检脚本：Swift 语法树检查、括号配平
└─ Sivan/
   ├─ App/                         # 入口、全局状态、路由、设置
   ├─ Design/                      # 主题、配色、通用组件
   ├─ Models/                      # FileItem、文件类型、排序等
   ├─ Core/                        # 文件系统、缩略图、剪贴板、zip 引擎
   │  └─ Zip/                      # 纯 Swift zip 读写（CRC32 / Inflate / 解析 / 打包）
   ├─ Features/
   │  ├─ Browser/                  # 浏览器：列表、网格、面包屑、标签栏、多选条
   │  ├─ Viewer/                   # 分页预览器、快捷栏、各类查看器
   │  ├─ Trash/                    # 最近删除（独立分页）
   │  └─ Sheets/                   # 简介、新建/重命名、设置、分享、压缩包、存储
   └─ Resources/Assets.xcassets/   # AppIcon（黑色 Win11 文件夹）、AccentColor
```

> 本目录已 `git init` 并完成首个 commit（分支 `main`），可直接推送。

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

1. **压缩只出 zip**（按需求保留）。解压支持 zip 系与 rar / 7z / tar / gz / bz2 / xz / zst / cab / iso 等，
   其中 zip 系走工程自带的纯 Swift 实现，其余由 libarchive 完成（静态链接，见 `THIRD-PARTY-LICENSES.md`）。
   **带密码的压缩包暂不支持**（会提示「压缩包已加密」）。
2. 压缩采用 **store（不压缩）模式** 写入 zip：兼容性最好（任何解压软件都能解），但不会变小；图片视频本来已压缩，文本类才会略大。
3. 文件范围是 **App 沙盒内**（`~/Documents`），也就是「我的 iPhone → Sivan」。越狱设备的系统盘访问需要另外的权限与私有 API，本工程未使用任何私有 API（这也是能正常签名安装的前提）。
4. 视频格式受 AVPlayer 支持范围限制：mp4/mov/m4v 稳，mkv/avi 多数解不了（会显示不支持）。
5. 首次进入某目录时缩略图是异步加载的，大目录滚动时会有短暂占位。
6. 未做后台任务续传 / 大文件流式解压，超大压缩包（>2 GB）解压时会有较长时间占用。

---

## 七、验证情况说明

工程在本机（Windows，无 Xcode/Swift 工具链）无法编译验证，代码经过：
- **已在 GitHub Actions（macos-15 / Xcode 16）真实编译通过**，产出未签名 ipa，Mach-O 为 arm64 `MH_EXECUTE`
- **tree-sitter Swift 语法树全量解析**：33 个文件 0 个 `ERROR` / `MISSING` 节点（`tools/swift_syntax_check.py`）
- 括号/引号配平检查（`tools/check_balance.py`）
- `Info.plist` / `project.yml` / workflow YAML / Asset `Contents.json` 全部通过解析校验
- 逐文件人工核对 API 名称、SwiftUI 修饰器可用版本（全部 ≤ iOS 17 API）
- 去掉了 iOS 26 独有 API，改用 `ultraThinMaterial` + 自定义配色实现同款「暗黑玻璃」质感，保证用 iOS 18 SDK 也能编过
- `SWIFT_VERSION = 5.0` + `SWIFT_STRICT_CONCURRENCY = minimal`，避免 Swift 6 严格并发检查把警告升级成错误

首次云端编译暴露过 2 个类型错误（`ImageLoader` 首参数无标签，调用处误带了 `url:`），已修正。
**运行时行为（界面、手势、解压、预览的实际情况）未在真机上验证过** —— 本机没有 iOS 设备也无法运行模拟器，
所以装到手机上后如果哪个功能不对，把现象告诉我。

如果云端编译出现个别报错（Swift 版本差异偶发），把 Actions 的日志贴出来，我按行修。
