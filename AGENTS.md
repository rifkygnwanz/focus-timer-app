# AGENTS.md — Fokus

Panduan ini wajib dibaca oleh AI agent (atau developer baru) sebelum menyentuh kode di repo ini.
Fokus adalah app timer Pomodoro native iOS — sederhana, tanpa server, dan dibangun dengan standar engineering kelas profesional.

---

## 1. Orientasi Cepat

| Item | Nilai |
|---|---|
| Nama produk | Fokus (nama kerja) |
| Platform | iPhone (iOS 18.0+) |
| UI | SwiftUI |
| Persistensi | SwiftData (lokal, di perangkat) |
| Arsitektur | MVVM + Functional core + Service layer, dimodularisasi dengan Swift Package |
| Dependensi runtime | **Nol** pihak ketiga |
| Akun / server / iklan | Tidak ada |
| Bahasa app | Indonesia dan Inggris |

Dokumentasi produk lengkap: [`docs/fokus-documentation.md`](docs/fokus-documentation.md)

---

## 2. Struktur Proyek

```
Fokus/
├── Packages/
│   ├── FokusCore/          # Swift Package: domain murni (tanpa UI/framework sistem)
│   │   ├── Sources/FokusCore/
│   │   │   ├── Models/     # TimerState, TimerPhase, SessionRecord, TimerConfiguration
│   │   │   ├── Engine/     # TimerEngine, TimerAction, TimerEffect
│   │   │   └── Protocols/  # Clock, NotificationScheduling, ActivityPresenting, ...
│   │   └── Tests/FokusCoreTests/
│   └── FokusUI/            # Swift Package: design system
│       └── Sources/FokusUI/
│           ├── Tokens/     # Spacing, Radius, Typography, Palette, Motion
│           ├── Components/ # ProgressRing, PhaseChip, StatCard, EmptyStateView, ...
│           └── Styles/     # PrimaryButtonStyle, SecondaryButtonStyle
├── App/                    # FokusApp.swift, AppContainer (composition root)
├── Infrastructure/         # Adapter: SwiftDataSessionRepository, ActivityKitPresenter,
│                           #   UserNotificationScheduler, AppGroupStateStore, SystemClock
├── Features/
│   ├── Timer/              # TimerScreen, TimerContent, TimerViewModel, TimerCoordinator
│   ├── Stats/              # StatsScreen, StatsContent, StatsViewModel
│   └── Settings/           # SettingsScreen, SettingsViewModel
├── Resources/              # Localizable.xcstrings, Assets, suara
├── Shared/                 # FokusActivityAttributes, App Intents (dipakai app + extension)
├── FokusTests/
├── FokusUITests/
└── FokusWidgetExtension/   # Live Activity + Dynamic Island
docs/
├── fokus-documentation.md  # Dokumen produk lengkap
└── adr/                    # Architecture Decision Records
```

**Target Xcode:**

| Target | Isi |
|---|---|
| `Fokus` | App utama |
| `FokusWidgetExtension` | Live Activity, Widget, Control (v1.1) |
| `FokusTests` | Unit test |
| `FokusUITests` | UI test |
| `FokusCore` (Swift Package) | Domain murni |
| `FokusUI` (Swift Package) | Design system |

---

## 3. Aturan Arsitektur — Wajib Dipatuhi

### 3.1 Aliran Data

```
Action → TimerEngine.reduce() → Transition(state, effects) → TimerCoordinator → Efek samping
                                                                              ↓
View ← ViewModel ← State baru
```

- **View** hanya menampilkan state dan meneruskan aksi. Tanpa logika bisnis.
- **ViewModel** mengelola state layar, memanggil service melalui ViewModel/Coordinator.
- **TimerEngine** adalah fungsi murni: `reduce(state, action, now: Date) → Transition`. Tidak ada efek samping di sini.
- **TimerCoordinator** adalah satu-satunya tempat yang "kotor" — menjalankan efek lewat protocol.
- **Infrastructure** adalah adapter: implementasi konkret dari protocol domain.

### 3.2 Batas Dependensi (Ditegakkan Compiler)

| Modul | Boleh import | Dilarang import |
|---|---|---|
| `FokusCore` | `Foundation` | `SwiftUI`, `UIKit`, `ActivityKit`, `UserNotifications`, `SwiftData`, `WidgetKit` |
| `FokusUI` | `SwiftUI`, `FokusCore` | `SwiftData`, `ActivityKit` |
| App + Extension | Semua | — |

> **PENTING:** Jangan pernah menambahkan import yang melanggar batas ini di `FokusCore` atau `FokusUI`. CI akan gagal.

### 3.3 Prinsip Desain Sistem

