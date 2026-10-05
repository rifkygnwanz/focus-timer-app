import AudioToolbox
import UIKit
import FokusCore

// MARK: - UIKitHapticProvider

/// Adapter haptic & audio feedback menggunakan UIKit dan AudioToolbox.
/// Mematuhi pengaturan Haptic dan Suara Akhir Fase dari App Group UserDefaults.
public final class UIKitHapticProvider: HapticFeedbackProviding {

    nonisolated(unsafe) private let defaults: UserDefaults

    public init(suiteName: String = "group.com.rifkygnwanz.fokus") {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    private var isHapticEnabled: Bool {
        defaults.object(forKey: SettingsKey.hapticEnabled.rawValue) as? Bool ?? true
    }

    private var currentSoundOption: PhaseEndSound {
        guard let raw = defaults.string(forKey: SettingsKey.soundOption.rawValue),
              let option = PhaseEndSound(rawValue: raw) else {
            return .defaultSound
        }
        return option
    }

    public func trigger(_ event: HapticEvent) {
        if event == .success, let soundID = currentSoundOption.systemSoundID {
            AudioServicesPlaySystemSound(soundID)
        }

        guard isHapticEnabled else { return }

        switch event {
        case .light:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        }
    }
}

// MARK: - NoOpActivityPresenter

/// Placeholder ActivityPresenting untuk pengujian atau fallback.
public final class NoOpActivityPresenter: ActivityPresenting {
    public init() {}
    public func startActivity(state: TimerState, configuration: TimerConfiguration) async {}
    public func updateActivity(state: TimerState) async {}
    public func endActivity() async {}
}
