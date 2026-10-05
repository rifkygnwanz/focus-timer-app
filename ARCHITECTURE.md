# ARCHITECTURE.md — Fokus

Dokumen ini menjelaskan keputusan arsitektur dan desain teknis proyek **Fokus**, sebuah app timer Pomodoro native iOS.

> Untuk aturan kontribusi harian dan panduan AI agent, lihat [`AGENTS.md`](AGENTS.md).  
> Untuk spesifikasi produk lengkap, lihat [`docs/fokus-documentation.md`](docs/fokus-documentation.md).

---

## 1. Visi Arsitektur

Fokus dibangun dengan satu prinsip utama: **logika adalah fungsi murni, efek samping ada di tepi.**

Ini berarti:
- `TimerEngine` tidak tahu tentang notifikasi, Live Activity, atau penyimpanan.
- UI tidak pernah mengubah state secara langsung.
- Semua dependensi disuntikkan lewat konstruktor — tidak ada singleton.
- Batas antar lapisan ditegakkan oleh compiler (bukan kesepakatan lisan) melalui Swift Package lokal.

---

## 2. Lapisan Arsitektur

```
┌─────────────────────────────────────────┐
│                  View                    │  SwiftUI, FokusUI components
│            (menampilkan state)           │
├─────────────────────────────────────────┤
│               ViewModel                  │  @Observable, @MainActor
│         (mengelola state layar)          │
├─────────────────────────────────────────┤
│    TimerEngine      TimerCoordinator     │  FokusCore (murni) + App (efek)
│  (fungsi murni)   (menjalankan efek)     │
├─────────────────────────────────────────┤
│           Protocol Services              │  FokusCore (interface)
│  Clock · Notifications · Activity · DB  │
├─────────────────────────────────────────┤
│            Infrastructure                │  App target (adapter konkret)
│  SystemClock · ActivityKitPresenter      │
│  UserNotificationScheduler · SwiftData  │
└─────────────────────────────────────────┘
```

**Aturan dependensi:** Panah selalu menunjuk ke **dalam** (ke domain). Domain tidak tahu apa pun tentang UI atau framework sistem.

---

## 3. Aliran Data

```
Pengguna menekan tombol
        │
        ▼
   TimerAction (.start, .pause, .resume, .stop, .skip, .phaseElapsed)
        │
        ▼
   TimerEngine.reduce(currentState, action, now: clock.now)
        │
        ▼
   Transition { state: TimerState, effects: [TimerEffect] }
        │
        ├── state → disimpan sebagai state baru → ViewModel → View diperbarui
        │
        └── effects → TimerCoordinator mengeksekusi:
                        ├── .scheduleNotification → NotificationScheduling
                        ├── .startActivity / .updateActivity / .endActivity → ActivityPresenting
                        ├── .persist → TimerStateStoring (App Group)
                        ├── .record → SessionRecording (SwiftData)
                        └── .haptic → HapticFeedback
```

---

## 4. Komponen Utama

### 4.1 TimerEngine — Functional Core

`TimerEngine` adalah jantung app. Ini adalah **struct dengan satu fungsi murni**:

```swift
// FokusCore/Engine/TimerEngine.swift
struct TimerEngine {
    let configuration: TimerConfiguration

    func reduce(_ state: TimerState, _ action: TimerAction, now: Date) -> Transition
}
```

**Sifat kunci:**
- Tidak memanggil `Date()` — menerima `now` sebagai parameter.
- Tidak punya efek samping. Tidak memanggil network, storage, atau UI.
- Mudah diuji: `engine.reduce(state, .start(label: nil), now: fixedDate)`.
- Mengembalikan `Transition` yang berisi state baru dan daftar efek.

**Actions:**

```swift
enum TimerAction: Equatable {
    case start(label: String?)
    case pause
    case resume
    case stop
    case skip
    case phaseElapsed  // dipanggil saat endDate tercapai
}
```

**Effects:**

```swift
enum TimerEffect: Equatable {
    case scheduleNotification(at: Date, phase: TimerPhase)
    case cancelNotifications
    case startActivity(TimerState)
    case updateActivity(TimerState)
    case endActivity
    case persist(TimerState)
    case record(SessionRecord)
    case haptic(HapticEvent)
}
```

