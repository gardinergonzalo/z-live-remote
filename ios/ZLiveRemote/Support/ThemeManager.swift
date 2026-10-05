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
            accent = Color(red: 1.0, green: 0.541, blue: 0.396)
            ready = Color(red: 0.945, green: 0.667, blue: 0.235)
            playing = Color(red: 0.341, green: 0.773, blue: 0.518)
            danger = Color(red: 0.902, green: 0.424, blue: 0.424)

        case .light:
            background = Color(red: 0.949, green: 0.949, blue: 0.937)
            surface = .white
            surfaceSecondary = Color(red: 0.914, green: 0.914, blue: 0.898)
            line = Color(red: 0.831, green: 0.831, blue: 0.812)
            text = Color(red: 0.090, green: 0.090, blue: 0.090)
            muted = Color(red: 0.431, green: 0.431, blue: 0.412)
            accent = Color(red: 1.0, green: 0.463, blue: 0.302)
            ready = Color(red: 0.831, green: 0.541, blue: 0.094)
            playing = Color(red: 0.165, green: 0.545, blue: 0.341)
            danger = Color(red: 0.784, green: 0.294, blue: 0.294)
        }
    }
}
