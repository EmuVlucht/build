# UploadServer

Aplikasi Flutter — jalankan `uploadserver` (Python) di Android **tanpa Termux**.

Python 3.11 + `uploadserver` di-bundle ke APK via **Chaquopy**.

## Cara Build (100% GitHub Actions)

1. Upload semua file ini ke repo GitHub
2. Buka tab **Actions** → tunggu workflow selesai (~10–15 menit)
3. Download APK dari **Artifacts → uploadserver-release**

## Fitur

- Start / Pause / Resume / Stop server
- Pilih folder yang di-serve (Internal, SD Card, USB, System)
- Port kustom (default 8000)
- Tema: Terang / Gelap / Sistem
- Basic Auth (download & upload)
- Basic Auth Upload Only
- Preview command sebelum start

## Arsitektur

```
Flutter (Dart) → MethodChannel → Kotlin → Chaquopy → Python 3.11
                                                          └── uploadserver (pip, bundled)
```

## minSdk

Android 7.0 (API 24)
