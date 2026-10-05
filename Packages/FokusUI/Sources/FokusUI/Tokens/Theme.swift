import SwiftUI
import FokusCore

// MARK: - Palette

public enum Palette {
    // MARK: Semantic
    public static let accent = adaptiveColor(
        named: "AccentColor",
        light: UIColor(red: 1.00, green: 0.51, blue: 0.22, alpha: 1.0),
        dark: UIColor(red: 1.00, green: 0.58, blue: 0.30, alpha: 1.0)
    )
    public static let background = Color(UIColor.systemBackground)
    public static let secondaryBackground = Color(UIColor.secondarySystemBackground)
    public static let cardBackground = Color(UIColor.secondarySystemGroupedBackground)
    public static let label = Color(UIColor.label)
    public static let secondaryLabel = Color(UIColor.secondaryLabel)
    public static let separator = Color(UIColor.separator)

    // MARK: Phase Colors
    public static func phaseBackground(for phase: TimerPhase) -> Color {
        Color(UIColor(red: 0.50, green: 0.50, blue: 0.50, alpha: 0.06))
    }

    public static func phaseAccent(for phase: TimerPhase) -> Color {
        switch phase {
        case .focus:
            adaptiveColor(
                named: "FocusAccent",
                light: UIColor(red: 1.00, green: 0.51, blue: 0.22, alpha: 1.0),
                dark: UIColor(red: 1.00, green: 0.58, blue: 0.30, alpha: 1.0)
            )
        case .shortBreak:
            adaptiveColor(
                named: "ShortBreakAccent",
                light: UIColor(red: 0.20, green: 0.82, blue: 0.71, alpha: 1.0),
                dark: UIColor(red: 0.28, green: 0.88, blue: 0.78, alpha: 1.0)
            )
        case .longBreak:
            adaptiveColor(
                named: "LongBreakAccent",
                light: UIColor(red: 0.48, green: 0.45, blue: 0.90, alpha: 1.0),
                dark: UIColor(red: 0.57, green: 0.54, blue: 0.96, alpha: 1.0)
            )
        }
    }

    private static func adaptiveColor(named name: String, light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traits in
            if let assetColor = UIColor(named: name, in: .main, compatibleWith: traits) {
                return assetColor
            }
            return traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

// MARK: - Typography

public enum Typography {
    public static let timer = Font.system(.largeTitle, design: .rounded, weight: .bold)
        .monospacedDigit()
    public static let timerLarge = Font.system(size: 72, weight: .bold, design: .rounded)
        .monospacedDigit()
    public static let headline = Font.system(.headline, design: .rounded, weight: .semibold)
    public static let subheadline = Font.system(.subheadline, design: .rounded)
    public static let body = Font.system(.body, design: .rounded)
    public static let caption = Font.system(.caption, design: .rounded)
    public static let caption2 = Font.system(.caption2, design: .rounded)
    public static let statValue = Font.system(.title, design: .rounded, weight: .bold)
        .monospacedDigit()
    public static let statLabel = Font.system(.footnote, design: .rounded, weight: .medium)
}

// MARK: - PhaseStyle

/// Satu sumber kebenaran untuk ikon, warna, dan nama per fase.
/// Dipakai di app dan Live Activity extension.
public struct PhaseStyle: Sendable {
    public let phase: TimerPhase
    public let symbolName: String
    public let name: String      // Sudah dilokalisasi
    public let color: Color

    public var titleKey: LocalizedStringKey {
        switch phase {
        case .focus: "Fokus"
        case .shortBreak: "Istirahat Pendek"
        case .longBreak: "Istirahat Panjang"
        }
    }

    private init(phase: TimerPhase, symbolName: String, name: String, color: Color) {
        self.phase = phase
        self.symbolName = symbolName
        self.name = name
        self.color = color
    }

    public static func style(for phase: TimerPhase) -> PhaseStyle {
        switch phase {
        case .focus:
            PhaseStyle(
                phase: .focus,
                symbolName: "brain.head.profile",
                name: String(localized: "Fokus"),
                color: Palette.phaseAccent(for: .focus)
            )
        case .shortBreak:
            PhaseStyle(
                phase: .shortBreak,
                symbolName: "cup.and.saucer.fill",
                name: String(localized: "Istirahat Pendek"),
                color: Palette.phaseAccent(for: .shortBreak)
            )
        case .longBreak:
            PhaseStyle(
                phase: .longBreak,
                symbolName: "moon.fill",
                name: String(localized: "Istirahat Panjang"),
                color: Palette.phaseAccent(for: .longBreak)
            )
        }
    }
}
