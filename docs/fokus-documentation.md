Fokus — Dokumentasi Produk
Versi dokumen: 1.0 · Tanggal: 29 September 2026 · Status: Draft siap implementasi Catatan: "Fokus" adalah nama kerja sementara. Bagian bertanda [Keputusan] adalah keputusan produk/teknis yang sudah diambil dan tercatat di Bagian 18.

1. Ringkasan Produk
   Item Nilai
   Nama kerja Fokus
   Tagline Satu ketukan untuk mulai fokus.
   Jenis Timer fokus dan istirahat (teknik Pomodoro)
   Platform iPhone
   Perangkat minimum iPhone XR dan yang lebih baru
   OS minimum (deployment target) iOS 18.0
   Bahasa app Indonesia dan Inggris
   UI SwiftUI
   Penyimpanan SwiftData (lokal, di perangkat)
   Arsitektur MVVM + functional core (TimerEngine murni) + lapisan Service, dimodularisasi dengan Swift Package (Bagian 15)
   Standar kode Clean code, dependency injection lewat protocol, design system reusable, Swift 6 strict concurrency (Bagian 15)
   Akun / server / iklan Tidak ada
   Nilai pembelajaran ActivityKit (Live Activity, Dynamic Island), App Intents, WidgetKit, SwiftData
   Ringkasan satu paragraf: Fokus adalah app timer yang membantu pengguna masuk ke sesi kerja fokus dengan satu ketukan, lalu mengatur ritme fokus dan istirahat secara otomatis. Sisa waktu selalu terlihat di Lock Screen dan Dynamic Island sehingga pengguna tidak perlu membuka app. Semua data tersimpan di perangkat.

2. Latar Belakang, Tujuan, dan Non-Tujuan
   2.1 Masalah
   Timer bawaan iPhone tidak mengenal siklus fokus lalu istirahat. Pengguna harus mengatur ulang tiap kali.
   App Pomodoro populer cenderung tumbuh menjadi platform produktivitas lengkap (tugas, sinkronisasi, laporan, langganan). Untuk orang yang hanya butuh timer, ini terasa berat.
   Saat bekerja, membuka app hanya untuk melihat sisa waktu justru memecah fokus.
   2.2 Tujuan
   ID Tujuan Cara mengukur
   G1 Memulai sesi fokus semudah mungkin Dari app terbuka ke timer berjalan ≤ 2 ketukan
   G2 Sisa waktu terlihat tanpa membuka app Live Activity tampil di 100% sesi pada perangkat yang mengizinkan
   G3 Terasa seperti app buatan Apple Lolos checklist kualitas dan standar engineering (Bagian 14 dan 15)
   G4 Menjadi proyek belajar yang ilmunya bisa dipakai di proyek profesional Semua komponen (Live Activity, App Intents, WidgetKit, SwiftData) terimplementasi dan teruji
   2.3 Non-Tujuan (versi 1.0)
   Manajemen tugas atau to-do list.
   Akun, sinkronisasi cloud, atau kolaborasi.
   Pemblokiran aplikasi atau situs.
   Gamifikasi berat (pohon, poin, level).
   App native untuk iPad, Mac, atau Apple Watch.
   Monetisasi (di luar cakupan proyek latihan ini).
3. Pengguna Sasaran
   Persona A — Rani, mahasiswa S1 (iPhone 11)
   Belajar 3–5 jam per hari, mudah tergoda membuka media sosial.
   Ingin ritme belajar yang teratur tanpa mengurus app yang rumit.
   Kebutuhan: timer sederhana, terlihat dari Lock Screen, riwayat belajar mingguan.
   Persona B — Dimas, pekerja remote (iPhone 15 Pro)
   Bekerja dari rumah dan sering rapat, butuh blok kerja mendalam.
   Suka Dynamic Island dan app yang terintegrasi dengan sistem.
   Kebutuhan: kontrol jeda dari Dynamic Island, istirahat otomatis, notifikasi tidak berlebihan.
   Jobs to be done
   "Ketika aku mau mulai bekerja, aku ingin memulai timer secepat mungkin dan tidak perlu memikirkannya lagi sampai waktunya habis."

4. Lanskap Kompetitor dan Diferensiasi
   App Pendekatan Yang bisa dipelajari
   Focus To-Do Pomodoro + tugas + sinkronisasi lintas platform + laporan Pengguna menghargai statistik; tetapi cakupan luas membuatnya berat
   Forest Gamifikasi: menanam pohon virtual selama sesi Motivasi emosional kuat, tetapi model "hukuman" tidak cocok untuk semua orang
   Flow Timer Pomodoro minimalis Kesederhanaan disukai
   Pomofocus Versi web tanpa akun Tanpa pendaftaran = hambatan rendah
   Diferensiasi Fokus:

Native sepenuhnya: Live Activity, Dynamic Island, komponen sistem, dan Liquid Glass otomatis di iOS 26.
Tanpa akun dan tanpa server: privasi penuh, tidak perlu masuk.
Satu tujuan: timer dan ritme, bukan platform produktivitas.
Tenang: tidak ada penalti, tidak ada rasa bersalah, tidak ada notifikasi promosi. 5. Prinsip Produk
Mulai sebelum berpikir. Tombol mulai selalu terlihat besar dan siap dipakai.
Hadir di tempat pengguna sudah melihat. Lock Screen dan Dynamic Island, bukan hanya di dalam app.
Tenang. Sedikit suara, sedikit teks, tanpa desakan.
Milik pengguna. Data ada di perangkat, tidak ada pelacakan.
Komponen sistem dulu. Gunakan kontrol dan pola bawaan iOS sebelum membuat sendiri. 6. Dukungan Perangkat dan OS
[Keputusan] Perangkat minimum adalah iPhone XR. Batas iOS tertinggi XR adalah iOS 18, maka deployment target ditetapkan iOS 18.0.

