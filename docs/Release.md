# 发布 MenuGauge

显示名称是 **MenuGauge**（原名 MacFan），网站 DMG 和 Mac App Store 都用这个名字。Bundle ID 仍是 `com.badpx.macfan`。GitHub 仓库与 Pages 地址不变。App Store Connect 记录已经建好：名称 MenuGauge，App ID `6827516123`，SKU `menu_gauge`，主语言 English (U.S.)。

两种发行物都由 `Scripts/build.sh` 完成：SwiftPM 编译，再手工组装 `.app`。仓库里没有 `.xcodeproj` / `.xcworkspace`，也不要加。

| 命令 | 给谁用 | 产物 |
| --- | --- | --- |
| `bash Scripts/build.sh` | 自己本机安装 | `build/MenuGauge.app`，ad-hoc 签名 |
| `bash Scripts/build.sh dmg` | 网站 / GitHub Release | `build/MenuGauge-v<版本>.dmg`，Developer ID + 公证 + 装订 |
| `bash Scripts/build.sh appstore` | Mac App Store | `build/MenuGauge-v<版本>.pkg`，沙盒 |

`bash Scripts/build.sh --help` 列出全部参数。身份、Team ID、描述文件、版本和公证凭据只来自环境变量或参数，仓库里不写死。`.p8` 和 `.provisionprofile` 已被 gitignore，不要提交。

## 版本号

`CFBundleShortVersionString` 和 `CFBundleVersion` 不在 `Resources/Info.plist` 里写死，打包时由脚本写入已组装的 Info.plist。

- `MACFAN_VERSION` 或 `--version`：MenuGauge 的发行版本用两段，例如 `1.0`。`1.0` 是这个产品的第一个发行版。GitHub Release 标签是 `v1.0`，附件名是 `MenuGauge-v1.0.dmg`。`CFBundleShortVersionString` 和文件名都按传入的字符串原样写入。脚本仍接受三段式（例如 `1.0.0`），以免已有命令失效。不要删除或改名已经发出的标签。
- `MACFAN_BUILD` 或 `--build`：非负整数，不要前导零。App Store 每次上传都要更大。
- `dmg` 和 `appstore` 必须显式给出这两项。
- 本地 `Scripts/build.sh` 省略时默认为 `1.0`（build `1`）。

`MACFAN_BUNDLE_ID`（`--bundle-id`）默认 `com.badpx.macfan`。描述文件、App Store Connect 记录和这里必须一致。

## 网站 / GitHub：DMG

直接分发的包**不沙盒**，仍通过 AppleSMC 读风扇转速和 CPU 温度，和现在的 ad-hoc 包行为一致。公证要求 Hardened Runtime 和安全时间戳；这不会挡住 SMC。

### 准备

1. Apple Developer Program。
2. 钥匙串里的 **Developer ID Application** 证书。名字用下面命令原样复制，形如 `Developer ID Application: 名字 (TEAMID)`：

   ```bash
   security find-identity -v -p codesigning
   ```

3. 公证二选一：
   - App Store Connect API 密钥（Users and Access → Integrations → App Store Connect API）。角色至少 Developer。下载一次 `.p8`。
   - 或事先写入钥匙串的 notarytool profile。

   三项都设置时脚本用 API 密钥，不再看 profile。只用 profile 时不要导出 `NOTARY_KEY_PATH` / `NOTARY_KEY_ID` / `NOTARY_ISSUER`。

   ```bash
   xcrun notarytool store-credentials "MenuGauge-Notary" \
     --key "$NOTARY_KEY_PATH" \
     --key-id "$NOTARY_KEY_ID" \
     --issuer "$NOTARY_ISSUER"
   ```

钥匙串要处于解锁状态（`security unlock-keychain`）。可选 `MACFAN_KEYCHAIN` 指向某个钥匙串文件。

### 命令

```bash
export DEVELOPER_ID_APPLICATION="Developer ID Application: 名字 (TEAMID)"
export NOTARY_KEY_PATH="$HOME/private_keys/AuthKey_XXXXXXXXXX.p8"
export NOTARY_KEY_ID="XXXXXXXXXX"
export NOTARY_ISSUER="00000000-0000-0000-0000-000000000000"
export MACFAN_VERSION="1.0"
export MACFAN_BUILD="4"
bash Scripts/build.sh dmg
```

只用钥匙串 profile：

