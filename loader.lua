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
for _, name in ipairs(MODULES) do
    local ok = loadModule(name)
    if not ok then
        warn("[Miracle Hub] Aborting load chain at module: " .. name)
        break
    end
end

print("[Miracle Hub] Loader finished. Modules loaded: " .. tostring(#MODULES))

return ctx
