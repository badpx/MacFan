import AppKit
import XCTest
@testable import MenuGauge

final class SettingsWindowTests: XCTestCase {
    func testSettingsOpensOnFirstManualLaunchOnly() {
        XCTAssertTrue(LaunchPresentation.shouldShowSettings(launchedAtLogin: false, hasCompletedFirstLaunch: false))
        XCTAssertFalse(LaunchPresentation.shouldShowSettings(launchedAtLogin: false, hasCompletedFirstLaunch: true))
        XCTAssertFalse(LaunchPresentation.shouldShowSettings(launchedAtLogin: true, hasCompletedFirstLaunch: false))
        XCTAssertFalse(LaunchPresentation.shouldShowSettings(launchedAtLogin: true, hasCompletedFirstLaunch: true))
        XCTAssertEqual(LaunchPresentation.firstLaunchKey, "didCompleteFirstLaunch")
    }

    func testLoginAppleEventIsTheOnlyAutomaticSuppression() {
        XCTAssertFalse(LoginLaunch.isLoginLaunch(nil))
        XCTAssertFalse(LoginLaunch.isLoginLaunch(openApplicationEvent()))
        // Launch Services puts the enum `lgit` directly in `prdt`.
        XCTAssertTrue(LoginLaunch.isLoginLaunch(loginItemOpenEvent()))
        // A nested record is not the system form, but still means login.
        XCTAssertTrue(LoginLaunch.isLoginLaunch(openEvent(loginFlag: true)))
        XCTAssertFalse(LoginLaunch.isLoginLaunch(openEvent(loginFlag: false)))

        let unrelated = NSAppleEventDescriptor(
            eventClass: AEEventClass(0x61657674),
            eventID: AEEventID(0x71756974),
            targetDescriptor: nil,
            returnID: AEReturnID(-1),
            transactionID: AETransactionID(0))
        XCTAssertFalse(LoginLaunch.isLoginLaunch(unrelated))
    }

    func testSessionEndingQuitSkipsConfirmation() {
        XCTAssertFalse(SessionQuit.isEndingSession(nil))
        XCTAssertFalse(SessionQuit.isEndingSession(quitEvent(reason: nil)))
        XCTAssertTrue(SessionQuit.isEndingSession(quitEvent(reason: 0x73687574))) // shut
        XCTAssertTrue(SessionQuit.isEndingSession(quitEvent(reason: 0x72657374))) // rest
        XCTAssertTrue(SessionQuit.isEndingSession(quitEvent(reason: 0x6C6F676F))) // logo
        XCTAssertFalse(SessionQuit.isEndingSession(loginItemOpenEvent()))
    }

    func testEveryLanguageHasEveryString() {
        XCTAssertEqual(Set(L10n.translatedLanguages).count, 11)
        for language in L10n.translatedLanguages {
            for key in L10n.Key.allCases {
                XCTAssertTrue(L10n.contains(key, language: language), "\(language) missing \(key)")
                XCTAssertFalse(L10n.string(key, language: language).isEmpty)
            }
        }
    }

    func testOpenAtLoginUsesSystemSettingsWording() {
        let expected = [
            "en": "Open at Login",
            "zh-Hans": "登录时打开",
            "zh-Hant": "在登入時打開",
            "ja": "ログイン時に開く",
            "ko": "로그인 시 열기",
            "hi": "लॉगइन पर खोलें",
            "es": "Abrir al iniciar sesión",
            "fr": "Ouvrir à la connexion",
            "pt": "Abrir ao iniciar sessão",
            "ru": "Открывать при входе",
            "bn": "লগইনে খুলুন",
        ]
        for (language, phrase) in expected {
            XCTAssertEqual(L10n.string(.launchAtLogin, language: language), phrase, language)
        }
    }

