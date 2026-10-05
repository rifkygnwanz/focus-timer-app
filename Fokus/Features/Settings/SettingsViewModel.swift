import AudioToolbox
import Foundation
import SwiftUI
import FokusCore

// MARK: - SettingsKey

/// Kunci UserDefaults yang bertipe. Tidak ada magic string. (15.4)
public nonisolated enum SettingsKey: String {
    case focusMinutes      = "fokus.focusMinutes"
    case shortBreakMinutes = "fokus.shortBreakMinutes"
    case longBreakMinutes  = "fokus.longBreakMinutes"
    case cyclesPerRound    = "fokus.cyclesPerRound"
    case autoStartBreaks   = "fokus.autoStartBreaks"
    case autoStartFocus    = "fokus.autoStartFocus"
    case hapticEnabled     = "fokus.hapticEnabled"
    case keepScreenOn      = "fokus.keepScreenOn"
    case soundOption       = "fokus.soundOption"
    case appLanguage       = "fokus.appLanguage"
}

// MARK: - AppLanguage

public nonisolated enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system     = "system"
    case indonesian = "id"
    case english    = "en"

    public var id: String { rawValue }

    public var displayNameKey: LocalizedStringKey {
        switch self {
        case .system:     "Ikuti Sistem"
        case .indonesian: "Bahasa Indonesia"
        case .english:    "English"
        }
    }

    public var displayName: String {
        switch self {
        case .system:     String(localized: "Ikuti Sistem")
        case .indonesian: "Bahasa Indonesia"
        case .english:    "English"
        }
    }

    public var locale: Locale {
        switch self {
        case .system:     .autoupdatingCurrent
        case .indonesian: Locale(identifier: "id")
        case .english:    Locale(identifier: "en")
        }
    }
}

// MARK: - DurationPreset

public nonisolated enum DurationPreset: String, CaseIterable, Identifiable, Sendable {
    case classic  = "classic"
    case deepWork = "deepWork"
    case sprint   = "sprint"

    public var id: String { rawValue }

    public var titleKey: LocalizedStringKey {
        switch self {
        case .classic:  "Klasik"
        case .deepWork: "Fokus Dalam"
        case .sprint:   "Sprint"
        }
    }

    public var title: String {
        switch self {
        case .classic:  String(localized: "Klasik")
        case .deepWork: String(localized: "Fokus Dalam")
        case .sprint:   String(localized: "Sprint")
        }
    }

    public var focusMinutes: Int {
        switch self {
        case .classic: 25
        case .deepWork: 50
        case .sprint: 15
        }
    }

    public var shortBreakMinutes: Int {
        switch self {
        case .classic: 5
        case .deepWork: 10
        case .sprint: 3
        }
    }

    public var longBreakMinutes: Int {
        switch self {
        case .classic: 15
        case .deepWork: 25
        case .sprint: 10
        }
    }
}

// MARK: - PhaseEndSound

/// Pilihan suara akhir fase (Spesifikasi 9.3).
public nonisolated enum PhaseEndSound: String, CaseIterable, Identifiable, Sendable {
    case defaultSound = "default"
    case triTone      = "tritone"
    case chime        = "chime"
    case bell         = "bell"
    case silent       = "silent"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .defaultSound: String(localized: "Standar")
        case .triTone:      String(localized: "Nada Tiga")
        case .chime:        String(localized: "Dering Lembut")
        case .bell:         String(localized: "Lonceng")
        case .silent:       String(localized: "Tanpa Suara")
        }
    }

    public var displayNameKey: LocalizedStringKey {
        switch self {
        case .defaultSound: "Standar"
        case .triTone:      "Nada Tiga"
        case .chime:        "Dering Lembut"
        case .bell:         "Lonceng"
        case .silent:       "Tanpa Suara"
        }
    }

    public var systemSoundID: SystemSoundID? {
        switch self {
        case .defaultSound: 1007
        case .triTone:      1002
        case .chime:        1013
        case .bell:         1005
        case .silent:       nil
        }
    }
}

// MARK: - SettingsViewModel

@Observable
@MainActor
public final class SettingsViewModel {

    var focusMinutes: Int {
        didSet {
            save(.focusMinutes, value: focusMinutes)
            notifyConfigurationChanged(didChangeDuration: true)
        }
    }
    var shortBreakMinutes: Int {
        didSet {
            save(.shortBreakMinutes, value: shortBreakMinutes)
            notifyConfigurationChanged(didChangeDuration: true)
        }
    }
    var longBreakMinutes: Int {
        didSet {
            save(.longBreakMinutes, value: longBreakMinutes)
            notifyConfigurationChanged(didChangeDuration: true)
        }
    }
    var cyclesPerRound: Int {
        didSet {
            save(.cyclesPerRound, value: cyclesPerRound)
            notifyConfigurationChanged(didChangeDuration: true)
        }
    }
    var autoStartBreaks: Bool {
        didSet {
            save(.autoStartBreaks, value: autoStartBreaks)
            notifyConfigurationChanged(didChangeDuration: false)
        }
    }
    var autoStartFocus: Bool {
        didSet {
            save(.autoStartFocus, value: autoStartFocus)
            notifyConfigurationChanged(didChangeDuration: false)
        }
    }
    var hapticEnabled: Bool {
        didSet {
            save(.hapticEnabled, value: hapticEnabled)
            onHapticChanged?(hapticEnabled)
        }
    }
    var keepScreenOn: Bool {
        didSet {
            save(.keepScreenOn, value: keepScreenOn)
            onKeepScreenOnChanged?(keepScreenOn)
        }
    }
    var soundOption: PhaseEndSound {
        didSet {
            save(.soundOption, value: soundOption.rawValue)
            previewSound(soundOption)
        }
    }
    var selectedLanguage: AppLanguage {
        didSet {
            save(.appLanguage, value: selectedLanguage.rawValue)
            onLanguageChanged?(selectedLanguage)
        }
    }

