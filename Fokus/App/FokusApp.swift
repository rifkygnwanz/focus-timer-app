import SwiftUI
import SwiftData
import FokusCore
import FokusUI

// MARK: - FokusApp

@main
struct FokusApp: App {

    @State private var container: AppContainer?
    @State private var containerError: Error?

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    RootView(container: container)
                        .environment(\.locale, container.settingsViewModel.selectedLanguage.locale)
                        .modelContainer(container.modelContainer)
                } else if containerError != nil {
                    // Fallback minimal jika setup gagal
                    Text("Gagal memulai aplikasi.")
                        .foregroundStyle(.secondary)
                } else {
                    // Splash singkat saat container diinisialisasi
                    Color(UIColor.systemBackground)
                        .ignoresSafeArea()
                }
            }
            .task {
                do {
                    container = try await MainActor.run { try AppContainer.live() }
                } catch {
                    containerError = error
                }
            }
        }
    }
}

// MARK: - RootView

struct RootView: View {

    let container: AppContainer
    @State private var showSettings = false
    @State private var selectedTab: AppTab = .timer

    enum AppTab: Hashable {
        case timer, stats
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Timer", systemImage: "timer", value: AppTab.timer) {
                NavigationStack {
                    TimerScreen(viewModel: container.timerViewModel)
                    .navigationTitle("Fokus")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                                    .accessibilityLabel("Pengaturan")
                            }
                        }
                    }
                }
            }

            Tab("Statistik", systemImage: "chart.bar.fill", value: AppTab.stats) {
                StatsScreen(viewModel: container.statsViewModel)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsScreen(
                viewModel: container.settingsViewModel,
                appVersion: Bundle.main.fullVersion
            )
            .environment(\.locale, container.settingsViewModel.selectedLanguage.locale)
        }
    }
}

// MARK: - Bundle Extension

private extension Bundle {
    var fullVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
