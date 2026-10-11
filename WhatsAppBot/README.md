# Bliss local WhatsApp runtime

Backend lokal terpisah untuk menjadi adapter antara konfigurasi onboarding Bliss, UI Flutter, dan sesi WhatsApp Web via Baileys. Tanggung jawab bot, penyimpanan sesi, dan generator balasan dipisahkan agar implementasi AI maupun host Android bisa diganti tanpa mengikat UI pada Baileys.

## Status integrasi Android

Proyek memiliki jalur embedding Android: Flutter memulai foreground service, service memuat `libnode.so` Node.js Mobile, lalu Node menjalankan adapter lokal dan Baileys. Runtime Node dipin ke fork `fogtape/nodejs-mobile` `v24.21.0-0` (prerelease); task Gradle mengunduh asset Android beserta SHA-256 yang diverifikasi dan mengemas runtime backend ke APK. Koneksi Flutter ↔ Node hanya melalui loopback dengan bearer token acak per proses; kunci sesi dibungkus Android Keystore. Pengguna telah mengonfirmasi pairing dan pengiriman pesan berhasil di perangkatnya. Perubahan konfigurasi dalam dokumen ini lulus tes backend lokal; APK Android perlu dibangun ulang untuk memuat perubahan tersebut.

### Build Android

Prasyarat: Android SDK/NDK dan CMake sesuai konfigurasi Flutter, Python 3, Node.js 20+, npm, serta akses jaringan saat pertama kali menyiapkan runtime. Dari folder `WhatsAppBot` jalankan `npm install`, lalu dari `Onboarding` jalankan `flutter pub get` dan `flutter build apk`. Gradle menjalankan `WhatsAppBot/scripts/fetch_android_node_runtime.py`, membangun TypeScript, dan menyalin runtime beserta dependensinya ke assets APK. Node mobile dirilis sebagai prerelease pihak ketiga dan ABI Android harus diuji pada perangkat sebenarnya sebelum rilis.

## Batas aman bawaan

- Hanya pesan teks/caption dari chat langsung yang masuk ke generator balasan.
- Grup, status, broadcast, pesan yang dikirim akun sendiri, dan pesan non-teks diabaikan.
- Deduplikasi pesan, serialisasi per-chat, cooldown balasan, panjang balasan terbatas, serta reconnect eksponensial berbatas.
- Tidak ada QR, nomor, JID, isi chat, token provider, atau kredensial yang ditulis oleh runtime ke log.
- `LocalStarterReplyProvider` berjalan lokal, menerapkan template dan aturan kata kunci yang dapat dikonfigurasi; ini bukan AI. Provider baru ditambahkan sebagai modul terpisah dan didaftarkan secara eksplisit.
- Sesi dienkripsi dengan AES-256-GCM; pada Android kunci AES dibungkus kunci non-exportable Android Keystore.

## Menjalankan mode koneksi lokal (Node 20+)

```sh
npm install
export BLISS_SESSION_KEY="$(openssl rand -base64 32)"
npm run dev
```

Scan QR yang tampil menggunakan WhatsApp > Perangkat tertaut. Untuk pairing code, set `BLISS_CONNECT_METHOD=pairCode` dan `BLISS_PHONE_NUMBER` ke nomor internasional berisi digit saja, misalnya `628123456789`. QR/kode pairing adalah kredensial sementara—jangan bagikan atau simpan di log.

CLI hanya menguji koneksi dan tidak membalas pesan. Integrasi aplikasi membuat `BotRuntime` dengan `ConfiguredReplyProvider` serta store yang sesuai platform:

```ts
const runtime = new BotRuntime(sessionStore, replyProvider);
runtime.on('event', (event) => nativeBridge.send(event));
const qrOrCode = await runtime.start({ profile, method: 'qr' }); // undefined if session is already connected
```

Untuk pair code, `start` menerima `phoneNumber` digits-only. Kontrak onboarding Flutter saat ini belum memiliki input nomor untuk mode ini; UI perlu meneruskan nomor secara eksplisit saat bridge diintegrasikan. Bentuk profil yang diterima runtime mengikuti field onboarding `purpose`, `purposeOther`, `volumeIndex`, `tone`, `businessName`, dan `provider`.

## Modul konfigurasi untuk dashboard

`BotConfiguration` adalah kontrak UI/backend berversi (`schemaVersion: 2`) dengan migrasi otomatis dari schema v1. Kontrak mencakup profil, aturan balasan, preset/custom plain-text tone, emoji/panjang respons, perintah teks, plugin terpasang, pilihan provider/model, serta privasi. Perubahan konfigurasi dapat diterapkan tanpa reconnect.