### 4.2 TimerState — Single Source of Truth

```swift
// FokusCore/Models/TimerState.swift
struct TimerState: Codable, Equatable {
    enum Status: Codable, Equatable {
        case idle
        case running(endDate: Date)
        case paused(remaining: TimeInterval)
    }

    var phase: TimerPhase   // .focus, .shortBreak, .longBreak
    var status: Status
    var cycleIndex: Int     // 1...cyclesPerRound
    var startedAt: Date?
    var label: String?
}
```

Dengan `enum` bersosiasi nilai, kombinasi mustahil (misalnya `running` tanpa `endDate`) tidak bisa dibuat — **make illegal states unrepresentable** (S7).

### 4.3 TimerCoordinator — Imperative Shell

`TimerCoordinator` adalah satu-satunya tempat yang "kotor". Tugasnya:
1. Menerima `Transition` dari engine.
2. Mengeksekusi setiap `TimerEffect` lewat protocol service.
3. Menyimpan state baru.

```swift
// App/Features/Timer/TimerCoordinator.swift
@MainActor
final class TimerCoordinator {
    init(
        engine: TimerEngine,
        clock: Clock,
        notifications: NotificationScheduling,
        activity: ActivityPresenting,
        sessions: SessionRecording,
        store: TimerStateStoring
    ) { ... }

    func handle(_ action: TimerAction) async { ... }
}
```

### 4.4 Protocol Services — Batas Domain

Setiap kemampuan sistem dimodelkan sebagai protocol kecil di `FokusCore`:

```swift
protocol Clock: Sendable {
    var now: Date { get }
}

protocol NotificationScheduling: Sendable {
    func scheduleEndOfPhase(at date: Date, phase: TimerPhase) async throws
    func cancelPending() async
}

protocol ActivityPresenting: Sendable {
    func start(with state: TimerState, attributes: FokusActivityAttributes) async
    func update(with state: TimerState) async
    func end() async
}

protocol SessionRecording: Sendable {
    func save(_ record: SessionRecord) async throws
}

protocol TimerStateStoring: Sendable {
    func save(_ state: TimerState) throws
    func load() throws -> TimerState?
}
```

Implementasi konkret berada di `Infrastructure/`. Saat testing, diganti dengan fake (FakeClock, dll.).

### 4.5 AppContainer — Composition Root

Satu-satunya tempat yang mengenal semua implementasi konkret. Tidak ada singleton buatan sendiri (`shared`). Semua dependensi dirakit di sini dan disebarkan lewat `init` (S4, D12):

```swift
// App/AppContainer.swift
@MainActor
public final class AppContainer {
    let timerCoordinator: TimerCoordinator
    let timerViewModel: TimerViewModel
    let settingsViewModel: SettingsViewModel
    let statsViewModel: StatsViewModel
    let notificationScheduler: UserNotificationScheduler
    let modelContainer: ModelContainer

    public static func live() throws -> AppContainer {
        let clock = SystemClock()
        let store = AppGroupStateStore()
        let notificationScheduler = UserNotificationScheduler()
        let haptic = UIKitHapticProvider()
        let activity = ActivityKitPresenter()

        let schema = Schema([FocusSessionModel.self])
        let modelConfig = ModelConfiguration(schema: schema, url: appGroupModelURL(), cloudKitDatabase: .none)
        let modelContainer = try ModelContainer(for: schema, configurations: [modelConfig])
        let sessionRepo = SwiftDataSessionRepository(modelContext: modelContainer.mainContext)

        let settings = SettingsViewModel()
        let engine = TimerEngine(configuration: settings.configuration)
        let coordinator = TimerCoordinator(
            engine: engine,
            clock: clock,
            notifications: notificationScheduler,
            activity: activity,
            sessions: sessionRepo,
            store: store,
            haptic: haptic
        )

        let timerViewModel = TimerViewModel(coordinator: coordinator, configuration: settings.configuration)
        let statsViewModel = StatsViewModel(sessions: sessionRepo, locale: settings.selectedLanguage.locale)

        // Wiring callbacks & integrasi antar fitur
        settings.onConfigurationChanged = { [weak coordinator, weak timerViewModel] newConfig in
            coordinator?.updateConfiguration(newConfig)
            timerViewModel?.updateConfiguration(newConfig)
        }
        settings.onApplyConfigurationAndReset = { [weak coordinator, weak timerViewModel] newConfig in
            await coordinator?.applyConfigurationAndReset(newConfig)
            timerViewModel?.updateConfiguration(newConfig)
        }
        settings.onLanguageChanged = { [weak statsViewModel, weak notificationScheduler] lang in
            statsViewModel?.updateLocale(lang.locale)
            notificationScheduler?.configureCategoriesAndDelegate()
        }
        notificationScheduler.onActionReceived = { [weak coordinator] action in
            await coordinator?.handle(action)
        }
        coordinator.onSessionRecorded = { [weak statsViewModel] in
            Task { @MainActor in await statsViewModel?.load() }
        }

        return AppContainer(...)
    }
}
```

