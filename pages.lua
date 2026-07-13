-- ======================================================================
-- Miracle Hub — pages.lua
-- All page builders. Loaded FOURTH (after core, ui, logic).
-- Registers each page via ctx.registerPage(name, builderFn).
--
-- Reads from ctx: Colors, States, Data, UI.*, Logic.*, player, services,
--   MY_PLOT_ID, MAX_FRUIT_CAP, MAX_EQUIPPED_PETS, GetActivePage, SESSION
-- ======================================================================

return function(ctx)
    local Colors            = ctx.Colors
    local States            = ctx.States
    local Data              = ctx.Data
    local player            = ctx.player
    local RunService        = ctx.RunService
    local CollectionService = ctx.CollectionService
    local ReplicatedStorage = ctx.ReplicatedStorage
    local MY_PLOT_ID        = ctx.MY_PLOT_ID
    local MAX_FRUIT_CAP     = ctx.MAX_FRUIT_CAP
    local MAX_EQUIPPED_PETS = ctx.MAX_EQUIPPED_PETS
    local SESSION           = ctx.SESSION
    local GetActivePage     = ctx.GetActivePage

    local UI    = ctx.UI
    local Logic = ctx.Logic

    -- UI shorthands
    local Create            = UI.Create
    local CreateCorner      = UI.CreateCorner
    local CreateStroke      = UI.CreateStroke
    local CreateListLayout  = UI.CreateListLayout
    local Tween             = UI.Tween
    local Notify            = UI.Notify
    local NotifyStok        = UI.NotifyStok
    local GetMutationColor  = UI.GetMutationColor
    local CreateSectionCard = UI.CreateSectionCard
    local CreateSubHeader   = UI.CreateSubHeader
    local CreateToggle      = UI.CreateToggle
    local CreateSlider      = UI.CreateSlider
    local CreateActionButton = UI.CreateActionButton
    local CreateDropdown    = UI.CreateDropdown
    local CreateMultiSelect = UI.CreateMultiSelect
    local CreateInfoText    = UI.CreateInfoText
    local CreateStatRow     = UI.CreateStatRow

    -- Data shorthands
    local SEEDS     = Data.SEEDS
    local GEARS     = Data.GEARS
    local CRATES    = Data.CRATES
    local CRATE_COST = Data.CRATE_COST
    local MUTATIONS = Data.MUTATIONS
    local PACKET    = Data.PACKET
    local SELL_VALUE_DATA = Data.SELL_VALUE_DATA

    -- Logic shorthands
    local GetMyPlot          = Logic.GetMyPlot
    local GetPlantsFolder    = Logic.GetPlantsFolder
    local GetMyPlantAreas    = Logic.GetMyPlantAreas
    local BuildValidPlantPositions = Logic.BuildValidPlantPositions
    local GetNextSeedFromBackpack  = Logic.GetNextSeedFromBackpack
    local DoPlantFire        = Logic.DoPlantFire
    local GetPlantedSeedCounts = Logic.GetPlantedSeedCounts
    local CountPlantedSlots  = Logic.CountPlantedSlots
    local GetReadyFruitCount = Logic.GetReadyFruitCount
    local DoHarvestAll       = Logic.DoHarvestAll
    local GetMutation        = Logic.GetMutation
    local SafeFirePrompt     = Logic.SafeFirePrompt
    local AcquireWateringCan = Logic.AcquireWateringCan
    local AcquireSprinklerTool = Logic.AcquireSprinklerTool
    local IsToolEquipped     = Logic.IsToolEquipped
    local HopToNearPos       = Logic.HopToNearPos
    local GetPlantWaterPos   = Logic.GetPlantWaterPos
    local GetPlantAreaParts             = Logic.GetPlantAreaParts
    local GetExistingSprinklerPositions = Logic.GetExistingSprinklerPositions
    local CalculateCoverage             = Logic.CalculateCoverage
    local DoPlaceSprinklerAt            = Logic.DoPlaceSprinklerAt
    local GetSeedStock       = Logic.GetSeedStock
    local GetCrateStock      = Logic.GetCrateStock
    local BuyCratePacket     = Logic.BuyCratePacket
    local OpenCrateViaNetworking = Logic.OpenCrateViaNetworking
    local GetCratesInInventory = Logic.GetCratesInInventory
    local MuteSFX_Failed     = Logic.MuteSFX_Failed
    local ShouldKeepFruit    = Logic.ShouldKeepFruit

    local Networking = ctx.Networking

    -- ====================== FARM PAGE ======================
    ctx.registerPage("Farm", function()
        local plantCard, plantContent = CreateSectionCard("\240\159\140\177 Auto Plant", 1, Colors.Success)

CreateInfoText(plantContent, "How It Works",
    "Automatically fills empty plot slots with seeds from your backpack. "
    .. "Select seeds below before enabling, or turn on 'Plant All' to skip selection."
)

        CreateToggle(plantContent, "Auto Plant", "autoPlant",
            "Fills empty plot slots, Needs at least one seed selected below (or enable Plant All)",
            function(newVal, revert)
                if newVal and not States.autoPlantAllSeeds then
                    local targets = States.autoPlantTargets or {}
                    if #targets == 0 then
                        revert()
                        Notify("Auto Plant", "\226\154\160\239\184\143 Select seeds in 'Choose Seeds to Plant' before enabling Auto Plant!", Colors.Warning, 5)
                        return
                    end
                end
            end)

        CreateToggle(plantContent, "Plant All Seeds in Backpack", "autoPlantAllSeeds",
            "Plants all seeds in backpack, ignoring the selection below")

        CreateMultiSelect(plantContent, " Choose Seeds to Plant", SEEDS, "autoPlantTargets")

        CreateToggle(plantContent, "Notify on Plant Cycle", "autoPlantNotify",
            "Notifies you each time a planting cycle completes")

        CreateActionButton(plantContent, "Plant Now", function()
            local plantAreas = GetMyPlantAreas()
            if #plantAreas == 0 then
                Notify("Farm", "No plant areas found on your plot. Make sure you're on your plot", Colors.Error)
                return
            end
            local firstSeed = GetNextSeedFromBackpack()
            if not firstSeed then
                Notify("Farm", "\226\154\160 No matching seeds in backpack.", Colors.Warning)
                return
            end
            Notify("Farm", "Planting on Plot " .. MY_PLOT_ID .. "...", Colors.Success)
            task.spawn(function()
                local validPos = BuildValidPlantPositions(plantAreas, 500)
                if #validPos == 0 then
                    Notify("Farm", "Plot " .. MY_PLOT_ID .. " is full — no empty slots available.", Colors.Warning)
                    return
                end
                local planted    = 0
                local plantedLog = {}
                for _, hitPos in ipairs(validPos) do
                    local seedEntry = GetNextSeedFromBackpack()
                    if not seedEntry then break end
                    local ok = pcall(DoPlantFire, seedEntry.tool, seedEntry.name, hitPos)
                    if ok then
                        planted = planted + 1
                        plantedLog[seedEntry.name] = (plantedLog[seedEntry.name] or 0) + 1
                    end
                    task.wait(0.3)
                end
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
                    NotifyStok(lines, Colors.Success, 8, "\240\159\140\177 Planted (+" .. planted .. " seeds)")
                else
                    Notify("Farm", "Nothing was planted.", Colors.Warning, 3)
                end
            end)
        end, Colors.Success)

        CreateActionButton(plantContent, "Scan Seeds in Backpack", function()
            local backpack = player:FindFirstChildOfClass("Backpack")
            if not backpack then
                Notify("Farm", "Backpack not found.", Colors.Error)
                return
            end
            local counts = {}
            local total = 0
            for _, tool in ipairs(backpack:GetChildren()) do
                if tool:IsA("Tool") then
                    local seedName = tool:GetAttribute("SeedTool")
                    if type(seedName) == "boolean" then seedName = tool.Name end
                    if type(seedName) ~= "string" or seedName == "" then
                        seedName = tool:GetAttribute("SeedName")
                    end
                    if not seedName then
                        for _, s in ipairs(SEEDS) do
                            if tool.Name == s or tool.Name == s .. " Seed" then
                                seedName = s break
                            end
                        end
                    end
                    if seedName then
                        counts[seedName] = (counts[seedName] or 0) + 1
                        total = total + 1
                    end
                end
            end
            if total == 0 then
                Notify("Farm", "No seeds found in backpack.", Colors.TextMuted)
                return
            end
            local lines = {}
            for name, cnt in pairs(counts) do
                table.insert(lines, name .. " x" .. cnt)
            end
            table.sort(lines)
            Notify("Seeds in Backpack (" .. total .. ")",
                table.concat(lines, " | "):sub(1, 200), Colors.Success, 7)
        end)

        CreateActionButton(plantContent, "Check Planted Slots", function()
            local seedCounts, totalPlanted = GetPlantedSeedCounts()
            local plantsFolder = GetPlantsFolder()
            local totalAll = plantsFolder and #plantsFolder:GetChildren() or 0
            if totalPlanted == 0 then
                Notify("Planted Slots", "No plants found on your plot.", Colors.TextMuted, 4)
                return
            end
            local lines = {}
            for name, cnt in pairs(seedCounts) do
                table.insert(lines, name .. " - " .. cnt)
            end
            table.sort(lines, function(a, b)
                local ca = tonumber(a:match("- (%d+)$")) or 0
                local cb = tonumber(b:match("- (%d+)$")) or 0
                return ca > cb
            end)
            NotifyStok(lines, Colors.Accent, 15, "\240\159\147\138 Mine: " .. totalPlanted .. " | Plot Total: " .. totalAll)
        end)

        local harvestCard, harvestContent = CreateSectionCard("\240\159\141\133 Auto Harvest", 2, Colors.Warning)
        CreateToggle(harvestContent, "Auto Harvest", "autoHarvest", "Automatically harvest fruits on your plot")
        CreateToggle(harvestContent, "Notify After Harvest", "notifyHarvest", "Show a notification after each harvest cycle")
        CreateSubHeader(harvestContent, "Delay Settings")
        CreateSlider(harvestContent, "Per-Fruit Delay (s)", 0, 2, "perFruitDelay")
        CreateSlider(harvestContent, "Loop Delay (s)", 0, 30, "harvestLoopDelay")
        CreateSubHeader(harvestContent, "Mutation Filter")
        CreateMultiSelect(harvestContent, "⏭️Skip Mutation", MUTATIONS, "harvestFilterMutation")
        CreateActionButton(harvestContent, "\226\154\161 Harvest All Now", function()
            local myPlot = GetMyPlot()
            if not myPlot then
                Notify("Harvest", "Your plot was not found!", Colors.Error)
                return
            end
            local currentCount = player:GetAttribute("FruitCount") or 0
            local remaining = MAX_FRUIT_CAP - currentCount
            if remaining <= 0 then
                Notify("Harvest", "\240\159\142\146 Backpack full! (" .. currentCount .. "/" .. MAX_FRUIT_CAP .. ")", Colors.Warning)
                return
            end
            local ready = GetReadyFruitCount()
            if ready == 0 then
                Notify("Harvest", "No fruits are ready to harvest right now.", Colors.TextMuted)
                return
            end
            local willHarvest = math.min(ready, remaining)
            Notify("Harvest", "Harvesting " .. willHarvest .. " fruits (bag " .. currentCount .. "/" .. MAX_FRUIT_CAP .. ")...", Colors.Warning)
            task.spawn(function()
                local harvested = DoHarvestAll(States.harvestFilterMutation, MAX_FRUIT_CAP)
                local after = player:GetAttribute("FruitCount") or 0
                Notify("Harvest", "Harvested " .. harvested .. " fruits | Bag " .. after .. "/" .. MAX_FRUIT_CAP, Colors.Success)
            end)
        end, Colors.Warning)
        CreateActionButton(harvestContent, "\240\159\148\141 Scan Fruits Ready", function()
            local myPlot = GetMyPlot()
            if not myPlot then Notify("Scan", "Your plot was not found!", Colors.Error) return end
            local readyList, total = {}, 0
            for _, prompt in ipairs(CollectionService:GetTagged("HarvestPrompt")) do
                if prompt:IsDescendantOf(myPlot) then
                    local harvestPart = prompt.Parent
                    local fruit = harvestPart and harvestPart.Parent
                    if fruit and fruit:IsA("Model") then
                        total = total + 1
                        if prompt.Enabled and not prompt:GetAttribute("Collected") then
                            local plant = fruit.Parent and fruit.Parent.Parent
                            local sn = (plant and plant:GetAttribute("SeedName"))
                                or fruit:GetAttribute("SeedName") or "?"
                            local mut = fruit:GetAttribute("Mutation") or ""
                            table.insert(readyList, sn .. (mut ~= "" and " ["..mut.."]" or ""))
                        end
                    end
                end
            end
            local currentCount = player:GetAttribute("FruitCount") or 0
            local msg = #readyList .. "/" .. total .. " ready | Bag " .. currentCount .. "/" .. MAX_FRUIT_CAP
                .. "\n" .. table.concat(readyList, ", "):sub(1, 80)
            Notify("Fruit Scanner \240\159\148\141", msg, Colors.Success, 7)
        end)

        local waterCard, waterContent = CreateSectionCard("\240\159\146\167 Watering & Sprinklers", 3, Colors.Electric)

        local WATERING_CANS = {}
        for _, g in ipairs(GEARS) do
            if g:lower():find("watering") then table.insert(WATERING_CANS, g) end
        end
        local SPRINKLER_LIST = {}
        for _, g in ipairs(GEARS) do
            if g:lower():find("sprinkler") then table.insert(SPRINKLER_LIST, g) end
        end

        CreateSubHeader(waterContent, "\240\159\146\167 Auto Water")
        CreateToggle(waterContent, "Auto Water Plants", "autoWater",
            "Automatically waters all plants on your plot using your selected watering can",
            function(newVal, revert)
                if newVal then
                    local targets = States.wateringCanTargets or {}
                    if #targets == 0 then
                        revert()
                        Notify("Auto Water", "\226\154\160\239\184\143 Select a Watering Can below before enabling!", Colors.Warning, 5)
                        return
                    end
                end
            end)
        CreateMultiSelect(waterContent, "\240\159\170\163 Choose Watering Can", WATERING_CANS, "wateringCanTargets")
        CreateToggle(waterContent, "Notify After Watering", "notifyHarvest",
            "Show a notification with how many plants were watered each cycle")
        CreateSlider(waterContent, "Per-Plant Delay (s)", 0, 2, "perFruitDelay")
        CreateSlider(waterContent, "Water Loop Delay (s)", 1, 60, "harvestLoopDelay")

        CreateActionButton(waterContent, "\240\159\146\167 Water All Now", function()
            if not Networking then
                Notify("Auto Water", "Networking not available!", Colors.Error)
                return
            end
            local selectedCans = States.wateringCanTargets or {}
            if #selectedCans == 0 then
                Notify("Auto Water", "\226\154\160\239\184\143 Select a Watering Can below before watering!", Colors.Warning, 5)
                return
            end
            local tool, canName = AcquireWateringCan()
            if not tool or not canName then
                Notify("Auto Water", "Selected Watering Can not found in backpack!", Colors.Error)
                return
            end
            local plants = GetPlantsFolder()
            if not plants then
                Notify("Auto Water", "No plants found on your plot!", Colors.Error)
                return
            end
            Notify("Auto Water \240\159\146\167", "Watering with " .. canName .. "...", Colors.Electric)
            task.spawn(function()
                local watered = 0
                for _, plant in ipairs(plants:GetChildren()) do
                    if plant:IsA("Model") then
                        local hitPos = GetPlantWaterPos(plant)
                        if hitPos then
                            if not IsToolEquipped(tool) then
                                local t2, cn2 = AcquireWateringCan()
                                if not t2 then break end
                                tool, canName = t2, cn2
                            end
                            HopToNearPos(hitPos)
                            pcall(function()
                                Networking.WateringCan.UseWateringCan:Fire(hitPos, canName, tool)
                            end)
                            watered = watered + 1
                            task.wait(math.max(States.perFruitDelay or 0.05, 0.05))
                        end
                    end
                end
                Notify("Auto Water", "Watered " .. watered .. " plants on Plot " .. MY_PLOT_ID, Colors.Success)
            end)
        end, Colors.Electric)

        CreateSubHeader(waterContent, "\240\159\140\191 Auto Sprinkler")
        CreateToggle(waterContent, "Auto Place Sprinklers", "autoSprinkler",
            "Automatically places sprinklers on areas that don't have one yet",
            function(newVal, revert)
                if newVal then
                    local targets = States.sprinklerTargets or {}
                    if #targets == 0 then
                        revert()
                        Notify("Auto Sprinkler", "\226\154\160\239\184\143 Select a Sprinkler below before enabling!", Colors.Warning, 5)
                        return
                    end
                end
            end)
        CreateMultiSelect(waterContent, "\240\159\140\191 Choose Sprinkler", SPRINKLER_LIST, "sprinklerTargets")

        CreateActionButton(waterContent, "\240\159\140\191 Place Sprinkler Now", function()
            if not Networking and not ctx.PacketRemote then
                Notify("Sprinkler", "Networking not available!", Colors.Error)
                return
            end
            local selectedTargets = States.sprinklerTargets or {}
            if #selectedTargets == 0 then
                Notify("Sprinkler", "\226\154\160\239\184\143 Select a sprinkler type in 'Choose Sprinkler' first!", Colors.Warning, 5)
                return
            end
            local tool, sprinklerName = AcquireSprinklerTool()
            if not tool or not sprinklerName then
                Notify("Sprinkler", "Selected sprinkler not found in backpack!", Colors.Error)
                return
            end

            -- Ambil PlantArea parts milik plot kita
            local plantAreaParts = GetPlantAreaParts()
            if #plantAreaParts == 0 then
                Notify("Sprinkler", "\226\154\160\239\184\143 PlantArea tidak ditemukan di plot kamu!", Colors.Warning)
                return
            end

            -- Radius per sprinkler type (sync dengan logic.lua)
            local SPRINKLER_RADII_LOCAL = {
                ["Common Sprinkler"]    = 20,
                ["Uncommon Sprinkler"]  = 25,
                ["Rare Sprinkler"]      = 30,
                ["Legendary Sprinkler"] = 40,
                ["Super Sprinkler"]     = 55,
            }
            local radius = SPRINKLER_RADII_LOCAL[sprinklerName] or 20

            -- Ambil posisi sprinkler yang sudah ada
            local existingPos = GetExistingSprinklerPositions()

            -- Grid step kecil (8 studs) agar titik lebih rapat dan tidak miss PlantArea
            local step = 8
            local candidates = {}
            for _, area in ipairs(plantAreaParts) do
                local cf = area.CFrame
                local sz = area.Size
                local margin = 2.0
                local lx = -sz.X/2 + margin
                while lx <= sz.X/2 - margin do
                    local lz = -sz.Z/2 + margin
                    while lz <= sz.Z/2 - margin do
                        local wp = cf:PointToWorldSpace(Vector3.new(lx, sz.Y/2, lz))
                        table.insert(candidates, Vector2.new(wp.X, wp.Z))
                        lz = lz + step
                    end
                    lx = lx + step
                end
            end

            Notify("Sprinkler [DEBUG]",
                "PlantAreas: " .. #plantAreaParts ..
                " | Kandidat titik: " .. #candidates ..
                " | Existing sprinkler: " .. #existingPos ..
                " | Radius: " .. radius,
                Colors.TextMuted, 8)

            if #candidates == 0 then
                Notify("Sprinkler", "\226\154\160 Tidak ada kandidat titik di PlantArea!", Colors.Error)
                return
            end

            -- Filter kandidat yang belum ter-cover sprinkler existing
            local function isCoveredLocal(pt, sprPos)
                for _, sp in ipairs(sprPos) do
                    local dx, dz = pt.X - sp.X, pt.Y - sp.Y
                    if dx*dx + dz*dz <= radius * radius then return true end
                end
                return false
            end

            -- Greedy: ambil titik yg tidak covered, tapi pilih yg paling jauh dari semua sprinkler existing
            -- (untuk spread optimal)
            local placed_positions = {table.unpack(existingPos)}
            local targets_to_place = {}
            local remaining = {table.unpack(candidates)}
            while #remaining > 0 do
                -- Cari titik yang tidak covered
                local best = nil
                local bestScore = -1
                local bestIdx = nil
                for i, pt in ipairs(remaining) do
                    if not isCoveredLocal(pt, placed_positions) then
                        -- Score: min distance ke sprinkler terdekat (lebih jauh = lebih baik)
                        local minDist = math.huge
                        for _, sp in ipairs(placed_positions) do
                            local dx, dz = pt.X - sp.X, pt.Y - sp.Y
                            local d = dx*dx + dz*dz
                            if d < minDist then minDist = d end
                        end
                        if #placed_positions == 0 then minDist = math.huge end
                        if minDist > bestScore then
                            bestScore = minDist
                            best = pt
                            bestIdx = i
                        end
                    end
                end
                if not best then break end
                table.insert(targets_to_place, best)
                table.insert(placed_positions, best)
                -- Hapus titik yang sekarang ter-cover oleh sprinkler baru ini
                local newRemaining = {}
                for _, pt in ipairs(remaining) do
                    if not isCoveredLocal(pt, {best}) then
                        table.insert(newRemaining, pt)
                    end
                end
                remaining = newRemaining
            end

            if #targets_to_place == 0 then
                Notify("Sprinkler", "Semua area sudah ter-cover sprinkler \240\159\140\191", Colors.Success)
                return
            end

            Notify("Sprinkler \240\159\140\191",
                "Akan place " .. #targets_to_place .. " sprinkler (" .. sprinklerName .. ", r=" .. radius .. ")...",
                Colors.Success)

            task.spawn(function()
                local placed = 0
                for i, pt in ipairs(targets_to_place) do
                    -- Re-acquire tool di awal setiap iterasi (tool dikonsumsi server setelah place)
                    if i > 1 then
                        task.wait(0.3)
                        local t2, sn2 = AcquireSprinklerTool()
                        if not t2 then
                            Notify("Sprinkler", "Habis sprinkler di backpack! (" .. placed .. "/" .. #targets_to_place .. " placed)", Colors.Error)
                            break
                        end
                        tool, sprinklerName = t2, sn2
                    end
                    local ok = false
                    local errMsg = ""
                    pcall(function()
                        ok = DoPlaceSprinklerAt(pt.X, pt.Y, plantAreaParts, tool, sprinklerName)
                    end)
                    if ok then
                        placed = placed + 1
                    else
                        Notify("Sprinkler [DEBUG]",
                            "Place " .. i .. "/" .. #targets_to_place ..
                            " GAGAL @ (" .. math.floor(pt.X) .. ", " .. math.floor(pt.Y) .. ")",
                            Colors.Warning, 4)
                    end
                end
                if placed > 0 then
                    Notify("Sprinkler",
                        "Placed " .. placed .. "/" .. #targets_to_place .. " sprinklers on Plot " .. MY_PLOT_ID,
                        Colors.Success, 5)
                else
                    Notify("Sprinkler", "Tidak ada sprinkler yang berhasil di-place. Cek debug di atas!", Colors.Warning)
                end
            end)
        end, Colors.Success)

        CreateActionButton(waterContent, "\240\159\148\141 Scan Sprinklers on Plot", function()
            local myPlot = GetMyPlot()
            if not myPlot then
                Notify("Scan", "Your plot was not found!", Colors.Error)
                return
            end
            local sprinklers = {}
            for _, obj in ipairs(myPlot:GetDescendants()) do
                if obj:IsA("Model") and obj:GetAttribute("Sprinkler") then
                    local sn = obj:GetAttribute("Sprinkler") or obj.Name
                    table.insert(sprinklers, sn .. " @ " .. tostring(obj.Name))
                end
            end
            if #sprinklers == 0 then
                Notify("Sprinkler Scan", "No sprinklers found on your plot.", Colors.TextMuted)
            else
                NotifyStok(sprinklers, Colors.Success, 10, "\240\159\140\191 Sprinklers on Plot (" .. #sprinklers .. ")")
            end
        end, Colors.Accent)
    end)

    -- ====================== PLOT PAGE ======================
    ctx.registerPage("Plot", function()
        local plotCard, plotContent = CreateSectionCard("\240\159\147\144 My Plot \226\128\148 Plot " .. MY_PLOT_ID, 1, Colors.Accent)

        local statsGrid = Create("Frame", {
            Parent = plotContent,
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
        })
        CreateListLayout(statsGrid, 5)

        CreateStatRow(statsGrid, "My Plot ID", MY_PLOT_ID, Colors.Success)
        local _, fruitCntLbl = CreateStatRow(statsGrid, "Fruit Count (Player Attr)", player:GetAttribute("FruitCount") or "?", Colors.Warning)
        local _, maxFruitLbl = CreateStatRow(statsGrid, "Max Fruit Capacity", MAX_FRUIT_CAP, Colors.Accent)
        local _, petSlotLbl = CreateStatRow(statsGrid, "Max Equipped Pets", MAX_EQUIPPED_PETS, Colors.Rainbow)
        local _, gardenLikesLbl = CreateStatRow(statsGrid, "Garden Likes", player:GetAttribute("GardenLikes") or 0, Colors.Gold)
        local _, plantCntLbl = CreateStatRow(statsGrid, "Plants on Plot", "...", Colors.TextSecondary)
        local _, readyCntLbl = CreateStatRow(statsGrid, "Ready to Harvest", "...", Colors.Success)

        local plotPageAlive = true
        task.spawn(function()
            while plotPageAlive and GetActivePage() == "Plot" do
                task.wait(1)
                if not plotPageAlive or GetActivePage() ~= "Plot" then break end
                pcall(function()
                    fruitCntLbl.Text = tostring(player:GetAttribute("FruitCount") or "?")
                    maxFruitLbl.Text = tostring(player:GetAttribute("MaxFruitCapacity") or MAX_FRUIT_CAP)
                    petSlotLbl.Text = tostring(player:GetAttribute("MaxEquippedPets") or MAX_EQUIPPED_PETS)
                    gardenLikesLbl.Text = tostring(player:GetAttribute("GardenLikes") or 0)
                    local myPlot = GetMyPlot()
                    if not myPlot then return end
                    local total, readyFruits = 0, 0
                    local plantsF = myPlot:FindFirstChild("Plants")
                    if plantsF then
                        for _, p in ipairs(plantsF:GetChildren()) do
                            if p:IsA("Model") then total = total + 1 end
                        end
                    end
                    for _, prompt in ipairs(CollectionService:GetTagged("HarvestPrompt")) do
                        if prompt.Enabled and not prompt:GetAttribute("Collected")
                            and prompt:IsDescendantOf(myPlot) then
                            readyFruits = readyFruits + 1
                        end
                    end
                    plantCntLbl.Text = tostring(total)
                    readyCntLbl.Text = tostring(readyFruits)
                end)
            end
        end)
        local _plotConn
        _plotConn = RunService.Heartbeat:Connect(function()
            if GetActivePage() ~= "Plot" then
                plotPageAlive = false
                _plotConn:Disconnect()
            end
        end)

    end)

    -- ====================== SHOP PAGE ======================
    ctx.registerPage("Shop", function()
        local buyCard, buyContent = CreateSectionCard("\240\159\155\146 Auto Buy Seeds", 1, Colors.Success)

        -- Guard: timestamp notif terakhir "no target" — rate-limit 5 detik
        local _lastNoTargetNotifTime = 0
        local NO_TARGET_NOTIF_COOLDOWN = 5

        local autoBuyToggleBg, autoBuyKnob  -- referensi visual toggle Auto Buy Seeds
        -- Shared control bridge: diisi oleh do-block setelah CreateMultiSelect selesai.
        -- Toggle callback pakai table ini sehingga tidak ada ordering issue (closure capture).
        local _msControl = { SetDisabled = nil }  -- akan diisi oleh do-block di bawah

        -- Toggle Auto Buy Seeds
        local autoBuyContainer, getAutoBuyState = CreateToggle(buyContent, "Auto Buy Seeds", "autoBuySeed",
            "Rapidly buys selected seeds, stops when out of stock",
            function(newVal, revert)
                if newVal and not States.autoBuyAll then
                    local targets = States.autoBuySeedTargets or {}
                    if #targets == 0 then
                        revert()
                        -- Rate-limit notif "no target" supaya tidak spam
                        local now = os.clock()
                        if now - _lastNoTargetNotifTime >= NO_TARGET_NOTIF_COOLDOWN then
                            _lastNoTargetNotifTime = now
                            Notify("Auto Buy", "\226\154\160\239\184\143 Select seeds below before enabling Auto Buy!", Colors.Warning, 5)
                        end
                        return
                    end
                end
                if newVal then
                    pcall(function() Logic.ResetNotifiedEmpty() end)
                    pcall(MuteSFX_Failed)
                end
            end
        )

        -- Simpan referensi visual toggle untuk force-off dari luar
        -- (toggleBg = child Frame ke-3, knob = child-nya toggleBg)
        pcall(function()
            for _, ch in ipairs(autoBuyContainer:GetChildren()) do
                if ch:IsA("Frame") and ch.Size == UDim2.new(0, 48, 0, 26) then
                    autoBuyToggleBg = ch
                    autoBuyKnob = ch:FindFirstChildWhichIsA("Frame")
                    break
                end
            end
        end)

        local function ForceOffAutoBuy()
            States.autoBuySeed = false
            pcall(function() SaveState("autoBuySeed", false) end)
            if autoBuyToggleBg then
                Tween(autoBuyToggleBg, {BackgroundColor3 = Colors.ToggleOff}, 0.2)
            end
            if autoBuyKnob then
                Tween(autoBuyKnob, {Position = UDim2.new(0, 3, 0.5, -10)}, 0.2)
            end
        end

        -- Toggle Buy ALL available seeds
        CreateToggle(buyContent, "Buy ALL available seeds", "autoBuyAll",
            "ON: buys every seed that has stock | OFF: only selected seeds",
            function(newVal)
                pcall(function() Logic.ResetNotifiedEmpty() end)
                -- _msControl.SetDisabled diisi oleh do-block di bawah setelah widget dibuat
                if _msControl.SetDisabled then
                    pcall(function() _msControl.SetDisabled(newVal) end)
                end
                -- Saat Buy ALL dimatikan: cek targets kosong → force off Auto Buy
                if not newVal then
                    local targets = States.autoBuySeedTargets or {}
                    if #targets == 0 and States.autoBuySeed then
                        ForceOffAutoBuy()
                        Notify("Auto Buy", "Buy ALL dimatikan & tidak ada seed dipilih — Auto Buy Seeds dinonaktifkan.", Colors.Warning, 5)
                    end
                end
            end
        )

        -- MultiSelect wrapper dengan polling
        do
            local _prevTargetCount = #(States.autoBuySeedTargets or {})
            -- CreateMultiSelect return table {instance, SetDisabled}
            -- wrapper sudah auto-parented ke buyContent di dalam CreateMultiSelect
            local msResult = CreateMultiSelect(buyContent, "\240\159\140\177Choose Target Seeds", SEEDS, "autoBuySeedTargets")
            -- Sambungkan ke shared bridge — toggle callback di atas bisa pakai ini sekarang
            _msControl.SetDisabled = msResult.SetDisabled

            -- Terapkan disabled state awal jika Buy ALL sudah ON saat load
            if States.autoBuyAll then
                task.defer(function()
                    if _msControl.SetDisabled then
                        pcall(function() _msControl.SetDisabled(true) end)
                    end
                end)
            end

            task.spawn(function()
                while true do
                    task.wait(0.3)
                    local cur = #(States.autoBuySeedTargets or {})
                    if cur ~= _prevTargetCount then
                        _prevTargetCount = cur
                        pcall(function() Logic.ResetNotifiedEmpty() end)
                    end
                    -- Continuous guard: force off jika Auto Buy ON tapi tidak ada coverage
                    -- (Buy ALL OFF dan tidak ada seed dipilih) — tangkap semua case termasuk
                    -- Buy ALL yang dimatikan saat target sudah kosong dari awal
                    if States.autoBuySeed and not States.autoBuyAll and cur == 0 then
                        ForceOffAutoBuy()
                        Notify("Auto Buy", "Tidak ada seed dipilih — Auto Buy Seeds dinonaktifkan.", Colors.Warning, 4)
                    end
                end
            end)
        end
        CreateToggle(buyContent, "Notify on Purchase", "notifyBuy", "Show a notification each time a seed is bought")

        -- Auto Buy Gear
        local gearCard, gearContent = CreateSectionCard("\226\154\153\239\184\143 Auto Buy Gear", 2, Colors.Electric)

        local autoBuyGearToggleBg, autoBuyGearKnob
        local _msGearControl = { SetDisabled = nil }

        -- Guard: rate-limit notif "no target" supaya tidak spam
        local _lastNoTargetGearNotifTime = 0

        local autoBuyGearContainer = CreateToggle(gearContent, "Auto Buy Gear", "autoBuyGear",
            "Rapidly buys selected gear, stops when out of stock",
            function(newVal, revert)
                if newVal and not States.autoBuyGearAll then
                    local targets = States.autoBuyGearTargets or {}
                    if #targets == 0 then
                        revert()
                        local now = os.clock()
                        if now - _lastNoTargetGearNotifTime >= NO_TARGET_NOTIF_COOLDOWN then
                            _lastNoTargetGearNotifTime = now
                            Notify("Auto Buy Gear", "\226\154\160\239\184\143 Select gear below before enabling!", Colors.Warning, 5)
                        end
                        return
                    end
                end
                if newVal then
                    pcall(function() Logic.ResetNotifiedEmptyGear() end)
                    pcall(MuteSFX_Failed)
                end
            end
        )
        pcall(function()
            for _, ch in ipairs(autoBuyGearContainer:GetChildren()) do
                if ch:IsA("Frame") and ch.Size == UDim2.new(0, 48, 0, 26) then
                    autoBuyGearToggleBg = ch
                    autoBuyGearKnob = ch:FindFirstChildWhichIsA("Frame")
                    break
                end
            end
        end)
        local function ForceOffAutoBuyGear()
            States.autoBuyGear = false
            pcall(function() SaveState("autoBuyGear", false) end)
            if autoBuyGearToggleBg then Tween(autoBuyGearToggleBg, {BackgroundColor3 = Colors.ToggleOff}, 0.2) end
            if autoBuyGearKnob then Tween(autoBuyGearKnob, {Position = UDim2.new(0, 3, 0.5, -10)}, 0.2) end
        end

        CreateToggle(gearContent, "Buy ALL available gear", "autoBuyGearAll",
            "ON: buys every gear that has stock | OFF: only selected gear",
            function(newVal)
                pcall(function() Logic.ResetNotifiedEmptyGear() end)
                if _msGearControl.SetDisabled then
                    pcall(function() _msGearControl.SetDisabled(newVal) end)
                end
                if not newVal then
                    local targets = States.autoBuyGearTargets or {}
                    if #targets == 0 and States.autoBuyGear then
                        ForceOffAutoBuyGear()
                        Notify("Auto Buy Gear", "Buy ALL dimatikan & tidak ada gear dipilih \226\128\148 Auto Buy Gear dinonaktifkan.", Colors.Warning, 5)
                    end
                end
            end
        )
        do
            local _prevGearCount = #(States.autoBuyGearTargets or {})
            local msGearResult = CreateMultiSelect(gearContent, "\226\154\153\239\184\143Choose Target Gear", GEARS, "autoBuyGearTargets")
            _msGearControl.SetDisabled = msGearResult.SetDisabled
            if States.autoBuyGearAll then
                task.defer(function()
                    if _msGearControl.SetDisabled then
                        pcall(function() _msGearControl.SetDisabled(true) end)
                    end
                end)
            end
            task.spawn(function()
                while true do
                    task.wait(0.3)
                    local cur = #(States.autoBuyGearTargets or {})
                    if cur ~= _prevGearCount then
                        _prevGearCount = cur
                        pcall(function() Logic.ResetNotifiedEmptyGear() end)
                    end
                    -- Continuous guard: force off jika Auto Buy Gear ON tapi tidak ada coverage
                    if States.autoBuyGear and not States.autoBuyGearAll and cur == 0 then
                        ForceOffAutoBuyGear()
                        Notify("Auto Buy Gear", "Tidak ada gear dipilih \226\128\148 Auto Buy Gear dinonaktifkan.", Colors.Warning, 4)
                    end
                end
            end)
        end
        CreateToggle(gearContent, "Notify on Purchase", "notifyBuyGear", "Show a notification each time a gear is bought")

        -- Auto Buy Crate
        local crateCard, crateContent = CreateSectionCard("\240\159\147\166 Auto Buy Crate", 3, Colors.Warning)

        local autoBuyCrateToggleBg, autoBuyCrateKnob
        local _msCrateControl = { SetDisabled = nil }

        -- Guard: rate-limit notif "no target" supaya tidak spam
        local _lastNoTargetCrateNotifTime = 0

        local autoBuyCrateContainer = CreateToggle(crateContent, "Auto Buy Crate", "autoBuyCrate",
            "Rapidly buys selected crates, stops when out of stock",
            function(newVal, revert)
                if newVal and not States.autoBuyCrateAll then
                    local targets = States.autoBuyCrateTargets or {}
                    if #targets == 0 then
                        revert()
                        local now = os.clock()
                        if now - _lastNoTargetCrateNotifTime >= NO_TARGET_NOTIF_COOLDOWN then
                            _lastNoTargetCrateNotifTime = now
                            Notify("Auto Buy Crate", "\226\154\160\239\184\143 Select crates below before enabling!", Colors.Warning, 5)
                        end
                        return
                    end
                end
                if newVal then
                    pcall(function() Logic.ResetNotifiedEmptyCrate() end)
                    pcall(MuteSFX_Failed)
                end
            end
        )
        pcall(function()
            for _, ch in ipairs(autoBuyCrateContainer:GetChildren()) do
                if ch:IsA("Frame") and ch.Size == UDim2.new(0, 48, 0, 26) then
                    autoBuyCrateToggleBg = ch
                    autoBuyCrateKnob = ch:FindFirstChildWhichIsA("Frame")
                    break
                end
            end
        end)
        local function ForceOffAutoBuyCrate()
            States.autoBuyCrate = false
            pcall(function() SaveState("autoBuyCrate", false) end)
            if autoBuyCrateToggleBg then Tween(autoBuyCrateToggleBg, {BackgroundColor3 = Colors.ToggleOff}, 0.2) end
            if autoBuyCrateKnob then Tween(autoBuyCrateKnob, {Position = UDim2.new(0, 3, 0.5, -10)}, 0.2) end
        end

        CreateToggle(crateContent, "Buy ALL available crates", "autoBuyCrateAll",
            "ON: buys every crate that has stock | OFF: only selected crates",
            function(newVal)
                pcall(function() Logic.ResetNotifiedEmptyCrate() end)
                if _msCrateControl.SetDisabled then
                    pcall(function() _msCrateControl.SetDisabled(newVal) end)
                end
                if not newVal then
                    local targets = States.autoBuyCrateTargets or {}
                    if #targets == 0 and States.autoBuyCrate then
                        ForceOffAutoBuyCrate()
                        Notify("Auto Buy Crate", "Buy ALL dimatikan & tidak ada crate dipilih \226\128\148 Auto Buy Crate dinonaktifkan.", Colors.Warning, 5)
                    end
                end
            end
        )
        do
            local _prevCrateCount = #(States.autoBuyCrateTargets or {})
            local msCrateResult = CreateMultiSelect(crateContent, "\240\159\147\166Choose Target Crates", CRATES, "autoBuyCrateTargets")
            _msCrateControl.SetDisabled = msCrateResult.SetDisabled
            if States.autoBuyCrateAll then
                task.defer(function()
                    if _msCrateControl.SetDisabled then
                        pcall(function() _msCrateControl.SetDisabled(true) end)
                    end
                end)
            end
            task.spawn(function()
                while true do
                    task.wait(0.3)
                    local cur = #(States.autoBuyCrateTargets or {})
                    if cur ~= _prevCrateCount then
                        _prevCrateCount = cur
                        pcall(function() Logic.ResetNotifiedEmptyCrate() end)
                    end
                    -- Continuous guard: force off jika Auto Buy Crate ON tapi tidak ada coverage
                    if States.autoBuyCrate and not States.autoBuyCrateAll and cur == 0 then
                        ForceOffAutoBuyCrate()
                        Notify("Auto Buy Crate", "Tidak ada crate dipilih \226\128\148 Auto Buy Crate dinonaktifkan.", Colors.Warning, 4)
                    end
                end
            end)
        end
        CreateToggle(crateContent, "Notify on Purchase", "notifyBuyCrate", "Show a notification each time a crate is bought")

        -- Auto Open Crate
        local openCrateCard, openCrateContent = CreateSectionCard("\240\159\142\129 Auto Open Crate", 4, Colors.Gold)
        CreateToggle(openCrateContent, "Auto Open Crate", "autoOpenCrate", "Automatically opens all crates in your backpack")
        CreateSlider(openCrateContent, "Delay Between Opens (s)", 1, 30, "crateOpenDelay")
        CreateToggle(openCrateContent, "Notify on Open", "notifyOpenCrate", "Show what item you received when a crate is opened")
        CreateActionButton(openCrateContent, "\240\159\148\141 Scan Crates in Backpack", function()
            local cratesInBag = GetCratesInInventory()
            if #cratesInBag == 0 then Notify("Scan Crates", "No crates found in backpack.", Colors.TextMuted) return end
            local names = {}
            for _, entry in ipairs(cratesInBag) do table.insert(names, entry.name) end
            Notify("Crates in Bag (" .. #cratesInBag .. ")", table.concat(names, ", "):sub(1, 150), Colors.Warning, 6)
        end)

    end)

    -- ====================== SELL PAGE ======================
    ctx.registerPage("Sell", function()
        local sellCard, sellContent = CreateSectionCard("\240\159\146\176 Auto Sell", 1, Colors.Gold)
        local netStatus = Networking and "Sell system ready." or "Sell system unavailable \226\128\148 reload the hub if this persists."
        CreateInfoText(sellContent, "How It Works", netStatus .. "\nAuto Sell continuously sells all fruits in your backpack. Use filters below to keep specific mutations.")
        CreateToggle(sellContent, "Auto Sell Fruits", "autoSell", "Continuously sells all fruits in your backpack automatically")
        CreateToggle(sellContent, "Keep Mutated Fruits", "keepMutations", "Skip all fruits that have any mutation")
        CreateMultiSelect(sellContent, "🔒Keep Specific Mutations", MUTATIONS, "sellKeepMutation")
        CreateSlider(sellContent, "Delay Between Sells (s)", 0, 3, "sellDelay")
        CreateSlider(sellContent, "Loop Delay (s)", 1, 60, "sellLoopDelay")
        CreateToggle(sellContent, "Notify on Sell", "notifySell", "Show a notification with sell totals after each cycle")

        CreateActionButton(sellContent, "\240\159\148\141 Preview Inventory Value", function()
            if not Networking then Notify("Preview", "Sell system unavailable!", Colors.Error) return end
            local ok, data = pcall(function() return Networking.NPCS.PreviewSellAll:Fire() end)
            if ok and data and data.FruitCount then
                local ddok, dddata = pcall(function() return Networking.NPCS.CheckDailyDeal:Fire() end)
                local ddAvail = ddok and dddata and dddata.Available
                local msg = data.FruitCount .. " fruits | Normal: " .. tostring(data.TotalValue or 0) .. "\194\162"
                if ddAvail then
                    local ddPrice = math.max(1, math.floor((data.TotalBaseValue or data.TotalValue or 0) * 5))
                    msg = msg .. " | Daily Deal: " .. tostring(ddPrice) .. "\194\162 (5x!) \226\173\144"
                end
                Notify("Preview Sell", msg, Colors.Gold, 6)
            else
                Notify("Preview Sell", "No fruits in backpack.", Colors.TextMuted)
            end
        end)
        CreateActionButton(sellContent, "\226\154\161 Sell All Now", function()
            if not Networking then Notify("Sell", "Sell system unavailable! Try reloading the hub.", Colors.Error) return end
            local ok, result = pcall(function() return Networking.NPCS.SellAll:Fire() end)
            if ok and result and result.Success then
                Notify("Sell", "Sold " .. (result.SoldCount or "?") .. " fruits = " .. tostring(result.SellPrice or 0) .. "\194\162", Colors.Gold, 10)
            else
                Notify("Sell", "Failed: " .. tostring(result and result.Reason or "Networking error"), Colors.Error)
            end
        end, Colors.Gold)
        CreateActionButton(sellContent, "\240\159\142\175 Sell with Filters", function()
            if not Networking then Notify("Sell", "Sell system unavailable!", Colors.Error) return end
            local fruits = {}
            for _, tool in ipairs(player.Backpack:GetChildren()) do
                if tool:GetAttribute("FruitName") or tool:GetAttribute("HarvestedFruit") then
                    table.insert(fruits, tool)
                end
            end
            if #fruits == 0 then Notify("Sell", "No fruits in backpack.", Colors.TextMuted) return end
            local sold, skipped = 0, 0
            for _, tool in ipairs(fruits) do
                if ShouldKeepFruit(tool) then
                    skipped = skipped + 1
                else
                    local fruitId = tool:GetAttribute("Id")
                    if not fruitId then
                        skipped = skipped + 1
                    else
                        local ok, result = pcall(function() return Networking.NPCS.SellFruit:Fire(fruitId) end)
                        if ok and result and result.Success then
                            sold = sold + 1
                        elseif result and result.Reason == "Favorited" then
                            skipped = skipped + 1
                        end
                    end
                end
                task.wait(States.sellDelay or 0.1)
            end
            Notify("Sell with Filters", "Sold " .. sold .. " fruit(s), skipped " .. skipped, Colors.Gold, 10)
        end)

        local bagCard, bagContent = CreateSectionCard("\240\159\142\146 Bag Inspector", 2, Colors.Accent)
        local _, fruitLbl = CreateStatRow(bagContent, "Harvested Fruits in Bag", "?", Colors.Warning)
        local _, seedLbl = CreateStatRow(bagContent, "Seeds in Bag", "?", Colors.Success)
        local _, petCntLbl = CreateStatRow(bagContent, "Pets in Bag", "?", Colors.Frozen)
        local _, capLbl = CreateStatRow(bagContent, "Capacity", "? / " .. MAX_FRUIT_CAP, Colors.Accent)
        task.spawn(function()
            while GetActivePage() == "Sell" do
                task.wait(0.5)
                if GetActivePage() ~= "Sell" then break end
                local fruits, seeds, pets, g = 0, 0, 0, 0
                for _, t in ipairs(player.Backpack:GetChildren()) do
                    if t:GetAttribute("HarvestedFruit") then fruits = fruits + 1
                    elseif t:GetAttribute("SeedTool") or t:GetAttribute("SeedName") then seeds = seeds + 1
                    elseif t:GetAttribute("Pet") then pets = pets + 1
                    else g = g + 1 end
                end
                fruitLbl.Text  = tostring(fruits)
                seedLbl.Text   = tostring(seeds)
                petCntLbl.Text = tostring(pets)
                capLbl.Text    = fruits .. " / " .. tostring(player:GetAttribute("MaxFruitCapacity") or MAX_FRUIT_CAP)
            end
        end)
        CreateActionButton(bagContent, "\240\159\147\139 List All Fruits in Bag", function()
            local items = {}
            for _, t in ipairs(player.Backpack:GetChildren()) do
                local fn = t:GetAttribute("FruitName")
                if fn then
                    local mut = GetMutation(t)
                    local sm = t:GetAttribute("SizeMultiplier") or 1
                    local entry = fn
                    if mut ~= "" and mut ~= "None" then entry = "[" .. mut .. "] " .. entry end
                    entry = entry .. " x" .. string.format("%.2f", sm)
                    table.insert(items, entry)
                end
            end
            if #items == 0 then Notify("Bag", "No fruits in backpack.", Colors.TextMuted)
            else
                Notify("Bag (" .. #items .. " fruits)", table.concat(items, ", "):sub(1, 150), Colors.Accent, 7)
            end
        end)
    end)

    -- ====================== PETS PAGE ======================
    ctx.registerPage("Pets", function()
        local ScanWildPets = Logic.ScanWildPets
        local HumanizePetName = Logic.HumanizePetName
        local RarityColor = Logic.RarityColor
        local PET_RARITY_LOOKUP = Logic.PET_RARITY_LOOKUP
        local SmartMoveToPet = Logic.SmartMoveToPet
        local BuyWildPet = Logic.BuyWildPet
        local IsWildPetFree = Logic.IsWildPetFree

        local petCard, petContent = CreateSectionCard("\240\159\144\190 Pet Inventory", 1, Colors.Frozen)
        local rarityOrd = {Super=6, Mythic=5, Legendary=4, Rare=3, Uncommon=2, Common=1}
        local sizeOrd   = {Huge=3, Big=2, Normal=1}

        local listArea = Create("Frame", {Parent = petContent, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1})
        CreateListLayout(listArea, 6)

        local function RebuildInventory()
            if not listArea or not listArea.Parent then return end
            for _, c in ipairs(listArea:GetChildren()) do
                if not c:IsA("UIListLayout") then c:Destroy() end
            end
            local playerPets = {}
            for _, t in ipairs(player.Backpack:GetChildren()) do
                local petName = t:GetAttribute("Pet") or t:GetAttribute("PetSpecies")
                local petSize = t:GetAttribute("PetSize") or "Normal"
                local petType = t:GetAttribute("PetType") or ""
                if petName then
                    table.insert(playerPets, {name=petName, size=petSize, petType=petType})
                end
            end
            table.sort(playerPets, function(a, b)
                local ra = rarityOrd[PET_RARITY_LOOKUP[a.name] or ""] or 0
                local rb = rarityOrd[PET_RARITY_LOOKUP[b.name] or ""] or 0
                if ra ~= rb then return ra > rb end
                return (sizeOrd[a.size] or 1) > (sizeOrd[b.size] or 1)
            end)
            CreateSubHeader(listArea, "Pets in Backpack (" .. #playerPets .. ")")
            if #playerPets == 0 then
                CreateInfoText(listArea, nil, "No pets in backpack.", Colors.TextMuted)
                return
            end
            local ROW_H, ROW_GAP = 28, 6
            local scrollH = 8 * ROW_H + 7 * ROW_GAP
            local scrollWrap = Create("Frame", {Parent = listArea, Size = UDim2.new(1, 0, 0, scrollH), BackgroundTransparency = 1})
            local petScroll = Create("ScrollingFrame", {
                Parent = scrollWrap, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
                ScrollBarThickness = 3, ScrollBarImageColor3 = Colors.Border, CanvasSize = UDim2.new(0, 0, 0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
            })
            CreateListLayout(petScroll, ROW_GAP)
            for i, pet in ipairs(playerPets) do
                local rarity = PET_RARITY_LOOKUP[pet.name] or "Unknown"
                local rarityCol = RarityColor[rarity] or Colors.TextSecondary
                local valStr = rarity
                if pet.size ~= "Normal" then valStr = rarity .. " (" .. pet.size .. ")" end
                local displayName = (pet.petType == "Rainbow" and "\240\159\140\136 " or "") .. pet.name
                CreateStatRow(petScroll, i .. ". " .. displayName, valStr, rarityCol)
            end
        end
        RebuildInventory()
        player.Backpack.ChildAdded:Connect(function(child)
            if child:GetAttribute("Pet") or child:GetAttribute("PetSpecies") then task.defer(RebuildInventory) end
        end)
        player.Backpack.ChildRemoved:Connect(function(child)
            if child:GetAttribute("Pet") or child:GetAttribute("PetSpecies") then task.defer(RebuildInventory) end
        end)

        local finderCard, finderContent = CreateSectionCard("\240\159\148\141 Pet Finder", 2, Colors.Warning)
        local listContainer = Create("Frame", {Parent = finderContent, Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y})
        CreateListLayout(listContainer, 4)

        local RebuildPetList
        RebuildPetList = function()
            if not listContainer or not listContainer.Parent then return end
            for _, c in ipairs(listContainer:GetChildren()) do
                if not c:IsA("UIListLayout") then c:Destroy() end
            end
            local pets = ScanWildPets("All")
            if #pets == 0 then
                CreateInfoText(listContainer, nil, "No unclaimed wild pets found nearby.", Colors.TextMuted)
                return
            end
            CreateSubHeader(listContainer, #pets .. " pet(s) available")
            for i, entry in ipairs(pets) do
                if i > 15 then
                    CreateInfoText(listContainer, nil, "... and " .. (#pets - 15) .. " more.", Colors.TextMuted)
                    break
                end
                local part, rarity, dist = entry.part, entry.rarity, entry.dist
                local col = RarityColor[rarity] or Colors.TextSecondary
                local distStr = dist < math.huge and string.format("%.0f studs", dist) or "?"
                local petName = HumanizePetName(entry.name or "Unknown")
                local row = Create("Frame", {Parent = listContainer, Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Colors.BackgroundLighter, BorderSizePixel = 0})
                CreateCorner(row, 8)
                CreateStroke(row, col, 1)
                local bullet = Create("Frame", {Parent = row, Size = UDim2.new(0, 7, 0, 7), Position = UDim2.new(0, 12, 0.5, -3), BackgroundColor3 = col, BorderSizePixel = 0})
                CreateCorner(bullet, 4)
                Create("TextLabel", {Parent = row, Size = UDim2.new(0, 130, 1, 0), Position = UDim2.new(0, 26, 0, 0), BackgroundTransparency = 1, Text = petName, TextColor3 = col, TextSize = 13, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd})
                Create("TextLabel", {Parent = row, Size = UDim2.new(0, 90, 1, 0), Position = UDim2.new(0, 164, 0, 0), BackgroundTransparency = 1, Text = rarity, TextColor3 = col, TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left})
                Create("TextLabel", {Parent = row, Size = UDim2.new(0, 80, 1, 0), Position = UDim2.new(0, 262, 0, 0), BackgroundTransparency = 1, Text = distStr, TextColor3 = Colors.TextMuted, TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left})
                local tpBtn = Create("TextButton", {Parent = row, Size = UDim2.new(0, 64, 0, 26), Position = UDim2.new(1, -72, 0.5, -13), BackgroundColor3 = Colors.Surface, Text = "TP \226\134\146", TextColor3 = col, TextSize = 12, Font = Enum.Font.GothamBold, BorderSizePixel = 0, AutoButtonColor = false})
                CreateCorner(tpBtn, 6)
                tpBtn.MouseEnter:Connect(function() Tween(tpBtn, {BackgroundColor3 = Colors.SurfaceLight}, 0.1) end)
                tpBtn.MouseLeave:Connect(function() Tween(tpBtn, {BackgroundColor3 = Colors.Surface}, 0.1) end)
                tpBtn.MouseButton1Click:Connect(function()
                    if not part or not part.Parent then
                        Notify("Pet Finder", "That pet has already disappeared!", Colors.Error)
                        RebuildPetList()
                        return
                    end
                    if not player.Character then return end
                    Notify("Pet Finder", "Moving \226\134\146 " .. petName .. " (" .. rarity .. ")", col, 3)
                    task.spawn(function()
                        SmartMoveToPet(part.Position, function()
                            if part and part.Parent and IsWildPetFree(part) then
                                if Logic.WaitForWildPetApproach then
                                    Logic.WaitForWildPetApproach(part, 1.2, 10)
                                end
                                BuyWildPet(part)
                            end
                        end)
                    end)
                end)
            end
        end
        local finderPageAlive = true
        task.spawn(function()
            while finderPageAlive and _G._MiracleHubSession == SESSION do
                task.wait(2)
                if finderPageAlive and GetActivePage() == "Pets" then
                    pcall(RebuildPetList)
                end
            end
        end)
        local _finderConn
        _finderConn = RunService.Heartbeat:Connect(function()
            if GetActivePage() ~= "Pets" then
                finderPageAlive = false
                _finderConn:Disconnect()
            end
        end)
        CreateActionButton(finderContent, "\226\154\161 TP to Nearest Pet", function()
            local pets = ScanWildPets("All")
            if #pets == 0 then Notify("Pet Finder", "No pets available right now.", Colors.Error) return end
            local nearest = pets[1]
            local pName = HumanizePetName(nearest.name or "Unknown")
            Notify("Pet Finder", "Moving -> " .. pName .. " (" .. nearest.rarity .. ")", RarityColor[nearest.rarity] or Colors.Warning, 4)
            task.spawn(function()
                SmartMoveToPet(nearest.part.Position, function()
                    if nearest.part and nearest.part.Parent and IsWildPetFree(nearest.part) then
                        if Logic.WaitForWildPetApproach then
                            Logic.WaitForWildPetApproach(nearest.part, 1.2, 10)
                        end
                        BuyWildPet(nearest.part)
                    end
                end)
            end)
        end, Colors.Warning)
        task.defer(RebuildPetList)

        local wildCard, wildContent = CreateSectionCard("\240\159\142\175 Auto Catch Wild", 3, Colors.Warning)
        local WILD_PET_NAMES = {"Frog", "Bunny", "Owl", "Deer", "Turtle", "Robin", "Bee", "Monkey", "Bear", "Unicorn", "Golden Dragonfly", "Raccoon", "Black Dragon", "Ice Serpent"}
        CreateMultiSelect(wildContent, "\240\159\144\190Choose Target Pets", WILD_PET_NAMES, "wildCatchTargets")
        CreateToggle(wildContent, "Auto Catch Wild Pets", "autoCatchWild",
            "ON: keeps running, chasing any matching pet that spawns | OFF: stops the loop",
            function(newVal)
                if newVal then
                    local sel = States.wildCatchTargets or {}
                    if #sel == 0 then Notify("Auto Catch", "ON \226\128\148 chasing all wild pets", Colors.Success, 3)
                    else Notify("Auto Catch", "ON \226\128\148 targeting: " .. table.concat(sel, ", "), Colors.Success, 3) end
                else
                    Notify("Auto Catch", "OFF", Colors.TextMuted, 2)
                end
            end)
    end)

    -- ====================== EGGS PAGE ======================
    ctx.registerPage("Eggs", function()
        local eggCard, eggContent = CreateSectionCard("\240\159\165\154 Egg Hatching", 1, Colors.Warning)
        CreateInfoText(eggContent, "\240\159\154\167 Coming Soon",
            "Egg Hatching is currently under development.\nNot many players have eggs yet, so this feature isn't active.\nStay tuned for the next update!")
    end)

    -- ====================== PLAYER PAGE ======================
    ctx.registerPage("Player", function()
        local statsCard, statsContent = CreateSectionCard("\240\159\147\138 Live Player Stats", 1, Colors.Accent)
        local _, hpLbl = CreateStatRow(statsContent, "Health", "100 / 100", Colors.Success)
        local _, wsLbl = CreateStatRow(statsContent, "WalkSpeed", tostring(ctx.humanoid and ctx.humanoid.WalkSpeed or "?"), Colors.Accent)
        local _, jpLbl = CreateStatRow(statsContent, "JumpPower", tostring(ctx.humanoid and ctx.humanoid.JumpPower or "?"), Colors.Accent)
        CreateStatRow(statsContent, "Plot ID", MY_PLOT_ID, Colors.Warning)
        local _, bpLbl = CreateStatRow(statsContent, "Backpack Items", #player.Backpack:GetChildren(), Colors.TextSecondary)
        task.spawn(function()
            local _playerTick = 0
            while GetActivePage() == "Player" do
                local dt = task.wait()
                if not ctx.humanoid then continue end
                hpLbl.Text = math.floor(ctx.humanoid.Health) .. " / " .. ctx.humanoid.MaxHealth
                wsLbl.Text = string.format("%.1f", ctx.humanoid.WalkSpeed)
                jpLbl.Text = string.format("%.1f", ctx.humanoid.JumpPower)
                _playerTick = _playerTick + dt
                if _playerTick >= 0.5 then
                    _playerTick = 0
                    bpLbl.Text = tostring(#player.Backpack:GetChildren())
                end
            end
        end)

        local moveCard, moveContent = CreateSectionCard("\240\159\143\131 Movement", 2, Colors.Electric)
        CreateToggle(moveContent, "Lock WalkSpeed", "lockWalkSpeed")
        CreateSlider(moveContent, "WalkSpeed", 1, 500, "walkSpeed")
        CreateToggle(moveContent, "Lock JumpPower", "lockJumpPower")
        CreateSlider(moveContent, "JumpPower", 1, 500, "jumpPower")
        CreateToggle(moveContent, "Infinite Jump", "infiniteJump")

        -- ── Fly Card ──────────────────────────────────────────────────────
        local utilCard, utilContent = CreateSectionCard("\226\156\136\239\184\143 Fly", 3, Colors.TextSecondary)
        CreateInfoText(utilContent, "Controls", "[F] Toggle Fly | [W/A/S/D] Move | [Space] Up | [Ctrl] Down")

        -- onToggle callback: delegasi Notify ke ctx.ToggleFly agar satu jalur dengan keybind F.
        -- CreateToggle sudah flip States.fly SEBELUM onToggle dipanggil, jadi kita
        -- kirim forceState=state (tidak flip ulang) supaya tidak double-toggle.
        -- Tangkap setVisual (return ke-3) untuk diexpose ke ctx — dipakai oleh keybind F
        -- supaya visual toggle sinkron saat user tekan F tanpa klik widget.
        local _, getFlyState, setFlyVisual = CreateToggle(utilContent, "Fly", "fly", "Hold WASD to fly, Space=up, Ctrl=down", function(state)
            if ctx.ToggleFly then
                ctx.ToggleFly(state)   -- forceState = state, tidak flip ulang
            else
                Notify("Player", "Fly " .. (state and "ON" or "OFF"), state and Colors.Success or Colors.TextMuted)
            end
        end)

        -- Simpan setVisual terbaru ke ctx setiap kali halaman Player dirender.
        -- Keybind F di bootstrap akan memanggil ctx._setFlyVisual(newState) setelah
        -- mengubah States.fly agar knob & warna toggle ikut berubah.
        ctx._setFlyVisual = setFlyVisual

        CreateSlider(utilContent, "Fly Speed", 1, 300, "flySpeed")
    end)

    -- ====================== VISUALS PAGE ======================
    ctx.registerPage("Visuals", function()
        local espCard, espContent = CreateSectionCard("\240\159\145\129 ESP & Highlights", 1, Colors.Electric)
        CreateToggle(espContent, "ESP Players", "espPlayers", "Shows player names/tags above heads")
        CreateToggle(espContent, "ESP Wild Pets", "espItems", "Highlights wild pets in workspace")
        CreateToggle(espContent, "ESP Fruits", "espFruits", "Highlights harvestable fruits on the plot")
        CreateToggle(espContent, "ESP Mutations", "espMutations", "Shows mutation tags on plants")
        CreateToggle(espContent, "Show Plant Age", "showPlantAge", "Shows Age/MaxAge above each plant")
        CreateToggle(espContent, "Show Fruit Weight", "showFruitWeight", "Shows fruit weight above harvestables")
        CreateActionButton(espContent, "Clear All ESP Labels", function()
            Logic.ClearESP()
            Notify("Visuals", "All ESP labels cleared.", Colors.TextMuted)
        end)

        -- ===== VISUAL SETTINGS =====
        local visCard, visContent = CreateSectionCard("\240\159\140\136 Visual Settings", 2, Colors.Accent)
        CreateToggle(visContent, "Full Bright", "fullBright", "Sets ambient to maximum brightness")
        CreateSlider(visContent, "Brightness", 0, 10, "brightness")
        CreateToggle(visContent, "No Fog", "noFog", "Removes environmental fog")
        CreateToggle(visContent, "No Shadows", "noShadows", "Disables global shadows")
        CreateActionButton(visContent, "Reset Visuals to Default", function()
            local lighting = game:GetService("Lighting")
            lighting.Brightness = 1
            lighting.Ambient = Color3.fromRGB(70, 70, 70)
            lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 140)
            lighting.FogEnd = 100000
            lighting.GlobalShadows = true
            States.fullBright = false
            States.noFog = false
            States.noShadows = false
            Notify("Visuals", "Reset to default lighting.", Colors.TextMuted)
        end)
        CreateActionButton(visContent, "\226\154\161 Ultra Low Graphics (Permanent until rejoin)", function()
            if ctx.UltraLow and ctx.UltraLow.Active then
                Notify("Ultra Low", "Already active. Rejoin to reset.", Colors.Warning)
                return
            end
            if not ctx.UltraLow then
                Notify("Ultra Low", "Ultra Low module not found.", Colors.Error)
                return
            end
            Notify("Ultra Low", "Applying... Don't close the hub.", Colors.Warning, 3)
            task.spawn(function()
                ctx.UltraLow.Apply()
            end)
        end, Colors.Warning)
    end)

    -- ====================== TELEPORT PAGE ======================
    ctx.registerPage("Teleport", function()
        local tpCard, tpContent = CreateSectionCard("\240\159\147\141 Quick Teleport", 1, Colors.Accent)
        local gameTeleports = {
            {"\240\159\140\177 Seeds Shop", "Seeds", Colors.Success},
            {"\240\159\146\176 Sell Area", "Sell", Colors.Gold},
            {"\226\154\153 Gear Shop", "Gears", Colors.Electric},
            {"\240\159\143\161 Props Shop", "Props", Colors.Accent},
        }
        CreateSubHeader(tpContent, "Game Locations")
        for _, tp in ipairs(gameTeleports) do
            CreateActionButton(tpContent, "Teleport to " .. tp[1], function()
                local teleports = game:GetService("Workspace"):FindFirstChild("Teleports")
                if teleports then
                    local part = teleports:FindFirstChild(tp[2])
                    if part and player.Character then
                        player.Character:PivotTo(part.CFrame + Vector3.new(0, 5, 0))
                        Notify("Teleport", "\226\134\146 " .. tp[1], tp[3])
                    else
                        Notify("Teleport", tp[1] .. " location not found!", Colors.Error)
                    end
                end
            end, tp[3])
        end
        CreateSubHeader(tpContent, "Player Locations")
        CreateActionButton(tpContent, "Teleport to My Plot (Plot " .. MY_PLOT_ID .. ")", function()
            local plot = GetMyPlot()
            if plot then
                local sp = plot:FindFirstChild("SpawnPoint")
                if sp and player.Character then
                    player.Character:PivotTo(sp.CFrame + Vector3.new(0, 5, 0))
                    Notify("Teleport", "Teleported to Plot " .. MY_PLOT_ID, Colors.Success)
                    return
                end
            end
            Notify("Teleport", "Plot SpawnPoint not found.", Colors.Error)
        end, Colors.Success)
        CreateSubHeader(tpContent, "Teleport to Player")
        local playerList = {}
        for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
            if p ~= player then table.insert(playerList, p.Name) end
        end
        if #playerList > 0 then
            CreateDropdown(tpContent, "Target Player", playerList, "tpTargetPlayer")
            CreateActionButton(tpContent, "Teleport to Selected Player", function()
                local targetName = States.tpTargetPlayer
                if not targetName then Notify("Teleport", "Select a player first.", Colors.Error) return end
                local target = game:GetService("Players"):FindFirstChild(targetName)
                if target and target.Character and player.Character then
                    player.Character:PivotTo(target.Character:GetPivot() * CFrame.new(3, 0, 3))
                    Notify("Teleport", "Teleported to " .. targetName, Colors.Electric)
                else
                    Notify("Teleport", target and "Target has no character." or "Player not found.", Colors.Error)
                end
            end, Colors.Electric)
        end
    end)

    -- ====================== UTILITY PAGE ======================
    ctx.registerPage("Utility", function()
        local worthCard, worthContent = CreateSectionCard("\240\159\146\142 Item Inspector", 1, Colors.Gold)
        local toolNameLbl
        do
            local currentTool = player.Character and player.Character:FindFirstChildWhichIsA("Tool")
            local _, v = CreateStatRow(worthContent, "Currently Holding", currentTool and currentTool.Name or "Nothing", Colors.TextPrimary)
            toolNameLbl = v
        end
        task.spawn(function()
            while GetActivePage() == "Utility" do
                task.wait(0.25)
                if GetActivePage() ~= "Utility" then break end
                if toolNameLbl and toolNameLbl.Parent then
                    local ct = player.Character and player.Character:FindFirstChildWhichIsA("Tool")
                    toolNameLbl.Text = ct and ct.Name or "Nothing"
                end
            end
        end)
        CreateActionButton(worthContent, "Inspect Held Item", function()
            local ct = player.Character and player.Character:FindFirstChildWhichIsA("Tool")
            if ct then
                local weight = ct:GetAttribute("Weight")
                local mut = GetMutation(ct)
                local sm = ct:GetAttribute("SizeMultiplier")
                local decay = ct:GetAttribute("DecayAlpha")
                local fn = ct:GetAttribute("FruitName") or ct:GetAttribute("Fruit") or ct.Name
                if weight then
                    Notify("Inspect: " .. fn, string.format("Wt:%.2fkg | Mut:%s | x%.2f size | Decay:%.4f", weight, mut, sm or 1, decay or 0), GetMutationColor(mut), 6)
                else
                    local seedName = ct:GetAttribute("SeedTool") or ct:GetAttribute("SeedName")
                    if seedName then Notify("Inspect: Seed", "Type: " .. seedName, Colors.Success)
                    else Notify("Inspect", ct.Name .. " \226\128\148 not a fruit or seed.", Colors.TextMuted) end
                end
            else
                Notify("Inspect", "Not holding anything.", Colors.TextMuted)
            end
        end, Colors.Gold)
        CreateActionButton(worthContent, "Count Bag Contents", function()
            local f, s, p2, g = 0, 0, 0, 0
            for _, t in ipairs(player.Backpack:GetChildren()) do
                if t:GetAttribute("HarvestedFruit") then f = f + 1
                elseif t:GetAttribute("SeedTool") or t:GetAttribute("SeedName") then s = s + 1
                elseif t:GetAttribute("Pet") then p2 = p2 + 1
                else g = g + 1 end
            end
            Notify("Bag Contents", "Fruits:" .. f .. " | Seeds:" .. s .. " | Pets:" .. p2 .. " | Other:" .. g, Colors.Accent)
        end)


        local giftCard, giftContent = CreateSectionCard("\240\159\142\129 Gifts & Mailbox", 2, Colors.Rainbow)
        CreateToggle(giftContent, "Auto Accept Gifts", "autoAcceptGifts", "Automatically checks your mailbox every 10 seconds")
        CreateActionButton(giftContent, "Check Mailbox Now", function()
            local plot = GetMyPlot()
            if not plot then Notify("Mailbox", "Your plot was not found!", Colors.Error) return end
            local signs = plot:FindFirstChild("Signs")
            if not signs then Notify("Mailbox", "Mailbox not found on your plot.", Colors.Error) return end
            local mailbox = signs:FindFirstChild("GreyMailBox")
            if not mailbox then Notify("Mailbox", "Mailbox not found on your plot.", Colors.Error) return end
            local found = false
            for _, desc in ipairs(mailbox:GetDescendants()) do
                if desc:IsA("ProximityPrompt") and desc.Name == "MailboxPrompt" then
                    SafeFirePrompt(desc)
                    found = true
                    break
                end
            end
            Notify("Mailbox", found and "Mailbox checked on Plot " .. MY_PLOT_ID or "Mailbox could not be opened.", found and Colors.Rainbow or Colors.Error)
        end, Colors.Rainbow)
    end)

    -- ====================== MAILER PAGE ======================
    ctx.registerPage("Mailer", function()
        local mailerCard, mailerContent = CreateSectionCard("\226\156\137 Mailer System", 1, Colors.Accent)
        CreateSubHeader(mailerContent, "Outbox")
        CreateActionButton(mailerContent, "Open My Mailbox", function()
            local plot = GetMyPlot()
            if plot then
                for _, desc in ipairs(plot:GetDescendants()) do
                    if desc:IsA("ProximityPrompt") and desc.Name == "MailboxPrompt" then
                        SafeFirePrompt(desc)
                        Notify("Mailer", "Opened mailbox!", Colors.Accent)
                        return
                    end
                end
            end
            Notify("Mailer", "Mailbox prompt not found.", Colors.Error)
        end, Colors.Accent)
        CreateSubHeader(mailerContent, "Trading")
        CreateActionButton(mailerContent, "Show Bid Info (Held Item)", function()
            local ct = player.Character and player.Character:FindFirstChildWhichIsA("Tool")
            if ct then
                local bidPrice = ct:GetAttribute("BidPrice")
                local bidsAsked = ct:GetAttribute("BidsAsked")
                if bidPrice or bidsAsked then
                    Notify("Bid Info", "BidPrice: " .. tostring(bidPrice) .. " | BidsAsked: " .. tostring(bidsAsked), Colors.Gold, 6)
                else
                    Notify("Bid", "No bid attrs on: " .. ct.Name, Colors.TextMuted)
                end
            else
                Notify("Bid", "Not holding anything.", Colors.TextMuted)
            end
        end)
    end)

    -- ====================== INFO PAGE ======================
    ctx.registerPage("Info", function()
        local infoCard, infoContent = CreateSectionCard("\226\132\185 About Miracle Hub", 1, Colors.Success)
        CreateStatRow(infoContent, "Hub Name", "Miracle Hub", Colors.Success)
        CreateStatRow(infoContent, "Game", "Grow A Garden 2", Colors.TextSecondary)
        CreateStatRow(infoContent, "Player", player.DisplayName or player.Name, Colors.Accent)
        CreateStatRow(infoContent, "UserId", player.UserId, Colors.TextMuted)
        CreateStatRow(infoContent, "Plot ID", MY_PLOT_ID, Colors.Warning)
        CreateStatRow(infoContent, "Prime Status", (player:GetAttribute("PrimeEnabled") and "Enabled" or "Disabled"), Colors.Warning)
        CreateStatRow(infoContent, "Connection Status", ctx.PacketRemote and "Connected" or "\226\154\160 Not Connected", ctx.PacketRemote and Colors.Success or Colors.Error)

    end)

    -- ====================== SERVER PAGE ======================
    ctx.registerPage("Server", function()
        local serverCard, serverContent = CreateSectionCard("\240\159\140\144 Server Info", 1, Colors.Electric)
        CreateStatRow(serverContent, "Job ID", game.JobId:sub(1, 20) .. "...", Colors.TextMuted)
        CreateStatRow(serverContent, "Place ID", tostring(game.PlaceId), Colors.TextMuted)
        local _, pcLbl = CreateStatRow(serverContent, "Players in Server", #game:GetService("Players"):GetPlayers(), Colors.Success)
        local playerPlotLabels = {}
        CreateSubHeader(serverContent, "Other Players")
        for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
            if p ~= player then
                local _, pPlotLbl = CreateStatRow(serverContent, p.DisplayName .. " (@" .. p.Name .. ")", "Plot " .. (p:GetAttribute("PlotId") or "?"), Colors.TextMuted)
                table.insert(playerPlotLabels, {p = p, lbl = pPlotLbl})
            end
        end
        task.spawn(function()
            while GetActivePage() == "Server" do
                task.wait(1)
                if GetActivePage() ~= "Server" then break end
                pcLbl.Text = tostring(#game:GetService("Players"):GetPlayers())
                for _, entry in ipairs(playerPlotLabels) do
                    if entry.lbl and entry.lbl.Parent then
                        entry.lbl.Text = "Plot " .. tostring(entry.p:GetAttribute("PlotId") or "?")
                    end
                end
            end
        end)
        CreateActionButton(serverContent, "Rejoin Server", function()
            Notify("Server", "Rejoining in 2s...", Colors.Warning)
            task.wait(2)
            game:GetService("TeleportService"):Teleport(game.PlaceId, player)
        end, Colors.Warning)
        CreateActionButton(serverContent, "Copy Job ID", function()
            setclipboard(game.JobId)
            Notify("Server", "Job ID copied.", Colors.Accent)
        end)

        local autoCard, autoContent = CreateSectionCard("\240\159\148\132 Auto Rejoin", 2, Colors.Warning)
        CreateToggle(autoContent, "Auto Rejoin on Disconnect", "autoRejoin", "Rejoins automatically when kicked/disconnected")
        CreateDropdown(autoContent, "Rejoin Condition", {"Server Full", "FPS Drop", "Disconnected", "Manual"}, "rejoinCondition")
        game:GetService("Players").PlayerRemoving:Connect(function(p)
            if p == player and States.autoRejoin then
                task.wait(2)
                game:GetService("TeleportService"):Teleport(game.PlaceId, player)
            end
        end)

    end)

    -- ====================== SETTINGS PAGE ======================
    ctx.registerPage("Settings", function()
        local settCard, settContent = CreateSectionCard("\226\154\153 General Settings", 1, Colors.Accent)
        CreateToggle(settContent, "Auto Save Config", "autoSaveConfig", "Saves your config automatically")
        CreateToggle(settContent, "Anti AFK", "antiAfk", "Prevents auto-disconnect")
        CreateToggle(settContent, "Minimize to Tray on Close", "minimizeToTray", "Minimizes to M shield instead of closing")
        CreateToggle(settContent, "Show Notifications", "showNotifications", "Shows popup notifications")
        CreateSubHeader(settContent, "Config")
        CreateActionButton(settContent, "Export Config to Clipboard", function()
            local cfg = {}
            for k, v in pairs(States) do table.insert(cfg, k .. "=" .. tostring(v)) end
            table.sort(cfg)
            setclipboard(table.concat(cfg, "\n"))
            Notify("Settings", "Full config exported to clipboard.", Colors.Success)
        end)
        CreateActionButton(settContent, "Reset All States", function()
            States.autoPlant = false
            States.autoHarvest = false
            States.autoSell = false
            States.autoBuySeed = false
            States.autoBuyCrate = false
            States.autoOpenCrate = false
            States.autoCatchWild = false
            States.autoOpenEgg = false
            States.autoAcceptGifts = false
            States.fly = false
            States.espPlayers = false
            States.espItems = false
            States.espFruits = false
            States.espMutations = false
            States.fullBright = false
            States.noFog = false
            States.noShadows = false
            States.showFruitWeight = false
            States.showPlantAge = false
            Logic.ClearESP()
            Logic.ClearSfxMuteConn()
            pcall(function()
                local ss = game:GetService("SoundService")
                local sfx = ss:FindFirstChild("SFX")
                local failedSnd = sfx and sfx:FindFirstChild("Failed")
                if failedSnd then failedSnd.Volume = 1 end
            end)
            Notify("Settings", "All automation states reset to OFF.", Colors.Warning)
        end, Colors.Error)

    end)

    ctx.__pagesLoaded = true
    return ctx
end