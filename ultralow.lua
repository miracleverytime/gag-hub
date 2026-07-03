-- ======================================================================
-- Miracle Hub — ultralow.lua
-- "Ultra Low Graphic Mode" module.
-- Loaded SETELAH core (sebelum ui) ATAU dipanggil on-demand dari pages.
--
-- Cara pakai dari loader/bootstrap:
--   local ultralow = loadstring(game:HttpGet(BASE .. "ultralow.lua"))()
--   ultralow(ctx)
--
-- Cara pakai langsung dari pages.lua (jika sudah di-load sebelumnya):
--   ctx.UltraLow.Apply()
--
-- Filosofi:
--   - ONE-WAY: setelah aktif, TIDAK menyimpan state apapun untuk restore.
--     Player harus relog agar scene kembali normal.
--   - Sesadar mungkin menghapus VISUAL objects, bukan fungsional objects.
--     CollisionBlock, HarvestPart, Base, dsb. TIDAK dihapus.
--   - Dilakukan dalam coroutine bertahap agar tidak freeze client.
-- ======================================================================

return function(ctx)
    local States = ctx.States

    -- ================================================================
    -- HELPER: yield-safe batch processor
    -- ================================================================
    local BATCH_SIZE   = 50     -- objek per batch sebelum task.wait
    local BATCH_YIELD  = 0.01   -- detik antar batch

    local function ProcessBatch(list, fn)
        local count = 0
        for _, v in ipairs(list) do
            pcall(fn, v)
            count = count + 1
            if count % BATCH_SIZE == 0 then
                task.wait(BATCH_YIELD)
            end
        end
    end

    -- ================================================================
    -- HELPER: Safely get a service
    -- ================================================================
    local function GetSvc(name)
        local ok, svc = pcall(function() return game:GetService(name) end)
        return ok and svc or nil
    end

    -- ================================================================
    -- MODULE NAMESPACE
    -- ================================================================
    local UltraLow = {}
    ctx.UltraLow   = UltraLow

    -- Status flag (hanya informatif, tidak dipakai untuk restore)
    UltraLow.Active = false

    -- ================================================================
    -- WHITELIST: nama part yang TIDAK boleh dihapus di dalam plant
    -- (mereka dibutuhkan untuk harvest/collision detection)
    -- ================================================================
    local PLANT_PART_KEEP = {
        HarvestPart = true,
        CollisionBlock = true,
        Base = true,
    }

    -- ================================================================
    -- 1. HAPUS TANAMAN MILIK ORANG LAIN
    --    Path: Workspace.Gardens.PlotX.Plants (semua plot KECUALI milik player)
    -- ================================================================
    local function RemoveOtherPlayerPlants()
        local workspace   = game:GetService("Workspace")
        local gardens     = workspace:FindFirstChild("Gardens")
        if not gardens then return end

        local myPlotName  = "Plot" .. tostring(ctx.MY_PLOT_ID or "")

        local toRemove = {}
        for _, plot in ipairs(gardens:GetChildren()) do
            if plot.Name ~= myPlotName then
                local plantsFolder = plot:FindFirstChild("Plants")
                if plantsFolder then
                    for _, plantModel in ipairs(plantsFolder:GetChildren()) do
                        table.insert(toRemove, plantModel)
                    end
                end
            end
        end

        ProcessBatch(toRemove, function(obj)
            if obj and obj.Parent then
                obj:Destroy()
            end
        end)

        -- Monitor: hapus tanaman baru dari plot lain saat di-load
        gardens.DescendantAdded:Connect(function(desc)
            if not UltraLow.Active then return end
            -- cek apakah descendent berada di plot lain
            local ancestor = desc
            local isOther  = false
            while ancestor and ancestor ~= gardens do
                if ancestor.Parent == gardens and ancestor.Name ~= myPlotName then
                    isOther = true
                    break
                end
                ancestor = ancestor.Parent
            end
            if isOther and desc.Parent and desc.Parent.Name == "Plants" then
                desc:Destroy()
            end
        end)
    end

    -- ================================================================
    -- 2. HAPUS VFX / EFEK MUTASI
    --    Anak-anak part bernama *VFX, *Effect, *Particle, *Glow,
    --    *Sparkle, *Aura, *Beam dari semua tanaman (termasuk punya kita).
    --    Kita TIDAK hapus mesh/body tanaman, hanya effect parts.
    -- ================================================================
    local VFX_PATTERNS = {
        "VFX", "Effect", "Particle", "Glow", "Sparkle",
        "Aura", "Beam", "Trail", "Smoke", "Fire", "Explosion",
        "BloodlitVFX", "StarstruckVFX", "AuroraVFX",
        "GoldVFX", "ElectricVFX", "RainbowVFX", "FrozenVFX",
    }

    local function NameMatchesVFX(name)
        local lower = name:lower()
        for _, pat in ipairs(VFX_PATTERNS) do
            if lower:find(pat:lower(), 1, true) then
                return true
            end
        end
        return false
    end

    local function RemoveMutationVFX()
        local workspace = game:GetService("Workspace")
        local gardens   = workspace:FindFirstChild("Gardens")
        if not gardens then return end

        local toRemove = {}

        -- Kumpulkan semua VFX parts dari semua plot (termasuk plot kita)
        -- tapi hanya di dalam Plants folder
        for _, plot in ipairs(gardens:GetChildren()) do
            local plantsFolder = plot:FindFirstChild("Plants")
            if plantsFolder then
                for _, plantModel in ipairs(plantsFolder:GetChildren()) do
                    for _, part in ipairs(plantModel:GetDescendants()) do
                        -- Hapus efek berupa SpecialMesh, ParticleEmitter,
                        -- PointLight, SpotLight, SelectionBox, Decal, dll
                        if part:IsA("ParticleEmitter") or part:IsA("PointLight")
                            or part:IsA("SpotLight") or part:IsA("SurfaceLight")
                            or part:IsA("SelectionBox") or part:IsA("Decal")
                            or part:IsA("Texture") or part:IsA("Trail")
                            or part:IsA("Smoke") or part:IsA("Fire")
                            or part:IsA("Sparkles")
                        then
                            table.insert(toRemove, part)
                        elseif part:IsA("BasePart") and NameMatchesVFX(part.Name) then
                            -- VFX part (BloodlitVFX, GoldVFX, dll)
                            table.insert(toRemove, part)
                        end
                    end
                end
            end
        end

        ProcessBatch(toRemove, function(obj)
            if obj and obj.Parent then
                obj:Destroy()
            end
        end)
    end

    -- ================================================================
    -- 3. BUAT TANAMAN MILIK KITA MENJADI TRANSPARENT (ULTRA FLAT)
    --    Body tanaman tetap ada (fungsi harvest bekerja via CollisionBlock/HarvestPart),
    --    tapi kita buat Transparency = 1 untuk semua visual parts
    --    agar GPU tidak perlu render polygon tanaman.
    -- ================================================================
    local function FlattenMyPlants()
        local workspace   = game:GetService("Workspace")
        local gardens     = workspace:FindFirstChild("Gardens")
        if not gardens then return end

        local myPlotName  = "Plot" .. tostring(ctx.MY_PLOT_ID or "")
        local myPlot      = gardens:FindFirstChild(myPlotName)
        if not myPlot then return end

        local plantsFolder = myPlot:FindFirstChild("Plants")
        if not plantsFolder then return end

        local toPatch = {}
        for _, plantModel in ipairs(plantsFolder:GetChildren()) do
            for _, part in ipairs(plantModel:GetChildren()) do
                -- Hanya transparent-kan part yang BUKAN kritis (bukan Base/HarvestPart/CollisionBlock)
                if part:IsA("BasePart") and not PLANT_PART_KEEP[part.Name] then
                    table.insert(toPatch, part)
                end
            end
        end

        ProcessBatch(toPatch, function(part)
            if part and part.Parent then
                part.Transparency     = 1
                part.CastShadow       = false
                part.ReceiveAge       = false   -- no-op safe
            end
        end)

        -- Monitor tanaman baru yang di-plant
        plantsFolder.ChildAdded:Connect(function(plantModel)
            if not UltraLow.Active then return end
            task.wait(0.1) -- beri waktu model selesai replicate
            for _, part in ipairs(plantModel:GetChildren()) do
                if part:IsA("BasePart") and not PLANT_PART_KEEP[part.Name] then
                    pcall(function()
                        part.Transparency = 1
                        part.CastShadow   = false
                    end)
                end
            end
        end)
    end

    -- ================================================================
    -- 4. HAPUS / NONAKTIFKAN ATMOSPHERE & CUACA
    -- ================================================================
    local function RemoveWeatherEffects()
        local lighting = game:GetService("Lighting")
        if not lighting then return end

        -- Hapus semua Atmosphere, Bloom, BlurEffect, ColorCorrectionEffect,
        -- DepthOfField, SunRaysEffect, ColorGradingEffect dari Lighting
        local effectsToRemove = {}
        for _, child in ipairs(lighting:GetChildren()) do
            if child:IsA("Atmosphere")
                or child:IsA("BloomEffect")
                or child:IsA("BlurEffect")
                or child:IsA("ColorCorrectionEffect")
                or child:IsA("DepthOfFieldEffect")
                or child:IsA("SunRaysEffect")
            then
                table.insert(effectsToRemove, child)
            end
        end
        for _, e in ipairs(effectsToRemove) do
            pcall(function() e:Destroy() end)
        end

        -- Nonaktifkan Sky (hapus objek Sky agar langit polos)
        for _, child in ipairs(lighting:GetChildren()) do
            if child:IsA("Sky") then
                pcall(function() child:Destroy() end)
            end
        end

        -- Set properti Lighting ke minimum:
        pcall(function()
            lighting.GlobalShadows    = false
            lighting.FogEnd           = 100000
            lighting.FogStart         = 100000
            lighting.Brightness       = 2
            lighting.Ambient          = Color3.fromRGB(128, 128, 128)
            lighting.OutdoorAmbient   = Color3.fromRGB(128, 128, 128)
            lighting.ClockTime        = 14   -- siang, cahaya bersih
            lighting.GeographicLatitude = 0
        end)
    end

    -- ================================================================
    -- 5. TURUNKAN RENDER QUALITY & LOD
    -- ================================================================
    local function LowerRenderQuality()
        local UserSettings = UserSettings()
        local gs = GetSvc("GraphicsSettings")

        -- Matikan detail rendering jika bisa
        pcall(function()
            if settings then
                settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            end
        end)

        -- Gunakan Enum.QualityLevel lewat UserGameSettings (alternatif)
        pcall(function()
            local ugs = UserSettings:GetService("UserGameSettings")
            if ugs then
                ugs.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
            end
        end)

        -- Turunkan MaxGraphicsQuality via workspace
        pcall(function()
            game.Workspace.StreamingEnabled = false   -- matikan streaming agar tidak reload
        end)
    end

    -- ================================================================
    -- 6. HAPUS OBJEK DEKORASI DI WORKSPACE
    --    Map, ambient props, ground decal, dsb. yang tidak
    --    mempengaruhi gameplay.
    -- ================================================================
    local DECO_NAMES = {
        -- Nama folder/object dekorasi umum di Grow A Garden
        "Ambient", "Decorations", "Deco", "Props", "Clouds",
        "Skybox", "Weather", "Particles", "VFX", "Effects",
        "WaterEffect", "RainEffect", "WindEffect",
    }

    -- Daftar ClassName yang aman untuk dihapus (visual only)
    local SAFE_REMOVE_CLASS = {
        ParticleEmitter = true,
        Trail           = true,
        Smoke           = true,
        Fire            = true,
        Sparkles        = true,
        SelectionBox    = true,
        Decal           = true,
        Texture         = true,
        PointLight      = true,
        SpotLight       = true,
        SurfaceLight    = true,
    }

    local function RemoveDecorations()
        local workspace = game:GetService("Workspace")
        local toRemove  = {}

        -- Cari folder dekorasi berdasarkan nama
        for _, name in ipairs(DECO_NAMES) do
            local child = workspace:FindFirstChild(name, true)
            if child and not child:IsA("BasePart") and not child:IsA("Model") then
                -- Hanya hapus jika bukan BasePart / Model penting
                table.insert(toRemove, child)
            end
        end

        -- Hapus semua ParticleEmitter, Trail, dsb. global di workspace
        -- (kecuali yang ada di bawah Characters atau plot tanaman kita)
        local myPlotName = "Plot" .. tostring(ctx.MY_PLOT_ID or "")
        for _, desc in ipairs(workspace:GetDescendants()) do
            if SAFE_REMOVE_CLASS[desc.ClassName] then
                -- Jangan hapus efek di karakter player sendiri
                local inCharacter = false
                local ancestor    = desc.Parent
                while ancestor do
                    if ancestor == game.Players.LocalPlayer.Character then
                        inCharacter = true
                        break
                    end
                    ancestor = ancestor.Parent
                end
                if not inCharacter then
                    table.insert(toRemove, desc)
                end
            end
        end

        ProcessBatch(toRemove, function(obj)
            if obj and obj.Parent then
                pcall(function() obj:Destroy() end)
            end
        end)
    end

    -- ================================================================
    -- 7. HAPUS TEKSTUR DARI BASEPART (DEKOMPRESI TEXTURE)
    --    Set Material ke SmoothPlastic dan hapus semua Decal/Texture
    --    dari semua BasePart di Map/Gardens. Ini secara efektif
    --    "decompress" texture dari VRAM karena tidak ada referensi.
    -- ================================================================
    local function StripTextures()
        local workspace = game:GetService("Workspace")
        local targets   = {}

        -- Kumpulkan semua BasePart di luar Gardens plot kita
        -- (Gardens plot kita sudah di-flatten sebelumnya)
        local myPlotName = "Plot" .. tostring(ctx.MY_PLOT_ID or "")
        local gardens    = workspace:FindFirstChild("Gardens")

        for _, desc in ipairs(workspace:GetDescendants()) do
            -- Skip descendants dari plot kita (sudah ditangani FlattenMyPlants)
            if desc:IsA("BasePart") then
                local skipThis = false
                if gardens then
                    local myPlot = gardens:FindFirstChild(myPlotName)
                    if myPlot and desc:IsDescendantOf(myPlot) then
                        skipThis = true
                    end
                end
                -- Skip Character player
                local char = game.Players.LocalPlayer.Character
                if char and desc:IsDescendantOf(char) then
                    skipThis = true
                end
                if not skipThis then
                    table.insert(targets, desc)
                end
            end
        end

        ProcessBatch(targets, function(part)
            if not (part and part.Parent) then return end
            -- Hapus semua Decal dan Texture children
            for _, child in ipairs(part:GetChildren()) do
                if child:IsA("Decal") or child:IsA("Texture") then
                    child:Destroy()
                end
            end
            -- Set material ke SmoothPlastic (paling murah secara GPU)
            pcall(function()
                if part.Material ~= Enum.Material.SmoothPlastic then
                    part.Material   = Enum.Material.SmoothPlastic
                end
                part.Reflectance  = 0
                part.CastShadow   = false
            end)
        end)
    end

    -- ================================================================
    -- 8. HAPUS BAGIAN MAP YANG JAUH / TIDAK PERLU
    --    Seperti dekorasi di luar area Gardens.
    -- ================================================================
    local function CleanupMapClutter()
        local workspace = game:GetService("Workspace")

        -- Coba hapus Map folder dekorasi (hati-hati jangan hapus terrain)
        local mapFolder = workspace:FindFirstChild("Map")
        if mapFolder then
            local toRemove = {}
            for _, child in ipairs(mapFolder:GetChildren()) do
                -- Simpan hanya folder yang namanya penting gameplay
                local keep = {
                    Teleports = true,
                    Spawns    = true,
                    SpawnLocation = true,
                    Spawn     = true,
                }
                if not keep[child.Name] then
                    -- Jika model berisi banyak BasePart dekorasi, make transparent
                    -- daripada destroy (lebih aman)
                    if child:IsA("Model") or child:IsA("Folder") then
                        for _, desc in ipairs(child:GetDescendants()) do
                            if desc:IsA("BasePart") then
                                table.insert(toRemove, desc)
                            end
                        end
                    end
                end
            end
            ProcessBatch(toRemove, function(part)
                if part and part.Parent then
                    pcall(function()
                        part.Transparency = 1
                        part.CastShadow   = false
                    end)
                end
            end)
        end

        -- Hapus Clouds dari workspace
        pcall(function()
            local clouds = workspace:FindFirstChildOfClass("Clouds")
            if clouds then clouds:Destroy() end
        end)

        -- Hapus Terrain Decoration (water detail, foam, dll)
        pcall(function()
            if workspace.Terrain then
                workspace.Terrain.Decoration  = false
                workspace.Terrain.WaterWaveSize = 0
                workspace.Terrain.WaterWaveSpeed = 0
                workspace.Terrain.WaterReflectance = 0
                workspace.Terrain.WaterTransparency = 0.5
            end
        end)
    end

    -- ================================================================
    -- 9. DISABLE ANIMASI & SCRIPTS YANG TIDAK PERLU
    --    AnimationController, SpecialMesh animation, dsb.
    -- ================================================================
    local function StopNonEssentialScripts()
        local workspace = game:GetService("Workspace")

        -- Disable semua LocalScript di workspace (dekorasi, ambient, dsb.)
        -- KECUALI yang ada di Character player
        local char = game.Players.LocalPlayer.Character
        local toDisable = {}
        for _, desc in ipairs(workspace:GetDescendants()) do
            if desc:IsA("LocalScript") or desc:IsA("Script") then
                local inChar = char and desc:IsDescendantOf(char)
                if not inChar then
                    table.insert(toDisable, desc)
                end
            end
        end
        ProcessBatch(toDisable, function(s)
            if s and s.Parent then
                pcall(function() s.Disabled = true end)
            end
        end)
    end

    -- ================================================================
    -- FUNGSI UTAMA: Apply Ultra Low Graphic
    -- ================================================================
    function UltraLow.Apply()
        if UltraLow.Active then
            warn("[UltraLow] Sudah aktif, skip.")
            return
        end
        UltraLow.Active = true

        task.spawn(function()
            -- Notifikasi awal
            if ctx.UI and ctx.UI.Notify then
                ctx.UI.Notify(
                    "⚡ Ultra Low Graphic",
                    "Menerapkan... Ini tidak bisa di-undo tanpa relog.",
                    Color3.fromRGB(255, 200, 60),
                    5
                )
            end

            -- Update state agar visual loop di logic.lua juga ikut
            if ctx.States then
                ctx.States.noFog      = true
                ctx.States.noShadows  = true
                ctx.States.fullBright = true
                ctx.States.brightness = 2
            end

            -- Step 1: Hapus tanaman orang lain (paling berdampak besar)
            task.spawn(RemoveOtherPlayerPlants)
            task.wait(0.1)

            -- Step 2: Hapus VFX & efek mutasi
            task.spawn(RemoveMutationVFX)
            task.wait(0.1)

            -- Step 3: Flatten tanaman kita (transparent, no shadow)
            task.spawn(FlattenMyPlants)
            task.wait(0.1)

            -- Step 4: Hapus Atmosphere, Bloom, Sky, efek cuaca
            task.spawn(RemoveWeatherEffects)
            task.wait(0.05)

            -- Step 5: Turunkan render quality
            task.spawn(LowerRenderQuality)
            task.wait(0.05)

            -- Step 6: Hapus dekorasi ambient global
            task.spawn(RemoveDecorations)
            task.wait(0.2)

            -- Step 7: Strip texture dari BasePart (paling berat, jalankan terakhir)
            task.spawn(StripTextures)
            task.wait(0.3)

            -- Step 8: Bersihkan clutter di Map
            task.spawn(CleanupMapClutter)
            task.wait(0.1)

            -- Step 9: Stop non-essential scripts
            task.spawn(StopNonEssentialScripts)

            task.wait(0.5)
            if ctx.UI and ctx.UI.Notify then
                ctx.UI.Notify(
                    "Ultra Low Graphic AKTIF",
                    "Scene sudah dioptimasi. Relog untuk kembali normal.",
                    Color3.fromRGB(80, 200, 120),
                    6
                )
            end
        end)
    end

    -- ================================================================
    -- EXPOSE ke ctx
    -- ================================================================
    ctx.UltraLow = UltraLow
    return ctx
end