Perangkat Status Catatan
iPhone XR, XS, XS Max Didukung (iOS 18 maks) Tidak mendapat Liquid Glass (iOS 26 tidak mendukung perangkat ini)
iPhone SE (gen 2 dan 3) Didukung Layar terkecil 4,7" (375×667 pt), wajib diuji
iPhone 11 dan yang lebih baru Didukung iOS 26 bisa mendapat Liquid Glass
iPhone 14 Pro dan yang lebih baru Didukung penuh Satu-satunya yang memiliki Dynamic Island
iPhone 8 / X dan sebelumnya Tidak didukung iOS 18 tidak tersedia
Perilaku per kemampuan:

Kemampuan Perangkat Perilaku
Live Activity di Lock Screen Semua perangkat yang didukung Banner dengan timer, progres, dan tombol
Dynamic Island iPhone 14 Pro+ Tampilan compact, minimal, dan expanded
Tombol interaktif (jeda/lanjut) Semua (iOS 17+) Berjalan lewat App Intents
Liquid Glass iOS 26+ Otomatis untuk komponen sistem; guard #available(iOS 26, \*) untuk efek tambahan
Syarat build: Xcode 26 atau lebih baru (SDK iOS 26 diwajibkan untuk pengiriman ke App Store sejak 28 April 2026).

Risiko yang diterima: pengguna iPhone XR yang belum memperbarui ke iOS 18 tidak bisa memasang app. Menurunkan target ke iOS 17 hanya butuh guard #available(iOS 18, \*) di fitur Control Center (Bagian 7.2), jadi ini bisa dipertimbangkan kembali kapan saja.

7. Fitur dan Prioritas
   7.1 Versi 1.0 (MVP)
   ID Fitur Prioritas
   FR-01 Timer dengan siklus otomatis: Fokus → Istirahat Pendek (×3) → Fokus → Istirahat Panjang Must
   FR-02 Kontrol: Mulai, Jeda, Lanjut, Berhenti, Lewati fase Must
   FR-03 Label sesi opsional (mengingat 5 label terakhir) Should
   FR-04 Notifikasi lokal saat fase berakhir Must
   FR-05 Live Activity: Lock Screen dan Dynamic Island Must
   FR-06 Jeda/Lanjut dari Live Activity (tombol interaktif) Should
   FR-07 Riwayat sesi, dikelompokkan per hari Must
   FR-08 Statistik: total hari ini, grafik 7 hari, streak Should
   FR-09 Pengaturan durasi dan perilaku Must
   FR-10 Pemulihan state setelah app dihentikan sistem atau perangkat restart Must
   FR-11 Haptic dan suara Should
   FR-12 Lokalisasi Indonesia dan Inggris Must
   FR-13 Layar tidak mati selama timer berjalan di foreground Could
   7.2 Versi 1.1
   Widget Home Screen dan Lock Screen (total fokus hari ini, streak).
   Control Center control untuk "Mulai Fokus" (ControlWidget, iOS 18).
   App Intents dan Shortcuts: "Mulai Fokus 25 menit", didukung Siri.
   Preset (misalnya Deep Work 50/10).
   7.3 Nanti
   Focus Filter (mengikuti mode Fokus sistem).
   App Apple Watch.
   Sinkronisasi iCloud (SwiftData + CloudKit).
   Ikon alternatif dan tema warna.
   Ekspor riwayat (CSV).
   7.4 Kriteria Penerimaan (fitur inti)
   FR-01 Siklus otomatis

Diberikan status Idle, ketika pengguna menekan Mulai, maka fase Fokus berjalan dengan sisa waktu sama dengan durasi fokus.
Diberikan fase Fokus selesai, maka fase berikutnya adalah Istirahat Pendek, atau Istirahat Panjang jika ini sesi fokus ke-N (default N = 4).
Diberikan Istirahat Panjang selesai, maka status kembali ke Idle dan hitungan siklus di-reset.
FR-02 Kontrol

Jeda menyimpan sisa waktu; Lanjut melanjutkan dari sisa itu.
Berhenti membatalkan fase saat ini dan kembali ke Idle setelah konfirmasi jika sisa waktu lebih dari 1 menit.
Lewati langsung memindahkan ke fase berikutnya tanpa mencatat sesi fokus sebagai selesai.
FR-10 Pemulihan state

Diberikan app dihentikan sistem saat timer berjalan, ketika app dibuka lagi sebelum endDate, maka timer melanjutkan dengan sisa waktu yang benar.
Diberikan endDate sudah lewat, maka fase dicatat selesai dan layar menampilkan status selesai (tanpa mengejar ulang rantai fase). 8. Alur Bisnis
8.1 Alur pengguna utama
Pengguna membuka app dan langsung melihat layar Timer (default Fokus 25 menit).
(Opsional) mengisi label sesi.
Menekan Mulai. Pada peluncuran pertama, izin notifikasi diminta pada momen ini (bukan saat app dibuka).
Timer berjalan. Live Activity dimulai, notifikasi akhir fase dijadwalkan.
Pengguna keluar dari app. Sisa waktu terlihat di Lock Screen atau Dynamic Island.
Fase berakhir: haptic, suara, notifikasi. Sistem pindah ke fase berikutnya sesuai aturan.
Setiap fase tercatat di riwayat.
8.2 State machine
Mulai

Jeda

Lanjut

Selesai (sesi 1..N-1)

Selesai (sesi ke-N)

Berhenti

Berhenti

Selesai / Lewati

Selesai / Lewati