---

## 5. Modularisasi

### 5.1 Dua Swift Package Lokal

Batas antar lapisan ditegakkan oleh **compiler**, bukan kesepakatan:

| Modul | Isi | Boleh import | Dilarang import |
|---|---|---|---|
| `FokusCore` | Model domain, `TimerEngine`, protocol service | `Foundation` | `SwiftUI`, `UIKit`, `ActivityKit`, `UserNotifications`, `SwiftData`, `WidgetKit` |
| `FokusUI` | Token desain, komponen reusable, `ButtonStyle` | `SwiftUI`, `FokusCore` | `SwiftData`, `ActivityKit` |
| App + Extension | Adapter, ViewModel, layar, composition root | Semua | — |

### 5.2 Keuntungan Modularisasi

- `FokusCore` dapat diuji dengan `swift test` **tanpa simulator**.
- `FokusWidgetExtension` memakai ulang `FokusUI` dan `FokusCore` tanpa duplikasi kode.
- Pelanggaran batas dependensi langsung gagal saat build — tidak perlu disiplin manual.

---

## 6. Persistensi dan State Bersama

### 6.1 SwiftData — Riwayat Sesi

```swift
// Infrastructure/SwiftDataSessionRepository.swift
// @Model hanya di lapisan Infrastructure
@Model 
final class FocusSessionModel {
    var id: UUID
    var label: String?
    var phaseRaw: String          // TimerPhase.rawValue
    var startedAt: Date           // diindeks untuk kueri per hari
    var endedAt: Date
    var plannedSeconds: Int
    var actualSeconds: Int
    var outcomeRaw: String        // SessionOutcome.rawValue
    var cycleIndex: Int
}
```

`FokusCore` tidak mengenal `FocusSessionModel` — ia hanya mengenal `SessionRecord` (struct murni, `Sendable`). Adapter `SwiftDataSessionRepository` memetakan keduanya secara dua arah.

`ModelContainer` ditempatkan di **App Group** (`fokus.sqlite`) agar widget extension (v1.1) dapat membaca data riwayat tanpa duplikasi penyimpanan.

### 6.2 App Group — State Timer Aktif

`TimerState` disimpan di App Group (`UserDefaults(suiteName: "group.com.rifkygnwanz.fokus")`) agar:
- Live Activity extension dapat membaca state saat tombol interaktif ditekan.
- App dapat memulihkan timer setelah dihentikan sistem atau crash (FR-10).

```swift
// App Group ID: "group.com.rifkygnwanz.fokus"
// Key: "fokus.timerState" → Data (JSON-encoded TimerState)
```

### 6.3 Pengaturan

UserDefaults App Group bertipe dengan enum `SettingsKey` (tanpa magic string):

