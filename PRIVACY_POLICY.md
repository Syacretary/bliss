# Kebijakan Privasi Bliss

**Status: draf untuk ditinjau sebelum dipublikasikan.** Lengkapi identitas pengendali/pengelola, kanal hak subjek data, kontak, dan tanggal berlaku. Draf ini merangkum perilaku rilis yang ditinjau dan bukan nasihat hukum. Periksa kembali setiap kali alur data atau dependency berubah.

**Berlaku mulai:** [tanggal berlaku]<br>
**Pengendali/pengelola:** [nama/entitas hukum pengelola Bliss]<br>
**Kontak privasi:** [email atau kanal untuk permintaan privasi]

## Ringkasan yang penting

Bliss dirancang untuk berjalan secara lokal di perangkat Android Anda. Pada rilis saat ini Bliss tidak mengoperasikan akun cloud, server pusat, database jarak jauh, iklan, atau SDK analytics yang mengirim log penggunaan kepada pengembang. Pengembang tidak menerima isi chat, nomor WhatsApp, sesi tertaut, API key, atau dokumen bisnis melalui server Bliss.

Namun Bliss bukan sistem yang sepenuhnya offline. WhatsApp/Meta memproses data saat Anda menghubungkan dan menggunakan WhatsApp. Jika Anda secara sadar mengaktifkan pemrosesan eksternal dan memilih provider AI, Bliss mengirim pesan dan konteks relevan ke provider itu untuk menghasilkan jawaban. Google Fonts juga dapat mengambil berkas font dari jaringan. Jadi, pernyataan yang akurat adalah “Bliss tidak mengumpulkan dan mengirim data Anda ke server pengembang pada rilis ini”—bukan “tidak ada data yang pernah meninggalkan perangkat.”

## 1. Data yang diproses Bliss

Data yang Anda pilih untuk masukkan atau hasilkan melalui aplikasi dapat meliputi:

- **Profil dan konfigurasi bot:** nama/jenis usaha, jam operasional, gaya balasan, pengaturan provider/model, dan instruksi bot.
- **Pengetahuan bisnis:** teks, FAQ, dokumen, atau teks yang diekstrak dari PDF/DOCX/gambar. Ekstraksi dan OCR dilakukan di perangkat; konten yang diekstrak disimpan sebagai pengetahuan lokal. Berkas sumber tetap berada di lokasi asal yang Anda pilih.
- **Kredensial provider AI:** API key yang Anda masukkan untuk provider pilihan. Kredensial disimpan lokal dalam penyimpanan terenkripsi; jangan membagikan key atau perangkat yang tidak terlindungi.
- **Kredensial sesi WhatsApp:** data sesi/perangkat tertaut yang diperlukan agar bot tetap terhubung.
- **Percakapan dan log:** bila logging percakapan aktif (default saat ini), pesan masuk dan jawaban bot dapat disimpan lokal untuk dashboard dan metrik. Retensi default 30 hari, dibatasi oleh konfigurasi runtime. Logging dapat dinonaktifkan melalui konfigurasi runtime; seluruh riwayat dapat dihapus melalui endpoint runtime `DELETE /v1/conversations`. Kontrol untuk kedua tindakan ini belum tersedia langsung di UI dashboard saat ini; pengguna teknis dapat memakai API runtime lokal, atau menghapus data aplikasi Android untuk menghapus salinan lokal.
- **Diagnostik teknis:** status runtime, provider/model, status ketersediaan kredensial, keberhasilan/waktu permintaan, dan pesan kesalahan yang disanitasi. Implementasi log berupaya tidak mencatat API key, header otorisasi, nomor/JID, atau isi pesan.

Penyimpanan lokal terenkripsi saat tersimpan pada perangkat Android yang didukung. Ini mengurangi risiko akses langsung ke berkas, tetapi bukan jaminan keamanan mutlak dan bukan enkripsi ujung-ke-ujung untuk semua proses. Data dapat terpapar bila perangkat, sistem operasi, aksesibilitas, atau cadangan perangkat dikompromikan.

## 2. Kapan data meninggalkan perangkat

