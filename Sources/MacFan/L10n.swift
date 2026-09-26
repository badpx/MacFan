import Foundation

/// Minimal in-code localization. The .app is assembled by Scripts/build.sh
/// from a bare SwiftPM binary and ships no .lproj bundles, so the (tiny)
/// string table lives here and the language follows the user's preferred
/// language list. Unsupported languages fall back to English.
enum L10n {
    enum UI: String {
        case overview = "System overview", configuration = "Menu bar settings"
        case tagline = "Your system, at a glance", refresh = "Updates every 2s"
        case processors = "Processors", utilization = "Live utilization"
        case storage = "Memory & storage", cooling = "Temperature & cooling"
        case transfer = "Transfer rate", download = "Download", upload = "Upload"
        case available = "Available", unavailable = "Unavailable", sampling = "Sampling…"
        case sensor = "Sensor reading", average = "Average speed", stopped = "Stopped"
        case elevated = "Elevated", high = "High", temperatureHigh = "Temperature elevated"
        case temperatureCritical = "Temperature high", averageUnavailable = "Average unavailable"
        case showInMenu = "Show in menu bar", selected = "%d enabled"
        case menuCount = "Menu bar · %d items"
        case configHint = "Enabled metrics appear in the menu bar. Turn all off to show only the MacFan icon."
        case loginHint = "Run automatically when you log in"
        case loginPending = "Approval required in System Settings"
        case loginUnavailable = "Login item unavailable for this app"
        case systemSettings = "Open System Settings"
        case product = "MacFan · Lightweight system monitor"
        case partial = "Some readings are unavailable. Other metrics continue updating."
    }

    static func ui(_ key: UI) -> String {
        let simplified: [UI: String] = [
            .overview: "系统概览", .configuration: "菜单栏设置", .tagline: "系统状态，一目了然",
            .refresh: "每 2 秒更新", .processors: "处理器", .utilization: "实时占用",
            .storage: "内存与存储", .cooling: "温度与散热", .transfer: "传输速率",
            .download: "下载", .upload: "上传", .available: "可用", .unavailable: "暂不可用",
            .sampling: "采样中…", .sensor: "传感器读数", .average: "平均转速", .stopped: "停转",
            .elevated: "偏高", .high: "很高", .temperatureHigh: "温度偏高",
            .temperatureCritical: "温度过高", .averageUnavailable: "平均转速不可用",
            .showInMenu: "显示在菜单栏", .selected: "%d 项已开启", .menuCount: "菜单栏 · %d 项",
            .configHint: "开启后，指标会显示在顶部菜单栏。关闭所有指标时，仅显示 MacFan 图标。",
            .loginHint: "登录 Mac 时自动运行", .loginPending: "请在系统设置中允许开机自启动",
            .loginUnavailable: "此应用的登录项暂不可用", .systemSettings: "打开系统设置",
            .product: "MacFan · 轻量系统监控", .partial: "部分数据暂不可用，其余指标继续更新。",
        ]
        let traditional: [UI: String] = [
            .overview: "系統概覽", .configuration: "選單列設定", .tagline: "系統狀態，一目了然",
            .refresh: "每 2 秒更新", .processors: "處理器", .utilization: "即時使用率",
            .storage: "記憶體與儲存空間", .cooling: "溫度與散熱", .transfer: "傳輸速率",
            .download: "下載", .upload: "上傳", .available: "可用", .unavailable: "暫不可用",
            .sampling: "取樣中…", .sensor: "感測器讀數", .average: "平均轉速", .stopped: "停轉",
            .elevated: "偏高", .high: "很高", .temperatureHigh: "溫度偏高",
            .temperatureCritical: "溫度過高", .averageUnavailable: "平均轉速不可用",
            .showInMenu: "顯示於選單列", .selected: "%d 項已開啟", .menuCount: "選單列 · %d 項",
            .configHint: "開啟後，指標會顯示於選單列。關閉所有指標時，僅顯示 MacFan 圖示。",
            .loginHint: "登入 Mac 時自動執行", .loginPending: "請在系統設定中允許登入時啟動",
            .loginUnavailable: "此應用程式的登入項目暫不可用", .systemSettings: "開啟系統設定",
            .product: "MacFan · 輕量系統監控", .partial: "部分資料暫不可用，其餘指標持續更新。",
        ]
        switch language {
        case "zh-Hans": return simplified[key] ?? key.rawValue
        case "zh-Hant": return traditional[key] ?? key.rawValue
        default: return key.rawValue
        }
    }

    enum Key {
        case memory, disk, temperature, fan, network
        case used, launchAtLogin, quit, quitConfirm, cancel
        case menuBarOverflow
    }

    static func tr(_ key: Key) -> String {
        table[language]?[key] ?? table["en"]![key]!
    }

    /// First supported entry in the user's preferred language list.
    private static let language: String = {
        for code in Locale.preferredLanguages {
            let lower = code.lowercased()
            if lower.hasPrefix("zh") {
                if lower.contains("hant") || lower.contains("-tw")
                    || lower.contains("-hk") || lower.contains("-mo") {
                    return "zh-Hant"
                }
                return "zh-Hans"
            }
            for lang in ["ja", "ko", "hi", "es", "fr", "bn", "ru", "pt", "en"] {
                if lower.hasPrefix(lang) { return lang }
            }
        }
        return "en"
    }()