```swift
public nonisolated enum SettingsKey: String {
    case focusMinutes      = "fokus.focusMinutes"       // default: 25
    case shortBreakMinutes = "fokus.shortBreakMinutes"  // default: 5
    case longBreakMinutes  = "fokus.longBreakMinutes"   // default: 15
    case cyclesPerRound    = "fokus.cyclesPerRound"     // default: 4
    case autoStartBreaks   = "fokus.autoStartBreaks"    // default: true
    case autoStartFocus    = "fokus.autoStartFocus"     // default: false
    case hapticEnabled     = "fokus.hapticEnabled"      // default: true
    case keepScreenOn      = "fokus.keepScreenOn"       // default: true
    case soundOption       = "fokus.soundOption"        // default: "default"
    case appLanguage       = "fokus.appLanguage"        // default: "system"
}
```

---

## 7. Live Activity dan Dynamic Island

### 7.1 Model Data

```swift
// Shared/FokusActivityAttributes.swift
struct FokusActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Timing: Codable, Hashable {
            case running(start: Date, end: Date)
            case paused(remaining: TimeInterval)
        }
        var phase: TimerPhase
        var timing: Timing    // state ilegal tidak bisa dibuat
        var cycleIndex: Int
    }
    var label: String?
    var cyclesPerRound: Int
}
```

### 7.2 Aturan Pembaruan

| Kondisi | Tindakan |
|---|---|
| Timer berjalan | Gunakan `Text(timerInterval: start...end, countsDown: true)` — sistem yang menghitung |
| Timer dijeda | Tampilkan sisa waktu statis dari `.paused(remaining:)` |
| Ada perubahan makna | Update Activity: mulai, jeda, lanjut, pindah fase, selesai |
| Timer mencapai 0:00 | Tampilkan "Selesai"; jangan bergantung pada penghentian otomatis |

**Jangan** memperbarui Live Activity tiap detik.

### 7.3 Tampilan per Area

| Area | Isi |
|---|---|
| Lock Screen | Ikon fase, "Fokus · 2/4", timer besar, progress bar, tombol Jeda/Lanjut & Berhenti |
| Dynamic Island — compact leading | Ikon fase (SF Symbol) |
| Dynamic Island — compact trailing | Timer dengan lebar terbatas |
| Dynamic Island — minimal | Ikon fase atau cincin progres kecil |
| Dynamic Island — expanded | Fase + siklus · Timer besar · Label sesi · Tombol kontrol |

### 7.4 Interaksi Tombol

Tombol di Live Activity memakai `Button(intent:)` dengan `LiveActivityIntent`.
Intent dieksekusi oleh sistem (bahkan saat app tidak berjalan), sehingga state dibaca dari App Group.

### 7.5 Home Screen Interactive Widget (`FokusTimerWidget`)

Mendukung widget interaktif di Home Screen (`.systemSmall` dan `.systemMedium`) menggunakan App Intents:
- **Status Sinkron**: Membaca `TimerState` dan `TimerConfiguration` dari App Group (`group.com.rifkygnwanz.fokus`).
- **Live Countdown**: Menggunakan `Text(timerInterval: Date()...endDate, countsDown: true)` untuk countdown hemat baterai secara real-time.
- **Interaksi Tombol (AppIntents)**:
  - *Idle*: Tombol interaktif **Mulai** (`StartTimerIntent`) untuk langsung memulai sesi fokus.
  - *Running*: Tombol **Jeda** (`PauseTimerIntent`), **Lewati** (`SkipTimerIntent`), dan **Berhenti** (`StopTimerIntent`).
  - *Paused*: Tombol **Lanjut** (`ResumeTimerIntent`), **Lewati** (`SkipTimerIntent`), dan **Berhenti** (`StopTimerIntent`).
- **Sinkronisasi Dua Arah**:
  - `TimerExternalSync.performExternalAction(...)` memanggil `WidgetCenter.shared.reloadAllTimelines()` saat ada aksi dari widget atau intent.
  - `TimerCoordinator` di aplikasi utama memanggil `WidgetCenter.shared.reloadAllTimelines()` saat state berubah di dalam aplikasi, memastikan widget dan layar utama selalu sinkron seketika.

---

## 8. Design System (FokusUI)

### 8.1 Token Desain

Tidak ada angka atau warna literal di dalam `View`. Semua dari:

