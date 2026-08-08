# PLAN PENGEMBANGAN APLIKASI POS (Point of Sale) — Flutter

> Dokumen ini dirancang agar bisa langsung dipakai sebagai **prompt/spec** untuk AI code generator (Claude Code, Cursor, dsb) supaya bisa men-generate project Flutter secara terstruktur, bertahap, dan konsisten.

---

## 1. Ringkasan Proyek

| Item | Detail |
|---|---|
| Nama Aplikasi | POS App (Restaurant / F&B) |
| Platform Utama | Tablet / iPad (landscape-first) |
| Platform Sekunder | Mobile phone (responsive, portrait) |
| Framework | Flutter (stable channel terbaru) |
| Target OS | Android, iOS |
| Printer | Thermal printer merk **iWare** (ESC/POS command, koneksi Bluetooth/USB) |
| Desain | Modern UI, clean, flat/minimal shadow, rounded corner |
| Mode Kerja (scope saat ini) | **Online saja** — semua aksi langsung ke API, tanpa antrian offline |
| Mode Kerja (fase lanjutan, belum dikerjakan) | Offline-first + sync via endpoint `/sync` (lihat Bagian 11, Fase 6) |
| Backend API | `https://shadja.codingajaindonesia.my.id` (lihat Bagian 6) |

> **Catatan scope:** Untuk tahap pengembangan saat ini, aplikasi dibangun **mode online saja**. Semua request (login, ambil menu, buat order, bayar, reservasi) langsung memanggil API dan menampilkan loading/error state seperti biasa — belum ada local database, antrian aksi pending, atau logic sync. Dukungan offline dirancang sebagai **fase lanjutan terpisah** (lihat Fase 6) supaya arsitektur awal tetap simpel dan cepat selesai.

### Tujuan
1. Kasir bisa input pesanan dengan cepat (grid menu ala POS kasir restoran).
2. Layout **utama tablet (landscape)**: panel menu di kiri/tengah, panel keranjang (cart) tetap terlihat di kanan.
3. Saat dibuka di HP (mobile), layout otomatis menyesuaikan (cart jadi bottom sheet / halaman terpisah).
4. Bisa cetak struk ke printer thermal iWare via Bluetooth.
5. (Fase lanjutan) Tetap bisa transaksi saat koneksi internet terputus, lalu sinkron otomatis saat online.

---

## 2. Tech Stack

| Layer | Pilihan | Alasan |
|---|---|---|
| State Management | **Riverpod** (`flutter_riverpod` + `riverpod_generator`) | Scalable, testable, cocok untuk arsitektur besar |
| Routing | **go_router** | Mendukung nested route & adaptive layout |
| Networking | **dio** | Interceptor untuk token, retry, logging |
| Local DB (offline) | *(Fase lanjutan, belum dipakai)* **Drift (SQLite)** atau **Isar** | Nanti untuk menyimpan order offline & antrian sync — tidak dibangun di scope online-only saat ini |
| Secure Storage | **flutter_secure_storage** | Simpan token auth (satu-satunya data yang persist di device untuk scope saat ini) |
| Printer Thermal | **esc_pos_utils_plus** + **print_bluetooth_thermal** (atau **flutter_pos_printer_platform** untuk Bluetooth/USB/Network) | Standar ESC/POS, kompatibel dengan printer iWare (umumnya ESC/POS compliant) |
| Responsive Layout | **flutter_screenutil** (opsional) + custom `Breakpoints` helper | Adaptive UI tablet/mobile |
| Icon & Font | **lucide_icons** / **Material Symbols**, Google Fonts (`Inter` / `Plus Jakarta Sans`) | Tampilan modern |
| Image caching | **cached_network_image** | Untuk gambar menu |
| Format angka & tanggal | **intl** | Format Rupiah, tanggal |
| Testing | **flutter_test**, **mocktail** | Unit & widget test |
| CI/CD (opsional) | **Codemagic** / **GitHub Actions** | Build otomatis iOS & Android |

---

## 3. Arsitektur Project

Gunakan **Clean Architecture** ringan (feature-first), supaya AI generator bisa membuat modul per fitur secara terpisah tanpa saling tabrak.