Berhenti

Berhenti

Idle

FocusRunning

FocusPaused

ShortBreak

LongBreak

Fase istirahat juga bisa dijeda dengan pola yang sama; dipangkas dari diagram agar tetap terbaca.

8.3 Aturan bisnis
ID Aturan
BR-01 Sumber kebenaran waktu adalah endDate (tanggal), bukan penghitung detik. Sisa waktu = endDate − sekarang.
BR-02 Saat Jeda, simpan pausedRemaining. Saat Lanjut, endDate = sekarang + pausedRemaining.
BR-03 Sesi fokus berstatus selesai hanya jika mencapai nol. Jika dihentikan lebih awal, statusnya dibatalkan dan actualSeconds menyimpan waktu yang sudah berjalan.
BR-04 Sesi dibatalkan dengan durasi aktual di bawah 60 detik tidak disimpan.
BR-05 Default: Fokus 25 mnt, Istirahat Pendek 5 mnt, Istirahat Panjang 15 mnt, istirahat panjang setiap 4 sesi fokus.
BR-06 Istirahat mulai otomatis (default nyala). Fokus berikutnya tidak mulai otomatis (default mati). Alasan: istirahat harus segera dimulai, sedangkan fokus butuh niat pengguna.
BR-07 Hanya satu timer aktif dan satu Live Activity pada satu waktu.
BR-08 Streak = jumlah hari kalender berturut-turut (zona waktu perangkat) dengan minimal satu sesi fokus selesai. Streak putus jika satu hari kalender terlewat. Hari ini tanpa sesi belum memutus streak sampai hari berakhir.
BR-09 Perubahan pengaturan durasi berlaku untuk fase berikutnya, tidak mengubah timer yang sedang berjalan.
BR-10 Notifikasi akhir fase dibatalkan saat Jeda atau Berhenti, dan dijadwalkan ulang saat Lanjut.
8.4 Rentang pengaturan
Pengaturan Default Rentang
Durasi Fokus 25 mnt 5–90 (langkah 5)
Istirahat Pendek 5 mnt 1–30
Istirahat Panjang 15 mnt 5–60 (langkah 5)
Sesi sebelum istirahat panjang 4 2–8 9. Spesifikasi Layar
Navigasi: TabView dengan dua tab, Timer dan Statistik. Pengaturan dibuka dari ikon roda gigi di toolbar layar Timer (sheet).

9.1 Layar Timer
Cincin progres di tengah dengan angka sisa waktu besar (.rounded, monospacedDigit()).
Chip fase di atas cincin: "Fokus · 2 dari 4", "Istirahat Pendek", "Istirahat Panjang".
Kolom label (opsional) di bawah cincin.
Tombol utama besar berbentuk kapsul: Mulai → Jeda/Lanjut.
Tombol sekunder: Berhenti dan Lewati (hanya saat timer aktif).
Angka timer di app memakai Text(timerInterval:) agar hemat baterai dan konsisten dengan Live Activity.
Kondisi Tampilan
Idle Sisa = durasi fokus, tombol Mulai
Berjalan Cincin bergerak, tombol Jeda + Berhenti + Lewati
Dijeda Angka tampil statis, redup sedikit, tombol Lanjut
Fase selesai (app di foreground) Haptic sukses, animasi transisi ke fase berikutnya
Izin notifikasi ditolak Banner inline yang tidak memblokir + tombol ke Pengaturan iOS
Live Activity dimatikan pengguna Tidak ada pesan; app tetap berfungsi normal
9.2 Layar Statistik
Kartu Hari Ini: total menit fokus dan jumlah sesi selesai.
Grafik 7 hari (Swift Charts, batang menit fokus per hari).
Streak (jumlah hari).
Riwayat: daftar dikelompokkan per hari ("Hari ini", "Kemarin", tanggal). Tiap baris: label (atau "Tanpa label"), jam mulai, durasi, ikon selesai/dibatalkan. Geser untuk hapus.
Kondisi kosong: ilustrasi sederhana dan teks singkat ("Belum ada sesi. Mulai sesi pertamamu.").
9.3 Layar Pengaturan (sheet)
Durasi (Fokus, Istirahat Pendek, Istirahat Panjang) dan jumlah sesi sebelum istirahat panjang.
Mulai istirahat otomatis (nyala), mulai fokus otomatis (mati).
Suara akhir fase (beberapa pilihan singkat) dan Haptic (nyala).
Jaga layar tetap menyala saat timer di foreground (nyala).
Tentang (versi, kebijakan privasi) dan Hapus semua riwayat (dengan konfirmasi). 10. Spesifikasi Live Activity dan Dynamic Island
10.1 Model data
struct FokusActivityAttributes: ActivityAttributes {
struct ContentState: Codable, Hashable {
enum Timing: Codable, Hashable {
case running(start: Date, end: Date)
case paused(remaining: TimeInterval)
}
var phase: TimerPhase // .focus, .shortBreak, .longBreak
var timing: Timing // state ilegal tidak bisa dibuat (Bagian 15.1, S7)
var cycleIndex: Int // 1...cyclesPerRound
}
var label: String?
var cyclesPerRound: Int
}
10.2 Aturan pembaruan (penting)
Jangan memperbarui Live Activity tiap detik. Berikan rentang tanggal ke SwiftUI dan biarkan sistem menghitung mundur: Text(timerInterval: start...end, countsDown: true) dan ProgressView(timerInterval:countsDown:).
Perbarui hanya saat ada perubahan makna: mulai, jeda, lanjut, pindah fase, selesai.
Saat dijeda (.paused), tampilkan sisa waktu statis dari nilai remaining.
Text(timerInterval:) cenderung melebar mengisi ruang. Batasi lebarnya dengan .frame(width:) di area compact.
10.3 Tampilan
Area Isi
Lock Screen Ikon fase, "Fokus · 2/4", timer besar, progress bar, tombol Jeda/Lanjut dan Berhenti
Dynamic Island — compact (leading) Ikon fase (SF Symbol)
Dynamic Island — compact (trailing) Timer dengan lebar terbatas
Dynamic Island — minimal Ikon fase atau cincin progres kecil
Dynamic Island — expanded Leading: fase + siklus · Trailing: timer besar · Center: label sesi · Bottom: tombol Jeda/Lanjut dan Berhenti
10.4 Interaksi
Tombol memakai Button(intent:) dengan LiveActivityIntent (App Intents).
Karena intent dieksekusi oleh sistem, state timer disimpan di penyimpanan bersama (App Group) agar app dan extension selalu konsisten.
10.5 Siklus hidup dan batasan
Live Activity dimulai bersama fase dan diakhiri saat Berhenti atau saat pengguna membuka app setelah fase selesai.
Ada laporan bahwa Live Activity tidak berhenti otomatis saat timer mencapai nol dan bahwa staleDate hanya menambah indikator loading. Desain kita tidak bergantung pada penghentian otomatis: tampilan tetap masuk akal pada 0:00 (teks "Selesai"), notifikasi lokal menjadi penanda utama, dan activity dibersihkan saat app dibuka.
Cek ActivityAuthorizationInfo().areActivitiesEnabled. Jika dimatikan, app berjalan tanpa Live Activity.
Info.plist: NSSupportsLiveActivities = YES. 11. Notifikasi
Peristiwa Judul Isi
Fokus selesai Sesi fokus selesai Waktunya istirahat {n} menit.
Istirahat pendek selesai Istirahat selesai Siap fokus lagi?
Istirahat panjang selesai Istirahat panjang selesai Siklus baru menunggu.
Hanya notifikasi lokal. Tanpa push, tanpa server.
Izin diminta secara kontekstual, saat pengguna menekan Mulai pertama kali.
Tidak ada notifikasi pengingat, promosi, atau "streak hampir putus".
Notifikasi dibatalkan dan dijadwalkan ulang mengikuti BR-10. 12. Model Data dan Persistensi
12.1 SwiftData: FocusSession
Properti Tipe Keterangan
id UUID Unik
label String? Opsional
kind enum (focus, shortBreak, longBreak) Jenis fase
startedAt Date Diindeks untuk kueri per hari
endedAt Date? Waktu selesai atau dibatalkan
plannedSeconds Int Durasi yang direncanakan
actualSeconds Int Durasi yang benar-benar berjalan
outcome enum (completed, cancelled) Hasil
cycleIndex Int Urutan dalam siklus
@Model hanya berada di lapisan persistence (Infrastructure). FokusCore memakai struct SessionRecord, dan repository memetakan keduanya (Bagian 15.2).

