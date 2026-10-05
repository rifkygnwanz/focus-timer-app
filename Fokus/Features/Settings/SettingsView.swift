import SwiftUI
import FokusUI
import FokusCore

// MARK: - SettingsScreen

struct SettingsScreen: View {

    @Bindable var viewModel: SettingsViewModel
    let appVersion: String

    @Environment(\.dismiss) private var dismiss
    @State private var showResetAlert = false
    @State private var showClearHistoryAlert = false
    @State private var showApplyNowAlert = false

    var body: some View {
        NavigationStack {
            List {
                durationSection
                behaviorSection
                feedbackSection
                languageSection
                dataSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Pengaturan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Selesai") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .alert("Terapkan Durasi Baru Sekarang?", isPresented: $showApplyNowAlert) {
                Button("Reset Timer & Terapkan", role: .destructive) {
                    Task {
                        await viewModel.applyChangesNowAndResetTimer()
                    }
                }
                Button("Tunggu Fase Berikutnya", role: .cancel) {}
            } message: {
                Text("Timer yang sedang berjalan akan dihentikan dan direset menggunakan durasi baru ini.")
            }
            .alert("Kembalikan Pengaturan Awal?", isPresented: $showResetAlert) {
                Button("Kembalikan", role: .destructive) {
                    viewModel.resetToDefaults()
                }
                Button("Batalkan", role: .cancel) {}
            } message: {
                Text("Semua pengaturan durasi dan perilaku akan dikembalikan ke standar Pomodoro (25/5/15 menit).")
            }
            .alert("Hapus Semua Riwayat?", isPresented: $showClearHistoryAlert) {
                Button("Hapus Semua", role: .destructive) {
                    Task {
                        await viewModel.clearAllHistory()
                    }
                }
                Button("Batalkan", role: .cancel) {}
            } message: {
                Text("Seluruh data sesi dan statistik fokus akan dihapus secara permanen dari perangkat ini.")
            }
        }
    }

    // MARK: - Sections

    private var durationSection: some View {
        Section {
            presetSelectorRow

            DurationStepperRow(
                label: "Fokus",
                range: 5...90,
                step: 5,
                value: $viewModel.focusMinutes
            )
            DurationStepperRow(
                label: "Istirahat Pendek",
                range: 1...30,
                value: $viewModel.shortBreakMinutes
            )
            DurationStepperRow(
                label: "Istirahat Panjang",
                range: 5...60,
                step: 5,
                value: $viewModel.longBreakMinutes
            )
            DurationStepperRow(
                label: "Sesi sebelum istirahat panjang",
                unit: "sesi",
                range: 2...8,
                value: $viewModel.cyclesPerRound
            )

            if viewModel.isTimerActive && viewModel.hasPendingDurationChanges {
                Button("Terapkan Sekarang & Mulai Ulang Timer") {
                    showApplyNowAlert = true
                }
                .foregroundStyle(Palette.accent)
            }
        } header: {
            Text("Durasi")
        } footer: {
            if viewModel.isTimerActive && viewModel.hasPendingDurationChanges {
                Text("Durasi baru telah disiapkan untuk fase berikutnya agar sesi yang sedang berjalan tetap aman. Pilih \"Terapkan Sekarang\" jika ingin langsung mengulang timer saat ini.")
            } else if viewModel.isTimerActive {
                Text("Timer sedang berjalan. Perubahan durasi akan otomatis diterapkan pada fase berikutnya.")
            } else {
                Text("Perubahan durasi langsung diterapkan pada timer.")
            }
        }
    }

    private var presetSelectorRow: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(DurationPreset.allCases) { preset in
                let isSelected = viewModel.isPresetSelected(preset)
                Button {
                    withAnimation(Motion.quick) {
                        viewModel.applyPreset(preset)
                    }
                } label: {
                    Text(preset.titleKey)
                        .font(Typography.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            isSelected ? Palette.accent : Palette.secondaryBackground,
                            in: RoundedRectangle(cornerRadius: Radius.sm)
                        )
                        .foregroundStyle(isSelected ? Color.white : Palette.label)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, Spacing.xxs)
    }

    private var behaviorSection: some View {
        Section {
            Toggle("Mulai istirahat otomatis", isOn: $viewModel.autoStartBreaks)
            Toggle("Mulai fokus otomatis", isOn: $viewModel.autoStartFocus)
            Toggle("Jaga layar tetap menyala", isOn: $viewModel.keepScreenOn)
        } header: {
            Text("Perilaku")
        } footer: {
            Text("Mencegah layar iPhone terkunci otomatis selama timer aktif dibuka di layar utama.")
        }
    }

    private var feedbackSection: some View {
        Section("Umpan Balik") {
            Picker("Suara Akhir Fase", selection: $viewModel.soundOption) {
                ForEach(PhaseEndSound.allCases) { option in
                    Text(option.displayNameKey).tag(option)
                }
            }
            Toggle("Haptic", isOn: $viewModel.hapticEnabled)
        }
    }

    private var languageSection: some View {
        Section("Bahasa") {
            Picker("Bahasa", selection: $viewModel.selectedLanguage) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.displayNameKey).tag(lang)
                }
            }
        }
    }

    private var dataSection: some View {
        Section("Data & Pengaturan") {
            Button("Kembalikan ke Pengaturan Awal") {
                showResetAlert = true
            }
            .foregroundStyle(Palette.accent)

            Button("Hapus Semua Riwayat", role: .destructive) {
                showClearHistoryAlert = true
            }
        }
    }

    private var aboutSection: some View {
        Section("Tentang") {
            HStack {
                Text("Versi")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(Palette.secondaryLabel)
            }

            NavigationLink("Kebijakan Privasi") {
                PrivacyPolicyView()
            }
        }
    }
}

// MARK: - PrivacyPolicyView

private struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Privasi Anda Sepenuhnya Milik Anda")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.label)

                Text("Fokus dirancang bekerja 100% secara lokal di perangkat iPhone Anda:")
                    .font(Typography.body)
                    .foregroundStyle(Palette.secondaryLabel)

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    privacyBullet(
                        icon: "iphone",
                        title: "Penyimpanan Lokal",
                        detail: "Semua riwayat sesi fokus dan pengaturan disimpan di perangkat Anda menggunakan SwiftData dan App Group lokal."
                    )
                    privacyBullet(
                        icon: "wifi.slash",
                        title: "Tanpa Server & Tanpa Akun",
                        detail: "Tidak ada data yang dikirim ke server eksternal, tidak ada pendaftaran akun, dan tidak ada pelacakan analitik pihak ketiga."
                    )
                    privacyBullet(
                        icon: "trash",
                        title: "Kendali Penuh",
                        detail: "Anda dapat menghapus satu atau seluruh riwayat sesi kapan saja melalui layar Statistik atau Pengaturan."
                    )
                }
            }
            .padding(Spacing.lg)
        }
        .navigationTitle("Kebijakan Privasi")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func privacyBullet(icon: String, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(Typography.headline)
                    .foregroundStyle(Palette.label)
                Text(detail)
                    .font(Typography.body)
                    .foregroundStyle(Palette.secondaryLabel)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.secondaryBackground, in: RoundedRectangle(cornerRadius: Radius.card))
    }
}

// MARK: - Preview

#Preview("Pengaturan") {
    SettingsScreen(
        viewModel: SettingsViewModel(),
        appVersion: "1.0.0 (1)"
    )
}