> Struktur di bawah adalah untuk **scope online-only saat ini**. Folder `core/sync/` dan `local_db` **belum dibuat** — baru ditambahkan nanti saat masuk Fase 6 (lihat Bagian 11).

```
lib/
 ├─ main.dart
 ├─ app.dart                        # MaterialApp.router, theme, locale
 │
 ├─ core/
 │   ├─ constants/                  # api_endpoints.dart, app_colors.dart, app_text_styles.dart
 │   ├─ theme/                      # app_theme.dart (light/dark), design tokens
 │   ├─ network/                    # dio_client.dart, interceptors, api_result.dart
 │   ├─ storage/                    # token_storage.dart (secure storage token saja)
 │   ├─ routing/                    # app_router.dart (go_router)
 │   ├─ responsive/                 # breakpoints.dart, responsive_layout.dart
 │   ├─ printer/                    # printer_service.dart, receipt_formatter.dart
 │   ├─ sync/                       # ⏳ belum dibuat — fase lanjutan (offline queue)
 │   └─ utils/                      # formatters, validators, extensions
 │
 ├─ features/
 │   ├─ auth/
 │   │   ├─ data/                   # auth_repository_impl.dart, auth_api.dart, models
 │   │   ├─ domain/                 # entities, repository interface, usecases
 │   │   └─ presentation/           # login_page.dart, register_page.dart, providers, widgets
 │   │
 │   ├─ menu/
 │   │   ├─ data/                   # menu_repository_impl.dart, menu_api.dart, menu_model.dart
 │   │   ├─ domain/
 │   │   └─ presentation/           # menu_page.dart (grid), widgets (menu_card, category_tab)
 │   │
 │   ├─ cart/                       # state keranjang belanja (lokal, live)
 │   │   ├─ domain/
 │   │   └─ presentation/           # cart_panel.dart, cart_item_tile.dart, cart_summary.dart
 │   │
 │   ├─ order/
 │   │   ├─ data/                   # order_repository_impl.dart, order_api.dart, models
 │   │   ├─ domain/
 │   │   └─ presentation/           # checkout_page.dart, order_history_page.dart, order_detail_page.dart
 │   │
 │   ├─ payment/
 │   │   ├─ data/
 │   │   ├─ domain/
 │   │   └─ presentation/           # payment_method_sheet.dart, payment_success_page.dart
 │   │
 │   ├─ reservation/
 │   │   ├─ data/
 │   │   ├─ domain/
 │   │   └─ presentation/           # reservation_list_page.dart, reservation_form_page.dart
 │   │
 │   ├─ printer_settings/
 │   │   └─ presentation/           # printer_scan_page.dart, printer_settings_page.dart
 │   │
 │   └─ profile/
 │       └─ presentation/           # profile_page.dart
 │
 └─ shared/
     └─ widgets/                    # app_button.dart, app_text_field.dart, empty_state.dart, loading.dart
```

---

## 4. Strategi Responsive (Tablet-first)

### Breakpoint
```dart
class Breakpoints {
  static const double mobile = 600;   // < 600  -> mobile layout
  static const double tablet = 1024;  // 600–1024 -> tablet portrait / small tablet
  // >= 1024 -> tablet landscape / desktop-like layout (default utama)
}
```

### Aturan Layout
- **Tablet landscape (≥1024px, default)**
  - 2 kolom tetap: **Menu Grid (kiri, ~65%)** + **Cart Panel (kanan, ~35%, sticky/fixed)**.
  - Category tab horizontal di atas grid menu.
  - Tombol checkout selalu terlihat di bawah cart panel.
- **Tablet portrait / mobile besar (600–1024px)**
  - Menu grid full width, cart bisa jadi **draggable bottom sheet** (collapsed jadi bar kecil "🛒 3 item • Rp75.000").
- **Mobile phone (<600px)**
  - Menu grid 2 kolom.
  - Cart terpisah jadi halaman sendiri, diakses lewat floating cart bar di bawah layar.
  - Bottom navigation untuk: Menu, Order, Reservasi, Profil.

Gunakan widget `ResponsiveLayout` yang menerima 3 builder: `mobile`, `tablet`, `tabletLandscape` — pakai `LayoutBuilder` + `MediaQuery.orientationOf`.

---

## 5. Desain UI (Modern)