12.2 State timer aktif (App Group, Codable)
struct TimerState: Codable, Equatable {
enum Status: Codable, Equatable {
case idle
case running(endDate: Date)
case paused(remaining: TimeInterval)
}

    var phase: TimerPhase
    var status: Status
    var cycleIndex: Int
    var startedAt: Date?
    var label: String?

}
Dengan enum bersosiasi nilai, kombinasi mustahil (misalnya running tanpa endDate, atau paused yang masih punya endDate) tidak bisa dibuat sama sekali. Disimpan agar pemulihan state (FR-10) dan tombol Live Activity bekerja walau app tidak berjalan.

12.3 Pengaturan
@AppStorage dengan suite App Group agar terbaca oleh widget extension.

12.4 Wadah data
ModelContainer ditempatkan di App Group supaya widget v1.1 bisa membaca statistik.

13. Arsitektur Teknis
    13.1 Lapisan
    View (SwiftUI) → ViewModel (@Observable) → TimerEngine (murni) + Coordinator → Protocol Service ← Adapter (Sistem iOS)
    Lapisan Tanggung jawab
    View Menampilkan state, meneruskan aksi. Tanpa logika bisnis.
    ViewModel Mengelola state layar, memanggil Service.
    TimerEngine Fungsi murni reduce(state, action, now) yang mengembalikan state baru beserta daftar efek (Bagian 15.3). Mudah diuji karena tanpa efek samping.
    TimerCoordinator Menjalankan efek dari engine lewat protocol layanan. Satu-satunya tempat yang "kotor".
    LiveActivityManager Memulai, memperbarui, dan mengakhiri Activity.
    NotificationScheduler Meminta izin, menjadwalkan, dan membatalkan notifikasi lokal.
    SessionRepository Membaca dan menulis FocusSession (SwiftData).
    StateStore Menyimpan TimerState di App Group.
    AppContainer Composition root: merakit semua dependensi di satu tempat.
    13.2 Target Xcode
    Target Isi
    Fokus App utama
    FokusWidgetExtension Live Activity, dan nanti widget serta Control
    FokusTests Unit test
    FokusUITests UI test
    FokusCore (Swift Package) Domain murni: model, TimerEngine, protocol layanan (Bagian 15.2)
    FokusUI (Swift Package) Design system: token dan komponen reusable (Bagian 15.5)
    Shared (grup file untuk dua target) FokusActivityAttributes, App Intents
    Capabilities: App Groups. Tidak perlu Push Notifications karena tanpa server.

