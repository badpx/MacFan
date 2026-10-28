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
        XCTAssertFalse(LoginLaunch.isLoginLaunch(openEvent(loginFlag: nil)))
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
        XCTAssertFalse(SessionQuit.isEndingSession(openEvent(loginFlag: true)))
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

    func testTemperatureToggleNameFollowsTheEdition() {
        let title = MetricDescriptor.all.first { $0.id == "temperature" }?.title
        #if MAS
        XCTAssertEqual(title, L10n.tr(.thermalState))
        #else
        XCTAssertEqual(title, L10n.tr(.temperature))
        #endif
    }

    private func openEvent(loginFlag: Bool?) -> NSAppleEventDescriptor {
        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(0x61657674),
            eventID: LoginLaunch.openApplication,
            targetDescriptor: nil,
            returnID: AEReturnID(-1),
            transactionID: AETransactionID(0))
        guard let loginFlag else { return event }
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