### Prinsip Desain
- Gaya: **flat modern**, rounded corner (12–16px), soft shadow tipis, banyak whitespace.
- Warna dasar: netral (putih/abu terang) + 1 warna aksen kuat (misal orange/emerald) untuk CTA & status.
- Tipografi: `Plus Jakarta Sans` atau `Inter` — heading semi-bold, body regular.
- Komponen kartu menu: gambar rounded di atas, nama + harga di bawah, badge kategori kecil.
- State kosong (empty cart, no orders) pakai ilustrasi sederhana + teks ringan.
- Gunakan skeleton loading (shimmer) saat fetch data, bukan spinner polos.
- Dark mode opsional (siapkan token warna dari awal walau default light).

### Design Tokens (contoh)
```dart
class AppColors {
  static const primary = Color(0xFF16A34A);   // hijau modern (bisa disesuaikan brand)
  static const background = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const danger = Color(0xFFDC2626);
  static const warning = Color(0xFFF59E0B);
  static const success = Color(0xFF16A34A);
}
```

---

## 6. Integrasi API

**Base URL:** `https://shadja.codingajaindonesia.my.id`
**Prefix:** `/api/v1`
**Auth:** Bearer Token (Laravel Sanctum-style token, didapat dari login/register, dikirim di header `Authorization: Bearer {token}`)
**Header wajib di semua request:** `Content-Type: application/json`, `Accept: application/json`

> Catatan: dokumentasi resmi mengatakan "Authenticating requests: API ini tidak diautentikasi" untuk section umum, namun hampir semua endpoint (Menu, Orders, Payments, Profile, Reservations, Sync) berlabel **"requires authentication"**. Artinya token harus tetap dikirim di header `Authorization: Bearer {token}` setelah login/register — perlakukan semua endpoint (kecuali register & login) sebagai **protected**.

### 6.1 Authentication

| Endpoint | Method | Body | Response Sukses |
|---|---|---|---|
| `/api/v1/auth/register` | POST | `name, email, password, password_confirmation, phone?` | 201 → `{ user, token }` |
| `/api/v1/auth/login` | POST | `email, password` | 200 → `{ user, token }` (401 jika salah) |
| `/api/v1/auth/logout` | POST | – (butuh token) | 200 → `{ message }` |

### 6.2 Menu

| Endpoint | Method | Deskripsi |
|---|---|---|
| `/api/v1/menu` | GET | List semua kategori beserta item menunya |
| `/api/v1/menu/{menuItem_id}` | GET | Detail 1 item menu + kategori |

Struktur respons list menu:
```json
[
  {
    "id": 1,
    "name": "Makanan",
    "menu_items": [
      { "id": 1, "name": "Nasi Goreng", "price": 25000, "image": null, "description": "...", "is_active": true }
    ]
  }
]
```

### 6.3 Orders

| Endpoint | Method | Deskripsi |
|---|---|---|
| `/api/v1/orders` | POST | Buat order baru |
| `/api/v1/orders` | GET | List semua order |
| `/api/v1/orders/{order_id}` | GET | Detail 1 order |

Body `POST /orders`:
```json
{
  "order_type": "delivery",        // atau "pickup" / "dine_in" (cek variasi di app, sesuaikan enum)
  "items": [
    { "menu_item_id": 1, "quantity": 2, "notes": "pedas" }
  ],
  "notes": "opsional",
  "delivery_address": "wajib jika order_type=delivery",
  "customer_name": "John Doe",
  "customer_phone": "08123456789",
  "discount": 5000
}
```
Response order berisi: `order_number, order_status, subtotal, discount, tax, total, order_items[], payments[]`.

> **order_status** yang teramati: `baru` (kemungkinan ada status lanjutan seperti `diproses`, `selesai`, `dibatalkan` — koordinasikan dengan backend/tambahkan enum saat testing nyata).

#### ⚠️ Rekomendasi penting: snapshot data di `order_items`

Saat ini contoh response `order_items` hanya menyertakan `menu_item_id, quantity, price, subtotal` + objek `menu_item` (nama & harga **saat ini**, hasil join/relasi). Pola ini berisiko: **jika suatu saat nama atau harga menu diubah di master data, riwayat order lama ikut berubah tampilannya** (karena `menu_item.name`/`menu_item.price` yang ditampilkan adalah data terkini, bukan data saat transaksi terjadi).

