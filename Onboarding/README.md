# Bliss

<p align="center">
  <img src="assets/images/avatarai_ready.png" alt="Maskot Bliss" width="96" />
</p>

<p align="center">
  <strong>Asisten WhatsApp local-first untuk Android.</strong><br />
  Atur gaya balasan dan pengetahuan bot dari ponselmu—tanpa server Bliss yang mengelola chat.
</p>

<p align="center">
  <a href="#status-proyek">Status</a> ·
  <a href="#fitur">Fitur</a> ·
  <a href="#privasi-dan-alur-data">Privasi</a> ·
  <a href="#risiko-penting">Risiko</a> ·
  <a href="#mencoba-dari-source">Build</a> ·
  <a href="assets/legal/terms.md">Ketentuan</a> ·
  <a href="assets/legal/privacy.md">Kebijakan Privasi</a>
</p>

---

Bliss mengubah perangkat Android menjadi tempat konfigurasi dan menjalankan bot WhatsApp yang dapat membalas pesan masuk berdasarkan profil serta pengetahuan bisnis yang kamu berikan. Aplikasi ini dikembangkan oleh **Syacretary**.

> **Penting:** Bliss bukan produk, mitra, atau API resmi WhatsApp/Meta. Koneksi WhatsApp menggunakan Baileys, pustaka pihak ketiga berbasis protokol WhatsApp Web. Metode ini dapat berhenti berfungsi atau menyebabkan akun dibatasi. Baca bagian [Risiko penting](#risiko-penting) sebelum menautkan nomor.

## Status proyek

Bliss masih dalam pengembangan dan belum dipublikasikan melalui Play Store. Integrasi Android, penautan WhatsApp, dan pengiriman/penerimaan pesan telah diuji pada perangkat pengembang; kompatibilitas luas, perilaku jangka panjang di berbagai perangkat, dan kesiapan untuk komunikasi bisnis kritis belum dijamin.

Belum ada APK rilis publik yang dijanjikan di sini. Jangan mengunduh APK dari sumber tidak dikenal. Pengguna yang memahami risiko dapat membangun aplikasi dari source code mengikuti [petunjuk build](#mencoba-dari-source).

## Fitur

- Alur onboarding untuk mengatur nama/profil bot, tujuan penggunaan, gaya bicara, dan provider AI.
- Penautan WhatsApp lewat QR atau pairing code.
- Runtime Node.js lokal yang dibundel di aplikasi Android; UI Flutter berkomunikasi dengannya melalui perangkat yang sama.
- Provider balasan lokal berbasis aturan, serta provider AI remote yang dapat dipilih pengguna.
- Persetujuan pemrosesan AI eksternal yang terpisah; tanpa persetujuan itu, isi pesan tidak dikirim ke provider AI remote oleh alur balasan Bliss.
- Pengolahan pengetahuan bisnis secara lokal, termasuk ekstraksi teks/OCR yang didukung, agar informasi relevan dapat dipakai bot.
- Dashboard untuk mengatur bot, melihat percakapan, dan memeriksa status runtime.
- Penyimpanan lokal terenkripsi untuk kredensial, sesi, konfigurasi, dan log yang didukung platform.

Bliss hanya memproses tipe pesan yang didukung oleh runtime. Saat ini fondasinya berfokus pada pesan langsung teks/caption; pesan grup, status, broadcast, pesan yang dikirim akun sendiri, serta pesan non-teks diabaikan. Periksa dokumentasi runtime untuk rincian batas implementasi.

## Privasi dan alur data

Bliss memakai pendekatan local-first: pada rilis saat ini, pengembang tidak mengoperasikan backend pusat untuk menerima isi chat, API key, sesi WhatsApp, atau dokumen bisnis. Konfigurasi, kredensial, sesi, dan log disimpan pada ruang aplikasi di perangkat.

Local-first bukan berarti semua data selalu berada di perangkat:

1. **WhatsApp/Meta** tetap memproses koneksi dan pesan sebagaimana bagian dari layanan WhatsApp.
2. Jika kamu mengaktifkan **Izinkan pemrosesan AI eksternal**, Bliss mengirim pesan dan konteks relevan ke provider AI yang dipilih untuk menyusun jawaban. Kebijakan retensi dan penggunaan provider tersebut berlaku secara terpisah.
3. Aplikasi dapat meminta berkas font dari Google Fonts saat font belum tersedia di cache.

Log percakapan aktif secara default dengan retensi standar 30 hari. Saat ini kontrol untuk menonaktifkan logging atau menghapus riwayat belum tersedia langsung di UI dashboard; konfigurasi dan API runtime lokal menyediakan tindakan tersebut. Menghapus data aplikasi Android menghapus salinan lokal Bliss, bukan salinan yang sudah diproses WhatsApp atau provider eksternal.

Detail lengkap: [Kebijakan Privasi](assets/legal/privacy.md). Jangan masukkan data sensitif pelanggan ke provider AI tanpa menilai dasar pemrosesan, pemberitahuan, dan kebijakan provider terlebih dahulu.

## Risiko penting

Bliss **tidak menggunakan WhatsApp Business Platform/API resmi**. Baileys adalah proyek pihak ketiga yang berinteraksi dengan protokol WhatsApp Web; perubahan protokol WhatsApp dapat memutus koneksi. Penggunaan otomatis juga dapat bertentangan dengan ketentuan WhatsApp. WhatsApp melarang penggunaan tertentu seperti pesan otomatis/massal yang tidak diizinkan dan dapat menonaktifkan atau menangguhkan akun yang dianggap melanggar. [Baca Ketentuan WhatsApp](https://www.whatsapp.com/legal/terms-of-service).

Dengan menautkan akun, kamu memahami bahwa:

- akun/nomor dapat dibatasi oleh WhatsApp; Bliss tidak dapat menjamin atau memulihkannya;
- runtime bergantung pada Android, daya, jaringan, dan pembatasan proses latar belakang perangkat—“24/7” tidak dijamin;
- jawaban AI mungkin keliru. Pantau bot dan ambil alih percakapan bila perlu;
- API provider AI, internet, dan layanan pihak ketiga dapat memiliki biaya, batas kuota, atau aturan sendiri;
- kamu bertanggung jawab atas izin menggunakan nomor, pemberitahuan kepada pelanggan, isi balasan, dan kepatuhan terhadap hukum serta kebijakan layanan yang kamu gunakan.

> Gunakan hanya untuk percakapan yang diharapkan dan penggunaan yang diizinkan. Jangan gunakan Bliss untuk spam, broadcast tak diminta, scraping, penipuan, pelecehan, atau pesan massal. Jika perlu kepastian operasional dan kepatuhan, gunakan solusi resmi WhatsApp Business Platform.

Dokumen lengkap: [Ketentuan Layanan Bliss](assets/legal/terms.md).

## Mencoba dari source

Petunjuk berikut ditujukan untuk pengembang. Build membutuhkan jaringan saat mengambil dependency dan runtime Android yang dipin.

### Prasyarat

- Flutter SDK dan Android SDK/NDK yang sesuai dengan konfigurasi proyek;
- Java 17, Python 3, CMake 3.22.1;
- Node.js 20 atau lebih baru dan npm;
- Linux/macOS atau lingkungan shell yang kompatibel dengan script build.

### Ambil dependency dan build APK debug

Jalankan dari direktori `Onboarding` ini, di dalam workspace yang juga berisi direktori `WhatsAppBot`:

```bash
# Siapkan backend WhatsApp lokal
cd ../WhatsAppBot
npm ci

# Kembali ke direktori aplikasi Flutter
cd ../Onboarding
./flutter-dev.sh pub get
./flutter-dev.sh analyze
./flutter-dev.sh test
./flutter-dev.sh build apk --debug
```

APK debug akan berada di `build/app/outputs/flutter-apk/app-debug.apk`. Perangkat Android dapat dipakai untuk menjalankan build dengan `./flutter-dev.sh run`; pastikan USB debugging dan izin perangkat telah diatur. Lihat [ANDROID_SETUP.md](ANDROID_SETUP.md) untuk rincian lingkungan lokal.

`flutter-dev.sh` memakai Flutter SDK lokal di `.tooling/flutter-sdk/` dan Pub cache lokal di `.pub-cache/`. Siapkan Flutter SDK pada lokasi tersebut terlebih dahulu, atau gunakan instalasi Flutter milikmu sendiri dengan memastikan Android SDK, Pub cache, serta izin tulisnya terkonfigurasi.

Untuk memeriksa backend secara mandiri:

```bash
cd ../WhatsAppBot
npm test
npm run typecheck
npm run build
```

> Catatan: build Android mengunduh runtime Node.js Mobile pihak ketiga dan memverifikasi checksum. Runtime mobile saat ini dipin ke versi prerelease. Build sukses tidak berarti sudah layak rilis atau kompatibel dengan semua perangkat.

## Struktur proyek

| Direktori | Isi |
| --- | --- |
| `lib/onboarding/` | Alur onboarding dan adapter koneksi Flutter |
| `lib/dashboard/` | Beranda, percakapan, Studio, dan state dashboard |
| `lib/legal/` | Layar persetujuan dan pembaca dokumen legal |
| `assets/legal/` | Dokumen Ketentuan dan Privasi yang dibundel ke aplikasi |
| `android/` | Host Android untuk runtime lokal dan integrasi native |
| `../WhatsAppBot/` | Adapter WhatsApp, runtime Node, provider AI, penyimpanan, dan tes backend |

Detail arsitektur dan kontrak runtime: [dokumentasi WhatsAppBot](../WhatsAppBot/README.md).

## Tentang Bliss

Bliss dibuat untuk memberi pemilik usaha pilihan local-first dan kendali langsung atas pengaturan bot, tanpa mewajibkan pengelola Bliss menjalankan server percakapan. Server dan infrastruktur berulang bisa menjadi beban, terutama bagi usaha kecil. Namun model lokal ini punya konsekuensi: pengguna mengelola perangkat dan koneksinya sendiri, sementara WhatsApp dan provider AI tetap memiliki aturan serta biaya masing-masing.

Proyek ini dibangun dengan bantuan agentic AI, termasuk Codex, Claude Code, dan Antigravity. Pengembang memperkirakan sekitar 95% kode ditulis dengan bantuan AI; keputusan alur kerja, desain, dan arah proyek tetap dibuat manusia, yang juga meninjau kode dan menguji fitur. Ini bukan jaminan aplikasi bebas bug atau risiko. Jika pendekatan tidak resmi ini tidak cocok untukmu, itu sepenuhnya wajar.

## Lisensi dan kontak

Belum ada berkas lisensi open-source yang memberikan izin penggunaan ulang. Jangan menganggap kode otomatis berlisensi untuk redistribusi atau penggunaan komersial. Untuk pertanyaan, hubungi pengelola melalui kanal resmi tempat kamu memperoleh repository ini.
