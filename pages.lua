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
    local GetSprinklerPlacePositions = Logic.GetSprinklerPlacePositions
    local GetSprinklerRadius         = Logic.GetSprinklerRadius
    local GetPlantPositions          = Logic.GetPlantPositions
    local DoPlaceSprinklerAt         = Logic.DoPlaceSprinklerAt
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

        CreateInfoText(plantContent, "Cara Kerja",
            "Menanam seed secara otomatis ke plot kamu (Plot " .. MY_PLOT_ID .. "). "
            .. "Posisi tanam dideteksi langsung dari area tanam di plotmu. "
            .. "Selama Auto Plant aktif, loop akan terus berjalan \226\128\148 menanam ulang setelah plot penuh dan di-harvest."
        )

        CreateToggle(plantContent, "Auto Plant", "autoPlant",
            "Aktifkan untuk menanam otomatis terus-menerus. Delay antar tanam: 0.3 detik.",
            function(newVal, revert)
                if newVal and not States.autoPlantAllSeeds then
                    local targets = States.autoPlantTargets or {}
                    if #targets == 0 then
                        revert()
                        Notify("Auto Plant", "\226\154\160\239\184\143 Pilih seed dulu di 'Pilih Seed yang Ditanam' sebelum aktifkan Auto Plant!", Colors.Warning, 5)
                        return
                    end
                end
            end)

        CreateToggle(plantContent, "Tanam Semua Seed di Backpack", "autoPlantAllSeeds",
            "ON: tanam semua seed yang ada di backpack | OFF: hanya seed yang dipilih di bawah")

        CreateMultiSelect(plantContent, "\240\159\140\177Pilih Seed yang Ditanam", SEEDS, "autoPlantTargets")

        CreateToggle(plantContent, "Notif Hasil Tanam", "autoPlantNotify",
            "Tampilkan notifikasi setiap kali satu siklus tanam selesai")

        CreateActionButton(plantContent, "\226\154\161 Tanam Sekarang (Manual)", function()
            local plantAreas = GetMyPlantAreas()
            if #plantAreas == 0 then
                Notify("Farm", "\226\157\140 PlantArea tidak ditemukan di Plot " .. MY_PLOT_ID
                    .. ". Pastikan kamu berada di plotmu.", Colors.Error)
                return
            end
            local firstSeed = GetNextSeedFromBackpack()
            if not firstSeed then
                Notify("Farm", "\226\154\160 Tidak ada seed di backpack (sesuai filter).", Colors.Warning)
                return
            end
            Notify("Farm", "Mulai menanam di Plot " .. MY_PLOT_ID .. "...", Colors.Success)
            task.spawn(function()
                local validPos = BuildValidPlantPositions(plantAreas, 500)
                if #validPos == 0 then
                    Notify("Farm", "Plot " .. MY_PLOT_ID .. " sudah penuh / tidak ada slot kosong.", Colors.Warning)
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
                    NotifyStok(lines, Colors.Success, 8, "\240\159\140\177 Tanam Sekarang (+" .. planted .. " ditanam)")
                else
                    Notify("Farm", "Tidak ada yang ditanam.", Colors.Warning, 3)
                end
            end)
        end, Colors.Success)

        CreateActionButton(plantContent, "\240\159\148\141 Scan Seed di Backpack", function()
            local backpack = player:FindFirstChildOfClass("Backpack")
            if not backpack then
                Notify("Farm", "Backpack tidak ditemukan.", Colors.Error)
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
                Notify("Farm", "Tidak ada seed di backpack.", Colors.TextMuted)
                return
            end
            local lines = {}
            for name, cnt in pairs(counts) do
                table.insert(lines, name .. " x" .. cnt)
            end
            table.sort(lines)
            Notify("Seed di Backpack (" .. total .. ")",
                table.concat(lines, " | "):sub(1, 200), Colors.Success, 7)
        end)

        CreateActionButton(plantContent, "\240\159\147\138 Cek Slot Terisi", function()
            local seedCounts, totalPlanted = GetPlantedSeedCounts()
            local plantsFolder = GetPlantsFolder()
            local totalAll = plantsFolder and #plantsFolder:GetChildren() or 0
            if totalPlanted == 0 then
                Notify("Slot Terisi", "Tidak ada tanaman milikmu di Plot " .. MY_PLOT_ID, Colors.TextMuted, 4)
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
            NotifyStok(lines, Colors.Accent, 15, "\240\159\147\138 Milikku: " .. totalPlanted .. " | Plot: " .. totalAll)
        end)

        local harvestCard, harvestContent = CreateSectionCard("\240\159\141\133 Auto Harvest", 2, Colors.Warning)
        CreateInfoText(harvestContent, "Cara Kerja",
            "Memanen semua buah yang sudah siap di Plot " .. MY_PLOT_ID .. " secara otomatis. "
            .. "Hanya buah yang prompt-nya aktif (sudah matang) yang akan dipanen."
        )
        CreateToggle(harvestContent, "Auto Harvest", "autoHarvest", "Aktifkan panen otomatis di plotmu")
        CreateToggle(harvestContent, "Notif Setelah Panen", "notifyHarvest", "Tampilkan notifikasi setelah setiap siklus panen selesai")
        CreateSubHeader(harvestContent, "Delay Settings")
        CreateSlider(harvestContent, "Per-Fruit Delay (s)", 0, 2, "perFruitDelay")
        CreateSlider(harvestContent, "Loop Delay (s)", 0, 30, "harvestLoopDelay")
        CreateSubHeader(harvestContent, "Mutation Filter")
        CreateMultiSelect(harvestContent, "⏭️Skip Mutation", MUTATIONS, "harvestFilterMutation")
        CreateActionButton(harvestContent, "\226\154\161 Harvest All Now", function()
            local myPlot = GetMyPlot()
            if not myPlot then
                Notify("Harvest", "\226\157\140 Plot " .. MY_PLOT_ID .. " tidak ditemukan!", Colors.Error)
                return
            end
            local currentCount = player:GetAttribute("FruitCount") or 0
            local remaining = MAX_FRUIT_CAP - currentCount
            if remaining <= 0 then
                Notify("Harvest", "\240\159\142\146 Backpack penuh! (" .. currentCount .. "/" .. MAX_FRUIT_CAP .. ")", Colors.Warning)
                return
            end
            local ready = GetReadyFruitCount()
            if ready == 0 then
                Notify("Harvest", "Tidak ada buah siap panen saat ini.", Colors.TextMuted)
                return
            end
            local willHarvest = math.min(ready, remaining)
            Notify("Harvest", "Memanen " .. willHarvest .. " buah (bag " .. currentCount .. "/" .. MAX_FRUIT_CAP .. ")...", Colors.Warning)
            task.spawn(function()
                local harvested = DoHarvestAll(States.harvestFilterMutation, MAX_FRUIT_CAP)
                local after = player:GetAttribute("FruitCount") or 0
                Notify("Harvest \226\156\133", "Panen " .. harvested .. " buah | Bag " .. after .. "/" .. MAX_FRUIT_CAP, Colors.Success)
            end)
        end, Colors.Warning)
        CreateActionButton(harvestContent, "\240\159\148\141 Scan Fruits Ready", function()
            local myPlot = GetMyPlot()
            if not myPlot then Notify("Scan", "\226\157\140 Plot tidak ditemukan!", Colors.Error) return end
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
            local msg = #readyList .. "/" .. total .. " siap | Bag " .. currentCount .. "/" .. MAX_FRUIT_CAP
                .. "\n" .. table.concat(readyList, ", "):sub(1, 80)
            Notify("Fruit Scanner \240\159\148\141", msg, Colors.Success, 7)
        end)

        local waterCard, waterContent = CreateSectionCard("\240\159\146\167 Watering & Sprinklers", 3, Colors.Electric)
        CreateInfoText(waterContent, "Cara Kerja",
            "Pilih Watering Can dan Sprinkler yang ingin dipakai dari daftar di bawah. "
            .. "Toggle akan otomatis aktif saat kamu memilih item. "
            .. "Jika tidak memilih, semua watering can / sprinkler di backpack akan dipakai."
        )

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
            "Siram otomatis semua tanaman via Networking.WateringCan.UseWateringCan",
            function(newVal, revert)
                if newVal then
                    local targets = States.wateringCanTargets or {}
                    if #targets == 0 then
                        revert()
                        Notify("Auto Water", "\226\154\160\239\184\143 Pilih Watering Can dulu di 'Pilih Watering Can' sebelum aktifkan!", Colors.Warning, 5)
                        return
                    end
                end
            end)
        CreateMultiSelect(waterContent, "\240\159\170\163 Pilih Watering Can", WATERING_CANS, "wateringCanTargets")
        CreateToggle(waterContent, "Notif Setelah Siram", "notifyHarvest",
            "Tampilkan notifikasi jumlah tanaman yang disiram tiap siklus")
        CreateSlider(waterContent, "Per-Plant Delay (s)", 0, 2, "perFruitDelay")
        CreateSlider(waterContent, "Water Loop Delay (s)", 1, 60, "harvestLoopDelay")

        CreateActionButton(waterContent, "\240\159\146\167 Water All Now", function()
            if not Networking then
                Notify("Auto Water", "\226\157\140 Networking module tidak ditemukan!", Colors.Error)
                return
            end
            local selectedCans = States.wateringCanTargets or {}
            if #selectedCans == 0 then
                Notify("Auto Water", "\226\154\160\239\184\143 Pilih Watering Can dulu sebelum menyiram!", Colors.Warning, 5)
                return
            end
            local tool, canName = AcquireWateringCan()
            if not tool or not canName then
                Notify("Auto Water", "\226\157\140 Watering Can yang dipilih tidak ada di backpack/tangan!", Colors.Error)
                return
            end
            local plants = GetPlantsFolder()
            if not plants then
                Notify("Auto Water", "\226\157\140 Plants folder Plot " .. MY_PLOT_ID .. " tidak ditemukan!", Colors.Error)
                return
            end
            Notify("Auto Water \240\159\146\167", "Menyiram dengan " .. canName .. "...", Colors.Electric)
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
                Notify("Auto Water \226\156\133", "Siram " .. watered .. " tanaman di Plot " .. MY_PLOT_ID, Colors.Success)
            end)
        end, Colors.Electric)

        CreateSubHeader(waterContent, "\240\159\140\191 Auto Sprinkler")
        CreateToggle(waterContent, "Auto Place Sprinklers", "autoSprinkler",
            "Pasang sprinkler otomatis di PlantArea yang belum ada sprinklernya",
            function(newVal, revert)
                if newVal then
                    local targets = States.sprinklerTargets or {}
                    if #targets == 0 then
                        revert()
                        Notify("Auto Sprinkler", "\226\154\160\239\184\143 Pilih Sprinkler dulu sebelum aktifkan!", Colors.Warning, 5)
                        return
                    end
                end
            end)
        CreateMultiSelect(waterContent, "\240\159\140\191 Pilih Sprinkler", SPRINKLER_LIST, "sprinklerTargets")

        CreateActionButton(waterContent, "\240\159\140\191 Place Sprinkler Now", function()
            if not Networking and not ctx.PacketRemote then
                Notify("Sprinkler", "\226\157\140 Networking module dan PacketRemote tidak ditemukan!", Colors.Error)
                return
            end
            local selectedTargets = States.sprinklerTargets or {}
            if #selectedTargets == 0 then
                Notify("Sprinkler", "\226\154\160\239\184\143 Pilih jenis sprinkler dulu di 'Pilih Sprinkler' sebelum menekan ini!", Colors.Warning, 5)
                return
            end
            local tool, sprinklerName = AcquireSprinklerTool()
            if not tool or not sprinklerName then
                Notify("Sprinkler", "\226\157\140 Sprinkler yang dipilih tidak ada di backpack/tangan!", Colors.Error)
                return
            end

            -- Hitung posisi sprinkler optimal berdasarkan tanaman aktual + radius sprinkler
            -- GetSprinklerPlacePositions menerima sprinklerName agar radius-nya tepat per rarity
            local positions = GetSprinklerPlacePositions(50, sprinklerName)

            if #positions == 0 then
                local plants = Logic.GetPlantPositions and Logic.GetPlantPositions() or {}
                if #plants == 0 then
                    Notify("Sprinkler", "Tidak ada tanaman di Plot " .. MY_PLOT_ID .. ". Tanam dulu!", Colors.TextMuted)
                else
                    Notify("Sprinkler", "Semua tanaman sudah ter-cover oleh sprinkler yang ada \240\159\140\191", Colors.Success)
                end
                return
            end

            local radius = Logic.GetSprinklerRadius and Logic.GetSprinklerRadius(sprinklerName) or 8
            Notify("Sprinkler \240\159\140\191",
                "Memasang " .. #positions .. " sprinkler (" .. sprinklerName .. ", radius " .. radius .. " studs)...",
                Colors.Success)

            task.spawn(function()
                local placed = 0
                for _, pos in ipairs(positions) do
                    pcall(function()
                        local success = DoPlaceSprinklerAt(pos, tool, sprinklerName)
                        if success then placed = placed + 1 end
                    end)
                    -- Re-acquire setelah tiap placement (tool di-consume server)
                    local t2, sn2 = AcquireSprinklerTool()
                    if not t2 then
                        Notify("Sprinkler", "\226\157\140 Sprinkler habis di backpack!", Colors.Error)
                        break
                    end
                    tool, sprinklerName = t2, sn2
                    task.wait(0.5)
                end
                if placed > 0 then
                    Notify("Sprinkler \226\156\133",
                        "Pasang " .. placed .. "/" .. #positions .. " sprinkler di Plot " .. MY_PLOT_ID,
                        Colors.Success, 5)
                else
                    Notify("Sprinkler", "Tidak ada sprinkler yang berhasil dipasang. Pastikan kamu di plotmu dan sudah ada tanaman.", Colors.Warning)
                end
            end)
        end, Colors.Success)

        CreateActionButton(waterContent, "\240\159\148\141 Scan Sprinkler di Plot", function()
            local myPlot = GetMyPlot()
            if not myPlot then
                Notify("Scan", "\226\157\140 Plot " .. MY_PLOT_ID .. " tidak ditemukan!", Colors.Error)
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
                Notify("Sprinkler Scan", "Tidak ada sprinkler di Plot " .. MY_PLOT_ID, Colors.TextMuted)
            else
                NotifyStok(sprinklers, Colors.Success, 10, "\240\159\140\191 Sprinkler di Plot (" .. #sprinklers .. ")")
            end
        end, Colors.Accent)
    end)

    -- ====================== PLOT PAGE ======================
    ctx.registerPage("Plot", function()
        local plotCard, plotContent = CreateSectionCard("\240\159\147\144 My Plot \226\128\148 Plot " .. MY_PLOT_ID, 1, Colors.Accent)
        CreateInfoText(plotContent, "Detected from scanner", "PlotId = " .. MY_PLOT_ID .. " | Path: Workspace.Gardens.Plot" .. MY_PLOT_ID)

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

        CreateSubHeader(plotContent, "Plot Actions")
        CreateActionButton(plotContent, "Customise Theme (ProximityPrompt)", function()
            local plot = GetMyPlot()
            if plot then
                local signs = plot:FindFirstChild("Signs")
                if signs then
                    local garden = signs:FindFirstChild("Garden")
                    if garden then
                        local core = garden:FindFirstChild("CorePart")
                        if core then
                            local prompt = core:FindFirstChild("CustomiseTheme")
                            if prompt then SafeFirePrompt(prompt) end
                        end
                    end
                end
            end
            Notify("Plot", "Triggered CustomiseTheme prompt", Colors.Accent)
        end)
        CreateActionButton(plotContent, "Like My Garden", function()
            local plot = GetMyPlot()
            if plot then
                for _, desc in ipairs(plot:GetDescendants()) do
                    if desc:IsA("ProximityPrompt") and desc.Name == "GardenSignLike" then
                        SafeFirePrompt(desc) break
                    end
                end
            end
            Notify("Plot", "Triggered GardenSignLike", Colors.Gold)
        end)
        CreateActionButton(plotContent, "Teleport to Plot SpawnPoint", function()
            local plot = GetMyPlot()
            if plot then
                local sp = plot:FindFirstChild("SpawnPoint")
                if sp and player.Character then
                    player.Character:PivotTo(sp.CFrame + Vector3.new(0, 5, 0))
                    Notify("Teleport", "Teleported to Plot " .. MY_PLOT_ID .. " SpawnPoint", Colors.Success)
                    return
                end
            end
            Notify("Teleport", "SpawnPoint not found.", Colors.Error)
        end, Colors.Success)

        local pottedCard, pottedContent = CreateSectionCard("\240\159\170\180 Potted Plants", 2, Colors.Rainbow)
        CreateInfoText(pottedContent, "Scanner detected", "PickUpPottedPlantPrompt found in workspace.")
        CreateActionButton(pottedContent, "Auto Pickup Potted Plants", function()
            local picked = 0
            for _, desc in ipairs(game:GetService("Workspace"):GetDescendants()) do
                if desc:IsA("ProximityPrompt") and desc.Name == "PickUpPottedPlantPrompt" then
                    SafeFirePrompt(desc)
                    picked = picked + 1
                    task.wait(0.2)
                end
            end
            Notify("Potted", "Picked up " .. picked .. " potted plant(s)", Colors.Rainbow)
        end, Colors.Rainbow)
    end)

    -- ====================== SHOP PAGE ======================
    ctx.registerPage("Shop", function()
        local buyCard, buyContent = CreateSectionCard("\240\159\155\146 Auto Buy Seeds", 1, Colors.Success)
        CreateInfoText(buyContent, "Cara Pakai", "1. Pilih seed di 'Pilih Seed Target'.\n2. Aktifkan 'Auto Buy Seeds'.\n3. Script beli 1 seed per cycle selama stok ada.\nGunakan 'Beli SEMUA yang ada stok' untuk auto-beli semua seed.")

        CreateToggle(buyContent, "Auto Buy Seeds", "autoBuySeed", "Loop cepat beli seed yang dipilih, stop jika stok 0", function(newVal, revert)
            if newVal and not States.autoBuyAll then
                local targets = States.autoBuySeedTargets or {}
                if #targets == 0 then
                    revert()
                    Notify("Auto Buy", "\226\154\160\239\184\143 Pilih seed dulu sebelum aktifkan Auto Buy!", Colors.Warning, 5)
                    return
                end
            end
            if newVal then pcall(MuteSFX_Failed) end
        end)
        CreateToggle(buyContent, "Beli SEMUA yang ada stok", "autoBuyAll", "ON: beli semua seed yg stok > 0 | OFF: hanya seed dipilih")
        CreateMultiSelect(buyContent, "\240\159\140\177Pilih Seed Target", SEEDS, "autoBuySeedTargets")
        CreateSlider(buyContent, "Delay Antar Beli (s)", 0, 2, "buyDelay")
        CreateSlider(buyContent, "Loop Delay (s)", 0, 10, "shopLoopDelay")
        CreateToggle(buyContent, "Notif Saat Beli", "notifyBuy", "Tampilkan notif setiap seed dibeli")

        -- Predict Next Stock
        local predictCard, predictContent = CreateSectionCard("\240\159\148\174 Predict Next Stock", 2, Colors.Rainbow)
        CreateInfoText(predictContent, "Cara Kerja",
            "Menggunakan RestockChance dari SeedData untuk hitung rata-rata berapa restock lagi sampai seed muncul.")

        local SEED_RESTOCK_DATA = {
            ["Carrot"]={chance=100,restockMin=3,restockMax=4},["Strawberry"]={chance=100,restockMin=4,restockMax=5},
            ["Blueberry"]={chance=100,restockMin=1,restockMax=2},["Tulip"]={chance=100,restockMin=3,restockMax=4},
            ["Tomato"]={chance=90,restockMin=2,restockMax=3},["Apple"]={chance=52.63,restockMin=1,restockMax=1},
            ["Bamboo"]={chance=80,restockMin=7,restockMax=11},["Corn"]={chance=35,restockMin=1,restockMax=1},
            ["Cactus"]={chance=16.668,restockMin=1,restockMax=2},["Pineapple"]={chance=12.501,restockMin=1,restockMax=3},
            ["Mushroom"]={chance=9.092,restockMin=2,restockMax=5},["Green Bean"]={chance=15,restockMin=1,restockMax=2},
            ["Banana"]={chance=9,restockMin=1,restockMax=1},["Grape"]={chance=6.668,restockMin=1,restockMax=1},
            ["Coconut"]={chance=5.001,restockMin=1,restockMax=1},["Mango"]={chance=5.001,restockMin=1,restockMax=1},
            ["Dragon Fruit"]={chance=4,restockMin=1,restockMax=1},["Acorn"]={chance=2.942,restockMin=1,restockMax=3},
            ["Cherry"]={chance=2.274,restockMin=1,restockMax=1},["Sunflower"]={chance=1.787,restockMin=1,restockMax=1},
            ["Venus Fly Trap"]={chance=1.43,restockMin=1,restockMax=1},["Pomegranate"]={chance=0.927,restockMin=1,restockMax=1},
            ["Poison Apple"]={chance=0.533,restockMin=1,restockMax=1},["Venom Spitter"]={chance=0.475,restockMin=1,restockMax=1},
            ["Moon Bloom"]={chance=0.35,restockMin=1,restockMax=1},["Hypno Bloom"]={chance=0.275,restockMin=1,restockMax=1},
            ["Dragon's Breath"]={chance=0.2,restockMin=1,restockMax=1},["Ghost Pepper"]={chance=0.533,restockMin=1,restockMax=1},
            ["Poison Ivy"]={chance=0.533,restockMin=1,restockMax=1},["Glow Mushroom"]={chance=0.533,restockMin=1,restockMax=1},
            ["Romanesco"]={chance=0.533,restockMin=1,restockMax=1},["Horned Melon"]={chance=0.533,restockMin=1,restockMax=1},
        }

        local function GetRestockData()
            local sv = ReplicatedStorage:FindFirstChild("StockValues")
            if not sv then return nil end
            local ss = sv:FindFirstChild("SeedShop")
            if not ss then return nil end
            local nextVal = ss:FindFirstChild("UnixNextRestock")
            local lastVal = ss:FindFirstChild("UnixLastRestock")
            if not nextVal or not lastVal then return nil end
            local interval = math.max(nextVal.Value - lastVal.Value, 1)
            return {nextRestock = nextVal.Value, lastRestock = lastVal.Value, interval = interval}
        end

        local function FormatSeconds(secs)
            secs = math.max(0, math.floor(secs))
            local h = math.floor(secs / 3600)
            local m = math.floor((secs % 3600) / 60)
            local s = secs % 60
            if h > 0 then return h .. "j " .. m .. "m " .. s .. "s"
            elseif m > 0 then return m .. "m " .. s .. "s" end
            return s .. "s"
        end
        local function FormatUnixTime(unix)
            local d = os.date("*t", unix)
            if d then return string.format("%02d:%02d:%02d", d.hour, d.min, d.sec) end
            return tostring(unix)
        end
        local function ExpectedRestocksUntilAppear(chance)
            if chance >= 100 then return 1 end
            return math.ceil(1 / (chance / 100))
        end
        local function RestocksFor75Pct(chance)
            if chance >= 100 then return 1 end
            local p = chance / 100
            return math.max(1, math.ceil(math.log(0.25) / math.log(1 - p)))
        end
        local function RestockColor(restocksLeft)
            if restocksLeft <= 1 then return Colors.Success
            elseif restocksLeft <= 10 then return Colors.Warning
            elseif restocksLeft <= 50 then return Colors.Electric
            else return Colors.Error end
        end

        local timerRow = Create("Frame", {Parent = predictContent, Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y})
        CreateListLayout(timerRow, 4)
        local _, nextRestockLbl = CreateStatRow(timerRow, "\226\143\177 Restock Berikutnya", "...", Colors.Rainbow)
        local _, intervalLbl    = CreateStatRow(timerRow, "\240\159\147\144 Interval", "...", Colors.TextSecondary)
        local _, stockCountLbl  = CreateStatRow(timerRow, "\240\159\147\166 Tersedia Sekarang", "...", Colors.Success)

        local _predictTick = 0
        RunService.Heartbeat:Connect(function(dt)
            if GetActivePage() ~= "Shop" then return end
            _predictTick = _predictTick + dt
            if _predictTick < 0.5 then return end
            _predictTick = 0
            local data = GetRestockData()
            if not data then
                nextRestockLbl.Text = "\226\154\160 StockValues tidak ditemukan"
                intervalLbl.Text = "\226\128\148"
                stockCountLbl.Text = "\226\128\148"
                return
            end
            local sisa = math.max(0, data.nextRestock - os.time())
            nextRestockLbl.Text = sisa > 0 and (FormatSeconds(sisa) .. "  (jam " .. FormatUnixTime(data.nextRestock) .. ")") or "\240\159\159\162 RESTOCK SEKARANG!"
            intervalLbl.Text = FormatSeconds(data.interval)
            local items = ReplicatedStorage:FindFirstChild("StockValues") and ReplicatedStorage.StockValues:FindFirstChild("SeedShop") and ReplicatedStorage.StockValues.SeedShop:FindFirstChild("Items")
            local available = 0
            if items then
                for _, c in ipairs(items:GetChildren()) do
                    if c:IsA("NumberValue") and c.Value > 0 then available = available + 1 end
                end
            end
            stockCountLbl.Text = available .. " seed ada stok"
        end)

        CreateSubHeader(predictContent, "\240\159\140\177 Prediksi Per Seed")
        States.predictSeedTarget = States.predictSeedTarget or SEEDS[1]
        CreateDropdown(predictContent, "Pilih Seed", SEEDS, "predictSeedTarget")
        CreateActionButton(predictContent, "\240\159\148\141 Prediksi Seed Ini", function()
            local seedName = States.predictSeedTarget or SEEDS[1]
            local data = GetRestockData()
            if not data then Notify("Predict", "\226\154\160\239\184\143 Data restock tidak ditemukan!", Colors.Warning, 5) return end
            local stock = GetSeedStock(seedName)
            local sdata = SEED_RESTOCK_DATA[seedName]
            local sisa = math.max(0, data.nextRestock - os.time())
            if stock > 0 then
                Notify("\240\159\140\177 " .. seedName, "\226\156\133 Ada stok: " .. stock, Colors.Success, 8)
                task.wait(0.1)
                Notify("\226\143\177 Restock berikutnya", FormatSeconds(sisa), Colors.Accent, 8)
                return
            end
            if not sdata then Notify("\240\159\140\177 " .. seedName, "\226\157\140 Stok habis, data chance tidak ada", Colors.Warning, 6) return end
            local meanN = ExpectedRestocksUntilAppear(sdata.chance)
            local n75 = RestocksFor75Pct(sdata.chance)
            local etaDetik = sisa + (data.interval * (meanN - 1))
            local eta75Detik = sisa + (data.interval * (n75 - 1))
            local col = RestockColor(meanN)
            Notify("\240\159\140\177 " .. seedName, "\226\157\140 Stok habis | Chance: " .. sdata.chance .. "%", col, 10)
            task.wait(0.1)
            Notify("\240\159\147\138 Expected muncul", "~" .. meanN .. " restock lagi (~" .. FormatSeconds(etaDetik) .. ")", col, 10)
            task.wait(0.1)
            Notify("\240\159\142\175 75% kemungkinan", "dalam " .. n75 .. " restock (~" .. FormatSeconds(eta75Detik) .. ")", Colors.Warning, 10)
        end, Colors.Rainbow)

        -- Auto Buy Gear
        local gearCard, gearContent = CreateSectionCard("\226\154\153\239\184\143 Auto Buy Gear", 3, Colors.Electric)
        CreateInfoText(gearContent, "Cara Pakai", "Pilih gear di 'Pilih Gear Target', aktifkan toggle. Script beli 1 gear per cycle selama stok ada.")
        CreateToggle(gearContent, "Auto Buy Gear", "autoBuyGear", "Loop cepat beli gear yang dipilih, stop jika stok 0", function(newVal, revert)
            if newVal and not States.autoBuyGearAll then
                local targets = States.autoBuyGearTargets or {}
                if #targets == 0 then
                    revert()
                    Notify("Auto Buy Gear", "\226\154\160\239\184\143 Pilih gear dulu sebelum aktifkan!", Colors.Warning, 5)
                    return
                end
            end
            if newVal then pcall(MuteSFX_Failed) end
        end)
        CreateToggle(gearContent, "Beli SEMUA Gear yang ada stok", "autoBuyGearAll", "ON: beli semua gear yg stok > 0 | OFF: hanya gear dipilih")
        CreateMultiSelect(gearContent, "\226\154\153\239\184\143Pilih Gear Target", GEARS, "autoBuyGearTargets")
        CreateSlider(gearContent, "Delay Antar Beli Gear (s)", 0, 2, "gearBuyDelay")
        CreateSlider(gearContent, "Loop Delay Gear (s)", 0, 10, "gearShopLoopDelay")
        CreateToggle(gearContent, "Notif Saat Beli Gear", "notifyBuyGear", "Tampilkan notif setiap gear dibeli")

        -- Auto Buy Crate
        local crateCard, crateContent = CreateSectionCard("\240\159\147\166 Auto Buy Crate", 4, Colors.Warning)
        CreateInfoText(crateContent, "Cara Pakai", "Pilih crate di 'Pilih Crate Target', aktifkan toggle. Stok dibaca dari StockValues.CrateShop.Items.")
        CreateToggle(crateContent, "Auto Buy Crate", "autoBuyCrate", "Loop cepat beli crate yang dipilih, stop jika stok 0", function(newVal, revert)
            if newVal and not States.autoBuyCrateAll then
                local targets = States.autoBuyCrateTargets or {}
                if #targets == 0 then
                    revert()
                    Notify("Auto Buy Crate", "\226\154\160\239\184\143 Pilih crate dulu sebelum aktifkan!", Colors.Warning, 5)
                    return
                end
            end
            if newVal then pcall(MuteSFX_Failed) end
        end)
        CreateToggle(crateContent, "Beli SEMUA Crate yang ada stok", "autoBuyCrateAll", "ON: beli semua crate yg stok > 0 | OFF: hanya crate dipilih")
        CreateMultiSelect(crateContent, "\240\159\147\166Pilih Crate Target", CRATES, "autoBuyCrateTargets")
        CreateSlider(crateContent, "Delay Antar Beli Crate (s)", 0, 2, "crateBuyDelay")
        CreateSlider(crateContent, "Loop Delay Crate (s)", 0, 10, "crateShopLoopDelay")
        CreateToggle(crateContent, "Notif Saat Beli Crate", "notifyBuyCrate", "Tampilkan notif setiap crate dibeli")
        CreateActionButton(crateContent, "\240\159\155\146 Beli Crate yang Dipilih Sekarang", function()
            local targets = States.autoBuyCrateTargets or {}
            if #targets == 0 then Notify("Buy Crate", "\226\154\160\239\184\143 Pilih crate dulu!", Colors.Warning) return end
            local bought = 0
            for _, crateName in ipairs(targets) do
                local stock = GetCrateStock(crateName)
                if stock > 0 then
                    BuyCratePacket(crateName, 1)
                    bought = bought + 1
                    task.wait(0.1)
                end
            end
            Notify("Buy Crate", "Beli " .. bought .. " crate sekarang.", Colors.Warning)
        end, Colors.Warning)
        CreateActionButton(crateContent, "\240\159\146\176 Lihat Harga Crate", function()
            local lines = {}
            for _, name in ipairs(CRATES) do
                local cost = CRATE_COST[name] or 0
                local costStr = cost >= 1000000 and string.format("%.1fM", cost/1000000) or string.format("%dk", cost/1000)
                table.insert(lines, name:gsub(" Crate", "") .. ": \194\162" .. costStr)
            end
            Notify("Harga Crate", table.concat(lines, " | "):sub(1, 200), Colors.Gold, 10)
        end)

        -- Auto Open Crate
        local openCrateCard, openCrateContent = CreateSectionCard("\240\159\142\129 Auto Open Crate", 5, Colors.Gold)
        CreateInfoText(openCrateContent, "Cara Kerja", "Script cek inventory; jika ada crate tool, otomatis equip lalu open via Networking.Crate.OpenCrate.")
        CreateToggle(openCrateContent, "Auto Open Crate", "autoOpenCrate", "Open semua crate di inventory secara otomatis")
        CreateSlider(openCrateContent, "Delay Antar Open (s)", 1, 30, "crateOpenDelay")
        CreateToggle(openCrateContent, "Notif Hasil Open", "notifyOpenCrate", "Tampilkan item yang didapat saat open crate")
        CreateActionButton(openCrateContent, "\240\159\148\141 Scan Crate di Inventory", function()
            local cratesInBag = GetCratesInInventory()
            if #cratesInBag == 0 then Notify("Scan Crate", "Tidak ada crate di inventory.", Colors.TextMuted) return end
            local names = {}
            for _, entry in ipairs(cratesInBag) do table.insert(names, entry.name) end
            Notify("Crate di Bag (" .. #cratesInBag .. ")", table.concat(names, ", "):sub(1, 150), Colors.Warning, 6)
        end)
        CreateActionButton(openCrateContent, "\226\154\161 Open Semua Crate Sekarang", function()
            local cratesInBag = GetCratesInInventory()
            if #cratesInBag == 0 then Notify("Open Crate", "Tidak ada crate di inventory!", Colors.Error) return end
            Notify("Open Crate", "Opening " .. #cratesInBag .. " crate(s)...", Colors.Warning)
            task.spawn(function()
                for _, entry in ipairs(cratesInBag) do
                    local tool = entry.tool
                    local crateName = entry.name
                    if tool.Parent ~= player.Character then
                        tool.Parent = player.Character
                        task.wait(0.2)
                    end
                    local ok, result = pcall(function() return OpenCrateViaNetworking(crateName) end)
                    if ok then
                        local wonItem = type(result) == "table" and result.WonItem
                        if wonItem then
                            Notify("\240\159\147\166 " .. crateName, "Dapat: " .. (wonItem.Name or "?"), Colors.Gold, 5)
                        else
                            Notify("\240\159\147\166 Opened!", crateName, Colors.Warning, 3)
                        end
                    end
                    task.wait(0.5)
                    if tool and tool.Parent == player.Character then tool.Parent = player.Backpack end
                    task.wait(States.crateOpenDelay or 8)
                end
            end)
        end, Colors.Gold)
        CreateActionButton(openCrateContent, "\240\159\147\139 Copy Semua Packet IDs", function()
            local ids = {}
            for k, v in pairs(PACKET) do table.insert(ids, k .. "=" .. v) end
            table.sort(ids)
            setclipboard(table.concat(ids, ", "))
            Notify("Dev", "Semua Packet IDs disalin ke clipboard.", Colors.Accent)
        end)
    end)

    -- ====================== SELL PAGE ======================
    ctx.registerPage("Sell", function()
        local sellCard, sellContent = CreateSectionCard("\240\159\146\176 Auto Sell", 1, Colors.Gold)
        local netStatus = Networking and "\226\156\133 Networking OK (Networking.NPCS.SellAll)" or "\226\157\140 Networking nil \226\128\148 sell tidak akan work!"
        CreateInfoText(sellContent, "Sell System", netStatus .. "\nCara benar: Networking.NPCS.SellAll:Fire() atau SellFruit:Fire(fruitId).")
        CreateToggle(sellContent, "Auto Sell Fruits", "autoSell", "Loop otomatis jual semua buah via Networking.NPCS.SellAll")
        CreateToggle(sellContent, "Keep Mutations (Jangan Dijual)", "keepMutations", "Skip semua buah yg punya mutation apapun")
        CreateMultiSelect(sellContent, "🔒Keep Mutation Spesifik", MUTATIONS, "sellKeepMutation")
        CreateSlider(sellContent, "Delay Antar Jual (s)", 0, 3, "sellDelay")
        CreateSlider(sellContent, "Loop Delay (s)", 1, 60, "sellLoopDelay")
        CreateToggle(sellContent, "Notif Saat Jual", "notifySell", "Tampilkan notif hasil penjualan + total")

        CreateActionButton(sellContent, "\240\159\148\141 Preview Harga Inventory", function()
            if not Networking then Notify("Preview", "\226\157\140 Networking nil!", Colors.Error) return end
            local ok, data = pcall(function() return Networking.NPCS.PreviewSellAll:Fire() end)
            if ok and data and data.FruitCount then
                local ddok, dddata = pcall(function() return Networking.NPCS.CheckDailyDeal:Fire() end)
                local ddAvail = ddok and dddata and dddata.Available
                local msg = data.FruitCount .. " buah | Normal: " .. tostring(data.TotalValue or 0) .. "\194\162"
                if ddAvail then
                    local ddPrice = math.max(1, math.floor((data.TotalBaseValue or data.TotalValue or 0) * 5))
                    msg = msg .. " | Daily Deal: " .. tostring(ddPrice) .. "\194\162 (5x!) \226\173\144"
                end
                Notify("Preview Sell", msg, Colors.Gold, 6)
            else
                Notify("Preview Sell", "Tidak ada buah di inventory.", Colors.TextMuted)
            end
        end)
        CreateActionButton(sellContent, "\226\154\161 Jual Semua Sekarang", function()
            if not Networking then Notify("Sell", "\226\157\140 Networking nil! Coba reload hub.", Colors.Error) return end
            local ok, result = pcall(function() return Networking.NPCS.SellAll:Fire() end)
            if ok and result and result.Success then
                Notify("Sell \226\156\133", "Sold " .. (result.SoldCount or "?") .. " buah = " .. tostring(result.SellPrice or 0) .. "\194\162", Colors.Gold, 10)
            else
                Notify("Sell", "Gagal: " .. tostring(result and result.Reason or "Networking error"), Colors.Error)
            end
        end, Colors.Gold)
        CreateActionButton(sellContent, "\240\159\142\175 Jual Selective (Pakai Filter)", function()
            if not Networking then Notify("Sell", "\226\157\140 Networking nil!", Colors.Error) return end
            local fruits = {}
            for _, tool in ipairs(player.Backpack:GetChildren()) do
                if tool:GetAttribute("FruitName") or tool:GetAttribute("HarvestedFruit") then
                    table.insert(fruits, tool)
                end
            end
            if #fruits == 0 then Notify("Sell", "Tidak ada buah di backpack.", Colors.TextMuted) return end
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
            Notify("Sell Selective", "Sold " .. sold .. " buah, skip " .. skipped, Colors.Gold, 10)
        end)

        local bagCard, bagContent = CreateSectionCard("\240\159\142\146 Bag Inspector", 2, Colors.Accent)
        local _, fruitLbl = CreateStatRow(bagContent, "Harvested Fruits in Bag", "?", Colors.Warning)
        local _, seedLbl = CreateStatRow(bagContent, "Seeds in Bag", "?", Colors.Success)
        local _, petCntLbl = CreateStatRow(bagContent, "Pets in Bag", "?", Colors.Frozen)
        local _, capLbl = CreateStatRow(bagContent, "Capacity", "? / " .. MAX_FRUIT_CAP, Colors.Accent)
        local _bagTick = 0
        RunService.Heartbeat:Connect(function(dt)
            if GetActivePage() ~= "Sell" then return end
            _bagTick = _bagTick + dt
            if _bagTick < 0.5 then return end
            _bagTick = 0
            local fruits, seeds, pets, g = 0, 0, 0, 0
            for _, t in ipairs(player.Backpack:GetChildren()) do
                if t:GetAttribute("HarvestedFruit") then fruits = fruits + 1
                elseif t:GetAttribute("SeedTool") or t:GetAttribute("SeedName") then seeds = seeds + 1
                elseif t:GetAttribute("Pet") then pets = pets + 1
                else g = g + 1 end
            end
            fruitLbl.Text = tostring(fruits)
            seedLbl.Text = tostring(seeds)
            petCntLbl.Text = tostring(pets)
            capLbl.Text = fruits .. " / " .. tostring(player:GetAttribute("MaxFruitCapacity") or MAX_FRUIT_CAP)
        end)
        CreateActionButton(bagContent, "\240\159\147\139 List Semua Buah di Bag", function()
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
            if #items == 0 then Notify("Bag", "Tidak ada buah di backpack.", Colors.TextMuted)
            else
                Notify("Bag (" .. #items .. " buah)", table.concat(items, ", "):sub(1, 150), Colors.Accent, 7)
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
            CreateSubHeader(listArea, "Pets di Backpack (" .. #playerPets .. ")")
            if #playerPets == 0 then
                CreateInfoText(listArea, nil, "Tidak ada pet di backpack saat ini.", Colors.TextMuted)
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
        CreateInfoText(finderContent, "Cara Kerja", "Membaca Workspace.Map.WildPetRef. Setiap pet BasePart dengan Attribute Rarity & OwnerUserId (0 = bebas).")
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
                CreateInfoText(listContainer, nil, "Tidak ada wild pet bebas ditemukan di WildPetRef.", Colors.TextMuted)
                return
            end
            CreateSubHeader(listContainer, #pets .. " pet tersedia")
            for i, entry in ipairs(pets) do
                if i > 15 then
                    CreateInfoText(listContainer, nil, "... dan " .. (#pets - 15) .. " lainnya.", Colors.TextMuted)
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
                        Notify("Pet Finder", "Pet sudah menghilang!", Colors.Error)
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
        CreateActionButton(finderContent, "\226\154\161 TP ke Pet Terdekat", function()
            local pets = ScanWildPets("All")
            if #pets == 0 then Notify("Pet Finder", "Tidak ada pet tersedia saat ini.", Colors.Error) return end
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
        CreateInfoText(wildContent, "Auto Catch via WildPetRef", "Loop otomatis hop ke tiap pet yang dipilih. Kalau tidak ada dipilih = tangkap semua.")
        local WILD_PET_NAMES = {"Frog", "Bunny", "Owl", "Deer", "Turtle", "Robin", "Bee", "Monkey", "Bear", "Unicorn", "Golden Dragonfly", "Raccoon", "Black Dragon", "Ice Serpent"}
        CreateMultiSelect(wildContent, "\240\159\144\190Pilih Pet Target", WILD_PET_NAMES, "wildCatchTargets")
        CreateToggle(wildContent, "Auto Catch Wild Pets", "autoCatchWild",
            "ON: loop jalan terus, notif saat menunggu spawn | OFF: loop berhenti",
            function(newVal)
                if newVal then
                    local sel = States.wildCatchTargets or {}
                    if #sel == 0 then Notify("Auto Catch", "ON \226\128\148 mengejar semua pet yang spawn", Colors.Success, 3)
                    else Notify("Auto Catch", "ON \226\128\148 mengejar: " .. table.concat(sel, ", "), Colors.Success, 3) end
                else
                    Notify("Auto Catch", "OFF", Colors.TextMuted, 2)
                end
            end)
    end)

    -- ====================== EGGS PAGE ======================
    ctx.registerPage("Eggs", function()
        local eggCard, eggContent = CreateSectionCard("\240\159\165\154 Egg Hatching", 1, Colors.Warning)
        CreateInfoText(eggContent, "\240\159\154\167 Coming Soon",
            "Fitur Egg Hatching sedang dalam pengembangan.\nBelum banyak yang punya egg, jadi fitur ini belum diaktifkan.\nStay tuned untuk update berikutnya!")
    end)

    -- ====================== PLAYER PAGE ======================
    ctx.registerPage("Player", function()
        local statsCard, statsContent = CreateSectionCard("\240\159\147\138 Live Player Stats", 1, Colors.Accent)
        local _, hpLbl = CreateStatRow(statsContent, "Health", "100 / 100", Colors.Success)
        local _, wsLbl = CreateStatRow(statsContent, "WalkSpeed", tostring(ctx.humanoid and ctx.humanoid.WalkSpeed or "?"), Colors.Accent)
        local _, jpLbl = CreateStatRow(statsContent, "JumpPower", tostring(ctx.humanoid and ctx.humanoid.JumpPower or "?"), Colors.Accent)
        CreateStatRow(statsContent, "Plot ID", MY_PLOT_ID, Colors.Warning)
        local _, bpLbl = CreateStatRow(statsContent, "Backpack Items", #player.Backpack:GetChildren(), Colors.TextSecondary)
        local _playerTick = 0
        RunService.Heartbeat:Connect(function(dt)
            if GetActivePage() ~= "Player" or not ctx.humanoid then return end
            hpLbl.Text = math.floor(ctx.humanoid.Health) .. " / " .. ctx.humanoid.MaxHealth
            wsLbl.Text = string.format("%.1f", ctx.humanoid.WalkSpeed)
            jpLbl.Text = string.format("%.1f", ctx.humanoid.JumpPower)
            _playerTick = _playerTick + dt
            if _playerTick < 0.5 then return end
            _playerTick = 0
            bpLbl.Text = tostring(#player.Backpack:GetChildren())
        end)

        local moveCard, moveContent = CreateSectionCard("\240\159\143\131 Movement", 2, Colors.Electric)
        CreateToggle(moveContent, "Lock WalkSpeed", "lockWalkSpeed")
        CreateSlider(moveContent, "WalkSpeed", 1, 500, "walkSpeed")
        CreateToggle(moveContent, "Lock JumpPower", "lockJumpPower")
        CreateSlider(moveContent, "JumpPower", 1, 500, "jumpPower")
        CreateToggle(moveContent, "Infinite Jump", "infiniteJump")

        local utilCard, utilContent = CreateSectionCard("\226\156\136\239\184\143 Fly", 3, Colors.TextSecondary)
        CreateInfoText(utilContent, "Controls", "[F] Toggle Fly | [W/A/S/D] Move | [Space] Up | [Ctrl] Down")
        CreateToggle(utilContent, "Fly", "fly", "Hold WASD to fly, Space=up, Ctrl=down")
        CreateSlider(utilContent, "Fly Speed", 1, 300, "flySpeed")
        CreateToggle(utilContent, "Anti AFK", "antiAfk", "Prevents auto-disconnect")
        CreateActionButton(utilContent, "Reset Character", function()
            if ctx.humanoid then ctx.humanoid.Health = 0 end
            Notify("Player", "Resetting character...", Colors.Warning)
        end)
        CreateActionButton(utilContent, "Respawn To Plot", function()
            local plot = GetMyPlot()
            if plot then
                local sp = plot:FindFirstChild("SpawnPoint")
                if sp and player.Character then
                    player.Character:PivotTo(sp.CFrame + Vector3.new(0, 5, 0))
                    Notify("Player", "Respawned to Plot " .. MY_PLOT_ID, Colors.Success)
                    return
                end
            end
            Notify("Player", "SpawnPoint not found.", Colors.Error)
        end, Colors.Success)
    end)

    -- ====================== VISUALS PAGE ======================
    ctx.registerPage("Visuals", function()
        local espCard, espContent = CreateSectionCard("\240\159\145\129 ESP & Highlights", 1, Colors.Electric)
        CreateInfoText(espContent, "ESP system", "Renders BillboardGuis on targets. Wild Pets dari Workspace.Map.WildPetRef, mutations dari plant attrs.")
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
    end)

    -- ====================== TELEPORT PAGE ======================
    ctx.registerPage("Teleport", function()
        local tpCard, tpContent = CreateSectionCard("\240\159\147\141 Quick Teleport", 1, Colors.Accent)
        CreateInfoText(tpContent, "Scanner data", "Workspace.Teleports: Seeds, Sell, Gears, Props.")
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
                        Notify("Teleport", "Part '" .. tp[2] .. "' not found!", Colors.Error)
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
        local savedCard, savedContent = CreateSectionCard("\240\159\146\190 Saved Positions", 2, Colors.TextSecondary)
        local savedPos = nil
        CreateActionButton(savedContent, "Save Current Position", function()
            if player.Character then
                savedPos = player.Character:GetPivot().Position
                Notify("Teleport", "Saved: " .. string.format("%.1f, %.1f, %.1f", savedPos.X, savedPos.Y, savedPos.Z), Colors.Success)
            end
        end)
        CreateActionButton(savedContent, "Load Saved Position", function()
            if savedPos and player.Character then
                player.Character:PivotTo(CFrame.new(savedPos + Vector3.new(0, 3, 0)))
                Notify("Teleport", "Loaded saved position.", Colors.Accent)
            else
                Notify("Teleport", "No position saved yet.", Colors.Error)
            end
        end)
        CreateSlider(savedContent, "Teleport Delay (s)", 0, 10, "tpDelay")
    end)

    -- ====================== UTILITY PAGE ======================
    ctx.registerPage("Utility", function()
        local worthCard, worthContent = CreateSectionCard("\240\159\146\142 Item Inspector", 1, Colors.Gold)
        CreateInfoText(worthContent, "Fruit attrs", "Weight, SizeMultiplier, DecayAlpha, Mutation.")
        local toolNameLbl
        do
            local currentTool = player.Character and player.Character:FindFirstChildWhichIsA("Tool")
            local _, v = CreateStatRow(worthContent, "Currently Holding", currentTool and currentTool.Name or "Nothing", Colors.TextPrimary)
            toolNameLbl = v
        end
        RunService.Heartbeat:Connect(function()
            if GetActivePage() == "Utility" and toolNameLbl and toolNameLbl.Parent then
                local ct = player.Character and player.Character:FindFirstChildWhichIsA("Tool")
                toolNameLbl.Text = ct and ct.Name or "Nothing"
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
                    else Notify("Inspect", ct.Name .. " \226\128\148 no fruit/seed attrs.", Colors.TextMuted) end
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

        local toolCard, toolContent = CreateSectionCard("\240\159\148\167 Quick Tools", 2)
        CreateActionButton(toolContent, "Copy My Position", function()
            if player.Character then
                local pos = player.Character:GetPivot().Position
                setclipboard(string.format("%.2f, %.2f, %.2f", pos.X, pos.Y, pos.Z))
                Notify("Copied", string.format("%.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z), Colors.Success)
            end
        end)
        CreateActionButton(toolContent, "Copy Job ID", function()
            setclipboard(game.JobId)
            Notify("Copied", "Job ID: " .. game.JobId:sub(1, 20) .. "...", Colors.Accent)
        end)
        CreateActionButton(toolContent, "Show All Player Attributes", function()
            local attrList = {}
            for k, v in pairs(player:GetAttributes()) do table.insert(attrList, k .. "=" .. tostring(v)) end
            table.sort(attrList)
            Notify("Player Attrs", table.concat(attrList, " | "):sub(1, 120), Colors.Accent, 8)
        end)

        local giftCard, giftContent = CreateSectionCard("\240\159\142\129 Gifts & Mailbox", 3, Colors.Rainbow)
        CreateToggle(giftContent, "Auto Accept Gifts", "autoAcceptGifts", "Triggers MailboxPrompt every 10 seconds")
        CreateActionButton(giftContent, "Check Mailbox Now", function()
            local plot = GetMyPlot()
            if not plot then Notify("Mailbox", "Plot " .. MY_PLOT_ID .. " not found!", Colors.Error) return end
            local signs = plot:FindFirstChild("Signs")
            if not signs then Notify("Mailbox", "Signs folder not found!", Colors.Error) return end
            local mailbox = signs:FindFirstChild("GreyMailBox")
            if not mailbox then Notify("Mailbox", "GreyMailBox not found!", Colors.Error) return end
            local found = false
            for _, desc in ipairs(mailbox:GetDescendants()) do
                if desc:IsA("ProximityPrompt") and desc.Name == "MailboxPrompt" then
                    SafeFirePrompt(desc)
                    found = true
                    break
                end
            end
            Notify("Mailbox", found and "Checked mailbox on Plot " .. MY_PLOT_ID or "MailboxPrompt not found!", found and Colors.Rainbow or Colors.Error)
        end, Colors.Rainbow)
    end)

    -- ====================== MAILER PAGE ======================
    ctx.registerPage("Mailer", function()
        local mailerCard, mailerContent = CreateSectionCard("\226\156\137 Mailer System", 1, Colors.Accent)
        CreateInfoText(mailerContent, "Mailer info", "Send items via GreyMailBox on plots. BidPrice/BidsAsked attrs detected on fruits.")
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
        CreateStatRow(infoContent, "PlotId (detected)", MY_PLOT_ID, Colors.Warning)
        CreateStatRow(infoContent, "Prime Status", (player:GetAttribute("PrimeEnabled") and "\226\156\133 Enabled" or "\226\157\140 Disabled"), Colors.Warning)
        CreateStatRow(infoContent, "Packet Remote", ctx.PacketRemote and "\226\156\133 Found" or "\226\154\160 Not Found", ctx.PacketRemote and Colors.Success or Colors.Error)

        local keybindCard, keybindContent = CreateSectionCard("\226\140\168 Keybinds", 2, Colors.TextSecondary)
        CreateInfoText(keybindContent, nil, "[Insert] Toggle GUI | [F] Toggle Fly | [W/A/S/D] + Fly Move | [Space] Ascend | [Ctrl] Descend")
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
        local _serverTick = 0
        RunService.Heartbeat:Connect(function(dt)
            if GetActivePage() ~= "Server" then return end
            _serverTick = _serverTick + dt
            if _serverTick < 1 then return end
            _serverTick = 0
            pcLbl.Text = tostring(#game:GetService("Players"):GetPlayers())
            for _, entry in ipairs(playerPlotLabels) do
                if entry.lbl and entry.lbl.Parent then
                    entry.lbl.Text = "Plot " .. tostring(entry.p:GetAttribute("PlotId") or "?")
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

        local scanCard, scanContent = CreateSectionCard("\240\159\169\160 Mythic Pet Server Scanner", 3, Colors.Rainbow)
        CreateInfoText(scanContent, "Server hop", "Cek server saat ini untuk wild pet target, lalu hop ke public server berikutnya sampai ketemu.")
        CreateDropdown(scanContent, "Target Rarity", {"Mythic", "Super", "Legendary", "Epic", "Rare", "Uncommon", "Common"}, "serverScannerRarity")
        CreateSlider(scanContent, "Hop Delay", 5, 60, "serverScannerDelay", "s")
        CreateToggle(scanContent, "Auto Hop Until Found", "autoServerScanner", "Terus hop server publik sampai pet target ditemukan", function(newVal, revert)
            if not newVal then return end
            local targetRarity = States.serverScannerRarity or "Mythic"
            Notify("Server Scanner", "Mulai cari server dengan pet " .. targetRarity .. ".", Colors.Warning, 4)
            task.spawn(function()
                local ok, result = false, nil
                if Logic.HopUntilWildPetRarityFound then
                    ok, result = Logic.HopUntilWildPetRarityFound(targetRarity)
                end
                if ok and type(result) == "table" and result.found then
                    Notify("Server Scanner", targetRarity .. " pet sudah ada di server ini.", Colors.Success, 4)
                elseif ok then
                    Notify("Server Scanner", "Hopping ke server publik berikutnya...", Colors.Warning, 3)
                else
                    if revert then revert() end
                    Notify("Server Scanner", "Gagal memulai server hunt.", Colors.Error)
                end
            end)
        end)
        CreateActionButton(scanContent, "Run Hunt Once", function()
            local targetRarity = States.serverScannerRarity or "Mythic"
            local ok, result = false, nil
            if Logic.HopUntilWildPetRarityFound then
                ok, result = Logic.HopUntilWildPetRarityFound(targetRarity)
            end
            if ok and type(result) == "table" and result.found then
                Notify("Server Scanner", targetRarity .. " pet sudah ada di server ini.", Colors.Success, 4)
            elseif ok then
                Notify("Server Scanner", "Teleport ke server publik berikutnya dimulai.", Colors.Warning, 3)
            else
                Notify("Server Scanner", "Gagal menjalankan hunt.", Colors.Error)
            end
        end, Colors.Rainbow)
        CreateActionButton(scanContent, "Scan Current Server", function()
            local targetRarity = States.serverScannerRarity or "Mythic"
            local pets = Logic.ScanWildPets and Logic.ScanWildPets(targetRarity) or {}
            if #pets == 0 then
                Notify("Server Scanner", "Tidak ada wild pet " .. targetRarity .. " di server ini.", Colors.TextMuted, 4)
                return
            end

            local preview = {}
            for i = 1, math.min(#pets, 5) do
                local entry = pets[i]
                table.insert(preview, entry.name .. " (" .. entry.rarity .. ")")
            end
            NotifyStok(preview, Colors.Success, 8, "Target ditemukan di server ini: " .. targetRarity)
        end, Colors.Success)
        CreateActionButton(scanContent, "Hop To Next Public Server", function()
            local targetRarity = States.serverScannerRarity or "Mythic"
            local server = Logic.FindNextPublicServer and Logic.FindNextPublicServer(game.JobId, 8)
            if not server then
                Notify("Server Scanner", "Tidak ada public server kandidat yang tersedia.", Colors.Error)
                return
            end

            local jobId = server.id or server.jobId
            if not jobId then
                Notify("Server Scanner", "Job ID server tidak valid.", Colors.Error)
                return
            end

            local ok = Logic.HopToServer and Logic.HopToServer(jobId, targetRarity)
            if not ok then
                Notify("Server Scanner", "Gagal teleport ke server target.", Colors.Error)
            end
        end, Colors.Rainbow)
    end)

    -- ====================== SETTINGS PAGE ======================
    ctx.registerPage("Settings", function()
        local settCard, settContent = CreateSectionCard("\226\154\153 General Settings", 1, Colors.Accent)
        CreateToggle(settContent, "Auto Save Config", "autoSaveConfig", "Saves your config automatically")
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
            States.autoServerScanner = false
            States.serverScannerRarity = "Mythic"
            States.serverScannerDelay = 8
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

        local debugCard, debugContent = CreateSectionCard("\240\159\155\160 Debug", 2, Colors.TextMuted)
        CreateActionButton(debugContent, "Test RemoteEvent Connection", function()
            if ctx.PacketRemote then
                Notify("Debug", "\226\156\133 PacketRemote found: " .. ctx.PacketRemote:GetFullName(), Colors.Success, 6)
            else
                local sm = ReplicatedStorage:FindFirstChild("SharedModules")
                local pk = sm and sm:FindFirstChild("Packet")
                local re = pk and pk:FindFirstChild("RemoteEvent")
                ctx.PacketRemote = re
                Notify("Debug", re and "\226\156\133 Found on retry!" or "\226\157\140 PacketRemote NOT found.", re and Colors.Success or Colors.Error, 6)
            end
        end)
        CreateActionButton(debugContent, "Print Gardens Tree", function()
            local gardens = game:GetService("Workspace"):FindFirstChild("Gardens")
            if gardens then
                for _, plot in ipairs(gardens:GetChildren()) do
                    local plants = plot:FindFirstChild("Plants")
                    local cnt = plants and #plants:GetChildren() or 0
                    print("[Miracle Hub] " .. plot.Name .. ": " .. cnt .. " plants")
                end
            end
            Notify("Debug", "Gardens tree printed to console.", Colors.TextMuted)
        end)
    end)

    ctx.__pagesLoaded = true
    return ctx
end