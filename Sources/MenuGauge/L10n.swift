import Foundation

/// Minimal in-code localization. The .app is assembled by Scripts/build.sh
/// from a bare SwiftPM binary and ships no .lproj bundles, so the (tiny)
/// string table lives here and the language follows the user's preferred
/// language list. Unsupported languages fall back to English.
enum L10n {
    enum UI: String {
        case cpuUsage = "CPU usage", gpuUsage = "GPU usage"
        case cpuTemperature = "CPU temperature", ofTotal = "of %@ GB"
        case available = "Available"
    }

    /// Languages that have a full `Key` table. Chinese is matched before this
    /// list; the rest use a prefix of the preferred-language code.
    static let translatedLanguages = [
        "en", "zh-Hans", "zh-Hant", "ja", "ko", "hi", "es", "fr", "bn", "ru", "pt",
    ]

    static func ui(_ key: UI) -> String {
        let simplified: [UI: String] = [
            .cpuUsage: "CPU 占用", .gpuUsage: "GPU 占用",
            .cpuTemperature: "CPU 温度", .ofTotal: "共 %@ GB",
            .available: "可用",
        ]
        let traditional: [UI: String] = [
            .cpuUsage: "CPU 佔用", .gpuUsage: "GPU 佔用",
            .cpuTemperature: "CPU 溫度", .ofTotal: "共 %@ GB",
            .available: "可用",
        ]
        switch language {
        case "zh-Hans": return simplified[key] ?? key.rawValue
        case "zh-Hant": return traditional[key] ?? key.rawValue
        default: return key.rawValue
        }
    }

    enum Key: CaseIterable {
        case memory, disk, temperature, fan, network, used
        case launchAtLogin, quit, quitStatusBar, quitShort, quitConfirm, cancel
        case menuBarOverflow
        case gaugeStatus, gaugeStatusPending
        case thermalState, thermalNominal, thermalFair, thermalHeavy, thermalSerious, thermalCritical
        case showInMenu, logo, selectAtLeastOne, configHint
        case loginHint, loginPending, loginUnavailable, systemSettings
        case settings, settingsTitle, runningTitle, runningDetail
        case general, about, privacyPolicy, website, websiteEdition
        case language, followSystem, temperatureUnit
        case closeWindow, windowMenu
    }

    static func tr(_ key: Key) -> String {
        string(key, language: language)
    }

    static func string(_ key: Key, language: String) -> String {
        table[language]?[key] ?? table["en"]![key]!
    }

    static func contains(_ key: Key, language: String) -> Bool {
        table[language]?[key] != nil
    }

    /// First supported entry in the user's preferred language list.
    private static let systemLanguage: String = {
        for code in Locale.preferredLanguages {
            let lower = code.lowercased()
            if lower.hasPrefix("zh") {
                if lower.contains("hant") || lower.contains("-tw")
                    || lower.contains("-hk") || lower.contains("-mo") {
                    return "zh-Hant"
                }
                return "zh-Hans"
            }
            for lang in translatedLanguages where lang != "zh-Hans" && lang != "zh-Hant" {
                if lower.hasPrefix(lang) { return lang }
            }
        }
        return "en"
    }()

    /// UserDefaults key for the Settings language picker. Empty means the
    /// language follows the system.
    static let overrideKey = "languageOverride"

    /// Manual choice from Settings; "" follows the system.
    static var override: String {
        get { UserDefaults.standard.string(forKey: overrideKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: overrideKey) }
    }

    static var language: String {
        translatedLanguages.contains(override) ? override : systemLanguage
    }

    /// Picker label for a language code, in that language itself.
    static func displayName(_ code: String) -> String {
        switch code {
        case "en": return "English"
        case "zh-Hans": return "简体中文"
        case "zh-Hant": return "繁體中文"
        case "ja": return "日本語"
        case "ko": return "한국어"
        case "hi": return "हिन्दी"
        case "es": return "Español"
        case "fr": return "Français"
        case "bn": return "বাংলা"
        case "ru": return "Русский"
        case "pt": return "Português"
        default: return code
        }
    }