    func testExistingThermalCopyAndConfigHintStayPut() {
        XCTAssertEqual(L10n.string(.thermalNominal, language: "en"), "Nominal")
        XCTAssertEqual(L10n.string(.thermalFair, language: "en"), "Fair")
        XCTAssertEqual(L10n.string(.thermalSerious, language: "en"), "Serious")
        XCTAssertEqual(L10n.string(.thermalCritical, language: "en"), "Critical")
        XCTAssertEqual(L10n.string(.thermalNominal, language: "zh-Hans"), "正常")
        XCTAssertEqual(L10n.string(.thermalFair, language: "zh-Hans"), "偏高")
        XCTAssertEqual(L10n.string(.thermalSerious, language: "zh-Hans"), "过热")
        XCTAssertEqual(L10n.string(.thermalCritical, language: "zh-Hans"), "危急")
        XCTAssertEqual(L10n.string(.configHint, language: "en"),
                       "Enabled metrics appear in the menu bar. Turn all off to show only the gauge icon.")
        XCTAssertEqual(L10n.string(.configHint, language: "zh-Hans"),
                       "开启后，指标会显示在顶部菜单栏。关闭所有指标时，仅显示仪表图标。")
        XCTAssertEqual(L10n.string(.loginPending, language: "zh-Hans"), "请在系统设置中允许开机自启动")
    }

    func testSettingsCopyIsLocalized() {
        XCTAssertEqual(L10n.string(.settingsTitle, language: "en"), "MenuGauge Settings")
        XCTAssertEqual(L10n.string(.settingsTitle, language: "zh-Hans"), "MenuGauge 设置")
        XCTAssertEqual(L10n.string(.runningTitle, language: "zh-Hans"), "MenuGauge 已在菜单栏运行")
        XCTAssertNotEqual(L10n.string(.runningDetail, language: "zh-Hans"),
                          L10n.string(.runningDetail, language: "en"))
        XCTAssertEqual(L10n.string(.quitShort, language: "zh-Hans"), "退出")
        XCTAssertEqual(L10n.string(.quit, language: "zh-Hans"), "退出 MenuGauge")
        XCTAssertEqual(L10n.string(.general, language: "zh-Hans"), "通用")
        XCTAssertEqual(L10n.string(.general, language: "zh-Hant"), "一般")
        XCTAssertEqual(L10n.string(.website, language: "zh-Hans"), "官网")
        for language in L10n.translatedLanguages where language != "en" {
            XCTAssertNotEqual(L10n.string(.runningDetail, language: language),
                              L10n.string(.runningDetail, language: "en"), language)
            XCTAssertNotEqual(L10n.string(.loginHint, language: language),
                              L10n.string(.loginHint, language: "en"), language)
        }
    }

    func testQuitDialogButtonIsShortWhileTheWindowButtonStaysFull() {
        XCTAssertEqual(L10n.string(.quitShort, language: "en"), "Quit")
        XCTAssertEqual(L10n.string(.quitShort, language: "zh-Hans"), "退出")
        XCTAssertEqual(L10n.string(.quitConfirm, language: "zh-Hans"), "确认退出 MenuGauge 吗？")
        XCTAssertEqual(L10n.string(.quit, language: "zh-Hans"), "退出 MenuGauge")
        for language in L10n.translatedLanguages {
            let button = L10n.string(.quitShort, language: language)
            XCTAssertFalse(button.contains("MenuGauge"), "\(language) dialog button")
            XCTAssertTrue(L10n.string(.quit, language: language).contains("MenuGauge"), language)
            XCTAssertTrue(L10n.string(.quitConfirm, language: language).contains("MenuGauge"), language)
        }
    }

    func testHintGaugeIsTheStatusItemDrawing() {
        let key = MenuBarHintArt.gaugeKey
        let painted = StatusGaugeImage.paintedImage(for: key, color: .white)
        let menu = StatusGaugeImage.image(for: key)
        XCTAssertFalse(painted.isTemplate)
        XCTAssertTrue(menu.isTemplate)
        XCTAssertEqual(painted.size, StatusGaugeImage.pointSize)
        XCTAssertEqual(menu.size, painted.size)
        XCTAssertEqual(alphaMask(painted), alphaMask(menu))
        let tip = MenuBarHintArt.arrowTip
        let ringBottom = MenuBarHintArt.ringCenter.y + MenuBarHintArt.ringDiameter / 2
        XCTAssertEqual(MenuBarHintArt.ringCenter.x, MenuBarHintArt.artSize.width / 2)
        XCTAssertEqual(tip.x, MenuBarHintArt.ringCenter.x)
        XCTAssertEqual(tip.x, MenuBarHintArt.arrowControl.x)
        XCTAssertGreaterThan(tip.y, ringBottom)
        XCTAssertLessThan(tip.y, MenuBarHintArt.arrowTail.y)
        XCTAssertEqual(MenuBarHintArt.ringCenter.x - MenuBarHintArt.arrowTail.x, 16)
        XCTAssertEqual(MenuBarHintArt.arrowTail.y - tip.y, 31)
    }

