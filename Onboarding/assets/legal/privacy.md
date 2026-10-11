# Kebijakan Privasi Bliss

Pengelola aplikasi: Syacretary, pengembang Bliss. Untuk pertanyaan atau permintaan privasi terkait Bliss, hubungi pengembang melalui kanal resmi tempat Anda memperoleh Bliss. Kebijakan ini mengikuti versi aplikasi yang Anda gunakan.

## Ringkasan penting

Bliss dirancang untuk berjalan secara lokal di perangkat Android Anda. Pada rilis saat ini Bliss tidak mengoperasikan akun cloud, server pusat, database jarak jauh, iklan, atau SDK analytics yang mengirim log penggunaan kepada pengembang. Pengembang tidak menerima isi chat, nomor WhatsApp, sesi tertaut, API key, atau dokumen bisnis melalui server Bliss.

Namun Bliss bukan sistem yang sepenuhnya offline. WhatsApp/Meta memproses data saat Anda menghubungkan dan menggunakan WhatsApp. Jika Anda secara sadar mengaktifkan pemrosesan eksternal dan memilih provider AI, Bliss mengirim pesan dan konteks relevan ke provider itu untuk menghasilkan jawaban. Google Fonts juga dapat mengambil berkas font dari jaringan. Jadi, pernyataan yang akurat adalah “Bliss tidak mengumpulkan dan mengirim data Anda ke server pengembang pada rilis ini”—bukan “tidak ada data yang pernah meninggalkan perangkat.”

## 1. Data yang diproses Bliss

- **Profil dan konfigurasi bot:** nama/jenis usaha, jam operasional, gaya balasan, pengaturan provider/model, dan instruksi bot.
- **Pengetahuan bisnis:** teks, FAQ, dokumen, atau teks yang diekstrak dari PDF/DOCX/gambar. Ekstraksi dan OCR dilakukan di perangkat; konten yang diekstrak disimpan sebagai pengetahuan lokal. Berkas sumber tetap berada di lokasi asal yang Anda pilih.
- **Kredensial provider AI:** API key provider pilihan. Kredensial disimpan lokal dalam penyimpanan terenkripsi.
- **Kredensial sesi WhatsApp:** data sesi/perangkat tertaut yang diperlukan agar bot tetap terhubung.
- **Percakapan dan log:** bila logging aktif (default saat ini), pesan masuk dan jawaban bot disimpan lokal untuk dashboard dan metrik. Retensi default 30 hari. Logging dapat dinonaktifkan melalui konfigurasi runtime; riwayat dapat dihapus melalui endpoint runtime `DELETE /v1/conversations`. Kontrol kedua tindakan ini belum tersedia langsung di UI dashboard saat ini; alternatif penghapusan lokal adalah menghapus data aplikasi Android.
- **Diagnostik teknis:** status runtime, provider/model, status ketersediaan kredensial, keberhasilan/waktu permintaan, dan pesan kesalahan yang disanitasi. Implementasi log berupaya tidak mencatat API key, header otorisasi, nomor/JID, atau isi pesan.

Penyimpanan lokal terenkripsi saat tersimpan pada perangkat Android yang didukung. Ini mengurangi risiko akses langsung ke berkas, tetapi bukan jaminan keamanan mutlak dan bukan enkripsi ujung-ke-ujung untuk semua proses. Data dapat terpapar bila perangkat, sistem operasi, aksesibilitas, atau cadangan perangkat dikompromikan.

## 2. Kapan data meninggalkan perangkat

| Penerima | Kapan dan data apa | Tujuan |
| --- | --- | --- |
| **WhatsApp/Meta** | Saat menautkan dan menjalankan bot: data akun/perangkat tertaut, koneksi, serta pesan yang diperlukan untuk layanan WhatsApp. | Menghubungkan akun dan mengirim/menerima pesan. Lihat Kebijakan Privasi WhatsApp. |
| **Provider AI pilihan** (mis. OpenAI, Google Gemini, Anthropic, DeepSeek, Groq) | Hanya jika Anda mengaktifkan pemrosesan eksternal dan menggunakan provider remote: pesan terbaru, konteks percakapan yang diperlukan, profil inti bisnis, serta potongan pengetahuan relevan. API key mengautentikasi permintaan. | Membuat balasan AI. Retensi, lokasi pemrosesan, dan penggunaan untuk pelatihan berbeda-beda; tinjau kebijakan provider. |
| **Google Fonts** | Bila font belum tersedia di cache/perangkat, berkas font dapat diminta melalui jaringan. Permintaan aset dapat mengungkap metadata koneksi biasa seperti alamat IP. | Menampilkan tipografi. Isi percakapan, API key, dan dokumen bisnis tidak dimasukkan dalam permintaan font. |
| **Android dan layanan sistem** | Sistem operasi dapat memproses data teknis yang diperlukan untuk menjalankan aplikasi, izin, penyimpanan, keyboard, dan jaringan. | Menyediakan fungsi perangkat. |

