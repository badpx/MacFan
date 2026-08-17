# MacFan

macOS 菜单栏系统监控小工具：查看 CPU 占用率、系统温度、风扇转速。纯 Swift + AppKit，无第三方依赖，常驻后台（无 Dock 图标），资源占用低（单个 2s 定时器 + 几次系统调用）。

## 功能

- 菜单栏图标（SF Symbol），点击弹出：
  - CPU 占用率（`host_processor_info` 采样差值）
  - 系统温度（Apple Silicon 走 IOHIDEventSystem HID 传感器取最高值；Intel 回退 SMC 温度 key）
  - 风扇转速（SMC `FNum` / `F*Ac`；无风扇机型显示 N/A，风扇停转显示 0 RPM）
- 开机自启动开关（SMAppService，macOS 13+）
- 手动退出（菜单项或 ⌘Q）
- 后台常驻（`LSUIElement`），不出现在 Dock

## 构建

```bash
bash Scripts/build.sh
```

产出 `build/MacFan.app`（release 编译 + ad-hoc 签名，签名是开机自启动的前提）。

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

新增指标只需实现 `MetricProvider` 协议（`func sample() -> String`），并加入 `AppDelegate.providers` 数组。计划扩展：磁盘、内存、网速。

## 系统要求

macOS 13+（SMAppService 依赖）。Apple Silicon 与 Intel 均支持。