```bash
export DEVELOPER_ID_APPLICATION="Developer ID Application: 名字 (TEAMID)"
export NOTARY_KEYCHAIN_PROFILE="MenuGauge-Notary"
export MACFAN_VERSION="1.0"
export MACFAN_BUILD="4"
bash Scripts/build.sh dmg
```

### 脚本做的事

1. `swift build -c release --arch arm64` 与 `x86_64`（`--build-system native`），**不**定义 `MAS`。产物放在 `build/spm-direct`，避免和 App Store 编译混用对象文件。
2. `lipo` 成通用二进制，并确认两个切片都引用了 `_IOServiceOpen`、二进制里有 `AppleSMC` 字面量，且没有私有的 `IOHIDEventSystemClientCreate`。
3. 组装 `.app`：`actool` 编译 `Resources/MenuGaugeFlat.icon`（macOS 26 的扁平图标；macOS 13–15 仍用 ICNS）、拷贝 `PrivacyInfo.xcprivacy`、写入版本号。
4. 用 Developer ID Application 签名，`--options runtime --timestamp`。没有沙盒，也没有额外 entitlements。
5. 做 UDZO 磁盘映像，卷名是 MenuGauge，卷内是 `MenuGauge.app` 和指向 `/Applications` 的替身，再用同一身份给 dmg 签名。
6. `xcrun notarytool submit --wait`，然后 `xcrun stapler staple` 与 `stapler validate`。

产物：`build/MenuGauge-v1.0.dmg`。GitHub Release 的标签是 `v1.0`，附件名是 `MenuGauge-v1.0.dmg`。`1.0` 是 MenuGauge 的第一个发行版。官网优先用 `MenuGauge-<标签>.dmg`，其次同名 zip。已经发布的标签保持不动。若最新 Release 仍是三段式标签，或 `MacFan-v<版本>.dmg` / `.zip`，官网构建也会接受，这样在换成 `v1.0` 之前站点不会中断。`website/release.json` 仍指向那份旧快照，等决定替换后再改。

装订打在 dmg 上。用户把 app 拖进「应用程序」后，Gatekeeper 用 Apple 保存的票据在线校验；离线首次打开仍建议机器曾经联网完成过公证检查。

## Mac App Store：pkg

沙盒会拒绝 AppleSMC 用户客户端。`com.apple.security.temporary-exception.iokit-user-client-class` 是已知的审核拒绝项，所以 **App Store 版在编译期去掉 SMC**，不申请这个例外。

`swift build` 额外传入 `-Xswiftc -DMAS`。`SMC.swift` 整份在 `#if !MAS` 里。CPU 温度改为 `ProcessInfo.thermalState`。风扇指标不进入这个版本：

- 弹出面板的大号温度位显示本地化的热状态（正常 / 偏高 / 过热 / 危急，以及其余语言），标题改为「热状态」，不再显示 °C。
- 概览没有风扇一行，设置里也没有风扇开关。已保存的 `menuBarMetrics` 若包含 `fan`，启动时去掉，避免计数和降级逻辑把它算进去。
- 菜单栏用固定短词 `OK` / `MID` / `HOT` / `MAX`，避免长翻译把状态项撑宽。温度在下标 `TEMP`。
- `MenuGauge --fandump` 在这个二进制里直接退出。

CPU、GPU、内存、磁盘、网速的采样代码不变。GPU 只读 `IOAccelerator` 的公开注册表属性，不 `IOServiceOpen`。沙盒里如果读不到，界面本来就会显示 `--`，不要为此加临时例外。

未使用的 `Sources/MenuGauge/System/HIDSensors.swift` 已删除。它用 `dlsym` 找私有的 `IOHIDEventSystemClient*`，两个发行物都不能带。

### 准备

1. **Apple Distribution** 证书（给 .app 签名）和 **Mac Installer Distribution** 证书（给 pkg 签名）。钥匙串里的通用名必须和参数完全一致。较老的证书可能仍叫 `3rd Party Mac Developer Application` / `3rd Party Mac Developer Installer`，用钥匙串里的原文字符串：

   ```bash
   security find-identity -v -p codesigning   # Apple Distribution
   security find-identity -v                   # Mac Installer Distribution 不一定出现在 codesigning 策略里
   ```