Bliss tidak mengirimkan otomatis seluruh arsip percakapan atau semua dokumen kepada provider AI. Konteks relevan dipilih untuk permintaan balasan. Jika persetujuan eksternal mati, provider remote tidak boleh menerima isi percakapan melalui alur balasan Bliss. Provider lokal tidak melakukan panggilan AI jarak jauh.

Provider dapat berada di luar Indonesia. Jika Anda mengelola data pelanggan, Anda bertanggung jawab memberi pemberitahuan, menentukan dasar pemrosesan dan transfer lintas negara yang sesuai, serta tidak mengirim data sensitif tanpa penilaian yang tepat. Pengelola Bliss tidak dapat mengendalikan retensi atau penggunaan data oleh WhatsApp, provider AI, Google, atau penyedia perangkat.

## 3. Tujuan penggunaan

Bliss memproses data lokal untuk menjalankan bot, menerapkan preferensi dan pengetahuan bisnis, menampilkan percakapan/statistik, menjaga koneksi, serta mendiagnosis kegagalan. Pengiriman ke provider AI eksternal bergantung pada persetujuan eksplisit yang diaktifkan di aplikasi. WhatsApp dan provider pihak ketiga memproses data berdasarkan hubungan dan ketentuan mereka sendiri.

Jangan masukkan data pribadi pelanggan yang tidak diperlukan. Sebagai pemilik bisnis, Anda bertanggung jawab atas pemberitahuan privasi kepada pelanggan, dasar pemrosesan, izin/consent yang diwajibkan, pemenuhan permintaan pelanggan, dan konten balasan bot.

## 4. Retensi, penghapusan, dan pemutusan

Konfigurasi lokal, kredensial, sesi, dan pengetahuan disimpan sampai Anda menghapusnya atau menghapus data aplikasi. Log percakapan default memiliki retensi 30 hari (konfigurasi runtime membatasi retensi 1–365 hari) serta batas kapasitas lokal. Saat ini logging dapat dinonaktifkan lewat konfigurasi runtime dan seluruh log dihapus melalui `DELETE /v1/conversations`; kontrol langsung di UI dashboard belum tersedia. Menghapus data aplikasi atau uninstall tidak menghapus salinan yang mungkin sudah diproses WhatsApp/provider, ekspor/cadangan sistem, maupun salinan di perangkat penerima.

Untuk memutus koneksi, hentikan bot dan hapus perangkat tertaut dari menu WhatsApp pada ponsel utama Anda. Untuk mencabut akses provider, hapus atau cabut API key dari akun provider terkait. Pengelola Bliss tidak dapat menghapus data dari sistem pihak ketiga atas nama Anda.

## 5. Keamanan

Bliss menggunakan penyimpanan terenkripsi lokal untuk data sensitif pada platform yang didukung dan membatasi diagnostik agar tidak mencatat rahasia atau isi pesan. Tidak ada metode penyimpanan atau transmisi yang bebas risiko. Lindungi perangkat dengan kunci layar, jangan melakukan sideload build dari sumber tak tepercaya, jaga API key, dan pertimbangkan risiko backup perangkat.

## 6. Hak dan pilihan Anda

Anda dapat memilih provider, menonaktifkan pemrosesan eksternal, meninjau/mengubah konfigurasi, menghentikan bot, menghapus log lokal, atau menghapus data aplikasi. Untuk permintaan akses, koreksi, penghapusan, keberatan, atau pertanyaan terkait data yang diproses langsung oleh pengelola Bliss, hubungi [kontak privasi]. Hak subjek data tunduk pada hukum yang berlaku, termasuk Undang-Undang Nomor 27 Tahun 2022 tentang Pelindungan Data Pribadi. Permintaan untuk data yang dipegang WhatsApp/provider harus diajukan kepada pihak tersebut.

## 7. Anak-anak

Bliss ditujukan untuk pengelolaan komunikasi bisnis oleh orang dewasa, bukan untuk anak-anak. Jangan gunakan Bliss untuk mengumpulkan atau memproses data anak tanpa dasar, pemberitahuan, dan perlindungan yang diwajibkan hukum.

## 8. Perubahan dan kontak

Kebijakan dapat berubah jika fitur, provider, dependency, atau hukum berubah. Versi terbaru dan ringkasan perubahan akan dipublikasikan pada kanal resmi Bliss. Jangan kirim API key atau isi chat sensitif saat menghubungi dukungan.

## Referensi utama

- Ketentuan Layanan WhatsApp: https://www.whatsapp.com/legal/terms-of-service
- Kebijakan Privasi WhatsApp: https://www.whatsapp.com/legal/privacy-policy
- UU RI Nomor 27 Tahun 2022 tentang Pelindungan Data Pribadi: https://peraturan.bpk.go.id/Details/229798/uu-no-27-
