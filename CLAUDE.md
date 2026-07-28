# Miracle Hub — CLAUDE.md

> Context file untuk Claude Code. Baca ini sebelum menyentuh file apapun.

---

## Overview Project

**Miracle Hub** adalah Roblox script hub yang di-inject via `loadstring` ke game **Grow a Garden**.
Saat ini berjalan baik di **desktop**. Sedang di-port ke **mobile/Android**.

Arsitektur yang dipilih: **hybrid — satu `loader.lua`, modul terpisah hanya untuk bagian yang
benar-benar beda secara fundamental (yaitu `ui.lua`).**

---

## Struktur File

```
/
├── loader.lua          ← Entry point. SATU file. User inject cukup ini.
├── core.lua            ← Shared ✅ (no changes needed)
├── ui.lua              ← Desktop only
├── ui.mobile.lua       ← Mobile only (BELUM ADA — perlu dibuat)
├── ultralow.lua        ← Shared ✅ (no changes needed)
├── logic.lua           ← Shared dengan conditional kecil ⚠️
├── pages.lua           ← Shared ✅ (no changes needed)
└── bootstrap.lua       ← Shared dengan conditional kecil ⚠️
```

---

## Analisis Per-File (Berdasarkan Kode Asli)

### ✅ `core.lua` — Fully Shared
Pure service/data/state setup. Tidak ada UI. Tidak ada input handling. Tidak perlu diubah apapun.
`ctx.isMobile` akan di-set oleh `loader.lua` SETELAH core berjalan — jadi core tidak perlu tahu platform.

### ✅ `ultralow.lua` — Fully Shared
Pure game-world manipulation (hapus tanaman, strip texture, lower render quality).
Tidak bergantung pada UI atau input. Satu-satunya koneksi ke UI adalah `ctx.UI.Notify()` yang sudah
di-provide oleh `ui.lua` atau `ui.mobile.lua` sebelum ultralow jalan.

### ✅ `pages.lua` — Fully Shared
Semua component builder (`CreateToggle`, `CreateSlider`, `CreateDropdown`, dll.) menggunakan
`MouseButton1Click` yang **juga di-fire oleh touch di Roblox** — jadi pages.lua compatible mobile
tanpa perubahan. Pages hanya populate `ContentArea` yang sudah di-buat oleh `ui.lua`/`ui.mobile.lua`,
jadi selama ctx-nya sama, pages.lua jalan di kedua platform.

### ⚠️ `logic.lua` — Shared + 2 Conditional Kecil
Mayoritas logic (harvest, plant, shop, sell, pets, ESP, anti-AFK) **sepenuhnya shared**.
Hanya dua bagian yang perlu conditional:

1. **Fly WASD controls** (sekitar line 2705–2711):
   ```lua
   -- Desktop: pakai IsKeyDown keyboard
   if UserInputService:IsKeyDown(Enum.KeyCode.W) then vel += cf.LookVector end
   -- ... dst
   ```
   Di mobile tidak ada keyboard, perlu touch joystick atau skip (fly toggle tetap bisa lewat UI button).

2. **Anti-AFK** sudah handle touch (`Enum.UserInputType.Touch`) — tidak perlu diubah.

### ⚠️ `bootstrap.lua` — Shared + 2 Conditional Kecil
Mayoritas bootstrap (sidebar wiring, search, loading reveal, confirm-close modal, ToggleFly) **shared**.
Yang perlu conditional:

1. **Keybinds** (line 682–692): `Insert` untuk minimize dan `F` untuk fly — tidak ada di mobile.
   Cukup skip seluruh blok keybind jika `ctx.isMobile`.

2. **Window drag**: Saat ini pakai `MouseMoved` + `MouseButton1Down/Up`. Di mobile perlu
   `TouchStarted`/`TouchMoved`/`TouchEnded`.

3. **Minimize pill**: Logic pill (DoMinimize/DoRestore) pakai absolute pixel positioning 900×600.
   Di mobile, minimize bisa diganti dengan floating button sederhana, atau pill ukuran disesuaikan.

### ❌ `ui.lua` → SPLIT: `ui.lua` (desktop) + `ui.mobile.lua` (baru)
Ini satu-satunya file yang benar-benar perlu split karena perbedaannya fundamental:

| Aspek | Desktop (`ui.lua`) | Mobile (`ui.mobile.lua`) |
|---|---|---|
| Window size | 900×600 hardcoded | ~fullscreen atau 95% viewport |
| Sidebar | 170px kiri, scrollable | Bottom tab bar (icon only) |
| Drag | `MouseButton1Down` + `MouseMoved` | `TouchStarted` + `TouchMoved` |
| Button size | 14×14 close/minimize | ≥40×40 (touch targets) |
| Hover effects | `MouseEnter`/`MouseLeave` | Tidak ada (remove semua) |
| Minimize pill | 304px pill bar | Floating button 44×44 |
| Font size | TextSize 11–14 | TextSize minimum 13 |

---