13.3 Struktur folder
Fokus/
├── Packages/
│ ├── FokusCore/ Swift Package: murni, tanpa UI/framework sistem
│ │ ├── Sources/FokusCore/
│ │ │ ├── Models/ TimerState, TimerPhase, SessionRecord, TimerConfiguration
│ │ │ ├── Engine/ TimerEngine, TimerAction, TimerEffect
│ │ │ └── Protocols/ Clock, NotificationScheduling, ActivityPresenting, ...
│ │ └── Tests/FokusCoreTests/
│ └── FokusUI/ Swift Package: design system
│ └── Sources/FokusUI/
│ ├── Tokens/ Spacing, Radius, Typography, Palette, Motion
│ ├── Components/ ProgressRing, PhaseChip, StatCard, EmptyStateView, ...
│ └── Styles/ PrimaryButtonStyle, SecondaryButtonStyle
├── App/ FokusApp.swift, AppContainer (composition root)
├── Infrastructure/ Adapter: SwiftDataSessionRepository, ActivityKitPresenter,
│ UserNotificationScheduler, AppGroupStateStore, SystemClock
├── Features/
│ ├── Timer/ TimerScreen, TimerContent, TimerViewModel, TimerCoordinator
│ ├── Stats/ StatsScreen, StatsContent, StatsViewModel
│ └── Settings/ SettingsScreen, SettingsViewModel
├── Resources/ Localizable.xcstrings, Assets, suara
├── Shared/ (masuk ke app + extension) FokusActivityAttributes, App Intents
├── FokusTests/ · FokusUITests/
FokusWidgetExtension/ Live Activity, Dynamic Island (memakai FokusUI + FokusCore)
docs/adr/ Architecture Decision Records 14. Standar Kualitas
14.1 Desain
Ikuti Human Interface Guidelines: satu aksi utama per layar, ruang kosong yang lega, tipografi SF.
Gunakan komponen sistem sebanyak mungkin. Di iOS 26, tab bar dan toolbar standar otomatis mendapat Liquid Glass hanya bila app dikompilasi dengan Xcode 26. Hindari mewarnai latar komponen navigasi karena dapat mengganggu efeknya.
Glass adalah untuk layer navigasi, bukan area konten. Cincin timer dan kartu statistik tetap sebagai konten biasa.
Warna semantik, mendukung Dark Mode dan Light Mode.
Animasi: contentTransition(.numericText()) untuk angka, transisi halus antar fase.
14.2 Aksesibilitas
Dynamic Type sampai ukuran aksesibilitas: angka timer memakai minimumScaleFactor dan tata letak tidak terpotong.
VoiceOver: label bermakna ("Sisa waktu 24 menit 10 detik"). Jangan mengumumkan tiap detik; umumkan saat status berubah atau pada interval.
Reduce Motion: ganti animasi besar dengan transisi sederhana.
Area sentuh minimal 44×44 pt. Kontras warna memenuhi WCAG AA.
Jangan mengandalkan warna saja untuk membedakan fase (selalu ada ikon dan teks).
14.3 Haptic dan suara
sensoryFeedback: ringan saat Mulai/Jeda, sukses saat fase selesai.
Suara singkat dan lembut. Menghormati pengaturan Silent.
14.4 Performa dan baterai
Tidak ada Timer per detik untuk tampilan; gunakan Text(timerInterval:).
Tidak ada pembaruan Live Activity per detik.
Target: cold start di bawah 1 detik, tanpa jank saat animasi.
14.5 Privasi
Tanpa akun, tanpa analitik pihak ketiga, tanpa akses jaringan.
Label privasi App Store: Data Not Collected.
14.6 Lokalisasi
String Catalog (.xcstrings) untuk Indonesia dan Inggris. Tidak ada teks hardcoded.
Format durasi mengikuti locale. 15. Standar Engineering: System Design dan Clean Code
Bagian ini adalah aturan wajib untuk seluruh kode proyek. Tujuannya: kode mudah dibaca, mudah diuji, mudah diubah, dan komponennya bisa dipakai ulang. Standar ini setara dengan yang diharapkan dari kode tingkat senior di tim profesional.

15.1 Prinsip Desain Sistem

# Prinsip Artinya di proyek ini

S1 Functional core, imperative shell Logika timer adalah fungsi murni (state + action + waktu → state baru + daftar efek). Efek samping (notifikasi, Live Activity, penyimpanan, haptic) dijalankan di lapisan tepi.
S2 Dependency rule Dependensi selalu menunjuk ke dalam: View → ViewModel → Domain ← Infrastructure. Domain tidak tahu apa pun tentang UI atau framework sistem.
S3 Program ke protocol, bukan ke implementasi Setiap kemampuan sistem (notifikasi, Live Activity, penyimpanan, jam, haptic) diakses lewat protocol kecil yang bisa diganti fake saat tes.
S4 Dependency injection lewat constructor Semua dependensi dikirim lewat init. Objek dirakit di satu tempat (composition root) di FokusApp. Tidak ada singleton buatan sendiri.
S5 Single source of truth TimerState hanya punya satu pemilik. UI, Live Activity, dan notifikasi adalah turunan dari state itu.
S6 Aliran data satu arah Action → Engine → State baru → Efek → UI. View tidak pernah mengubah state secara langsung.
S7 Buat state ilegal tidak mungkin ada Modelkan dengan enum bersosiasi nilai, bukan kombinasi Optional yang bisa saling bertentangan.
S8 Efek samping bersifat idempoten Memulai Live Activity dua kali atau me-reconcile dua kali menghasilkan hasil yang sama, tidak duplikat.
15.2 Modularisasi
Kode inti dipisah menjadi dua Swift Package lokal agar batas antar lapisan ditegakkan oleh compiler, bukan hanya oleh kesepakatan.