**Rekomendasi (idealnya diterapkan di backend, tapi juga diantisipasi di sisi Flutter):**
- Tabel `order_items` sebaiknya **menyimpan salinan (snapshot)** dari data produk pada saat order dibuat, minimal:
  - `item_name` — nama menu saat transaksi
  - `item_price` — harga satuan saat transaksi (sebelum diskon)
  - `item_discount` — diskon per item (jika ada diskon di level item, bukan cuma diskon di level order)
  - `subtotal` — tetap dihitung dari `price`, `discount`, `quantity` saat itu
  - `menu_item_id` tetap disimpan sebagai referensi (untuk laporan/analitik), tapi **bukan** sumber tampilan nama/harga di struk & riwayat order.
- Dengan begitu, struk dan riwayat order selalu akurat sesuai kondisi saat transaksi, walau produk aslinya sudah diubah/dihapus dari menu.
- **Di sisi Flutter**, `OrderItemModel` (Bagian 7) sudah dirancang mengikuti pola ini: field `menuItemName` dan `price` diambil langsung dari objek item di response order (bukan fetch ulang ke `/menu/{id}`), sehingga selama backend menerapkan snapshot di atas, data yang tampil di app otomatis konsisten.
- Saat submit `POST /orders`, Flutter tetap mengirim `menu_item_id` + `quantity` (+`notes`) sesuai kontrak API saat ini — harga diambil/dihitung di sisi server pada saat itu juga (server-side pricing), lalu snapshot itulah yang disimpan backend ke `order_items`.
- **Aksi tindak lanjut:** koordinasikan ke tim backend agar kolom snapshot (`item_name`, `item_price`, `item_discount`) ditambahkan ke tabel `order_items` bila belum ada — ini sudah dicatat juga di Bagian 13 (Catatan ke Backend).

### 6.4 Payments

| Endpoint | Method | Deskripsi |
|---|---|---|
| `/api/v1/payments/callback` | POST | Submit pembayaran untuk sebuah order |
| `/api/v1/payments/{payment_id}` | GET | Detail pembayaran |

Body:
```json
{ "order_id": 1, "method": "qris", "amount": 55500, "reference": "opsional" }
```
`method` yang didukung: `cash`, `qris`, `transfer`, `card`.

### 6.5 Profile

| Endpoint | Method | Deskripsi |
|---|---|---|
| `/api/v1/profile` | GET | Data user login saat ini |

### 6.6 Reservations

| Endpoint | Method | Deskripsi |
|---|---|---|
| `/api/v1/reservations` | GET | List reservasi |
| `/api/v1/reservations` | POST | Buat reservasi meja |
| `/api/v1/reservations/{id}` | GET | Detail reservasi |

Body create:
```json
{ "restaurant_table_id": 1, "reservation_time": "2026-01-15 19:00:00", "guest_count": 4, "notes": "opsional" }
```

### 6.7 Sync (Offline-first)

| Endpoint | Method | Deskripsi |
|---|---|---|
| `/api/v1/sync` | POST | Kirim batch aksi offline (order/reservasi) untuk disinkronkan |

Body:
```json
{
  "actions": [
    {
      "idempotency_key": "uuid-unik-per-aksi",
      "action_type": "order",
      "payload": { "...": "sesuai body create order/reservation" }
    }
  ],
  "device_id": "id-unik-device"
}
```
Response: `{ "results": [ { "idempotency_key": "...", "status": "synced", "resource_id": 1 } ] }`

**Strategi implementasi offline:**
1. Semua aksi transaksi (create order, create reservation) pertama-tama disimpan ke tabel lokal `pending_actions` dengan `idempotency_key` (gunakan `uuid` package) + status `pending`.
2. UI langsung update optimis (order muncul dengan badge "Menunggu sinkron").
3. `SyncService` berjalan: saat online (cek konektivitas via `connectivity_plus`) atau saat app resume, ambil semua `pending_actions`, kirim batch ke `/sync`.
4. Setelah response sukses, update status lokal jadi `synced` + simpan `resource_id` asli dari server.
5. Retry dengan backoff jika gagal; tampilkan indikator jumlah antrian belum sync di AppBar.