    // MARK: Active Timer Awareness (BR-09)

    var isTimerActive: Bool = false
    var hasPendingDurationChanges: Bool = false

    // MARK: Integration Callbacks

    var onConfigurationChanged: ((TimerConfiguration) -> Void)?
    var onApplyConfigurationAndReset: ((TimerConfiguration) async -> Void)?
    var onKeepScreenOnChanged: ((Bool) -> Void)?
    var onHapticChanged: ((Bool) -> Void)?
    var onLanguageChanged: ((AppLanguage) -> Void)?
    var onClearHistory: (() async -> Void)?

    private let defaults: UserDefaults

    public init(suiteName: String = "group.com.rifkygnwanz.fokus") {
        let userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        self.defaults = userDefaults
        self.focusMinutes = userDefaults.integer(forKey: SettingsKey.focusMinutes.rawValue).nonZeroOr(25)
        self.shortBreakMinutes = userDefaults.integer(forKey: SettingsKey.shortBreakMinutes.rawValue).nonZeroOr(5)
        self.longBreakMinutes = userDefaults.integer(forKey: SettingsKey.longBreakMinutes.rawValue).nonZeroOr(15)
        self.cyclesPerRound = userDefaults.integer(forKey: SettingsKey.cyclesPerRound.rawValue).nonZeroOr(4)
        self.autoStartBreaks = userDefaults.object(forKey: SettingsKey.autoStartBreaks.rawValue) as? Bool ?? true
        self.autoStartFocus = userDefaults.bool(forKey: SettingsKey.autoStartFocus.rawValue)
        self.hapticEnabled = userDefaults.object(forKey: SettingsKey.hapticEnabled.rawValue) as? Bool ?? true
        self.keepScreenOn = userDefaults.object(forKey: SettingsKey.keepScreenOn.rawValue) as? Bool ?? true

        if let rawSound = userDefaults.string(forKey: SettingsKey.soundOption.rawValue),
           let parsedSound = PhaseEndSound(rawValue: rawSound) {
            self.soundOption = parsedSound
        } else {
            self.soundOption = .defaultSound
        }

        if let rawLang = userDefaults.string(forKey: SettingsKey.appLanguage.rawValue),
           let parsedLang = AppLanguage(rawValue: rawLang) {
            self.selectedLanguage = parsedLang
        } else {
            self.selectedLanguage = .system
        }
    }

    var configuration: TimerConfiguration {
        TimerConfiguration(
            focusMinutes: focusMinutes,
            shortBreakMinutes: shortBreakMinutes,
            longBreakMinutes: longBreakMinutes,
            cyclesPerRound: cyclesPerRound,
            autoStartBreaks: autoStartBreaks,
            autoStartFocus: autoStartFocus
        )
    }

    func isPresetSelected(_ preset: DurationPreset) -> Bool {
        focusMinutes == preset.focusMinutes &&
        shortBreakMinutes == preset.shortBreakMinutes &&
        longBreakMinutes == preset.longBreakMinutes
    }

    func applyPreset(_ preset: DurationPreset) {
        focusMinutes = preset.focusMinutes
        shortBreakMinutes = preset.shortBreakMinutes
        longBreakMinutes = preset.longBreakMinutes
    }

    func applyChangesNowAndResetTimer() async {
        await onApplyConfigurationAndReset?(configuration)
        hasPendingDurationChanges = false
        isTimerActive = false
    }

    func syncTimerActiveState(isActive: Bool, hasPending: Bool) {
        self.isTimerActive = isActive
        if !isActive {
            self.hasPendingDurationChanges = false
        } else {
            self.hasPendingDurationChanges = hasPending
        }
    }

    func resetToDefaults() {
        focusMinutes = 25
        shortBreakMinutes = 5
        longBreakMinutes = 15
        cyclesPerRound = 4
        autoStartBreaks = true
        autoStartFocus = false
        hapticEnabled = true
        keepScreenOn = true
        soundOption = .defaultSound
        selectedLanguage = .system
    }

    func clearAllHistory() async {
        await onClearHistory?()
    }

    // MARK: - Private

    private func save(_ key: SettingsKey, value: some Any) {
        defaults.set(value, forKey: key.rawValue)
    }

    private func notifyConfigurationChanged(didChangeDuration: Bool) {
        if isTimerActive && didChangeDuration {
            hasPendingDurationChanges = true
        }
        onConfigurationChanged?(configuration)
    }

    private func previewSound(_ option: PhaseEndSound) {
        guard let soundID = option.systemSoundID else { return }
        AudioServicesPlaySystemSound(soundID)
    }
}

private extension Int {
    func nonZeroOr(_ fallback: Int) -> Int {
        self == 0 ? fallback : self
    }
}
