# MacFan

macOS 菜单栏系统监控小工具：查看 CPU 占用率、系统温度、风扇转速、内存、磁盘、网速。纯 Swift + AppKit，无第三方依赖，常驻后台（无 Dock 图标），资源占用低（单个 2s 定时器 + 几次系统调用）。

## 功能

- 菜单栏图标（SF Symbol），点击弹出并实时刷新：
  - CPU 占用率（`host_processor_info` 采样差值）
  - 系统温度（Apple Silicon 走 IOHIDEventSystem HID 传感器取最高值；Intel 回退 SMC 温度 key）
  - 风扇转速（SMC `FNum` / `F*Ac`；无风扇机型显示 N/A，风扇停转显示 0 RPM）
  - 内存（`host_statistics64`，口径同活动监视器：App 内存 + 联动 + 压缩）
  - 磁盘（系统卷已用 / 总量）
  - 网速（`getifaddrs` 统计 en* 物理网卡上下行速率；某些 VPN/过滤驱动如 CorpLink 会导致接口入站计数恒为 0，检测到该情况时下行显示 `--` 而非误导性的 0B，入站恢复后自动复原）
- 数据项可勾选：勾选项直接显示在菜单栏，两行式紧凑布局（数值在上、标题在下；网速为上行/下行两行同字号），各项之间竖线分隔，随 2s 定时器实时刷新，选择状态持久化；全部取消勾选时回退为风扇图标
- 风扇转速：菜单栏显示最大转速单值；双风扇机型弹出菜单显示 `Fan1: xxxx | Fan2: xxxx`
- 开机自启动开关（SMAppService，macOS 13+）
- 手动退出（菜单项或 ⌘Q）
- 后台常驻（`LSUIElement`），不出现在 Dock

## 构建

```bash
bash Scripts/build.sh
```

产出 `build/MacFan.app`（release 编译 arm64 + x86_64 universal binary + ad-hoc 签名，签名是开机自启动的前提）。

分发给其他人：ad-hoc 签名不带开发者身份，对方通过浏览器/AirDrop 等渠道下载后首次打开会被 Gatekeeper 拦截，右键 → 打开 确认一次即可（或 `xattr -dr com.apple.quarantine MacFan.app`）；U 盘等本地拷贝无此提示。如需双击即开零警告，需 Apple Developer Program 的 Developer ID 签名 + 公证。

## 安装

```bash
cp -R build/MacFan.app /Applications/
open /Applications/MacFan.app
```

首次开启「开机自启动」需在 系统设置 → 通用 → 登录项 中允许 MacFan。

## 命令行冒烟测试

```bash
swift run MacFan --smoke
# 输出示例：
# CPU: 11.1 %
# 温度: 51.8 °C
# 风扇: 0 / 0 RPM
```

## 卸载

```bash
# 先在菜单中关闭「开机自启动」，然后：
rm -rf /Applications/MacFan.app
```

## 扩展

新增指标只需实现 `MetricProvider` 协议（`func sample() -> String`），并加入 `AppDelegate.providers` 数组。已实现：CPU、温度、风扇、内存、磁盘、网速。

## 系统要求

macOS 13+（SMAppService 依赖）。Apple Silicon 与 Intel 均支持。