    private static let table: [String: [Key: String]] = [
        "en": [
            .memory: "Memory", .disk: "Disk", .temperature: "Temperature",
            .fan: "Fan", .network: "Network", .used: "Used",
            .launchAtLogin: "Launch at Login", .quit: "Quit MacFan",
            .quitConfirm: "Quit MacFan %@?", .cancel: "Cancel",
            .menuBarOverflow: "Menu bar full — some widgets hidden",
        ],
        "zh-Hans": [
            .memory: "内存", .disk: "磁盘", .temperature: "温度",
            .fan: "风扇", .network: "网络", .used: "已用",
            .launchAtLogin: "开机自启动", .quit: "退出 MacFan",
            .quitConfirm: "确认退出 MacFan %@ 吗？", .cancel: "取消",
            .menuBarOverflow: "菜单栏空间不足，部分数值已隐藏",
        ],
        "zh-Hant": [
            .memory: "記憶體", .disk: "磁碟", .temperature: "溫度",
            .fan: "風扇", .network: "網路", .used: "已用",
            .launchAtLogin: "開機自動啟動", .quit: "結束 MacFan",
            .quitConfirm: "確認結束 MacFan %@ 嗎？", .cancel: "取消",
            .menuBarOverflow: "選單列空間不足，部分數值已隱藏",
        ],
        "ja": [
            .memory: "メモリ", .disk: "ディスク", .temperature: "温度",
            .fan: "ファン", .network: "ネットワーク", .used: "使用済み",
            .launchAtLogin: "ログイン時に起動", .quit: "MacFan を終了",
            .quitConfirm: "MacFan %@ を終了しますか？", .cancel: "キャンセル",
            .menuBarOverflow: "メニューバーの空き不足：一部の数値を非表示中",
        ],
        "ko": [
            .memory: "메모리", .disk: "디스크", .temperature: "온도",
            .fan: "팬", .network: "네트워크", .used: "사용됨",
            .launchAtLogin: "로그인 시 자동 실행", .quit: "MacFan 종료",
            .quitConfirm: "MacFan %@을 종료하시겠습니까?", .cancel: "취소",
            .menuBarOverflow: "메뉴 막대 공간 부족: 일부 수치 숨김",
        ],
        "hi": [
            .memory: "मेमोरी", .disk: "डिस्क", .temperature: "तापमान",
            .fan: "पंखा", .network: "नेटवर्क", .used: "उपयोग किया हुआ",
            .launchAtLogin: "लॉगिन पर खोलें", .quit: "MacFan से बाहर निकलें",
            .quitConfirm: "MacFan %@ से बाहर निकलें?", .cancel: "रद्द करें",
            .menuBarOverflow: "मेनू बार में जगह नहीं — कुछ मान छिपाए गए",
        ],
        "es": [
            .memory: "Memoria", .disk: "Disco", .temperature: "Temperatura",
            .fan: "Ventilador", .network: "Red", .used: "Usado",
            .launchAtLogin: "Abrir al iniciar sesión", .quit: "Salir de MacFan",
            .quitConfirm: "¿Salir de MacFan %@?", .cancel: "Cancelar",
            .menuBarOverflow: "Barra de menús llena — algunos valores ocultos",
        ],
        "fr": [
            .memory: "Mémoire", .disk: "Disque", .temperature: "Température",
            .fan: "Ventilateur", .network: "Réseau", .used: "Utilisé",
            .launchAtLogin: "Ouvrir au démarrage", .quit: "Quitter MacFan",
            .quitConfirm: "Quitter MacFan %@ ?", .cancel: "Annuler",
            .menuBarOverflow: "Barre des menus pleine — certaines valeurs masquées",
        ],
        "bn": [
            .memory: "মেমরি", .disk: "ডিস্ক", .temperature: "তাপমাত্রা",
            .fan: "ফ্যান", .network: "নেটওয়ার্ক", .used: "ব্যবহৃত",
            .launchAtLogin: "লগইনে খুলুন", .quit: "MacFan বন্ধ করুন",
            .quitConfirm: "MacFan %@ বন্ধ করবেন?", .cancel: "বাতিল",
            .menuBarOverflow: "মেনু বারে জায়গা নেই — কিছু মান লুকানো হয়েছে",
        ],
        "ru": [
            .memory: "Память", .disk: "Диск", .temperature: "Температура",
            .fan: "Вентилятор", .network: "Сеть", .used: "Использовано",
            .launchAtLogin: "Запускать при входе", .quit: "Выйти из MacFan",
            .quitConfirm: "Выйти из MacFan %@?", .cancel: "Отмена",
            .menuBarOverflow: "Строка меню переполнена — часть значений скрыта",
        ],
        "pt": [
            .memory: "Memória", .disk: "Disco", .temperature: "Temperatura",
            .fan: "Ventoinha", .network: "Rede", .used: "Utilizado",
            .launchAtLogin: "Abrir ao iniciar sessão", .quit: "Sair do MacFan",
            .quitConfirm: "Sair do MacFan %@?", .cancel: "Cancelar",
            .menuBarOverflow: "Barra de menus cheia — alguns valores ocultos",
        ],
    ]
}