---

## 7. Model Data (Dart) — Ringkasan

Buat via `freezed` + `json_serializable` agar konsisten:

- `UserModel` (id, name, email, phone, role)
- `AuthResponseModel` (user, token)
- `MenuCategoryModel` (id, name, menuItems[])
- `MenuItemModel` (id, name, price, image, description, isActive, category?)
- `OrderModel` (id, orderNumber, orderType, orderStatus, subtotal, discount, tax, total, customerName, customerPhone, deliveryAddress, orderItems[], payments[])
- `OrderItemModel` (id, menuItemId, **menuItemName** ← snapshot nama, **price** ← snapshot harga satuan, quantity, **itemDiscount** *(opsional, jika backend sudah dukung)*, subtotal, notes)
  - Field nama & harga **diambil dari data item di dalam response order itu sendiri** (snapshot saat transaksi), **bukan** dengan fetch ulang ke `/menu/{menuItemId}` — supaya riwayat order & struk tetap akurat meski data menu di master berubah kemudian.
- `PaymentModel` (id, orderId, method, amount, status, reference)
- `ReservationModel` (id, restaurantTableId, reservationTime, guestCount, status, notes, restaurantTable)
- `RestaurantTableModel` (id, tableNumber, capacity)
- `PendingActionModel` (idempotencyKey, actionType, payload, status, createdAt) — **lokal only**, untuk offline queue
- `CartItemModel` (menuItem, quantity, notes) — **lokal only**, state keranjang sebelum jadi order

---

## 8. Integrasi Printer Thermal (iWare)

### Karakteristik
- Printer thermal iWare umumnya kompatibel **ESC/POS** dan terhubung via **Bluetooth (SPP)**, sebagian model juga USB/Network.
- Gunakan pendekatan generik ESC/POS supaya tetap kompatibel walau ganti merk printer di kemudian hari.

### Rencana Implementasi
1. **Pairing & Scan**: Halaman `printer_scan_page.dart` — scan device Bluetooth di sekitar (`print_bluetooth_thermal` atau `flutter_bluetooth_serial`), tampilkan list device, simpan MAC address terpilih ke local storage.
2. **PrinterService** (`core/printer/printer_service.dart`):
   - `connect(String macAddress)`
   - `disconnect()`
   - `printReceipt(OrderModel order)`
   - `printTestPage()`
   - `isConnected` (stream/state)
3. **ReceiptFormatter** (`core/printer/receipt_formatter.dart`): membangun byte ESC/POS dari data order menggunakan `esc_pos_utils_plus`:
   - Header: nama toko, alamat, no. telp (dari config app, bisa disimpan di Settings).
   - No. order, tanggal/jam, tipe order (dine-in/delivery/pickup), nama customer.
   - List item: nama, qty, harga satuan, subtotal — rata kiri/kanan pakai `PosColumn`.
   - Subtotal, diskon, pajak, total — bold di baris total.
   - Metode pembayaran & status.
   - Footer: "Terima kasih" + QR code opsional (jika ada `reference` pembayaran QRIS).
   - Cut paper command di akhir.
4. **Auto print** opsional: setelah order sukses dibuat & pembayaran sukses, tampilkan dialog "Cetak struk?" dengan tombol cetak & lewati.
5. **Reprint**: dari halaman Order Detail / Order History, tombol "Cetak Ulang".
6. **Pengaturan printer**: halaman Settings menyimpan default printer, lebar kertas (58mm/80mm), auto-print on/off.
7. **Fallback**: jika printer tidak terhubung, tampilkan error jelas + tombol "Coba sambung ulang" — jangan blokir alur transaksi (order tetap tersimpan meski gagal cetak).

> Catatan: jika iWare menyediakan SDK resmi (native Android/iOS), evaluasi apakah perlu dibuat **Platform Channel** khusus. Jika printer merespons standar ESC/POS lewat Bluetooth SPP, pendekatan generik di atas sudah cukup dan lebih maintainable.

---

## 9. Daftar Fitur & Halaman

1. **Splash & Auth**
   - Splash (cek token tersimpan → auto-login)
   - Login
   - Register
   - Logout