| Penerima | Kapan dan data apa | Tujuan |
| --- | --- | --- |
| **WhatsApp/Meta** | Saat Anda memindai QR/memasukkan kode dan menjalankan bot: data akun/perangkat tertaut, koneksi, serta pesan yang diperlukan untuk layanan WhatsApp. | Menghubungkan akun dan mengirim/menerima pesan. Pemrosesan WhatsApp tunduk pada [Kebijakan Privasi WhatsApp](https://www.whatsapp.com/legal/privacy-policy). |
| **Provider AI yang Anda pilih** (mis. OpenAI, Google Gemini, Anthropic, DeepSeek, atau Groq) | Hanya jika Anda mengaktifkan izin pemrosesan eksternal dan menggunakan provider remote: pesan terbaru, konteks percakapan yang diperlukan, profil inti bisnis, serta potongan pengetahuan relevan. API key digunakan untuk mengautentikasi permintaan ke provider tersebut. | Membuat balasan AI. Provider memproses data sesuai kebijakan, konfigurasi, dan syaratnya sendiri; retensi, lokasi pemrosesan, dan penggunaan untuk pelatihan dapat berbeda. Tinjau kebijakan provider sebelum mengaktifkan fitur. |
| **Google Fonts** | Aplikasi menggunakan Google Fonts; bila font belum tersedia di cache/perangkat, berkas font dapat diminta melalui jaringan. Permintaan aset dapat mengungkap metadata koneksi biasa seperti alamat IP kepada penyedia aset. | Menampilkan tipografi. Isi percakapan, API key, dan dokumen bisnis tidak dimasukkan dalam permintaan font. |
| **Android dan layanan sistem** | Sistem operasi dapat memproses data teknis yang diperlukan untuk menjalankan aplikasi, izin, penyimpanan, keyboard, dan jaringan. | Menyediakan fungsi perangkat. Lihat kebijakan privasi penyedia sistem/perangkat Anda. |

Bliss tidak mengirimkan otomatis seluruh arsip percakapan atau semua dokumen kepada provider AI. Konteks yang relevan dipilih untuk permintaan balasan. Sebelum menyalakan pemrosesan eksternal, pastikan UI menunjukkan provider yang dipilih dan persetujuan Anda. Jika persetujuan eksternal mati, provider remote tidak boleh menerima isi percakapan melalui alur balasan Bliss. Provider lokal tidak melakukan panggilan AI jarak jauh.

Provider dapat berada di luar Indonesia. Jika Anda mengelola data pelanggan, Anda bertanggung jawab memberi pemberitahuan, menentukan dasar pemrosesan dan transfer lintas negara yang sesuai, serta tidak mengirim data sensitif tanpa penilaian yang tepat. Pengelola Bliss tidak dapat mengendalikan retensi atau penggunaan data oleh WhatsApp, provider AI, Google, atau penyedia perangkat.

## 3. Dasar dan tujuan penggunaan

Bliss memproses data lokal untuk menjalankan bot, menerapkan preferensi dan pengetahuan bisnis Anda, menampilkan percakapan/statistik, menjaga koneksi, serta mendiagnosis kegagalan. Pengiriman ke provider AI eksternal bergantung pada persetujuan eksplisit yang diaktifkan di aplikasi. WhatsApp dan provider pihak ketiga memproses data berdasarkan hubungan dan ketentuan mereka sendiri.

Jangan masukkan data pribadi pelanggan yang tidak diperlukan. Sebagai pemilik bisnis, Anda bertanggung jawab atas pemberitahuan privasi kepada pelanggan, dasar pemrosesan, izin/consent yang diwajibkan, pemenuhan permintaan pelanggan, dan konten balasan bot.

## 4. Retensi dan penghapusan

Konfigurasi lokal, kredensial, sesi, dan pengetahuan disimpan sampai Anda menghapusnya atau menghapus data aplikasi. Log percakapan default memiliki retensi 30 hari (konfigurasi runtime membatasi retensi antara 1 dan 365 hari) serta batas kapasitas lokal. Pada versi saat ini, logging dapat dinonaktifkan lewat konfigurasi runtime dan seluruh log dihapus melalui `DELETE /v1/conversations`; belum ada kontrol langsung untuk keduanya pada UI dashboard. Alternatif penghapusan lokal adalah menghapus data aplikasi Android. Menghapus data aplikasi atau uninstall tidak menghapus salinan yang mungkin sudah diproses WhatsApp/provider, ekspor atau cadangan sistem, maupun salinan di perangkat penerima.

Untuk memutus koneksi, hentikan bot dan hapus perangkat tertaut dari menu WhatsApp pada ponsel utama Anda. Untuk mencabut akses provider, hapus atau cabut API key dari akun provider terkait. Pengelola Bliss tidak dapat menghapus data dari sistem pihak ketiga atas nama Anda.

## 5. Keamanan

Bliss menggunakan penyimpanan terenkripsi lokal untuk data sensitif pada platform yang didukung dan membatasi diagnostik agar tidak mencatat rahasia atau isi pesan. Tidak ada metode penyimpanan atau transmisi yang bebas risiko. Lindungi perangkat dengan kunci layar, jangan melakukan sideload build dari sumber tak tepercaya, jaga API key, dan pertimbangkan risiko backup perangkat.

## 6. Hak dan pilihan Anda

Anda dapat memilih provider, menonaktifkan pemrosesan eksternal, meninjau/mengubah konfigurasi, menghentikan bot, menghapus log lokal, atau menghapus data aplikasi. Untuk permintaan akses, koreksi, penghapusan, keberatan, atau pertanyaan terkait data yang diproses langsung oleh pengelola Bliss, hubungi **[kontak privasi]**. Hak subjek data tunduk pada hukum yang berlaku, termasuk Undang-Undang Nomor 27 Tahun 2022 tentang Pelindungan Data Pribadi. Permintaan untuk data yang dipegang WhatsApp/provider harus diajukan kepada pihak tersebut.

## 7. Anak-anak

Bliss ditujukan untuk pengelolaan komunikasi bisnis oleh orang dewasa, bukan untuk anak-anak. Jangan gunakan Bliss untuk mengumpulkan atau memproses data anak tanpa dasar, pemberitahuan, dan perlindungan yang diwajibkan hukum.

## 8. Perubahan kebijakan

Kebijakan dapat berubah jika fitur, provider, dependency, atau hukum berubah. Versi terbaru, tanggal berlaku, dan ringkasan perubahan akan dipublikasikan pada kanal resmi Bliss. Jika ada perubahan material pada pihak penerima atau jenis data eksternal, pengguna perlu diberi penjelasan sebelum fitur terkait digunakan.

## 9. Hubungi pengelola

Pertanyaan privasi atau permintaan hak subjek data: **[email/kontak privasi resmi pengelola Bliss]**. Jangan kirim API key atau isi chat sensitif melalui email dukungan.

## Referensi utama

- [Ketentuan Layanan WhatsApp](https://www.whatsapp.com/legal/terms-of-service)
- [Kebijakan Privasi WhatsApp](https://www.whatsapp.com/legal/privacy-policy)
- [Undang-Undang Republik Indonesia Nomor 27 Tahun 2022 tentang Pelindungan Data Pribadi](https://peraturan.bpk.go.id/Details/229798/uu-no-27-)