Modul Isi Boleh import Dilarang import
FokusCore (package) Model domain, TimerEngine, TimerConfiguration, protocol layanan, use case Foundation SwiftUI, UIKit, ActivityKit, UserNotifications, SwiftData, WidgetKit
FokusUI (package) Design system: token, komponen reusable, ButtonStyle, ViewModifier SwiftUI, FokusCore SwiftData, ActivityKit
App + Extension Adapter infrastruktur (SwiftData, ActivityKit, notifikasi), ViewModel, layar, composition root Semua —
Keuntungan: FokusCore dapat diuji cepat dengan swift test tanpa simulator, dan Live Activity extension memakai ulang FokusUI serta FokusCore tanpa menduplikasi kode.

15.3 Pola Inti
Mesin timer sebagai fungsi murni (tanpa Date() langsung, tanpa efek samping):

// FokusCore
struct Transition: Equatable {
var state: TimerState
var effects: [TimerEffect]
}

enum TimerAction: Equatable {
case start(label: String?)
case pause, resume, stop, skip
case phaseElapsed // dipanggil saat endDate tercapai
}

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

struct TimerEngine {
let configuration: TimerConfiguration
func reduce(_ state: TimerState, _ action: TimerAction, now: Date) -> Transition
}
Koordinator menjalankan efek lewat protocol (satu-satunya tempat yang "kotor"):

// FokusCore
protocol NotificationScheduling: Sendable {
func scheduleEndOfPhase(at date: Date, phase: TimerPhase) async throws
func cancelPending() async
}
protocol ActivityPresenting: Sendable { /_ start, update, end _/ }
protocol SessionRecording: Sendable { func save(\_ record: SessionRecord) async throws }
protocol Clock: Sendable { var now: Date { get } }

// App
@MainActor
final class TimerCoordinator {
init(engine: TimerEngine,
clock: Clock,
notifications: NotificationScheduling,
activity: ActivityPresenting,
sessions: SessionRecording,
store: TimerStateStoring) { /_ ... _/ }
}
Composition root (satu-satunya tempat yang mengenal semua implementasi konkret):

@main
struct FokusApp: App {
private let container = AppContainer.live() // merakit semua dependensi
var body: some Scene {
WindowGroup { RootView(container: container) }
}
}
Container/Presentation split untuk layar (mudah dipratinjau dan diuji):

struct TimerScreen: View { // "pintar": memegang ViewModel
@State private var viewModel: TimerViewModel
var body: some View { TimerContent(state: viewModel.presentation, actions: viewModel.actions) }
}

struct TimerContent: View { // "bodoh": hanya data + closure, tanpa dependensi
let state: TimerPresentation
let actions: TimerActions
}
15.4 Aturan Clean Code
Penamaan

Ikuti Swift API Design Guidelines. Nama harus menjelaskan maksud, bukan cara kerja.
Tipe = kata benda (TimerEngine), fungsi = kata kerja (scheduleEndOfPhase), Boolean terbaca sebagai pernyataan (isPaused, hasCompletedCycle).
Tanpa singkatan yang tidak baku (cfg, mgr, vm, tmp).
Ukuran dan kompleksitas (batas lunak yang ditegakkan SwiftLint)

Elemen Batas
Fungsi ≈ 20 baris, kompleksitas siklomatik ≤ 10
Parameter fungsi ≤ 3; lebih dari itu gunakan struct
View.body ≈ 40 baris; lebih dari itu ekstrak subview
File ≈ 300 baris
Nesting ≤ 3 tingkat; gunakan guard dan early return
Desain

SRP: satu tipe, satu alasan untuk berubah. TimerEngine tidak menjadwalkan notifikasi; TimerCoordinator tidak menghitung sisa waktu.
Composition over inheritance. Value type (struct, enum) adalah default. class hanya untuk identitas atau semantik referensi (ViewModel, koordinator), dan ditandai final.
Protocol kecil dan spesifik (interface segregation), bukan satu protocol besar "ServiceManager".
DRY dengan akal sehat: abstraksikan setelah pola muncul tiga kali (rule of three). Jangan membuat abstraksi untuk kebutuhan yang belum ada (YAGNI).
Tidak ada magic value. Angka, kunci UserDefaults, ID notifikasi, dan nama SF Symbol berada di tipe bernama:
enum SettingsKey: String { case focusMinutes, shortBreakMinutes, autoStartBreaks }
enum Symbol { static let focus = "brain.head.profile"; static let rest = "cup.and.saucer.fill" }
Immutability: let secara default; var hanya bila benar-benar berubah.
Access control ketat: private secara default, internal seperlunya, public hanya untuk API package.
Modelkan state dengan enum bersosiasi nilai (S7), contoh di Bagian 12.2.
Keamanan dan kesalahan

Tidak ada ! (force unwrap), try!, atau as!. fatalError hanya untuk kesalahan programmer yang mustahil terjadi.
Kesalahan dimodelkan sebagai enum Error bertipe, dipetakan ke pesan yang dimengerti pengguna di lapisan ViewModel.
Logging memakai Logger (OSLog) dengan subsystem dan category. Tidak ada print.
Concurrency (Swift 6)

Language mode Swift 6 dengan strict concurrency complete.
ViewModel dan koordinator ditandai @MainActor. Tipe domain adalah Sendable.
async/await dan actor; tidak ada DispatchQueue manual atau callback bertingkat.
Komentar dan dokumentasi

Komentar menjelaskan mengapa, bukan apa. Kode yang butuh komentar "apa" sebaiknya diberi nama lebih baik.
API publik FokusCore didokumentasikan dengan /// dan dibangun dengan DocC.
Tidak ada kode yang di-comment-out. Riwayat ada di Git.
15.5 Standar UI yang Reusable (Design System)
Token desain (satu sumber kebenaran, di FokusUI): Spacing, Radius, Typography, Palette (warna semantik di Asset Catalog), Motion. Tidak ada angka atau warna literal di dalam View.

