# Bliss

<p align="center">
  <img src="MainApp/assets/images/iconapp.png" alt="Ikon Bliss" width="96" />
</p>

<p align="center">
  <strong>Asisten WhatsApp local-first untuk Android.</strong><br />
  Konfigurasikan bot dari ponsel—tanpa server Bliss yang mengelola percakapan.
</p>

> **Peringatan penting:** Bliss bukan produk, afiliasi, atau API resmi WhatsApp/Meta. Koneksi memakai Baileys, pustaka pihak ketiga berbasis protokol WhatsApp Web. WhatsApp dapat mengubah protokol atau membatasi akun. Pahami [risiko dan ketentuan](MainApp/assets/legal/terms.md) sebelum menautkan nomor.

Bliss menyimpan konfigurasi, sesi, kredensial provider, dan log di perangkat. Jika pengguna mengaktifkan pemrosesan AI eksternal, pesan dan konteks relevan dikirim ke provider AI yang dipilih. Baca [Kebijakan Privasi](MainApp/assets/legal/privacy.md) untuk alur data selengkapnya.

## Mulai di sini

- [README aplikasi Android](MainApp/README.md) — fitur, status, batasan, dan cara build.
- [Setup Android](MainApp/ANDROID_SETUP.md) — persiapan Flutter, Android SDK, dan runtime lokal.
- [Dokumentasi runtime WhatsApp](WhatsAppBot/README.md) — arsitektur Node.js/Baileys dan API dashboard.
- [Ketentuan Layanan](TERMS_OF_SERVICE.md) · [Kebijakan Privasi](PRIVACY_POLICY.md)

## Status

Proyek ini masih dalam pengembangan; belum dirilis melalui Play Store dan belum menjamin kompatibilitas luas atau ketersediaan 24/7. Build Android mengemas Node.js Mobile versi prerelease pihak ketiga. Gunakan nomor khusus uji/bisnis dan jangan mengandalkan bot untuk komunikasi kritis.

## Tentang proyek

Dibangun oleh Syacretary dengan bantuan Codex, Claude Code, dan Antigravity. Pengembang memperkirakan sekitar 95% kode dibuat dengan bantuan AI, sementara keputusan desain, alur kerja, peninjauan, dan pengujian tetap menjadi tanggung jawab manusia. Lihat [README aplikasi](MainApp/README.md#tentang-bliss) untuk konteks proyek dan [catatan lisensi](MainApp/README.md#lisensi-dan-kontak) sebelum menggunakan ulang kode.
