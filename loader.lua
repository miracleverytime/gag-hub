-- ======================================================================
-- Miracle Hub — loader.lua  [FIXED v2]
-- This is the ONLY file you inject. Fetches every module from GitHub,
-- builds a shared `ctx` table, runs modules in dependency order:
--   core -> ui -> ultralow -> logic -> pages -> bootstrap
--
-- Inject with:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/Miracleverytime/GAG-Hub/main/loader.lua"))()
--
-- FIX v2: BytecodePatchWatcherT crash diatasi dengan:
--   1. Delay PROPORSIONAL ke ukuran file SEBELUM loadstring()
--      → Workers Xeno butuh waktu lebih lama reset untuk file besar (>50KB)
--   2. task.wait() TAMBAHAN setelah pcall(fn) untuk modul besar
--      → fn() menjalankan outer wrapper, moduleFn(ctx) build seluruh UI/logic
--        yang juga melibatkan banyak upvalue/closure patches
--   3. Delay ANTAR modul juga disesuaikan ukuran modul sebelumnya
-- ======================================================================

local BASE = "https://raw.githubusercontent.com/Miracleverytime/GAG-Hub/main/"

-- MODULES: { name, preCompileDelay, postInitDelay }
-- preCompileDelay : detik wait SEBELUM loadstring()  (worker recovery)
-- postInitDelay   : detik wait SETELAH moduleFn(ctx) (closure patch recovery)
-- Aturan thumb: ~1 detik per 25KB source. Minimum 1.0 untuk semua modul.
local MODULES = {
    { name = "core.lua",      preDelay = 0.5,  postDelay = 0.5  },  -- 13 KB  → ringan
    { name = "ui.lua",        preDelay = 2.5,  postDelay = 2.0  },  -- 112 KB → BESAR
    { name = "ultralow.lua",  preDelay = 1.0,  postDelay = 0.5  },  -- 24 KB  → sedang
    { name = "logic.lua",     preDelay = 2.5,  postDelay = 2.0  },  -- 116 KB → BESAR
    { name = "pages.lua",     preDelay = 2.0,  postDelay = 1.5  },  -- 83 KB  → besar
    { name = "bootstrap.lua", preDelay = 1.0,  postDelay = 0.0  },  -- 33 KB  → last, no post
}

local ctx = {}

-- ====================== LOAD HELPER ======================
local function loadModule(mod)
    local name       = mod.name
    local preDelay   = mod.preDelay
    local postDelay  = mod.postDelay

    -- 1. Fetch source dari GitHub
    local src
    local ok, err = pcall(function()
        src = game:HttpGet(BASE .. name, true)
    end)
    if not ok or not src then
        warn("[MiracleHub] FETCH FAILED — " .. name .. ": " .. tostring(err))
        return false
    end

    -- 2. Strip UTF-8 BOM jika ada
    if src:sub(1, 3) == "\239\187\191" then
        src = src:sub(4)
    end

    -- 3. PRE-COMPILE DELAY — beri waktu BytecodePatchWatcher workers recover
    --    Ini adalah fix UTAMA: delay proporsional ukuran file, bukan flat 0.1s
    print("[MiracleHub] Compiling " .. name .. " (" .. #src .. " bytes) — waiting " .. preDelay .. "s …")
    task.wait(preDelay)

    -- 4. Compile
    local fn, compileErr = loadstring(src, "=" .. name)
    if not fn then
        warn("[MiracleHub] COMPILE ERROR — " .. name .. ": " .. tostring(compileErr))
        return false
    end

    -- 5. Run outer wrapper (returns moduleFn)
    local runOk, moduleFn = pcall(fn)
    if not runOk then
        warn("[MiracleHub] RUN ERROR — " .. name .. ": " .. tostring(moduleFn))
        return false
    end
    if type(moduleFn) ~= "function" then
        warn("[MiracleHub] " .. name .. " did not return a function.")
        return false
    end

    -- 6. Init module — untuk ui.lua/logic.lua ini membangun ratusan closures
    --    Yield singkat SEBELUM init agar patcher punya napas
    task.wait(0.2)
    local initOk, initErr = pcall(moduleFn, ctx)
    if not initOk then
        warn("[MiracleHub] INIT ERROR — " .. name .. ": " .. tostring(initErr))
        return false
    end

    -- 7. POST-INIT DELAY — beri waktu patch closures selesai sebelum modul berikutnya
    if postDelay > 0 then
        print("[MiracleHub] " .. name .. " OK — cooling down " .. postDelay .. "s …")
        task.wait(postDelay)
    else
        print("[MiracleHub] " .. name .. " OK.")
    end

    return true
end

-- ====================== MAIN LOAD CHAIN ======================
-- Beri sinyal awal
print("[MiracleHub] Starting load — " .. #MODULES .. " modules.")
print("[MiracleHub] Load akan memakan ~18-22 detik. Jangan inject ulang!")

local loaded = 0
for _, mod in ipairs(MODULES) do
    local ok = loadModule(mod)
    if not ok then
        warn("[MiracleHub] Load chain ABORTED at: " .. mod.name)
        warn("[MiracleHub] " .. loaded .. "/" .. #MODULES .. " modules loaded before abort.")
        break
    end
    loaded = loaded + 1
end

if loaded == #MODULES then
    print("[MiracleHub] ✓ All " .. loaded .. " modules loaded successfully!")
else
    warn("[MiracleHub] Only " .. loaded .. "/" .. #MODULES .. " modules loaded.")
end

return ctx