```swift
// FokusUI/Tokens/
Spacing.sm / .md / .lg / .xl
Radius.card / .button / .chip
Typography.headline / .body / .caption / .timerLarge
Palette.accent / .onAccent / .background / .secondaryBackground / .phaseAccent(for:)
Motion.standard / .quick / .slow / .spring
```

### 8.2 Komponen dan Aturan Teks

Komponen `FokusUI` bersifat reusable, murni tampilan (*presentation*), dan mendukung lokalisasi dinamis:

```swift
// FokusUI/Tokens/Theme.swift
public struct PhaseStyle: Sendable {
    public let phase: TimerPhase
    public let symbolName: String
    public let name: String          // String terlokalisasi
    public let color: Color
    public var titleKey: LocalizedStringKey {
        switch phase {
        case .focus: "Fokus"
        case .shortBreak: "Istirahat Pendek"
        case .longBreak: "Istirahat Panjang"
        }
    }
}
```

> **Aturan Lokalisasi Komponen:**
> 1. Parameter label/judul pada komponen reusable (`StatCard`, `EmptyStateView`, `DurationStepperRow`) bertipe `LocalizedStringKey`, bukan `String`. Ini memastikan teks otomatis diterjemahkan saat environment `\.locale` berubah.
> 2. Teks input dinamis pengguna (seperti nama kegiatan sesi) wajib dibungkus dengan `Text(verbatim: label)` agar iOS tidak mencarinya di kamus bahasa.

### 8.3 Container/Presentation Split

```swift
// "Pintar" — punya dependensi, tidak bisa dipratinjau tanpa setup
struct TimerScreen: View {
    @State private var viewModel: TimerViewModel
    var body: some View {
        TimerContent(state: viewModel.presentation, actions: viewModel.actions)
    }
}

// "Bodoh" — stateless, bisa dipratinjau dengan data statis
struct TimerContent: View {
    let state: TimerPresentation
    let actions: TimerActions
}
```

---

## 9. State Machine Timer

```
                    ┌─────────┐
              ┌────▶│  Idle   │◀────────────────────────────────┐
              │     └────┬────┘                                  │
              │          │ .start                                │
              │          ▼                                       │
              │    ┌─────────────┐  .pause  ┌──────────────┐   │
              │    │FocusRunning │─────────▶│ FocusPaused  │   │
              │    └──────┬──────┘◀─────────└──────────────┘   │
              │           │ .resume                              │ .stop
              │           │ .phaseElapsed (sesi 1..N-1)         │
              │           ▼                                      │
              │    ┌─────────────┐                              │
              │    │ ShortBreak  │──────────────────────────────┤
              │    └─────────────┘                              │
              │           │ .phaseElapsed (sesi ke-N)           │
              │           ▼                                      │
              │    ┌─────────────┐                              │
              └────│  LongBreak  │──────────────────────────────┘
                   └─────────────┘
```

**Aturan bisnis utama:**

| ID | Aturan |
|---|---|
| BR-01 | Sumber kebenaran waktu adalah `endDate`. Sisa waktu = `endDate − sekarang` |
| BR-02 | Jeda: simpan `pausedRemaining`. Lanjut: `endDate = sekarang + pausedRemaining` |
| BR-03 | Sesi fokus selesai hanya jika mencapai nol. Jika dihentikan lebih awal → dibatalkan |
| BR-04 | Sesi dibatalkan < 60 detik tidak disimpan |
| BR-05 | Default: Fokus 25 mnt, Pendek 5 mnt, Panjang 15 mnt, panjang setiap 4 sesi |
| BR-06 | Istirahat mulai otomatis (default: nyala). Fokus berikutnya tidak mulai otomatis |
| BR-07 | Hanya satu timer aktif dan satu Live Activity pada satu waktu |
| BR-08 | Streak = hari berturut-turut dengan ≥1 sesi fokus selesai (zona waktu perangkat) |
| BR-09 | Perubahan durasi saat timer berjalan disiapkan untuk fase berikutnya (`pendingConfiguration`) agar timer aktif tidak terganggu |
| BR-09b | Pengguna dapat memilih opsi "Terapkan Sekarang (Reset Timer Aktif)" untuk langsung mereset timer berjalan dengan durasi baru |
| BR-10 | Notifikasi dibatalkan saat Jeda/Berhenti, dijadwalkan ulang saat Lanjut |
| BR-11 | Penghapusan semua riwayat sesi dipusatkan di layar Pengaturan dengan konfirmasi destruktif. Layar Statistik hanya mendukung swipe-to-delete per sesi |
| BR-12 | Pilihan suara akhir fase mendukung: Standar (1007), Nada Tiga (1002), Dering Lembut (1013), Lonceng (1005), dan Tanpa Suara |