2. Team ID，10 位，`APPLE_TEAM_ID` 或 `--team-id`。
3. App Store Connect 里已有的 macOS App「MenuGauge」（App ID `6827516123`，SKU `menu_gauge`，主语言 English (U.S.)）。bundle id 与 `MACFAN_BUNDLE_ID` 一致，不要新建另一条记录。App ID 打开 App Sandbox，不要打开 IOKit user client。
4. 对应的 Mac App Store **Distribution** 描述文件。脚本会解码它，核对 `com.apple.application-identifier` 等于 `TEAMID.bundleid`（Apple 的格式：Team ID、一个点、bundle id）、team id 一致，并拒绝带 `iokit-user-client-class` 的描述文件。发行描述文件的 Entitlements 不含沙盒是正常的。沙盒必须在 `Resources/MacFan-MAS.entitlements` 里为 true，签名后再用 `codesign -d --entitlements :-` 确认。

签名用的 entitlements 只有这三项（`Resources/MacFan-MAS.entitlements`，Team ID 和 bundle id 由脚本填入）：

- `com.apple.security.app-sandbox`
- `com.apple.application-identifier`（`TEAMID.com.badpx.macfan`）
- `com.apple.developer.team-identifier`

没有网络客户端、文件访问或 IOKit 例外：UserDefaults、卷容量、`getifaddrs` 和 `SMAppService.mainApp` 都不需要额外 entitlement。

### 命令

```bash
export APPLE_TEAM_ID="TEAMID"
export APPLE_DISTRIBUTION_IDENTITY="Apple Distribution: 名字 (TEAMID)"
export MAC_INSTALLER_DISTRIBUTION_IDENTITY="Mac Installer Distribution: 名字 (TEAMID)"
export MACFAN_PROVISIONING_PROFILE="$HOME/Downloads/MenuGauge_Mac_AppStore.provisionprofile"
export MACFAN_VERSION="1.0"
export MACFAN_BUILD="2"
bash Scripts/build.sh appstore
```

`1.0` 的构建号 `1` 已经被 App Store Connect 拒绝（ITMS-90236，缺少 512pt @2x 图标）。下一次上传必须用 `--build 2`（或 `MACFAN_BUILD=2`），不要再传 `1`。

### 脚本做的事

1. 在 `build/spm-mas` 里以 `-DMAS` 编译两个架构并 `lipo`。两个切片都不得引用 `_IOServiceOpen`，二进制里不得有 `AppleSMC` 或 `IOHIDEventSystemClientCreate`。
2. 组装 `build/MenuGauge-MAS.app`，写入版本号。DMG 仍只编译 `MenuGaugeFlat.icon`（回退位图关闭，macOS 13–15 继续用 ICNS）。App Store 包在同一个 `.icon` 前面再交给 `actool` 一套位图 `MenuGaugeFlat.appiconset`（16、32、128、256、512 的 @1x/@2x，其中 512@2x 是 1024px），并用 `--include-all-app-icons` 写进 `Assets.car`。编译后若没有名为 `MenuGaugeFlat`、Scale 为 2、像素为 1024 的 Icon Image，脚本直接失败。`CFBundleIconName` 与 `CFBundleIconFile` 都是 `MenuGaugeFlat`。
3. 把描述文件放到 `Contents/embedded.provisionprofile`，再签名。签名在拷贝描述文件之后，这样签名覆盖它。
4. `codesign --options runtime --timestamp --generate-entitlement-der`，身份是 Apple Distribution。签名前确认 entitlements 里沙盒为 true。然后 `codesign --verify --strict`，并用 `codesign -d --entitlements :-` 确认签进 app 的沙盒为 true。
5. `productbuild --component build/MenuGauge-MAS.app /Applications --product … --sign "Mac Installer Distribution: …"`。requirements 里的最低系统版本来自 Info.plist 的 `LSMinimumSystemVersion`（13.0），架构包含 `arm64` 和 `x86_64`（避免安装器只在 Rosetta 下评估）。
6. `pkgutil --check-signature`。

产物：`build/MenuGauge-v1.0.pkg` 和 `build/MenuGauge-MAS.app`。本地 ad-hoc / DMG 用的是 `build/MenuGauge.app`，两条命令不会互相覆盖 app 包。

### 上传（默认关闭）

需要 App Store Connect 里已经建好的 app。`--apple-id` 是 App Information 里的数字 Apple ID，不是开发者账号。API 密钥角色需要能上传构建版本（App Manager 或 Admin）。公证用的 Developer 密钥不一定够，可以另给 `ASC_KEY_*`；省略时回退到 `NOTARY_KEY_*`。