Komponen reusable minimum:

Komponen Fungsi
ProgressRing Cincin progres generik (nilai 0...1, warna dari token)
PhaseChip Chip fase Fokus/Istirahat
PrimaryButtonStyle, SecondaryButtonStyle Gaya tombol lewat ButtonStyle
StatCard Kartu statistik dengan judul, nilai, satuan
DurationStepperRow Baris pengaturan durasi
EmptyStateView Kondisi kosong dengan ikon, judul, deskripsi
SectionHeader Judul seksi seragam
PhaseStyle Satu sumber untuk ikon, warna, dan nama tiap fase, dipakai di app dan Live Activity
Aturan komponen:

Stateless dan murni tampilan: menerima nilai dan closure, tidak mengenal ViewModel atau layanan.
API minimal dengan nilai default yang masuk akal; gunakan @ViewBuilder bila butuh konten fleksibel.
Styling lewat ButtonStyle/ViewModifier, bukan menyalin rantai modifier ke banyak tempat.
Aksesibilitas bawaan: label, trait, dan dukungan Dynamic Type sudah ada di dalam komponen.
Setiap komponen wajib punya #Preview dengan varian: Light/Dark, Dynamic Type terbesar, Bahasa Indonesia/Inggris.
Contoh gaya tombol yang memakai token:

public struct PrimaryButtonStyle: ButtonStyle {
public init() {}
public func makeBody(configuration: Configuration) -> some View {
configuration.label
.font(Typography.headline)
.padding(.vertical, Spacing.md)
.frame(maxWidth: .infinity)
.background(Palette.accent, in: Capsule())
.foregroundStyle(Palette.onAccent)
.opacity(configuration.isPressed ? 0.85 : 1)
}
}
15.6 Aturan Arsitektur yang Ditegakkan Otomatis
Aturan Cara penegakan
FokusCore tidak boleh import UI/framework sistem Batas dependensi di Package.swift + langkah CI yang gagal jika ada import terlarang
Logika tidak memanggil Date() langsung Aturan kustom SwiftLint; gunakan Clock yang disuntikkan
View tidak memanggil layanan langsung Semua lewat ViewModel; diperiksa di review
Tidak ada singleton buatan sendiri Aturan review + composition root tunggal
Tidak ada teks hardcoded untuk pengguna Semua lewat String Catalog; aturan kustom SwiftLint
Tidak ada print, try!, force unwrap SwiftLint (severity error)
15.7 Toolchain dan Otomasi Kualitas
Area Standar
Format SwiftFormat, dijalankan lewat pre-commit hook dan CI
Lint SwiftLint mode ketat dengan aturan kustom (Bagian 15.6)
Compiler Swift 6, strict concurrency complete, warnings as errors di CI
CI Build, test, lint di setiap Pull Request (mis. GitHub Actions dengan runner macOS)
Cakupan test FokusCore ≥ 90%, ViewModel ≥ 80%, keseluruhan ≥ 70%. Cakupan adalah alat bantu, bukan tujuan
Git Conventional Commits, branch pendek (trunk-based), PR kecil (± < 400 baris), template PR dengan checklist
Versi Semantic Versioning
Keputusan arsitektur Dicatat sebagai ADR (Architecture Decision Record) di docs/adr/
Dependensi Nol dependensi pihak ketiga di runtime. Boleh untuk alat build (SwiftLint, SwiftFormat)
15.8 Definition of Done (per fitur / Pull Request)
Compile tanpa warning (Swift 6, strict concurrency)
SwiftFormat dan SwiftLint bersih
Unit test untuk logika baru; bug diperbaiki dengan test regresi yang gagal lebih dulu
Komponen UI baru punya #Preview (Light/Dark, teks besar, ID/EN)
Teks masuk String Catalog (Indonesia dan Inggris)
Aksesibilitas dicek (label VoiceOver, Dynamic Type)
Tidak ada duplikasi berulang tiga kali, tidak ada magic value
ADR ditulis jika ada keputusan arsitektur
Bila menyentuh UI: diuji di layar sempit (SE), iPhone XR, dan iPhone dengan Dynamic Island 16. Strategi Pengujian
16.1 Otomatis
Jenis Cakupan
Unit test TimerEngine (semua transisi state, BR-01 sampai BR-10), perhitungan streak, pemulihan dari endDate yang sudah lewat, SessionRepository dengan SwiftData in-memory
UI test Mulai → Jeda → Lanjut → Berhenti; perpindahan fase; pembuatan riwayat
Test aturan arsitektur CI memeriksa tidak ada import terlarang di FokusCore, tidak ada Date() langsung di logika, dan tidak ada print/force unwrap (Bagian 15.6)
Test dengan fake TimerCoordinator diuji dengan FakeClock, FakeNotificationScheduler, dan FakeActivityPresenter untuk memverifikasi efek yang dijalankan
16.2 Matriks pengujian manual
Skenario Perangkat/kondisi
Tanpa Dynamic Island iPhone XR (iOS 18)
Layar terkecil iPhone SE gen 3
Dynamic Island iPhone 14 Pro atau lebih baru
Liquid Glass Perangkat dengan iOS 26
Aksesibilitas Dynamic Type terbesar, VoiceOver, Reduce Motion
Kondisi sistem Low Power Mode, mode Fokus aktif, izin notifikasi ditolak, Live Activities dimatikan
Ketahanan App dihentikan paksa saat berjalan, perangkat di-restart, perubahan zona waktu/DST, jam otomatis berubah
Live Activity dan Dynamic Island idealnya diverifikasi di perangkat fisik, bukan hanya simulator.