    private func alphaMask(_ image: NSImage) -> [Int] {
        let scale: CGFloat = 2
        let width = Int(image.size.width * scale)
        let height = Int(image.size.height * scale)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
            return []
        }
        rep.size = image.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height).fill()
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()
        var mask: [Int] = []
        mask.reserveCapacity(width * height)
        for y in 0..<height {
            for x in 0..<width {
                let alpha = rep.colorAt(x: x, y: y)?.alphaComponent ?? 0
                mask.append(Int((alpha * 255).rounded()))
            }
        }
        return mask
    }

    func testLoginHintStopsBeforeTheSettingsWindow() {
        let expected = [
            "en": "Opens in the menu bar when you log in.",
            "zh-Hans": "登录 Mac 后自动在菜单栏运行",
            "zh-Hant": "登入 Mac 後會在選單列自動執行",
            "ja": "ログインするとメニューバーで自動的に起動します。",
            "ko": "로그인하면 메뉴 막대에서 자동으로 실행됩니다.",
            "hi": "लॉगइन करने पर मेनू बार में अपने आप खुलता है।",
            "es": "Se abre en la barra de menús al iniciar sesión.",
            "fr": "S’ouvre dans la barre des menus à la connexion.",
            "bn": "লগইন করলে মেনু বারে নিজে থেকে চলবে।",
            "ru": "При входе запускается в строке меню.",
            "pt": "Abre na barra de menus ao iniciar sessão.",
        ]
        for (language, phrase) in expected {
            XCTAssertEqual(L10n.string(.loginHint, language: language), phrase, language)
        }
    }

    func testPanelIconChromeIsPlainUntilHoverOrPress() {
        XCTAssertEqual(MenuGaugeIconChrome.state(hovered: false, pressed: false), .plain)
        XCTAssertEqual(MenuGaugeIconChrome.state(hovered: true, pressed: false), .hover)
        XCTAssertEqual(MenuGaugeIconChrome.state(hovered: false, pressed: true), .pressed)
        XCTAssertEqual(MenuGaugeIconChrome.state(hovered: true, pressed: true), .pressed)
        XCTAssertEqual(MenuGaugeIconChrome.side, 28)
        XCTAssertGreaterThan(MenuGaugeIconChrome.pressedOpacity, MenuGaugeIconChrome.hoverOpacity)
    }

    func testTemperatureToggleNameFollowsTheEdition() {
        let title = MetricDescriptor.all.first { $0.id == "temperature" }?.title
        #if MAS
        XCTAssertEqual(title, L10n.tr(.thermalState))
        #else
        XCTAssertEqual(title, L10n.tr(.temperature))
        #endif
    }

    /// Plain `oapp`, the way Finder and `open` launch the app.
    private func openApplicationEvent() -> NSAppleEventDescriptor {
        NSAppleEventDescriptor(
            eventClass: AEEventClass(0x61657674),
            eventID: LoginLaunch.openApplication,
            targetDescriptor: nil,
            returnID: AEReturnID(-1),
            transactionID: AETransactionID(0))
    }

    /// `prdt` is the enum `lgit`, the way a login-item launch arrives.
    private func loginItemOpenEvent() -> NSAppleEventDescriptor {
        let event = openApplicationEvent()
        event.setParam(NSAppleEventDescriptor(enumCode: LoginLaunch.launchedAsLogInItem),
                       forKeyword: LoginLaunch.propData)
        return event
    }

    /// Alternate shape some callers build: a record with a boolean `lgit`.
    private func openEvent(loginFlag: Bool) -> NSAppleEventDescriptor {
        let event = openApplicationEvent()
        let record = NSAppleEventDescriptor.record()
        record.setParam(NSAppleEventDescriptor(boolean: loginFlag),
                        forKeyword: LoginLaunch.launchedAsLogInItem)
        event.setParam(record, forKeyword: LoginLaunch.propData)
        return event
    }

    private func quitEvent(reason: OSType?) -> NSAppleEventDescriptor {
        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(0x61657674),
            eventID: SessionQuit.quitApplication,
            targetDescriptor: nil,
            returnID: AEReturnID(-1),
            transactionID: AETransactionID(0))
        if let reason {
            event.setParam(NSAppleEventDescriptor(enumCode: reason),
                           forKeyword: SessionQuit.reasonKeyword)
        }
        return event
    }
}