2. **Dashboard / Home** (opsional ringkasan penjualan harian — bisa dihitung dari `/orders` di sisi client jika belum ada endpoint statistik)
3. **Menu / Kasir (halaman utama POS)**
   - Grid menu per kategori (tab kategori horizontal)
   - Search menu
   - Tambah ke cart (tap card / tombol +)
   - Cart panel (tablet: sidebar kanan tetap; mobile: bottom sheet/halaman)
   - Edit qty & catatan per item
   - Pilih tipe order: Dine-in / Pickup / Delivery
   - Input data customer (nama, no. telp, alamat jika delivery)
   - Input diskon
4. **Checkout & Pembayaran**
   - Ringkasan order (subtotal, diskon, pajak, total)
   - Pilih metode bayar: cash / qris / transfer / card
   - Konfirmasi pembayaran → panggil `/payments/callback`
   - Preview & cetak struk
5. **Riwayat Order**
   - List order (status badge: baru/diproses/selesai/dibatalkan)
   - Filter by status/tanggal
   - Detail order + reprint struk
6. **Reservasi**
   - List reservasi (status: pending/confirmed/dsb)
   - Form buat reservasi (pilih meja, waktu, jumlah tamu)
   - Detail reservasi
7. **Pengaturan Printer**
   - Scan & pair printer
   - Test print
   - Pilih ukuran kertas
8. **Profil**
   - Info user login
   - Logout

---

## 10. State Management — Pola Riverpod

- `authProvider` (StateNotifier/AsyncNotifier) — menyimpan `User?` & token.
- `menuProvider` (FutureProvider/AsyncNotifier) — fetch & cache menu.
- `cartProvider` (NotifierProvider) — CRUD item cart, hitung subtotal live.
- `orderProvider` / `orderHistoryProvider` — create & list order (dengan fallback offline).
- `paymentProvider` — proses pembayaran.
- `reservationProvider` — CRUD reservasi.
- `printerProvider` — status koneksi printer, device tersimpan.
- `syncQueueProvider` — jumlah antrian pending & trigger manual sync.
- `connectivityProvider` — status online/offline (dari `connectivity_plus`).

---

## 11. Tahapan Pengembangan (Milestone) — untuk dikerjakan bertahap oleh AI

### Fase 0 — Setup Project
- [ ] Init project Flutter, setup folder sesuai Bagian 3.
- [ ] Setup `pubspec.yaml` dengan semua dependency di Bagian 2.
- [ ] Setup tema (`app_theme.dart`), font, warna (Bagian 5).
- [ ] Setup `go_router` dengan shell route (bottom nav untuk mobile, side nav untuk tablet).
- [ ] Setup `dio_client.dart` dengan base URL + interceptor token + logging.
- [ ] Setup local DB (Drift/Isar) untuk cart offline & pending actions.

### Fase 1 — Autentikasi
- [ ] Model & repository Auth (register/login/logout).
- [ ] UI Login & Register (responsive, form validasi).
- [ ] Simpan token di secure storage, auto-attach ke header.
- [ ] Auto-login saat splash jika token valid.

### Fase 2 — Menu & Kasir (Core POS)
- [ ] Fetch & cache `/menu`, tampilkan grid + kategori tab.
- [ ] Implementasi `ResponsiveLayout` untuk halaman kasir (tablet 2-kolom vs mobile bottom sheet).
- [ ] `cartProvider` lengkap (add/remove/update qty/notes, hitung total).
- [ ] Search & filter menu.

### Fase 3 — Checkout, Order, Payment
- [ ] Form checkout (tipe order, data customer, diskon).
- [ ] Submit ke `/orders` (dengan fallback offline ke local queue bila gagal/offline).
- [ ] Halaman pilih metode bayar → submit `/payments/callback`.
- [ ] Halaman sukses transaksi + opsi cetak struk.
- [ ] Riwayat order + detail order.

### Fase 4 — Printer Thermal
- [ ] `PrinterService` + scan/pairing Bluetooth.
- [ ] `ReceiptFormatter` ESC/POS sesuai desain struk.
- [ ] Auto-print & reprint dari Order Detail/History.
- [ ] Halaman Pengaturan Printer.

### Fase 5 — Reservasi
- [ ] List, form create, detail reservasi.
- [ ] Integrasi dengan data meja (`restaurant_table`).

