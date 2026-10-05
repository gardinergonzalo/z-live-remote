import SwiftUI

enum AppTheme: String {
    case light
    case dark

    var colorScheme: ColorScheme {
        switch self {
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// Shows the action the button will perform.
    var toggleIcon: String {
        switch self {
        case .light: return "moon.fill"
        case .dark: return "sun.max.fill"
        }
    }

    var toggleAccessibilityLabel: String {
        switch self {
        case .light: return "Cambiar a tema oscuro"
        case .dark: return "Cambiar a tema claro"
        }
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    private static let storageKey = "zlr.appearance.theme"

    @Published private(set) var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: Self.storageKey)
        }
    }

    init() {
        if
            let rawValue = UserDefaults.standard.string(forKey: Self.storageKey),
            let storedTheme = AppTheme(rawValue: rawValue)
        {
            theme = storedTheme
        } else {
            theme = .dark
        }
    }

    func toggle() {
        theme = theme == .dark ? .light : .dark
    }
}

struct AppPalette {
    let background: Color
    let surface: Color
    let surfaceSecondary: Color
    let line: Color
    let text: Color
    let muted: Color
    let accent: Color
    let ready: Color
    let playing: Color
    let danger: Color

    init(theme: AppTheme) {
        switch theme {
        case .dark:
            background = Color(red: 0.106, green: 0.106, blue: 0.102)
            surface = Color(red: 0.141, green: 0.141, blue: 0.137)
            surfaceSecondary = Color(red: 0.176, green: 0.176, blue: 0.169)
            line = Color(red: 0.239, green: 0.239, blue: 0.227)
            text = Color(red: 0.949, green: 0.949, blue: 0.937)
            muted = Color(red: 0.647, green: 0.647, blue: 0.624)
            accent = Color(red: 1.0, green: 0.416, blue: 0.0)
            ready = Color(red: 1.0, green: 0.584, blue: 0.0)
            playing = Color(red: 0.196, green: 0.835, blue: 0.514)
            danger = Color(red: 1.0, green: 0.271, blue: 0.227)

        case .light:
            background = Color(red: 0.949, green: 0.949, blue: 0.937)
            surface = .white
            surfaceSecondary = Color(red: 0.914, green: 0.914, blue: 0.898)
            line = Color(red: 0.831, green: 0.831, blue: 0.812)
            text = Color(red: 0.090, green: 0.090, blue: 0.090)
            muted = Color(red: 0.431, green: 0.431, blue: 0.412)
            accent = Color(red: 0.957, green: 0.361, blue: 0.0)
            ready = Color(red: 0.914, green: 0.498, blue: 0.0)
            playing = Color(red: 0.063, green: 0.635, blue: 0.314)
            danger = Color(red: 0.851, green: 0.176, blue: 0.125)
        }
    }
}