API dipisahkan ke modul `dashboard-api.ts`, hanya menerima koneksi loopback, dan semua endpoint memerlukan bearer token acak milik sesi runtime. Request harus menyertakan `Authorization: Bearer <token>`:

| Endpoint | Fungsi |
| --- | --- |
| `GET /v1/capabilities` | Skema, daftar fitur tertunda, hot update |
| `GET /v1/config`, `PATCH /v1/config` | Baca/perbarui konfigurasi; API key tidak pernah disertakan |
| `GET /v1/providers` | Daftar provider dan status `configured` tanpa membuka kunci |
| `PUT/DELETE /v1/providers/:id/credential` | Simpan/hapus API key terenkripsi; `PUT` menerima `{ "apiKey": "..." }`, respons hanya status |
| `POST /v1/test-reply` | Uji provider/model yang tersimpan melalui runtime; memerlukan consent eksternal dan kredensial bila dibutuhkan |
| `GET /v1/conversations?limit=50` | Ringkasan inbox dengan ID opaque, nama, pesan terakhir, arah, dan status takeover |
| `DELETE /v1/conversations` | Hapus seluruh riwayat tersimpan secara eksplisit |
| `GET /v1/conversations/:id/messages?limit=100` | Riwayat masuk/balasan yang tersimpan |
| `POST /v1/conversations/:id/takeover` / `resume` | Jeda bot untuk satu percakapan / lanjutkan otomatisasi |
| `POST /v1/conversations/:id/reply` | Kirim balasan teks sebagai operator; aksi non-teks tidak tersedia |
| `GET /v1/events` | SSE untuk status, pesan percakapan, error generik, dan diagnostik provider yang sudah disanitasi |
| `POST /v1/start`, `/stop`, `/logout`; `GET /v1/status`, `/health` | Lifecycle serta status runtime |

Contoh payload parsial untuk mengubah balasan dan menambah rule:

```json
{
  "assistant": {
    "defaultReply": "Halo, terima kasih sudah menghubungi {{businessName}}.",
    "rules": [
      { "id": "jam-buka", "enabled": true, "keywords": ["jam buka", "operasional"], "response": "Kami buka pukul 09.00–17.00." }
    ]
  },
  "behavior": { "autoReply": true, "cooldownSeconds": 15, "maxReplyLength": 1000 }
}
```

Template mendukung `{{businessName}}`, `{{assistantName}}`, `{{acknowledgement}}`, dan `{{customerMessage}}`. Field tak dikenal dibuang saat normalisasi; API key tidak termasuk dalam konfigurasi. API key remote tersimpan dalam file terenkripsi terpisah dari konfigurasi dan sesi Baileys; Android membungkus kunci enkripsi dengan Android Keystore. Endpoint provider hanya mengungkap boolean `configured`.

Provider yang terdaftar: `local-template`, `openai`, `gemini`, `anthropic`, `deepseek`, dan `groq`. Provider remote tidak akan mengirim isi percakapan sebelum `privacy.allowExternalProcessing` diaktifkan secara eksplisit; start ditolak bila auto-reply aktif tetapi consent atau API key belum tersedia. Model default bisa diganti lewat `provider.model`; kapabilitas API mengembalikan ID model default dan notice provider.

Percakapan disimpan terenkripsi, dibatasi 500 thread/3.000 pesan, serta mengikuti `privacy.retentionDays`; pemilik dapat menonaktifkan logging. ID percakapan yang terlihat dashboard adalah hash opaque, bukan nomor/JID WhatsApp. SSE tetap menyediakan pesan live selama runtime berjalan meski logging dimatikan. Diagnostik mengungkap provider/model, status kredensial (ada/tidak), request/hasil HTTP, dan alasan pesan dilewati; nilai API key, header otorisasi, nomor/JID, dan isi request tidak pernah dimasukkan ke log. Pastikan dashboard menyediakan penjelasan consent, pengaturan retensi, dan tindakan hapus riwayat sebelum membuka inbox ke pengguna.

### Fokus inti dan pemetaan Dashboardv2

