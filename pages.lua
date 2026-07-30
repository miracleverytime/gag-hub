-- ======================================================================
-- Miracle Hub — pages.lua (RESTRUCTURED)
-- All page builders. Loaded FOURTH (after core, ui, logic).
-- Registers each page via ctx.registerPage(name, builderFn).
--
-- STRUCTURE: 5 Pages (reduced from 13)
--   1. Automatic  - All automation loops
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

    -- ====================== PAGE 1: AUTOMATIC ======================
    ctx.registerPage("Automatic", function()

        -- ═══════════════════════════════════════════════════════════
        -- Section 1: 🌱 Farming
        -- ═══════════════════════════════════════════════════════════
        local _, farmContent = CreateSectionCard("🌱 Farming", 1, Colors.Success)

        -- AUTO PLANT
        CreateSubHeader(farmContent, "🌱 Auto Plant")
        
        local lastNoTargetPlant = { [1] = 0 }
        local msPlantControl    = { SetDisabled = nil }

        local _, _, setAutoPlantVisual = CreateToggle(farmContent, "Auto Plant", "autoPlant",
            "Fills empty plot slots. Needs at least one seed selected below (or enable Plant All).",
            function(newVal, revert)
                if newVal and not States.autoPlantAllSeeds then
                    if #(States.autoPlantTargets or {}) == 0 then
                        revert()
                        notifyIfCooled(lastNoTargetPlant, "Auto Plant",
                            "⚠️ Select seeds in 'Choose Seeds to Plant' before enabling Auto Plant!",
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
        CreateSubHeader(farmContent, "🍅 Auto Harvest")
        
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
            while GetActivePage() == "Automatic" do
                task.wait(1)
                if GetActivePage() ~= "Automatic" then break end
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
        CreateMultiSelect(farmContent, "⏯️Skip Mutation", MUTATIONS, "harvestFilterMutation")

        -- AUTO WATER
        CreateSubHeader(farmContent, "💧 Auto Water")
        
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
                    Notify("Auto Water", "⚠️ Select a Watering Can below before enabling!", Colors.Warning, 5)
                end
            end)
        CreateMultiSelect(farmContent, "🪣 Choose Watering Can", wateringCans, "wateringCanTargets")
        CreateSlider(farmContent, "Per-Plant Delay (s)", 0, 2, "perFruitDelay")
        CreateSlider(farmContent, "Water Loop Delay (s)", 1, 60, "harvestLoopDelay")

        -- AUTO SPRINKLER
        CreateSubHeader(farmContent, "🌿 Auto Sprinkler")
        
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
                    Notify("Auto Sprinkler", "⚠️ Select a Sprinkler below before enabling!", Colors.Warning, 5)
                end
            end)
        CreateMultiSelect(farmContent, "🌿 Choose Sprinkler", sprinklerList, "sprinklerTargets")

        -- ═══════════════════════════════════════════════════════════
        -- Section 2: 🛒 Shopping
        -- ═══════════════════════════════════════════════════════════
        local _, shopContent = CreateSectionCard("🛒 Shopping", 2, Colors.Electric)

        -- AUTO BUY SEEDS
        CreateSubHeader(shopContent, "🌱 Auto Buy Seeds")
        
        local lastNoTargetSeed = { [1] = 0 }
        local msSeedControl    = { SetDisabled = nil }

        local _, _, setAutoBuyVisual = CreateToggle(shopContent, "Auto Buy Seeds", "autoBuySeed",
            "Rapidly buys selected seeds, stops when out of stock",
            function(newVal, revert)
                if newVal and not States.autoBuyAll and #(States.autoBuySeedTargets or {}) == 0 then
                    revert()
                    notifyIfCooled(lastNoTargetSeed, "Auto Buy",
                        "⚠️ Select seeds below before enabling Auto Buy!", Colors.Warning)
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
            shopContent, "🌱Choose Target Seeds", SEEDS,
            "autoBuySeedTargets", "autoBuySeed", "autoBuyAll",
            msSeedControl, forceOffAutoBuy, "Auto Buy Seeds",
            function() pcall(function() Logic.ResetNotifiedEmpty() end) end
        )
        CreateToggle(shopContent, "Notify on Purchase", "notifyBuy", "Show a notification each time a seed is bought")

        -- AUTO BUY GEAR
        CreateSubHeader(shopContent, "⚙️ Auto Buy Gear")
        
        local lastNoTargetGear = { [1] = 0 }
        local msGearControl    = { SetDisabled = nil }

        local _, _, setAutoBuyGearVisual = CreateToggle(shopContent, "Auto Buy Gear", "autoBuyGear",
            "Rapidly buys selected gear, stops when out of stock",
            function(newVal, revert)
                if newVal and not States.autoBuyGearAll and #(States.autoBuyGearTargets or {}) == 0 then
                    revert()
                    notifyIfCooled(lastNoTargetGear, "Auto Buy Gear",
                        "⚠️ Select gear below before enabling!", Colors.Warning)
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
            shopContent, "⚙️Choose Target Gear", GEARS,
            "autoBuyGearTargets", "autoBuyGear", "autoBuyGearAll",
            msGearControl, forceOffAutoBuyGear, "Auto Buy Gear",
            function() pcall(function() Logic.ResetNotifiedEmptyGear() end) end
        )
        CreateToggle(shopContent, "Notify on Purchase", "notifyBuyGear", "Show a notification each time a gear is bought")

        -- AUTO BUY CRATE
        CreateSubHeader(shopContent, "📦 Auto Buy Crate")
        
        local lastNoTargetCrate = { [1] = 0 }
        local msCrateControl    = { SetDisabled = nil }

        local _, _, setAutoBuyCrateVisual = CreateToggle(shopContent, "Auto Buy Crate", "autoBuyCrate",
            "Rapidly buys selected crates, stops when out of stock",
            function(newVal, revert)
                if newVal and not States.autoBuyCrateAll and #(States.autoBuyCrateTargets or {}) == 0 then
                    revert()
                    notifyIfCooled(lastNoTargetCrate, "Auto Buy Crate",
                        "⚠️ Select crates below before enabling!", Colors.Warning)
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
            shopContent, "📦Choose Target Crates", CRATES,
            "autoBuyCrateTargets", "autoBuyCrate", "autoBuyCrateAll",
            msCrateControl, forceOffAutoBuyCrate, "Auto Buy Crate",
            function() pcall(function() Logic.ResetNotifiedEmptyCrate() end) end
        )
        CreateToggle(shopContent, "Notify on Purchase", "notifyBuyCrate", "Show a notification each time a crate is bought")

        -- AUTO OPEN CRATE
        CreateSubHeader(shopContent, "🎁 Auto Open Crate")
        CreateToggle(shopContent, "Auto Open Crate", "autoOpenCrate", "Automatically opens all crates in your backpack")
        CreateSlider(shopContent, "Delay Between Opens (s)", 1, 30, "crateOpenDelay")
        CreateToggle(shopContent, "Notify on Open", "notifyOpenCrate", "Show what item you received when a crate is opened")

        -- ═══════════════════════════════════════════════════════════
        -- Section 3: 💰 Selling
        -- ═══════════════════════════════════════════════════════════
        local _, sellContent = CreateSectionCard("💰 Selling", 3, Colors.Gold)
        
        local netStatus = Networking
            and "Sell system ready."
            or "Sell system unavailable — reload the hub if this persists."
        CreateInfoText(sellContent, "How It Works",
            netStatus .. "\nAuto Sell continuously sells all fruits in your backpack. Use filters below to keep specific mutations.")
        CreateToggle(sellContent, "Auto Sell Fruits", "autoSell", "Continuously sells all fruits in your backpack automatically")
        CreateToggle(sellContent, "Keep Mutated Fruits", "keepMutations", "Skip all fruits that have any mutation")
        CreateMultiSelect(sellContent, "🔒Keep Specific Mutations", MUTATIONS, "sellKeepMutation")
        CreateSlider(sellContent, "Delay Between Sells (s)", 0, 3, "sellDelay")
        CreateSlider(sellContent, "Loop Delay (s)", 1, 60, "sellLoopDelay")
        CreateToggle(sellContent, "Notify on Sell", "notifySell", "Show a notification with sell totals after each cycle")

        -- ═══════════════════════════════════════════════════════════
        -- Section 4: 🐾 Pets
        -- ═══════════════════════════════════════════════════════════
        local _, petContent = CreateSectionCard("🐾 Pets", 4, Colors.Frozen)
        
        local WILD_PET_NAMES = {
            "__SIZE_Big", "__SIZE_Huge", "__SIZE_Giant",
            "__TYPE_Rainbow",
            "Frog", "Bunny", "Owl", "Deer", "Turtle", "Robin", "Bee",
            "Monkey", "Bear", "Unicorn", "Golden Dragonfly",
            "Firefly", "Bald Eagle",
            "Raccoon",
        }
        local WILD_PET_DISPLAY = {
            __SIZE_Big     = "🔷 All Big",
            __SIZE_Huge    = "🔶 All Huge",
            __SIZE_Giant   = "💠 All Giant",
            __TYPE_Rainbow = "🌈 All Rainbow",
        }
        CreateMultiSelect(petContent, "🐾Choose Target Pets", WILD_PET_NAMES, "wildCatchTargets", WILD_PET_DISPLAY)
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
        -- Section 5: 🎁 Utilities
        -- ═══════════════════════════════════════════════════════════
        local _, utilContent = CreateSectionCard("🎁 Utilities", 5, Colors.Rainbow)
        
        CreateToggle(utilContent, "Auto Accept Gifts", "autoAcceptGifts", "Automatically checks your mailbox every 10 seconds")
        CreateToggle(utilContent, "Auto Rejoin on Disconnect", "autoRejoin", "Rejoins automatically when kicked/disconnected")

    end)

    -- ====================== PAGE 2: INVENTORY ======================
    ctx.registerPage("Inventory", function()
        
        -- Section 1 akan saya lanjutkan di message berikutnya...
        CreateInfoText(Create("Frame", {Parent = ctx.ContentArea, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,100)}), 
            "🚧 Under Construction", 
            "Inventory page is being built...")
            
    end)

    -- ====================== PAGE 3: SHOW ======================
    ctx.registerPage("Show", function()
        CreateInfoText(Create("Frame", {Parent = ctx.ContentArea, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,100)}), 
            "🚧 Under Construction", 
            "Show page is being built...")
    end)

    -- ====================== PAGE 4: MISC ======================
    ctx.registerPage("Misc", function()
        CreateInfoText(Create("Frame", {Parent = ctx.ContentArea, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,100)}), 
            "🚧 Under Construction", 
            "Misc page is being built...")
    end)

    -- ====================== PAGE 5: SETTINGS ======================
    ctx.registerPage("Settings", function()
        local _, settContent = CreateSectionCard("⚙️ General Settings", 1, Colors.Accent)
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
