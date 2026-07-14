-- ======================================================================
-- Miracle Hub — logic.lua
-- Game logic + automation module. Loaded THIRD (after core, ui).
--
-- Exposes ctx.Logic with all helpers used by pages.lua, and starts every
-- task.spawn automation loop, ESP, fly, anti-afk, respawn handler.
--
-- Reads from ctx: Colors, States, Data, player, humanoid, Networking,
--   PacketRemote, MY_PLOT_ID, MAX_FRUIT_CAP, SESSION, services, UI.Notify
-- ======================================================================

return function(ctx)
    local Colors            = ctx.Colors
    local States            = ctx.States
    local Data              = ctx.Data
    local player            = ctx.player
    local UserInputService   = ctx.UserInputService
    local RunService        = ctx.RunService
    local CollectionService = ctx.CollectionService
    local ReplicatedStorage = ctx.ReplicatedStorage
    local TeleportService   = ctx.TeleportService
    local HttpService       = ctx.HttpService
    local MY_PLOT_ID        = ctx.MY_PLOT_ID
    local MAX_FRUIT_CAP     = ctx.MAX_FRUIT_CAP
    local SESSION           = ctx.SESSION

    local Notify     = ctx.UI.Notify
    local NotifyStok = ctx.UI.NotifyStok
    local Create     = ctx.UI.Create
    local CreateCorner = ctx.UI.CreateCorner

    -- humanoid is reassigned on respawn; keep a local mutable copy
    local humanoid = ctx.humanoid

    local SEEDS   = Data.SEEDS
    local CRATES  = Data.CRATES
    local PACKET  = Data.PACKET
    local SELL_VALUE_DATA = Data.SELL_VALUE_DATA

    -- PacketRemote / Networking can be refreshed; keep mutable locals
    local PacketRemote = ctx.PacketRemote
    local Networking   = ctx.Networking

    local Logic = {}



    -- ====================== PROXIMITY PROMPT HELPERS ======================
    local _fireprox = fireproximityprompt or function(p)
        p:InputHoldBegin()
        task.wait((p.HoldDuration or 0) + 0.05)
        p:InputHoldEnd()
    end

    local function SafeFirePrompt(prompt)
        if not prompt then return false end
        pcall(_fireprox, prompt)
        return true
    end
    Logic.SafeFirePrompt = SafeFirePrompt

    local function GetMutation(obj)
        return obj:GetAttribute("Mutation") or ""
    end
    Logic.GetMutation = GetMutation

    -- ====================== PLOT / PLANTS HELPERS ======================
    local function GetMyPlot()
        local gardens = game:GetService("Workspace"):FindFirstChild("Gardens")
        if not gardens then return nil end
        return gardens:FindFirstChild("Plot" .. MY_PLOT_ID)
    end
    Logic.GetMyPlot = GetMyPlot

    local function GetPlantsFolder()
        local plot = GetMyPlot()
        if not plot then return nil end
        return plot:FindFirstChild("Plants")
    end
    Logic.GetPlantsFolder = GetPlantsFolder

    local function FirePacket(id, ...)
        if PacketRemote then
            PacketRemote:FireServer(id, ...)
        end
    end
    Logic.FirePacket = FirePacket

    -- ====================== HARVEST CORE ======================
    local function GetReadyFruitCount()
        local myPlot = GetMyPlot()
        if not myPlot then return 0 end
        local count = 0
        for _, prompt in ipairs(CollectionService:GetTagged("HarvestPrompt")) do
            if prompt.Enabled
                and not prompt:GetAttribute("Collected")
                and prompt:IsDescendantOf(myPlot) then
                count = count + 1
            end
        end
        return count
    end
    Logic.GetReadyFruitCount = GetReadyFruitCount

    local function DoHarvestAll(mutFilter, hardLimit)
        local myPlot = GetMyPlot()
        if not myPlot then return 0 end

        local currentCount = player:GetAttribute("FruitCount") or 0
        local cap          = hardLimit or MAX_FRUIT_CAP
        local remaining    = cap - currentCount
        if remaining <= 0 then return 0 end

        local harvested = 0
        local delay     = math.max(States.perFruitDelay or 0, 0)

        for _, prompt in ipairs(CollectionService:GetTagged("HarvestPrompt")) do
            if harvested < remaining
                and prompt:IsDescendantOf(myPlot)
                and prompt:IsDescendantOf(workspace)
                and prompt.Enabled
                and not prompt:GetAttribute("Collected") then
                local harvestPart = prompt.Parent
                local fruit = harvestPart and harvestPart.Parent
                if fruit and fruit:IsA("Model") then
                    local mut = fruit:GetAttribute("Mutation") or ""
                    local skipMuts = (type(mutFilter) == "table") and mutFilter or {}
                    local shouldSkip = #skipMuts > 0 and mut ~= "" and mut ~= "None" and table.find(skipMuts, mut)
                    if not shouldSkip then
                        local plantId = fruit:GetAttribute("PlantId")
                        local fruitId = fruit:GetAttribute("FruitId")
                        local fired   = false

                        if Networking then
                            pcall(function()
                                Networking.Garden.CollectFruit:Fire(plantId, fruitId or "")
                                fired = true
                            end)
                        end

                        if not fired then
                            pcall(function()
                                fireproximityprompt(prompt)
                                fired = true
                            end)
                        end

                        if fired then
                            harvested = harvested + 1
                            if delay > 0 then task.wait(delay) end
                        end
                    end
                end
            end
        end

        return harvested
    end
    Logic.DoHarvestAll = DoHarvestAll

    -- AUTO HARVEST LOOP
    local _harvestCooldown = 0
    task.spawn(function()
        while _G._MiracleHubSession == SESSION do
            task.wait(0.5)
            if States.autoHarvest then
                local currentCount = player:GetAttribute("FruitCount") or 0
                if currentCount < MAX_FRUIT_CAP then
                    local now = os.clock()
                    if now >= _harvestCooldown then
                        local ready = GetReadyFruitCount()
                        if ready > 0 then
                            pcall(function()
                                local harvested = DoHarvestAll(States.harvestFilterMutation)
                                if harvested > 0 and States.notifyHarvest then
                                    local after = player:GetAttribute("FruitCount") or 0
                                    Notify("Auto Harvest", harvested .. " buah | Bag " .. after .. "/" .. MAX_FRUIT_CAP, Colors.Warning)
                                end
                            end)
                            _harvestCooldown = os.clock() + math.max(States.harvestLoopDelay or 2, 0.5)
                        end
                    end
                end
            end
        end
    end)

    -- ====================== AUTO PLANT CORE ======================
    local function GetMyPlantAreas()
        local myPlot = GetMyPlot()
        if not myPlot then return {} end
        local areas = {}
        pcall(function()
            for _, part in ipairs(CollectionService:GetTagged("PlantArea")) do
                if part:IsA("BasePart") and part:IsDescendantOf(myPlot) then
                    table.insert(areas, part)
                end
            end
        end)
        if #areas == 0 then
            pcall(function()
                local visual = myPlot:FindFirstChild("Visual")
                if visual then
                    for _, part in ipairs(visual:GetDescendants()) do
                        if part:IsA("BasePart") and part.Name:find("PlantArea") then
                            table.insert(areas, part)
                        end
                    end
                end
            end)
        end
        return areas
    end
    Logic.GetMyPlantAreas = GetMyPlantAreas

    local function CountPlantedSlots()
        local plantsFolder = GetPlantsFolder()
        if not plantsFolder then return 0 end
        local count = 0
        for _, plant in ipairs(plantsFolder:GetChildren()) do
            if plant:GetAttribute("UserId") == player.UserId then
                count = count + 1
            end
        end
        return count
    end
    Logic.CountPlantedSlots = CountPlantedSlots

    local function GetPlantedSeedCounts()
        local plantsFolder = GetPlantsFolder()
        local counts = {}
        local total = 0
        if not plantsFolder then return counts, total end
        for _, plant in ipairs(plantsFolder:GetChildren()) do
            if plant:GetAttribute("UserId") == player.UserId then
                local name = plant:GetAttribute("SeedName") or plant:GetAttribute("SeedTool") or "?"
                counts[name] = (counts[name] or 0) + 1
                total = total + 1
            end
        end
        return counts, total
    end
    Logic.GetPlantedSeedCounts = GetPlantedSeedCounts

    local function GetExistingPlantPositions()
        local plantsFolder = GetPlantsFolder()
        local occupied = {}
        if not plantsFolder then return occupied end
        for _, plant in ipairs(plantsFolder:GetChildren()) do
            local px, pz
            local posX = plant:GetAttribute("PosX")
            local posZ = plant:GetAttribute("PosZ")
            if posX and posZ then
                px, pz = posX, posZ
            else
                local ok, pivot = pcall(function() return plant:GetPivot() end)
                if ok and pivot then
                    px, pz = pivot.Position.X, pivot.Position.Z
                else
                    local ok2, pos = pcall(function()
                        return plant.PrimaryPart and plant.PrimaryPart.Position
                    end)
                    if ok2 and pos then
                        px, pz = pos.X, pos.Z
                    end
                end
            end
            if px and pz then
                table.insert(occupied, Vector2.new(px, pz))
            end
        end
        return occupied
    end

    local function IsTooClose(px, pz, posList, minDist)
        minDist = minDist or 1.5
        local md2 = minDist * minDist
        for _, p in ipairs(posList) do
            local dx = px - p.X
            local dz = pz - p.Y
            if dx*dx + dz*dz < md2 then
                return true
            end
        end
        return false
    end

    local function BuildValidPlantPositions(plantAreas, maxCount)
        maxCount = maxCount or 200
        local occupied = GetExistingPlantPositions()
        local MIN_DIST   = 1.5
        local STEP       = 1.5
        local candidates = {}

        for _, area in ipairs(plantAreas) do
            local cf  = area.CFrame
            local sz  = area.Size
            local halfX = sz.X / 2
            local halfZ = sz.Z / 2
            local margin = 0.5
            local lx = -halfX + margin
            while lx <= halfX - margin do
                local lz = -halfZ + margin
                while lz <= halfZ - margin do
                    local worldPt = cf:PointToWorldSpace(Vector3.new(lx, sz.Y / 2, lz))
                    local wx, wy, wz = worldPt.X, worldPt.Y, worldPt.Z
                    if not IsTooClose(wx, wz, occupied, MIN_DIST) then
                        table.insert(candidates, Vector3.new(wx, wy, wz))
                        table.insert(occupied, Vector2.new(wx, wz))
                    end
                    lz = lz + STEP
                end
                lx = lx + STEP
            end
        end

        for i = #candidates, 2, -1 do
            local j = math.random(1, i)
            candidates[i], candidates[j] = candidates[j], candidates[i]
        end

        local result = {}
        for i = 1, math.min(#candidates, maxCount) do
            result[i] = candidates[i]
        end
        return result
    end
    Logic.BuildValidPlantPositions = BuildValidPlantPositions

    local function GetNextSeedFromBackpack()
        local backpack = player:FindFirstChildOfClass("Backpack")
        if not backpack then return nil end

        local allowedSeeds = nil
        if States.autoPlantAllSeeds then
            allowedSeeds = nil
        else
            if #(States.autoPlantTargets or {}) == 0 then
                return nil
            end
            allowedSeeds = {}
            for _, name in ipairs(States.autoPlantTargets) do
                allowedSeeds[name] = true
            end
        end

        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                local seedName = tool:GetAttribute("SeedTool")
                if type(seedName) ~= "string" or seedName == "" then
                    local raw = tool:GetAttribute("SeedTool")
                    if raw ~= nil then
                        seedName = tool.Name
                    else
                        seedName = tool:GetAttribute("SeedName")
                        if type(seedName) ~= "string" or seedName == "" then
                            seedName = nil
                            for _, s in ipairs(SEEDS) do
                                if tool.Name == s or tool.Name == s .. " Seed" then
                                    seedName = s
                                    break
                                end
                            end
                        end
                    end
                end
                if seedName and (allowedSeeds == nil or allowedSeeds[seedName]) then
                    return {tool = tool, name = seedName}
                end
            end
        end
        return nil
    end
    Logic.GetNextSeedFromBackpack = GetNextSeedFromBackpack

    local _lastPlantFireTime = 0
    local function DoPlantFire(tool, seedName, hitPos)
        local now = os.clock()
        local wait = 0.05 - (now - _lastPlantFireTime)
        if wait > 0 then task.wait(wait) end

        local attr = tool:GetAttribute("SeedTool")
        if type(attr) == "string" and attr ~= "" then
            seedName = attr
        end

        local fired = false
        if Networking then
            local ok = pcall(function()
                Networking.Plant.PlantSeed:Fire(hitPos, seedName, tool)
            end)
            fired = ok
        end
        if not fired and PacketRemote then
            pcall(function()
                PacketRemote:FireServer(PACKET.PlantSeed, hitPos, seedName, tool)
            end)
            fired = true
        end
        _lastPlantFireTime = os.clock()
        return fired
    end
    Logic.DoPlantFire = DoPlantFire

    -- AUTO PLANT LOOP
    task.spawn(function()
        while _G._MiracleHubSession == SESSION do
            if not States.autoPlant then
                task.wait(0.5)
            else
                local plantAreas = GetMyPlantAreas()
                if #plantAreas == 0 then
                    if States.autoPlantNotify then
                        Notify("Auto Plant \226\154\160", "PlantArea tidak ditemukan di Plot " .. MY_PLOT_ID
                            .. ". Pastikan kamu di plotmu.", Colors.Warning, 5)
                    end
                    task.wait(5)
                else
                    local validPositions = BuildValidPlantPositions(plantAreas, 500)
                    if #validPositions == 0 then
                        if States.autoPlantNotify then
                            local slotCount = CountPlantedSlots()
                            Notify("Auto Plant",
                                "Tidak ada slot kosong di Plot " .. MY_PLOT_ID
                                .. " (" .. slotCount .. " tanaman ada). Harvest dulu lalu coba lagi.",
                                Colors.Warning, 5)
                        end
                        task.wait(5)
                    else
                        local planted = 0
                        local noSeed = false
                        local plantedLog = {}

                        for _, hitPos in ipairs(validPositions) do
                            if not States.autoPlant then break end
                            local seedEntry = GetNextSeedFromBackpack()
                            if not seedEntry then
                                noSeed = true
                                break
                            end

                            local ok = pcall(DoPlantFire, seedEntry.tool, seedEntry.name, hitPos)
                            if ok then
                                planted = planted + 1
                                plantedLog[seedEntry.name] = (plantedLog[seedEntry.name] or 0) + 1
                            end
                            task.wait(0.3)
                        end

                        if States.autoPlantNotify then
                            if planted > 0 then
                                local lines = {}
                                for name, cnt in pairs(plantedLog) do
                                    table.insert(lines, name .. " - " .. cnt)
                                end
                                table.sort(lines, function(a, b)
                                    local ca = tonumber(a:match("- (%d+)$")) or 0
                                    local cb = tonumber(b:match("- (%d+)$")) or 0
                                    return ca > cb
                                end)
                                NotifyStok(lines, Colors.Success, 8, "\240\159\140\177 Auto Plant (+" .. planted .. " ditanam)")
                            elseif noSeed then
                                Notify("Auto Plant", "Seed habis di backpack (sesuai filter).", Colors.Warning, 3)
                            end
                        end
                    end
                end
                task.wait(0.5)
            end
        end
    end)

    -- ====================== HOP MOVEMENT HELPERS ======================
    local NEAR_HOP_SIZE = 5
    local NEAR_HOP_WAIT = 0.10

    local function HopToNearPos(targetPos)
        local c = player.Character
        if not c then return end
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local dest = targetPos + Vector3.new(3, 2, 0)
        for _ = 1, 30 do
            local ch = player.Character
            if not ch then break end
            local r = ch:FindFirstChild("HumanoidRootPart")
            if not r then break end
            local curPos    = r.Position
            local remaining = (dest - curPos).Magnitude
            if remaining <= NEAR_HOP_SIZE then
                r.CFrame = CFrame.new(dest)
                break
            end
            local dir = (dest - curPos).Unit
            r.CFrame  = CFrame.new(curPos + dir * NEAR_HOP_SIZE)
            task.wait(NEAR_HOP_WAIT)
        end
    end
    Logic.HopToNearPos = HopToNearPos

    -- ====================== TOOL EQUIP HELPERS ======================
    local function IsToolEquipped(tool)
        if not tool then return false end
        local char = player.Character
        if not char then return false end
        return tool.Parent == char
    end
    Logic.IsToolEquipped = IsToolEquipped

    local function EquipTool(tool)
        if not tool then return false end
        local char = player.Character
        if not char then return false end
        if tool.Parent == char then return true end
        local bp = player:FindFirstChildOfClass("Backpack")
        if tool.Parent ~= bp then return false end
        local held = char:FindFirstChildOfClass("Tool")
        if held then
            held.Parent = bp
            task.wait(0.1)
        end
        tool.Parent = char
        task.wait(0.15)
        return tool.Parent == char
    end
    Logic.EquipTool = EquipTool

    local function GetWateringCanTool()
        local targets = States.wateringCanTargets or {}
        local hasTargets = #targets > 0
        local targetSet = {}
        for _, n in ipairs(targets) do targetSet[n] = true end

        local function checkTool(tool)
            if not (tool and tool:IsA("Tool")) then return false end
            local attr = tool:GetAttribute("WateringCan")
            if attr then
                local canName = type(attr) == "string" and attr ~= "" and attr or tool.Name
                if hasTargets and not targetSet[canName] then return false end
                return tool, canName
            end
            if tool.Name:lower():find("watering") then
                local canName = tool.Name
                if hasTargets and not targetSet[canName] then return false end
                return tool, canName
            end
            return false
        end

        if player.Character then
            local held = player.Character:FindFirstChildOfClass("Tool")
            local t, n = checkTool(held)
            if t then return t, n end
        end
        local bp = player:FindFirstChildOfClass("Backpack")
        if bp then
            if hasTargets then
                for _, targetName in ipairs(targets) do
                    for _, tool in ipairs(bp:GetChildren()) do
                        if tool:IsA("Tool") then
                            local attr = tool:GetAttribute("WateringCan")
                            local canName = type(attr) == "string" and attr ~= "" and attr or tool.Name
                            if canName == targetName then
                                return tool, canName
                            end
                        end
                    end
                end
            else
                for _, tool in ipairs(bp:GetChildren()) do
                    local t, n = checkTool(tool)
                    if t then return t, n end
                end
            end
        end
        return nil, nil
    end

    local function GetPlantWaterPos(plant)
        if plant.PrimaryPart then
            local p = plant.PrimaryPart.Position
            return Vector3.new(p.X, p.Y - 0.3, p.Z)
        end
        local ok, cf = pcall(function() return plant:GetPivot() end)
        if ok and cf then
            local p = cf.Position
            return Vector3.new(p.X, p.Y - 0.3, p.Z)
        end
        for _, d in ipairs(plant:GetDescendants()) do
            if d:IsA("BasePart") then
                return Vector3.new(d.Position.X, d.Position.Y - 0.3, d.Position.Z)
            end
        end
        return nil
    end
    Logic.GetPlantWaterPos = GetPlantWaterPos

    -- ACQUIRE HELPERS (find + equip)
    local function AcquireWateringCan()
        local tool, canName = GetWateringCanTool()
        if not tool or not canName then return nil, nil end
        if not IsToolEquipped(tool) then
            local ok = EquipTool(tool)
            if not ok then return nil, nil end
        end
        return tool, canName
    end
    Logic.AcquireWateringCan = AcquireWateringCan


    -- AUTO WATER LOOP
    local _waterCooldown = 0
    task.spawn(function()
        while _G._MiracleHubSession == SESSION do
            task.wait(0.5)
            if States.autoWater then
                local now = os.clock()
                if now >= _waterCooldown and Networking then
                    pcall(function()
                        local tool, canName = AcquireWateringCan()
                        if not tool or not canName then return end
                        local plants = GetPlantsFolder()
                        if not plants then return end

                        local watered = 0
                        for _, plant in ipairs(plants:GetChildren()) do
                            if States.autoWater and plant:IsA("Model") then
                                local hitPos = GetPlantWaterPos(plant)
                                if hitPos then
                                    local needsWater = plant:GetAttribute("NeedsWater")
                                    local waterLevel = plant:GetAttribute("WaterLevel")
                                    local shouldSkip = (needsWater == false) or (waterLevel ~= nil and waterLevel >= 1)
                                    if not shouldSkip then
                                        if not IsToolEquipped(tool) then
                                            local t2, cn2 = AcquireWateringCan()
                                            if not t2 then break end
                                            tool, canName = t2, cn2
                                        end

                                        HopToNearPos(hitPos)
                                        local ok = pcall(function()
                                            Networking.WateringCan.UseWateringCan:Fire(hitPos, canName, tool)
                                        end)
                                        if ok then
                                            watered = watered + 1
                                            task.wait(math.max(States.perFruitDelay or 0.05, 0.05))
                                        end
                                    end
                                end
                            end
                        end

                        if watered > 0 and States.notifyHarvest then
                            Notify("Auto Water \240\159\146\167", "Siram " .. watered .. " tanaman di Plot " .. MY_PLOT_ID, Colors.Electric, 3)
                        end
                    end)
                    _waterCooldown = os.clock() + math.max(States.harvestLoopDelay or 5, 1)
                elseif not Networking then
                    task.wait(3)
                end
            end
        end
    end)

    -- ====================== AUTO PLACE SPRINKLERS ======================
    --
    -- Pendekatan baru berdasarkan decompile + debug data real:
    --
    -- 1. Raycast dari atas ke bawah di titik-titik dalam PlantArea
    --    FilterType = Include, target = semua BasePart ber-tag "PlantArea" di plot kita
    --    hitPos = result.Position langsung (Y otomatis sesuai surface game, ~142.75)
    --
    -- 2. Fire: Networking.Place.PlaceSprinkler:Fire(hitPos, sprinklerName, tool, plotId)
    --    plotId = number dari "PlotXX" → XX
    --
    -- 3. Cek sprinkler existing via plot:FindFirstChild("Sprinklers") folder
    --    (diisi oleh SprinklerVisualizerController setelah server confirm)
    --
    -- 4. Cek too-close: jarak < 1 stud dari sprinkler model existing
    --
    -- 5. Coverage: hitung apakah titik-titik PlantArea sudah ter-cover radius sprinkler
    --    Radius dari SprinklerData (Common=20, Uncommon=25, Rare=30, Legendary=40, Super=55)

    local SPRINKLER_RADII = {
        ["Common Sprinkler"]    = 20,
        ["Uncommon Sprinkler"]  = 25,
        ["Rare Sprinkler"]      = 30,
        ["Legendary Sprinkler"] = 40,
        ["Super Sprinkler"]     = 55,
    }

    -- Ambil PlantArea BaseParts milik plot kita (pakai CollectionService + fallback manual)
    local function GetPlantAreaParts()
        local myPlot = GetMyPlot()
        if not myPlot then return {} end
        local parts = {}
        -- Primary: CollectionService tag "PlantArea"
        for _, part in ipairs(CollectionService:GetTagged("PlantArea")) do
            if part:IsA("BasePart") and part:IsDescendantOf(myPlot) then
                table.insert(parts, part)
            end
        end
        -- Fallback: scan nama
        if #parts == 0 then
            for _, desc in ipairs(myPlot:GetDescendants()) do
                if desc:IsA("BasePart") and desc.Name:find("PlantArea") then
                    table.insert(parts, desc)
                end
            end
        end
        return parts
    end
    Logic.GetPlantAreaParts = GetPlantAreaParts

    -- Raycast dari atas ke bawah di (X, Z) tertentu, return hitPos atau nil
    -- FilterDescendantsInstances = array of PlantArea BaseParts (bukan QueryDescendants string!)
    local function RaycastToPlantSurface(px, pz, plantAreaParts)
        if not plantAreaParts or #plantAreaParts == 0 then return nil end

        -- Coba raycast dari berbagai ketinggian (plot bisa di Y berbeda)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        params.FilterDescendantsInstances = plantAreaParts
        for _, startY in ipairs({500, 300, 1000, 2000}) do
            local result = workspace:Raycast(
                Vector3.new(px, startY, pz),
                Vector3.new(0, -(startY + 500), 0),
                params
            )
            if result then
                return result.Position
            end
        end

        -- Fallback: pakai Y dari surface area terdekat secara XZ
        -- (kalau raycast gagal total, pakai posisi center area + offset kecil ke atas)
        local bestArea = nil
        local bestDist = math.huge
        for _, area in ipairs(plantAreaParts) do
            local apos = area.Position
            local dx = px - apos.X
            local dz = pz - apos.Z
            local d = dx*dx + dz*dz
            if d < bestDist then
                bestDist = d
                bestArea = area
            end
        end
        if bestArea then
            -- Surface Y = area.Position.Y + area.Size.Y/2
            local surfaceY = bestArea.Position.Y + bestArea.Size.Y / 2
            return Vector3.new(px, surfaceY, pz)
        end

        return nil
    end
    Logic.RaycastToPlantSurface = RaycastToPlantSurface

    -- Ambil posisi world semua sprinkler yang sudah terpasang di plot kita.
    -- Scan plot:GetDescendants() untuk Model yang namanya ada di SPRINKLER_RADII
    -- atau punya attribute "Sprinkler" — persis seperti cara game LocalScript sendiri
    -- (IsTooCloseToSprinkler scan plot:GetDescendants(), bukan subfolder tertentu).
    -- Jangan pakai FindFirstChild("Sprinklers") karena folder itu belum tentu exist.
    local function GetExistingSprinklerPositions()
        local myPlot = GetMyPlot()
        local positions = {}
        if not myPlot then return positions end

        -- PATCHED: Scan Sprinklers folder langsung (selalu ada, confirmed dari scan data).
        -- Komentar lama "belum tentu exist" ternyata salah — folder ini SELALU ada di plot.
        -- Ini jauh lebih efisien daripada GetDescendants() yang scan ribuan objek.
        local sprinklerFolder = myPlot:FindFirstChild("Sprinklers")
        local items = sprinklerFolder and sprinklerFolder:GetChildren() or myPlot:GetDescendants()

        for _, model in ipairs(items) do
            if model:IsA("Model") then
                -- PATCHED: model.Name = UUID (bukan "Common Sprinkler"), jadi SPRINKLER_RADII[model.Name] selalu nil.
                -- Atribut "Sprinkler" juga tidak ada di game.
                -- Yang benar dari scan data: Attr.SprinklerId dan Attr.SprinklerName.
                local sprinklerId   = model:GetAttribute("SprinklerId")
                local sprinklerName = model:GetAttribute("SprinklerName")
                local isSprinkler   = sprinklerId ~= nil
                    or (sprinklerName ~= nil and SPRINKLER_RADII[sprinklerName] ~= nil)
                    or SPRINKLER_RADII[model.Name] ~= nil  -- fallback lama (just in case)

                if isSprinkler then
                    local wpos
                    local pp = model.PrimaryPart
                    if pp then
                        wpos = pp.Position
                    else
                        local ok, piv = pcall(function() return model:GetPivot() end)
                        if ok and piv then wpos = piv.Position end
                    end
                    -- PATCHED: fallback ke child "Build" (struktur model sprinkler dari scan data [488])
                    if not wpos then
                        local build = model:FindFirstChild("Build")
                        if build then
                            if build:IsA("BasePart") then
                                wpos = build.Position
                            else
                                local ok2, piv2 = pcall(function() return build:GetPivot() end)
                                if ok2 and piv2 then wpos = piv2.Position end
                            end
                        end
                    end
                    if wpos then
                        table.insert(positions, Vector2.new(wpos.X, wpos.Z))
                    end
                end
            end
        end
        return positions
    end
    Logic.GetExistingSprinklerPositions = GetExistingSprinklerPositions

    -- Cek apakah hitPos terlalu dekat sprinkler existing (< 1 stud, persis seperti game)
    local function IsTooCloseToExistingSprinkler(hitPos, existingPositions)
        for _, sp in ipairs(existingPositions) do
            local dx = hitPos.X - sp.X
            local dz = hitPos.Z - sp.Y
            if dx*dx + dz*dz < 1 then  -- < 1 stud^2 = < 1 stud distance
                return true
            end
        end
        return false
    end

    -- Ambil sprinkler tool dari backpack / karakter
    local function GetSprinklerTool()
        local targets = States.sprinklerTargets or {}
        local hasTargets = #targets > 0

        -- PATCHED: cek "Sprinkler" (lama) DAN "SprinklerName" (atribut baru dari game)
        -- Kalau salah satu ada, tool terdeteksi.
        local function resolveSprinklerName(tool)
            local attr = tool:GetAttribute("Sprinkler") or tool:GetAttribute("SprinklerName")
            if not attr then return nil end
            return type(attr) == "string" and attr ~= "" and attr or tool.Name
        end

        local function isValidTool(tool)
            if not (tool and tool:IsA("Tool")) then return false end
            local sName = resolveSprinklerName(tool)
            if not sName then return false end
            if hasTargets then
                for _, t in ipairs(targets) do
                    if t == sName then return tool, sName end
                end
                return false
            end
            return tool, sName
        end

        -- Cek equipped dulu
        if player.Character then
            local held = player.Character:FindFirstChildOfClass("Tool")
            local t, n = isValidTool(held)
            if t then return t, n end
        end

        -- Cek backpack
        local bp = player:FindFirstChildOfClass("Backpack")
        if bp then
            if hasTargets then
                for _, targetName in ipairs(targets) do
                    for _, tool in ipairs(bp:GetChildren()) do
                        if tool:IsA("Tool") then
                            local sName = resolveSprinklerName(tool)
                            if sName == targetName then return tool, sName end
                        end
                    end
                end
            else
                for _, tool in ipairs(bp:GetChildren()) do
                    local t, n = isValidTool(tool)
                    if t then return t, n end
                end
            end
        end
        return nil, nil
    end

    local function AcquireSprinklerTool()
        local tool, sprinklerName = GetSprinklerTool()
        if not tool or not sprinklerName then return nil, nil end
        if not IsToolEquipped(tool) then
            if not EquipTool(tool) then return nil, nil end
        end
        return tool, sprinklerName
    end
    Logic.AcquireSprinklerTool = AcquireSprinklerTool

    -- Hitung plotId dari nama plot ("PlotXX" → XX)
    local function GetPlotId(plot)
        if not plot then return nil end
        return tonumber(string.match(plot.Name, "%d+"))
    end

    -- Generate kandidat titik (XZ) yang merata di seluruh PlantArea
    -- step = spasi grid; lebih kecil = lebih presisi tapi lebih banyak titik
    local function GetPlantAreaCandidatePoints(plantAreaParts, step)
        step = step or 8
        local candidates = {}
        for _, area in ipairs(plantAreaParts) do
            local cf   = area.CFrame
            local sz   = area.Size
            local halfX = sz.X / 2
            local halfZ = sz.Z / 2
            local margin = 1.0
            local lx = -halfX + margin
            while lx <= halfX - margin do
                local lz = -halfZ + margin
                while lz <= halfZ - margin do
                    local worldPt = cf:PointToWorldSpace(Vector3.new(lx, sz.Y / 2, lz))
                    table.insert(candidates, Vector2.new(worldPt.X, worldPt.Z))
                    lz = lz + step
                end
                lx = lx + step
            end
        end
        return candidates
    end

    -- Cek apakah titik (Vector2 XZ) ter-cover oleh salah satu sprinkler
    local function IsPointCoveredBySprinkler(point, sprinklerPositions, radius)
        for _, sp in ipairs(sprinklerPositions) do
            local dx = point.X - sp.X
            local dz = point.Y - sp.Y
            if dx*dx + dz*dz <= radius * radius then
                return true
            end
        end
        return false
    end

    -- Hitung coverage: berapa persen titik PlantArea sudah ter-cover
    local function CalculateCoverage(candidatePoints, sprinklerPositions, radius)
        if #candidatePoints == 0 then return 1.0 end
        local covered = 0
        for _, pt in ipairs(candidatePoints) do
            if IsPointCoveredBySprinkler(pt, sprinklerPositions, radius) then
                covered = covered + 1
            end
        end
        return covered / #candidatePoints
    end
    Logic.CalculateCoverage = CalculateCoverage

    -- Fire single placement: coba Networking dulu, fallback ke PacketRemote (ID=20).
    -- Dual-path ini handle kasus Networking nil (executor tertentu gagal require module).
    -- Return true jika berhasil (sprinkler count bertambah di folder plot).
    local _lastSprinklerFire = 0
    local function DoPlaceSprinklerAt(px, pz, plantAreaParts, tool, sprinklerName)
        -- Perlu minimal salah satu channel komunikasi
        if not Networking and not PacketRemote then return false end

        -- Rate limit: minimal 0.6s antar fire (server cooldown ~0.5s, +margin)
        local now = os.clock()
        local gap = 0.6 - (now - _lastSprinklerFire)
        if gap > 0 then task.wait(gap) end

        -- Pastikan tool masih valid di inventory
        if not (tool and tool.Parent) then return false end

        -- Equip tool (server butuh tool instance yang valid & equipped)
        if not IsToolEquipped(tool) then
            if not EquipTool(tool) then return false end
            task.wait(0.2)
        end
        if not IsToolEquipped(tool) then return false end

        -- Raycast ke bawah dari (px, pz) untuk dapat hitPos surface yang akurat
        -- Server pakai posisi ini langsung, jadi Y harus tepat dari surface
        local hitPos = RaycastToPlantSurface(px, pz, plantAreaParts)
        if not hitPos then return false end

        -- plotId harus number (NumberU8), bukan string
        local plotId = tonumber(MY_PLOT_ID)
        if not plotId then return false end

        -- Hitung existing count sebelum fire untuk verifikasi
        local countBefore = #GetExistingSprinklerPositions()

        -- === PATH 1: Networking module (cara ideal, kalau tersedia) ===
        -- Fire: Networking.Place.PlaceSprinkler(Vector3F32, String, Instance, NumberU8)
        local fired = false
        if Networking then
            pcall(function()
                Networking.Place.PlaceSprinkler:Fire(hitPos, sprinklerName, tool, plotId)
                fired = true
            end)
        end

        -- === PATH 2: PacketRemote fallback (PACKET.PlaceSprinkler = 20) ===
        -- Dipakai kalau Networking nil atau Fire() gagal.
        -- Format dari buffer capture manual: (packetId, hitPos, sprinklerName, tool, plotId)
        if not fired and PacketRemote then
            pcall(function()
                PacketRemote:FireServer(PACKET.PlaceSprinkler, hitPos, sprinklerName, tool, plotId)
                fired = true
            end)
        end

        if not fired then return false end

        _lastSprinklerFire = os.clock()

        -- Tunggu server konfirmasi (sprinkler muncul di folder plot)
        -- PATCHED: 0.7s → 1.2s untuk antisipasi latency tinggi dan replication delay
        task.wait(1.2)

        local newPos = GetExistingSprinklerPositions()
        return #newPos > countBefore
    end
    Logic.DoPlaceSprinklerAt = DoPlaceSprinklerAt

    -- AUTO SPRINKLER LOOP
    -- Strategy: grid coverage per PlantArea, skip titik yang sudah ter-cover
    -- Cooldown panjang setelah satu sesi placement selesai
    local _sprinklerLoopCooldown = 0
    task.spawn(function()
        while _G._MiracleHubSession == SESSION do
            task.wait(0.5)
            if not States.autoSprinkler then continue end

            local now = os.clock()
            if now < _sprinklerLoopCooldown then continue end

            pcall(function()
                -- 1. Acquire tool
                local tool, sprinklerName = AcquireSprinklerTool()
                if not tool or not sprinklerName then
                    Notify("Auto Sprinkler", "\226\154\160 Tidak ada sprinkler tool di backpack!", Colors.Warning, 3)
                    _sprinklerLoopCooldown = os.clock() + 10
                    return
                end

                local radius = SPRINKLER_RADII[sprinklerName] or 20

                -- 2. Ambil PlantArea parts
                local plantAreaParts = GetPlantAreaParts()
                if #plantAreaParts == 0 then
                    Notify("Auto Sprinkler", "\226\154\160 PlantArea tidak ditemukan di Plot " .. MY_PLOT_ID, Colors.Warning, 3)
                    _sprinklerLoopCooldown = os.clock() + 15
                    return
                end

                -- 3. Generate kandidat titik (grid step = radius/2 agar coverage cukup)
                local step = math.max(math.floor(radius / 2), 4)
                local candidatePoints = GetPlantAreaCandidatePoints(plantAreaParts, step)
                if #candidatePoints == 0 then
                    _sprinklerLoopCooldown = os.clock() + 15
                    return
                end

                -- 4. Ambil posisi sprinkler existing sebagai Vector2
                local existingSpPos = GetExistingSprinklerPositions()

                -- 5. Cek coverage saat ini
                local coverage = CalculateCoverage(candidatePoints, existingSpPos, radius)
                if coverage >= 0.95 then
                    -- Plot sudah ter-cover ≥95%, tidak perlu pasang lagi
                    _sprinklerLoopCooldown = os.clock() + 30
                    return
                end

                -- 6. Cari titik yang belum ter-cover, sort dari yang paling central
                local uncoveredPoints = {}
                for _, pt in ipairs(candidatePoints) do
                    if not IsPointCoveredBySprinkler(pt, existingSpPos, radius) then
                        table.insert(uncoveredPoints, pt)
                    end
                end

                -- 7. Greedy placement: pilih titik yang cover paling banyak uncovered sekaligus
                local placed  = 0
                local failed  = 0
                local placedPositions = {} -- track posisi yang baru kita pasang sesi ini

                -- Gabungkan existing + baru untuk coverage check akumulatif
                local allSprinklerPos = {}
                for _, p in ipairs(existingSpPos) do table.insert(allSprinklerPos, p) end

                while #uncoveredPoints > 0 and States.autoSprinkler do
                    -- Re-acquire tool tiap iterasi (bisa habis)
                    local curTool, curName = AcquireSprinklerTool()
                    if not curTool then
                        Notify("Auto Sprinkler", "\226\154\160 Sprinkler habis di backpack!", Colors.Warning, 3)
                        break
                    end
                    tool, sprinklerName = curTool, curName
                    radius = SPRINKLER_RADII[sprinklerName] or 20

                    -- Greedy: cari kandidat yang cover paling banyak uncovered
                    local bestPt    = nil
                    local bestCount = 0
                    for _, cand in ipairs(candidatePoints) do
                        -- Skip jika terlalu dekat dengan yang sudah ada
                        local tooClose = false
                        for _, sp in ipairs(allSprinklerPos) do
                            local dx = cand.X - sp.X
                            local dz = cand.Y - sp.Y
                            if dx*dx + dz*dz < 1 then tooClose = true; break end
                        end
                        if not tooClose then
                            local count = 0
                            local r2 = radius * radius
                            for _, pt in ipairs(uncoveredPoints) do
                                local dx = cand.X - pt.X
                                local dz = cand.Y - pt.Y
                                if dx*dx + dz*dz <= r2 then count = count + 1 end
                            end
                            if count > bestCount then
                                bestCount = count
                                bestPt    = cand
                            end
                        end
                    end

                    -- Tidak ada kandidat yang bisa cover apapun → stop
                    if not bestPt or bestCount == 0 then break end

                    -- Place sprinkler di bestPt
                    local success = false
                    local ok = pcall(function()
                        success = DoPlaceSprinklerAt(bestPt.X, bestPt.Y, plantAreaParts, tool, sprinklerName)
                    end)

                    if ok and success then
                        placed = placed + 1
                        failed = 0
                        -- Update coverage tracking
                        local newSp = Vector2.new(bestPt.X, bestPt.Y)
                        table.insert(allSprinklerPos, newSp)
                        table.insert(placedPositions, newSp)
                        -- Filter uncovered
                        local newUncovered = {}
                        local r2 = radius * radius
                        for _, pt in ipairs(uncoveredPoints) do
                            local dx = bestPt.X - pt.X
                            local dz = bestPt.Y - pt.Y
                            if dx*dx + dz*dz > r2 then
                                table.insert(newUncovered, pt)
                            end
                        end
                        uncoveredPoints = newUncovered
                    else
                        failed = failed + 1
                        if failed >= 3 then
                            task.wait(1)
                            failed = 0
                            -- Refresh existing positions (mungkin ada perubahan)
                            local refreshed = GetExistingSprinklerPositions()
                            allSprinklerPos = refreshed
                            for _, p in ipairs(placedPositions) do
                                table.insert(allSprinklerPos, p)
                            end
                        end
                    end
                end

                -- 8. Notify hasil
                if placed > 0 then
                    Notify("Auto Sprinkler \240\159\140\191",
                        "Pasang " .. placed .. " sprinkler di Plot " .. MY_PLOT_ID,
                        Colors.Success, 5)
                elseif #uncoveredPoints == 0 or coverage >= 0.95 then
                    -- Sudah ter-cover, tidak ada notif (spam)
                else
                    Notify("Auto Sprinkler",
                        "Tidak ada sprinkler yang berhasil dipasang.",
                        Colors.Warning, 3)
                end
            end)

            _sprinklerLoopCooldown = os.clock() + 15
        end
    end)

    -- ====================== SELL HELPERS + LOOP ======================
    local function PreviewSellAll()
        if not Networking then return nil end
        local ok, result = pcall(function() return Networking.NPCS.PreviewSellAll:Fire() end)
        return ok and result or nil
    end
    Logic.PreviewSellAll = PreviewSellAll

    local function SellAllFruits()
        if not Networking then return nil end
        local ok, result = pcall(function() return Networking.NPCS.SellAll:Fire() end)
        return ok and result or nil
    end
    Logic.SellAllFruits = SellAllFruits

    local function SellFruitById(fruitId)
        if not Networking then return nil end
        local ok, result = pcall(function() return Networking.NPCS.SellFruit:Fire(fruitId) end)
        return ok and result or nil
    end
    Logic.SellFruitById = SellFruitById

    local function UseDailyDeal()
        if not Networking then return nil end
        local ok, result = pcall(function() return Networking.NPCS.UseDailyDealAll:Fire() end)
        return ok and result or nil
    end
    Logic.UseDailyDeal = UseDailyDeal

    local function ShouldKeepFruit(tool)
        local mut = GetMutation(tool)
        if States.keepMutations and mut ~= "" and mut ~= "None" then return true end
        local keepMuts = States.sellKeepMutation or {}
        if type(keepMuts) == "table" and #keepMuts > 0 and mut ~= "" and mut ~= "None" then
            if table.find(keepMuts, mut) then return true end
        end
        return false
    end
    Logic.ShouldKeepFruit = ShouldKeepFruit

    local function NeedsSelectiveSell()
        local keepMuts = States.sellKeepMutation or {}
        if not States.keepMutations and (type(keepMuts) ~= "table" or #keepMuts == 0) then
            return false
        end
        return true
    end

    task.spawn(function()
        while _G._MiracleHubSession == SESSION do
            task.wait(States.sellLoopDelay or 3)
            if States.autoSell then
                if not Networking then
                    Notify("Auto Sell", "Networking module tidak ditemukan!", Colors.Error)
                    task.wait(5)
                else
                    pcall(function()
                        local fruits = {}
                        for _, tool in ipairs(player.Backpack:GetChildren()) do
                            if tool:GetAttribute("HarvestedFruit") or tool:GetAttribute("FruitName") then
                                table.insert(fruits, tool)
                            end
                        end
                        if player.Character then
                            local held = player.Character:FindFirstChildOfClass("Tool")
                            if held and (held:GetAttribute("HarvestedFruit") or held:GetAttribute("FruitName")) then
                                table.insert(fruits, held)
                            end
                        end
                        if #fruits == 0 then return end

                        if States.autoUseDailyDeal then
                            pcall(function() return Networking.NPCS.CheckDailyDeal:Fire() end)
                            local dealResult = UseDailyDeal()
                            if dealResult and dealResult.Success then
                                if States.notifySell then
                                    Notify("Daily Deal! \240\159\140\136", "Sold " .. (dealResult.SoldCount or 0) .. " buah = " .. tostring(dealResult.SellPrice or 0) .. "\194\162 (5x bonus!)", Colors.Success, 10)
                                end
                                return
                            end
                        end

                        if NeedsSelectiveSell() then
                            local soldCount = 0
                            local skippedCount = 0
                            for _, tool in ipairs(fruits) do
                                if States.autoSell then
                                    if ShouldKeepFruit(tool) then
                                        skippedCount = skippedCount + 1
                                    else
                                        local fruitId = tool:GetAttribute("Id")
                                        if fruitId then
                                            local result = SellFruitById(fruitId)
                                            if result and result.Success then
                                                soldCount = soldCount + 1
                                            elseif result and result.Reason == "Favorited" then
                                                skippedCount = skippedCount + 1
                                            end
                                        end
                                    end
                                end
                                task.wait(States.sellDelay or 0.1)
                            end
                            if States.notifySell and soldCount > 0 then
                                Notify("Auto Sell", "Sold " .. soldCount .. " buah (skip " .. skippedCount .. " mutation)", Colors.Gold, 10)
                            end
                        else
                            local result = SellAllFruits()
                            if result and result.Success then
                                if States.notifySell then
                                    Notify("Auto Sell", "Sold " .. (result.SoldCount or #fruits) .. " buah = " .. tostring(result.SellPrice or 0) .. "\194\162", Colors.Gold, 10)
                                end
                            elseif result then
                                if States.notifySell then
                                    Notify("Auto Sell", "Gagal: " .. tostring(result.Reason or "unknown"), Colors.Error)
                                end
                            end
                        end
                    end)
                end
            end
        end
    end)

    -- ====================== SHOP STOCK + BUY HELPERS ======================
    local function GetSeedStock(seedName)
        local sv = ReplicatedStorage:FindFirstChild("StockValues")
        if not sv then return 0 end
        local ss = sv:FindFirstChild("SeedShop")
        if not ss then return 0 end
        local items = ss:FindFirstChild("Items")
        if not items then return 0 end
        local stockVal = items:FindFirstChild(seedName)
        return stockVal and stockVal.Value or 0
    end
    Logic.GetSeedStock = GetSeedStock

    local function BuySeedPacket(seedName, quantity)
        quantity = quantity or 1
        if Networking then
            local shop = rawget(Networking, "SeedShop")
            if shop then
                local purchase = rawget(shop, "Purchase") or rawget(shop, "BuySeed") or rawget(shop, "PurchaseSeed")
                if purchase and purchase.Fire then
                    pcall(function() purchase:Fire(seedName, quantity) end)
                    return true
                end
            end
        end
        if not PacketRemote then
            local sm = ReplicatedStorage:FindFirstChild("SharedModules")
            PacketRemote = sm and sm:FindFirstChild("Packet") and sm.Packet:FindFirstChild("RemoteEvent")
        end
        if not PacketRemote then return false end
        pcall(function() PacketRemote:FireServer(PACKET.PurchaseSeed, seedName, quantity) end)
        return true
    end
    Logic.BuySeedPacket = BuySeedPacket

    local function GetGearStock(gearName)
        local sv = ReplicatedStorage:FindFirstChild("StockValues")
        if not sv then return 0 end
        local gs = sv:FindFirstChild("GearShop")
        if not gs then return 0 end
        local items = gs:FindFirstChild("Items")
        if not items then return 0 end
        local stockVal = items:FindFirstChild(gearName)
        return stockVal and stockVal.Value or 0
    end
    Logic.GetGearStock = GetGearStock

    local function BuyGearPacket(gearName, quantity)
        quantity = quantity or 1
        if Networking then
            local shop = rawget(Networking, "GearShop")
            if shop then
                local purchase = rawget(shop, "Purchase") or rawget(shop, "BuyGear") or rawget(shop, "PurchaseGear")
                if purchase and purchase.Fire then
                    pcall(function() purchase:Fire(gearName, quantity) end)
                    return true
                end
            end
        end
        if not PacketRemote then
            local sm = ReplicatedStorage:FindFirstChild("SharedModules")
            PacketRemote = sm and sm:FindFirstChild("Packet") and sm.Packet:FindFirstChild("RemoteEvent")
        end
        if not PacketRemote then return false end
        pcall(function() PacketRemote:FireServer(PACKET.EquipGear, gearName, quantity) end)
        return true
    end
    Logic.BuyGearPacket = BuyGearPacket

    local function GetCrateStock(crateName)
        local sv = ReplicatedStorage:FindFirstChild("StockValues")
        if not sv then return 0 end
        local cs = sv:FindFirstChild("CrateShop")
        if not cs then return 0 end
        local items = cs:FindFirstChild("Items")
        if not items then return 0 end
        local stockVal = items:FindFirstChild(crateName)
        return stockVal and stockVal.Value or 0
    end
    Logic.GetCrateStock = GetCrateStock

    local function BuyCratePacket(crateName, quantity)
        quantity = quantity or 1
        if Networking then
            local shop = rawget(Networking, "CrateShop")
            if shop then
                local purchase = rawget(shop, "Purchase") or rawget(shop, "BuyCrate") or rawget(shop, "PurchaseCrate")
                if purchase and purchase.Fire then
                    pcall(function() purchase:Fire(crateName, quantity) end)
                    return true
                end
            end
        end
        if not PacketRemote then
            local sm = ReplicatedStorage:FindFirstChild("SharedModules")
            PacketRemote = sm and sm:FindFirstChild("Packet") and sm.Packet:FindFirstChild("RemoteEvent")
        end
        if not PacketRemote then return false end
        pcall(function() PacketRemote:FireServer(PACKET.PurchaseCrate, crateName, quantity) end)
        return true
    end
    Logic.BuyCratePacket = BuyCratePacket

    local function OpenCrateViaNetworking(crateName)
        if Networking then
            local crateNS = rawget(Networking, "Crate")
            if crateNS then
                local openFn = rawget(crateNS, "OpenCrate")
                if openFn and openFn.Fire then
                    local ok, result = pcall(function()
                        return openFn:Fire(crateName)
                    end)
                    if ok and result then return result end
                    return ok
                end
            end
        end
        if PacketRemote then
            pcall(function() PacketRemote:FireServer(PACKET.OpenCrate, crateName) end)
            return true
        end
        return false
    end
    Logic.OpenCrateViaNetworking = OpenCrateViaNetworking

    local function GetCratesInInventory()
        local found = {}
        for _, tool in ipairs(player.Backpack:GetChildren()) do
            local crateName = tool:GetAttribute("Crate")
            if crateName then
                table.insert(found, {tool = tool, name = crateName})
            end
        end
        if player.Character then
            local held = player.Character:FindFirstChildOfClass("Tool")
            if held and held:GetAttribute("Crate") then
                table.insert(found, {tool = held, name = held:GetAttribute("Crate")})
            end
        end
        return found
    end
    Logic.GetCratesInInventory = GetCratesInInventory

    -- ====================== FAILED SOUND MUTE ======================
    local _sfxMuteConn = nil
    local function MuteSFX_Failed()
        local ss = game:GetService("SoundService")
        local sfx = ss:FindFirstChild("SFX")
        local failedSnd = sfx and sfx:FindFirstChild("Failed")
        if not failedSnd then return end
        failedSnd.Volume = 0
        failedSnd.RollOffMaxDistance = 0
        if _sfxMuteConn then
            _sfxMuteConn:Disconnect()
            _sfxMuteConn = nil
        end
        _sfxMuteConn = failedSnd:GetPropertyChangedSignal("Volume"):Connect(function()
            if failedSnd.Volume ~= 0 then
                failedSnd.Volume = 0
            end
        end)
    end
    Logic.MuteSFX_Failed = MuteSFX_Failed
    Logic.GetSfxMuteConn = function() return _sfxMuteConn end
    Logic.ClearSfxMuteConn = function()
        if _sfxMuteConn then _sfxMuteConn:Disconnect() _sfxMuteConn = nil end
    end
    pcall(MuteSFX_Failed)
    task.spawn(function()
        local ss = game:GetService("SoundService")
        local sfx = ss:WaitForChild("SFX", 15)
        if sfx then
            local failedSnd = sfx:WaitForChild("Failed", 10)
            if failedSnd then
                pcall(MuteSFX_Failed)
            end
        end
    end)

    -- ====================== AUTO BUY SEED LOOP ======================
    -- _notifiedEmpty[seedName]  = true     → "out of stock" notif already sent this cycle
    -- _notifEmptyTime[seedName] = number   → rate-limit timestamp for "out of stock" notif
    -- _notifBuySent[seedName]   = true     → "buying" notif already sent this restock cycle
    --                             nil/false → not yet sent, will fire on first purchase
    -- _notifBuySent is reset ONLY by the Changed event (new restock from server),
    -- not by toggle ON — guaranteeing exactly 1 notif per restock cycle.
    --
    -- BATCHED SUMMARY NOTIF:
    -- Alih-alih 1 notif per seed (bisa 30+ sekaligus), satu notif ringkasan
    -- yang hidup selama sesi beli berlangsung dan di-update tiap loop.
    -- _buyHandle          = handle Notify yang sedang aktif (loading toast)
    -- _buyHandleSeeds     = set seed yang sedang dibeli (untuk label)
    -- _buyBatchOOS        = set seed yang out-of-stock tapi belum dirangkum
    -- _buyOOSHandle       = handle Notify "out of stock" summary yang aktif
    local _notifiedEmpty  = {}
    local _notifEmptyTime = {}   -- timestamp terakhir notif OOS per seed
    local _notifBuySent   = {}   -- flag: notif "buying" sudah terkirim sesi ini
    local _notifBuyTime   = {}   -- timestamp terakhir notif "buying" per seed
    local NOTIF_EMPTY_COOLDOWN = 3  -- cooldown detik antar notif OOS per seed
    local NOTIF_BUY_COOLDOWN   = 3  -- cooldown detik antar notif "buying" per seed (sama dengan OOS)

    -- Batched buy summary state
    local _buyHandle    = nil  -- handle notif ringkasan "sedang beli"
    local _buyOOSHandle = nil  -- handle notif ringkasan "out of stock"

    -- Called when toggle is turned ON or targets change.
    -- Reset KEDUA flag (OOS & buying) supaya notif bisa muncul lagi setelah toggle ON.
    -- Cooldown timestamp (_notifEmptyTime & _notifBuyTime) TIDAK di-clear —
    -- ini yang menjaga rate-limit sehingga spam toggle tidak langsung tembak notif.
    local function ResetNotifiedEmpty()
        table.clear(_notifiedEmpty)
        table.clear(_notifBuySent)
        -- _notifEmptyTime & _notifBuyTime sengaja tidak di-clear → cooldown tetap jalan
    end
    Logic.ResetNotifiedEmpty = ResetNotifiedEmpty

    -- Watch for restocks from server: when stock changes to > 0 (new restock),
    -- reset all flags for that seed so buy & out-of-stock notifs fire fresh next cycle.
    pcall(function()
        local sv = ReplicatedStorage:WaitForChild("StockValues", 10)
        if not sv then return end
        local ss = sv:WaitForChild("SeedShop", 10)
        if not ss then return end
        local items = ss:WaitForChild("Items", 10)
        if not items then return end
        local function watchChild(child)
            if not child:IsA("NumberValue") then return end
            child.Changed:Connect(function(newVal)
                if newVal > 0 then
                    -- New restock → reset semua flag & timestamp, notif siap tembak lagi
                    _notifiedEmpty[child.Name]  = nil
                    _notifEmptyTime[child.Name] = nil
                    _notifBuySent[child.Name]   = nil
                    _notifBuyTime[child.Name]   = nil
                end
            end)
        end
        items.ChildAdded:Connect(function(child) watchChild(child) end)
        for _, child in ipairs(items:GetChildren()) do
            watchChild(child)
        end
    end)

    task.spawn(function()
        while _G._MiracleHubSession == SESSION do
            task.wait(math.max(States.shopLoopDelay or 0.5, 0.1))
            if States.autoBuySeed then
                pcall(function()
                    local items = ReplicatedStorage:FindFirstChild("StockValues")
                        and ReplicatedStorage.StockValues:FindFirstChild("SeedShop")
                        and ReplicatedStorage.StockValues.SeedShop:FindFirstChild("Items")
                    local targets = {}
                    if States.autoBuyAll then
                        if not items then return end
                        for _, stockVal in ipairs(items:GetChildren()) do
                            if stockVal:IsA("NumberValue") then
                                table.insert(targets, stockVal.Name)
                            end
                        end
                    else
                        targets = States.autoBuySeedTargets or {}
                        if #targets == 0 then return end
                    end
                    -- ── Batch notif: kumpulkan seed yang perlu notif di loop ini ──
                    local _loopBought = {}  -- seed baru dibeli yang belum pernah notif (atau cooldown habis)
                    local _loopOOS    = {}  -- seed OOS yang belum pernah notif (atau cooldown habis)
                    local now = os.clock()

                    for _, seedName in ipairs(targets) do
                        if States.autoBuySeed then
                            local stock = GetSeedStock(seedName)
                            if stock > 0 then
                                -- Stock ada → clear flag OOS, beli
                                _notifiedEmpty[seedName] = false
                                _notifEmptyTime[seedName] = nil
                                -- Notif "buying" hanya jika: belum pernah notif sesi ini
                                -- DAN cooldown NOTIF_BUY_COOLDOWN detik sejak notif terakhir sudah lewat
                                -- (persis logika OOS: flag + timestamp cooldown)
                                if not _notifBuySent[seedName] then
                                    local lastT = _notifBuyTime[seedName] or 0
                                    if now - lastT >= NOTIF_BUY_COOLDOWN then
                                        _notifBuySent[seedName] = true
                                        _notifBuyTime[seedName] = now
                                        table.insert(_loopBought, seedName)
                                    end
                                end
                                BuySeedPacket(seedName, 1)
                                task.wait(States.buyDelay or 0.05)
                            else
                                -- OOS → notif hanya jika belum notif DAN cooldown sudah lewat
                                if not _notifiedEmpty[seedName] then
                                    local lastT = _notifEmptyTime[seedName] or 0
                                    if now - lastT >= NOTIF_EMPTY_COOLDOWN then
                                        _notifiedEmpty[seedName] = true
                                        _notifEmptyTime[seedName] = now
                                        table.insert(_loopOOS, seedName)
                                    end
                                end
                            end
                        end
                    end

                    -- ── Satu notif ringkasan "buying" ──
                    if States.notifyBuy and #_loopBought > 0 then
                        local label
                        if #_loopBought == 1 then
                            label = _loopBought[1]
                        elseif #_loopBought <= 3 then
                            label = table.concat(_loopBought, ", ")
                        else
                            label = #_loopBought .. " seeds"
                        end
                        if _buyHandle then pcall(function() _buyHandle.Dismiss() end) end
                        _buyHandle = Notify("Auto Buy", "Buying: " .. label, Colors.Success, 4)
                    end

                    -- ── Satu notif ringkasan "out of stock" ──
                    if States.notifyBuy and #_loopOOS > 0 then
                        local oosLabel
                        if #_loopOOS == 1 then
                            oosLabel = _loopOOS[1] .. " out of stock"
                        elseif #_loopOOS <= 3 then
                            oosLabel = table.concat(_loopOOS, ", ") .. " out of stock"
                        else
                            oosLabel = #_loopOOS .. " seeds out of stock"
                        end
                        if _buyOOSHandle then pcall(function() _buyOOSHandle.Dismiss() end) end
                        _buyOOSHandle = Notify("Auto Buy", oosLabel .. ", waiting restock...", Colors.TextMuted, 4)
                    end
                end)
            end
        end
    end)

    -- ====================== AUTO BUY GEAR LOOP ======================
    -- ====================== AUTO BUY GEAR LOOP ======================
    -- _notifiedEmptyGear[gearName]  = true     → "out of stock" notif already sent this cycle
    -- _notifEmptyTimeGear[gearName] = number   → rate-limit timestamp for "out of stock" notif
    -- _notifBuySentGear[gearName]   = true     → "buying" notif already sent this restock cycle
    --                                 nil/false → not yet sent, will fire on first purchase
    -- _notifBuySentGear is reset ONLY by the Changed event (new restock from server),
    -- not by toggle ON — guaranteeing exactly 1 notif per restock cycle.
    local _notifiedEmptyGear  = {}
    local _notifEmptyTimeGear = {}
    local _notifBuySentGear   = {}
    local _notifBuyTimeGear   = {}
    local NOTIF_GEAR_COOLDOWN     = 3
    local NOTIF_GEAR_BUY_COOLDOWN = 3

    local _buyGearHandle    = nil
    local _buyGearOOSHandle = nil

    local function ResetNotifiedEmptyGear()
        table.clear(_notifiedEmptyGear)
        table.clear(_notifBuySentGear)
        -- _notifEmptyTimeGear & _notifBuyTimeGear tidak di-clear → cooldown tetap jalan
    end
    Logic.ResetNotifiedEmptyGear = ResetNotifiedEmptyGear

    -- Watch for restocks from server: when stock changes to > 0 (new restock),
    -- reset all flags for that gear so buy & out-of-stock notifs fire fresh next cycle.
    pcall(function()
        local sv = ReplicatedStorage:WaitForChild("StockValues", 10)
        if not sv then return end
        local gs = sv:WaitForChild("GearShop", 10)
        if not gs then return end
        local items = gs:WaitForChild("Items", 10)
        if not items then return end
        local function watchChild(child)
            if not child:IsA("NumberValue") then return end
            child.Changed:Connect(function(newVal)
                if newVal > 0 then
                    _notifiedEmptyGear[child.Name]  = nil
                    _notifEmptyTimeGear[child.Name] = nil
                    _notifBuySentGear[child.Name]   = nil
                    _notifBuyTimeGear[child.Name]   = nil
                end
            end)
        end
        items.ChildAdded:Connect(function(child) watchChild(child) end)
        for _, child in ipairs(items:GetChildren()) do
            watchChild(child)
        end
    end)

    task.spawn(function()
        while _G._MiracleHubSession == SESSION do
            task.wait(math.max(States.shopLoopDelay or 0.5, 0.1))
            if States.autoBuyGear then
                pcall(function()
                    local items = ReplicatedStorage:FindFirstChild("StockValues")
                        and ReplicatedStorage.StockValues:FindFirstChild("GearShop")
                        and ReplicatedStorage.StockValues.GearShop:FindFirstChild("Items")
                    local targets = {}
                    if States.autoBuyGearAll then
                        if not items then return end
                        for _, stockVal in ipairs(items:GetChildren()) do
                            if stockVal:IsA("NumberValue") then
                                table.insert(targets, stockVal.Name)
                            end
                        end
                    else
                        targets = States.autoBuyGearTargets or {}
                        if #targets == 0 then return end
                    end
                    -- ── Batch notif gear ──
                    local _loopGearBought = {}
                    local _loopGearOOS    = {}
                    local now = os.clock()

                    for _, gearName in ipairs(targets) do
                        if States.autoBuyGear then
                            local stock = GetGearStock(gearName)
                            if stock > 0 then
                                _notifiedEmptyGear[gearName] = false
                                _notifEmptyTimeGear[gearName] = nil
                                if not _notifBuySentGear[gearName] then
                                    local lastT = _notifBuyTimeGear[gearName] or 0
                                    if now - lastT >= NOTIF_GEAR_BUY_COOLDOWN then
                                        _notifBuySentGear[gearName] = true
                                        _notifBuyTimeGear[gearName] = now
                                        table.insert(_loopGearBought, gearName)
                                    end
                                end
                                BuyGearPacket(gearName, 1)
                                task.wait(States.buyDelay or 0.05)
                            else
                                if not _notifiedEmptyGear[gearName] then
                                    local lastT = _notifEmptyTimeGear[gearName] or 0
                                    if now - lastT >= NOTIF_GEAR_COOLDOWN then
                                        _notifiedEmptyGear[gearName] = true
                                        _notifEmptyTimeGear[gearName] = now
                                        table.insert(_loopGearOOS, gearName)
                                    end
                                end
                            end
                        end
                    end

                    if States.notifyBuyGear and #_loopGearBought > 0 then
                        local label
                        if #_loopGearBought == 1 then
                            label = _loopGearBought[1]
                        elseif #_loopGearBought <= 3 then
                            label = table.concat(_loopGearBought, ", ")
                        else
                            label = #_loopGearBought .. " gears"
                        end
                        if _buyGearHandle then pcall(function() _buyGearHandle.Dismiss() end) end
                        _buyGearHandle = Notify("Auto Buy Gear", "Buying: " .. label, Colors.Electric, 4)
                    end

                    if States.notifyBuyGear and #_loopGearOOS > 0 then
                        local oosLabel
                        if #_loopGearOOS == 1 then
                            oosLabel = _loopGearOOS[1] .. " out of stock"
                        elseif #_loopGearOOS <= 3 then
                            oosLabel = table.concat(_loopGearOOS, ", ") .. " out of stock"
                        else
                            oosLabel = #_loopGearOOS .. " gears out of stock"
                        end
                        if _buyGearOOSHandle then pcall(function() _buyGearOOSHandle.Dismiss() end) end
                        _buyGearOOSHandle = Notify("Auto Buy Gear", oosLabel .. ", waiting restock...", Colors.TextMuted, 4)
                    end
                end)
            end
        end
    end)

    -- ====================== AUTO BUY CRATE LOOP ======================
    -- _notifiedEmptyCrate[crateName]  = true     → "out of stock" notif already sent this cycle
    -- _notifEmptyTimeCrate[crateName] = number   → rate-limit timestamp for "out of stock" notif
    -- _notifBuySentCrate[crateName]   = true     → "buying" notif already sent this restock cycle
    --                                   nil/false → not yet sent, will fire on first purchase
    -- _notifBuySentCrate is reset ONLY by the Changed event (new restock from server),
    -- not by toggle ON — guaranteeing exactly 1 notif per restock cycle.
    local _notifiedEmptyCrate  = {}
    local _notifEmptyTimeCrate = {}
    local _notifBuySentCrate   = {}
    local _notifBuyTimeCrate   = {}
    local NOTIF_CRATE_COOLDOWN     = 3
    local NOTIF_CRATE_BUY_COOLDOWN = 3

    local _buyCrateHandle    = nil
    local _buyCrateOOSHandle = nil

    local function ResetNotifiedEmptyCrate()
        table.clear(_notifiedEmptyCrate)
        table.clear(_notifBuySentCrate)
        -- _notifEmptyTimeCrate & _notifBuyTimeCrate tidak di-clear → cooldown tetap jalan
    end
    Logic.ResetNotifiedEmptyCrate = ResetNotifiedEmptyCrate

    -- Watch for restocks from server: when stock changes to > 0 (new restock),
    -- reset all flags for that crate so buy & out-of-stock notifs fire fresh next cycle.
    pcall(function()
        local sv = ReplicatedStorage:WaitForChild("StockValues", 10)
        if not sv then return end
        local cs = sv:WaitForChild("CrateShop", 10)
        if not cs then return end
        local items = cs:WaitForChild("Items", 10)
        if not items then return end
        local function watchChild(child)
            if not child:IsA("NumberValue") then return end
            child.Changed:Connect(function(newVal)
                if newVal > 0 then
                    _notifiedEmptyCrate[child.Name]  = nil
                    _notifEmptyTimeCrate[child.Name] = nil
                    _notifBuySentCrate[child.Name]   = nil
                    _notifBuyTimeCrate[child.Name]   = nil
                end
            end)
        end
        items.ChildAdded:Connect(function(child) watchChild(child) end)
        for _, child in ipairs(items:GetChildren()) do
            watchChild(child)
        end
    end)

    task.spawn(function()
        while _G._MiracleHubSession == SESSION do
            task.wait(math.max(States.shopLoopDelay or 0.5, 0.1))
            if States.autoBuyCrate then
                pcall(function()
                    local items = ReplicatedStorage:FindFirstChild("StockValues")
                        and ReplicatedStorage.StockValues:FindFirstChild("CrateShop")
                        and ReplicatedStorage.StockValues.CrateShop:FindFirstChild("Items")
                    local targets = {}
                    if States.autoBuyCrateAll then
                        if not items then return end
                        for _, stockVal in ipairs(items:GetChildren()) do
                            if stockVal:IsA("NumberValue") then
                                table.insert(targets, stockVal.Name)
                            end
                        end
                        if #targets == 0 then
                            targets = CRATES
                        end
                    else
                        targets = States.autoBuyCrateTargets or {}
                        if #targets == 0 then return end
                    end
                    -- ── Batch notif crate ──
                    local _loopCrateBought = {}
                    local _loopCrateOOS    = {}
                    local now = os.clock()

                    for _, crateName in ipairs(targets) do
                        if States.autoBuyCrate then
                            local stock = GetCrateStock(crateName)
                            if stock > 0 then
                                _notifiedEmptyCrate[crateName] = false
                                _notifEmptyTimeCrate[crateName] = nil
                                if not _notifBuySentCrate[crateName] then
                                    local lastT = _notifBuyTimeCrate[crateName] or 0
                                    if now - lastT >= NOTIF_CRATE_BUY_COOLDOWN then
                                        _notifBuySentCrate[crateName] = true
                                        _notifBuyTimeCrate[crateName] = now
                                        table.insert(_loopCrateBought, crateName)
                                    end
                                end
                                BuyCratePacket(crateName, 1)
                                task.wait(States.buyDelay or 0.05)
                            else
                                if not _notifiedEmptyCrate[crateName] then
                                    local lastT = _notifEmptyTimeCrate[crateName] or 0
                                    if now - lastT >= NOTIF_CRATE_COOLDOWN then
                                        _notifiedEmptyCrate[crateName] = true
                                        _notifEmptyTimeCrate[crateName] = now
                                        table.insert(_loopCrateOOS, crateName)
                                    end
                                end
                            end
                        end
                    end

                    if States.notifyBuyCrate and #_loopCrateBought > 0 then
                        local label
                        if #_loopCrateBought == 1 then
                            label = _loopCrateBought[1]
                        elseif #_loopCrateBought <= 3 then
                            label = table.concat(_loopCrateBought, ", ")
                        else
                            label = #_loopCrateBought .. " crates"
                        end
                        if _buyCrateHandle then pcall(function() _buyCrateHandle.Dismiss() end) end
                        _buyCrateHandle = Notify("Auto Buy Crate", "Buying: " .. label, Colors.Warning, 4)
                    end

                    if States.notifyBuyCrate and #_loopCrateOOS > 0 then
                        local oosLabel
                        if #_loopCrateOOS == 1 then
                            oosLabel = _loopCrateOOS[1] .. " out of stock"
                        elseif #_loopCrateOOS <= 3 then
                            oosLabel = table.concat(_loopCrateOOS, ", ") .. " out of stock"
                        else
                            oosLabel = #_loopCrateOOS .. " crates out of stock"
                        end
                        if _buyCrateOOSHandle then pcall(function() _buyCrateOOSHandle.Dismiss() end) end
                        _buyCrateOOSHandle = Notify("Auto Buy Crate", oosLabel .. ", waiting restock...", Colors.TextMuted, 4)
                    end
                end)
            end
        end
    end)

    -- ====================== AUTO OPEN CRATE LOOP ======================
    task.spawn(function()
        while _G._MiracleHubSession == SESSION do
            task.wait(math.max(States.crateOpenDelay or 8, 1))
            if not States.autoOpenCrate then continue end
            pcall(function()
                local cratesInBag = GetCratesInInventory()
                if #cratesInBag == 0 then return end
                for _, entry in ipairs(cratesInBag) do
                    if not States.autoOpenCrate then return end
                    local tool = entry.tool
                    local crateName = entry.name
                    if tool.Parent ~= player.Character then
                        tool.Parent = player.Character
                        task.wait(0.2)
                    end
                    local ok, result = pcall(function()
                        return OpenCrateViaNetworking(crateName)
                    end)
                    if ok and States.notifyOpenCrate then
                        local wonItem = type(result) == "table" and result.WonItem
                        if wonItem then
                            Notify("\240\159\147\166 Crate Opened!", crateName .. " \226\134\146 " .. (wonItem.Name or "?") .. (wonItem.Chance and string.format(" (%.2f%%)", wonItem.Chance) or ""), Colors.Gold, 5)
                        else
                            Notify("\240\159\147\166 Crate Opened!", "Opened: " .. crateName, Colors.Warning, 3)
                        end
                    end
                    task.wait(0.5)
                    if tool and tool.Parent == player.Character then
                        tool.Parent = player.Backpack
                    end
                    task.wait(States.crateOpenDelay or 8)
                end
            end)
        end
    end)

    -- ====================== WILD PET HELPERS ======================
    local function GetWildPetRef()
        local map = workspace:FindFirstChild("Map")
        return map and map:FindFirstChild("WildPetRef")
    end
    Logic.GetWildPetRef = GetWildPetRef

    local HOP_SIZE = 10
    local HOP_WAIT = 0.50
    local function SmartMoveToPet(targetPosition, onArrive)
        local c = player.Character
        if not c then if onArrive then onArrive() end return end
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if not hrp then if onArrive then onArrive() end return end
        local dest = Vector3.new(targetPosition.X, targetPosition.Y + 5, targetPosition.Z)
        while true do
            local ch = player.Character
            if not ch then break end
            local r = ch:FindFirstChild("HumanoidRootPart")
            if not r then break end
            local currentPos = r.Position
            local remaining  = (dest - currentPos).Magnitude
            if remaining <= HOP_SIZE then
                r.CFrame = CFrame.new(dest)
                break
            end
            local direction  = (dest - currentPos).Unit
            local nextPos    = currentPos + direction * HOP_SIZE
            r.CFrame = CFrame.new(nextPos)
            task.wait(HOP_WAIT)
        end
        if onArrive then onArrive() end
    end
    Logic.SmartMoveToPet = SmartMoveToPet

    local function ScanWildPets(rarityFilter)
        local ref = GetWildPetRef()
        if not ref then return {} end
        local results = {}
        for _, part in ipairs(ref:GetChildren()) do
            if part:IsA("BasePart") then
                local rarity = part:GetAttribute("Rarity") or "Unknown"
                local owner  = tonumber(part:GetAttribute("OwnerUserId")) or 0
                if owner ~= 0 then continue end
                if rarityFilter and rarityFilter ~= "All" and rarityFilter ~= rarity then continue end
                local dist = math.huge
                if player.Character then
                    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then dist = (part.Position - hrp.Position).Magnitude end
                end
                local petName = part:GetAttribute("Pet")
                    or part:GetAttribute("Species")
                    or part:GetAttribute("PetSpecies")
                    or part:GetAttribute("PetName")
                    or part.Name
                table.insert(results, {part=part, rarity=rarity, dist=dist, name=tostring(petName)})
            end
        end
        table.sort(results, function(a,b) return a.dist < b.dist end)
        return results
    end
    Logic.ScanWildPets = ScanWildPets

    local function HumanizePetName(n)
        return (tostring(n):gsub("(%l)(%u)", "%1 %2"))
    end
    Logic.HumanizePetName = HumanizePetName

    local function NormalizePetName(n)
        return tostring(n)
            :lower()
            :gsub("[%s_%-%(%)]", "")
    end
    Logic.NormalizePetName = NormalizePetName

    local RarityColor = {
        Common    = Color3.fromRGB(180, 180, 180),
        Uncommon  = Color3.fromRGB(60, 200, 70),
        Rare      = Color3.fromRGB(60, 130, 255),
        Epic      = Color3.fromRGB(160, 60, 220),
        Legendary = Color3.fromRGB(255, 215, 0),
        Mythic    = Color3.fromRGB(220, 40, 40),
        Super     = Color3.fromRGB(255, 255, 255),
    }
    Logic.RarityColor = RarityColor

    local PET_RARITY_LOOKUP = {
        Frog = "Common", Bunny = "Common",
        Owl = "Uncommon",
        Deer = "Rare", Turtle = "Rare",
        Robin = "Legendary", Bee = "Legendary",
        Monkey = "Mythic", Bear = "Mythic", Unicorn = "Mythic",
        GoldenDragonfly = "Mythic", ["Golden Dragonfly"] = "Mythic",
        Raccoon = "Super",
        BlackDragon = "Super", ["Black Dragon"] = "Super",
        IceSerpent = "Super", ["Ice Serpent"] = "Super",
    }
    Logic.PET_RARITY_LOOKUP = PET_RARITY_LOOKUP

    -- FIX: BuyPrompt ada di PrimaryPart model di WildPetSpawns, bukan di RefPart.
    -- RefPart = BasePart di WildPetRef (data/trigger).
    -- Model visual = di WildPetSpawns, namanya "WildPet_<PetName>_<RefPart.Name>".
    local function FindPromptForRefPart(refPart)
        if not refPart then return nil end

        -- Cari langsung di refPart dulu (kalau ada)
        local prompt = refPart:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then return prompt end

        -- Cari model visual di WildPetSpawns berdasarkan nama refPart
        local map = workspace:FindFirstChild("Map")
        local spawnsFolder = map and map:FindFirstChild("WildPetSpawns")
        if spawnsFolder then
            for _, model in ipairs(spawnsFolder:GetChildren()) do
                -- Nama model format: "WildPet_<PetName>_<RefPart.Name>"
                if model.Name:find(refPart.Name, 1, true) then
                    local p = model:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if p then return p end
                end
            end
        end

        -- Fallback: cari di _PetVisualClient juga
        local visualClient = workspace:FindFirstChild("_PetVisualClient")
        local modelsFolder = visualClient and visualClient:FindFirstChild("Models")
        if modelsFolder then
            for _, model in ipairs(modelsFolder:GetChildren()) do
                local ownerSlot = model:GetAttribute("OwnerSlot")
                if ownerSlot == refPart.Name then
                    local p = model:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if p then return p end
                end
            end
        end

        return nil
    end

    local function FireWildPetPrompt(part)
        if not part then return false end
        local prompt = FindPromptForRefPart(part)
        if prompt then
            return SafeFirePrompt(prompt)
        end
        return false
    end

    local function FireWildPetNetwork(part)
        if not part then return false end

        -- FIX: server butuh Instance RefPart langsung (bukan string/name).
        -- Dari spy: Networking.Pets.WildPetTame:Fire(refPartInstance)
        if Networking then
            local petsNS = rawget(Networking, "Pets")
            if petsNS then
                local tame = rawget(petsNS, "WildPetTame")
                if tame and tame.Fire then
                    local ok = pcall(function() tame:Fire(part) end)
                    if ok then return true end
                end
            end
        end

        -- Fallback PacketRemote juga dengan Instance
        if PacketRemote then
            pcall(function() PacketRemote:FireServer(part) end)
        end

        return false
    end

    local function IsWildPetClaimed(part)
        if not part or not part.Parent then return true end
        if (tonumber(part:GetAttribute("OwnerUserId")) or 0) ~= 0 then return true end
        -- FIX: State "wandering" = pet bebas, "walking_to_garden" = sudah dibeli
        local state = part:GetAttribute("State") or ""
        if state == "walking_to_garden" then return true end
        return false
    end

    local function BuyWildPet(part)
        if not part or not part.Parent then return false end

        local function succeeded()
            -- Cek server sudah acknowledge: OwnerUserId berubah atau State berubah
            if (tonumber(part:GetAttribute("OwnerUserId")) or 0) ~= 0 then return true end
            if part:GetAttribute("State") == "walking_to_garden" then return true end
            return false
        end

        -- Metode utama: Networking langsung dengan RefPart Instance
        if FireWildPetNetwork(part) then
            task.wait(0.4)
            if succeeded() then return true end
        end

        -- Fallback: ProximityPrompt
        if FireWildPetPrompt(part) then
            task.wait(0.4)
            if succeeded() then return true end
        end

        -- Retry sekali lagi
        task.wait(0.3)
        FireWildPetNetwork(part)
        task.wait(0.5)

        return succeeded()
    end
    Logic.BuyWildPet = BuyWildPet

    local function WaitForWildPetApproach(part, timeoutSeconds, desiredDistance)
        if not part or not part.Parent then return false end

        local timeout = os.clock() + math.max(timeoutSeconds or 1.0, 0.1)
        local range = math.max(desiredDistance or 10, 1)

        while os.clock() < timeout do
            if not part or not part.Parent then
                return false
            end

            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if root then
                local dist = (root.Position - part.Position).Magnitude
                if dist <= range then
                    return true
                end
            end

            task.wait(0.05)
        end

        return false
    end
    Logic.WaitForWildPetApproach = WaitForWildPetApproach

    local function IsWildPetFree(part)
        if not part or not part.Parent then return false end
        if (tonumber(part:GetAttribute("OwnerUserId")) or 0) ~= 0 then return false end
        local state = part:GetAttribute("State") or ""
        if state == "walking_to_garden" then return false end
        return true
    end
    Logic.IsWildPetFree = IsWildPetFree

    -- AUTO CATCH WILD PETS LOOP
    task.spawn(function()
        local lastWaitingNotif = 0
        while _G._MiracleHubSession == SESSION do
            task.wait(2)
            if not States.autoCatchWild then continue end
            local map = workspace:FindFirstChild("Map")
            local ref = map and map:FindFirstChild("WildPetRef")
            if not ref then continue end
            local sel = States.wildCatchTargets or {}
            local targets = {}
            for _, part in ipairs(ref:GetChildren()) do
                if not part:IsA("BasePart") then continue end
                if not IsWildPetFree(part) then continue end
                local petName = part:GetAttribute("PetName")
                    or part:GetAttribute("Pet")
                    or part:GetAttribute("Species")
                    or part.Name
                if #sel > 0 then
                    local match = false
                    local normalizedPetName = NormalizePetName(petName)
                    for _, target in ipairs(sel) do
                        if NormalizePetName(target) == normalizedPetName then
                            match = true; break
                        end
                    end
                    if not match then continue end
                end
                local rarity = part:GetAttribute("Rarity") or "Unknown"
                local price  = part:GetAttribute("Price") or 0
                table.insert(targets, {part=part, petName=tostring(petName), rarity=rarity, price=price})
            end
            if #targets == 0 then
                local now = tick()
                if now - lastWaitingNotif >= 15 then
                    lastWaitingNotif = now
                    local filterStr = #sel > 0 and table.concat(sel, ", ") or "semua pet"
                    Notify("Auto Catch", "\226\143\179 Menunggu spawn: " .. filterStr, Colors.TextMuted, 5)
                end
                continue
            end
            for _, entry in ipairs(targets) do
                if not States.autoCatchWild then break end
                local part    = entry.part
                local petName = entry.petName
                local rarity  = entry.rarity
                local price   = entry.price
                if not IsWildPetFree(part) then continue end
                SmartMoveToPet(part.Position, nil)
                WaitForWildPetApproach(part, 1.2, 10)
                if not IsWildPetFree(part) then continue end
                local ok = BuyWildPet(part)
                if ok then
                    Notify("Auto Catch",
                        "\240\159\142\175 " .. HumanizePetName(petName) .. " (" .. rarity .. ") | " .. tostring(price) .. "\194\162",
                        RarityColor[rarity] or Colors.Warning, 4)
                    task.wait(1.5)
                end
            end
        end
    end)

    -- AUTO OPEN EGGS LOOP
    task.spawn(function()
        while _G._MiracleHubSession == SESSION do
            task.wait(States.eggLoopDelay or 5)
            if not States.autoOpenEgg then continue end
            pcall(function()
                local teleports = game:GetService("Workspace"):FindFirstChild("Teleports")
                if teleports then
                    local gearPart = teleports:FindFirstChild("Gears")
                    if gearPart and player.Character then
                        player.Character:PivotTo(gearPart.CFrame + Vector3.new(0, 5, 0))
                        task.wait(0.4)
                    end
                end
                local gearShop = game:GetService("Workspace"):FindFirstChild("Gears") or game:GetService("Workspace"):FindFirstChild("GearShop")
                if gearShop then
                    for _, desc in ipairs(gearShop:GetDescendants()) do
                        if desc:IsA("ProximityPrompt") and (desc.Name:lower():find("egg") or desc.Name:lower():find("hatch") or desc.Name:lower():find("open")) then
                            SafeFirePrompt(desc)
                            if States.notifyCrate then
                                Notify("Eggs", "Opened an egg!", Colors.Warning)
                            end
                            task.wait(1)
                        end
                    end
                end
                FirePacket(PACKET.OpenEgg)
            end)
        end
    end)

    -- AUTO ACCEPT GIFTS / MAILBOX LOOP
    task.spawn(function()
        while _G._MiracleHubSession == SESSION do
            task.wait(10)
            if not States.autoAcceptGifts then continue end
            pcall(function()
                local plot = GetMyPlot()
                if not plot then return end
                local signs = plot:FindFirstChild("Signs")
                if not signs then return end
                local mailbox = signs:FindFirstChild("GreyMailBox")
                if not mailbox then return end
                local promptPart = mailbox:FindFirstChild("ProximityPromptPart")
                if not promptPart then
                    promptPart = mailbox:FindFirstChildWhichIsA("BasePart")
                end
                if not promptPart then return end
                local mailPrompt = promptPart:FindFirstChild("MailboxPrompt")
                if not mailPrompt then
                    for _, desc in ipairs(mailbox:GetDescendants()) do
                        if desc:IsA("ProximityPrompt") and desc.Name == "MailboxPrompt" then
                            mailPrompt = desc
                            break
                        end
                    end
                end
                if mailPrompt then
                    SafeFirePrompt(mailPrompt)
                end
            end)
        end
    end)

    -- ====================== ESP SYSTEM ======================
    local espLabels = {}
    local espStateSnapshot = {
        espPlayers = nil,
        espItems = nil,
        espFruits = nil,
        espMutations = nil,
        showPlantAge = nil,
        showFruitWeight = nil,
    }

    local function TrackESP(instance)
        if instance then
            table.insert(espLabels, instance)
        end
        return instance
    end

    local function ClearESP()
        for _, v in ipairs(espLabels) do
            if v and v.Parent then v:Destroy() end
        end
        table.clear(espLabels)
        espStateSnapshot = {
            espPlayers = nil,
            espItems = nil,
            espFruits = nil,
            espMutations = nil,
            showPlantAge = nil,
            showFruitWeight = nil,
        }
    end
    Logic.ClearESP = ClearESP

    local function GetModelRootPart(model)
        if not model then return nil end
        if model.PrimaryPart then return model.PrimaryPart end
        local ok, pivot = pcall(function() return model:GetPivot() end)
        if ok and pivot then
            local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
            if root then return root end
        end
        return model:FindFirstChildWhichIsA("BasePart")
    end

    local function AttachESPMarker(parent, name)
        if not parent then return nil end
        local marker = parent:FindFirstChild(name)
        if marker then return marker end
        marker = Instance.new("ObjectValue")
        marker.Name = name
        marker.Parent = parent
        return TrackESP(marker)
    end

    -- lineCount: hitung baris dari \n untuk set tinggi billboard
    local function MakeESPLabel(adornee, text, color)
        local lineCount = 1
        for _ in text:gmatch("\n") do lineCount = lineCount + 1 end
        local bbHeight = math.max(20, lineCount * 16 + 6)
        local billboard = Create("BillboardGui", {
            Parent = game:GetService("Workspace"),
            Adornee = adornee,
            Size = UDim2.new(0, 160, 0, bbHeight),
            StudsOffset = Vector3.new(0, 3.5, 0),
            AlwaysOnTop = true,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        })
        local frame = Create("Frame", {
            Parent = billboard,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 0.45,
            BorderSizePixel = 0,
        })
        CreateCorner(frame, 4)
        Create("TextLabel", {
            Parent = frame,
            Size = UDim2.new(1, -6, 1, 0),
            Position = UDim2.new(0, 3, 0, 0),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = color or Colors.TextPrimary,
            TextSize = 11,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextWrapped = true,
            RichText = false,
        })
        return TrackESP(billboard)
    end

    -- UpdateESPLabel: update teks + warna label yg sudah ada (tanpa buat baru)
    local function UpdateESPLabel(billboard, text, color)
        if not billboard then return end
        local frame = billboard:FindFirstChildWhichIsA("Frame")
        if not frame then return end
        local lbl = frame:FindFirstChildWhichIsA("TextLabel")
        if not lbl then return end
        lbl.Text = text
        if color then lbl.TextColor3 = color end
        -- resize billboard sesuai baris baru
        local lineCount = 1
        for _ in text:gmatch("\n") do lineCount = lineCount + 1 end
        billboard.Size = UDim2.new(0, 160, 0, math.max(20, lineCount * 16 + 6))
    end

    RunService.Heartbeat:Connect(function()
        local currentSnapshot = {
            espPlayers = States.espPlayers,
            espItems = States.espItems,
            espFruits = States.espFruits,
            espMutations = States.espMutations,
            showPlantAge = States.showPlantAge,
            showFruitWeight = States.showFruitWeight,
        }
        local snapshotChanged = false
        for k, v in pairs(currentSnapshot) do
            if espStateSnapshot[k] ~= v then
                snapshotChanged = true
                break
            end
        end
        if snapshotChanged then
            ClearESP()
            espStateSnapshot = currentSnapshot
        end

        if States.espPlayers then
            local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
                if p ~= player and p.Character then
                    local rootPart = p.Character:FindFirstChild("HumanoidRootPart")
                    if not rootPart then continue end
                    -- hitung distance untuk label
                    local dist = myRoot
                        and math.floor((rootPart.Position - myRoot.Position).Magnitude)
                        or 0
                    local distLabel = dist > 0 and ("
" .. dist .. "m") or ""
                    local fullLabel = p.DisplayName .. "
@" .. p.Name .. distLabel
                    if rootPart:FindFirstChild("MiracleESP_Player") then
                        -- refresh distance setiap tick
                        for _, tracked in ipairs(espLabels) do
                            if tracked:IsA("BillboardGui") and tracked.Adornee == rootPart then
                                UpdateESPLabel(tracked, fullLabel, Colors.Electric)
                                break
                            end
                        end
                    else
                        local bb = MakeESPLabel(rootPart, fullLabel, Colors.Electric)
                        bb.Name = "MiracleESP_Player_" .. p.Name
                        AttachESPMarker(rootPart, "MiracleESP_Player")
                    end
                end
            end
        end

        if States.espItems then
            local map = workspace:FindFirstChild("Map")
            local ref = map and map:FindFirstChild("WildPetRef")
            if ref then
                for _, part in ipairs(ref:GetChildren()) do
                    if part:IsA("BasePart") then
                        local owner = tonumber(part:GetAttribute("OwnerUserId")) or 0
                        if owner ~= 0 then continue end
                        if not part:FindFirstChild("MiracleESP_WP") then
                            local rarity  = part:GetAttribute("Rarity") or "?"
                            local petName = part:GetAttribute("PetName")
                                or part:GetAttribute("Name")
                                or part:GetAttribute("PetType")
                                or part.Name
                            -- bersihkan instance name acak (hanya pakai kalau terlihat wajar)
                            if petName and #petName > 20 then petName = nil end
                            local col = RarityColor and RarityColor[rarity] or Colors.Warning
                            local label = petName
                                and ("🐾 " .. petName .. "
" .. rarity)
                                or  ("🐾 " .. rarity)
                            MakeESPLabel(part, label, col)
                            AttachESPMarker(part, "MiracleESP_WP")
                        end
                    end
                end
            end
        end

        if States.espFruits or States.showFruitWeight then
            local myPlot = GetMyPlot()
            if myPlot then
                for _, prompt in ipairs(CollectionService:GetTagged("HarvestPrompt")) do
                    if not prompt:IsDescendantOf(myPlot) then continue end
                    local fruitPart = prompt.Parent
                    local fruit = fruitPart and fruitPart.Parent
                    if not (fruit and fruit:IsA("Model")) then continue end

                    local rootPart = GetModelRootPart(fruit)
                    if not rootPart then continue end

                    -- BUG FIX: fruit.Name bisa jadi instance-id acak dari server.
                    -- Prioritaskan atribut semantik; fallback "Fruit" jika semua nil.
                    local seedName = fruit:GetAttribute("SeedName")
                        or fruit:GetAttribute("SeedTool")
                        or fruit:GetAttribute("PlantType")
                        or fruit:GetAttribute("FruitName")
                        or "Fruit"

                    local weight = fruit:GetAttribute("Weight")
                    local mut    = GetMutation(fruit)
                    local label  = seedName
                    if States.showFruitWeight and weight then
                        label = label .. string.format(" %.2fkg", weight)
                    end
                    if States.espFruits and mut and mut ~= "" and mut ~= "None" then
                        label = mut .. "
" .. label
                    end
                    local color = (mut and mut ~= "" and mut ~= "None")
                        and ctx.UI.GetMutationColor(mut)
                        or Colors.Warning

                    -- Refresh: kalau label sudah ada, update teks (weight/mut bisa berubah)
                    local existingMarker = rootPart:FindFirstChild("MiracleESP_Fruit")
                    if existingMarker then
                        -- cari billboard yang terhubung ke rootPart ini dan update
                        for _, tracked in ipairs(espLabels) do
                            if tracked:IsA("BillboardGui") and tracked.Adornee == rootPart then
                                UpdateESPLabel(tracked, label, color)
                                break
                            end
                        end
                    else
                        MakeESPLabel(rootPart, label, color)
                        AttachESPMarker(rootPart, "MiracleESP_Fruit")
                    end
                end
            end
        end

        if States.espMutations then
            -- BUG FIX: GetPlantsFolder() hanya cek plot sendiri.
            -- Scan semua plot di Gardens agar mutation player lain juga terdeteksi.
            local gardens = workspace:FindFirstChild("Gardens")
            if gardens then
                for _, plot in ipairs(gardens:GetChildren()) do
                    local plantsFolder = plot:FindFirstChild("Plants")
                    if not plantsFolder then continue end
                    for _, plant in ipairs(plantsFolder:GetChildren()) do
                        local mut = GetMutation(plant)
                        if mut and mut ~= "" and mut ~= "None" then
                            local rootPart = GetModelRootPart(plant)
                            if not rootPart then continue end
                            local sn = plant:GetAttribute("SeedName")
                                or plant:GetAttribute("SeedTool")
                                or "Plant"
                            local label = mut .. "
" .. sn
                            local color = ctx.UI.GetMutationColor(mut)
                            if rootPart:FindFirstChild("MiracleESP_Mut") then
                                -- refresh: mutation bisa berubah (multiple stacked mutations)
                                for _, tracked in ipairs(espLabels) do
                                    if tracked:IsA("BillboardGui") and tracked.Adornee == rootPart then
                                        UpdateESPLabel(tracked, label, color)
                                        break
                                    end
                                end
                            else
                                MakeESPLabel(rootPart, label, color)
                                AttachESPMarker(rootPart, "MiracleESP_Mut")
                            end
                        end
                    end
                end
            end
        end

        if States.showPlantAge then
            local plants = GetPlantsFolder()
            if plants then
                for _, plant in ipairs(plants:GetChildren()) do
                    local age    = plant:GetAttribute("Age")
                    local maxAge = plant:GetAttribute("MaxAge")
                    if age and maxAge then
                        local rootPart = GetModelRootPart(plant)
                        if not rootPart then continue end
                        local sn = plant:GetAttribute("SeedName")
                            or plant:GetAttribute("SeedTool")
                            or "Plant"
                        local pct   = math.floor((age / maxAge) * 100)
                        local ready = age >= maxAge
                        local label = sn .. "
" .. age .. "/" .. maxAge .. " (" .. pct .. "%)"
                        local color = ready and Colors.Success or Colors.TextMuted
                        -- BUG FIX: Age berubah setiap tick → harus update label, bukan skip
                        if rootPart:FindFirstChild("MiracleESP_Age") then
                            for _, tracked in ipairs(espLabels) do
                                if tracked:IsA("BillboardGui") and tracked.Adornee == rootPart then
                                    UpdateESPLabel(tracked, label, color)
                                    break
                                end
                            end
                        else
                            MakeESPLabel(rootPart, label, color)
                            AttachESPMarker(rootPart, "MiracleESP_Age")
                        end
                    end
                end
            end
        end

        local lighting = game:GetService("Lighting")
        if not Logic._lightingDefaults then
            Logic._lightingDefaults = {
                Brightness = lighting.Brightness,
                Ambient = lighting.Ambient,
                OutdoorAmbient = lighting.OutdoorAmbient,
                FogStart = lighting.FogStart,
                FogEnd = lighting.FogEnd,
                GlobalShadows = lighting.GlobalShadows,
            }
        end
        local defaults = Logic._lightingDefaults
        if States.fullBright then
            lighting.Brightness = States.brightness
            lighting.Ambient = Color3.fromRGB(255, 255, 255)
            lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        else
            lighting.Brightness = defaults.Brightness
            lighting.Ambient = defaults.Ambient
            lighting.OutdoorAmbient = defaults.OutdoorAmbient
        end
        if States.noFog then
            lighting.FogEnd = 100000
            lighting.FogStart = 100000
        else
            lighting.FogEnd = defaults.FogEnd
            lighting.FogStart = defaults.FogStart
        end
        if States.noShadows then
            lighting.GlobalShadows = false
        else
            lighting.GlobalShadows = defaults.GlobalShadows
        end
        if States.lockWalkSpeed and humanoid then humanoid.WalkSpeed = States.walkSpeed end
        if States.lockJumpPower and humanoid then
            if humanoid.UseJumpPower then
                humanoid.JumpPower = States.jumpPower
            else
                -- Roblox baru pakai JumpHeight; konversi dari JumpPower: h = v²/2g
                humanoid.JumpHeight = (States.jumpPower * States.jumpPower) / (2 * 196.2)
            end
        end
    end)

    -- ====================== FLY ======================
    local flyBody = nil
    RunService.Heartbeat:Connect(function()
        if States.fly and player.Character then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            if root then
                if not flyBody or not flyBody.Parent then
                    flyBody = Instance.new("BodyVelocity")
                    flyBody.MaxForce = Vector3.new(1e6, 1e6, 1e6)
                    flyBody.Parent = root
                end
                local vel = Vector3.new()
                local cam = game:GetService("Workspace").CurrentCamera
                local cf = cam.CFrame
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then vel += cf.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then vel -= cf.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then vel -= cf.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then vel += cf.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vel += Vector3.new(0, 1, 0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then vel -= Vector3.new(0, 1, 0) end
                flyBody.Velocity = vel.Magnitude > 0 and vel.Unit * States.flySpeed or Vector3.new()
            end
        else
            if flyBody then flyBody:Destroy() flyBody = nil end
        end
    end)

    -- Infinite jump
    UserInputService.JumpRequest:Connect(function()
        if States.infiniteJump and humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)

    -- ====================== ANTI AFK ======================
    --
    -- Game (Grow a Garden) track activity via os.clock(), listen ke:
    --   InputBegan / InputChanged / TouchStarted / TouchMoved
    -- Threshold kick = 1140 detik (~19 mnt). Kita simulasi input tiap 60 detik
    -- sebagai margin aman — tapi HANYA jika user benar-benar idle (tidak ada
    -- input asli dalam 30 detik terakhir). Kalau user aktif, input aslinya
    -- sudah cukup reset timer game, jadi tidak perlu trigger dan tidak ada
    -- risiko interrupt aksi player.
    --
    -- Logic._antiAfkStats bisa dibaca UI page untuk status real-time.

    local VirtualUser = game:GetService("VirtualUser")

    Logic._antiAfkStats = {
        lastTriggerTime = 0,      -- os.clock() saat terakhir trigger
        triggerCount    = 0,      -- total berapa kali trigger
        lastMethod      = "none", -- metode terakhir berhasil
        active          = false,  -- apakah loop jalan
        nextTriggerIn   = 60,     -- countdown ke trigger berikutnya (detik)
        skippedActive   = 0,      -- berapa kali skip karena user aktif
    }

    local _afkStats = Logic._antiAfkStats

    -- Tracking waktu input terakhir dari user (keyboard, mouse, touch)
    local _lastRealInput = os.clock()
    local _IDLE_THRESHOLD = 300  -- 5 menit tanpa input → anggap user idle

    UserInputService.InputBegan:Connect(function(input, processed)
        -- Tangkap semua input hardware (bukan UI-consumed saja)
        local t = input.UserInputType
        if t == Enum.UserInputType.Keyboard
            or t == Enum.UserInputType.MouseButton1
            or t == Enum.UserInputType.MouseButton2
            or t == Enum.UserInputType.MouseButton3
            or t == Enum.UserInputType.Touch
            or t == Enum.UserInputType.Gamepad1 then
            _lastRealInput = os.clock()
        end
    end)

    UserInputService.InputChanged:Connect(function(input, processed)
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseMovement
            or t == Enum.UserInputType.MouseWheel
            or t == Enum.UserInputType.Touch then
            _lastRealInput = os.clock()
        end
    end)

    local VIM = nil
    pcall(function() VIM = game:GetService("VirtualInputManager") end)

    local function TriggerAntiAfk()
        local success = false

        -- Metode 1: VirtualInputManager (paling reliable, masuk UIS pipeline)
        if VIM then
            pcall(function()
                VIM:SendKeyEvent(true,  Enum.KeyCode.LeftShift, false, game)
                task.wait(0.05)
                VIM:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
                success = true
                _afkStats.lastMethod = "VirtualInputManager"
            end)
        end

        -- Metode 2: VirtualUser Button2 (right-click)
        if not success then
            pcall(function()
                local cam = workspace.CurrentCamera
                if cam then
                    if VirtualUser.CaptureController then
                        VirtualUser:CaptureController()
                    end
                    VirtualUser:Button2Down(Vector2.new(0, 0), cam.CFrame)
                    task.wait(0.05)
                    VirtualUser:Button2Up(Vector2.new(0, 0), cam.CFrame)
                    success = true
                    _afkStats.lastMethod = "VirtualUser.Button2"
                end
            end)
        end

        -- Metode 3: mousemoverel (Synapse / Fluxus legacy)
        if not success then
            pcall(function()
                if mousemoverel then
                    mousemoverel(1, 0)
                    task.wait(0.05)
                    mousemoverel(-1, 0)
                    success = true
                    _afkStats.lastMethod = "mousemoverel"
                end
            end)
        end

        -- Metode 4: VirtualUser Button1 (last resort)
        if not success then
            pcall(function()
                local cam = workspace.CurrentCamera
                if cam then
                    VirtualUser:Button1Down(Vector2.new(0, 0), cam.CFrame)
                    task.wait(0.05)
                    VirtualUser:Button1Up(Vector2.new(0, 0), cam.CFrame)
                    success = true
                    _afkStats.lastMethod = "VirtualUser.Button1"
                end
            end)
        end

        if success then
            _afkStats.lastTriggerTime = os.clock()
            _afkStats.triggerCount    = _afkStats.triggerCount + 1
        else
            _afkStats.lastMethod = "failed"
            warn("[Miracle Hub] Anti AFK: semua metode gagal — executor mungkin tidak support VIM/VirtualUser.")
        end
    end

    -- Loop utama: cek tiap detik, trigger tiap 60 detik HANYA saat user idle
    local ANTI_AFK_INTERVAL = 60
    task.spawn(function()
        _afkStats.active = true
        local countdown  = ANTI_AFK_INTERVAL

        while _G._MiracleHubSession == SESSION do
            task.wait(1)
            if States.antiAfk then
                countdown = countdown - 1
                _afkStats.nextTriggerIn = math.max(countdown, 0)

                if countdown <= 0 then
                    countdown = ANTI_AFK_INTERVAL
                    local idleSec = os.clock() - _lastRealInput
                    if idleSec >= _IDLE_THRESHOLD then
                        -- User benar-benar idle, trigger simulasi input
                        TriggerAntiAfk()
                    else
                        -- User masih aktif, input aslinya sudah reset timer game
                        _afkStats.skippedActive = _afkStats.skippedActive + 1
                    end
                end
            else
                countdown = ANTI_AFK_INTERVAL
                _afkStats.nextTriggerIn = ANTI_AFK_INTERVAL
            end
        end
        _afkStats.active = false
    end)

    -- Fallback: Roblox Idled event sebagai safety net terakhir
    player.Idled:Connect(function()
        if States.antiAfk then
            TriggerAntiAfk()
        end
    end)

    ctx._triggerAntiAfk = TriggerAntiAfk

    -- Character respawn handler
    player.CharacterAdded:Connect(function(char)
        ctx.character = char
        humanoid = char:WaitForChild("Humanoid")
        ctx.humanoid = humanoid
        flyBody = nil
    end)

    ctx.Logic = Logic
    return ctx
end