```bash
export ASC_KEY_ID="XXXXXXXXXX"
export ASC_ISSUER_ID="00000000-0000-0000-0000-000000000000"
export ASC_KEY_PATH="$HOME/private_keys/AuthKey_XXXXXXXXXX.p8"
export ASC_APP_APPLE_ID="1234567890"
# 账号挂了多个 provider 时才需要：
# export ASC_PUBLIC_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
bash Scripts/build.sh appstore --upload
```

脚本把 `.p8` 复制到临时目录并命名为 `AuthKey_<id>.p8`，通过 `API_PRIVATE_KEYS_DIR` 传给 altool，上传结束就删掉。不会把密钥内容打进日志。

```bash
xcrun altool --upload-package MenuGauge-v1.0.pkg -t osx \
  --apple-id "$ASC_APP_APPLE_ID" \
  --bundle-id "$MACFAN_BUNDLE_ID" \
  --bundle-short-version-string "$MACFAN_VERSION" \
  --bundle-version "$MACFAN_BUILD" \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID" \
  --show-progress
```

账号有多个 provider 时再加 `--asc-public-id`。若本机 `xcrun altool --help` 里已经没有 `--upload-package`，以帮助文本为准，不要改用已废弃的 `--upload-app`。

## 隐私清单

`Resources/PrivacyInfo.xcprivacy` 打进 `Contents/Resources/`，两个发行物都有。应用不追踪、不收集数据。

| API | 原因 | 依据 |
| --- | --- | --- |
| UserDefaults | `CA92.1` | 只读写本应用自己的 `menuBarMetrics` |
| 磁盘空间 | `85F4.1` | `volumeAvailableCapacityForImportantUsage` 用来在界面上显示系统卷占用，数据不出设备 |

`volumeTotalCapacity` 不在 Apple 的必填原因列表里。代码没有文件时间戳、开机时间或活跃键盘 API。`DiskMonitor` 的注释里提到 `statfs`，但并没有调用它。

## Info.plist

源 plist 增加了：

- `LSApplicationCategoryType` = `public.app-category.utilities`
- `ITSAppUsesNonExemptEncryption` = false（没有自有加密）
- `CFBundleLocalizations`：`en`、`zh-Hans`、`zh-Hant`、`ja`、`ko`、`hi`、`es`、`fr`、`bn`、`ru`、`pt`（与 `L10n.swift` 的 11 种语言一致）

`LSUIElement` 仍为 true：菜单栏应用，没有 Dock 图标。

## 在 Mac 上确认

这台环境是 Linux，不能跑 Swift 工具链。合并前请在装有 Xcode 26 命令行工具的 Mac 上做这些事：

1. `swift test`。
2. `bash Scripts/build.sh`，把 `build/MenuGauge.app` 拷到 `/Applications` 再打开。风扇转速和 CPU 温度仍来自 SMC；开机自启动仍要在系统设置里批准；图标在 macOS 26 上保持扁平，在 13–15 上仍是 ICNS。
3. `bash Scripts/build.sh dmg`（用上面的身份和公证变量）。`codesign -dv --verbose=4 build/MenuGauge.app` 应显示 Developer ID、runtime、timestamp。公证和 `stapler validate` 由脚本执行，失败即非零退出。打开 dmg，把 app 拖进「应用程序」，Gatekeeper 不应再要求右键打开。SMC 读数应与 ad-hoc 包一致。
4. `bash Scripts/build.sh appstore`（用描述文件和两个 Distribution 身份）。确认：
   - `codesign -d --entitlements :- build/MenuGauge-MAS.app` 含沙盒，且 application-identifier / team id 与描述文件一致。
   - `xcrun assetutil --info build/MenuGauge-MAS.app/Contents/Resources/Assets.car` 里有一条 `AssetType` 为 `Icon Image`、`Name` 为 `MenuGaugeFlat`、`Scale` 为 2、`PixelWidth` 和 `PixelHeight` 为 1024 的记录。1024 且 `Scale` 为 1 的是 Icon Composer 图层，不算。`CFBundleIconName` 和 `CFBundleIconFile` 都打印为 `MenuGaugeFlat`。DMG 的 `build/MenuGauge.app` 不要求这条 1024 记录；macOS 26 仍用扁平 `.icon`，13–15 仍用 ICNS。
   - 弹出面板温度是热状态而不是 °C，没有风扇一行，设置里也没有风扇开关。
   - CPU、内存、磁盘、网速仍有数。GPU 若变成 `--`，那是沙盒挡住了注册表，保持这样，不要加 IOKit 例外。
   - 开机自启动在沙盒里仍能注册，或把系统返回的错误显示出来。
   - `pkgutil --check-signature` 的签名身份是 Mac Installer Distribution。
