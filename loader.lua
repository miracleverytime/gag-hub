-- ======================================================================
-- Miracle Hub — loader.lua  [FIXED v3]
-- ONLY file to inject. Loads modules in order, updates the in-game
-- loading screen (LoadingBarFill / LoadingPercent / LoadingStatus) yang
-- sudah dibangun oleh ui.lua secara real-time.
--
-- Inject:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/Miracleverytime/GAG-Hub/main/loader.lua"))()
-- ======================================================================

local BASE = "https://raw.githubusercontent.com/Miracleverytime/GAG-Hub/main/"

-- Konfigurasi per modul:
--   label     = teks yang muncul di LoadingStatus saat modul sedang diproses
--   preDelay  = detik wait SEBELUM loadstring() — BytecodePatchWatcher recovery
--   postDelay = detik wait SETELAH moduleFn(ctx) — closure patch cooldown
local MODULES = {
    {
        name      = "core.lua",
        label     = "Connecting to servers...",
        preDelay  = 0.5,
        postDelay = 0.5,
    },
    {
        name      = "ui.lua",
        label     = "Loading assets & icons...",
        preDelay  = 2.5,
        postDelay = 2.0,
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

local TOTAL = #MODULES
local ctx   = {}

-- ====================== LOADING SCREEN HELPER ======================
-- Dipanggil setelah ui.lua selesai (ctx.LoadingBarFill dll sudah ada).
-- Aman dipanggil kapanpun — guard nil di dalam.
local function setLoadingUI(stepIndex, statusText)
    local barFill  = ctx.LoadingBarFill
    local pctLabel = ctx.LoadingPercent
    local stLabel  = ctx.LoadingStatus

    if not (barFill and pctLabel and stLabel) then return end

    local pct = stepIndex / TOTAL
    -- Tween bar fill
    local TweenService = game:GetService("TweenService")
    local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(barFill, info, {Size = UDim2.new(pct, 0, 1, 0)}):Play()

    pctLabel.Text = math.floor(pct * 100) .. "%"
    stLabel.Text  = statusText
end

-- ====================== LOAD HELPER ======================
local function loadModule(mod, stepIndex)
    local name      = mod.name
    local preDelay  = mod.preDelay
    local postDelay = mod.postDelay

    -- Update status: "Fetching …"
    setLoadingUI(stepIndex - 0.8, "Preparing " .. (stepIndex) .. "/" .. TOTAL .. "...")

    -- 1. Fetch
    local src
    local ok, err = pcall(function()
        src = game:HttpGet(BASE .. name, true)
    end)
    if not ok or not src then
        setLoadingUI(stepIndex - 0.8, "Connection error. Retrying...")
        warn("[MiracleHub] FETCH FAILED — " .. name .. ": " .. tostring(err))
        return false
    end

    -- 2. Strip UTF-8 BOM
    if src:sub(1, 3) == "\239\187\191" then src = src:sub(4) end

    -- 3. PRE-COMPILE DELAY — BytecodePatchWatcher worker recovery
    setLoadingUI(stepIndex - 0.5, mod.label)
    task.wait(preDelay)

    -- 4. Compile
    local fn, compileErr = loadstring(src, "=" .. name)
    if not fn then
        setLoadingUI(stepIndex - 0.5, "Failed to load. Please re-inject.")
        warn("[MiracleHub] COMPILE ERROR — " .. name .. ": " .. tostring(compileErr))
        return false
    end

    -- 5. Run outer wrapper
    local runOk, moduleFn = pcall(fn)
    if not runOk then
        setLoadingUI(stepIndex - 0.5, "Failed to load. Please re-inject.")
        warn("[MiracleHub] RUN ERROR — " .. name .. ": " .. tostring(moduleFn))
        return false
    end
    if type(moduleFn) ~= "function" then
        warn("[MiracleHub] " .. name .. " did not return a function.")
        return false
    end

    -- 6. Yield lagi sebelum init (closure patches butuh jeda)
    setLoadingUI(stepIndex - 0.2, mod.label)
    task.wait(0.2)

    -- 7. Init module
    local initOk, initErr = pcall(moduleFn, ctx)
    if not initOk then
        setLoadingUI(stepIndex - 0.2, "Failed to load. Please re-inject.")
        warn("[MiracleHub] INIT ERROR — " .. name .. ": " .. tostring(initErr))
        return false
    end

    -- 8. POST-INIT COOLDOWN
    setLoadingUI(stepIndex, mod.label)
    if postDelay > 0 then
        task.wait(postDelay)
    end

    return true
end

-- ====================== MAIN LOAD CHAIN ======================
local loaded = 0
for i, mod in ipairs(MODULES) do
    local ok = loadModule(mod, i)
    if not ok then
        warn("[MiracleHub] Load chain ABORTED at: " .. mod.name)
        break
    end
    loaded = loaded + 1
end

-- Loader selesai — bootstrap.lua sudah berjalan dan akan handle
-- animasi reveal (fade out loading screen → show MainFrame).
-- Tidak perlu print ke console lagi.
if loaded < TOTAL then
    setLoadingUI(loaded, "Something went wrong. Please re-inject.")
end

return ctx