## Task yang Perlu Dikerjakan

### Task 1 — Update `loader.lua`: Platform Detection + Module Routing

Tambahkan setelah `local ctx = {}`:

```lua
-- ====================== PLATFORM DETECTION ======================
local function isMobilePlatform()
    local UIS = game:GetService("UserInputService")
    -- KeyboardEnabled true pada desktop/PC; false pada mobile pure
    -- TouchEnabled bisa true di PC yang punya touchscreen, makanya cek keyboard dulu
    return not UIS.KeyboardEnabled and UIS.TouchEnabled
end

local IS_MOBILE = isMobilePlatform()
ctx.isMobile = IS_MOBILE
```

Lalu update tabel `MODULES` — hanya ganti baris `ui.lua`:

```lua
local MODULES = {
    {
        name      = "core.lua",
        label     = "Connecting to servers...",
        preDelay  = 0.5,
        postDelay = 0.5,
    },
    {
        -- SATU-SATUNYA baris yang berubah
        name      = IS_MOBILE and "ui.mobile.lua" or "ui.lua",
        label     = "Loading assets & icons...",
        preDelay  = IS_MOBILE and 1.5 or 2.5,
        postDelay = IS_MOBILE and 1.0 or 2.0,
    },
    {
        name      = "ultralow.lua",
        label     = "Optimizing performance...",
        preDelay  = 1.0,
        postDelay = 0.5,
    },
    {
        name      = "logic.lua",
        label     = "Loading features...",
        preDelay  = 2.5,
        postDelay = 2.0,
    },
    {
        name      = "pages.lua",
        label     = "Almost there...",
        preDelay  = 2.0,
        postDelay = 1.5,
    },
    {
        name      = "bootstrap.lua",
        label     = "Finishing up...",
        preDelay  = 1.0,
        postDelay = 0.0,
    },
}
```

> **Penting:** `ctx.isMobile` harus di-set SEBELUM MODULES dideklarasikan karena `IS_MOBILE`
> dipakai di dalam tabel. Dan harus SETELAH `local ctx = {}`.

---

### Task 2 — Update `logic.lua`: Fly Controls + Keybind Skip

Cari blok fly loop (sekitar line 2700–2716) dan wrap WASD dengan conditional:

```lua
-- Ganti ini:
if UserInputService:IsKeyDown(Enum.KeyCode.W) then vel += cf.LookVector end
if UserInputService:IsKeyDown(Enum.KeyCode.S) then vel -= cf.LookVector end
if UserInputService:IsKeyDown(Enum.KeyCode.A) then vel -= cf.RightVector end
if UserInputService:IsKeyDown(Enum.KeyCode.D) then vel += cf.RightVector end
if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vel += Vector3.new(0, 1, 0) end
if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then vel -= Vector3.new(0, 1, 0) end

-- Jadi ini:
if not ctx.isMobile then
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then vel += cf.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then vel -= cf.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then vel -= cf.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then vel += cf.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vel += Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then vel -= Vector3.new(0, 1, 0) end
end
-- Di mobile, fly direction dikendalikan lewat joystick bawaan Roblox
-- (karakter bergerak → vel diambil dari HumanoidRootPart.AssemblyLinearVelocity)
-- atau fly dinonaktifkan dari UI toggle saja.
```

---

### Task 3 — Update `bootstrap.lua`: Skip Keybinds + Touch Drag

**3a. Keybinds (line 682–692)** — wrap dengan `if not ctx.isMobile`:

```lua
-- Ganti:
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Insert then
        if minimized then DoRestore() else DoMinimize() end
    end
    if input.KeyCode == Enum.KeyCode.F then
        ctx.ToggleFly()
    end
end)

-- Jadi:
if not ctx.isMobile then
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.Insert then
            if minimized then DoRestore() else DoMinimize() end
        end
        if input.KeyCode == Enum.KeyCode.F then
            ctx.ToggleFly()
        end
    end)
end
```

**3b. Window Drag** — bootstrap.lua menggunakan drag via `TopBar`. Cari blok drag
(biasanya ada `InputBegan` + `InputChanged` untuk drag window) dan tambahkan support
`UserInputType.Touch` di samping `UserInputType.MouseButton1`.

**3c. Minimize Pill** — `MinimizedPill` dibuat di bootstrap dengan ukuran `PILL_W = 304`.
Di mobile: cukup buat floating button `44×44` di pojok layar sebagai pengganti pill.
Wrap seluruh blok pill creation dan DoMinimize/DoRestore dengan:

```lua
if ctx.isMobile then
    -- Versi mobile: floating button sederhana
else
    -- Versi desktop: pill bar 304px seperti sekarang
end
```

---

### Task 4 — Buat `ui.mobile.lua` (File Baru)

File ini harus expose **ctx yang identik** dengan `ui.lua` agar `pages.lua` dan `bootstrap.lua`
tidak perlu tahu platform. Wajib expose semua referensi ini:

```lua
-- Wajib ada (dipakai loader.lua untuk loading screen):
ctx.LoadingScreen    -- Frame fullscreen
ctx.LoadingContainer -- Frame konten loading
ctx.LoadingBarFill   -- Frame progress bar fill
ctx.LoadingPercent   -- TextLabel "0%" → "100%"
ctx.LoadingStatus    -- TextLabel status teks

-- Wajib ada (dipakai bootstrap.lua):
ctx.ScreenGui        -- ScreenGui utama
ctx.MainFrame        -- Frame utama hub
ctx.TopBar           -- Frame top bar
ctx.Sidebar          -- Frame sidebar (atau bottom bar di mobile)
ctx.ContentArea      -- Frame area konten (tempat pages.lua populate)
ctx.ContentScroll    -- ScrollingFrame di dalam ContentArea
ctx.SearchBox        -- TextBox (boleh hidden, dipakai bootstrap untuk search wiring)
ctx.CloseButton      -- Button tutup
ctx.MinimizeButton   -- Button minimize
ctx.sidebarButtonRefs -- Table {Farm=btn, Shop=btn, ...} untuk bootstrap wiring
ctx.SetActivePage    -- Function(pageName)
ctx.GetActivePage    -- Function() → pageName
ctx.Pages            -- Table {pageName = builderFn}
ctx.registerPage     -- Function(name, fn)
ctx.ClearContent     -- Function() bersihkan ContentScroll
ctx.originalSize     -- UDim2 ukuran asli MainFrame
ctx.SnapMainFramePosition -- Function()
ctx.UI               -- Table berisi semua component builders (identik dengan desktop)

-- ctx.UI wajib berisi semua key ini (dipakai pages.lua):
-- UI.Create, UI.CreateCorner, UI.CreateStroke, UI.CreatePadding, UI.CreateListLayout
-- UI.Tween, UI.Notify, UI.NotifyStok, UI.GetMutationColor
-- UI.CreateSectionCard, UI.CreateSubHeader, UI.CreateToggle, UI.CreateSlider
-- UI.CreateActionButton, UI.CreateDropdown, UI.CreateMultiSelect
-- UI.CreateInfoText, UI.CreateStatRow
```

**Panduan spesifik layout mobile:**

- `MainFrame`: gunakan `UDim2.fromScale(0.97, 0.94)` agar responsive di semua layar
- Tidak ada Sidebar kiri — ganti dengan **bottom tab bar** tinggi 52px di bawah `MainFrame`
- `ContentArea` mengisi seluruh MainFrame minus TopBar (48px) dan BottomBar (52px)
- `sidebarButtonRefs` tetap berisi referensi button yang sama (`sb.Farm`, `sb.Shop`, dst.)
  tapi button-nya adalah ikon di bottom bar, bukan item sidebar kiri
- Hilangkan semua `MouseEnter`/`MouseLeave` handler — ganti dengan `Activated` atau tidak ada
- Ukuran minimum touch target: **40×40 pixel** untuk semua button interaktif
- `TextSize` minimum **13** di seluruh file
- `ScrollBarThickness` minimum **6** di semua ScrollingFrame
- Minimize button di mobile: bisa dihilangkan atau jadi floating button di luar MainFrame
- Drag window: gunakan `TouchStarted`/`TouchMoved` di TopBar

---

## Konvensi yang Harus Dipatuhi

- **Jangan ubah** pola `return function(ctx)` — loader bergantung pada ini
- **Gunakan `ctx.isMobile`** untuk conditional, jangan re-detect platform di dalam modul
- **Semua `warn()`** tetap pakai prefix `[MiracleHub]`
- **Jangan ubah** error handling di `loadModule()` pada `loader.lua`
- **ctx harus identik** antara desktop dan mobile — semua key yang sama harus ada

---

## Urutan Pengerjaan yang Disarankan

1. `loader.lua` — platform detection + module routing (paling kecil risikonya)
2. `logic.lua` — conditional fly controls (perubahan minimal, 1 blok)
3. `bootstrap.lua` — skip keybinds + touch drag + pill conditional
4. `ui.mobile.lua` — file baru terbesar, kerjakan terakhir setelah 1–3 verified

---

## Testing Checklist

- [ ] `loader.lua` detect `isMobile` dengan benar di Roblox Studio Mobile Emulator
- [ ] Loading screen muncul dan bar fill berjalan normal di mobile
- [ ] Bottom tab bar tidak overlap virtual joystick kiri bawaan Roblox
- [ ] Semua button bisa di-tap dengan jari (touch target ≥ 40px)
- [ ] `ctx.UI.*` lengkap — `pages.lua` tidak error saat load di mobile
- [ ] `bootstrap.lua` tidak error karena keybind `Insert`/`F` di mobile
- [ ] Fly toggle lewat UI button (bukan keybind) tetap berfungsi di mobile
- [ ] Anti-AFK tetap berjalan (sudah handle `UserInputType.Touch`)
- [ ] Tidak ada error di Output Roblox Studio saat inject mode mobile