5. 需要上传时再加 `--upload`，并对照 `xcrun altool --help` 核对参数。上传成功不等于可以提审；先在 App Store Connect 上看构建版本处理结果。
6. `Contents/Resources/PrivacyInfo.xcprivacy` 在两个 .app 里都在。Info.plist 的版本号等于传入的 `MACFAN_VERSION` / `MACFAN_BUILD`。

---

# Releasing MenuGauge

The display name is **MenuGauge** (formerly MacFan) on both the website DMG and the Mac App Store. The bundle identifier stays `com.badpx.macfan`. The GitHub repository and Pages URL stay the same. The App Store Connect record already exists: name MenuGauge, App ID `6827516123`, SKU `menu_gauge`, primary language English (U.S.).

Both artifacts come from `Scripts/build.sh`: SwiftPM compiles, then the script assembles the `.app` by hand. There is no `.xcodeproj` or `.xcworkspace`, and none should be added.

| Command | Audience | Output |
| --- | --- | --- |
| `bash Scripts/build.sh` | Local install | `build/MenuGauge.app`, ad-hoc signature |
| `bash Scripts/build.sh dmg` | Website / GitHub Release | `build/MenuGauge-v<version>.dmg`, Developer ID, notarized, stapled |
| `bash Scripts/build.sh appstore` | Mac App Store | `build/MenuGauge-v<version>.pkg`, sandboxed |

`bash Scripts/build.sh --help` lists every flag. Identities, Team ID, the profile, the version and notarization credentials come only from the environment or flags. `.p8` keys and `.provisionprofile` files are gitignored.

## Version

`CFBundleShortVersionString` and `CFBundleVersion` are not stored in `Resources/Info.plist`. The script writes them into the assembled plist.

- `MACFAN_VERSION` or `--version`: MenuGauge releases use two components, for example `1.0`. `1.0` is the first release of this product. The GitHub Release tag is `v1.0` and the asset is `MenuGauge-v1.0.dmg`. `CFBundleShortVersionString` and the file name are that string as given. The script still accepts a three-part value such as `1.0.0`, so an existing command keeps working. Do not delete or rename tags that are already published.
- `MACFAN_BUILD` or `--build`: a non-negative integer with no leading zeros. App Store Connect requires a greater build number on every upload.
- `dmg` and `appstore` require both.
- A plain `Scripts/build.sh` defaults to `1.0` (build `1`).

`MACFAN_BUNDLE_ID` (`--bundle-id`) defaults to `com.badpx.macfan`. The profile, the App Store Connect record and this value must match.

## Website / GitHub: DMG

The direct download is **not sandboxed**. Fan RPM and CPU temperature still come from AppleSMC, same as the ad-hoc app. Notarization requires the Hardened Runtime and a secure timestamp; that does not block SMC.

### Prerequisites

1. An Apple Developer Program membership.
2. A **Developer ID Application** certificate. Copy the name exactly, for example `Developer ID Application: Name (TEAMID)`:

   ```bash
   security find-identity -v -p codesigning
   ```

3. Notarization credentials, either:
   - An App Store Connect API key (Users and Access → Integrations → App Store Connect API) with at least the Developer role. The `.p8` file can be downloaded once.
   - Or a notarytool keychain profile stored ahead of time.

   When `NOTARY_KEY_PATH`, `NOTARY_KEY_ID` and `NOTARY_ISSUER` are all set, the script uses the API key and ignores a profile. To use a profile, leave those three unset.

   ```bash
   xcrun notarytool store-credentials "MenuGauge-Notary" \
     --key "$NOTARY_KEY_PATH" \
     --key-id "$NOTARY_KEY_ID" \
     --issuer "$NOTARY_ISSUER"
   ```

The keychain must be unlocked (`security unlock-keychain`). `MACFAN_KEYCHAIN` optionally points at a specific keychain file.

### Command

