# IngetZeon 🔔

Aplikasi pengingat harian untuk Android dengan **asisten AI** dan **suara** (Bahasa Indonesia).

- Alarm tetap berbunyi walau aplikasi ditutup, bahkan setelah HP di-restart
- Bilang *"ingatkan besok jam 7 pagi olahraga"*, pengingat langsung dibuat
- Bisa dipakai tanpa internet (pemahaman offline), lebih pintar dengan Gemini
- **Kamera parkir**: foto lokasi parkir + "saya parkir di B2", lalu tanya "di mana aku parkir?"
- **Alarm berlagu**: melodi khas IngetZeon / nada alarm HP, berulang sampai dimatikan, layar alarm di atas layar kunci
- Beranda, Kalender, Statistik, Profil, tema terang/gelap
- **Versi website** di folder `website/` (bisa dibuka di browser HP/laptop)

## Unduh APK

Buka halaman **[Releases](../../releases/latest)**, unduh `IngetZeon.apk`, lalu buka di HP.
Kalau muncul peringatan "aplikasi tidak dikenal", izinkan pemasangan dari browser/file manager.

Setiap kali kode di repo ini berubah, GitHub otomatis mem-build APK baru (tab **Actions**).

## Versi website

Folder `website/` berisi versi web IngetZeon (satu file HTML, bisa dipasang ke layar utama HP).
Cara online di Cloudflare Pages (`ingetzeon.pages.dev`):

1. Cloudflare → **Workers & Pages** → **Create** → **Pages** → **Connect to Git** → pilih repo `ingetzeon`
2. *Framework preset*: None · *Build command*: kosongkan · *Build output directory*: `website`
3. **Save and Deploy**. Setiap perubahan di repo otomatis ikut ter-update.

Atau unggah manual file `IngetZeon-website.zip` dari halaman Releases.

## Setelah dipasang

1. Izinkan **notifikasi** dan **mikrofon** saat diminta.
2. (Opsional) Isi **Kunci API Gemini** di menu Profil. Buat gratis di [aistudio.google.com](https://aistudio.google.com) → *Get API key*.
3. Kalau alarm telat/tidak bunyi: Pengaturan HP → Aplikasi → IngetZeon → Baterai → **Tanpa batasan**
   (di Xiaomi aktifkan juga **Autostart**).

## Struktur kode

```
lib/
├── main.dart                     # Inisialisasi Hive, notifikasi, Riverpod
├── app.dart                      # MaterialApp, tema, bahasa Indonesia
├── core/
│   ├── theme/                    # Warna (Violet #6C63FF, Pink #FF6584), tema Poppins
│   └── utils/date_utils.dart     # Format tanggal & jam Indonesia
├── data/
│   ├── models/reminder.dart      # Model pengingat + logika pengulangan
│   └── repositories/             # Penyimpanan Hive (offline-first)
├── services/
│   ├── notification_service.dart # Alarm (sekali/harian/mingguan/bulanan, exact alarm)
│   ├── ai_service.dart           # Gemini via REST → JSON reminder
│   ├── natural_parser.dart       # Pemahaman bahasa alami offline
│   └── voice_service.dart        # speech_to_text + flutter_tts (id-ID)
├── providers/                    # Riverpod: reminders, settings, chat
└── presentation/
    ├── screens/                  # Home, Kalender, AI Assistant, Form, Statistik, Profil
    └── widgets/                  # Kartu, tile pengingat, dll.
test/widget_test.dart             # Tes parser & logika jadwal
tool/patch_android.py             # Izin AndroidManifest, desugaring, ikon
```

## Build sendiri di komputer (opsional)

Butuh Flutter SDK + Android Studio.

```bash
flutter create --platforms=android --org com.zeon --project-name ingetin .
python3 tool/patch_android.py
flutter pub get
flutter run            # ke HP yang tersambung kabel USB
flutter build apk      # hasil: build/app/outputs/flutter-apk/app-release.apk
```

### Izin yang ditambahkan ke `android/app/src/main/AndroidManifest.xml`

`tool/patch_android.py` menambahkan otomatis:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" android:maxSdkVersion="32"/>
```

plus receiver `ScheduledNotificationReceiver`, `ScheduledNotificationBootReceiver`, `ActionBroadcastReceiver`
dan `<queries>` untuk `RecognitionService` & `TTS_SERVICE`.