    private static let table: [String: [Key: String]] = [
        "en": [
            .memory: "Memory", .disk: "Disk", .temperature: "Temperature",
            .fan: "Fan", .network: "Network", .used: "Used",
            .launchAtLogin: "Start at Login", .quit: "Quit MenuGauge", .quitStatusBar: "Quit Status Bar",
            .quitShort: "Quit",
            .quitConfirm: "Quit MenuGauge?", .cancel: "Cancel",
            .menuBarOverflow: "Menu bar full — some widgets hidden",
            .gaugeStatus: "MenuGauge, CPU %d%%, %@",
            .gaugeStatusPending: "MenuGauge, %@",
            .thermalState: "Thermal state",
            .thermalNominal: "Nominal", .thermalFair: "Fair", .thermalHeavy: "Heavy",
            .thermalSerious: "Serious", .thermalCritical: "Critical",
            .showInMenu: "Show in status bar",
            .logo: "Logo",
            .selectAtLeastOne: "Select at least one",
            .configHint: "Enabled items appear in the menu bar, with the logo on the left. At least one stays on.",
            .loginHint: "Opens in the menu bar when you log in.",
            .loginPending: "Approval required in System Settings",
            .loginUnavailable: "Login item unavailable for this app",
            .systemSettings: "Open System Settings",
            .settings: "Settings",
            .settingsTitle: "MenuGauge Settings",
            .runningTitle: "MenuGauge is running in the menu bar",
            .runningDetail: "Click the gauge icon at the top right of the screen to see live CPU, GPU, memory and more. Closing this window keeps MenuGauge running in the menu bar.",
            .general: "General",
            .language: "Language", .followSystem: "Follow System", .temperatureUnit: "Temperature Unit", .about: "About",
            .privacyPolicy: "Privacy Policy", .website: "Website",
            .websiteEdition: "Website edition",
            .closeWindow: "Close", .windowMenu: "Window",
        ],
        "zh-Hans": [
            .memory: "内存", .disk: "磁盘", .temperature: "温度",
            .fan: "风扇", .network: "网络", .used: "已用",
            .launchAtLogin: "登录时启动", .quit: "退出 MenuGauge", .quitStatusBar: "退出状态栏",
            .quitShort: "退出",
            .quitConfirm: "确认退出 MenuGauge 吗？", .cancel: "取消",
            .menuBarOverflow: "菜单栏空间不足，部分数值已隐藏",
            .gaugeStatus: "MenuGauge，CPU %d%%，%@",
            .gaugeStatusPending: "MenuGauge，%@",
            .thermalState: "热状态",
            .thermalNominal: "正常", .thermalFair: "偏高", .thermalHeavy: "很高",
            .thermalSerious: "过热", .thermalCritical: "危急",
            .showInMenu: "状态栏显示",
            .logo: "图标",
            .selectAtLeastOne: "请至少选择一项",
            .configHint: "开启的项目会显示在菜单栏，图标在最左侧。至少保留一项。",
            .loginHint: "登录 Mac 后自动在菜单栏运行",
            .loginPending: "请在系统设置中允许开机自启动",
            .loginUnavailable: "此应用的登录项暂不可用",
            .systemSettings: "打开系统设置",
            .settings: "设置",
            .settingsTitle: "MenuGauge 设置",
            .runningTitle: "MenuGauge 已在菜单栏运行",
            .runningDetail: "点击屏幕右上角的仪表图标，随时查看 CPU、GPU、内存等实时数据。关掉这个窗口后，MenuGauge 会继续在菜单栏工作。",
            .general: "通用",
            .language: "语言", .followSystem: "跟随系统", .temperatureUnit: "温度单位", .about: "关于",
            .privacyPolicy: "隐私政策", .website: "官网",
            .websiteEdition: "官网版",
            .closeWindow: "关闭", .windowMenu: "窗口",
        ],
        "zh-Hant": [
            .memory: "記憶體", .disk: "磁碟", .temperature: "溫度",
            .fan: "風扇", .network: "網路", .used: "已用",
            .launchAtLogin: "登入時啟動", .quit: "結束 MenuGauge", .quitStatusBar: "退出狀態列",
            .quitShort: "結束",
            .quitConfirm: "確認結束 MenuGauge 嗎？", .cancel: "取消",
            .menuBarOverflow: "選單列空間不足，部分數值已隱藏",
            .gaugeStatus: "MenuGauge，CPU %d%%，%@",
            .gaugeStatusPending: "MenuGauge，%@",
            .thermalState: "熱狀態",
            .thermalNominal: "正常", .thermalFair: "偏高", .thermalHeavy: "很高",
            .thermalSerious: "過熱", .thermalCritical: "危急",
            .showInMenu: "狀態列顯示",
            .logo: "圖示",
            .selectAtLeastOne: "請至少選擇一項",
            .configHint: "開啟的項目會顯示於選單列，圖示在最左側。至少保留一項。",
            .loginHint: "登入 Mac 後會在選單列自動執行",
            .loginPending: "請在系統設定中允許登入時啟動",
            .loginUnavailable: "此應用程式的登入項目暫不可用",
            .systemSettings: "開啟系統設定",
            .settings: "設定",
            .settingsTitle: "MenuGauge 設定",
            .runningTitle: "MenuGauge 已在選單列執行",
            .runningDetail: "點一下畫面右上角的儀表圖示，就能查看 CPU、GPU、記憶體等即時數據。關掉這個視窗後，MenuGauge 會繼續在選單列運作。",
            .general: "一般",
            .language: "語言", .followSystem: "跟隨系統", .temperatureUnit: "溫度單位", .about: "關於",
            .privacyPolicy: "隱私權政策", .website: "官網",
            .websiteEdition: "官網版",
            .closeWindow: "關閉", .windowMenu: "視窗",
        ],
        "ja": [
            .memory: "メモリ", .disk: "ディスク", .temperature: "温度",
            .fan: "ファン", .network: "ネットワーク", .used: "使用済み",
            .launchAtLogin: "ログイン時に起動", .quit: "MenuGauge を終了", .quitStatusBar: "ステータスバーを終了",
            .quitShort: "終了",
            .quitConfirm: "MenuGauge を終了しますか？", .cancel: "キャンセル",
            .menuBarOverflow: "メニューバーの空き不足：一部の数値を非表示中",
            .gaugeStatus: "MenuGauge、CPU %d%%、%@",
            .gaugeStatusPending: "MenuGauge、%@",
            .thermalState: "熱状態",
            .thermalNominal: "正常", .thermalFair: "やや高め", .thermalHeavy: "高め",
            .thermalSerious: "高い", .thermalCritical: "危険",
            .showInMenu: "ステータスバーに表示",
            .logo: "ロゴ",
            .selectAtLeastOne: "少なくとも1つ選択",
            .configHint: "オンにした項目はメニューバーに表示され、ロゴは左端です。少なくとも1つはオンのままです。",
            .loginHint: "ログインするとメニューバーで自動的に起動します。",
            .loginPending: "システム設定での承認が必要です",
            .loginUnavailable: "このアプリのログイン項目は使えません",
            .systemSettings: "システム設定を開く",
            .settings: "設定",
            .settingsTitle: "MenuGauge 設定",
            .runningTitle: "MenuGauge はメニューバーで実行中です",
            .runningDetail: "画面右上のメーターアイコンをクリックすると、CPU、GPU、メモリなどの様子をその場で確認できます。このウインドウを閉じても、MenuGauge はメニューバーで動き続けます。",
            .general: "一般",
            .language: "言語", .followSystem: "システムに従う", .temperatureUnit: "温度単位", .about: "情報",
            .privacyPolicy: "プライバシーポリシー", .website: "公式サイト",
            .websiteEdition: "公式サイト版",
            .closeWindow: "閉じる", .windowMenu: "ウインドウ",
        ],
        "ko": [
            .memory: "메모리", .disk: "디스크", .temperature: "온도",
            .fan: "팬", .network: "네트워크", .used: "사용됨",
            .launchAtLogin: "로그인 시 시작", .quit: "MenuGauge 종료", .quitStatusBar: "상태 막대 종료",
            .quitShort: "종료",
            .quitConfirm: "MenuGauge를 종료하시겠습니까?", .cancel: "취소",
            .menuBarOverflow: "메뉴 막대 공간 부족: 일부 수치 숨김",
            .gaugeStatus: "MenuGauge, CPU %d%%, %@",
            .gaugeStatusPending: "MenuGauge, %@",
            .thermalState: "열 상태",
            .thermalNominal: "정상", .thermalFair: "보통", .thermalHeavy: "다소 높음",
            .thermalSerious: "높음", .thermalCritical: "위험",
            .showInMenu: "상태 막대에 표시",
            .logo: "로고",
            .selectAtLeastOne: "하나 이상 선택",
            .configHint: "켠 항목은 메뉴 막대에 나타나고 로고는 왼쪽에 있습니다. 하나 이상은 켜 둡니다.",
            .loginHint: "로그인하면 메뉴 막대에서 자동으로 실행됩니다.",
            .loginPending: "시스템 설정에서 승인이 필요합니다",
            .loginUnavailable: "이 앱의 로그인 항목을 사용할 수 없습니다",
            .systemSettings: "시스템 설정 열기",
            .settings: "설정",
            .settingsTitle: "MenuGauge 설정",
            .runningTitle: "MenuGauge가 메뉴 막대에서 실행 중입니다",
            .runningDetail: "화면 오른쪽 위의 게이지 아이콘을 클릭하면 CPU, GPU, 메모리 등의 실시간 정보를 볼 수 있습니다. 이 창을 닫아도 MenuGauge는 메뉴 막대에서 계속 실행됩니다.",
            .general: "일반",
            .language: "언어", .followSystem: "시스템 설정 따르기", .temperatureUnit: "온도 단위", .about: "정보",
            .privacyPolicy: "개인정보 처리방침", .website: "웹사이트",
            .websiteEdition: "웹사이트판",
            .closeWindow: "닫기", .windowMenu: "윈도우",
        ],
        "hi": [
            .memory: "मेमोरी", .disk: "डिस्क", .temperature: "तापमान",
            .fan: "पंखा", .network: "नेटवर्क", .used: "उपयोग किया हुआ",
            .launchAtLogin: "लॉगइन पर शुरू करें", .quit: "MenuGauge से बाहर निकलें", .quitStatusBar: "स्टेटस बार से बाहर निकलें",
            .quitShort: "बाहर निकलें",
            .quitConfirm: "MenuGauge से बाहर निकलें?", .cancel: "रद्द करें",
            .menuBarOverflow: "मेनू बार में जगह नहीं — कुछ मान छिपाए गए",
            .gaugeStatus: "MenuGauge, CPU %d%%, %@",
            .gaugeStatusPending: "MenuGauge, %@",
            .thermalState: "थर्मल स्थिति",
            .thermalNominal: "सामान्य", .thermalFair: "मध्यम", .thermalHeavy: "उच्च",
            .thermalSerious: "गंभीर", .thermalCritical: "अति गंभीर",
            .showInMenu: "स्टेटस बार में दिखाएँ",
            .logo: "लोगो",
            .selectAtLeastOne: "कम से कम एक चुनें",
            .configHint: "चालू आइटम मेनू बार में दिखते हैं, लोगो बाईं ओर रहता है। कम से कम एक चालू रहता है।",
            .loginHint: "लॉगइन करने पर मेनू बार में अपने आप खुलता है।",
            .loginPending: "सिस्टम सेटिंग्ज़ में अनुमति आवश्यक है",
            .loginUnavailable: "इस ऐप के लिए लॉगइन आइटम उपलब्ध नहीं है",
            .systemSettings: "सिस्टम सेटिंग्ज़ खोलें",
            .settings: "सेटिंग्ज़",
            .settingsTitle: "MenuGauge सेटिंग्ज़",
            .runningTitle: "MenuGauge मेनू बार में चल रहा है",
            .runningDetail: "स्क्रीन के ऊपर दाईं ओर गेज आइकॉन पर क्लिक करें — CPU, GPU, मेमोरी जैसी लाइव जानकारी दिखेगी। यह विंडो बंद करने पर भी MenuGauge मेनू बार में चलता रहता है।",
            .general: "सामान्य",
            .language: "भाषा", .followSystem: "सिस्टम का पालन करें", .temperatureUnit: "तापमान इकाई", .about: "परिचय",
            .privacyPolicy: "गोपनीयता नीति", .website: "वेबसाइट",
            .websiteEdition: "वेबसाइट संस्करण",
            .closeWindow: "बंद करें", .windowMenu: "विंडो",
        ],
        "es": [
            .memory: "Memoria", .disk: "Disco", .temperature: "Temperatura",
            .fan: "Ventilador", .network: "Red", .used: "Usado",
            .launchAtLogin: "Iniciar al iniciar sesión", .quit: "Salir de MenuGauge", .quitStatusBar: "Salir de la barra de estado",
            .quitShort: "Salir",
            .quitConfirm: "¿Salir de MenuGauge?", .cancel: "Cancelar",
            .menuBarOverflow: "Barra de menús llena — algunos valores ocultos",
            .gaugeStatus: "MenuGauge, CPU %d%%, %@",
            .gaugeStatusPending: "MenuGauge, %@",
            .thermalState: "Estado térmico",
            .thermalNominal: "Normal", .thermalFair: "Moderado", .thermalHeavy: "Elevado",
            .thermalSerious: "Alto", .thermalCritical: "Crítico",
            .showInMenu: "Mostrar en la barra de estado",
            .logo: "Logotipo",
            .selectAtLeastOne: "Selecciona al menos uno",
            .configHint: "Los elementos activados aparecen en la barra de menús, con el logotipo a la izquierda. Al menos uno permanece activo.",
            .loginHint: "Se abre en la barra de menús al iniciar sesión.",
            .loginPending: "Se requiere aprobación en Ajustes del Sistema",
            .loginUnavailable: "El ítem de inicio de sesión no está disponible para esta app",
            .systemSettings: "Abrir Ajustes del Sistema",
            .settings: "Ajustes",
            .settingsTitle: "Ajustes de MenuGauge",
            .runningTitle: "MenuGauge se está ejecutando en la barra de menús",
            .runningDetail: "Haz clic en el icono del indicador, arriba a la derecha, para ver la CPU, la GPU, la memoria y más en tiempo real. Al cerrar esta ventana, MenuGauge sigue en la barra de menús.",
            .general: "General",
            .language: "Idioma", .followSystem: "Como el sistema", .temperatureUnit: "Unidad de temperatura", .about: "Acerca de",
            .privacyPolicy: "Política de privacidad", .website: "Sitio web",
            .websiteEdition: "Edición del sitio web",
            .closeWindow: "Cerrar", .windowMenu: "Ventana",
        ],
        "fr": [
            .memory: "Mémoire", .disk: "Disque", .temperature: "Température",
            .fan: "Ventilateur", .network: "Réseau", .used: "Utilisé",
            .launchAtLogin: "Démarrer à la connexion", .quit: "Quitter MenuGauge", .quitStatusBar: "Quitter la barre d’état",
            .quitShort: "Quitter",
            .quitConfirm: "Quitter MenuGauge ?", .cancel: "Annuler",
            .menuBarOverflow: "Barre des menus pleine — certaines valeurs masquées",
            .gaugeStatus: "MenuGauge, CPU %d %%, %@",
            .gaugeStatusPending: "MenuGauge, %@",
            .thermalState: "État thermique",
            .thermalNominal: "Normal", .thermalFair: "Modéré", .thermalHeavy: "Fort",
            .thermalSerious: "Élevé", .thermalCritical: "Critique",
            .showInMenu: "Afficher dans la barre d’état",
            .logo: "Logo",
            .selectAtLeastOne: "Sélectionnez au moins un",
            .configHint: "Les éléments activés apparaissent dans la barre des menus, logo à gauche. Un élément au moins reste activé.",
            .loginHint: "S’ouvre dans la barre des menus à la connexion.",
            .loginPending: "Approbation requise dans Réglages Système",
            .loginUnavailable: "L’élément d’ouverture n’est pas disponible pour cette app",
            .systemSettings: "Ouvrir Réglages Système",
            .settings: "Réglages",
            .settingsTitle: "Réglages de MenuGauge",
            .runningTitle: "MenuGauge est en cours d’exécution dans la barre des menus",
            .runningDetail: "Cliquez sur l’icône de la jauge en haut à droite de l’écran pour voir le CPU, le GPU, la mémoire et le reste en direct. Si vous fermez cette fenêtre, MenuGauge continue de fonctionner dans la barre des menus.",
            .general: "Général",
            .language: "Langue", .followSystem: "Comme le système", .temperatureUnit: "Unité de température", .about: "À propos",
            .privacyPolicy: "Politique de confidentialité", .website: "Site web",
            .websiteEdition: "Édition du site web",
            .closeWindow: "Fermer", .windowMenu: "Fenêtre",
        ],
        "bn": [
            .memory: "মেমরি", .disk: "ডিস্ক", .temperature: "তাপমাত্রা",
            .fan: "ফ্যান", .network: "নেটওয়ার্ক", .used: "ব্যবহৃত",
            .launchAtLogin: "লগইনে চালু করুন", .quit: "MenuGauge বন্ধ করুন", .quitStatusBar: "স্ট্যাটাস বার বন্ধ করুন",
            .quitShort: "বন্ধ",
            .quitConfirm: "MenuGauge বন্ধ করবেন?", .cancel: "বাতিল",
            .menuBarOverflow: "মেনু বারে জায়গা নেই — কিছু মান লুকানো হয়েছে",
            .gaugeStatus: "MenuGauge, CPU %d%%, %@",
            .gaugeStatusPending: "MenuGauge, %@",
            .thermalState: "তাপের অবস্থা",
            .thermalNominal: "স্বাভাবিক", .thermalFair: "মাঝারি", .thermalHeavy: "বেশি",
            .thermalSerious: "উচ্চ", .thermalCritical: "সংকটপূর্ণ",
            .showInMenu: "স্ট্যাটাস বারে দেখান",
            .logo: "লোগো",
            .selectAtLeastOne: "অন্তত একটি বেছে নিন",
            .configHint: "চালু করা আইটেম মেনু বারে দেখা যায়, লোগো বাঁ দিকে থাকে। অন্তত একটি চালু থাকে।",
            .loginHint: "লগইন করলে মেনু বারে নিজে থেকে চলবে।",
            .loginPending: "সিস্টেম সেটিংসে অনুমোদন প্রয়োজন",
            .loginUnavailable: "এই অ্যাপের লগইন আইটেম এখন উপলভ্য নয়",
            .systemSettings: "সিস্টেম সেটিংস খুলুন",
            .settings: "সেটিংস",
            .settingsTitle: "MenuGauge সেটিংস",
            .runningTitle: "MenuGauge মেনু বারে চলছে",
            .runningDetail: "স্ক্রিনের উপরে ডান দিকের গেজ আইকনে ক্লিক করলে CPU, GPU, মেমরিসহ লাইভ তথ্য দেখা যায়। এই উইন্ডো বন্ধ করলেও MenuGauge মেনু বারে চলতে থাকে।",
            .general: "সাধারণ",
            .language: "ভাষা", .followSystem: "সিস্টেম অনুসরণ করুন", .temperatureUnit: "তাপমাত্রার একক", .about: "পরিচিতি",
            .privacyPolicy: "গোপনীয়তা নীতি", .website: "ওয়েবসাইট",
            .websiteEdition: "ওয়েবসাইট সংস্করণ",
            .closeWindow: "বন্ধ করুন", .windowMenu: "উইন্ডো",
        ],
        "ru": [
            .memory: "Память", .disk: "Диск", .temperature: "Температура",
            .fan: "Вентилятор", .network: "Сеть", .used: "Использовано",
            .launchAtLogin: "Запускать при входе", .quit: "Выйти из MenuGauge", .quitStatusBar: "Выйти из строки состояния",
            .quitShort: "Выйти",
            .quitConfirm: "Выйти из MenuGauge?", .cancel: "Отмена",
            .menuBarOverflow: "Строка меню переполнена — часть значений скрыта",
            .gaugeStatus: "MenuGauge, ЦП %d%%, %@",
            .gaugeStatusPending: "MenuGauge, %@",
            .thermalState: "Тепловое состояние",
            .thermalNominal: "Норма", .thermalFair: "Повышенное", .thermalHeavy: "Сильное",
            .thermalSerious: "Высокое", .thermalCritical: "Критическое",
            .showInMenu: "Показывать в строке состояния",
            .logo: "Логотип",
            .selectAtLeastOne: "Выберите хотя бы один",
            .configHint: "Включённые пункты показываются в строке меню, логотип слева. Хотя бы один остаётся включённым.",
            .loginHint: "При входе запускается в строке меню.",
            .loginPending: "Нужно разрешение в Системных настройках",
            .loginUnavailable: "Объект входа недоступен для этого приложения",
            .systemSettings: "Открыть Системные настройки",
            .settings: "Настройки",
            .settingsTitle: "Настройки MenuGauge",
            .runningTitle: "MenuGauge работает в строке меню",
            .runningDetail: "Нажмите значок индикатора справа вверху экрана — там живые CPU, GPU, память и остальное. Если закрыть это окно, MenuGauge продолжит работать в строке меню.",
            .general: "Основные",
            .language: "Язык", .followSystem: "Как в системе", .temperatureUnit: "Единица температуры", .about: "О программе",
            .privacyPolicy: "Политика конфиденциальности", .website: "Сайт",
            .websiteEdition: "Версия с сайта",
            .closeWindow: "Закрыть", .windowMenu: "Окно",
        ],
        "pt": [
            .memory: "Memória", .disk: "Disco", .temperature: "Temperatura",
            .fan: "Ventoinha", .network: "Rede", .used: "Utilizado",
            .launchAtLogin: "Iniciar ao iniciar sessão", .quit: "Sair do MenuGauge", .quitStatusBar: "Sair da barra de estado",
            .quitShort: "Sair",
            .quitConfirm: "Sair do MenuGauge?", .cancel: "Cancelar",
            .menuBarOverflow: "Barra de menus cheia — alguns valores ocultos",
            .gaugeStatus: "MenuGauge, CPU %d%%, %@",
            .gaugeStatusPending: "MenuGauge, %@",
            .thermalState: "Estado térmico",
            .thermalNominal: "Normal", .thermalFair: "Moderado", .thermalHeavy: "Elevado",
            .thermalSerious: "Alto", .thermalCritical: "Crítico",
            .showInMenu: "Mostrar na barra de estado",
            .logo: "Logótipo",
            .selectAtLeastOne: "Selecione pelo menos um",
            .configHint: "Os itens ativados aparecem na barra de menus, com o logótipo à esquerda. Pelo menos um fica ativo.",
            .loginHint: "Abre na barra de menus ao iniciar sessão.",
            .loginPending: "É necessária aprovação nas Definições do Sistema",
            .loginUnavailable: "O item de início de sessão não está disponível para esta app",
            .systemSettings: "Abrir Definições do Sistema",
            .settings: "Definições",
            .settingsTitle: "Definições do MenuGauge",
            .runningTitle: "O MenuGauge está em execução na barra de menus",
            .runningDetail: "Clique no ícone do indicador no canto superior direito do ecrã para ver a CPU, a GPU, a memória e outros valores em tempo real. Fechar esta janela mantém o MenuGauge na barra de menus.",
            .general: "Geral",
            .language: "Idioma", .followSystem: "Como o sistema", .temperatureUnit: "Unidade de temperatura", .about: "Acerca de",
            .privacyPolicy: "Política de Privacidade", .website: "Site",
            .websiteEdition: "Edição do site",
            .closeWindow: "Fechar", .windowMenu: "Janela",
        ],
    ]
}
