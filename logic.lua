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
                                    Notify("Auto Harvest \226\156\133", harvested .. " buah | Bag " .. after .. "/" .. MAX_FRUIT_CAP, Colors.Warning)
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

    local function GetSprinklerTool()
        local targets = States.sprinklerTargets or {}
        local hasTargets = #targets > 0

        local function checkTool(tool)
            if not (tool and tool:IsA("Tool")) then return false end
            local attr = tool:GetAttribute("Sprinkler")
            if attr then
                local sName = type(attr) == "string" and attr ~= "" and attr or tool.Name
                if hasTargets then
                    for _, t in ipairs(targets) do
                        if t == sName then return tool, sName end
                    end
                    return false
                end
                return tool, sName
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
                            local attr = tool:GetAttribute("Sprinkler")
                            local sName = type(attr) == "string" and attr ~= "" and attr or tool.Name
                            if sName == targetName then
                                return tool, sName
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

    local function AcquireSprinklerTool()
        local tool, sprinklerName = GetSprinklerTool()
        if not tool or not sprinklerName then return nil, nil end
        if not IsToolEquipped(tool) then
            local ok = EquipTool(tool)
            if not ok then return nil, nil end
        end
        return tool, sprinklerName
    end
    Logic.AcquireSprinklerTool = AcquireSprinklerTool

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

    -- ====================== SPRINKLER PLACEMENT HELPERS ======================

    -- Radius coverage tiap jenis sprinkler (diameter / 2 dalam studs, XZ plane).
    -- Nilai fallback = 8 jika nama tidak dikenali.
    -- Radius diambil dari SprinklerData di ReplicatedStorage; tabel ini sebagai cache/fallback.
    local SPRINKLER_RADIUS_FALLBACK = {
        ["Common Sprinkler"]    = 10,
        ["Uncommon Sprinkler"]  = 16,
        ["Rare Sprinkler"]      = 22,
        ["Legendary Sprinkler"] = 30,
        ["Super Sprinkler"]     = 40,
    }

    -- Coba baca radius dari SprinklerData di ReplicatedStorage, fallback ke tabel di atas.
    local function GetSprinklerRadius(sprinklerName)
        local ok, radius = pcall(function()
            local sd = require(ReplicatedStorage.SharedModules.SprinklerData)
            for _, entry in ipairs(sd) do
                if entry.SprinklerName == sprinklerName and entry.Radius then
                    return entry.Radius
                end
            end
            return nil
        end)
        if ok and radius then return radius end
        return SPRINKLER_RADIUS_FALLBACK[sprinklerName] or 8
    end
    Logic.GetSprinklerRadius = GetSprinklerRadius

    -- Ambil semua posisi tanaman yang ada di plot (XZ saja untuk coverage check).
    local function GetPlantPositions()
        local plantsFolder = GetPlantsFolder()
        local positions = {}
        if not plantsFolder then return positions end
        for _, plant in ipairs(plantsFolder:GetChildren()) do
            if plant:IsA("Model") then
                local pos
                local ok, cf = pcall(function() return plant:GetPivot() end)
                if ok and cf then
                    pos = cf.Position
                else
                    local pp = plant.PrimaryPart
                    if pp then pos = pp.Position
                    else
                        for _, d in ipairs(plant:GetDescendants()) do
                            if d:IsA("BasePart") then pos = d.Position break end
                        end
                    end
                end
                if pos then
                    table.insert(positions, Vector2.new(pos.X, pos.Z))
                end
            end
        end
        return positions
    end
    Logic.GetPlantPositions = GetPlantPositions

    -- Ambil semua sprinkler yang sudah terpasang di plot beserta posisi & radius-nya.
    local function GetExistingSprinklers(myPlot)
        local sprinklers = {}
        if not myPlot then return sprinklers end
        local function resolveWorldPosition(model)
            if not model then return nil end
            local primary = model.PrimaryPart
            if primary then return primary.Position end

            local okPivot, pivot = pcall(function()
                return model:GetPivot()
            end)
            if okPivot and pivot then
                return pivot.Position
            end

            for _, desc in ipairs(model:GetDescendants()) do
                if desc:IsA("BasePart") then
                    return desc.Position
                end
            end

            return nil
        end
        for _, obj in ipairs(myPlot:GetDescendants()) do
            if obj:IsA("Model") then
                local sName = obj:GetAttribute("SprinklerName") or obj:GetAttribute("Sprinkler")
                if sName then
                    local pos = resolveWorldPosition(obj)
                    if pos then
                        local r = GetSprinklerRadius(sName)
                        table.insert(sprinklers, {
                            pos    = Vector2.new(pos.X, pos.Z),
                            radius = r,
                            name   = sName,
                        })
                    end
                end
            end
        end
        return sprinklers
    end
    Logic.GetExistingSprinklers = GetExistingSprinklers

    local function CountPlotSprinklers(myPlot)
        local sprinklers = GetExistingSprinklers(myPlot)
        return #sprinklers
    end
    Logic.CountPlotSprinklers = CountPlotSprinklers

    -- Cek apakah suatu titik (Vector2) sudah ter-cover oleh salah satu sprinkler.
    local function IsPointCovered(point, sprinklers)
        for _, sp in ipairs(sprinklers) do
            local dx = point.X - sp.pos.X
            local dz = point.Y - sp.pos.Y
            if dx*dx + dz*dz <= sp.radius * sp.radius then
                return true
            end
        end
        return false
    end

    -- Greedy set-cover: pilih posisi sprinkler optimal agar semua tanaman ter-cover
    -- dengan jumlah sprinkler sesedikit mungkin.
    --
    -- candidatePositions = list Vector3 (posisi valid untuk meletakkan sprinkler)
    -- plantPositions     = list Vector2 (posisi XZ tanaman yang perlu di-cover)
    -- radius             = radius coverage sprinkler yang akan dipakai
    -- existingSprinklers = list {pos=Vector2, radius=number} (sudah terpasang)
    --
    -- Returns: list Vector3 posisi sprinkler yang perlu dipasang
    local function GreedySprinklerCover(candidatePositions, plantPositions, radius, existingSprinklers)
        -- Filter tanaman yang belum ter-cover oleh sprinkler existing
        local uncovered = {}
        for _, p in ipairs(plantPositions) do
            if not IsPointCovered(p, existingSprinklers) then
                table.insert(uncovered, p)
            end
        end

        if #uncovered == 0 then return {} end -- semua sudah ter-cover

        local placed = {}        -- sprinkler baru yang akan dipasang (Vector3)
        local placedSp = {}      -- sebagai sprinklers list untuk IsPointCovered

        -- Salin existing sprinklers ke placedSp agar coverage check akumulatif
        for _, sp in ipairs(existingSprinklers) do
            table.insert(placedSp, sp)
        end

        local r2 = radius * radius

        while #uncovered > 0 do
            local bestPos   = nil
            local bestCount = 0
            local bestVec3  = nil

            -- Untuk setiap kandidat posisi, hitung berapa uncovered plants yang bisa dicakup
            for _, cand in ipairs(candidatePositions) do
                -- Skip jika sudah ada sprinkler sangat dekat di titik ini
                local tooClose = false
                for _, sp in ipairs(placedSp) do
                    local dx = cand.X - sp.pos.X
                    local dz = cand.Z - sp.pos.Y
                    if dx*dx + dz*dz < 4 then -- < 2 studs = terlalu dekat
                        tooClose = true break
                    end
                end
                if not tooClose then
                    local count = 0
                    for _, p in ipairs(uncovered) do
                        local dx = cand.X - p.X
                        local dz = cand.Z - p.Y
                        if dx*dx + dz*dz <= r2 then
                            count = count + 1
                        end
                    end

                    if count > bestCount then
                        bestCount = count
                        bestVec3  = cand
                        bestPos   = Vector2.new(cand.X, cand.Z)
                    end
                end
            end

            if not bestVec3 or bestCount == 0 then
                -- Tidak ada kandidat yang bisa cover tanaman tersisa:
                -- pasang satu sprinkler tepat di atas tiap tanaman yang belum ter-cover
                for _, p in ipairs(uncovered) do
                    -- Cari Y dari candidatePositions terdekat
                    local bestY = 142.602 -- fallback Y plot
                    local minD  = math.huge
                    for _, cand in ipairs(candidatePositions) do
                        local d = (cand.X - p.X)^2 + (cand.Z - p.Y)^2
                        if d < minD then minD = d bestY = cand.Y end
                    end
                    local v3 = Vector3.new(p.X, bestY, p.Y)
                    table.insert(placed, v3)
                    table.insert(placedSp, {pos = Vector2.new(p.X, p.Y), radius = radius})
                end
                break
            end

            -- Tandai semua tanaman yang ter-cover oleh sprinkler ini
            local newUncovered = {}
            for _, p in ipairs(uncovered) do
                local dx = bestVec3.X - p.X
                local dz = bestVec3.Z - p.Y
                if dx*dx + dz*dz > r2 then
                    table.insert(newUncovered, p)
                end
            end

            table.insert(placed, bestVec3)
            table.insert(placedSp, {pos = bestPos, radius = radius})
            uncovered = newUncovered
        end

        return placed
    end
    Logic.GreedySprinklerCover = GreedySprinklerCover

    -- Kandidat posisi untuk meletakkan sprinkler: titik-titik di dalam PlantArea
    -- dengan grid step lebih besar (karena 1 sprinkler bisa cover banyak tanaman).
    local function GetSprinklerCandidatePositions(radius)
        local myPlot = GetMyPlot()
        if not myPlot then return {} end
        local plantAreas = GetMyPlantAreas()
        if #plantAreas == 0 then return {} end

        -- Step grid = radius / 2 agar ada cukup kandidat tanpa terlalu banyak
        local step = math.max(radius / 2, 2)
        local candidates = {}

        for _, area in ipairs(plantAreas) do
            local cf     = area.CFrame
            local sz     = area.Size
            local halfX  = sz.X / 2
            local halfZ  = sz.Z / 2
            local margin = 0.5
            local centerY = cf.Position.Y + sz.Y / 2

            local lx = -halfX + margin
            while lx <= halfX - margin do
                local lz = -halfZ + margin
                while lz <= halfZ - margin do
                    local worldPt = cf:PointToWorldSpace(Vector3.new(lx, sz.Y / 2, lz))
                    table.insert(candidates, Vector3.new(worldPt.X, centerY, worldPt.Z))
                    lz = lz + step
                end
                lx = lx + step
            end
        end

        return candidates
    end
    Logic.GetSprinklerCandidatePositions = GetSprinklerCandidatePositions

    -- Fungsi utama: kembalikan list posisi Vector3 tempat sprinkler harus dipasang,
    -- berdasarkan posisi tanaman aktual + radius coverage sprinkler yang dipilih.
    local function GetSprinklerPlacePositions(maxCount, sprinklerName)
        local myPlot = GetMyPlot()
        if not myPlot then return {} end

        -- Dapatkan radius sprinkler yang akan dipakai
        local radius = GetSprinklerRadius(sprinklerName or "Common Sprinkler")

        -- Sprinkler yang sudah terpasang
        local existingSprinklers = GetExistingSprinklers(myPlot)

        -- Kandidat posisi untuk sprinkler baru
        local candidates = GetSprinklerCandidatePositions(radius)
        if #candidates == 0 then
            -- Fallback: gunakan center tiap PlantArea
            local plantAreas = GetMyPlantAreas()
            for _, area in ipairs(plantAreas) do
                local cf  = area.CFrame
                local sz  = area.Size
                table.insert(candidates, Vector3.new(cf.Position.X, cf.Position.Y + sz.Y/2, cf.Position.Z))
            end
        end

        -- Posisi semua tanaman di plot. Kalau belum ada tanaman sama sekali,
        -- tetap pasang sprinkler berdasarkan grid PlantArea (pre-place),
        -- bukan berhenti total seperti sebelumnya.
        local plantPositions = GetPlantPositions()
        local positions
        if #plantPositions == 0 then
            positions = {}
            for _, cand in ipairs(candidates) do
                if not IsPointCovered(Vector2.new(cand.X, cand.Z), existingSprinklers) then
                    table.insert(positions, cand)
                end
            end
        else
            positions = GreedySprinklerCover(candidates, plantPositions, radius, existingSprinklers)
        end

        -- Trim ke maxCount
        if maxCount and #positions > maxCount then
            local trimmed = {}
            for i = 1, maxCount do trimmed[i] = positions[i] end
            return trimmed
        end

        return positions
    end
    Logic.GetSprinklerPlacePositions = GetSprinklerPlacePositions

    -- ====================== SPRINKLER PLACEMENT FIRE ======================
    -- Dari decompile StevenController.TryPlace, server hanya butuh:
    --   Networking.Place.PlaceSprinkler:Fire(hitPos, sprinklerName, tool, plotId)
    -- Server validasi: player harus dekat hitPos (raycast), tool harus di-equip,
    -- hitPos harus di atas PlantArea yang ber-tag "PlantArea", tidak terlalu dekat
    -- dengan sprinkler lain (< 1 stud), dan plotId harus Owner == player.
    --
    -- Pendekatan: equip tool -> teleport player tepat ke atas pos -> fire remote.
    -- Tidak pakai VirtualInputManager sama sekali (brittle, tergantung kamera & layar).

    -- Hitung Y surface dari PlantArea di posisi XZ tertentu via raycast
    local function GetSurfaceY(px, pz)
        local foundY = nil
        pcall(function()
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Include
            local gardens = workspace:FindFirstChild("Gardens")
            if gardens then rayParams.FilterDescendantsInstances = {gardens} end
            local result = workspace:Raycast(Vector3.new(px, 200, pz), Vector3.new(0, -300, 0), rayParams)
            if result and result.Instance then
                local inst = result.Instance
                if CollectionService:HasTag(inst, "PlantArea")
                   or inst.Name:lower():find("plantarea") then
                    foundY = result.Position.Y
                end
            end
        end)
        if foundY then return foundY end
        local plantAreas = GetMyPlantAreas()
        local bestY, bestDist = nil, math.huge
        for _, area in ipairs(plantAreas) do
            local cf, sz = area.CFrame, area.Size
            local dx = px - cf.Position.X
            local dz = pz - cf.Position.Z
            local d2 = dx*dx + dz*dz
            if d2 < bestDist then
                bestDist = d2
                -- Top surface yang akurat: center + UpVector * halfHeight
                local topWorld = cf.Position + cf.UpVector * (sz.Y / 2)
                bestY = topWorld.Y
            end
        end
        return bestY or 142.602
    end
    Logic.GetSurfaceY = GetSurfaceY

    local function SnapPosToSurface(pos)
        local surfY = GetSurfaceY(pos.X, pos.Z)
        return Vector3.new(pos.X, surfY, pos.Z)
    end

    local function CountSprinklerTools()
        local count = 0
        local bp = player:FindFirstChildOfClass("Backpack")
        if bp then
            for _, t in ipairs(bp:GetChildren()) do
                if t:IsA("Tool") and t:GetAttribute("Sprinkler") then count = count + 1 end
            end
        end
        if player.Character then
            local held = player.Character:FindFirstChildOfClass("Tool")
            if held and held:GetAttribute("Sprinkler") then count = count + 1 end
        end
        return count
    end

    local _lastSprinklerFire = 0

    local function DoPlaceSprinklerAt(pos, tool, sprinklerName)
        -- Rate limit
        local now = os.clock()
        local gap = 0.6 - (now - _lastSprinklerFire)
        if gap > 0 then task.wait(gap) end

        -- Validasi tool
        if not (tool and tool.Parent) then
            local t2, sn2 = AcquireSprinklerTool()
            if not t2 then return false end
            tool, sprinklerName = t2, sn2
        end

        -- Equip tool (harus di karakter, bukan backpack)
        if not IsToolEquipped(tool) then
            if not EquipTool(tool) then return false end
            task.wait(0.05)
        end

        -- Posisi: pakai top surface dari PlantArea langsung via CFrame.UpVector
        -- Ini yang paling akurat tanpa perlu raycast maupun move player
        local hitPos = pos
        pcall(function()
            local plantAreas = GetMyPlantAreas()
            local bestDist = math.huge
            for _, area in ipairs(plantAreas) do
                local cf, sz = area.CFrame, area.Size
                -- Cek apakah pos XZ masuk dalam bounds area ini
                local localPt = cf:PointToObjectSpace(Vector3.new(pos.X, cf.Position.Y, pos.Z))
                local halfX, halfZ = sz.X / 2, sz.Z / 2
                if math.abs(localPt.X) <= halfX and math.abs(localPt.Z) <= halfZ then
                    -- Pos ada di dalam area ini — hitung top surface
                    local topWorld = cf.Position + cf.UpVector * (sz.Y / 2)
                    hitPos = Vector3.new(pos.X, topWorld.Y, pos.Z)
                    bestDist = 0
                    break
                end
                -- Kalau tidak ada yang match, ambil terdekat
                local dx = pos.X - cf.Position.X
                local dz = pos.Z - cf.Position.Z
                local d2 = dx*dx + dz*dz
                if d2 < bestDist then
                    bestDist = d2
                    local topWorld = cf.Position + cf.UpVector * (sz.Y / 2)
                    hitPos = Vector3.new(pos.X, topWorld.Y, pos.Z)
                end
            end
        end)

        -- plotId dari nama model Garden — persis cara TryPlace game lakukan
        local plotId
        local myPlot = GetMyPlot()
        if myPlot then
            plotId = tonumber(string.match(myPlot.Name, "%d+"))
        end
        plotId = plotId or tonumber(player:GetAttribute("PlotId")) or MY_PLOT_ID

        local countBefore = CountSprinklerTools()

        -- Fire langsung — tidak perlu move player sama sekali
        local ok = pcall(function()
            Networking.Place.PlaceSprinkler:Fire(hitPos, sprinklerName, tool, plotId)
        end)
        _lastSprinklerFire = os.clock()

        if not ok then return false end

        -- Deteksi sukses: tool berkurang dari inventory
        task.wait(0.5)
        return CountSprinklerTools() < countBefore
    end
    Logic.DoPlaceSprinklerAt = DoPlaceSprinklerAt

    -- AUTO SPRINKLER LOOP
    -- Loop interval lebih panjang (cooldown 15s) karena placement butuh waktu.
    -- Loop akan berhenti otomatis jika semua tanaman sudah ter-cover atau sprinkler habis.
    local _sprinklerCooldown = 0
    task.spawn(function()
        while _G._MiracleHubSession == SESSION do
            task.wait(0.5)
            if States.autoSprinkler then
                local now = os.clock()
                if now >= _sprinklerCooldown then
                    pcall(function()
                        local tool, sprinklerName = AcquireSprinklerTool()
                        if not tool or not sprinklerName then
                            Notify("Auto Sprinkler", "\226\154\160 Tidak ada sprinkler di backpack!", Colors.Warning, 3)
                            _sprinklerCooldown = os.clock() + 5
                            return
                        end

                        local positions = GetSprinklerPlacePositions(20, sprinklerName)
                        if #positions == 0 then
                            local plantAreas = GetMyPlantAreas()
                            if #plantAreas == 0 then
                                Notify("Auto Sprinkler", "\226\154\160 PlantArea tidak ditemukan di Plot " .. MY_PLOT_ID, Colors.Warning, 3)
                            end
                            -- Kalau plantAreas ada tapi positions kosong, berarti plot
                            -- sudah full-covered sprinkler — tidak perlu notif tiap cycle.
                            _sprinklerCooldown = os.clock() + 15
                            return
                        end

                        local placed = 0
                        local failed = 0

                        for _, pos in ipairs(positions) do
                            if not States.autoSprinkler then break end

                            local curTool, curName = AcquireSprinklerTool()
                            if not curTool then
                                Notify("Auto Sprinkler", "\226\154\160 Sprinkler habis di backpack!", Colors.Warning, 3)
                                break
                            end
                            tool, sprinklerName = curTool, curName

                            local success = false
                            local ok = pcall(function()
                                success = DoPlaceSprinklerAt(pos, tool, sprinklerName)
                            end)

                            if ok and success then
                                placed = placed + 1
                            else
                                failed = failed + 1
                                if failed >= 3 then
                                    task.wait(1)
                                    failed = 0
                                end
                            end
                        end

                        if placed > 0 then
                            Notify("Auto Sprinkler \240\159\140\191",
                                "Pasang " .. placed .. "/" .. #positions .. " sprinkler di Plot " .. MY_PLOT_ID,
                                Colors.Success, 5)
                        else
                            Notify("Auto Sprinkler", "Tidak ada sprinkler yang berhasil dipasang. Pastikan kamu di plotmu dan sudah ada tanaman.", Colors.Warning)
                        end
                    end)
                    _sprinklerCooldown = os.clock() + 15
                end
            end
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
                    Notify("Auto Sell", "\226\157\140 Networking module tidak ditemukan!", Colors.Error)
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
                                    Notify("Auto Sell \226\156\133", "Sold " .. (result.SoldCount or #fruits) .. " buah = " .. tostring(result.SellPrice or 0) .. "\194\162", Colors.Gold, 10)
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
    local _notifiedEmpty = {}
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
                    for _, seedName in ipairs(targets) do
                        if States.autoBuySeed then
                            local stock = GetSeedStock(seedName)
                            if stock > 0 then
                                _notifiedEmpty[seedName] = false
                                BuySeedPacket(seedName, 1)
                                task.wait(States.buyDelay or 0.05)
                            else
                                if States.notifyBuy and not _notifiedEmpty[seedName] then
                                    _notifiedEmpty[seedName] = true
                                    Notify("Auto Buy", seedName .. " stok habis, menunggu restock...", Colors.TextMuted, 4)
                                end
                            end
                        end
                    end
                end)
            end
        end
    end)

    -- ====================== AUTO BUY GEAR LOOP ======================
    local _notifiedEmptyGear = {}
    task.spawn(function()
        while _G._MiracleHubSession == SESSION do
            task.wait(math.max(States.gearShopLoopDelay or 0.5, 0.1))
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
                    for _, gearName in ipairs(targets) do
                        if States.autoBuyGear then
                            local stock = GetGearStock(gearName)
                            if stock > 0 then
                                _notifiedEmptyGear[gearName] = false
                                BuyGearPacket(gearName, 1)
                                if States.notifyBuyGear then
                                    Notify("Auto Buy Gear", "\226\156\133 Beli: " .. gearName .. " (stok: " .. stock .. ")", Colors.Electric, 3)
                                end
                                task.wait(States.gearBuyDelay or 0.05)
                            else
                                if States.notifyBuyGear and not _notifiedEmptyGear[gearName] then
                                    _notifiedEmptyGear[gearName] = true
                                    Notify("Auto Buy Gear", gearName .. " stok habis, menunggu restock...", Colors.TextMuted, 4)
                                end
                            end
                        end
                    end
                end)
            end
        end
    end)

    -- ====================== AUTO BUY CRATE LOOP ======================
    local _notifiedEmptyCrate = {}
    task.spawn(function()
        while _G._MiracleHubSession == SESSION do
            task.wait(math.max(States.crateShopLoopDelay or 0.5, 0.1))
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
                    for _, crateName in ipairs(targets) do
                        if States.autoBuyCrate then
                            local stock = GetCrateStock(crateName)
                            if stock > 0 then
                                _notifiedEmptyCrate[crateName] = false
                                BuyCratePacket(crateName, 1)
                                if States.notifyBuyCrate then
                                    Notify("Auto Buy Crate", "\226\156\133 Beli: " .. crateName .. " (stok: " .. stock .. ")", Colors.Warning, 3)
                                end
                                task.wait(States.crateBuyDelay or 0.05)
                            else
                                if States.notifyBuyCrate and not _notifiedEmptyCrate[crateName] then
                                    _notifiedEmptyCrate[crateName] = true
                                    Notify("Auto Buy Crate", crateName .. " stok habis, menunggu restock...", Colors.TextMuted, 4)
                                end
                            end
                        end
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

    local function FireWildPetPrompt(part)
        if not part then return false end

        local prompt = part:FindFirstChildWhichIsA("ProximityPrompt", true)
        if not prompt and part.Parent then
            prompt = part.Parent:FindFirstChildWhichIsA("ProximityPrompt", true)
        end
        if prompt then
            return SafeFirePrompt(prompt)
        end

        return false
    end

    local function FireWildPetNetwork(part)
        if not part then return false end

        local petId = part.Name
        local petName = part:GetAttribute("PetName") or part:GetAttribute("Pet") or part:GetAttribute("Species") or petId

        if Networking then
            local petsNS = rawget(Networking, "Pets")
            if petsNS then
                local tame = rawget(petsNS, "WildPetTame")
                if tame and tame.Fire then
                    local payloads = {petId, petName, part}
                    for _, payload in ipairs(payloads) do
                        local ok = pcall(function() tame:Fire(payload) end)
                        if ok then return true end
                    end
                end
            end
        end

        if PacketRemote then
            local payloads = {petId, petName, part}
            for _, payload in ipairs(payloads) do
                local ok = pcall(function() PacketRemote:FireServer(payload) end)
                if ok then return true end
            end
        end

        return false
    end

    local function IsWildPetClaimed(part)
        if not part or not part.Parent then return true end
        if (tonumber(part:GetAttribute("OwnerUserId")) or 0) ~= 0 then return true end
        local state = part:GetAttribute("State") or ""
        if state ~= "" and state ~= "free" and state ~= "idle" then return true end
        return false
    end

    local function BuyWildPet(part)
        if not part or not part.Parent then return false end

        local function succeeded()
            return IsWildPetClaimed(part)
        end

        if FireWildPetPrompt(part) then
            task.wait(0.2)
            if succeeded() then return true end
        end

        if FireWildPetNetwork(part) then
            task.wait(0.25)
            if succeeded() then return true end
        end

        task.wait(0.25)
        if FireWildPetPrompt(part) then
            task.wait(0.2)
            if succeeded() then return true end
        end

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

    local function MakeESPLabel(adornee, text, color)
        local billboard = Create("BillboardGui", {
            Parent = game:GetService("Workspace"),
            Adornee = adornee,
            Size = UDim2.new(0, 120, 0, 30),
            StudsOffset = Vector3.new(0, 3, 0),
            AlwaysOnTop = true,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        })
        local frame = Create("Frame", {
            Parent = billboard,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
        })
        CreateCorner(frame, 5)
        Create("TextLabel", {
            Parent = frame,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = color or Colors.TextPrimary,
            TextSize = 11,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        return TrackESP(billboard)
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
            for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
                if p ~= player and p.Character then
                    local rootPart = p.Character:FindFirstChild("HumanoidRootPart")
                    if rootPart and not rootPart:FindFirstChild("MiracleESP_Player") then
                        local bb = MakeESPLabel(rootPart, p.DisplayName .. "\n@" .. p.Name, Colors.Electric)
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
                            local rarity = part:GetAttribute("Rarity") or "?"
                            local col = RarityColor and RarityColor[rarity] or Colors.Warning
                            MakeESPLabel(part, "\240\159\144\190 " .. rarity, col)
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
                    if rootPart and not rootPart:FindFirstChild("MiracleESP_Fruit") then
                        local seedName = fruit:GetAttribute("SeedName") or fruit.Name or "Fruit"
                        local weight = fruit:GetAttribute("Weight")
                        local mut = GetMutation(fruit)
                        local label = seedName
                        if States.showFruitWeight and weight then
                            label = label .. string.format(" %.2fkg", weight)
                        end
                        if States.espFruits and mut and mut ~= "" and mut ~= "None" then
                            label = mut .. " " .. label
                        end
                        local color = mut and mut ~= "" and mut ~= "None" and ctx.UI.GetMutationColor(mut) or Colors.Warning
                        MakeESPLabel(rootPart, label, color)
                        AttachESPMarker(rootPart, "MiracleESP_Fruit")
                    end
                end
            end
        end

        if States.espMutations then
            local plants = GetPlantsFolder()
            if plants then
                for _, plant in ipairs(plants:GetChildren()) do
                    local mut = GetMutation(plant)
                    if mut and mut ~= "" and mut ~= "None" then
                        local rootPart = GetModelRootPart(plant)
                        if rootPart and not rootPart:FindFirstChild("MiracleESP_Mut") then
                            local sn = plant:GetAttribute("SeedName") or "Plant"
                            MakeESPLabel(rootPart, mut .. " " .. sn, ctx.UI.GetMutationColor(mut))
                            AttachESPMarker(rootPart, "MiracleESP_Mut")
                        end
                    end
                end
            end
        end

        if States.showPlantAge then
            local plants = GetPlantsFolder()
            if plants then
                for _, plant in ipairs(plants:GetChildren()) do
                    local age = plant:GetAttribute("Age")
                    local maxAge = plant:GetAttribute("MaxAge")
                    if age and maxAge then
                        local rootPart = GetModelRootPart(plant)
                        if rootPart and not rootPart:FindFirstChild("MiracleESP_Age") then
                            local sn = plant:GetAttribute("SeedName") or "Plant"
                            MakeESPLabel(rootPart, sn .. " " .. age .. "/" .. maxAge, age >= maxAge and Colors.Success or Colors.TextMuted)
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