```bash
export DEVELOPER_ID_APPLICATION="Developer ID Application: Name (TEAMID)"
export NOTARY_KEY_PATH="$HOME/private_keys/AuthKey_XXXXXXXXXX.p8"
export NOTARY_KEY_ID="XXXXXXXXXX"
export NOTARY_ISSUER="00000000-0000-0000-0000-000000000000"
export MACFAN_VERSION="1.0"
export MACFAN_BUILD="4"
bash Scripts/build.sh dmg
```

Keychain profile only:

```bash
export DEVELOPER_ID_APPLICATION="Developer ID Application: Name (TEAMID)"
export NOTARY_KEYCHAIN_PROFILE="MenuGauge-Notary"
export MACFAN_VERSION="1.0"
export MACFAN_BUILD="4"
bash Scripts/build.sh dmg
```

### What the script does

1. `swift build -c release` for `arm64` and `x86_64` (`--build-system native`), without `MAS`. Objects go to `build/spm-direct` so they cannot be reused by the App Store compile.
2. `lipo` builds the universal binary and checks that both slices reference `_IOServiceOpen`, that the `AppleSMC` literal is present, and that private `IOHIDEventSystemClientCreate` is absent.
3. Assembles the `.app`: `actool` compiles `Resources/MenuGaugeFlat.icon` (flat icon on macOS 26; ICNS on macOS 13–15), copies `PrivacyInfo.xcprivacy`, and writes the version.
4. Signs with Developer ID Application, `--options runtime --timestamp`. No sandbox and no extra entitlements.
5. Builds a UDZO disk image with volume name MenuGauge, containing `MenuGauge.app` and a symlink to `/Applications`, then signs the dmg with the same identity.
6. `xcrun notarytool submit --wait`, then `xcrun stapler staple` and `stapler validate`.

Output: `build/MenuGauge-v1.0.dmg`. The GitHub Release tag is `v1.0` and the asset is `MenuGauge-v1.0.dmg`. `1.0` is the first MenuGauge release. The website prefers `MenuGauge-<tag>.dmg`, then a zip of the same name. Tags already published stay as they are. If the latest release is still a three-part tag, or a `MacFan-v<version>.dmg` / `.zip`, the site build accepts that too, so the site keeps building until it is replaced by `v1.0`. `website/release.json` still points at that older snapshot until it is replaced.

The staple is on the dmg. After the app is copied to Applications, Gatekeeper checks Apple's online ticket. The first offline launch still wants a machine that has been online for that check.

## Mac App Store: pkg

The sandbox refuses the AppleSMC user client. An `iokit-user-client-class` temporary exception is a known review rejection, so the **App Store edition omits SMC at compile time** and does not request that exception.

`swift build` passes `-Xswiftc -DMAS`. All of `SMC.swift` is inside `#if !MAS`. CPU temperature becomes `ProcessInfo.thermalState`. The fan metric is absent from this edition:

- The large temperature figure shows the localized thermal state, captioned as thermal state, not °C. Simplified Chinese uses 正常 / 偏高 / 过热 / 危急.
- There is no fan row in the overview and no fan switch in Settings. A saved `menuBarMetrics` entry of `fan` is removed at launch so the count and overflow logic do not reserve it.
- The menu bar uses the fixed tokens `OK` / `MID` / `HOT` / `MAX` so a long translation does not resize the status item. Temperature is labeled `TEMP`.
- `MenuGauge --fandump` exits immediately in this binary.

CPU, GPU, memory, disk and network sampling are unchanged. GPU reads public `IOAccelerator` registry properties and does not call `IOServiceOpen`. If the sandbox hides that dictionary, the UI already shows `--`. Do not add a temporary exception to force it.

Unused `Sources/MenuGauge/System/HIDSensors.swift` is deleted. It resolved private `IOHIDEventSystemClient*` symbols with `dlsym`, which neither edition can ship.

### Prerequisites

1. An **Apple Distribution** certificate (signs the .app) and a **Mac Installer Distribution** certificate (signs the pkg). The common name must match the flag exactly. Older certificates may still be named `3rd Party Mac Developer Application` / `3rd Party Mac Developer Installer`; pass the keychain's exact string:

   ```bash
   security find-identity -v -p codesigning   # Apple Distribution
   security find-identity -v                   # the installer identity may be absent from the codesigning policy
   ```

