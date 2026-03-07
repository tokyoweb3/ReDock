import Foundation

/// Available app languages.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case japanese = "ja"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case korean = "ko"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case portuguese = "pt-BR"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .japanese: return "日本語"
        case .chineseSimplified: return "简体中文"
        case .chineseTraditional: return "繁體中文"
        case .korean: return "한국어"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .portuguese: return "Português (Brasil)"
        }
    }

    /// Label suffix when this language matches the system language.
    var systemSuffix: String {
        switch self {
        case .japanese: return " (システム)"
        case .chineseSimplified, .chineseTraditional: return " (系统)"
        case .korean: return " (시스템)"
        case .spanish: return " (Sistema)"
        case .french: return " (Système)"
        case .german: return " (System)"
        case .portuguese: return " (Sistema)"
        case .english: return " (System)"
        }
    }
}

/// Manages app-level localization, independent of system language.
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    private static let languageKey = "appLanguage"

    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: Self.languageKey)
            _bundle = nil // Reset cached bundle
        }
    }

    /// Whether the user has explicitly chosen a language (vs. using system default).
    var isUserOverridden: Bool {
        UserDefaults.standard.string(forKey: Self.languageKey) != nil
    }

    private var _bundle: Bundle?

    private init() {
        if let stored = UserDefaults.standard.string(forKey: Self.languageKey),
           let language = AppLanguage(rawValue: stored) {
            // User explicitly chose a language
            currentLanguage = language
        } else {
            // Default: follow system language
            currentLanguage = Self.detectSystemLanguage()
        }
    }

    /// Detect the system's preferred language, falling back to English.
    static func detectSystemLanguage() -> AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("ja") { return .japanese }
        if preferred.hasPrefix("zh-Hans") || preferred.hasPrefix("zh-CN") { return .chineseSimplified }
        if preferred.hasPrefix("zh-Hant") || preferred.hasPrefix("zh-TW") || preferred.hasPrefix("zh-HK") { return .chineseTraditional }
        if preferred.hasPrefix("zh") { return .chineseSimplified } // Generic Chinese fallback
        if preferred.hasPrefix("ko") { return .korean }
        if preferred.hasPrefix("es") { return .spanish }
        if preferred.hasPrefix("fr") { return .french }
        if preferred.hasPrefix("de") { return .german }
        if preferred.hasPrefix("pt") { return .portuguese }
        return .english
    }

    /// The bundle for the currently selected language.
    var bundle: Bundle {
        if let cached = _bundle { return cached }
        let resolved = resolveBundle()
        _bundle = resolved
        return resolved
    }

    /// Resolved language code.
    var resolvedLanguageCode: String {
        currentLanguage.rawValue
    }

    /// Reset to system default (remove user override).
    func resetToSystem() {
        UserDefaults.standard.removeObject(forKey: Self.languageKey)
        currentLanguage = Self.detectSystemLanguage()
    }

    private func resolveBundle() -> Bundle {
        let code = resolvedLanguageCode

        // SPM may lowercase the lproj directory name, so try both
        let candidates = [code, code.lowercased()]
        for candidate in candidates {
            if let path = Bundle.module.path(forResource: candidate, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }

        // Fallback to English
        if code != "en",
           let path = Bundle.module.path(forResource: "en", ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        return Bundle.module
    }
}

/// Localization helper. Usage: `L10n.string("key")` or `L10n.string("key", arg1, arg2)`
enum L10n {
    /// Look up a localized string by key.
    static func string(_ key: String) -> String {
        let bundle = LocalizationManager.shared.bundle
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    /// Look up a localized format string and apply arguments.
    static func string(_ key: String, _ args: CVarArg...) -> String {
        let format = string(key)
        return String(format: format, arguments: args)
    }
}
