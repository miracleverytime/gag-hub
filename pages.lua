-- ======================================================================
-- Miracle Hub — pages.lua (RESTRUCTURED)
-- All page builders. Loaded FOURTH (after core, ui, logic).
-- Registers each page via ctx.registerPage(name, builderFn).
--
-- STRUCTURE: 5 Pages (reduced from 13)
--   1. Automation - All automation loops
--   2. Inventory  - Bag/pet/item management
--   3. Show       - ESP/visuals/stats
--   4. Misc       - Movement/fly/mailbox/server
--   5. Settings   - Config/general
-- ======================================================================

return function(ctx)
    local Colors            = ctx.Colors
    local States            = ctx.States
    local Data              = ctx.Data
    local player            = ctx.player
    local RunService        = ctx.RunService
    local CollectionService = ctx.CollectionService
    local MY_PLOT_ID        = ctx.MY_PLOT_ID
    local MAX_FRUIT_CAP     = ctx.MAX_FRUIT_CAP
    local MAX_EQUIPPED_PETS = ctx.MAX_EQUIPPED_PETS
    local SESSION           = ctx.SESSION
    local GetActivePage     = ctx.GetActivePage

    local UI    = ctx.UI
    local Logic = ctx.Logic

    -- UI shorthands
    local Create             = UI.Create
    local CreateCorner       = UI.CreateCorner
    local CreateStroke       = UI.CreateStroke
    local CreateListLayout   = UI.CreateListLayout
    local Tween              = UI.Tween
    local Notify             = UI.Notify
    local NotifyStok         = UI.NotifyStok
    local GetMutationColor   = UI.GetMutationColor
    local CreateSectionCard  = UI.CreateSectionCard
    local CreateSubHeader    = UI.CreateSubHeader
    local CreateToggle       = UI.CreateToggle
    local CreateSlider       = UI.CreateSlider
    local CreateActionButton = UI.CreateActionButton
    local CreateDropdown     = UI.CreateDropdown
    local CreateMultiSelect  = UI.CreateMultiSelect
    local CreateInfoText     = UI.CreateInfoText
    local CreateStatRow      = UI.CreateStatRow

    -- Data shorthands
    local SEEDS      = Data.SEEDS
    local GEARS      = Data.GEARS
    local CRATES     = Data.CRATES
    local MUTATIONS  = Data.MUTATIONS

    -- Logic shorthands
    local GetMyPlot              = Logic.GetMyPlot
    local GetPlantsFolder        = Logic.GetPlantsFolder
    local GetPlantedSeedCounts   = Logic.GetPlantedSeedCounts
    local GetReadyFruitCount     = Logic.GetReadyFruitCount
    local GetMutation            = Logic.GetMutation
    local SafeFirePrompt         = Logic.SafeFirePrompt
    local MuteSFX_Failed         = Logic.MuteSFX_Failed
    local ShouldKeepFruit        = Logic.ShouldKeepFruit
    local GetCratesInInventory   = Logic.GetCratesInInventory

    local Networking = ctx.Networking

    -- =========================================================
    -- MODULE-LEVEL HELPERS
    -- =========================================================

    local NO_TARGET_COOLDOWN = 5

    local function notifyIfCooled(lastTimeRef, title, msg, color, duration)
        local now = os.clock()
        if now - lastTimeRef[1] >= NO_TARGET_COOLDOWN then
            lastTimeRef[1] = now
            Notify(title, msg, color, duration or 5)
        end
    end

    local function makeForceOff(stateKey, setVisual)
        return function()
            States[stateKey] = false
            pcall(function() SaveState(stateKey, false) end)
            pcall(function() setVisual(false) end)
        end
    end

    local function setupMultiSelectGuard(
        parent, label, items, targetsKey, activeKey, allKey,
        msControl, forceOff, notifyTitle, onChangeCb
    )
        local msResult = CreateMultiSelect(parent, label, items, targetsKey)
        msControl.SetDisabled = msResult.SetDisabled

        if States[allKey] then
            task.defer(function()
                pcall(function() msControl.SetDisabled(true) end)
            end)
        end

        local prevCount = #(States[targetsKey] or {})
        task.spawn(function()
            while _G._MiracleHubSession == SESSION do
                task.wait(0.3)
                local cur = #(States[targetsKey] or {})
                if cur ~= prevCount then
                    prevCount = cur
                    if onChangeCb then pcall(onChangeCb) end
                    if States[activeKey] and cur == 0 then
                        forceOff()
                        Notify(notifyTitle, "No items selected — " .. notifyTitle .. " disabled.", Colors.Warning, 4)
                    end
                end
            end
        end)
    end

    -- ====================== PAGE 1: AUTOMATION ======================
    ctx.registerPage("Automation", function()

        -- ═══════════════════════════════════════════════════════════
        -- Section 1:  Farming
        -- ═══════════════════════════════════════════════════════════
        local _, farmContent = CreateSectionCard(" Farming", 1, Colors.Success)

        -- AUTO PLANT
        CreateSubHeader(farmContent, " Auto Plant")
        
        local lastNoTargetPlant = { [1] = 0 }
        local msPlantControl    = { SetDisabled = nil }

        local _, _, setAutoPlantVisual = CreateToggle(farmContent, "Auto Plant", "autoPlant",
            "Fills empty plot slots. Needs at least one seed selected below (or enable Plant All).",
            function(newVal, revert)
                if newVal and not States.autoPlantAllSeeds then
                    if #(States.autoPlantTargets or {}) == 0 then
                        revert()
                        notifyIfCooled(lastNoTargetPlant, "Auto Plant",
                            " Select seeds in 'Choose Seeds to Plant' before enabling Auto Plant!",
                            Colors.Warning)
                    end
                end
            end)

        local forceOffAutoPlant = makeForceOff("autoPlant", setAutoPlantVisual)

        CreateToggle(farmContent, "Plant All Seeds in Backpack", "autoPlantAllSeeds",
            "Plants all seeds in backpack, ignoring the selection below",
            function(newVal)
                if msPlantControl.SetDisabled then
                    pcall(function() msPlantControl.SetDisabled(newVal) end)
                end
            end)

        setupMultiSelectGuard(
            farmContent, "Choose Seeds to Plant", SEEDS,
            "autoPlantTargets", "autoPlant", "autoPlantAllSeeds",
            msPlantControl, forceOffAutoPlant, "Auto Plant", nil
        )

        CreateToggle(farmContent, "Notify on Plant Cycle", "autoPlantNotify",
            "Notifies you each time a planting cycle completes")

        -- AUTO HARVEST
        CreateSubHeader(farmContent, " Auto Harvest")
        
        -- LIVE COUNTER (Option C - styled stat row)
        local statsGrid = Create("Frame", {
            Parent            = farmContent,
            Size              = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            AutomaticSize     = Enum.AutomaticSize.Y,
        })
        CreateListLayout(statsGrid, 5)
        local _, readyCntLbl = CreateStatRow(statsGrid, "Ready to Harvest", "...", Colors.Success)
        
        -- Live polling untuk update counter
        task.spawn(function()
            while GetActivePage() == "Automation" do
                task.wait(1)
                if GetActivePage() ~= "Automation" then break end
                pcall(function()
                    local myPlot = GetMyPlot()
                    if not myPlot then return end
                    local readyFruits = 0
                    for _, prompt in ipairs(CollectionService:GetTagged("HarvestPrompt")) do
                        if prompt.Enabled and not prompt:GetAttribute("Collected")
                            and prompt:IsDescendantOf(myPlot) then
                            readyFruits = readyFruits + 1
                        end
                    end
                    readyCntLbl.Text = tostring(readyFruits)
                end)
            end
        end)

        CreateToggle(farmContent, "Auto Harvest", "autoHarvest", "Automatically harvest fruits on your plot")
        CreateToggle(farmContent, "Notify After Harvest", "notifyHarvest", "Show a notification after each harvest cycle")
        CreateSlider(farmContent, "Per-Fruit Delay (s)", 0, 2, "perFruitDelay")
        CreateSlider(farmContent, "Loop Delay (s)", 0, 30, "harvestLoopDelay")
        CreateMultiSelect(farmContent, "Skip Mutation", MUTATIONS, "harvestFilterMutation")

        -- AUTO WATER
        CreateSubHeader(farmContent, " Auto Water")
        
        local wateringCans = {}
        for _, g in ipairs(GEARS) do
            local gl = g:lower()
            if gl:find("watering") then table.insert(wateringCans, g) end
        end

        CreateToggle(farmContent, "Auto Water Plants", "autoWater",
            "Automatically waters all plants on your plot using your selected watering can",
            function(newVal, revert)
                if newVal and #(States.wateringCanTargets or {}) == 0 then
                    revert()
                    Notify("Auto Water", " Select a Watering Can below before enabling!", Colors.Warning, 5)
                end
            end)
        CreateMultiSelect(farmContent, " Choose Watering Can", wateringCans, "wateringCanTargets")
        CreateSlider(farmContent, "Per-Plant Delay (s)", 0, 2, "perFruitDelay")
        CreateSlider(farmContent, "Water Loop Delay (s)", 1, 60, "harvestLoopDelay")

        -- AUTO SPRINKLER
        CreateSubHeader(farmContent, " Auto Sprinkler")
        
        local sprinklerList = {}
        for _, g in ipairs(GEARS) do
            local gl = g:lower()
            if gl:find("sprinkler") then table.insert(sprinklerList, g) end
        end

        CreateToggle(farmContent, "Auto Place Sprinklers", "autoSprinkler",
            "Automatically places sprinklers on areas that don't have one yet",
            function(newVal, revert)
                if newVal and #(States.sprinklerTargets or {}) == 0 then
                    revert()
                    Notify("Auto Sprinkler", " Select a Sprinkler below before enabling!", Colors.Warning, 5)
                end
            end)
        CreateMultiSelect(farmContent, " Choose Sprinkler", sprinklerList, "sprinklerTargets")

        -- ═══════════════════════════════════════════════════════════
        -- Section 2:  Shopping
        -- ═══════════════════════════════════════════════════════════
        local _, shopContent = CreateSectionCard(" Shopping", 2, Colors.Electric)

        -- AUTO BUY SEEDS
        CreateSubHeader(shopContent, " Auto Buy Seeds")
        
        local lastNoTargetSeed = { [1] = 0 }
        local msSeedControl    = { SetDisabled = nil }

        local _, _, setAutoBuyVisual = CreateToggle(shopContent, "Auto Buy Seeds", "autoBuySeed",
            "Rapidly buys selected seeds, stops when out of stock",
            function(newVal, revert)
                if newVal and not States.autoBuyAll and #(States.autoBuySeedTargets or {}) == 0 then
                    revert()
                    notifyIfCooled(lastNoTargetSeed, "Auto Buy",
                        " Select seeds below before enabling Auto Buy!", Colors.Warning)
                    return
                end
                if newVal then
                    pcall(function() Logic.ResetNotifiedEmpty() end)
                    pcall(MuteSFX_Failed)
                end
            end)

        local forceOffAutoBuy = makeForceOff("autoBuySeed", setAutoBuyVisual)

        CreateToggle(shopContent, "Buy All available seeds", "autoBuyAll",
            "ON: buys every seed that has stock | OFF: only selected seeds",
            function(newVal)
                pcall(function() Logic.ResetNotifiedEmpty() end)
                if msSeedControl.SetDisabled then
                    pcall(function() msSeedControl.SetDisabled(newVal) end)
                end
                if not newVal and #(States.autoBuySeedTargets or {}) == 0 and States.autoBuySeed then
                    forceOffAutoBuy()
                    Notify("Auto Buy", "Buy ALL disabled & no seeds selected — Auto Buy Seeds disabled.", Colors.Warning, 5)
                end
            end)

        setupMultiSelectGuard(
            shopContent, "Choose Target Seeds", SEEDS,
            "autoBuySeedTargets", "autoBuySeed", "autoBuyAll",
            msSeedControl, forceOffAutoBuy, "Auto Buy Seeds",
            function() pcall(function() Logic.ResetNotifiedEmpty() end) end
        )
        CreateToggle(shopContent, "Notify on Purchase", "notifyBuy", "Show a notification each time a seed is bought")

        -- AUTO BUY GEAR
        CreateSubHeader(shopContent, " Auto Buy Gear")
        
        local lastNoTargetGear = { [1] = 0 }
        local msGearControl    = { SetDisabled = nil }

        local _, _, setAutoBuyGearVisual = CreateToggle(shopContent, "Auto Buy Gear", "autoBuyGear",
            "Rapidly buys selected gear, stops when out of stock",
            function(newVal, revert)
                if newVal and not States.autoBuyGearAll and #(States.autoBuyGearTargets or {}) == 0 then
                    revert()
                    notifyIfCooled(lastNoTargetGear, "Auto Buy Gear",
                        " Select gear below before enabling!", Colors.Warning)
                    return
                end
                if newVal then
                    pcall(function() Logic.ResetNotifiedEmptyGear() end)
                    pcall(MuteSFX_Failed)
                end
            end)

        local forceOffAutoBuyGear = makeForceOff("autoBuyGear", setAutoBuyGearVisual)

        CreateToggle(shopContent, "Buy All available gear", "autoBuyGearAll",
            "ON: buys every gear that has stock | OFF: only selected gear",
            function(newVal)
                pcall(function() Logic.ResetNotifiedEmptyGear() end)
                if msGearControl.SetDisabled then
                    pcall(function() msGearControl.SetDisabled(newVal) end)
                end
                if not newVal and #(States.autoBuyGearTargets or {}) == 0 and States.autoBuyGear then
                    forceOffAutoBuyGear()
                    Notify("Auto Buy Gear", "Buy ALL disabled & no gear selected — Auto Buy Gear disabled.", Colors.Warning, 5)
                end
            end)

        setupMultiSelectGuard(
            shopContent, "Choose Target Gear", GEARS,
            "autoBuyGearTargets", "autoBuyGear", "autoBuyGearAll",
            msGearControl, forceOffAutoBuyGear, "Auto Buy Gear",
            function() pcall(function() Logic.ResetNotifiedEmptyGear() end) end
        )
        CreateToggle(shopContent, "Notify on Purchase", "notifyBuyGear", "Show a notification each time a gear is bought")

        -- AUTO BUY CRATE
        CreateSubHeader(shopContent, " Auto Buy Crate")
        
        local lastNoTargetCrate = { [1] = 0 }
        local msCrateControl    = { SetDisabled = nil }

        local _, _, setAutoBuyCrateVisual = CreateToggle(shopContent, "Auto Buy Crate", "autoBuyCrate",
            "Rapidly buys selected crates, stops when out of stock",
            function(newVal, revert)
                if newVal and not States.autoBuyCrateAll and #(States.autoBuyCrateTargets or {}) == 0 then
                    revert()
                    notifyIfCooled(lastNoTargetCrate, "Auto Buy Crate",
                        " Select crates below before enabling!", Colors.Warning)
                    return
                end
                if newVal then
                    pcall(function() Logic.ResetNotifiedEmptyCrate() end)
                    pcall(MuteSFX_Failed)
                end
            end)

        local forceOffAutoBuyCrate = makeForceOff("autoBuyCrate", setAutoBuyCrateVisual)

        CreateToggle(shopContent, "Buy All available crates", "autoBuyCrateAll",
            "ON: buys every crate that has stock | OFF: only selected crates",
            function(newVal)
                pcall(function() Logic.ResetNotifiedEmptyCrate() end)
                if msCrateControl.SetDisabled then
                    pcall(function() msCrateControl.SetDisabled(newVal) end)
                end
                if not newVal and #(States.autoBuyCrateTargets or {}) == 0 and States.autoBuyCrate then
                    forceOffAutoBuyCrate()
                    Notify("Auto Buy Crate", "Buy ALL disabled & no crates selected — Auto Buy Crate disabled.", Colors.Warning, 5)
                end
            end)

        setupMultiSelectGuard(
            shopContent, "Choose Target Crates", CRATES,
            "autoBuyCrateTargets", "autoBuyCrate", "autoBuyCrateAll",
            msCrateControl, forceOffAutoBuyCrate, "Auto Buy Crate",
            function() pcall(function() Logic.ResetNotifiedEmptyCrate() end) end
        )
        CreateToggle(shopContent, "Notify on Purchase", "notifyBuyCrate", "Show a notification each time a crate is bought")

        -- AUTO OPEN CRATE
        CreateSubHeader(shopContent, " Auto Open Crate")
        CreateToggle(shopContent, "Auto Open Crate", "autoOpenCrate", "Automatically opens all crates in your backpack")
        CreateSlider(shopContent, "Delay Between Opens (s)", 1, 30, "crateOpenDelay")
        CreateToggle(shopContent, "Notify on Open", "notifyOpenCrate", "Show what item you received when a crate is opened")

        -- ═══════════════════════════════════════════════════════════
        -- Section 3:  Selling
        -- ═══════════════════════════════════════════════════════════
        local _, sellContent = CreateSectionCard(" Selling", 3, Colors.Gold)
        
        local netStatus = Networking
            and "Sell system ready."
            or "Sell system unavailable — reload the hub if this persists."
        CreateInfoText(sellContent, "How It Works",
            netStatus .. "\nAuto Sell continuously sells all fruits in your backpack. Use filters below to keep specific mutations.")
        CreateToggle(sellContent, "Auto Sell Fruits", "autoSell", "Continuously sells all fruits in your backpack automatically")
        CreateToggle(sellContent, "Keep Mutated Fruits", "keepMutations", "Skip all fruits that have any mutation")
        CreateMultiSelect(sellContent, "Keep Specific Mutations", MUTATIONS, "sellKeepMutation")
        CreateSlider(sellContent, "Delay Between Sells (s)", 0, 3, "sellDelay")
        CreateSlider(sellContent, "Loop Delay (s)", 1, 60, "sellLoopDelay")
        CreateToggle(sellContent, "Notify on Sell", "notifySell", "Show a notification with sell totals after each cycle")

        -- ═══════════════════════════════════════════════════════════
        -- Section 4:  Pets
        -- ═══════════════════════════════════════════════════════════
        local _, petContent = CreateSectionCard(" Pets", 4, Colors.Frozen)
        
        local WILD_PET_NAMES = {
            "__SIZE_Big", "__SIZE_Huge", "__SIZE_Giant",
            "__TYPE_Rainbow",
            "Frog", "Bunny", "Owl", "Deer", "Turtle", "Robin", "Bee",
            "Monkey", "Bear", "Unicorn", "Golden Dragonfly",
            "Firefly", "Bald Eagle",
            "Raccoon",
        }
        local WILD_PET_DISPLAY = {
            __SIZE_Big     = " All Big",
            __SIZE_Huge    = " All Huge",
            __SIZE_Giant   = " All Giant",
            __TYPE_Rainbow = " All Rainbow",
        }
        CreateMultiSelect(petContent, "Choose Target Pets", WILD_PET_NAMES, "wildCatchTargets", WILD_PET_DISPLAY)
        CreateToggle(petContent, "Auto Catch Wild Pets", "autoCatchWild",
            "ON: keeps running, chasing any matching pet that spawns | OFF: stops the loop",
            function(newVal)
                if newVal then
                    local sel = States.wildCatchTargets or {}
                    if #sel == 0 then
                        Notify("Auto Catch", "ON — chasing all wild pets", Colors.Success, 3)
                    else
                        Notify("Auto Catch", "ON — targeting: " .. table.concat(sel, ", "), Colors.Success, 3)
                    end
                else
                    Notify("Auto Catch", "OFF", Colors.TextMuted, 2)
                end
            end)

        -- ═══════════════════════════════════════════════════════════
        -- Section 5:  Utilities
        -- ═══════════════════════════════════════════════════════════
        local _, utilContent = CreateSectionCard(" Utilities", 5, Colors.Rainbow)
        
        CreateToggle(utilContent, "Auto Accept Gifts", "autoAcceptGifts", "Automatically checks your mailbox every 10 seconds")
        CreateToggle(utilContent, "Auto Rejoin on Disconnect", "autoRejoin", "Rejoins automatically when kicked/disconnected")

    end)

    -- ====================== PAGE 2: INVENTORY ======================
    ctx.registerPage("Inventory", function()
        
        -- Cache Logic references used only on this page
        local ScanWildPets      = Logic.ScanWildPets
        local HumanizePetName   = Logic.HumanizePetName
        local RarityColor       = Logic.RarityColor
        local PET_RARITY_LOOKUP = Logic.PET_RARITY_LOOKUP
        local SmartMoveToPet    = Logic.SmartMoveToPet
        local BuyWildPet        = Logic.BuyWildPet
        local IsWildPetFree     = Logic.IsWildPetFree

        local rarityOrd = { Super = 6, Mythic = 5, Legendary = 4, Rare = 3, Uncommon = 2, Common = 1 }
        local sizeOrd   = { Huge = 3, Big = 2, Normal = 1 }

        -- ═══════════════════════════════════════════════════════════
        -- Section 1:  Backpack Overview
        -- ═══════════════════════════════════════════════════════════
        local _, bagContent = CreateSectionCard(" Backpack", 1, Colors.Accent)
        
        local _, fruitLbl  = CreateStatRow(bagContent, "Harvested Fruits in Bag", "?", Colors.Warning)
        local _, seedLbl   = CreateStatRow(bagContent, "Seeds in Bag", "?", Colors.Success)
        local _, petCntLbl = CreateStatRow(bagContent, "Pets in Bag", "?", Colors.Frozen)
        local _, capLbl    = CreateStatRow(bagContent, "Capacity", "? / " .. MAX_FRUIT_CAP, Colors.Accent)
        
        task.spawn(function()
            while GetActivePage() == "Inventory" do
                task.wait(0.5)
                if GetActivePage() ~= "Inventory" then break end
                local fruits, seeds, pets = 0, 0, 0
                for _, t in ipairs(player.Backpack:GetChildren()) do
                    if     t:GetAttribute("HarvestedFruit") then fruits = fruits + 1
                    elseif t:GetAttribute("SeedTool") or t:GetAttribute("SeedName") then seeds = seeds + 1
                    elseif t:GetAttribute("Pet") then pets = pets + 1
                    end
                end
                fruitLbl.Text  = tostring(fruits)
                seedLbl.Text   = tostring(seeds)
                petCntLbl.Text = tostring(pets)
                capLbl.Text    = fruits .. " / " .. tostring(player:GetAttribute("MaxFruitCapacity") or MAX_FRUIT_CAP)
            end
        end)

        CreateActionButton(bagContent, " List All Fruits in Bag", function()
            local items = {}
            for _, t in ipairs(player.Backpack:GetChildren()) do
                local fn = t:GetAttribute("FruitName")
                if fn then
                    local mut = GetMutation(t)
                    local sm  = t:GetAttribute("SizeMultiplier") or 1
                    local entry = fn
                    if mut ~= "" and mut ~= "None" then entry = "[" .. mut .. "] " .. entry end
                    entry = entry .. " x" .. string.format("%.2f", sm)
                    table.insert(items, entry)
                end
            end
            if #items == 0 then
                Notify("Bag", "No fruits in backpack.", Colors.TextMuted)
            else
                Notify("Bag (" .. #items .. " fruits)", table.concat(items, ", "):sub(1, 150), Colors.Accent, 7)
            end
        end)

        CreateActionButton(bagContent, " Scan Crates in Backpack", function()
            local cratesInBag = GetCratesInInventory()
            if #cratesInBag == 0 then
                Notify("Scan Crates", "No crates found in backpack.", Colors.TextMuted)
                return
            end
            local names = {}
            for _, entry in ipairs(cratesInBag) do table.insert(names, entry.name) end
            Notify("Crates in Bag (" .. #cratesInBag .. ")", table.concat(names, ", "):sub(1, 150), Colors.Warning, 6)
        end)

        CreateActionButton(bagContent, " Inspect Held Item", function()
            local ct = player.Character and player.Character:FindFirstChildWhichIsA("Tool")
            if ct then
                local weight = ct:GetAttribute("Weight")
                local mut    = GetMutation(ct)
                local sm     = ct:GetAttribute("SizeMultiplier")
                local decay  = ct:GetAttribute("DecayAlpha")
                local fn     = ct:GetAttribute("FruitName") or ct:GetAttribute("Fruit") or ct.Name
                if weight then
                    Notify("Inspect: " .. fn,
                        string.format("Wt:%.2fkg | Mut:%s | x%.2f size | Decay:%.4f", weight, mut, sm or 1, decay or 0),
                        GetMutationColor(mut), 6)
                else
                    local seedName = ct:GetAttribute("SeedTool") or ct:GetAttribute("SeedName")
                    if seedName then
                        Notify("Inspect: Seed", "Type: " .. seedName, Colors.Success)
                    else
                        Notify("Inspect", ct.Name .. " — not a fruit or seed.", Colors.TextMuted)
                    end
                end
            else
                Notify("Inspect", "Not holding anything.", Colors.TextMuted)
            end
        end, Colors.Gold)

        -- ═══════════════════════════════════════════════════════════
        -- Section 2:  Pet Inventory
        -- ═══════════════════════════════════════════════════════════
        local _, petContent = CreateSectionCard(" Pet Inventory", 2, Colors.Frozen)
        local listArea = Create("Frame", {
            Parent              = petContent,
            Size                = UDim2.new(1, 0, 0, 0),
            AutomaticSize       = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
        })
        CreateListLayout(listArea, 6)

        local ROW_H, ROW_GAP = 24, 4
        local petListExpanded = false  -- default collapsed

        local function RebuildInventory()
            if not listArea or not listArea.Parent then return end
            for _, c in ipairs(listArea:GetChildren()) do
                if not c:IsA("UIListLayout") then c:Destroy() end
            end

            local playerPets = {}
            for _, t in ipairs(player.Backpack:GetChildren()) do
                local petName = t:GetAttribute("Pet") or t:GetAttribute("PetSpecies")
                if petName then
                    table.insert(playerPets, {
                        name    = petName,
                        size    = t:GetAttribute("PetSize")  or "Normal",
                        petType = t:GetAttribute("PetType")  or "",
                    })
                end
            end
            table.sort(playerPets, function(a, b)
                local ra = rarityOrd[PET_RARITY_LOOKUP[a.name] or ""] or 0
                local rb = rarityOrd[PET_RARITY_LOOKUP[b.name] or ""] or 0
                if ra ~= rb then return ra > rb end
                return (sizeOrd[a.size] or 1) > (sizeOrd[b.size] or 1)
            end)

            local count = #playerPets

            -- Header row: label kiri + toggle button kanan
            local headerRow = Create("Frame", {
                Parent              = listArea,
                Size                = UDim2.new(1, 0, 0, 28),
                BackgroundTransparency = 1,
            })
            Create("TextLabel", {
                Parent                 = headerRow,
                Size                   = UDim2.new(1, -90, 1, 0),
                Position               = UDim2.new(0, 0, 0, 0),
                BackgroundTransparency = 1,
                Text                   = "Pets in Backpack (" .. count .. ")",
                TextColor3             = Colors.TextSecondary,
                TextSize               = 11,
                Font                   = Enum.Font.GothamBold,
                TextXAlignment         = Enum.TextXAlignment.Left,
            })

            if count == 0 then
                CreateInfoText(listArea, nil, "No pets in backpack.", Colors.TextMuted)
                return
            end

            -- Toggle button (ikutin style valLabel di slider: Colors.Background + Accent + BorderLight)
            local toggleBtn = Create("TextButton", {
                Parent                 = headerRow,
                Size                   = UDim2.new(0, 70, 0, 22),
                Position               = UDim2.new(1, -70, 0.5, -11),
                BackgroundColor3       = Colors.BackgroundLighter,
                BackgroundTransparency = 0,
                BorderSizePixel        = 0,
                Text                   = petListExpanded and "Hide ▲" or "Show ▼",
                TextColor3             = Colors.Accent,
                TextSize               = 12,
                Font                   = Enum.Font.Gotham,
                AutoButtonColor        = false,
            })
            CreateCorner(toggleBtn, 5)
            CreateStroke(toggleBtn, Colors.BorderLight, 1)

            -- Frame konten pet (flat, tanpa nested scroll)
            local petListFrame = Create("Frame", {
                Parent              = listArea,
                Size                = UDim2.new(1, 0, 0, 0),
                AutomaticSize       = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Visible             = petListExpanded,
            })
            CreateListLayout(petListFrame, ROW_GAP)

            for i, pet in ipairs(playerPets) do
                local rarity    = PET_RARITY_LOOKUP[pet.name] or "Unknown"
                local rarityCol = RarityColor[rarity] or Colors.TextSecondary
                local valStr    = rarity
                if pet.size ~= "Normal" then valStr = rarity .. " (" .. pet.size .. ")" end
                local displayName = (pet.petType == "Rainbow" and " " or "") .. pet.name
                CreateStatRow(petListFrame, i .. ". " .. displayName, valStr, rarityCol)
            end

            toggleBtn.MouseButton1Click:Connect(function()
                petListExpanded = not petListExpanded
                petListFrame.Visible = petListExpanded
                toggleBtn.Text = petListExpanded and "Hide ▲" or "Show ▼"
            end)
            toggleBtn.MouseEnter:Connect(function() Tween(toggleBtn, { BackgroundColor3 = Colors.Surface }, 0.1) end)
            toggleBtn.MouseLeave:Connect(function() Tween(toggleBtn, { BackgroundColor3 = Colors.BackgroundLighter }, 0.1) end)
        end

        RebuildInventory()
        player.Backpack.ChildAdded:Connect(function(child)
            if child:GetAttribute("Pet") or child:GetAttribute("PetSpecies") then task.defer(RebuildInventory) end
        end)
        player.Backpack.ChildRemoved:Connect(function(child)
            if child:GetAttribute("Pet") or child:GetAttribute("PetSpecies") then task.defer(RebuildInventory) end
        end)

        -- ═══════════════════════════════════════════════════════════
        -- Section 3:  Pet Finder
        -- ═══════════════════════════════════════════════════════════
        local _, finderContent = CreateSectionCard(" Pet Finder", 3, Colors.Warning)
        local listContainer = Create("Frame", {
            Parent              = finderContent,
            Size                = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            AutomaticSize       = Enum.AutomaticSize.Y,
        })
        CreateListLayout(listContainer, 4)

        local function RebuildPetList()
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
                local col     = RarityColor[rarity] or Colors.TextSecondary
                local distStr = dist < math.huge and string.format("%.0f studs", dist) or "?"
                local petName = HumanizePetName(entry.name or "Unknown")

                local row = Create("Frame", {
                    Parent          = listContainer,
                    Size            = UDim2.new(1, 0, 0, 36),
                    BackgroundColor3 = Colors.BackgroundLighter,
                    BorderSizePixel = 0,
                })
                CreateCorner(row, 6)
                CreateStroke(row, col, 1)

                -- Layout kolom (semua pakai persen, total = 100%):
                --   [8px pad] [dot 4%] [name 36%] [rarity 26%] [dist 20%] [tp 14%] [8px pad]
                -- Bullet dot
                local bullet = Create("Frame", {
                    Parent          = row,
                    Size            = UDim2.new(0, 6, 0, 6),
                    Position        = UDim2.new(0.01, 4, 0.5, -3),
                    BackgroundColor3 = col,
                    BorderSizePixel = 0,
                })
                CreateCorner(bullet, 3)

                -- Pet name: mulai setelah dot (~6% dari kiri), lebar 36%
                Create("TextLabel", {
                    Parent                 = row,
                    Size                   = UDim2.new(0.36, 0, 1, 0),
                    Position               = UDim2.new(0.06, 0, 0, 0),
                    BackgroundTransparency = 1,
                    Text                   = petName,
                    TextColor3             = col,
                    TextSize               = 11,
                    Font                   = Enum.Font.GothamBold,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    TextTruncate           = Enum.TextTruncate.AtEnd,
                })

                -- Rarity: zona 42%-64% (22% lebar), center di tengah zona
                -- Ruang tengah antara nama(42%) dan TP(86%) = 44%, dibagi 2 = masing2 22%
                Create("TextLabel", {
                    Parent                 = row,
                    Size                   = UDim2.new(0.22, 0, 1, 0),
                    Position               = UDim2.new(0.42, 0, 0, 0),
                    BackgroundTransparency = 1,
                    Text                   = rarity,
                    TextColor3             = col,
                    TextSize               = 10,
                    Font                   = Enum.Font.Gotham,
                    TextXAlignment         = Enum.TextXAlignment.Center,
                })

                -- Distance: zona 64%-86% (22% lebar), center di tengah zona
                Create("TextLabel", {
                    Parent                 = row,
                    Size                   = UDim2.new(0.22, 0, 1, 0),
                    Position               = UDim2.new(0.64, 0, 0, 0),
                    BackgroundTransparency = 1,
                    Text                   = distStr,
                    TextColor3             = Colors.TextMuted,
                    TextSize               = 10,
                    Font                   = Enum.Font.Gotham,
                    TextXAlignment         = Enum.TextXAlignment.Center,
                })

                -- TP button: 14% lebar dari kanan, dengan sedikit padding
                local tpBtn = Create("TextButton", {
                    Parent          = row,
                    Size            = UDim2.new(0.14, -4, 0, 22),
                    Position        = UDim2.new(0.86, 2, 0.5, -11),
                    BackgroundColor3 = Colors.Surface,
                    Text            = "TP →",
                    TextColor3      = col,
                    TextSize        = 11,
                    Font            = Enum.Font.GothamBold,
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                })
                CreateCorner(tpBtn, 6)
                tpBtn.MouseEnter:Connect(function() Tween(tpBtn, { BackgroundColor3 = Colors.SurfaceLight }, 0.1) end)
                tpBtn.MouseLeave:Connect(function() Tween(tpBtn, { BackgroundColor3 = Colors.Surface }, 0.1) end)
                tpBtn.MouseButton1Click:Connect(function()
                    if not part or not part.Parent then
                        Notify("Pet Finder", "That pet has already disappeared!", Colors.Error)
                        RebuildPetList()
                        return
                    end
                    if not player.Character then return end
                    Notify("Pet Finder", "Moving → " .. petName .. " (" .. rarity .. ")", col, 3)
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
        local finderConn
        finderConn = RunService.Heartbeat:Connect(function()
            if GetActivePage() ~= "Inventory" then
                finderPageAlive = false
                finderConn:Disconnect()
            end
        end)

        task.spawn(function()
            while finderPageAlive and _G._MiracleHubSession == SESSION do
                task.wait(2)
                if finderPageAlive and GetActivePage() == "Inventory" then
                    pcall(RebuildPetList)
                end
            end
        end)

        CreateActionButton(finderContent, " TP to Nearest Pet", function()
            local pets = ScanWildPets("All")
            if #pets == 0 then Notify("Pet Finder", "No pets available right now.", Colors.Error) return end
            local nearest = pets[1]
            local pName   = HumanizePetName(nearest.name or "Unknown")
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

        -- ═══════════════════════════════════════════════════════════
        -- Section 4:  Selling Tools
        -- ═══════════════════════════════════════════════════════════
        local _, sellToolsContent = CreateSectionCard(" Selling", 4, Colors.Gold)

        CreateActionButton(sellToolsContent, " Preview Inventory Value", function()
            if not Networking then Notify("Preview", "Sell system unavailable!", Colors.Error) return end
            local ok, data = pcall(function() return Networking.NPCS.PreviewSellAll:Fire() end)
            if ok and data and data.FruitCount then
                local ddOk, ddData = pcall(function() return Networking.NPCS.CheckDailyDeal:Fire() end)
                local ddAvail = ddOk and ddData and ddData.Available
                local msg = data.FruitCount .. " fruits | Normal: " .. tostring(data.TotalValue or 0) .. "¢"
                if ddAvail then
                    local ddPrice = math.max(1, math.floor((data.TotalBaseValue or data.TotalValue or 0) * 5))
                    msg = msg .. " | Daily Deal: " .. tostring(ddPrice) .. "¢ (5x!) "
                end
                Notify("Preview Sell", msg, Colors.Gold, 6)
            else
                Notify("Preview Sell", "No fruits in backpack.", Colors.TextMuted)
            end
        end)

        CreateActionButton(sellToolsContent, " Sell All Now", function()
            if not Networking then Notify("Sell", "Sell system unavailable! Try reloading the hub.", Colors.Error) return end
            local ok, result = pcall(function() return Networking.NPCS.SellAll:Fire() end)
            if ok and result and result.Success then
                Notify("Sell", "Sold " .. (result.SoldCount or "?") .. " fruits = " .. tostring(result.SellPrice or 0) .. "¢", Colors.Gold, 10)
            else
                Notify("Sell", "Failed: " .. tostring(result and result.Reason or "Networking error"), Colors.Error)
            end
        end, Colors.Gold)

        CreateActionButton(sellToolsContent, " Sell with Filters", function()
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
            
    end)

    -- ====================== PAGE 3: SHOW ======================
    ctx.registerPage("Show", function()
        
        -- ═══════════════════════════════════════════════════════════
        -- Section 1:  ESP
        -- ═══════════════════════════════════════════════════════════
        local _, espContent = CreateSectionCard(" ESP", 1, Colors.Electric)
        
        CreateToggle(espContent, "ESP Players", "espPlayers", "Shows player names/tags above heads")
        CreateToggle(espContent, "ESP Wild Pets", "espItems", "Highlights wild pets in workspace")
        CreateToggle(espContent, "ESP Fruits", "espFruits", "Highlights harvestable fruits on the plot")

        -- ═══════════════════════════════════════════════════════════
        -- Section 2:  Live Stats
        -- ═══════════════════════════════════════════════════════════
        local _, statsContent = CreateSectionCard(" Live Stats", 2, Colors.Accent)
        
        local _, hpLbl = CreateStatRow(statsContent, "Health", "100 / 100", Colors.Success)
        local _, wsLbl = CreateStatRow(statsContent, "WalkSpeed", tostring(ctx.humanoid and ctx.humanoid.WalkSpeed or "?"), Colors.Accent)
        local _, jpLbl = CreateStatRow(statsContent, "JumpPower", tostring(ctx.humanoid and ctx.humanoid.JumpPower or "?"), Colors.Accent)
        CreateStatRow(statsContent, "Plot ID", MY_PLOT_ID, Colors.Warning)
        local _, bpLbl = CreateStatRow(statsContent, "Backpack Items", #player.Backpack:GetChildren(), Colors.TextSecondary)

        task.spawn(function()
            local bpTick = 0
            while GetActivePage() == "Show" do
                local dt = task.wait()
                if not ctx.humanoid then continue end
                hpLbl.Text = math.floor(ctx.humanoid.Health) .. " / " .. ctx.humanoid.MaxHealth
                wsLbl.Text = string.format("%.1f", ctx.humanoid.WalkSpeed)
                jpLbl.Text = string.format("%.1f", ctx.humanoid.JumpPower)
                bpTick = bpTick + dt
                if bpTick >= 0.5 then
                    bpTick = 0
                    bpLbl.Text = tostring(#player.Backpack:GetChildren())
                end
            end
        end)

        -- ═══════════════════════════════════════════════════════════
        -- Section 3:  Graphics
        -- ═══════════════════════════════════════════════════════════
        local _, graphicsContent = CreateSectionCard(" Graphics", 3, Colors.Warning)
        
        CreateActionButton(graphicsContent, "Ultra Low Graphics (Permanent until rejoin)", function()
            if ctx.UltraLow and ctx.UltraLow.Active then
                Notify("Ultra Low", "Already active. Rejoin to reset.", Colors.Warning)
                return
            end
            if not ctx.UltraLow then
                Notify("Ultra Low", "Ultra Low module not found.", Colors.Error)
                return
            end
            Notify("Ultra Low", "Applying... Don't close the hub.", Colors.Warning, 3)
            task.spawn(function() ctx.UltraLow.Apply() end)
        end)
        
    end)

    -- ====================== PAGE 4: MISC ======================
    ctx.registerPage("Misc", function()
        
        -- ═══════════════════════════════════════════════════════════
        -- Section 1:  Movement
        -- ═══════════════════════════════════════════════════════════
        local _, moveContent = CreateSectionCard(" Movement", 1, Colors.Electric)
        
        CreateToggle(moveContent, "Lock WalkSpeed", "lockWalkSpeed")
        CreateSlider(moveContent, "WalkSpeed", 1, 500, "walkSpeed")
        CreateToggle(moveContent, "Lock JumpPower", "lockJumpPower")
        CreateSlider(moveContent, "JumpPower", 1, 500, "jumpPower")
        CreateToggle(moveContent, "Infinite Jump", "infiniteJump")

        -- ═══════════════════════════════════════════════════════════
        -- Section 2:  Fly
        -- ═══════════════════════════════════════════════════════════
        local _, flyContent = CreateSectionCard(" Fly", 2, Colors.TextSecondary)
        
        CreateInfoText(flyContent, "Controls", "[F] Toggle Fly | [W/A/S/D] Move | [Space] Up | [Ctrl] Down")

        local _, _, setFlyVisual = CreateToggle(flyContent, "Fly", "fly",
            "Hold WASD to fly, Space=up, Ctrl=down",
            function(state)
                if ctx.ToggleFly then
                    ctx.ToggleFly(state)
                else
                    Notify("Misc", "Fly " .. (state and "ON" or "OFF"), state and Colors.Success or Colors.TextMuted)
                end
            end)

        ctx._setFlyVisual = setFlyVisual
        CreateSlider(flyContent, "Fly Speed", 1, 300, "flySpeed")

        -- ═══════════════════════════════════════════════════════════
        -- Section 3:  Mailbox
        -- ═══════════════════════════════════════════════════════════
        local _, mailContent = CreateSectionCard(" Mailbox", 3, Colors.Rainbow)
        
        CreateActionButton(mailContent, "Check Mailbox Now", function()
            local plot = GetMyPlot()
            if not plot then Notify("Mailbox", "Your plot was not found!", Colors.Error) return end
            local signs   = plot:FindFirstChild("Signs")
            local mailbox = signs and signs:FindFirstChild("GreyMailBox")
            if not mailbox then Notify("Mailbox", "Mailbox not found on your plot.", Colors.Error) return end
            local found = false
            for _, desc in ipairs(mailbox:GetDescendants()) do
                if desc:IsA("ProximityPrompt") and desc.Name == "MailboxPrompt" then
                    SafeFirePrompt(desc)
                    found = true
                    break
                end
            end
            Notify("Mailbox",
                found and "Mailbox checked on Plot " .. MY_PLOT_ID or "Mailbox could not be opened.",
                found and Colors.Rainbow or Colors.Error)
        end, Colors.Rainbow)

        CreateActionButton(mailContent, "Show Bid Info (Held Item)", function()
            local ct = player.Character and player.Character:FindFirstChildWhichIsA("Tool")
            if ct then
                local bidPrice  = ct:GetAttribute("BidPrice")
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

        -- ═══════════════════════════════════════════════════════════
        -- Section 4:  Server Info
        -- ═══════════════════════════════════════════════════════════
        local PlayersService  = game:GetService("Players")
        local TeleportService = game:GetService("TeleportService")

        local _, serverContent = CreateSectionCard(" Server Info", 4, Colors.Accent)
        
        CreateStatRow(serverContent, "Job ID", game.JobId:sub(1, 20) .. "...", Colors.TextMuted)
        CreateStatRow(serverContent, "Place ID", tostring(game.PlaceId), Colors.TextMuted)
        local _, pcLbl = CreateStatRow(serverContent, "Players in Server", #PlayersService:GetPlayers(), Colors.Success)

        local playerPlotLabels = {}
        CreateSubHeader(serverContent, "Other Players")
        for _, p in ipairs(PlayersService:GetPlayers()) do
            if p ~= player then
                local _, pPlotLbl = CreateStatRow(serverContent,
                    p.DisplayName .. " (@" .. p.Name .. ")",
                    "Plot " .. (p:GetAttribute("PlotId") or "?"),
                    Colors.TextMuted)
                table.insert(playerPlotLabels, { p = p, lbl = pPlotLbl })
            end
        end

        task.spawn(function()
            while GetActivePage() == "Misc" do
                task.wait(1)
                if GetActivePage() ~= "Misc" then break end
                pcLbl.Text = tostring(#PlayersService:GetPlayers())
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
            TeleportService:Teleport(game.PlaceId, player)
        end, Colors.Warning)

        CreateActionButton(serverContent, "Copy Job ID", function()
            setclipboard(game.JobId)
            Notify("Server", "Job ID copied.", Colors.Accent)
        end)
        
    end)

    -- ====================== PAGE 5: SETTINGS ======================
    ctx.registerPage("Settings", function()
        local _, settContent = CreateSectionCard(" General Settings", 1, Colors.Accent)
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
            local RESET_STATES = {
                "autoPlant", "autoHarvest", "autoSell", "autoBuySeed", "autoBuyCrate",
                "autoOpenCrate", "autoCatchWild", "autoOpenEgg", "autoAcceptGifts", "fly",
                "espPlayers", "espItems", "espFruits",
            }
            for _, key in ipairs(RESET_STATES) do
                States[key] = false
            end
            Logic.ClearESP()
            Logic.ClearSfxMuteConn()
            pcall(function()
                local sfx = game:GetService("SoundService"):FindFirstChild("SFX")
                local failedSnd = sfx and sfx:FindFirstChild("Failed")
                if failedSnd then failedSnd.Volume = 1 end
            end)
            Notify("Settings", "All automation states reset to OFF.", Colors.Warning)
        end, Colors.Error)
    end)

    ctx.__pagesLoaded = true
    return ctx
end