---

## 10. Pengujian

### 10.1 Strategi

| Jenis | Target | Cakupan |
|---|---|---|
| Unit test (`FokusCore`) | `TimerEngine`, streak, repository in-memory | ≥ 90% |
| Unit test (ViewModel) | Dengan fake service | ≥ 80% |
| Keseluruhan | — | ≥ 70% |
| UI test | Mulai → Jeda → Lanjut → Berhenti; perpindahan fase | — |
| Aturan arsitektur (CI) | Tidak ada import terlarang di `FokusCore`; tidak ada `Date()` di logika | — |

### 10.2 Fake Objects

```swift
// FokusTests/Fakes/
final class FakeClock: Clock { var now: Date = .now }
final class FakeNotificationScheduler: NotificationScheduling { ... }
final class FakeActivityPresenter: ActivityPresenting { ... }
final class FakeSessionRecorder: SessionRecording { ... }
```

### 10.3 Contoh Unit Test Engine

```swift
func testFocusTransitionsToPausedOnPauseAction() {
    let engine = TimerEngine(configuration: .default)
    let now = Date(timeIntervalSince1970: 0)
    let runningState = TimerState(
        phase: .focus,
        status: .running(endDate: now.addingTimeInterval(1500)),
        cycleIndex: 1
    )

    let transition = engine.reduce(runningState, .pause, now: now)

    XCTAssertEqual(transition.state.status, .paused(remaining: 1500))
    XCTAssert(transition.effects.contains(.cancelNotifications))
}
```

---

## 11. Roadmap Implementasi

| Fase | Fokus | Estimasi |
|---|---|---|
| F0 | Setup: repo, Swift Package, App Group, SwiftLint/SwiftFormat, CI, ADR pertama | 1 minggu |
| F1 | Engine + design system + UI dasar (timer berjalan, ProgressRing, PhaseChip) | 2 minggu |
| F2 | Persistensi + Statistik (riwayat, grafik 7 hari, streak) | 1 minggu |
| F3 | Notifikasi + pemulihan state (FR-10) | 1 minggu |
| F4 | Live Activity + Dynamic Island | 1,5 minggu |
| F5 | Kontrol interaktif dari Live Activity (App Intents) | 1 minggu |
| F6 | Polish: haptic, animasi, aksesibilitas, lokalisasi, ikon | 1,5 minggu |
| F7 | Beta (TestFlight) dan rilis | 1 minggu |

Setiap fase harus memenuhi **Definition of Done** di [`AGENTS.md § 9`](AGENTS.md) sebelum lanjut.

---

## 12. Log Keputusan Arsitektur (ADR)

Keputusan besar dicatat di `docs/adr/`. Ringkasan:

| ID | Keputusan | Alasan |
|---|---|---|
| D3 | SwiftData untuk riwayat | Tersedia iOS 17+; tidak perlu fallback Core Data |
| D4 | `@Observable` untuk ViewModel | Tersedia iOS 17+; lebih ergonomis dari ObservableObject |
| D5 | State timer berbasis `endDate` | Andal saat app dihentikan sistem (FR-10) |
| D6 | Tanpa akun/server/analitik | Privasi dan kesederhanaan |
| D8 | Tidak bergantung pada penghentian Live Activity otomatis | Perilaku tidak konsisten di berbagai perangkat |
| D10 | `TimerEngine` fungsi murni | Mudah diuji, tanpa efek samping |
| D11 | Dua Swift Package lokal | Batas ditegakkan compiler; reuse ke widget extension |
| D12 | DI lewat constructor + composition root | Testabilitas penuh |
| D13 | Swift 6 strict concurrency | Keamanan concurrency sejak hari pertama |
| D14 | Nol dependensi runtime pihak ketiga | Kecil, aman, mudah dirawat |
| D15 | SwiftLint + SwiftFormat + CI | Konsistensi tanpa bergantung pada disiplin manual |
| D16 | String Catalog & In-App Switcher | Lokalisasi modern iOS 18 dengan `.environment(\.locale)` real-time |
| D17 | Main Thread Synchronous completionHandler | Mencegah crash `NSInternalInconsistencyException` pada notifikasi interaktif |
| D18 | Pemisahan Hapus Riwayat Sesi | Hapus baris tunggal via swipe di Statistik; hapus seluruh data via konfirmasi di Pengaturan |
| D19 | Safe Duration Update (Pending queue) | Mencegah anomali waktu saat timer aktif; opsi reset instan disediakan eksplisit |
| D20 | Non-generated String Catalog Symbols | Menghindari benturan identifier Swift pada kunci natural language dan specifier dinamis |

---

## 13. Sistem Lokalisasi (Bilingual ID/EN & String Catalog)

Fokus mengadopsi sistem lokalisasi modern iOS berbasis **String Catalog (`.xcstrings`)** dengan arsitektur dua bahasa (Bahasa Indonesia & English).

### 13.1 Struktur & Konvensi Kunci

File tunggal berada di [`Fokus/Localizable.xcstrings`](Fokus/Localizable.xcstrings).
- Semua kunci menggunakan kalimat natural bahasa Indonesia sebagai basis kunci utama (misal `"Statistik"`, `"Fokus Hari Ini"`, `"Selesai"`).
- Kunci dinamis memakai format specifier standar iOS:
  - `"%lld mnt"` (menit) & `"%lld dtk"` (detik)
  - `"%lld mnt fokus"`
  - `"%@ sedang berjalan"` & `"%@ dijeda (%@)"`

### 13.2 Mekanisme `LocalizedStringKey` vs `Text(verbatim:)`

1. **Komponen Teks Statis & Label UI**:
   Semua teks literal yang ditulis langsung di view SwiftUI (`Text("...")`, `Button("...")`, `Label("...")`) otomatis bertipe `LocalizedStringKey` dan diterjemahkan sesuai bahasa aktif.
2. **Komponen Reusable (FokusUI)**:
   Properti judul atau label pada komponen desain (`StatCard`, `EmptyStateView`, `DurationStepperRow`) **wajib** menerima `LocalizedStringKey` (bukan `String`) agar bereaksi langsung saat locale berganti.
3. **Teks Dinamis Pengguna**:
   Teks yang bersumber dari input pengguna (misal catatan/label sesi fokus `state.label`) **wajib** menggunakan `Text(verbatim: label)`. Ini mencegah pencarian string yang tidak perlu pada kamus bahasa.

### 13.3 In-App Language Switcher & Real-time Update

Pengguna dapat memilih bahasa aplikasi secara independen dari pengaturan sistem:
- **Pilihan**: `AppLanguage.system` ("Ikuti Sistem"), `.indonesian` ("Bahasa Indonesia"), dan `.english` ("English").
- **Penyimpanan**: Disimpan di App Group `UserDefaults` (`fokus.appLanguage`).
- **Injeksi Root**:
  ```swift
  // FokusApp.swift
  RootView(container: container)
      .environment(\.locale, container.settingsViewModel.selectedLanguage.locale)
  ```
  Modifier `.environment(\.locale, ...)` juga disuntikkan pada sheet modal `SettingsScreen` sehingga teks di dalam sheet dan layar di baliknya seketika me-render ulang (*real-time*) tanpa perlu restart aplikasi.
- **Propagasi ke Service & Formatter**:
  Perubahan bahasa meneruskan locale baru ke:
  - `StatsViewModel.updateLocale(_:)`: Memformat ulang sumbu grafik (nama hari) dan grup tanggal riwayat.
  - `UserNotificationScheduler.configureCategoriesAndDelegate()`: Memperbarui judul tombol aksi pada notifikasi.

### 13.4 Konfigurasi Xcode Build