17. Metrik Keberhasilan, Risiko, dan Roadmap
    17.1 Metrik (tanpa analitik pihak ketiga)
    Metrik Target Sumber
    Crash-free sessions ≥ 99,5% Xcode Organizer
    Akurasi timer vs jam sistem Selisih ≤ 1 detik Unit/UI test dan uji manual
    Waktu ke sesi pertama ≤ 2 ketukan UI test
    Retensi hari ke-7 Dipantau App Store Connect
    Rating App Store ≥ 4,5 App Store Connect
    17.2 Risiko dan mitigasi
    Risiko Dampak Mitigasi
    Live Activity tidak berhenti otomatis di 0:00 Tampilan basi Desain yang tetap benar pada 0:00 + notifikasi lokal + pembersihan saat app dibuka (Bagian 10.5)
    App dihentikan sistem Timer "hilang" Berbasis endDate dan TimerState di App Group (BR-01, FR-10)
    Izin notifikasi ditolak Pengguna tidak tahu fase habis Banner inline yang tidak memblokir; app tetap berfungsi
    Pengguna mematikan Live Activities Fitur unggulan hilang Fallback ke notifikasi; app tetap penuh fungsi
    Review App Store menilai app terlalu sederhana Penolakan Fitur inti mencakup Live Activity, statistik, dan riwayat, bukan sekadar timer
    Regresi tampilan di iOS 26 UI terlihat janggal Uji di iOS 18 dan 26; hindari kustomisasi yang menimpa komponen sistem
    DST/zona waktu merusak streak Streak salah Hitung dengan Calendar lokal; uji unit untuk kasus tepi
    17.3 Roadmap
    Estimasi kasar untuk satu developer paruh waktu; sesuaikan dengan ritme kamu.

Fase Fokus Hasil / Definition of Done Estimasi
F0 Setup Repo, Swift Package FokusCore dan FokusUI, target, App Group, SwiftLint/SwiftFormat, CI, ADR pertama 1 minggu
F1 Engine + design system + UI dasar TimerEngine murni dan teruji; token serta komponen dasar (ProgressRing, PhaseChip, button style) dengan #Preview; siklus berjalan 2 minggu
F2 Persistensi + Statistik Sesi tersimpan; riwayat, total hari ini, grafik 7 hari, streak 1 minggu
F3 Notifikasi + pemulihan state Notifikasi akurat; app dimatikan/restart tetap benar 1 minggu
F4 Live Activity + Dynamic Island Timer tampil di Lock Screen dan Dynamic Island 1,5 minggu
F5 Kontrol interaktif Jeda/Lanjut/Berhenti dari Live Activity via App Intents 1 minggu
F6 Polish Haptic, animasi, aksesibilitas, lokalisasi, ikon 1,5 minggu
F7 Beta dan rilis TestFlight, perbaikan, materi App Store 1 minggu
Setiap fase harus memenuhi Definition of Done di Bagian 15.8 sebelum lanjut ke fase berikutnya. Total estimasi ± 10 minggu. Setelah 1.0: fitur versi 1.1 (Bagian 7.2).

18. Catatan Rilis App Store dan Log Keputusan
    18.1 Kesiapan App Store
    Kategori: Produktivitas. Peringkat usia: 4+.
    Privasi: Data Not Collected; sertakan kebijakan privasi singkat.
    Aset: ikon, screenshot (sesuai ukuran yang diwajibkan App Store Connect), deskripsi ID dan EN, kata kunci.
    Build: Xcode 26+, uji lewat TestFlight sebelum submit.
    Draf deskripsi singkat: "Timer fokus yang tenang. Mulai dengan satu ketukan, pantau dari Lock Screen dan Dynamic Island, dan biarkan ritme fokus-istirahat berjalan sendiri. Tanpa akun, tanpa iklan."
    18.2 Log keputusan

# Keputusan Alasan Dapat ditinjau ulang?

D1 Perangkat minimum iPhone XR Permintaan produk Ya
D2 Deployment target iOS 18.0 XR mendukung hingga iOS 18; menyederhanakan kode Ya, bisa turun ke iOS 17
D3 SwiftData untuk riwayat Tersedia sejak iOS 17; tidak perlu fallback Core Data Tidak perlu
D4 @Observable untuk ViewModel Tersedia sejak iOS 17 Tidak perlu
D5 State timer berbasis endDate Andal saat app dihentikan Tidak
D6 Tanpa akun/server/analitik Privasi dan kesederhanaan Ya, untuk sinkronisasi iCloud di masa depan
D7 Istirahat mulai otomatis, fokus tidak Menjaga niat pengguna Ya (setting)
D8 Tidak bergantung pada penghentian Live Activity otomatis Ada laporan perilaku tidak konsisten Tidak
D9 Liquid Glass hanya lewat komponen sistem + guard iOS 26 Menghindari kustomisasi yang mengganggu Ya
D10 Functional core, imperative shell: TimerEngine fungsi murni Mudah diuji, tanpa efek samping Tidak
D11 Dua Swift Package lokal (FokusCore, FokusUI) Batas lapisan ditegakkan compiler; reuse ke extension Ya, bisa digabung jika terasa berlebihan
D12 Dependency injection lewat constructor + composition root, tanpa singleton Testabilitas Tidak
D13 Swift 6 dengan strict concurrency complete Keamanan concurrency sejak awal Tidak
D14 Nol dependensi pihak ketiga di runtime Kecil, aman, mudah dirawat Ya, jika ada kebutuhan kuat
D15 Aturan kode ditegakkan otomatis (SwiftLint, SwiftFormat, CI) Konsistensi tanpa bergantung pada disiplin manual Tidak
