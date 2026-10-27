# MenuGauge

MenuGauge 原名 MacFan。Bundle ID 仍是 `com.badpx.macfan`，GitHub 仓库与官网仍是 [badpx/MacFan](https://github.com/badpx/MacFan)、[badpx.github.io/MacFan](https://badpx.github.io/MacFan/)。

macOS 菜单栏系统监控小工具：查看 CPU / GPU 占用率、系统温度、风扇平均转速、内存、磁盘、网速。Swift + AppKit / SwiftUI 原生界面，无第三方依赖，常驻后台（无 Dock 图标），使用单个 2s 定时器采样。

## 功能

- 点击菜单栏图标打开原生弹出面板，保留「系统概览 / 菜单栏设置」两个标签页；右上角显示「每 2 秒更新」。支持浅色 / 深色外观，小屏内容可滚动，点击外部、再次点击图标或按 Esc 关闭。
- 系统概览按处理器、内存与存储、温度与散热、网络分组，数值等宽显示，比例条直接使用结构化数据：
  - CPU 占用率（`host_processor_info` 采样差值）
  - CPU 温度（Apple Silicon 按 M1–M5 芯片系列选择 SMC 传感器，与 Lemon 5.3.7 使用相同列表，仅对 `20 < 温度 < 110°C` 的有限有效读数求平均；读取失败不计入分母，无有效读数或未知芯片显示不可用。Intel 按 CPU SMC key 优先级读取首个有效值。不再用 PMU 等 HID 读数代替 CPU 温度）
  - 风扇转速（SMC `FNum` / `F*Ac`；无风扇机型显示 N/A，风扇停转显示 0 RPM）
  - 内存（`host_statistics64`，口径同活动监视器：App 内存 + 联动 + 压缩）
  - 磁盘（系统卷已用 / 总量）
  - 网速（`getifaddrs` 统计 en* 物理网卡上下行速率；某些 VPN/过滤驱动如 CorpLink 会导致接口入站计数恒为 0，检测到该情况时下行显示 `--` 而非误导性的 0B，入站恢复后自动复原）
- 在「菜单栏设置」标签页切换指标开关，选择状态持久化并兼容原有选择；概览始终显示所有指标。开启任一指标后，菜单栏只显示两行文字；全部关闭时才显示实时仪表（热状态决定点亮的弧段，CPU 占用决定指针），和以前的风扇图标一样。空间不足时从右侧自动隐藏 / 恢复。
- 风扇转速：面板和菜单栏统一显示所有风扇的平均值，四舍五入到整数 RPM；0 读数参与平均，任一所需读数缺失时显示不可用，不再分别显示 F1 / F2 或取最大值。
- 温度达到 75 °C、内存 / 磁盘达到 80% 时，指标颜色从橙色连续向红色增强；分别在 85 °C、90% 达到上限，保留文字提示。
- 温度口径与 [Lemon 的传感器配置](https://github.com/Tencent/lemon-cleaner/blob/master/Tools/LemonDaemon/LemonDaemon/Monitor/SMC/CmcTemperature.m) 对齐：M1 Pro/Max/Ultra、M2、M3 的列表包含部分 GPU 传感器；M4、M5 列表不包含 GPU。不同工具的采样时刻不同，瞬时显示仍可能略有差异。
- 开机自启动开关（SMAppService，macOS 13+）；需要系统批准时提供系统设置入口，失败时显示原因并保持真实状态。
- 手动退出（面板底部或 ⌘Q），带确认对话框，取消后返回面板。
- 后台常驻（`LSUIElement`），不出现在 Dock

## 构建

```bash
bash Scripts/build.sh
```

产出 `build/MenuGauge.app`（release 编译 arm64 + x86_64 universal binary + ad-hoc 签名，签名是开机自启动的前提）。版本号和构建号由脚本写入，未指定时为 `1.0`（build `1`）。MenuGauge 的第一个发行版是 `1.0`，对应 GitHub 标签 `v1.0` 和附件 `MenuGauge-v1.0.dmg`。已经发出的标签不要删除或改名。

这条本地包仍是 ad-hoc 签名。发给别人用的公证 DMG，以及 Mac App Store 的沙盒 pkg，见 [docs/Release.md](docs/Release.md)（中英）。ad-hoc 包通过浏览器或隔空投送下载后，首次打开会被 Gatekeeper 拦截，右键 → 打开 确认一次即可（或 `xattr -dr com.apple.quarantine MenuGauge.app`）；U 盘等本地拷贝无此提示。

App Store 版在编译期去掉 AppleSMC。CPU 温度改为系统热状态，面板、菜单栏和设置里都没有风扇项；若本机以前存过 `menuBarMetrics` 里的 `fan`，启动时会去掉。直接分发的 DMG 仍读取 SMC 风扇转速和 CPU 温度。

## 安装

```bash
cp -R build/MenuGauge.app /Applications/
open /Applications/MenuGauge.app
```

首次开启「开机自启动」需在 系统设置 → 通用 → 登录项 中允许 MenuGauge。登录项是 `SMAppService.mainApp`，身份是 bundle id `com.badpx.macfan`。

## 命令行冒烟测试

```bash
swift run MenuGauge --smoke
# 输出示例：
# CPU: 11.1 %
# 温度: 51.8 °C
# 风扇: 0 RPM
```

## 验证与原生界面快照

```bash
swift test
swift run MenuGauge --ui-snapshot build/ui-check -AppleLanguages '(zh-Hans)'
```

快照模式仅包含在 debug 构建中，使用固定示例数据生成浅色、深色、设置页、告警、不可用和小屏状态图片，不读取传感器、不改写指标选择或开机自启动。实际应用仅在面板打开时向 SwiftUI 发布采样结果；菜单栏继续使用单视图绘制。

## 应用图标

应用图标是青绿色圆角方块上的白色仪表：左段实心、右段描边，指针指向右上。菜单栏里的图标是同一套造型的模板图像，随 CPU 占用和系统热状态变化，不再使用风扇符号。

macOS 26 会对旧式 ICNS 自动添加玻璃高光和浮雕。因此打包使用 Xcode 26+ 编译 `Resources/MenuGaugeFlat.icon`，明确关闭图层玻璃材质、高光、阴影和半透明；macOS 13–15 继续使用 ICNS。生成器同时输出不带外部留白的 Icon Composer 画稿，由系统提供圆角遮罩。不要只复制 ICNS 来替代完整打包。1024px 预览在 `Design/MacFan-UI/MenuGauge-AppIcon.png`。

```bash
swift Scripts/generate_icon.swift
iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
bash Scripts/build.sh
```

没有 Swift 时可以用 `python3 Scripts/render_icon.py` 写出同一套 iconset、icns、favicon 和预览。两份脚本的弧度、间距和指针角度要一起改。

## 卸载

```bash
# 先在菜单中关闭「开机自启动」，然后：
rm -rf /Applications/MenuGauge.app
```

## 扩展

新增指标只需实现 `MetricProvider` 协议（`func sample() -> String`），并加入 `AppDelegate.providers` 数组。已实现：CPU、温度、风扇、内存、磁盘、网速。

## 系统要求

macOS 13+（SMAppService 依赖）。Apple Silicon 与 Intel 均支持。
