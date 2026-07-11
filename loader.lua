-- ======================================================================
-- Miracle Hub — loader.lua
-- This is the ONLY file you inject. It fetches every module from the
-- public GitLab raw endpoint, builds a shared `ctx` table, and runs the
-- modules in dependency order:
--   core  -> ui -> logic -> pages -> bootstrap
--
-- Inject with:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/Miracleverytime/GAG-Hub/main/loader.lua"))()
--
-- NOTE: modules below are loaded incrementally during the refactor.
-- Only modules that already exist on the branch are listed in MODULES.
-- ======================================================================

-- Base raw URL for this repo (public). Trailing slash required.
local BASE = "https://raw.githubusercontent.com/Miracleverytime/GAG-Hub/main/"

-- Modules in load order. Append new ones here as the refactor progresses.
local MODULES = {
    "core.lua",
    "ui.lua",
    "ultralow.lua",
    "logic.lua",
    "pages.lua",
    "bootstrap.lua",
}

-- Shared context passed to every module.
local ctx = {}

-- Helper: fetch + compile + run a module, passing ctx.
local function loadModule(name)
    local url = BASE .. name
    local src
    local ok, err = pcall(function()
        src = game:HttpGet(url, true)
    end)
    if not ok or not src then
        warn("[Miracle Hub] Failed to fetch " .. name .. ": " .. tostring(err))
        return false
    end

    -- Strip UTF-8 BOM (U+FEFF = EF BB BF) if present — some editors/GitHub
    -- uploads include it, which makes loadstring crash at :1 with "got Unicode U+FEFF".
    if src:sub(1, 3) == "\239\187\191" then
        src = src:sub(4)
    end

    -- FIX: Yield before compiling each module.
    -- Xeno's BytecodePatchWatcherT has a threshold on rapid bytecode patches.
    -- Without this yield, 6 large loadstring() calls back-to-back causes
    -- "Threshold reached. Workers failed to call restore" → client crash.
    task.wait(0.1)

    local fn, compileErr = loadstring(src, "=" .. name)
    if not fn then
        warn("[Miracle Hub] Compile error in " .. name .. ": " .. tostring(compileErr))
        return false
    end

    local runOk, moduleFn = pcall(fn)
    if not runOk then
        warn("[Miracle Hub] Run error in " .. name .. ": " .. tostring(moduleFn))
        return false
    end

    -- Each module returns `function(ctx) ... end`.
    if type(moduleFn) ~= "function" then
        warn("[Miracle Hub] " .. name .. " did not return a function.")
        return false
    end

    local initOk, initErr = pcall(moduleFn, ctx)
    if not initOk then
        warn("[Miracle Hub] Init error in " .. name .. ": " .. tostring(initErr))
        return false
    end

    return true
end

-- Run all modules in order. Abort early if a critical module fails.
-- FIX: task.wait(0.5) between each module load — lets Xeno's BytecodePatchWatcher
-- workers fully recover between loadstring calls. Without this, compiling 6 large
-- scripts in rapid succession hits the patcher threshold and crashes the client.
for i, name in ipairs(MODULES) do
    local ok = loadModule(name)
    if not ok then
        warn("[Miracle Hub] Aborting load chain at module: " .. name)
        break
    end
    if i < #MODULES then
        task.wait(0.5)
    end
end

print("[Miracle Hub] Loader finished. Modules loaded: " .. tostring(#MODULES))

return ctx