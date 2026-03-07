import Foundation

/// Available app languages.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case japanese = "ja"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return L10n.string("language.system")
        case .english: return "English"
        case .japanese: return "日本語"
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

    private var _bundle: Bundle?

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.languageKey) ?? "system"
        currentLanguage = AppLanguage(rawValue: stored) ?? .system
    }

    /// The bundle for the currently selected language.
    var bundle: Bundle {
        if let cached = _bundle { return cached }
        let resolved = resolveBundle()
        _bundle = resolved
        return resolved
    }

    /// Resolved language code (never "system").
    var resolvedLanguageCode: String {
        switch currentLanguage {
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            if preferred.hasPrefix("ja") { return "ja" }
            return "en"
        case .english: return "en"
        case .japanese: return "ja"
        }
    }

    private func resolveBundle() -> Bundle {
        let code = resolvedLanguageCode

        // Try to find the .lproj in the module bundle
        if let path = Bundle.module.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
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