| Kode | Prinsip | Penerapan |
|---|---|---|
| S1 | Functional core, imperative shell | `TimerEngine` adalah fungsi murni; efek samping hanya di tepi (koordinator & adapter) |
| S2 | Dependency rule | Dependensi selalu ke dalam: View → ViewModel → Domain ← Infrastructure |
| S3 | Program ke protocol | Setiap kemampuan sistem diakses lewat protocol kecil yang bisa difake saat test |
| S4 | DI lewat constructor | Semua dependensi dikirim via `init`; dirakit di `AppContainer` |
| S5 | Single source of truth | `TimerState` hanya punya satu pemilik |
| S6 | Aliran data satu arah | View tidak pernah mengubah state langsung |
| S7 | State ilegal tidak mungkin ada | Gunakan `enum` dengan associated value, bukan `Optional` yang bertentangan |
| S8 | Efek samping idempoten | Memulai Live Activity dua kali menghasilkan hasil yang sama |

---

## 4. Panduan Menulis Kode

### 4.1 Penamaan

- Ikuti [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
- **Tipe** = kata benda (`TimerEngine`), **fungsi** = kata kerja (`scheduleEndOfPhase`), **Boolean** = pernyataan (`isPaused`, `hasCompletedCycle`).
- Tidak ada singkatan tidak baku: `cfg`, `mgr`, `vm`, `tmp` ❌

### 4.2 Batas Ukuran (Ditegakkan SwiftLint)

| Elemen | Batas |
|---|---|
| Fungsi | ≈ 20 baris, kompleksitas siklomatik ≤ 10 |
| Parameter fungsi | ≤ 3; lebih dari itu gunakan struct |
| `View.body` | ≈ 40 baris; lebih dari itu ekstrak subview |
| File | ≈ 300 baris |
| Nesting | ≤ 3 tingkat; gunakan `guard` dan early return |

### 4.3 Larangan Keras

```swift
// ❌ DILARANG
let x = someOptional!          // force unwrap
try! someFunc()                // try!
let y = value as! Type         // force cast
print("debug")                 // gunakan Logger (OSLog)
let now = Date()               // di dalam logika; gunakan Clock yang diinjeksi
"focusMinutes"                 // magic string; gunakan enum SettingsKey
```

```swift
// ✅ BENAR
guard let x = someOptional else { return }
let now = clock.now            // Clock diinjeksi
Logger(subsystem: "com.app.fokus", category: "timer").debug("...")
enum SettingsKey: String { case focusMinutes }
```

### 4.4 Concurrency (Swift 6)

- Language mode: **Swift 6, strict concurrency complete**.
- `ViewModel` dan `Coordinator` ditandai `@MainActor`.
- Tipe domain adalah `Sendable`.
- Gunakan `async/await` dan `actor`. Tidak ada `DispatchQueue` manual.

### 4.5 Komentar

- Komentar menjelaskan **mengapa**, bukan **apa**.
- API publik `FokusCore` didokumentasikan dengan `///` dan dibangun dengan DocC.
- Tidak ada kode yang di-comment-out — riwayat ada di Git.

---

## 5. Pola Wajib

### 5.1 TimerEngine — Fungsi Murni

```swift
// FokusCore
struct TimerEngine {
    let configuration: TimerConfiguration
    func reduce(_ state: TimerState, _ action: TimerAction, now: Date) -> Transition
}

struct Transition: Equatable {
    var state: TimerState
    var effects: [TimerEffect]
}
```

**Jangan** memanggil `Date()` langsung di dalam `reduce`. Selalu gunakan parameter `now`.

### 5.2 Protocol Service (Bisa Difake saat Test)

```swift
// FokusCore — protocol kecil dan spesifik
protocol NotificationScheduling: Sendable {
    func scheduleEndOfPhase(at date: Date, phase: TimerPhase) async throws
    func cancelPending() async
}
protocol ActivityPresenting: Sendable { /* start, update, end */ }
protocol SessionRecording: Sendable { func save(_ record: SessionRecord) async throws }
protocol Clock: Sendable { var now: Date { get } }
```

### 5.3 Container/Presentation Split (View)

```swift
// "Pintar" — memegang ViewModel, punya dependensi
struct TimerScreen: View {
    @State private var viewModel: TimerViewModel
    var body: some View { TimerContent(state: viewModel.presentation, actions: viewModel.actions) }
}

// "Bodoh" — hanya data + closure, bisa dipratinjau tanpa dependensi
struct TimerContent: View {
    let state: TimerPresentation
    let actions: TimerActions
}
```

### 5.4 Composition Root

```swift
// Satu-satunya tempat yang mengenal semua implementasi konkret
@main
struct FokusApp: App {
    private let container = AppContainer.live()
    var body: some Scene {
        WindowGroup { RootView(container: container) }
    }
}
```

Tidak ada singleton buatan sendiri (`shared`, `default`). Semua dependensi lewat `init`.

### 5.5 State Ilegal Tidak Mungkin Ada

```swift
// ✅ Benar — kombinasi mustahil tidak bisa dibuat
struct TimerState: Codable, Equatable {
    enum Status: Codable, Equatable {
        case idle
        case running(endDate: Date)   // selalu punya endDate
        case paused(remaining: TimeInterval) // tidak punya endDate
    }
    var phase: TimerPhase
    var status: Status
    var cycleIndex: Int
}
```

---

## 6. Design System (FokusUI)

Semua token dan komponen berada di `FokusUI`. **Tidak ada angka atau warna literal di dalam `View`.**

| Komponen | Fungsi |
|---|---|
| `ProgressRing` | Cincin progres generik (nilai 0...1) |
| `PhaseChip` | Chip fase Fokus/Istirahat |
| `PrimaryButtonStyle` | Gaya tombol utama (kapsul) |
| `SecondaryButtonStyle` | Gaya tombol sekunder |
| `StatCard` | Kartu statistik dengan judul, nilai, satuan |
| `DurationStepperRow` | Baris pengaturan durasi |
| `EmptyStateView` | Kondisi kosong dengan ikon dan deskripsi |
| `PhaseStyle` | Satu sumber untuk ikon, warna, nama tiap fase |

**Aturan komponen:**
- Stateless dan murni tampilan: menerima nilai dan closure, tidak mengenal ViewModel.
- API minimal dengan nilai default yang masuk akal.
- Aksesibilitas bawaan: label VoiceOver, Dynamic Type.
- Setiap komponen **wajib** punya `#Preview` dengan varian: Light/Dark, Dynamic Type terbesar, ID/EN.

---

## 7. Aturan Live Activity

- **Jangan** memperbarui Live Activity tiap detik.
- Gunakan `Text(timerInterval: start...end, countsDown: true)` dan `ProgressView(timerInterval:countsDown:)`.
- Perbarui hanya saat ada perubahan makna: mulai, jeda, lanjut, pindah fase, selesai.
- Tombol interaktif memakai `Button(intent:)` dengan `LiveActivityIntent` (App Intents).
- State timer disimpan di **App Group** agar app dan extension selalu konsisten.

---

## 8. Pengujian

### 8.1 Target Cakupan

| Lapisan | Target |
|---|---|
| `FokusCore` | ≥ 90% |
| ViewModel | ≥ 80% |
| Keseluruhan | ≥ 70% |

### 8.2 Yang Wajib Diuji

- Semua transisi state `TimerEngine` (BR-01 sampai BR-10).
- Perhitungan streak dengan kasus tepi DST/zona waktu.
- Pemulihan dari `endDate` yang sudah lewat (FR-10).
- `SessionRepository` dengan SwiftData in-memory.
- `TimerCoordinator` dengan fake: `FakeClock`, `FakeNotificationScheduler`, `FakeActivityPresenter`.

### 8.3 FokusCore dapat Diuji Tanpa Simulator

```bash
swift test --package-path Packages/FokusCore
```

---

## 9. Definition of Done (per PR)

Sebelum membuka PR, pastikan semua item berikut terpenuhi:

- [ ] Compile tanpa warning (Swift 6, strict concurrency)
- [ ] `SwiftFormat` dan `SwiftLint` bersih
- [ ] Unit test untuk logika baru; bug diperbaiki dengan test regresi yang gagal lebih dulu
- [ ] Komponen UI baru punya `#Preview` (Light/Dark, teks besar, ID/EN)
- [ ] Teks masuk String Catalog (`Localizable.xcstrings`) dalam dua bahasa
- [ ] Aksesibilitas dicek (label VoiceOver, Dynamic Type)
- [ ] Tidak ada duplikasi tiga kali, tidak ada magic value
- [ ] ADR ditulis jika ada keputusan arsitektur baru
- [ ] Bila menyentuh UI: diuji di SE (layar kecil), iPhone XR, dan iPhone dengan Dynamic Island

---

## 10. Toolchain

| Area | Standar |
|---|---|
| Format | SwiftFormat (pre-commit hook + CI) |
| Lint | SwiftLint mode ketat dengan aturan kustom |
| Compiler | Swift 6, warnings as errors di CI |
| CI | Build, test, lint di setiap PR (GitHub Actions, runner macOS) |
| Git | Conventional Commits, trunk-based, PR < 400 baris, template PR |
| Versi | Semantic Versioning |
| Keputusan arsitektur | ADR di `docs/adr/` |
| Dependensi runtime | **Nol** pihak ketiga |

---

## 11. Hal yang Tidak Boleh Dilakukan Agent

1. ❌ Menambahkan dependensi runtime pihak ketiga tanpa diskusi eksplisit.
2. ❌ Menambahkan `import SwiftUI` atau framework sistem di `FokusCore`.
3. ❌ Memanggil `Date()` langsung di dalam `TimerEngine.reduce` — gunakan parameter `now`.
4. ❌ Membuat singleton (`static let shared`).
5. ❌ Memakai `print()` untuk logging — gunakan `Logger` (OSLog).
6. ❌ Force unwrap (`!`), `try!`, atau `as!`.
7. ❌ Hardcode teks yang tampil ke pengguna — semua lewat String Catalog.
8. ❌ Hardcode angka atau warna literal di `View` — semua dari token `FokusUI`.
9. ❌ Memperbarui Live Activity tiap detik.
10. ❌ Mengubah pengaturan durasi yang sedang berjalan — perubahan berlaku untuk fase berikutnya (BR-09).
