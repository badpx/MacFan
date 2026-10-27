import Foundation

/// Minimal in-code localization. The .app is assembled by Scripts/build.sh
/// from a bare SwiftPM binary and ships no .lproj bundles, so the (tiny)
/// string table lives here and the language follows the user's preferred
/// language list. Unsupported languages fall back to English.
enum L10n {
    enum UI: String {
        case overview = "System overview", configuration = "Settings"
        case cpuUsage = "CPU usage", gpuUsage = "GPU usage"
        case cpuTemperature = "CPU temperature", ofTotal = "of %@ GB"
        case available = "Available"
        case showInMenu = "Show in menu bar", selected = "%d enabled"
        case menuCount = "Menu bar · %d items"
        case configHint = "Enabled metrics appear in the menu bar. Turn all off to show only the MenuGauge icon."
        case loginHint = "Run automatically when you log in"
        case loginPending = "Approval required in System Settings"
        case loginUnavailable = "Login item unavailable for this app"
        case systemSettings = "Open System Settings"
        case product = "MenuGauge · Lightweight system monitor"
    }

    static func ui(_ key: UI) -> String {
        let simplified: [UI: String] = [
            .overview: "系统概览", .configuration: "设置",
            .cpuUsage: "CPU 占用", .gpuUsage: "GPU 占用",
            .cpuTemperature: "CPU 温度", .ofTotal: "共 %@ GB",
            .available: "可用",
            .showInMenu: "显示在菜单栏", .selected: "%d 项已开启", .menuCount: "菜单栏 · %d 项",
            .configHint: "开启后，指标会显示在顶部菜单栏。关闭所有指标时，仅显示 MenuGauge 图标。",
            .loginHint: "登录 Mac 时自动运行", .loginPending: "请在系统设置中允许开机自启动",
            .loginUnavailable: "此应用的登录项暂不可用", .systemSettings: "打开系统设置",
            .product: "MenuGauge · 轻量系统监控",
        ]
        let traditional: [UI: String] = [
            .overview: "系統概覽", .configuration: "設定",
            .cpuUsage: "CPU 佔用", .gpuUsage: "GPU 佔用",
            .cpuTemperature: "CPU 溫度", .ofTotal: "共 %@ GB",
            .available: "可用",
            .showInMenu: "顯示於選單列", .selected: "%d 項已開啟", .menuCount: "選單列 · %d 項",
            .configHint: "開啟後，指標會顯示於選單列。關閉所有指標時，僅顯示 MenuGauge 圖示。",
            .loginHint: "登入 Mac 時自動執行", .loginPending: "請在系統設定中允許登入時啟動",
            .loginUnavailable: "此應用程式的登入項目暫不可用", .systemSettings: "開啟系統設定",
            .product: "MenuGauge · 輕量系統監控",
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
        case thermalState, thermalNominal, thermalFair, thermalSerious, thermalCritical
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
            .launchAtLogin: "Launch at Login", .quit: "Quit MenuGauge",
            .quitConfirm: "Quit MenuGauge?", .cancel: "Cancel",
            .menuBarOverflow: "Menu bar full — some widgets hidden",
            .thermalState: "Thermal state",
            .thermalNominal: "Nominal", .thermalFair: "Fair",
            .thermalSerious: "Serious", .thermalCritical: "Critical",
        ],
        "zh-Hans": [
            .memory: "内存", .disk: "磁盘", .temperature: "温度",
            .fan: "风扇", .network: "网络", .used: "已用",
            .launchAtLogin: "开机自启动", .quit: "退出 MenuGauge",
            .quitConfirm: "确认退出 MenuGauge 吗？", .cancel: "取消",
            .menuBarOverflow: "菜单栏空间不足，部分数值已隐藏",
            .thermalState: "热状态",
            .thermalNominal: "正常", .thermalFair: "一般",
            .thermalSerious: "严重", .thermalCritical: "危急",
        ],
        "zh-Hant": [
            .memory: "記憶體", .disk: "磁碟", .temperature: "溫度",
            .fan: "風扇", .network: "網路", .used: "已用",
            .launchAtLogin: "開機自動啟動", .quit: "結束 MenuGauge",
            .quitConfirm: "確認結束 MenuGauge 嗎？", .cancel: "取消",
            .menuBarOverflow: "選單列空間不足，部分數值已隱藏",
            .thermalState: "熱狀態",
            .thermalNominal: "正常", .thermalFair: "一般",
            .thermalSerious: "嚴重", .thermalCritical: "危急",
        ],
        "ja": [
            .memory: "メモリ", .disk: "ディスク", .temperature: "温度",
            .fan: "ファン", .network: "ネットワーク", .used: "使用済み",
            .launchAtLogin: "ログイン時に起動", .quit: "MenuGauge を終了",
            .quitConfirm: "MenuGauge を終了しますか？", .cancel: "キャンセル",
            .menuBarOverflow: "メニューバーの空き不足：一部の数値を非表示中",
            .thermalState: "熱状態",
            .thermalNominal: "正常", .thermalFair: "やや高め",
            .thermalSerious: "高い", .thermalCritical: "危険",
        ],
        "ko": [
            .memory: "메모리", .disk: "디스크", .temperature: "온도",
            .fan: "팬", .network: "네트워크", .used: "사용됨",
            .launchAtLogin: "로그인 시 자동 실행", .quit: "MenuGauge 종료",
            .quitConfirm: "MenuGauge를 종료하시겠습니까?", .cancel: "취소",
            .menuBarOverflow: "메뉴 막대 공간 부족: 일부 수치 숨김",
            .thermalState: "열 상태",
            .thermalNominal: "정상", .thermalFair: "보통",
            .thermalSerious: "높음", .thermalCritical: "위험",
        ],
        "hi": [
            .memory: "मेमोरी", .disk: "डिस्क", .temperature: "तापमान",
            .fan: "पंखा", .network: "नेटवर्क", .used: "उपयोग किया हुआ",
            .launchAtLogin: "लॉगिन पर खोलें", .quit: "MenuGauge से बाहर निकलें",
            .quitConfirm: "MenuGauge से बाहर निकलें?", .cancel: "रद्द करें",
            .menuBarOverflow: "मेनू बार में जगह नहीं — कुछ मान छिपाए गए",
            .thermalState: "थर्मल स्थिति",
            .thermalNominal: "सामान्य", .thermalFair: "मध्यम",
            .thermalSerious: "गंभीर", .thermalCritical: "अति गंभीर",
        ],
        "es": [
            .memory: "Memoria", .disk: "Disco", .temperature: "Temperatura",
            .fan: "Ventilador", .network: "Red", .used: "Usado",
            .launchAtLogin: "Abrir al iniciar sesión", .quit: "Salir de MenuGauge",
            .quitConfirm: "¿Salir de MenuGauge?", .cancel: "Cancelar",
            .menuBarOverflow: "Barra de menús llena — algunos valores ocultos",
            .thermalState: "Estado térmico",
            .thermalNominal: "Normal", .thermalFair: "Moderado",
            .thermalSerious: "Alto", .thermalCritical: "Crítico",
        ],
        "fr": [
            .memory: "Mémoire", .disk: "Disque", .temperature: "Température",
            .fan: "Ventilateur", .network: "Réseau", .used: "Utilisé",
            .launchAtLogin: "Ouvrir au démarrage", .quit: "Quitter MenuGauge",
            .quitConfirm: "Quitter MenuGauge ?", .cancel: "Annuler",
            .menuBarOverflow: "Barre des menus pleine — certaines valeurs masquées",
            .thermalState: "État thermique",
            .thermalNominal: "Normal", .thermalFair: "Modéré",
            .thermalSerious: "Élevé", .thermalCritical: "Critique",
        ],
        "bn": [
            .memory: "মেমরি", .disk: "ডিস্ক", .temperature: "তাপমাত্রা",
            .fan: "ফ্যান", .network: "নেটওয়ার্ক", .used: "ব্যবহৃত",
            .launchAtLogin: "লগইনে খুলুন", .quit: "MenuGauge বন্ধ করুন",
            .quitConfirm: "MenuGauge বন্ধ করবেন?", .cancel: "বাতিল",
            .menuBarOverflow: "মেনু বারে জায়গা নেই — কিছু মান লুকানো হয়েছে",
            .thermalState: "তাপের অবস্থা",
            .thermalNominal: "স্বাভাবিক", .thermalFair: "মাঝারি",
            .thermalSerious: "উচ্চ", .thermalCritical: "সংকটপূর্ণ",
        ],
        "ru": [
            .memory: "Память", .disk: "Диск", .temperature: "Температура",
            .fan: "Вентилятор", .network: "Сеть", .used: "Использовано",
            .launchAtLogin: "Запускать при входе", .quit: "Выйти из MenuGauge",
            .quitConfirm: "Выйти из MenuGauge?", .cancel: "Отмена",
            .menuBarOverflow: "Строка меню переполнена — часть значений скрыта",
            .thermalState: "Тепловое состояние",
            .thermalNominal: "Норма", .thermalFair: "Повышенное",
            .thermalSerious: "Высокое", .thermalCritical: "Критическое",
        ],
        "pt": [
            .memory: "Memória", .disk: "Disco", .temperature: "Temperatura",
            .fan: "Ventoinha", .network: "Rede", .used: "Utilizado",
            .launchAtLogin: "Abrir ao iniciar sessão", .quit: "Sair do MenuGauge",
            .quitConfirm: "Sair do MenuGauge?", .cancel: "Cancelar",
            .menuBarOverflow: "Barra de menus cheia — alguns valores ocultos",
            .thermalState: "Estado térmico",
            .thermalNominal: "Normal", .thermalFair: "Moderado",
            .thermalSerious: "Alto", .thermalCritical: "Crítico",
        ],
    ]
}
