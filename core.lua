-- ======================================================================
-- Miracle Hub — core.lua
-- Foundation module: services, player refs, Colors, game Data, States.
-- Loaded FIRST. Fills the shared `ctx` table that every other module reads.
--
-- Usage (from loader): require-style via loadstring
--   local core = loadstring(game:HttpGet(BASE .. "core.lua"))()
--   core(ctx)
-- ======================================================================

return function(ctx)
    -- ====================== SERVICES ======================
    local Players              = game:GetService("Players")
    local TweenService         = game:GetService("TweenService")
    local UserInputService      = game:GetService("UserInputService")
    local RunService           = game:GetService("RunService")
    local CollectionService    = game:GetService("CollectionService")
    local ReplicatedStorage    = game:GetService("ReplicatedStorage")
    local TeleportService      = game:GetService("TeleportService")
    local HttpService          = game:GetService("HttpService")

    ctx.Players           = Players
    ctx.TweenService      = TweenService
    ctx.UserInputService  = UserInputService
    ctx.RunService        = RunService
    ctx.CollectionService = CollectionService
    ctx.ReplicatedStorage = ReplicatedStorage
    ctx.TeleportService   = TeleportService
    ctx.HttpService       = HttpService

    -- ====================== PLAYER REFS ======================
    local player    = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid  = character:WaitForChild("Humanoid")

    ctx.player    = player
    ctx.playerGui = playerGui
    ctx.character = character
    ctx.humanoid  = humanoid

    -- ====================== SESSION GUARD ======================
    -- Kill semua loop dari inject sebelumnya (cegah double loop).
    _G._MiracleHubSession = (_G._MiracleHubSession or 0) + 1
    ctx.SESSION = _G._MiracleHubSession

    -- Remove existing GUI if any
    local existingGui = playerGui:FindFirstChild("MiracleHub")
    if existingGui then existingGui:Destroy() end

    -- ====================== COLORS ======================
    ctx.Colors = {
        Background = Color3.fromRGB(12, 12, 14),
        BackgroundLight = Color3.fromRGB(20, 20, 24),
        BackgroundLighter = Color3.fromRGB(30, 30, 36),
        Surface = Color3.fromRGB(40, 40, 48),
        SurfaceLight = Color3.fromRGB(55, 55, 65),
        Border = Color3.fromRGB(60, 60, 72),
        BorderLight = Color3.fromRGB(80, 80, 95),
        TextPrimary = Color3.fromRGB(255, 255, 255),
        TextSecondary = Color3.fromRGB(180, 180, 190),
        TextMuted = Color3.fromRGB(120, 120, 135),
        Accent = Color3.fromRGB(200, 200, 210),
        AccentHover = Color3.fromRGB(220, 220, 230),
        ToggleOn = Color3.fromRGB(80, 200, 120),
        ToggleOnDark = Color3.fromRGB(40, 100, 60),
        ToggleOff = Color3.fromRGB(40, 40, 48),
        ToggleKnob = Color3.fromRGB(255, 255, 255),
        SliderTrack = Color3.fromRGB(40, 40, 48),
        SliderFill = Color3.fromRGB(200, 200, 210),
        Success = Color3.fromRGB(50, 255, 100),
        Error = Color3.fromRGB(180, 80, 80),
        Warning = Color3.fromRGB(255, 200, 60),
        Gold = Color3.fromRGB(255, 215, 0),
        Electric = Color3.fromRGB(80, 160, 255),
        Rainbow = Color3.fromRGB(255, 100, 200),
        Frozen = Color3.fromRGB(100, 210, 255),
        BadgeRare = Color3.fromRGB(60, 120, 255),
        BadgeLegend = Color3.fromRGB(200, 100, 255),
        -- Mutation colors (new)
        Bloodlit   = Color3.fromRGB(220, 40,  40),
        Starstruck = Color3.fromRGB(255, 230, 80),
        Aurora     = Color3.fromRGB(80,  255, 200),
    }

    -- ====================== GAME DATA (from scanner) ======================
    local Data = {}

    -- Full seed list from ReplicatedStorage.StockValues.SeedShop.Items (scanner verified)
    Data.SEEDS = {
        "Carrot", "Strawberry", "Blueberry", "Tulip", "Tomato", "Apple", "Bamboo",
        "Corn", "Cactus", "Pineapple", "Mushroom", "Green Bean", "Banana", "Grape",
        "Coconut", "Mango", "Dragon Fruit", "Acorn", "Cherry", "Sunflower",
        "Venus Fly Trap", "Pomegranate", "Poison Apple", "Venom Spitter",
        "Moon Bloom", "Dragon's Breath", "Ghost Pepper", "Poison Ivy",
        "Baby Cactus", "Glow Mushroom", "Romanesco", "Horned Melon",
        "Hypnobloom", "Gold", "Rainbow",
    }

    -- Gear list dari GearShopData
    Data.GEARS = {
        "Common Watering Can", "Common Sprinkler", "Sign", "Megaphone",
        "Uncommon Sprinkler", "Rare Sprinkler", "Legendary Sprinkler", "Super Sprinkler",
        "Wheelbarrow", "Strawberry Sniper", "Trowel",
        "Speed Mushroom", "Jump Mushroom", "Shrink Mushroom", "Supersize Mushroom",
        "Invisibility Mushroom", "Gnome", "Teleporter",
        "Super Watering Can", "Basic Pot", "Flashbang",
        "Player Magnet", "Grappling Hook",
        "Legendary Pet Teleporter", "Mythic Pet Teleporter", "Super Pet Teleporter",
    }

    Data.CRATES = {
        "Arch Crate",
        "Bear Trap Crate",
        "Bench Crate",
        "Bridge Crate",
        "Conveyor Crate",
        "Fence Crate",
        "Ladder Crate",
        "Light Crate",
        "Owner Door Crate",
        "Picture Frame Crate",
        "Roleplay Crate",
        "Seesaw Crate",
        "Sign Crate",
        "Spring Crate",
        "Teleporter Pad Crate",
    }

    Data.CRATE_COST = {
        ["Arch Crate"]          = 200000,
        ["Bear Trap Crate"]     = 500000,
        ["Bench Crate"]         = 60000,
        ["Bridge Crate"]        = 700000,
        ["Conveyor Crate"]      = 700000,
        ["Fence Crate"]         = 7000000,
        ["Ladder Crate"]        = 30000,
        ["Light Crate"]         = 90000,
        ["Owner Door Crate"]    = 1500000,
        ["Picture Frame Crate"] = 350000,
        ["Roleplay Crate"]      = 300000,
        ["Seesaw Crate"]        = 1500000,
        ["Sign Crate"]          = 150000,
        ["Spring Crate"]        = 900000,
        ["Teleporter Pad Crate"]= 20000000,
    }

    Data.MUTATIONS = {"Gold", "Electric", "Rainbow", "Frozen", "Bloodlit", "Starstruck", "Aurora"}
    Data.RARITIES  = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical"}
    Data.PETS      = {"Frog", "Bunny", "Robin", "Owl", "Cat", "Dog"}
    Data.PET_SIZES = {"Normal", "Big", "Huge", "Giant"}

    -- SellValueData — base harga per fruit dari decompile (fallback jika Networking nil)
    Data.SELL_VALUE_DATA = {
        Carrot=5, Strawberry=3, Tomato=9, Blueberry=5, Apple=12, Bamboo=800,
        Cactus=40, Pineapple=30, ["Green Bean"]=10, Banana=35, Grape=45,
        Mushroom=13000, Coconut=60, Mango=90, ["Dragon Fruit"]=150, Acorn=200,
        Cherry=350, Sunflower=1750, ["Venus Fly Trap"]=3000, Pomegranate=900,
        ["Poison Apple"]=900, ["Moon Bloom"]=9000, ["Dragon's Breath"]=3400,
        ["Poison Ivy"]=1700, ["Glow Mushroom"]=700, ["Ghost Pepper"]=2500,
        ["Horned Melon"]=200, Corn=34, ["Baby Cactus"]=70, Tulip=60,
        ["Venom Spitter"]=4000,
    }

    -- Packet IDs — semua dari Attribute di RemoteEvent (scanner verified)
    Data.PACKET = {
        PlantSeed           = 9,
        PurchaseSeed        = 120,   -- beli seed dari SeedShop (FIXED)
        SeedShopRestock     = 121,   -- personal restock (opsional)
        PurchaseCrate       = 122,
        CrateShopRestock    = 123,
        EquipGear           = 126,
        SellFruit           = 167,   -- jual buah (FIXED, bukan 4)
        OpenCrate           = 130,
        OpenEgg             = 139,
        ReplicateOpenEgg    = 140,
        LikeGarden          = 221,
        MailboxClaim        = 281,
    }

    ctx.Data = Data

    -- ====================== PLAYER ATTRIBUTES ======================
    -- PlotId: scanner detected Plot6 for this player
    ctx.MY_PLOT_ID       = player:GetAttribute("PlotId") or 6
    ctx.MAX_EQUIPPED_PETS = player:GetAttribute("MaxEquippedPets") or 6
    ctx.MAX_FRUIT_CAP    = player:GetAttribute("MaxFruitCapacity") or 100

    -- ====================== REMOTE REFERENCES ======================
    ctx.PacketRemote = ReplicatedStorage:FindFirstChild("SharedModules")
        and ReplicatedStorage.SharedModules:FindFirstChild("Packet")
        and ReplicatedStorage.SharedModules.Packet:FindFirstChild("RemoteEvent")

    -- Networking module (dari decompile StevenController — cara BENAR buat sell/plant/water)
    ctx.Networking = nil
    pcall(function()
        ctx.Networking = require(ReplicatedStorage.SharedModules.Networking)
    end)

    -- ====================== STATES ======================
    ctx.States = {
        -- Farm
        autoPlant = false,
        autoHarvest = false,
        autoWater = false,
        autoSprinkler = false,
        wateringCanTargets = {},    -- TABLE: watering can yang dipilih (multi-select)
        sprinklerTargets = {},      -- TABLE: sprinkler yang dipilih (multi-select)
        harvestFilterMutation = {},      -- TABLE: mutasi yang di-skip saat harvest (multi-select)
        plantSeedFilter = "All Seeds",
        plantRarityFilter = "All",
        perFruitDelay = 0.05,
        harvestLoopDelay = 2.0,
        notifyHarvest = false,
        autoPlantNotify = true,     -- notif saat siklus tanam selesai
        autoPlantAllSeeds = false,  -- tanam semua seed di backpack tanpa filter
        autoPlantTargets = {},      -- TABLE: seed yang dipilih untuk ditanam
        -- Shop
        autoBuySeed = false,
        autoBuySeedTarget = nil,            -- legacy (tidak dipakai jika targets kosong)
        autoBuySeedTargets = {},           -- TABLE: daftar seed dipilih (multi-select)
        autoBuyQuantity = 1,               -- jumlah yg dibeli per cycle (1/3/10/50)
        autoBuyQtyStr = "1",               -- versi string untuk dropdown
        autoBuyAll = false,                -- beli semua seed yg ada stoknya
        autoBuyGear = false,
        autoBuyGearTargets = {},           -- TABLE: daftar gear dipilih (multi-select)
        autoBuyGearAll = false,            -- beli semua gear yg ada stoknya
        gearBuyDelay = 0.05,               -- delay antar beli gear
        gearShopLoopDelay = 0.5,           -- loop delay cek stok gear
        notifyBuyGear = true,
        autoCrate = false,
        buyBeforeOpen = true,
        crateLoopDelay = 8,
        autoBuyCrate = false,
        autoBuyCrateTargets = {},          -- TABLE: daftar crate dipilih (multi-select)
        autoBuyCrateAll = false,           -- beli semua crate yg ada stoknya
        crateBuyDelay = 0.05,              -- delay antar beli crate
        crateShopLoopDelay = 0.5,          -- loop delay cek stok crate
        notifyBuyCrate = true,
        autoOpenCrate = false,
        crateOpenDelay = 8,                -- delay antar open (biar efek selesai)
        notifyOpenCrate = true,
        buyDelay = 0.05,                   -- delay antar beli (cepat)
        shopLoopDelay = 0.5,               -- loop delay (cek stock tiap 0.5s)
        notifyBuy = true,
        notifyCrate = true,
        alertRarity = "Legendary",
        -- Sell
        autoSell = false,
        autoUseDailyDeal = false,   -- otomatis pakai daily deal kalau tersedia (5x harga)
        sellDelay = 0.05,
        sellLoopDelay = 3,
        keepMutations = true,
        sellKeepMutation = {},       -- TABLE: mutasi spesifik yang di-keep saat auto-sell (multi-select)
        keepRarity = "Legendary",
        notifySell = false,
        -- Player
        lockWalkSpeed = false,
        walkSpeed = 31,
        lockJumpPower = false,
        jumpPower = 50,
        infiniteJump = false,
        fly = false,
        flySpeed = 25,
        antiAfk = true,
        -- Pets
        autoCatchWild = false,
        petFinderRarity = "All",     -- filter rarity di Pet Finder
        wildCatchTargets = {},       -- TABLE: nama pet yang dipilih untuk auto catch (kosong = semua)
        -- Eggs
        autoOpenEgg = false,
        eggLoopDelay = 5,
        -- Visuals
        espPlayers = false,
        espItems = false,
        espFruits = false,
        espMutations = false,
        fullBright = false,
        brightness = 5,
        noFog = false,
        noShadows = false,
        showPlantAge = false,
        showFruitWeight = false,
        -- Teleport
        tpDelay = 0,
        -- Utility
        autoAcceptGifts = false,
        autoBidAccept = false,
        showRestockTimer = false,
        -- Server
        autoRejoin = false,
        rejoinCondition = "Server Full",
        autoServerScanner = false,
        serverScannerRarity = "Mythic",
        serverScannerDelay = 8,
        -- Settings
        autoSaveConfig = true,
        minimizeToTray = false,
        showNotifications = true,
    }

    return ctx
end