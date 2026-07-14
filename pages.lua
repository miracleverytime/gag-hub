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
    local GetReadyFruitCount     = Logic.GetReadyFruitCount  -- referenced for clarity; used indirectly
    local GetMutation            = Logic.GetMutation
    local SafeFirePrompt         = Logic.SafeFirePrompt
    local MuteSFX_Failed         = Logic.MuteSFX_Failed
    local ShouldKeepFruit        = Logic.ShouldKeepFruit
    local GetCratesInInventory   = Logic.GetCratesInInventory

    local Networking = ctx.Networking

    -- =========================================================
    -- MODULE-LEVEL HELPERS
    -- =========================================================

    -- Rate-limiter for "no target selected" notifications.
    -- Each auto-feature gets its own last-notif timestamp so they don't
    -- interfere.  All share the same 5-second cooldown constant.
    local NO_TARGET_COOLDOWN = 5  -- seconds

    -- Returns true and fires a Notify if the cooldown has elapsed.
    -- `lastTimeRef` is a single-element table used as a mutable reference:
    --   { [1] = lastTime }
    local function notifyIfCooled(lastTimeRef, title, msg, color, duration)
        local now = os.clock()
        if now - lastTimeRef[1] >= NO_TARGET_COOLDOWN then
            lastTimeRef[1] = now
            Notify(title, msg, color, duration or 5)
        end
    end

    -- Builds a "ForceOff" closure for an auto-feature toggle.
    -- Writes the state key to false, persists it (if SaveState exists globally),
    -- and syncs the visual knob.
    local function makeForceOff(stateKey, setVisual)
        return function()
            States[stateKey] = false
            pcall(function() SaveState(stateKey, false) end)
            pcall(function() setVisual(false) end)
        end
    end

    -- Builds the standard MultiSelect + polling guard block used by Auto Buy Seeds,
    -- Gear, and Crate, and also by Auto Plant.
    --
    -- Parameters:
    --   parent        – Frame to parent the MultiSelect into
    --   label         – MultiSelect header label
    --   items         – list of selectable items
    --   targetsKey    – States key for the selection table   (e.g. "autoBuySeedTargets")
    --   activeKey     – States key for the "is running" bool (e.g. "autoBuySeed")
    --   allKey        – States key for "buy/plant all" bool  (e.g. "autoBuyAll")
    --   msControl     – { SetDisabled = nil } bridge table to fill
    --   forceOff      – the ForceOff closure for this feature
    --   notifyTitle   – string shown in the "disabled" notification
    --   onChangeCb    – optional extra callback when target count changes (may be nil)
    --   sessionRef    – the SESSION value captured at module load
    local function setupMultiSelectGuard(
        parent, label, items, targetsKey, activeKey, allKey,
        msControl, forceOff, notifyTitle, onChangeCb
    )
        local msResult = CreateMultiSelect(parent, label, items, targetsKey)
        msControl.SetDisabled = msResult.SetDisabled

        -- Apply initial disabled state if "All" was already ON at load time.
        if States[allKey] then
            task.defer(function()
                pcall(function() msControl.SetDisabled(true) end)
            end)
        end

        local prevCount = #(States[targetsKey] or {})
        task.spawn(function()
            -- Bug fix: previous loops used `while true do` with no session guard,
            -- meaning they leaked forever after the GUI was destroyed/reloaded.
            -- Now we check the SESSION sentinel so the loop stops on hub reload.
            while _G._MiracleHubSession == SESSION do
                task.wait(0.3)
                local cur = #(States[targetsKey] or {})
                if cur ~= prevCount then
                    prevCount = cur
                    if onChangeCb then pcall(onChangeCb) end
                end
                -- Safety guard: if feature is ON but has no coverage, force it off.
                if States[activeKey] and not States[allKey] and cur == 0 then
                    forceOff()
                    Notify(notifyTitle, "No items selected — " .. notifyTitle .. " disabled.", Colors.Warning, 4)
                end
            end
        end)
    end

    -- ====================== FARM PAGE ======================
    ctx.registerPage("Farm", function()
        local _, plantContent = CreateSectionCard("\240\159\140\177 Auto Plant", 1, Colors.Success)

        CreateInfoText(plantContent, "How It Works",
            "Automatically fills empty plot slots with seeds from your backpack. "
            .. "Select seeds below before enabling, or turn on 'Plant All' to skip selection."
        )

        local lastNoTargetPlant = { [1] = 0 }  -- mutable timestamp ref
        local msPlantControl    = { SetDisabled = nil }

        local _, _, setAutoPlantVisual = CreateToggle(plantContent, "Auto Plant", "autoPlant",
            "Fills empty plot slots. Needs at least one seed selected below (or enable Plant All).",
            function(newVal, revert)
                if newVal and not States.autoPlantAllSeeds then
                    if #(States.autoPlantTargets or {}) == 0 then
                        revert()
                        notifyIfCooled(lastNoTargetPlant, "Auto Plant",
                            "\226\154\160\239\184\143 Select seeds in 'Choose Seeds to Plant' before enabling Auto Plant!",
                            Colors.Warning)
                    end
                end
            end)

        local forceOffAutoPlant = makeForceOff("autoPlant", setAutoPlantVisual)

        CreateToggle(plantContent, "Plant All Seeds in Backpack", "autoPlantAllSeeds",
            "Plants all seeds in backpack, ignoring the selection below",
            function(newVal)
                if msPlantControl.SetDisabled then
                    pcall(function() msPlantControl.SetDisabled(newVal) end)
                end
            end)

        setupMultiSelectGuard(
            plantContent, " Choose Seeds to Plant", SEEDS,
            "autoPlantTargets", "autoPlant", "autoPlantAllSeeds",
            msPlantControl, forceOffAutoPlant, "Auto Plant", nil
        )

        CreateToggle(plantContent, "Notify on Plant Cycle", "autoPlantNotify",
            "Notifies you each time a planting cycle completes")

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

        -- Harvest card
        local _, harvestContent = CreateSectionCard("\240\159\141\133 Auto Harvest", 2, Colors.Warning)
        CreateToggle(harvestContent, "Auto Harvest", "autoHarvest", "Automatically harvest fruits on your plot")
        CreateToggle(harvestContent, "Notify After Harvest", "notifyHarvest", "Show a notification after each harvest cycle")
        CreateSubHeader(harvestContent, "Delay Settings")
        CreateSlider(harvestContent, "Per-Fruit Delay (s)", 0, 2, "perFruitDelay")
        CreateSlider(harvestContent, "Loop Delay (s)", 0, 30, "harvestLoopDelay")
        CreateSubHeader(harvestContent, "Mutation Filter")
        CreateMultiSelect(harvestContent, "\226\143\175\239\184\143Skip Mutation", MUTATIONS, "harvestFilterMutation")

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
                            table.insert(readyList, sn .. (mut ~= "" and " [" .. mut .. "]" or ""))
                        end
                    end
                end
            end
            local currentCount = player:GetAttribute("FruitCount") or 0
            local msg = #readyList .. "/" .. total .. " ready | Bag " .. currentCount .. "/" .. MAX_FRUIT_CAP
                .. "\n" .. table.concat(readyList, ", "):sub(1, 80)
            Notify("Fruit Scanner \240\159\148\141", msg, Colors.Success, 7)
        end)

        -- Watering & Sprinklers card
        local _, waterContent = CreateSectionCard("\240\159\146\167 Watering & Sprinklers", 3, Colors.Electric)

        -- Cache filtered gear lists once at page-build time rather than re-filtering each tick.
        local wateringCans, sprinklerList = {}, {}
        for _, g in ipairs(GEARS) do
            local gl = g:lower()
            if gl:find("watering")  then table.insert(wateringCans, g) end
            if gl:find("sprinkler") then table.insert(sprinklerList, g) end
        end

        CreateSubHeader(waterContent, "\240\159\146\167 Auto Water")
        CreateToggle(waterContent, "Auto Water Plants", "autoWater",
            "Automatically waters all plants on your plot using your selected watering can",
            function(newVal, revert)
                if newVal and #(States.wateringCanTargets or {}) == 0 then
                    revert()
                    Notify("Auto Water", "\226\154\160\239\184\143 Select a Watering Can below before enabling!", Colors.Warning, 5)
                end
            end)
        CreateMultiSelect(waterContent, "\240\159\170\163 Choose Watering Can", wateringCans, "wateringCanTargets")
        -- Bug: original used "notifyHarvest" and "perFruitDelay"/"harvestLoopDelay" for watering —
        -- these are intentionally shared state keys with harvest (per hub design). Preserved as-is.
        CreateToggle(waterContent, "Notify After Watering", "notifyHarvest",
            "Show a notification with how many plants were watered each cycle")
        CreateSlider(waterContent, "Per-Plant Delay (s)", 0, 2, "perFruitDelay")
        CreateSlider(waterContent, "Water Loop Delay (s)", 1, 60, "harvestLoopDelay")

        CreateSubHeader(waterContent, "\240\159\140\191 Auto Sprinkler")
        CreateToggle(waterContent, "Auto Place Sprinklers", "autoSprinkler",
            "Automatically places sprinklers on areas that don't have one yet",
            function(newVal, revert)
                if newVal and #(States.sprinklerTargets or {}) == 0 then
                    revert()
                    Notify("Auto Sprinkler", "\226\154\160\239\184\143 Select a Sprinkler below before enabling!", Colors.Warning, 5)
                end
            end)
        CreateMultiSelect(waterContent, "\240\159\140\191 Choose Sprinkler", sprinklerList, "sprinklerTargets")
    end)

    -- ====================== PLOT PAGE ======================
    ctx.registerPage("Plot", function()
        local _, plotContent = CreateSectionCard("\240\159\147\144 My Plot \226\128\148 Plot " .. MY_PLOT_ID, 1, Colors.Accent)

        local statsGrid = Create("Frame", {
            Parent            = plotContent,
            Size              = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            AutomaticSize     = Enum.AutomaticSize.Y,
        })
        CreateListLayout(statsGrid, 5)

        CreateStatRow(statsGrid, "My Plot ID",         MY_PLOT_ID,        Colors.Success)
        local _, fruitCntLbl   = CreateStatRow(statsGrid, "Fruit Count (Player Attr)",  player:GetAttribute("FruitCount") or "?", Colors.Warning)
        local _, maxFruitLbl   = CreateStatRow(statsGrid, "Max Fruit Capacity",          MAX_FRUIT_CAP,    Colors.Accent)
        local _, petSlotLbl    = CreateStatRow(statsGrid, "Max Equipped Pets",           MAX_EQUIPPED_PETS, Colors.Rainbow)
        local _, gardenLikesLbl = CreateStatRow(statsGrid, "Garden Likes",               player:GetAttribute("GardenLikes") or 0, Colors.Gold)
        local _, plantCntLbl   = CreateStatRow(statsGrid, "Plants on Plot",  "...", Colors.TextSecondary)
        local _, readyCntLbl   = CreateStatRow(statsGrid, "Ready to Harvest", "...", Colors.Success)

        -- Heartbeat connection kills the polling loop when the user leaves this page.
        -- Bug fix: original set plotPageAlive=false inside Heartbeat then kept the
        -- polling task alive for one more iteration; the guard order is now correct.
        local plotPageAlive = true
        local plotConn
        plotConn = RunService.Heartbeat:Connect(function()
            if GetActivePage() ~= "Plot" then
                plotPageAlive = false
                plotConn:Disconnect()
            end
        end)

        task.spawn(function()
            while plotPageAlive do
                task.wait(1)
                if not plotPageAlive then break end
                pcall(function()
                    fruitCntLbl.Text    = tostring(player:GetAttribute("FruitCount")         or "?")
                    maxFruitLbl.Text    = tostring(player:GetAttribute("MaxFruitCapacity")   or MAX_FRUIT_CAP)
                    petSlotLbl.Text     = tostring(player:GetAttribute("MaxEquippedPets")     or MAX_EQUIPPED_PETS)
                    gardenLikesLbl.Text = tostring(player:GetAttribute("GardenLikes")         or 0)
                    local myPlot = GetMyPlot()
                    if not myPlot then return end
                    -- Cache Plants folder reference for the duration of this tick.
                    local plantsF = myPlot:FindFirstChild("Plants")
                    local total, readyFruits = 0, 0
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
    end)

    -- ====================== SHOP PAGE ======================
    ctx.registerPage("Shop", function()

        -- ── Auto Buy Seeds ────────────────────────────────────────────────
        local _, buyContent = CreateSectionCard("\240\159\155\146 Auto Buy Seeds", 1, Colors.Success)

        local lastNoTargetSeed = { [1] = 0 }
        local msSeedControl    = { SetDisabled = nil }

        local _, _, setAutoBuyVisual = CreateToggle(buyContent, "Auto Buy Seeds", "autoBuySeed",
            "Rapidly buys selected seeds, stops when out of stock",
            function(newVal, revert)
                if newVal and not States.autoBuyAll and #(States.autoBuySeedTargets or {}) == 0 then
                    revert()
                    notifyIfCooled(lastNoTargetSeed, "Auto Buy",
                        "\226\154\160\239\184\143 Select seeds below before enabling Auto Buy!", Colors.Warning)
                    return
                end
                if newVal then
                    pcall(function() Logic.ResetNotifiedEmpty() end)
                    pcall(MuteSFX_Failed)
                end
            end)

        local forceOffAutoBuy = makeForceOff("autoBuySeed", setAutoBuyVisual)

        CreateToggle(buyContent, "Buy All available seeds", "autoBuyAll",
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
            buyContent, "\240\159\140\177Choose Target Seeds", SEEDS,
            "autoBuySeedTargets", "autoBuySeed", "autoBuyAll",
            msSeedControl, forceOffAutoBuy, "Auto Buy Seeds",
            function() pcall(function() Logic.ResetNotifiedEmpty() end) end
        )
        CreateToggle(buyContent, "Notify on Purchase", "notifyBuy", "Show a notification each time a seed is bought")

        -- ── Auto Buy Gear ─────────────────────────────────────────────────
        local _, gearContent = CreateSectionCard("\226\154\153\239\184\143 Auto Buy Gear", 2, Colors.Electric)

        local lastNoTargetGear = { [1] = 0 }
        local msGearControl    = { SetDisabled = nil }

        local _, _, setAutoBuyGearVisual = CreateToggle(gearContent, "Auto Buy Gear", "autoBuyGear",
            "Rapidly buys selected gear, stops when out of stock",
            function(newVal, revert)
                if newVal and not States.autoBuyGearAll and #(States.autoBuyGearTargets or {}) == 0 then
                    revert()
                    notifyIfCooled(lastNoTargetGear, "Auto Buy Gear",
                        "\226\154\160\239\184\143 Select gear below before enabling!", Colors.Warning)
                    return
                end
                if newVal then
                    pcall(function() Logic.ResetNotifiedEmptyGear() end)
                    pcall(MuteSFX_Failed)
                end
            end)

        local forceOffAutoBuyGear = makeForceOff("autoBuyGear", setAutoBuyGearVisual)

        CreateToggle(gearContent, "Buy All available gear", "autoBuyGearAll",
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
            gearContent, "\226\154\153\239\184\143Choose Target Gear", GEARS,
            "autoBuyGearTargets", "autoBuyGear", "autoBuyGearAll",
            msGearControl, forceOffAutoBuyGear, "Auto Buy Gear",
            function() pcall(function() Logic.ResetNotifiedEmptyGear() end) end
        )
        CreateToggle(gearContent, "Notify on Purchase", "notifyBuyGear", "Show a notification each time a gear is bought")

        -- ── Auto Buy Crate ────────────────────────────────────────────────
        local _, crateContent = CreateSectionCard("\240\159\147\166 Auto Buy Crate", 3, Colors.Warning)

        local lastNoTargetCrate = { [1] = 0 }
        local msCrateControl    = { SetDisabled = nil }

        local _, _, setAutoBuyCrateVisual = CreateToggle(crateContent, "Auto Buy Crate", "autoBuyCrate",
            "Rapidly buys selected crates, stops when out of stock",
            function(newVal, revert)
                if newVal and not States.autoBuyCrateAll and #(States.autoBuyCrateTargets or {}) == 0 then
                    revert()
                    notifyIfCooled(lastNoTargetCrate, "Auto Buy Crate",
                        "\226\154\160\239\184\143 Select crates below before enabling!", Colors.Warning)
                    return
                end
                if newVal then
                    pcall(function() Logic.ResetNotifiedEmptyCrate() end)
                    pcall(MuteSFX_Failed)
                end
            end)

        local forceOffAutoBuyCrate = makeForceOff("autoBuyCrate", setAutoBuyCrateVisual)

        CreateToggle(crateContent, "Buy All available crates", "autoBuyCrateAll",
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
            crateContent, "\240\159\147\166Choose Target Crates", CRATES,
            "autoBuyCrateTargets", "autoBuyCrate", "autoBuyCrateAll",
            msCrateControl, forceOffAutoBuyCrate, "Auto Buy Crate",
            function() pcall(function() Logic.ResetNotifiedEmptyCrate() end) end
        )
        CreateToggle(crateContent, "Notify on Purchase", "notifyBuyCrate", "Show a notification each time a crate is bought")

        -- ── Auto Open Crate ───────────────────────────────────────────────
        local _, openCrateContent = CreateSectionCard("\240\159\142\129 Auto Open Crate", 4, Colors.Gold)
        CreateToggle(openCrateContent, "Auto Open Crate", "autoOpenCrate", "Automatically opens all crates in your backpack")
        CreateSlider(openCrateContent, "Delay Between Opens (s)", 1, 30, "crateOpenDelay")
        CreateToggle(openCrateContent, "Notify on Open", "notifyOpenCrate", "Show what item you received when a crate is opened")
        CreateActionButton(openCrateContent, "Scan Crates in Backpack", function()
            local cratesInBag = GetCratesInInventory()
            if #cratesInBag == 0 then Notify("Scan Crates", "No crates found in backpack.", Colors.TextMuted) return end
            local names = {}
            for _, entry in ipairs(cratesInBag) do table.insert(names, entry.name) end
            Notify("Crates in Bag (" .. #cratesInBag .. ")", table.concat(names, ", "):sub(1, 150), Colors.Warning, 6)
        end)
    end)

    -- ====================== SELL PAGE ======================
    ctx.registerPage("Sell", function()
        local _, sellContent = CreateSectionCard("\240\159\146\176 Auto Sell", 1, Colors.Gold)
        local netStatus = Networking
            and "Sell system ready."
            or "Sell system unavailable \226\128\148 reload the hub if this persists."
        CreateInfoText(sellContent, "How It Works",
            netStatus .. "\nAuto Sell continuously sells all fruits in your backpack. Use filters below to keep specific mutations.")
        CreateToggle(sellContent, "Auto Sell Fruits",        "autoSell",         "Continuously sells all fruits in your backpack automatically")
        CreateToggle(sellContent, "Keep Mutated Fruits",     "keepMutations",    "Skip all fruits that have any mutation")
        CreateMultiSelect(sellContent, "\240\159\148\128Keep Specific Mutations", MUTATIONS, "sellKeepMutation")
        CreateSlider(sellContent, "Delay Between Sells (s)", 0, 3,  "sellDelay")
        CreateSlider(sellContent, "Loop Delay (s)",          1, 60, "sellLoopDelay")
        CreateToggle(sellContent, "Notify on Sell", "notifySell", "Show a notification with sell totals after each cycle")

        CreateActionButton(sellContent, "\240\159\148\141 Preview Inventory Value", function()
            if not Networking then Notify("Preview", "Sell system unavailable!", Colors.Error) return end
            local ok, data = pcall(function() return Networking.NPCS.PreviewSellAll:Fire() end)
            if ok and data and data.FruitCount then
                local ddOk, ddData = pcall(function() return Networking.NPCS.CheckDailyDeal:Fire() end)
                local ddAvail = ddOk and ddData and ddData.Available
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

        -- Bag Inspector card
        local _, bagContent = CreateSectionCard("\240\159\142\146 Bag Inspector", 2, Colors.Accent)
        local _, fruitLbl   = CreateStatRow(bagContent, "Harvested Fruits in Bag", "?",            Colors.Warning)
        local _, seedLbl    = CreateStatRow(bagContent, "Seeds in Bag",             "?",            Colors.Success)
        local _, petCntLbl  = CreateStatRow(bagContent, "Pets in Bag",              "?",            Colors.Frozen)
        local _, capLbl     = CreateStatRow(bagContent, "Capacity",                 "? / " .. MAX_FRUIT_CAP, Colors.Accent)

        task.spawn(function()
            while GetActivePage() == "Sell" do
                task.wait(0.5)
                if GetActivePage() ~= "Sell" then break end
                local fruits, seeds, pets = 0, 0, 0
                for _, t in ipairs(player.Backpack:GetChildren()) do
                    if     t:GetAttribute("HarvestedFruit")                         then fruits = fruits + 1
                    elseif t:GetAttribute("SeedTool") or t:GetAttribute("SeedName") then seeds  = seeds  + 1
                    elseif t:GetAttribute("Pet")                                     then pets   = pets   + 1
                    end
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
    end)

    -- ====================== PETS PAGE ======================
    ctx.registerPage("Pets", function()
        -- Cache Logic references used only on this page.
        local ScanWildPets           = Logic.ScanWildPets
        local HumanizePetName        = Logic.HumanizePetName
        local RarityColor            = Logic.RarityColor
        local PET_RARITY_LOOKUP      = Logic.PET_RARITY_LOOKUP
        local SmartMoveToPet         = Logic.SmartMoveToPet
        local BuyWildPet             = Logic.BuyWildPet
        local IsWildPetFree          = Logic.IsWildPetFree

        -- Lookup tables built once; avoid re-creating them inside callbacks.
        local rarityOrd = { Super = 6, Mythic = 5, Legendary = 4, Rare = 3, Uncommon = 2, Common = 1 }
        local sizeOrd   = { Huge  = 3, Big    = 2, Normal    = 1 }

        -- ── Pet Inventory card ────────────────────────────────────────────
        local _, petContent = CreateSectionCard("\240\159\144\190 Pet Inventory", 1, Colors.Frozen)
        local listArea = Create("Frame", {
            Parent              = petContent,
            Size                = UDim2.new(1, 0, 0, 0),
            AutomaticSize       = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
        })
        CreateListLayout(listArea, 6)

        local ROW_H, ROW_GAP = 28, 6

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
            CreateSubHeader(listArea, "Pets in Backpack (" .. #playerPets .. ")")
            if #playerPets == 0 then
                CreateInfoText(listArea, nil, "No pets in backpack.", Colors.TextMuted)
                return
            end
            local scrollH   = 8 * ROW_H + 7 * ROW_GAP
            local scrollWrap = Create("Frame", { Parent = listArea, Size = UDim2.new(1, 0, 0, scrollH), BackgroundTransparency = 1 })
            local petScroll  = Create("ScrollingFrame", {
                Parent                = scrollWrap,
                Size                  = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                BorderSizePixel       = 0,
                ScrollBarThickness    = 3,
                ScrollBarImageColor3  = Colors.Border,
                CanvasSize            = UDim2.new(0, 0, 0, 0),
                AutomaticCanvasSize   = Enum.AutomaticSize.Y,
            })
            CreateListLayout(petScroll, ROW_GAP)
            for i, pet in ipairs(playerPets) do
                local rarity    = PET_RARITY_LOOKUP[pet.name] or "Unknown"
                local rarityCol = RarityColor[rarity] or Colors.TextSecondary
                local valStr    = rarity
                if pet.size ~= "Normal" then valStr = rarity .. " (" .. pet.size .. ")" end
                local displayName = (pet.petType == "Rainbow" and "\240\159\140\136 " or "") .. pet.name
                CreateStatRow(petScroll, i .. ". " .. displayName, valStr, rarityCol)
            end
        end

        RebuildInventory()
        -- Event-driven rebuild instead of polling — fires only when backpack actually changes.
        player.Backpack.ChildAdded:Connect(function(child)
            if child:GetAttribute("Pet") or child:GetAttribute("PetSpecies") then task.defer(RebuildInventory) end
        end)
        player.Backpack.ChildRemoved:Connect(function(child)
            if child:GetAttribute("Pet") or child:GetAttribute("PetSpecies") then task.defer(RebuildInventory) end
        end)

        -- ── Pet Finder card ───────────────────────────────────────────────
        local _, finderContent = CreateSectionCard("\240\159\148\141 Pet Finder", 2, Colors.Warning)
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
                    Size            = UDim2.new(1, 0, 0, 40),
                    BackgroundColor3 = Colors.BackgroundLighter,
                    BorderSizePixel = 0,
                })
                CreateCorner(row, 8)
                CreateStroke(row, col, 1)
                local bullet = Create("Frame", {
                    Parent          = row,
                    Size            = UDim2.new(0, 7, 0, 7),
                    Position        = UDim2.new(0, 12, 0.5, -3),
                    BackgroundColor3 = col,
                    BorderSizePixel = 0,
                })
                CreateCorner(bullet, 4)
                Create("TextLabel", { Parent = row, Size = UDim2.new(0, 130, 1, 0), Position = UDim2.new(0, 26,  0, 0), BackgroundTransparency = 1, Text = petName,  TextColor3 = col,               TextSize = 13, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
                Create("TextLabel", { Parent = row, Size = UDim2.new(0,  90, 1, 0), Position = UDim2.new(0, 164, 0, 0), BackgroundTransparency = 1, Text = rarity,   TextColor3 = col,               TextSize = 12, Font = Enum.Font.Gotham,     TextXAlignment = Enum.TextXAlignment.Left })
                Create("TextLabel", { Parent = row, Size = UDim2.new(0,  80, 1, 0), Position = UDim2.new(0, 262, 0, 0), BackgroundTransparency = 1, Text = distStr,  TextColor3 = Colors.TextMuted,  TextSize = 12, Font = Enum.Font.Gotham,     TextXAlignment = Enum.TextXAlignment.Left })

                local tpBtn = Create("TextButton", {
                    Parent          = row,
                    Size            = UDim2.new(0, 64, 0, 26),
                    Position        = UDim2.new(1, -72, 0.5, -13),
                    BackgroundColor3 = Colors.Surface,
                    Text            = "TP \226\134\146",
                    TextColor3      = col,
                    TextSize        = 12,
                    Font            = Enum.Font.GothamBold,
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                })
                CreateCorner(tpBtn, 6)
                tpBtn.MouseEnter:Connect(function() Tween(tpBtn, { BackgroundColor3 = Colors.SurfaceLight }, 0.1) end)
                tpBtn.MouseLeave:Connect(function() Tween(tpBtn, { BackgroundColor3 = Colors.Surface },      0.1) end)
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

        -- Session-guarded background refresh (every 2 s while on Pets page).
        local finderPageAlive = true
        local finderConn
        finderConn = RunService.Heartbeat:Connect(function()
            if GetActivePage() ~= "Pets" then
                finderPageAlive = false
                finderConn:Disconnect()
            end
        end)

        task.spawn(function()
            while finderPageAlive and _G._MiracleHubSession == SESSION do
                task.wait(2)
                if finderPageAlive and GetActivePage() == "Pets" then
                    pcall(RebuildPetList)
                end
            end
        end)

        CreateActionButton(finderContent, "\226\154\161 TP to Nearest Pet", function()
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

        -- ── Auto Catch Wild card ──────────────────────────────────────────
        local _, wildContent = CreateSectionCard("\240\159\142\175 Auto Catch Wild", 3, Colors.Warning)
        local WILD_PET_NAMES = {
            "Frog", "Bunny", "Owl", "Deer", "Turtle", "Robin", "Bee",
            "Monkey", "Bear", "Unicorn", "Golden Dragonfly", "Raccoon",
            "Black Dragon", "Ice Serpent",
        }
        CreateMultiSelect(wildContent, "\240\159\144\190Choose Target Pets", WILD_PET_NAMES, "wildCatchTargets")
        CreateToggle(wildContent, "Auto Catch Wild Pets", "autoCatchWild",
            "ON: keeps running, chasing any matching pet that spawns | OFF: stops the loop",
            function(newVal)
                if newVal then
                    local sel = States.wildCatchTargets or {}
                    if #sel == 0 then
                        Notify("Auto Catch", "ON \226\128\148 chasing all wild pets", Colors.Success, 3)
                    else
                        Notify("Auto Catch", "ON \226\128\148 targeting: " .. table.concat(sel, ", "), Colors.Success, 3)
                    end
                else
                    Notify("Auto Catch", "OFF", Colors.TextMuted, 2)
                end
            end)
    end)

    -- ====================== EGGS PAGE ======================
    ctx.registerPage("Eggs", function()
        local _, eggContent = CreateSectionCard("\240\159\165\154 Egg Hatching", 1, Colors.Warning)
        CreateInfoText(eggContent, "\240\159\154\167 Coming Soon",
            "Egg Hatching is currently under development.\nNot many players have eggs yet, so this feature isn't active.\nStay tuned for the next update!")
    end)

    -- ====================== PLAYER PAGE ======================
    ctx.registerPage("Player", function()
        -- Live Stats card
        local _, statsContent = CreateSectionCard("\240\159\147\138 Live Player Stats", 1, Colors.Accent)
        local _, hpLbl = CreateStatRow(statsContent, "Health",     "100 / 100",  Colors.Success)
        local _, wsLbl = CreateStatRow(statsContent, "WalkSpeed",  tostring(ctx.humanoid and ctx.humanoid.WalkSpeed  or "?"), Colors.Accent)
        local _, jpLbl = CreateStatRow(statsContent, "JumpPower",  tostring(ctx.humanoid and ctx.humanoid.JumpPower  or "?"), Colors.Accent)
        CreateStatRow(statsContent, "Plot ID", MY_PLOT_ID, Colors.Warning)
        local _, bpLbl = CreateStatRow(statsContent, "Backpack Items", #player.Backpack:GetChildren(), Colors.TextSecondary)

        task.spawn(function()
            local bpTick = 0
            while GetActivePage() == "Player" do
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

        -- Movement card
        local _, moveContent = CreateSectionCard("\240\159\143\131 Movement", 2, Colors.Electric)
        CreateToggle(moveContent, "Lock WalkSpeed",  "lockWalkSpeed")
        CreateSlider(moveContent, "WalkSpeed",  1, 500, "walkSpeed")
        CreateToggle(moveContent, "Lock JumpPower",  "lockJumpPower")
        CreateSlider(moveContent, "JumpPower",  1, 500, "jumpPower")
        CreateToggle(moveContent, "Infinite Jump",   "infiniteJump")

        -- Fly card
        local _, utilContent = CreateSectionCard("\226\156\136\239\184\143 Fly", 3, Colors.TextSecondary)
        CreateInfoText(utilContent, "Controls", "[F] Toggle Fly | [W/A/S/D] Move | [Space] Up | [Ctrl] Down")

        -- The third return value (setFlyVisual) is exposed to ctx so the keybind in
        -- bootstrap can sync the toggle knob when the user presses F without clicking.
        local _, _, setFlyVisual = CreateToggle(utilContent, "Fly", "fly",
            "Hold WASD to fly, Space=up, Ctrl=down",
            function(state)
                if ctx.ToggleFly then
                    ctx.ToggleFly(state)  -- forceState avoids a double-toggle
                else
                    Notify("Player", "Fly " .. (state and "ON" or "OFF"), state and Colors.Success or Colors.TextMuted)
                end
            end)

        ctx._setFlyVisual = setFlyVisual
        CreateSlider(utilContent, "Fly Speed", 1, 300, "flySpeed")
    end)

    -- ====================== VISUALS PAGE ======================
    ctx.registerPage("Visuals", function()
        local _, espContent = CreateSectionCard("\240\159\145\129 ESP & Highlights", 1, Colors.Electric)
        CreateToggle(espContent, "ESP Players",      "espPlayers",     "Shows player names/tags above heads")
        CreateToggle(espContent, "ESP Wild Pets",    "espItems",       "Highlights wild pets in workspace")
        CreateToggle(espContent, "ESP Fruits",       "espFruits",      "Highlights harvestable fruits on the plot")
        CreateToggle(espContent, "ESP Mutations",    "espMutations",   "Shows mutation tags on plants")
        CreateToggle(espContent, "Show Plant Age",   "showPlantAge",   "Shows Age/MaxAge above each plant")
        CreateToggle(espContent, "Show Fruit Weight","showFruitWeight","Shows fruit weight above harvestables")
        CreateActionButton(espContent, "Clear All ESP Labels", function()
            Logic.ClearESP()
            Notify("Visuals", "All ESP labels cleared.", Colors.TextMuted)
        end)

        local _, visContent = CreateSectionCard("\240\159\140\136 Visual Settings", 2, Colors.Accent)
        CreateToggle(visContent, "Full Bright", "fullBright", "Sets ambient to maximum brightness")
        CreateSlider(visContent, "Brightness",  0, 10, "brightness")
        CreateToggle(visContent, "No Fog",      "noFog",       "Removes environmental fog")
        CreateToggle(visContent, "No Shadows",  "noShadows",   "Disables global shadows")

        CreateActionButton(visContent, "Reset Visuals to Default", function()
            local lighting = game:GetService("Lighting")
            lighting.Brightness    = 1
            lighting.Ambient       = Color3.fromRGB(70, 70, 70)
            lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 140)
            lighting.FogEnd        = 100000
            lighting.GlobalShadows = true
            States.fullBright = false
            States.noFog      = false
            States.noShadows  = false
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
            task.spawn(function() ctx.UltraLow.Apply() end)
        end, Colors.Warning)
    end)

    -- ====================== TELEPORT PAGE ======================
    ctx.registerPage("Teleport", function()
        local _, tpContent = CreateSectionCard("\240\159\147\141 Quick Teleport", 1, Colors.Accent)

        -- Cache once; no need to call GetService inside every button callback.
        local Workspace       = game:GetService("Workspace")
        local PlayersService  = game:GetService("Players")

        local GAME_TELEPORTS = {
            { "\240\159\140\177 Seeds Shop", "Seeds", Colors.Success  },
            { "\240\159\146\176 Sell Area",  "Sell",  Colors.Gold     },
            { "\226\154\153 Gear Shop",      "Gears", Colors.Electric },
            { "\240\159\143\161 Props Shop", "Props", Colors.Accent   },
        }

        CreateSubHeader(tpContent, "Game Locations")
        for _, tp in ipairs(GAME_TELEPORTS) do
            local tpLabel, tpKey, tpColor = tp[1], tp[2], tp[3]
            CreateActionButton(tpContent, "Teleport to " .. tpLabel, function()
                local teleports = Workspace:FindFirstChild("Teleports")
                if teleports then
                    local part = teleports:FindFirstChild(tpKey)
                    if part and player.Character then
                        player.Character:PivotTo(part.CFrame + Vector3.new(0, 5, 0))
                        Notify("Teleport", "\226\134\146 " .. tpLabel, tpColor)
                    else
                        Notify("Teleport", tpLabel .. " location not found!", Colors.Error)
                    end
                end
            end, tpColor)
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
        for _, p in ipairs(PlayersService:GetPlayers()) do
            if p ~= player then table.insert(playerList, p.Name) end
        end
        if #playerList > 0 then
            CreateDropdown(tpContent, "Target Player", playerList, "tpTargetPlayer")
            CreateActionButton(tpContent, "Teleport to Selected Player", function()
                local targetName = States.tpTargetPlayer
                if not targetName then Notify("Teleport", "Select a player first.", Colors.Error) return end
                local target = PlayersService:FindFirstChild(targetName)
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
        local _, worthContent = CreateSectionCard("\240\159\146\142 Item Inspector", 1, Colors.Gold)

        -- Cache tool reference at page-open time; polling loop updates it each tick.
        local currentTool = player.Character and player.Character:FindFirstChildWhichIsA("Tool")
        local _, toolNameLbl = CreateStatRow(worthContent, "Currently Holding", currentTool and currentTool.Name or "Nothing", Colors.TextPrimary)

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
                local weight   = ct:GetAttribute("Weight")
                local mut      = GetMutation(ct)
                local sm       = ct:GetAttribute("SizeMultiplier")
                local decay    = ct:GetAttribute("DecayAlpha")
                local fn       = ct:GetAttribute("FruitName") or ct:GetAttribute("Fruit") or ct.Name
                if weight then
                    Notify("Inspect: " .. fn,
                        string.format("Wt:%.2fkg | Mut:%s | x%.2f size | Decay:%.4f", weight, mut, sm or 1, decay or 0),
                        GetMutationColor(mut), 6)
                else
                    local seedName = ct:GetAttribute("SeedTool") or ct:GetAttribute("SeedName")
                    if seedName then
                        Notify("Inspect: Seed", "Type: " .. seedName, Colors.Success)
                    else
                        Notify("Inspect", ct.Name .. " \226\128\148 not a fruit or seed.", Colors.TextMuted)
                    end
                end
            else
                Notify("Inspect", "Not holding anything.", Colors.TextMuted)
            end
        end, Colors.Gold)

        CreateActionButton(worthContent, "Count Bag Contents", function()
            local fruits, seeds, pets, other = 0, 0, 0, 0
            for _, t in ipairs(player.Backpack:GetChildren()) do
                if     t:GetAttribute("HarvestedFruit")                         then fruits = fruits + 1
                elseif t:GetAttribute("SeedTool") or t:GetAttribute("SeedName") then seeds  = seeds  + 1
                elseif t:GetAttribute("Pet")                                     then pets   = pets   + 1
                else   other = other + 1 end
            end
            Notify("Bag Contents",
                "Fruits:" .. fruits .. " | Seeds:" .. seeds .. " | Pets:" .. pets .. " | Other:" .. other,
                Colors.Accent)
        end)

        -- Gifts & Mailbox card
        local _, giftContent = CreateSectionCard("\240\159\142\129 Gifts & Mailbox", 2, Colors.Rainbow)
        CreateToggle(giftContent, "Auto Accept Gifts", "autoAcceptGifts", "Automatically checks your mailbox every 10 seconds")
        CreateActionButton(giftContent, "Check Mailbox Now", function()
            local plot = GetMyPlot()
            if not plot then Notify("Mailbox", "Your plot was not found!", Colors.Error) return end
            -- Cache descendant search: Signs → GreyMailBox → MailboxPrompt
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
    end)

    -- ====================== MAILER PAGE ======================
    ctx.registerPage("Mailer", function()
        local _, mailerContent = CreateSectionCard("\226\156\137 Mailer System", 1, Colors.Accent)
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
    end)

    -- ====================== INFO PAGE ======================
    ctx.registerPage("Info", function()
        local _, infoContent = CreateSectionCard("\226\132\185 About Miracle Hub", 1, Colors.Success)
        CreateStatRow(infoContent, "Hub Name",         "Miracle Hub",                                                Colors.Success)
        CreateStatRow(infoContent, "Game",             "Grow A Garden 2",                                            Colors.TextSecondary)
        CreateStatRow(infoContent, "Player",           player.DisplayName or player.Name,                            Colors.Accent)
        CreateStatRow(infoContent, "UserId",           player.UserId,                                                Colors.TextMuted)
        CreateStatRow(infoContent, "Plot ID",          MY_PLOT_ID,                                                   Colors.Warning)
        CreateStatRow(infoContent, "Prime Status",     player:GetAttribute("PrimeEnabled") and "Enabled" or "Disabled", Colors.Warning)
        CreateStatRow(infoContent, "Connection Status",
            ctx.PacketRemote and "Connected" or "\226\154\160 Not Connected",
            ctx.PacketRemote and Colors.Success or Colors.Error)
    end)

    -- ====================== SERVER PAGE ======================
    ctx.registerPage("Server", function()
        local PlayersService     = game:GetService("Players")
        local TeleportService    = game:GetService("TeleportService")

        local _, serverContent = CreateSectionCard("\240\159\140\144 Server Info", 1, Colors.Electric)
        CreateStatRow(serverContent, "Job ID",    game.JobId:sub(1, 20) .. "...", Colors.TextMuted)
        CreateStatRow(serverContent, "Place ID",  tostring(game.PlaceId),         Colors.TextMuted)
        local _, pcLbl = CreateStatRow(serverContent, "Players in Server", #PlayersService:GetPlayers(), Colors.Success)

        -- Build per-player plot labels once; update them on the polling loop.
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
            while GetActivePage() == "Server" do
                task.wait(1)
                if GetActivePage() ~= "Server" then break end
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

        -- Auto Rejoin card
        local _, autoContent = CreateSectionCard("\240\159\148\132 Auto Rejoin", 2, Colors.Warning)
        CreateToggle(autoContent, "Auto Rejoin on Disconnect", "autoRejoin", "Rejoins automatically when kicked/disconnected")
        CreateDropdown(autoContent, "Rejoin Condition", { "Server Full", "FPS Drop", "Disconnected", "Manual" }, "rejoinCondition")
        PlayersService.PlayerRemoving:Connect(function(p)
            if p == player and States.autoRejoin then
                task.wait(2)
                TeleportService:Teleport(game.PlaceId, player)
            end
        end)
    end)

    -- ====================== SETTINGS PAGE ======================
    ctx.registerPage("Settings", function()
        local _, settContent = CreateSectionCard("\226\154\153 General Settings", 1, Colors.Accent)
        CreateToggle(settContent, "Auto Save Config",         "autoSaveConfig",    "Saves your config automatically")
        CreateToggle(settContent, "Anti AFK",                 "antiAfk",           "Prevents auto-disconnect")
        CreateToggle(settContent, "Minimize to Tray on Close","minimizeToTray",    "Minimizes to M shield instead of closing")
        CreateToggle(settContent, "Show Notifications",       "showNotifications", "Shows popup notifications")
        CreateSubHeader(settContent, "Config")

        CreateActionButton(settContent, "Export Config to Clipboard", function()
            local cfg = {}
            for k, v in pairs(States) do table.insert(cfg, k .. "=" .. tostring(v)) end
            table.sort(cfg)
            setclipboard(table.concat(cfg, "\n"))
            Notify("Settings", "Full config exported to clipboard.", Colors.Success)
        end)

        CreateActionButton(settContent, "Reset All States", function()
            -- Toggle-style automation states
            local RESET_STATES = {
                "autoPlant", "autoHarvest", "autoSell", "autoBuySeed", "autoBuyCrate",
                "autoOpenCrate", "autoCatchWild", "autoOpenEgg", "autoAcceptGifts", "fly",
                "espPlayers", "espItems", "espFruits", "espMutations",
                "fullBright", "noFog", "noShadows", "showFruitWeight", "showPlantAge",
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