### Fase 6 — Offline & Sync ⏳ (Fase Lanjutan — tidak dikerjakan di scope saat ini)
> Scope pengembangan saat ini **berhenti di mode online**. Fase ini didokumentasikan agar arsitektur (folder `core/sync/`, local DB) mudah ditambahkan nanti tanpa merombak fitur online yang sudah jadi.
- [ ] `SyncService` (deteksi konektivitas, kirim batch ke `/sync`).
- [ ] Indikator antrian pending di UI.
- [ ] Retry/backoff, resolusi konflik dasar.

### Fase 7 — Polish
- [ ] Dark mode (opsional).
- [ ] Empty states, error states, skeleton loading di semua halaman.
- [ ] Animasi transisi halaman & micro-interaction tombol.
- [ ] Testing di ukuran layar berbeda (iPad, Android tablet, HP kecil).
- [ ] App icon, splash screen native, nama aplikasi.

### Fase 8 — Testing & Release
- [ ] Unit test repository & providers penting (cart calc, sync logic).
- [ ] Widget test halaman kasir (responsive breakpoints).
- [ ] Build release Android (apk/aab) & iOS (ipa).

---

## 12. Instruksi untuk AI Generator

Ketika memakai dokumen ini sebagai prompt ke AI coding assistant, gunakan urutan berikut agar hasil lebih terarah:

1. Minta AI generate **Fase 0** dulu (struktur project + dependency + theme + router) — review sebelum lanjut.
2. Lanjut **Fase 1 & 2** sekaligus karena saling terkait (auth perlu jalan dulu sebelum fetch menu).
3. Untuk setiap fase berikutnya, beri instruksi: *"Lanjutkan ke Fase X sesuai PLAN_POS_APP.md, gunakan pola folder & provider yang sudah ada, jangan ubah struktur yang sudah dibuat kecuali diminta."*
4. Selalu minta AI membuat **mock data lokal** dulu untuk UI testing sebelum menyambungkan API asli, supaya UI bisa direview cepat.
5. Setelah UI menu/cart/checkout jadi, baru sambungkan ke endpoint sungguhan satu per satu (Menu → Auth → Orders → Payments → Reservations → Sync).
6. Untuk printer, minta AI membuat dulu `ReceiptFormatter` dengan **mock order**, test hasil format teks di console sebelum benar-benar kirim ke printer fisik.
7. Selalu minta AI menjelaskan asumsi yang diambil bila ada bagian API yang ambigu (contoh: nilai pasti enum `order_status`, apakah ada `order_type: dine_in`) — supaya bisa dikonfirmasi ke backend.

---

## 13. Catatan & Hal yang Perlu Dikonfirmasi ke Backend

- Nilai lengkap enum `order_status` (baru diketahui: `baru`; kemungkinan ada `diproses`, `siap`, `selesai`, `dibatalkan`).
- Apakah `order_type` mendukung `dine_in` (untuk kasir tablet di tempat), atau hanya `delivery`/`pickup`.
- Format pasti perhitungan `tax` (persentase berapa, dihitung dari subtotal setelah/sebelum diskon).
- Apakah ada endpoint statistik/dashboard penjualan (belum terlihat di dokumentasi saat ini).
- Apakah ada endpoint untuk daftar meja (`restaurant_table`) secara terpisah dari reservasi (untuk keperluan pilih meja saat dine-in).
- Rate limit & masa berlaku token (expiry), serta mekanisme refresh token bila ada.
- **Snapshot data order item** (prioritas): mohon konfirmasi apakah tabel `order_items` sudah/akan menyimpan `item_name`, `item_price`, `item_discount` sebagai salinan data saat transaksi, terpisah dari data master `menu_items`. Ini penting agar riwayat order & struk cetak tidak berubah retroaktif ketika harga/nama menu diedit di kemudian hari. Detail rasional ada di Bagian 6.3.

---

*Dokumen ini disusun berdasarkan dokumentasi API resmi per 8 Agustus 2026: `https://shadja.codingajaindonesia.my.id/docs`*
*Revisi: scope dipersempit ke **mode online-only** untuk tahap pengembangan saat ini + catatan rekomendasi snapshot data pada `order_items`.*