Untuk mendukung kompilasi String Catalog yang bersih:
- `knownRegions = (en, Base, id);` pada `Fokus.xcodeproj/project.pbxproj` memastikan bundle aplikasi menyertakan direktori `id.lproj`.
- `STRING_CATALOG_GENERATE_SYMBOLS = NO;` diatur pada konfigurasi Debug dan Release agar Xcode tidak mencoba membuat Swift identifier otomatis yang rawan benturan pada string dengan tanda baca atau specifier.

---

## 14. Sistem Notifikasi Interaktif & Thread Safety

### 14.1 Penanganan Main Thread (Mencegah Crash Runtime)

UIKit memanggil delegate `userNotificationCenter(_:didReceive:withCompletionHandler:)` di main thread dan mewajibkan `completionHandler()` dipanggil di main thread. Memanggilnya di dalam closure async Swift dapat memicu crash `NSInternalInconsistencyException ('Call must be made on main thread')`.

**Pola Arsitektur yang Diterapkan:**
```swift
// Infrastructure/NotificationScheduler.swift
public nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
) {
    let actionIdentifier = response.actionIdentifier
    let categoryIdentifier = response.notification.request.content.categoryIdentifier
    let mappedAction: TimerAction? = ...

    // WAJIB: Panggil completionHandler secara sinkron di main thread
    completionHandler()

    guard let action = mappedAction else { return }

    Task { @MainActor in
        if let handler = self.onActionReceived {
            await handler(action)
        } else {
            await TimerExternalSync.performExternalAction(action)
        }
    }
}
```

### 14.2 Kategori Notifikasi Interaktif

| Kategori | Tombol Aksi | Action Timer |
|---|---|---|
| `runningCategory` | Jeda, Lewati, Berhenti (destruktif) | `.pause`, `.skip`, `.stop` |
| `pausedCategory` | Lanjut, Lewati, Berhenti (destruktif) | `.resume`, `.skip`, `.stop` |
| `phaseEndCategory` | Mulai (foreground), Lewati | `.start(label: nil)`, `.skip` |

### 14.3 Notifikasi Status Berjalan vs Akhir Fase

- **`fokus.activeTimer`**: Notifikasi persisten yang otomatis muncul saat aplikasi berjalan di background pada perangkat tanpa Live Activity aktif, memungkinkan kontrol timer langsung dari Notification Center / Lock Screen.
- **`fokus.phaseEnd`**: Notifikasi *time-sensitive* dengan suara yang memicu saat fase selesai.

---

## 15. Fitur Statistik & Keamanan Data (SwiftData)

### 15.1 Tampilan Berstandar iOS Native (Screen Time & Health Style)

1. **Kartu Ringkasan (2x2 Grid)**:
   - Fokus Hari Ini (`mnt`), Sesi Selesai (`sesi`), Streak Beruntun (`hari`), Total 7 Hari Terakhir (`mnt`).
2. **Grafik 7 Hari (Swift Charts)**:
   - Sumbu X menampilkan nama hari yang diselaraskan dengan locale aktif.
   - Sumbu Y dengan skala dinamis dan grid line putus-putus halus.
   - Menampilkan rata-rata harian dan total 7 hari.
3. **Riwayat Sesi per Hari**:
   - Dikelompokkan berdasarkan hari (`DayGroup`).
   - Setiap baris menampilkan ikon fase (rounded square), label kustom (jika ada), rentang waktu jam, durasi, dan indikator status ("Selesai" / "Dihentikan").

### 15.2 Proteksi dan Kebersihan Data

- **Filter Sampah Sesi (BR-04)**: Sesi yang dihentikan sebelum 60 detik tidak dicatat ke basis data SwiftData.
- **Penghapusan Baris Sesi Tunggal**: Pengguna dapat menghapus rekaman sesi tertentu menggunakan *swipe-to-delete* di layar Statistik.
- **Penghapusan Massal (BR-11)**: Tombol "Hapus Semua Riwayat" sengaja dipindahkan dari layar Statistik ke menu Pengaturan, dilengkapi dialog konfirmasi destruktif untuk mencegah penghapusan data tidak sengaja.