- `toneIndex`: `0 → formal`, `1 → friendly`, `2 → concise`, `3 → custom`; `customTone` masuk sebagai `style.customText`. Slider `emoji` dan `length` langsung dipetakan ke `style.emojiLevel` dan `style.responseLength`.
- Provider label UI dipetakan ke ID stabil: `Google / Gemini → gemini`, `OpenAI / ChatGPT → openai`, `Anthropic / Claude → anthropic`, `Opensource / Deepseek → deepseek`, `Groq → groq`. Simpan kunci hanya melalui credential endpoint, bukan `PATCH /v1/config`.
- `chats` dashboard masih sample in-memory; ganti dengan `/v1/conversations`, `/messages`, dan SSE. Aksi `Ambil alih` mengirim `takeover`; balasan operator masuk ke `/reply`; tombol untuk menyerahkan kembali ke bot memakai `resume`.
- Plugin resmi tersedia melalui `GET /v1/plugin-store` dan folder `src/plugin-store/<id>/` (`manifest.json` + `index.ts`). Penambahan plugin memerlukan implementasi lokal tepercaya yang ikut dikompilasi/dibundel; manifest saja tidak dapat menambahkan atau mengeksekusi kode. Android mengemas manifest dan implementasi hasil build bersama runtime. Instalasi selalu dimulai nonaktif, memerlukan pengaturan eksplisit, dan API menolak ID yang tidak terdaftar atau plugin aktif tanpa konfigurasi tervalidasi. `PATCH /v1/plugins` menyimpan instalasi/konfigurasi/aktivasi, sedangkan `commands` masih ditunda dan ditolak (`FEATURES_DEFERRED`).

Dashboardv2 saat ini belum terhubung ke API: state chat, API key, plugin, dan command masih demo lokal. API key perlu memakai endpoint credential khusus; data rahasia tidak boleh dikirim lewat `PATCH /v1/config`.

### Menambah provider atau integrasi

Implementasikan kontrak `ReplyProvider.generate`, daftarkan modul melalui `ReplyProviderRegistry.register(id, adapter)`, lalu tambahkan secure credential adapter bila provider membutuhkan kunci. Runtime meneruskan profil, teks pesan, konfigurasi, dan chat ID ke adapter; provider AI eksternal sebaiknya meminta persetujuan sebelum mengirim isi pesan, membatasi timeout/biaya, dan tidak mencatat konten pesan. Untuk penyimpanan konfigurasi lain, implementasikan kontrak `SessionStore` dan injeksikan ke `BotConfigurationStore`.

Jalankan `npm test`, `npm run typecheck`, dan `npm run build` untuk memvalidasi backend. Tes mencakup migrasi/merge konfigurasi, pemindaian plugin store, validasi konfigurasi/aktivasi plugin, ID/riwayat percakapan, consent provider, dan kerahasiaan API key.

## Adapter provider AI

Adapter HTTP menggunakan API Responses OpenAI, `generateContent` Gemini, Messages Anthropic, serta format Chat Completions DeepSeek/Groq. Semua request dibatasi timeout 20 detik, tanpa tool/action, dan error upstream tidak diteruskan ke log maupun dashboard. Default mengikuti pilihan produk: [GPT-6 Luna](https://developers.openai.com/api/docs/models/gpt-6-luna), [Claude Haiku 5.5](https://platform.claude.com/docs/en/models/haiku-5-5/overview), [Gemini 3.1 Flash-Lite](https://ai.google.dev/gemini-api/docs/models/gemini-3.1-flash-lite), DeepSeek V4 Flash, dan GPT-OSS 20B di Groq. DeepSeek menyebut `deepseek-flash` sebagai ID aktif untuk V4.1 Flash; `deepseek-v4-flash` merupakan nama lama yang masih sementara diterima. Dari daftar Free-tier yang diberikan, GPT-OSS 20B memiliki kuota sama dengan GPT-OSS 120B (30 RPM, 1K RPD, 8K TPM, 200K TPD), sementara harga Developer per tokennya setengah menurut [halaman model 20B](https://console.groq.com/docs/model/openai/gpt-oss-20b) dan [120B](https://console.groq.com/docs/model/openai/gpt-oss-120b). Karena itu, 20B jadi opsi lebih hemat dengan kuota yang sama; reasoning dibatasi rendah dan tools dimatikan. Model dapat diganti lewat `provider.model` di Studio setelah integrasi.

## Catatan kebijakan dan risiko

Baileys adalah library pihak ketiga yang berkomunikasi melalui protokol WhatsApp Web, bukan API resmi WhatsApp. Penggunaan automation dapat melanggar ketentuan WhatsApp dan menyebabkan sesi/nomor dibatasi atau diblokir. Implementasikan hanya untuk penggunaan yang diizinkan dan percakapan yang diharapkan; tidak ada fitur blast/bulk, scraping, pengelolaan grup, atau auto-reply grup di fondasi ini.

Paket npm dipin ke `baileys@7.0.0-rc14`, mengikuti nama package pada metadata upstream rilis tersebut (halaman install wiki dapat tertinggal dengan nama scoped lama). Baileys 7 masih release candidate dan membutuhkan Node 20+. Periksa dokumentasi/advisory upstream sebelum upgrade.