2. The 10-character Team ID, `APPLE_TEAM_ID` or `--team-id`.
3. The existing macOS app in App Store Connect named MenuGauge (App ID `6827516123`, SKU `menu_gauge`, primary language English (U.S.)). Its bundle id is `MACFAN_BUNDLE_ID`. Do not create a second record. Enable App Sandbox on the App ID. Do not enable an IOKit user client.
4. The matching Mac App Store **distribution** provisioning profile. The script decodes it and requires `com.apple.application-identifier` to equal `TEAMID.bundleid` (Apple's form: Team ID, a dot, then the bundle id), a matching team id, and no `iokit-user-client-class` entry. A distribution profile's Entitlements omit the sandbox. Sandbox must be true in `Resources/MacFan-MAS.entitlements`, and the script checks the signed app with `codesign -d --entitlements :-`.

The signed entitlements are only these three (`Resources/MacFan-MAS.entitlements`; the script fills in the Team ID and bundle id):

- `com.apple.security.app-sandbox`
- `com.apple.application-identifier` (`TEAMID.com.badpx.macfan`)
- `com.apple.developer.team-identifier`

There is no network-client, file-access or IOKit exception. UserDefaults, volume capacity, `getifaddrs` and `SMAppService.mainApp` do not need extra entitlements.

### Command

```bash
export APPLE_TEAM_ID="TEAMID"
export APPLE_DISTRIBUTION_IDENTITY="Apple Distribution: Name (TEAMID)"
export MAC_INSTALLER_DISTRIBUTION_IDENTITY="Mac Installer Distribution: Name (TEAMID)"
export MACFAN_PROVISIONING_PROFILE="$HOME/Downloads/MenuGauge_Mac_AppStore.provisionprofile"
export MACFAN_VERSION="1.0"
export MACFAN_BUILD="2"
bash Scripts/build.sh appstore
```

Build `1` of version `1.0` was already rejected by App Store Connect (ITMS-90236, missing the 512pt @2x icon). The next upload must use `--build 2` (or `MACFAN_BUILD=2`). Do not upload build `1` again.

### What the script does

1. Compiles both architectures with `-DMAS` into `build/spm-mas` and runs `lipo`. Neither slice may reference `_IOServiceOpen`, and the binary must not contain `AppleSMC` or `IOHIDEventSystemClientCreate`.
2. Assembles `build/MenuGauge-MAS.app` and writes the version. The DMG still compiles only `MenuGaugeFlat.icon` (bitmap fallbacks stay off, so macOS 13–15 keep the ICNS). The App Store bundle also passes a `MenuGaugeFlat.appiconset` in front of that `.icon`: 16, 32, 128, 256 and 512 at @1x and @2x, with 512@2x at 1024px. `--include-all-app-icons` keeps those bitmaps in `Assets.car`. The build fails if `assetutil` does not list an Icon Image named `MenuGaugeFlat` at scale 2 and 1024 pixels. `CFBundleIconName` and `CFBundleIconFile` are both `MenuGaugeFlat`.
3. Copies the profile to `Contents/embedded.provisionprofile`, then signs. The profile is inside the bundle before signing so the signature covers it.
4. `codesign --options runtime --timestamp --generate-entitlement-der` with the Apple Distribution identity. The entitlements passed to codesign must already have sandbox true. Then `codesign --verify --strict`, and `codesign -d --entitlements :-` must show sandbox true on the signed app.
5. `productbuild --component build/MenuGauge-MAS.app /Applications --product … --sign "Mac Installer Distribution: …"`. The requirements plist takes the minimum OS from `LSMinimumSystemVersion` (13.0) and lists `arm64` and `x86_64`, so the installer is not evaluated only under Rosetta.
6. `pkgutil --check-signature`.

Output: `build/MenuGauge-v1.0.pkg` and `build/MenuGauge-MAS.app`. The local and DMG commands use `build/MenuGauge.app`, so the two editions do not overwrite each other's bundle.

### Upload (off by default)

The app record must already exist. `--apple-id` is the numeric Apple ID from App Information, not the developer account. The API key needs permission to upload a build (App Manager or Admin). A notarization key limited to the Developer role may not be enough; set `ASC_KEY_*`, or omit them to reuse `NOTARY_KEY_*`.

```bash
export ASC_KEY_ID="XXXXXXXXXX"
export ASC_ISSUER_ID="00000000-0000-0000-0000-000000000000"
export ASC_KEY_PATH="$HOME/private_keys/AuthKey_XXXXXXXXXX.p8"
export ASC_APP_APPLE_ID="1234567890"
# Only when the account has more than one provider:
# export ASC_PUBLIC_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
bash Scripts/build.sh appstore --upload
```

The script copies the `.p8` into a temporary directory as `AuthKey_<id>.p8`, points altool at it with `API_PRIVATE_KEYS_DIR`, and deletes the copy when the upload finishes. The key bytes are not printed.

```bash
xcrun altool --upload-package MenuGauge-v1.0.pkg -t osx \
  --apple-id "$ASC_APP_APPLE_ID" \
  --bundle-id "$MACFAN_BUNDLE_ID" \
  --bundle-short-version-string "$MACFAN_VERSION" \
  --bundle-version "$MACFAN_BUILD" \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID" \
  --show-progress
```

Add `--asc-public-id` when the account has multiple providers. If `xcrun altool --help` on that Xcode no longer lists `--upload-package`, follow the help text. Do not switch to the deprecated `--upload-app`.

## Privacy manifest

`Resources/PrivacyInfo.xcprivacy` is copied to `Contents/Resources/` for both editions. The app does not track or collect data.

| API | Reason | Why |
| --- | --- | --- |
| UserDefaults | `CA92.1` | Reads and writes only this app's `menuBarMetrics` |
| Disk space | `85F4.1` | `volumeAvailableCapacityForImportantUsage` is shown on screen and is not sent off the device |

`volumeTotalCapacity` is not on Apple's required-reason list. The app does not call file-timestamp, boot-time or active-keyboard APIs. `DiskMonitor` mentions `statfs` in a comment and does not call it.

## Info.plist

The source plist now includes:

- `LSApplicationCategoryType` = `public.app-category.utilities`
- `ITSAppUsesNonExemptEncryption` = false (no non-exempt encryption)
- `CFBundleLocalizations`: `en`, `zh-Hans`, `zh-Hant`, `ja`, `ko`, `hi`, `es`, `fr`, `bn`, `ru`, `pt` (the same 11 languages as `L10n.swift`)

`LSUIElement` stays true: menu-bar app, no Dock icon.

## Verify on a Mac

This change was written on Linux, so the Swift toolchain did not run. Before relying on a release, use a Mac with the Xcode 26 command-line tools:

1. `swift test`.
2. `bash Scripts/build.sh`, copy `build/MenuGauge.app` to `/Applications` and launch it. Fan RPM and CPU temperature still come from SMC. Launch at login still needs approval in System Settings. The icon stays flat on macOS 26 and uses the ICNS on 13–15.
3. `bash Scripts/build.sh dmg` with the identity and notarization variables above. `codesign -dv --verbose=4 build/MenuGauge.app` should show Developer ID, the hardened runtime and a timestamp. Notarization and `stapler validate` run inside the script and fail the build on error. Open the dmg, drag the app to Applications, and confirm Gatekeeper does not ask for a right-click Open. SMC readings should match the ad-hoc app.
4. `bash Scripts/build.sh appstore` with the profile and both distribution identities. Confirm:
   - `codesign -d --entitlements :- build/MenuGauge-MAS.app` contains the sandbox, and the application identifier and team id match the profile.
   - `xcrun assetutil --info build/MenuGauge-MAS.app/Contents/Resources/Assets.car` includes an `Icon Image` named `MenuGaugeFlat` with `Scale` 2 and `PixelWidth` / `PixelHeight` 1024. A 1024px image at `Scale` 1 is the Icon Composer layer and does not count. `CFBundleIconName` and `CFBundleIconFile` both print `MenuGaugeFlat`. The DMG's `build/MenuGauge.app` does not need that 1024 rendition; macOS 26 still uses the flat `.icon`, and 13–15 still use the ICNS.
   - The temperature figure is a thermal state, not °C. There is no fan row and no fan switch in Settings.
   - CPU, memory, disk and network still produce numbers. If GPU becomes `--`, the sandbox hid the registry entry; leave it that way and do not add an IOKit exception.
   - Launch at login still registers inside the sandbox, or the panel shows the error the system returned.
   - `pkgutil --check-signature` reports the Mac Installer Distribution identity.
5. Add `--upload` only when a build should be sent, and compare the flags with `xcrun altool --help`. A successful upload is not App Review. Check the build's processing state in App Store Connect first.
6. `Contents/Resources/PrivacyInfo.xcprivacy` is inside both apps. The Info.plist version equals the `MACFAN_VERSION` / `MACFAN_BUILD` that were passed in.
