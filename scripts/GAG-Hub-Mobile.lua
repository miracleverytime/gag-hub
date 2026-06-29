local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- ======================== PLATFORM DETECTION ========================
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Layout constants — otomatis menyesuaikan PC vs Mobile
local SIDEBAR_W   = isMobile and 0   or 240   -- mobile: tidak ada sidebar, pakai tab bar bawah
local TAB_BAR_H   = isMobile and 52  or 0
local TOPBAR_H    = isMobile and 44  or 50
local WINDOW_W    = isMobile and 0   or 900   -- mobile: fullscreen (scale 1,0)
local WINDOW_H    = isMobile and 0   or 600
local TOUCH_MIN   = isMobile and 44  or 36    -- minimum touch target height
local FONT_BODY   = isMobile and 14  or 13    -- body font size
local FONT_LABEL  = isMobile and 13  or 12    -- label/desc font size
local FONT_TINY   = isMobile and 12  or 11    -- muted/tiny text
local CORNER_R    = isMobile and 12  or 9     -- button corner radius

-- Kill semua loop dari inject sebelumnya (cegah double loop)
_G._MiracleHubSession = (_G._MiracleHubSession or 0) + 1
local _SESSION = _G._MiracleHubSession

-- Remove existing GUI if any
local existingGui = playerGui:FindFirstChild("MiracleHub")
if existingGui then existingGui:Destroy() end

-- ======================== COLORS ========================
local Colors = {
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
}

-- ======================== GAME DATA (from scanner) ========================
-- Full seed list from ReplicatedStorage.StockValues.SeedShop.Items (scanner verified)
local SEEDS = {
    "Carrot", "Strawberry", "Blueberry", "Tulip", "Tomato", "Apple", "Bamboo",
    "Corn", "Cactus", "Pineapple", "Mushroom", "Green Bean", "Banana", "Grape",
    "Coconut", "Mango", "Dragon Fruit", "Acorn", "Cherry", "Sunflower",
    "Venus Fly Trap", "Pomegranate", "Poison Apple", "Venom Spitter",
    "Moon Bloom", "Dragon's Breath", "Ghost Pepper", "Poison Ivy",
    "Baby Cactus", "Glow Mushroom", "Romanesco", "Horned Melon",
    "Hypnobloom", "Gold", "Rainbow",
}
-- Gear list dari GearShopData (semua item yg ada di GearShop, exclude HideFromShop jika diinginkan)
local GEARS = {
    "Common Watering Can", "Common Sprinkler", "Sign", "Megaphone",
    "Uncommon Sprinkler", "Rare Sprinkler", "Legendary Sprinkler", "Super Sprinkler",
    "Wheelbarrow", "Strawberry Sniper", "Trowel",
    "Speed Mushroom", "Jump Mushroom", "Shrink Mushroom", "Supersize Mushroom",
    "Invisibility Mushroom", "Gnome", "Teleporter",
    "Super Watering Can", "Basic Pot", "Flashbang",
    "Player Magnet", "Grappling Hook",
    "Legendary Pet Teleporter", "Mythic Pet Teleporter", "Super Pet Teleporter",
}
local CRATES = {
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
local CRATE_COST = {
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
local MUTATIONS = {"None", "Gold", "Electric", "Rainbow", "Frozen"}
local RARITIES = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical"}
local PETS = {"Frog", "Bunny", "Robin", "Owl", "Cat", "Dog"}
local PET_SIZES = {"Normal", "Big", "Huge", "Giant"}

-- PlotId: scanner detected Plot6 for this player
local MY_PLOT_ID = player:GetAttribute("PlotId") or 6
local MAX_EQUIPPED_PETS = player:GetAttribute("MaxEquippedPets") or 6
local MAX_FRUIT_CAP = player:GetAttribute("MaxFruitCapacity") or 100

-- Remote references
local PacketRemote = game:GetService("ReplicatedStorage"):FindFirstChild("SharedModules")
    and game:GetService("ReplicatedStorage").SharedModules:FindFirstChild("Packet")
    and game:GetService("ReplicatedStorage").SharedModules.Packet:FindFirstChild("RemoteEvent")

-- Networking module (dari decompile StevenController — cara BENAR buat sell)
-- Networking.NPCS.SellAll:Fire() → jual semua inventory
-- Networking.NPCS.SellFruit:Fire(fruitId) → jual 1 buah by ID
-- Networking.NPCS.PreviewSellAll:Fire() → preview total harga {FruitCount, TotalValue, TotalBaseValue}
-- Networking.NPCS.CheckDailyDeal:Fire() → cek daily deal {Available}
-- Networking.NPCS.UseDailyDealAll:Fire() → pakai daily deal semua
local Networking = nil
pcall(function()
    Networking = require(game:GetService("ReplicatedStorage").SharedModules.Networking)
end)

-- SellValueData — base harga per fruit dari decompile (fallback jika Networking nil)
local SELL_VALUE_DATA = {
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
local PACKET = {
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

-- ======================== STATES ========================
local States = {
    -- Farm
    autoPlant = false,
    autoHarvest = false,
    autoWater = false,
    autoSprinkler = false,
    harvestFilterMutation = "None",
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
    -- Settings
    autoSaveConfig = true,
    minimizeToTray = false,
    showNotifications = true,
}

-- ======================== UTILITY FUNCTIONS ========================
local function Create(className, properties)
    local instance = Instance.new(className)
    for prop, value in pairs(properties or {}) do
        instance[prop] = value
    end
    return instance
end

local function CreateCorner(parent, radius)
    return Create("UICorner", {CornerRadius = UDim.new(0, radius or 8), Parent = parent})
end

local function CreateStroke(parent, color, thickness)
    return Create("UIStroke", {Color = color or Colors.Border, Thickness = thickness or 1, Parent = parent})
end

local function CreatePadding(parent, padding)
    return Create("UIPadding", {
        PaddingLeft = UDim.new(0, padding or 12),
        PaddingRight = UDim.new(0, padding or 12),
        PaddingTop = UDim.new(0, padding or 12),
        PaddingBottom = UDim.new(0, padding or 12),
        Parent = parent,
    })
end

local function CreateListLayout(parent, padding, direction)
    return Create("UIListLayout", {
        Padding = UDim.new(0, padding or 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        FillDirection = direction or Enum.FillDirection.Vertical,
        Parent = parent,
    })
end

local function Tween(instance, properties, duration, easingStyle, easingDirection)
    local tween = TweenService:Create(
        instance,
        TweenInfo.new(duration or 0.3, easingStyle or Enum.EasingStyle.Quad, easingDirection or Enum.EasingDirection.Out),
        properties
    )
    tween:Play()
    return tween
end

-- ======================== HELPER: FIRE PROXIMITY PROMPT ========================
local function FirePrompt(prompt)
    if not prompt then return false end
    if prompt:IsA("ProximityPrompt") then
        local hd = prompt.HoldDuration
        if hd and hd > 0 then
            prompt:InputHoldBegin()
            task.wait(hd + 0.05)
            prompt:InputHoldEnd()
        else
            fireproximityprompt(prompt)
        end
        return true
    end
    return false
end

-- Safe fireproximityprompt wrapper (executor function)
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

-- ======================== NOTIFICATION SYSTEM ========================
local notifCount = 0
local function Notify(title, message, color, duration)
    if not States.showNotifications then return end
    duration = duration or 4
    notifCount = notifCount + 1
    local yOffset = (notifCount - 1) * 72

    -- Mobile: notif di atas tengah layar, lebih lebar
    -- PC: notif di kanan atas
    local notifW = isMobile and 320 or 280
    local notifX = isMobile and UDim2.new(0.5, -(notifW/2), 0, 56 + yOffset) or UDim2.new(1, -290, 0, 16 + yOffset)
    local notifStartX = isMobile and UDim2.new(0.5, -(notifW/2), 0, -80 + yOffset) or UDim2.new(1, 10, 0, 16 + yOffset)

    local notifFrame = Create("Frame", {
        Parent = playerGui:FindFirstChild("MiracleHub"),
        Size = UDim2.new(0, notifW, 0, 60),
        Position = notifStartX,
        BackgroundColor3 = Colors.BackgroundLight,
        BorderSizePixel = 0,
        ZIndex = 200,
    })
    CreateCorner(notifFrame, 10)
    CreateStroke(notifFrame, color or Colors.Border, 1)

    local bar = Create("Frame", {
        Parent = notifFrame,
        Size = UDim2.new(0, 3, 1, 0),
        BackgroundColor3 = color or Colors.Success,
        BorderSizePixel = 0,
        ZIndex = 201,
    })
    CreateCorner(bar, 2)

    Create("TextLabel", {
        Parent = notifFrame,
        Size = UDim2.new(1, -44, 0, 20),
        Position = UDim2.new(0, 12, 0, 8),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Colors.TextPrimary,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 201,
    })
    Create("TextLabel", {
        Parent = notifFrame,
        Size = UDim2.new(1, -20, 0, 18),
        Position = UDim2.new(0, 12, 0, 28),
        BackgroundTransparency = 1,
        Text = message,
        TextColor3 = Colors.TextMuted,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 201,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    -- Tombol close (×) di sudut kanan atas
    local closeBtn = Create("TextButton", {
        Parent = notifFrame,
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(1, -26, 0, 6),
        BackgroundTransparency = 1,
        Text = "×",
        TextColor3 = Colors.TextMuted,
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
        ZIndex = 202,
        AutoButtonColor = false,
    })

    notifFrame.Position = notifStartX
    Tween(notifFrame, {Position = notifX}, 0.3, Enum.EasingStyle.Back)

    local dismissed = false
    local function DismissNotif()
        if dismissed then return end
        dismissed = true
        Tween(notifFrame, {Position = notifStartX}, 0.3)
        task.wait(0.35)
        if notifFrame and notifFrame.Parent then notifFrame:Destroy() end
        notifCount = math.max(0, notifCount - 1)
    end

    closeBtn.MouseButton1Click:Connect(DismissNotif)
    task.delay(duration, DismissNotif)
end

-- Notifikasi stok khusus: vertikal, scrollable, ada tombol close, durasi panjang
local _stockNotif = nil
local function NotifyStok(available, color, duration, title)
    if not States.showNotifications then return end
    duration = duration or 30

    -- Tutup notif stok sebelumnya jika masih tampil
    if _stockNotif and _stockNotif.Parent then
        _stockNotif:Destroy()
        _stockNotif = nil
    end

    local lineH      = 20
    local headerH    = 36
    local maxVisible = 8
    local visibleCount = math.min(#available, maxVisible)
    local listH      = visibleCount * lineH
    local totalH     = headerH + listH + 16

    local notifFrame = Create("Frame", {
        Parent = playerGui:FindFirstChild("MiracleHub"),
        Size = UDim2.new(0, 290, 0, totalH),
        Position = UDim2.new(1, 10, 0, 16),
        BackgroundColor3 = Colors.BackgroundLight,
        BorderSizePixel = 0,
        ZIndex = 200,
    })
    CreateCorner(notifFrame, 10)
    CreateStroke(notifFrame, color or Colors.Success, 1)
    _stockNotif = notifFrame

    -- Left color bar
    Create("Frame", {
        Parent = notifFrame,
        Size = UDim2.new(0, 3, 1, 0),
        BackgroundColor3 = color or Colors.Success,
        BorderSizePixel = 0,
        ZIndex = 201,
    })

    -- Judul
    Create("TextLabel", {
        Parent = notifFrame,
        Size = UDim2.new(1, -50, 0, 22),
        Position = UDim2.new(0, 12, 0, 7),
        BackgroundTransparency = 1,
        Text = title or ("🌱 Stok Ada (" .. #available .. " seed)"),
        TextColor3 = Colors.TextPrimary,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 201,
    })

    -- Tombol close
    local closeBtn = Create("TextButton", {
        Parent = notifFrame,
        Size = UDim2.new(0, 22, 0, 22),
        Position = UDim2.new(1, -28, 0, 7),
        BackgroundColor3 = Colors.Surface,
        Text = "x",
        TextColor3 = Colors.TextMuted,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
        ZIndex = 202,
        AutoButtonColor = false,
    })
    CreateCorner(closeBtn, 5)

    -- Separator
    Create("Frame", {
        Parent = notifFrame,
        Size = UDim2.new(1, -18, 0, 1),
        Position = UDim2.new(0, 9, 0, 31),
        BackgroundColor3 = Colors.Border,
        BorderSizePixel = 0,
        ZIndex = 201,
    })

    -- Scrollable list baris per baris
    local scrollFrame = Create("ScrollingFrame", {
        Parent = notifFrame,
        Size = UDim2.new(1, -18, 0, listH),
        Position = UDim2.new(0, 12, 0, headerH),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Colors.Border,
        CanvasSize = UDim2.new(0, 0, 0, #available * lineH),
        ZIndex = 201,
    })
    CreateListLayout(scrollFrame, 0)

    for _, entry in ipairs(available) do
        Create("TextLabel", {
            Parent = scrollFrame,
            Size = UDim2.new(1, 0, 0, lineH),
            BackgroundTransparency = 1,
            Text = "• " .. entry,
            TextColor3 = Colors.TextSecondary,
            TextSize = 11,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 202,
        })
    end

    -- Slide in dari kanan
    Tween(notifFrame, {Position = UDim2.new(1, -300, 0, 16)}, 0.3, Enum.EasingStyle.Back)

    local dismissed = false
    local function DismissStok()
        if dismissed then return end
        dismissed = true
        Tween(notifFrame, {Position = UDim2.new(1, 10, 0, 16)}, 0.3)
        task.wait(0.35)
        if notifFrame and notifFrame.Parent then notifFrame:Destroy() end
        _stockNotif = nil
    end

    closeBtn.MouseButton1Click:Connect(DismissStok)
    task.delay(duration, DismissStok)
end

local function GetMutationColor(mutation)
    if mutation == "Gold" then return Colors.Gold
    elseif mutation == "Electric" then return Colors.Electric
    elseif mutation == "Rainbow" then return Colors.Rainbow
    elseif mutation == "Frozen" then return Colors.Frozen
    else return Colors.TextMuted end
end

-- ======================== MAIN GUI ========================
local ScreenGui = Create("ScreenGui", {
    Name = "MiracleHub",
    Parent = playerGui,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

-- Loading Screen
local LoadingScreen = Create("Frame", {
    Name = "LoadingScreen",
    Parent = ScreenGui,
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    ZIndex = 100,
})
local LoadingContainer = Create("Frame", {
    Parent = LoadingScreen,
    Size = UDim2.new(0, 420, 0, 170),
    Position = UDim2.new(0.5, -210, 0.5, -85),
    BackgroundColor3 = Colors.BackgroundLight,
    BorderSizePixel = 0,
    ZIndex = 101,
})
CreateCorner(LoadingContainer, 16)
CreateStroke(LoadingContainer, Colors.Border, 1)
Create("TextLabel", {Parent=LoadingContainer, Size=UDim2.new(1,0,0,30), Position=UDim2.new(0,0,0,20), BackgroundTransparency=1, Text="Miracle Hub", TextColor3=Colors.Success, TextSize=24, Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=102})
Create("TextLabel", {Parent=LoadingContainer, Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,0,0,52), BackgroundTransparency=1, Text="Grow A Garden 2  •  Full Feature Build", TextColor3=Colors.TextMuted, TextSize=13, Font=Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=102})
local LoadingBarBg = Create("Frame", {Parent=LoadingContainer, Size=UDim2.new(1,-60,0,8), Position=UDim2.new(0,30,0,92), BackgroundColor3=Colors.BackgroundLighter, BorderSizePixel=0, ZIndex=102})
CreateCorner(LoadingBarBg, 4)
local LoadingBarFill = Create("Frame", {Parent=LoadingBarBg, Size=UDim2.new(0,0,1,0), BackgroundColor3=Colors.Success, BorderSizePixel=0, ZIndex=103})
CreateCorner(LoadingBarFill, 4)
local LoadingPercent = Create("TextLabel", {Parent=LoadingContainer, Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,0,0,112), BackgroundTransparency=1, Text="0%", TextColor3=Colors.Success, TextSize=14, Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=102})
local LoadingStatus = Create("TextLabel", {Parent=LoadingContainer, Size=UDim2.new(1,0,0,18), Position=UDim2.new(0,0,0,138), BackgroundTransparency=1, Text="Initializing...", TextColor3=Colors.TextMuted, TextSize=12, Font=Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=102})

-- Main Frame
local originalSize = isMobile and UDim2.new(1, 0, 1, 0) or UDim2.new(0, 900, 0, 600)
local originalPos  = isMobile and UDim2.new(0, 0, 0, 0) or UDim2.new(0.5, -450, 0.5, -300)
local MainFrame = Create("Frame", {
    Name = "MainFrame",
    Parent = ScreenGui,
    Size = originalSize,
    Position = originalPos,
    BackgroundColor3 = Colors.Background,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Visible = false,
})
CreateCorner(MainFrame, isMobile and 0 or 16)

-- Top Bar
local TopBar = Create("Frame", {
    Name = "TopBar",
    Parent = MainFrame,
    Size = UDim2.new(1, 0, 0, TOPBAR_H),
    BackgroundColor3 = Colors.BackgroundLight,
    BorderSizePixel = 0,
})
CreateCorner(TopBar, 0)

for i, xpos in ipairs({0, 16, 32}) do
    local dot = Create("Frame", {
        Parent = TopBar,
        Size = UDim2.new(0, 10, 0, 10),
        Position = UDim2.new(0, 16 + xpos, 0.5, -5),
        BackgroundColor3 = Colors.TextPrimary,
        BorderSizePixel = 0,
        Visible = not isMobile,
    })
    CreateCorner(dot, 5)
end

local SearchBar = Create("Frame", {
    Parent = TopBar,
    Size = isMobile and UDim2.new(1, -100, 0, 32) or UDim2.new(0, 280, 0, 34),
    Position = isMobile and UDim2.new(0, 8, 0.5, -16) or UDim2.new(0, 120, 0.5, -17),
    BackgroundColor3 = Colors.Background,
    BorderSizePixel = 0,
})
CreateCorner(SearchBar, 8)
CreateStroke(SearchBar, Colors.Border, 1)
Create("TextLabel", {Parent=SearchBar, Size=UDim2.new(0,30,1,0), BackgroundTransparency=1, Text="🔍", TextColor3=Colors.TextMuted, TextSize=14, Font=Enum.Font.Gotham})
local SearchBox = Create("TextBox", {
    Parent = SearchBar,
    Size = UDim2.new(1,-40,1,0),
    Position = UDim2.new(0,30,0,0),
    BackgroundTransparency = 1,
    Text = "",
    PlaceholderText = "Search features...",
    PlaceholderColor3 = Colors.TextMuted,
    TextColor3 = Colors.TextPrimary,
    TextSize = FONT_BODY,
    Font = Enum.Font.Gotham,
    ClearTextOnFocus = false,
})

local PageTitle = Create("TextLabel", {
    Parent = TopBar,
    Size = UDim2.new(0, 200, 1, 0),
    Position = isMobile and UDim2.new(1, -200, 0, 0) or UDim2.new(0.5, -100, 0, 0),
    BackgroundTransparency = 1,
    Text = "Farm",
    TextColor3 = Colors.TextPrimary,
    TextSize = isMobile and 16 or 18,
    Font = Enum.Font.GothamBold,
    TextXAlignment = isMobile and Enum.TextXAlignment.Right or Enum.TextXAlignment.Center,
})

local RightControls = Create("Frame", {
    Parent = TopBar,
    Size = UDim2.new(0, 80, 1, 0),
    Position = UDim2.new(1, -80, 0, 0),
    BackgroundTransparency = 1,
})

local CloseButton = Create("TextButton", {
    Parent = RightControls,
    Size = UDim2.new(0, isMobile and 36 or 32, 0, isMobile and 36 or 32),
    Position = isMobile and UDim2.new(0, 36, 0.5, -18) or UDim2.new(0, 44, 0.5, -16),
    BackgroundColor3 = Colors.Surface,
    Text = "×",
    TextColor3 = Colors.TextSecondary,
    TextSize = isMobile and 20 or 18,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0,
    AutoButtonColor = false,
})
CreateCorner(CloseButton, 6)

local MinimizeButton = Create("TextButton", {
    Parent = RightControls,
    Size = UDim2.new(0, 32, 0, 32),
    Position = UDim2.new(0, 8, 0.5, -16),
    BackgroundColor3 = Colors.Surface,
    Text = "−",
    TextColor3 = Colors.TextSecondary,
    TextSize = 18,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Visible = not isMobile,  -- tidak tampil di mobile
})
CreateCorner(MinimizeButton, 6)

CloseButton.MouseEnter:Connect(function() Tween(CloseButton, {BackgroundColor3 = Color3.fromRGB(180, 80, 80), TextColor3 = Colors.TextPrimary}, 0.2) end)
CloseButton.MouseLeave:Connect(function() Tween(CloseButton, {BackgroundColor3 = Colors.Surface, TextColor3 = Colors.TextSecondary}, 0.2) end)
MinimizeButton.MouseEnter:Connect(function() Tween(MinimizeButton, {BackgroundColor3 = Colors.SurfaceLight, TextColor3 = Colors.TextPrimary}, 0.2) end)
MinimizeButton.MouseLeave:Connect(function() Tween(MinimizeButton, {BackgroundColor3 = Colors.Surface, TextColor3 = Colors.TextSecondary}, 0.2) end)

-- Sidebar
local Sidebar = Create("Frame", {
    Parent = MainFrame,
    Size = UDim2.new(0, SIDEBAR_W, 1, -TOPBAR_H),
    Position = UDim2.new(0, 0, 0, TOPBAR_H),
    BackgroundColor3 = Colors.BackgroundLight,
    BorderSizePixel = 0,
    Visible = not isMobile,
})

local SidebarContent = Create("ScrollingFrame", {
    Parent = Sidebar,
    Size = UDim2.new(1, 0, 1, -80),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Colors.Border,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
})
CreatePadding(SidebarContent, 12)
CreateListLayout(SidebarContent, 3)

local HubCard = Create("Frame", {
    Parent = SidebarContent,
    Size = UDim2.new(1, 0, 0, 60),
    BackgroundColor3 = Colors.BackgroundLighter,
    BorderSizePixel = 0,
    LayoutOrder = 0,
})
CreateCorner(HubCard, 12)
CreatePadding(HubCard, 14)
Create("TextLabel", {Parent=HubCard, Size=UDim2.new(1,0,0,22), BackgroundTransparency=1, Text="Miracle Hub", TextColor3=Colors.Accent, TextSize=17, Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left})
Create("TextLabel", {Parent=HubCard, Size=UDim2.new(1,0,0,16), Position=UDim2.new(0,0,0,24), BackgroundTransparency=1, Text="Grow A Garden 2  •  Full Edition", TextColor3=Colors.TextMuted, TextSize=11, Font=Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Left})

local SidebarButtons = {}
local ActivePage = "Farm"

local function CreateSectionHeader(parent, text, layoutOrder)
    return Create("TextLabel", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Colors.TextMuted,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = layoutOrder,
    })
end

local function CreateSidebarButton(parent, icon, text, layoutOrder)
    local button = Create("TextButton", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
        Text = "",
        BorderSizePixel = 0,
        LayoutOrder = layoutOrder,
        AutoButtonColor = false,
    })
    CreateCorner(button, 9)

    local indicator = Create("Frame", {
        Parent = button,
        Size = UDim2.new(0, 3, 0, 18),
        Position = UDim2.new(0, 0, 0.5, -9),
        BackgroundColor3 = Colors.Success,
        BorderSizePixel = 0,
        Visible = false,
    })
    CreateCorner(indicator, 2)

    local iconLabel = Create("TextLabel", {
        Parent = button,
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(0, 14, 0.5, -12),
        BackgroundTransparency = 1,
        Text = icon,
        TextColor3 = Colors.TextSecondary,
        TextSize = 17,
        Font = Enum.Font.Gotham,
    })
    local textLabel = Create("TextLabel", {
        Parent = button,
        Size = UDim2.new(1, -50, 1, 0),
        Position = UDim2.new(0, 44, 0, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Colors.TextSecondary,
        TextSize = 14,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    SidebarButtons[text] = {button=button, indicator=indicator, icon=iconLabel, label=textLabel}

    button.MouseEnter:Connect(function()
        if ActivePage ~= text then
            Tween(button, {BackgroundTransparency = 0.85}, 0.15)
            button.BackgroundColor3 = Colors.Surface
        end
    end)
    button.MouseLeave:Connect(function()
        if ActivePage ~= text then
            Tween(button, {BackgroundTransparency = 1}, 0.15)
        end
    end)

    return button
end

-- Build sidebar
CreateSectionHeader(SidebarContent, "AUTOMATION", 1)
local BtnFarm = CreateSidebarButton(SidebarContent, "🌱", "Farm", 2)
local BtnPlot = CreateSidebarButton(SidebarContent, "📐", "Plot", 3)
local BtnShop = CreateSidebarButton(SidebarContent, "🛒", "Shop", 4)
local BtnSell = CreateSidebarButton(SidebarContent, "💰", "Sell", 5)
local BtnPets = CreateSidebarButton(SidebarContent, "🐾", "Pets", 6)
local BtnEggs = CreateSidebarButton(SidebarContent, "🥚", "Eggs", 7)

CreateSectionHeader(SidebarContent, "PLAYER", 8)
local BtnPlayer = CreateSidebarButton(SidebarContent, "👤", "Player", 9)
local BtnVisuals = CreateSidebarButton(SidebarContent, "👁", "Visuals", 10)
local BtnTeleport = CreateSidebarButton(SidebarContent, "📍", "Teleport", 11)

CreateSectionHeader(SidebarContent, "MISC", 12)
local BtnUtility = CreateSidebarButton(SidebarContent, "🔧", "Utility", 13)
local BtnMailer = CreateSidebarButton(SidebarContent, "✉", "Mailer", 14)
local BtnInfo = CreateSidebarButton(SidebarContent, "ℹ", "Info", 15)
local BtnServer = CreateSidebarButton(SidebarContent, "🌐", "Server", 16)
local BtnSettings = CreateSidebarButton(SidebarContent, "⚙", "Settings", 17)

-- Profile card
local ProfileCard = Create("Frame", {
    Parent = Sidebar,
    Size = UDim2.new(1, -24, 0, 64),
    Position = UDim2.new(0, 12, 1, -74),
    BackgroundColor3 = Colors.BackgroundLighter,
    BorderSizePixel = 0,
})
CreateCorner(ProfileCard, 12)
local ProfileAvatar = Create("ImageLabel", {
    Parent = ProfileCard,
    Size = UDim2.new(0, 44, 0, 44),
    Position = UDim2.new(0, 10, 0.5, -22),
    BackgroundColor3 = Colors.Surface,
    Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150",
    BorderSizePixel = 0,
})
CreateCorner(ProfileAvatar, 22)
Create("TextLabel", {Parent=ProfileCard, Size=UDim2.new(1,-70,0,18), Position=UDim2.new(0,62,0,12), BackgroundTransparency=1, Text=player.DisplayName or player.Name, TextColor3=Colors.TextPrimary, TextSize=13, Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd})
Create("TextLabel", {Parent=ProfileCard, Size=UDim2.new(1,-70,0,14), Position=UDim2.new(0,62,0,32), BackgroundTransparency=1, Text="@"..player.Name, TextColor3=Colors.TextMuted, TextSize=11, Font=Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Left})
local PrimeLabel = Create("TextLabel", {Parent=ProfileCard, Size=UDim2.new(0,50,0,16), Position=UDim2.new(0,62,0,46), BackgroundTransparency=1, Text="⭐ Prime", TextColor3=Colors.Warning, TextSize=10, Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left})
if player:GetAttribute("PrimeEnabled") then
    PrimeLabel.Text = "⭐ Prime"
    PrimeLabel.TextColor3 = Colors.Warning
else
    PrimeLabel.Text = "Free"
    PrimeLabel.TextColor3 = Colors.TextMuted
end

-- Content Area
local ContentArea = Create("Frame", {
    Parent = MainFrame,
    Size = isMobile
        and UDim2.new(1, 0, 1, -(TOPBAR_H + TAB_BAR_H))
        or  UDim2.new(1, -240, 1, -50),
    Position = isMobile
        and UDim2.new(0, 0, 0, TOPBAR_H)
        or  UDim2.new(0, 240, 0, 50),
    BackgroundColor3 = Colors.Background,
    BorderSizePixel = 0,
    ClipsDescendants = true,
})

local ContentScroll = Create("ScrollingFrame", {
    Parent = ContentArea,
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = isMobile and 2 or 4,
    ScrollBarImageColor3 = Colors.Border,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
})
CreatePadding(ContentScroll, isMobile and 12 or 20)
local ContentLayout = CreateListLayout(ContentScroll, 14)

-- ======================== MOBILE TAB BAR ========================
-- Di mobile, navigasi pakai tab bar di bagian bawah (seperti app Android)
-- Pages dikelompokkan: tab utama (icon+label) + More drawer untuk halaman lainnya

local MobileTabBar = nil
local MobileTabButtons = {}
local MobileMoreDrawer = nil
local MobileMoreVisible = false

if isMobile then
    MobileTabBar = Create("Frame", {
        Parent = MainFrame,
        Size = UDim2.new(1, 0, 0, TAB_BAR_H),
        Position = UDim2.new(0, 0, 1, -TAB_BAR_H),
        BackgroundColor3 = Colors.BackgroundLight,
        BorderSizePixel = 0,
        ZIndex = 10,
    })
    CreateStroke(MobileTabBar, Colors.Border, 1)

    -- Tab utama yang selalu kelihatan
    local MAIN_TABS = {
        {"🌱", "Farm"},
        {"🛒", "Shop"},
        {"💰", "Sell"},
        {"🐾", "Pets"},
        {"☰",  "More"},
    }

    local tabW = 1 / #MAIN_TABS
    for i, tab in ipairs(MAIN_TABS) do
        local icon, label = tab[1], tab[2]
        local btn = Create("TextButton", {
            Parent = MobileTabBar,
            Size = UDim2.new(tabW, 0, 1, 0),
            Position = UDim2.new(tabW * (i-1), 0, 0, 0),
            BackgroundTransparency = 1,
            Text = "",
            BorderSizePixel = 0,
            AutoButtonColor = false,
            ZIndex = 11,
        })
        local iconLbl = Create("TextLabel", {
            Parent = btn,
            Size = UDim2.new(1, 0, 0, 22),
            Position = UDim2.new(0, 0, 0, 4),
            BackgroundTransparency = 1,
            Text = icon,
            TextColor3 = Colors.TextMuted,
            TextSize = 18,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 12,
        })
        local textLbl = Create("TextLabel", {
            Parent = btn,
            Size = UDim2.new(1, 0, 0, 14),
            Position = UDim2.new(0, 0, 0, 28),
            BackgroundTransparency = 1,
            Text = label,
            TextColor3 = Colors.TextMuted,
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 12,
        })
        -- Active indicator bar di atas tab
        local indicator = Create("Frame", {
            Parent = btn,
            Size = UDim2.new(0.5, 0, 0, 2),
            Position = UDim2.new(0.25, 0, 0, 0),
            BackgroundColor3 = Colors.Success,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 12,
        })
        CreateCorner(indicator, 1)

        MobileTabButtons[label] = {btn=btn, icon=iconLbl, text=textLbl, indicator=indicator}
    end

    -- More drawer — slide up dari bawah
    MobileMoreDrawer = Create("Frame", {
        Parent = MainFrame,
        Size = UDim2.new(1, 0, 0, 0),   -- mulai collapse
        Position = UDim2.new(0, 0, 1, -TAB_BAR_H),
        BackgroundColor3 = Colors.BackgroundLight,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 20,
        Visible = false,
    })
    CreateStroke(MobileMoreDrawer, Colors.Border, 1)

    -- Grid tombol di drawer
    local drawerScroll = Create("ScrollingFrame", {
        Parent = MobileMoreDrawer,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 21,
    })
    CreatePadding(drawerScroll, 10)

    local drawerGrid = Create("Frame", {
        Parent = drawerScroll,
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 21,
    })
    local gridLayout = Create("UIGridLayout", {
        Parent = drawerGrid,
        CellSize = UDim2.new(0.5, -6, 0, 48),
        CellPaddingSize = UDim2.new(0, 8, 0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        FillDirection = Enum.FillDirection.Horizontal,
    })

    local DRAWER_PAGES = {
        {"📐","Plot"}, {"👤","Player"}, {"👁","Visuals"},
        {"📍","Teleport"}, {"🔧","Utility"}, {"✉","Mailer"},
        {"ℹ","Info"}, {"🌐","Server"}, {"⚙","Settings"}, {"🥚","Eggs"},
    }
    for i, p in ipairs(DRAWER_PAGES) do
        local dIcon, dLabel = p[1], p[2]
        local dBtn = Create("TextButton", {
            Parent = drawerGrid,
            Size = UDim2.new(0, 100, 0, 48),
            BackgroundColor3 = Colors.BackgroundLighter,
            Text = "",
            BorderSizePixel = 0,
            AutoButtonColor = false,
            LayoutOrder = i,
            ZIndex = 22,
        })
        CreateCorner(dBtn, 10)
        Create("TextLabel", {
            Parent = dBtn,
            Size = UDim2.new(1, 0, 0, 22),
            Position = UDim2.new(0, 0, 0, 4),
            BackgroundTransparency = 1,
            Text = dIcon,
            TextColor3 = Colors.TextSecondary,
            TextSize = 16,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 23,
        })
        Create("TextLabel", {
            Parent = dBtn,
            Size = UDim2.new(1, 0, 0, 14),
            Position = UDim2.new(0, 0, 0, 26),
            BackgroundTransparency = 1,
            Text = dLabel,
            TextColor3 = Colors.TextSecondary,
            TextSize = 11,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 23,
        })
        MobileTabButtons[dLabel] = {btn=dBtn, icon=nil, text=nil, indicator=nil}
        dBtn.MouseButton1Click:Connect(function()
            -- Tutup drawer lalu navigate
            MobileMoreVisible = false
            Tween(MobileMoreDrawer, {Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 1, -TAB_BAR_H)}, 0.25, Enum.EasingStyle.Quart)
            task.delay(0.26, function() MobileMoreDrawer.Visible = false end)
            SetActivePage(dLabel)
        end)
        dBtn.MouseEnter:Connect(function() Tween(dBtn, {BackgroundColor3 = Colors.Surface}, 0.1) end)
        dBtn.MouseLeave:Connect(function() Tween(dBtn, {BackgroundColor3 = Colors.BackgroundLighter}, 0.1) end)
    end
end

-- ======================== PAGE SYSTEM ========================
local Pages = {}

local function ClearContent()
    for _, child in ipairs(ContentScroll:GetChildren()) do
        if child:IsA("GuiObject") and child.Name ~= "UIPadding" and child.Name ~= "UIListLayout" then
            child:Destroy()
        end
    end
end

local function SetActivePage(pageName)
    if SidebarButtons[ActivePage] then
        local sb = SidebarButtons[ActivePage]
        sb.indicator.Visible = false
        Tween(sb.button, {BackgroundTransparency = 1}, 0.15)
        sb.label.TextColor3 = Colors.TextSecondary
        sb.icon.TextColor3 = Colors.TextSecondary
        sb.button.BackgroundColor3 = Colors.Surface
    end

    -- Mobile: deactivate previous tab
    if isMobile and MobileTabButtons[ActivePage] then
        local mt = MobileTabButtons[ActivePage]
        if mt.indicator then mt.indicator.Visible = false end
        if mt.icon then mt.icon.TextColor3 = Colors.TextMuted end
        if mt.text then mt.text.TextColor3 = Colors.TextMuted end
    end

    ActivePage = pageName
    PageTitle.Text = pageName

    if SidebarButtons[pageName] then
        local sb = SidebarButtons[pageName]
        sb.indicator.Visible = true
        sb.button.BackgroundColor3 = Colors.BackgroundLighter
        Tween(sb.button, {BackgroundTransparency = 0}, 0.15)
        sb.label.TextColor3 = Colors.TextPrimary
        sb.label.Font = Enum.Font.GothamBold
        sb.icon.TextColor3 = Colors.TextPrimary
    end

    -- Mobile: activate new tab
    if isMobile and MobileTabButtons[pageName] then
        local mt = MobileTabButtons[pageName]
        if mt.indicator then mt.indicator.Visible = true end
        if mt.icon then mt.icon.TextColor3 = Colors.Success end
        if mt.text then mt.text.TextColor3 = Colors.Success end
    end

    ClearContent()
    if Pages[pageName] then Pages[pageName]() end
    ContentScroll.CanvasPosition = Vector2.new(0, 0)
end

-- ======================== UI COMPONENT BUILDERS ========================

local function CreateSectionCard(title, layoutOrder, accentColor)
    local card = Create("Frame", {
        Parent = ContentScroll,
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = Colors.BackgroundLight,
        BorderSizePixel = 0,
        LayoutOrder = layoutOrder,
        AutomaticSize = Enum.AutomaticSize.Y,
    })
    CreateCorner(card, 13)
    CreatePadding(card, 18)
    local cardLayout = CreateListLayout(card, 12)

    local header = Create("Frame", {
        Parent = card,
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        LayoutOrder = 0,
    })

    if accentColor then
        local accentBar = Create("Frame", {
            Parent = header,
            Size = UDim2.new(0, 3, 0, 20),
            Position = UDim2.new(0, 0, 0.5, -10),
            BackgroundColor3 = accentColor,
            BorderSizePixel = 0,
        })
        CreateCorner(accentBar, 2)
    end

    Create("TextLabel", {
        Parent = header,
        Size = UDim2.new(1, -50, 1, 0),
        Position = UDim2.new(0, accentColor and 10 or 0, 0, 0),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Colors.Accent,
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local dropBtn = Create("TextButton", {
        Parent = header,
        Size = UDim2.new(0, 40, 0, 40),
        Position = UDim2.new(1, -44, 0.5, -20),
        BackgroundColor3 = Colors.Surface,
        Text = "▼",
        TextColor3 = Colors.TextSecondary,
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
        AutoButtonColor = false,
    })
    CreateCorner(dropBtn, 9)

    local content = Create("Frame", {
        Parent = card,
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false,
    })
    CreateListLayout(content, 10)

    local collapsed = true
    dropBtn.Rotation = -90
    dropBtn.MouseButton1Click:Connect(function()
        collapsed = not collapsed
        content.Visible = not collapsed
        Tween(dropBtn, {Rotation = collapsed and -90 or 0}, 0.25)
    end)

    return card, content
end

local function CreateSubHeader(parent, text)
    local h = Create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
    })
    Create("TextLabel", {
        Parent = h,
        Size = UDim2.new(0, 200, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Colors.TextSecondary,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    Create("Frame", {
        Parent = h,
        Size = UDim2.new(1, -210, 0, 1),
        Position = UDim2.new(0, 210, 0.5, 0),
        BackgroundColor3 = Colors.Border,
        BorderSizePixel = 0,
    })
    return h
end

local function CreateToggle(parent, text, stateKey, description, onToggle)
    local defaultState = States[stateKey] or false
    local baseH = description and 54 or 36
    local mobileH = description and 60 or TOUCH_MIN
    local container = Create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, isMobile and mobileH or baseH),
        BackgroundTransparency = 1,
    })
    Create("TextLabel", {
        Parent = container,
        Size = UDim2.new(1, -70, 0, 20),
        Position = UDim2.new(0, 0, 0, description and 7 or 8),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Colors.TextPrimary,
        TextSize = 14,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    if description then
        Create("TextLabel", {
            Parent = container,
            Size = UDim2.new(1, -70, 0, 16),
            Position = UDim2.new(0, 0, 0, 30),
            BackgroundTransparency = 1,
            Text = description,
            TextColor3 = Colors.TextMuted,
            TextSize = 11,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
    end

    local toggleBg = Create("Frame", {
        Parent = container,
        Size = UDim2.new(0, 48, 0, 26),
        Position = UDim2.new(1, -48, 0, description and 14 or 5),
        BackgroundColor3 = defaultState and Colors.ToggleOn or Colors.ToggleOff,
        BorderSizePixel = 0,
    })
    CreateCorner(toggleBg, 13)
    CreateStroke(toggleBg, Colors.Border, 1)
    local knob = Create("Frame", {
        Parent = toggleBg,
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(0, defaultState and 25 or 3, 0.5, -10),
        BackgroundColor3 = Colors.ToggleKnob,
        BorderSizePixel = 0,
    })
    CreateCorner(knob, 10)

    local state = defaultState
    local toggleBtn = Create("TextButton", {
        Parent = container,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
    })
    toggleBtn.MouseButton1Click:Connect(function()
        state = not state
        States[stateKey] = state
        Tween(toggleBg, {BackgroundColor3 = state and Colors.ToggleOn or Colors.ToggleOff}, 0.2)
        Tween(knob, {Position = UDim2.new(0, state and 25 or 3, 0.5, -10)}, 0.2)
        if onToggle then
            onToggle(state, function()
                -- revert: paksa balik ke off
                state = false
                States[stateKey] = false
                Tween(toggleBg, {BackgroundColor3 = Colors.ToggleOff}, 0.2)
                Tween(knob, {Position = UDim2.new(0, 3, 0.5, -10)}, 0.2)
            end)
        end
    end)
    return container, function() return state end
end

local function CreateSlider(parent, text, minVal, maxVal, stateKey, suffix, onChange)
    local defaultVal = States[stateKey] or minVal
    local container = Create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 54),
        BackgroundTransparency = 1,
    })
    Create("TextLabel", {
        Parent = container,
        Size = UDim2.new(0, 200, 0, 20),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Colors.TextPrimary,
        TextSize = 14,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local valLabel = Create("TextLabel", {
        Parent = container,
        Size = UDim2.new(0, 60, 0, 24),
        Position = UDim2.new(1, -60, 0, -2),
        BackgroundColor3 = Colors.BackgroundLighter,
        Text = tostring(defaultVal) .. (suffix or ""),
        TextColor3 = Colors.TextSecondary,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        BorderSizePixel = 0,
    })
    CreateCorner(valLabel, 6)
    local track = Create("Frame", {
        Parent = container,
        Size = UDim2.new(1, -80, 0, 6),
        Position = UDim2.new(0, 0, 0, 36),
        BackgroundColor3 = Colors.SliderTrack,
        BorderSizePixel = 0,
    })
    CreateCorner(track, 3)
    local fillPct = (defaultVal - minVal) / math.max(maxVal - minVal, 1)
    local fill = Create("Frame", {
        Parent = track,
        Size = UDim2.new(fillPct, 0, 1, 0),
        BackgroundColor3 = Colors.SliderFill,
        BorderSizePixel = 0,
    })
    CreateCorner(fill, 3)
    local sliderKnob = Create("Frame", {
        Parent = track,
        Size = UDim2.new(0, 16, 0, 16),
        Position = UDim2.new(fillPct, -8, 0.5, -8),
        BackgroundColor3 = Colors.TextPrimary,
        BorderSizePixel = 0,
    })
    CreateCorner(sliderKnob, 8)

    local dragging = false
    local trackBtn = Create("TextButton", {
        Parent = container,
        Size = UDim2.new(1, -80, 0, 26),
        Position = UDim2.new(0, 0, 0, 26),
        BackgroundTransparency = 1,
        Text = "",
    })
    local function updateSlider(x)
        local trackAbsPos = track.AbsolutePosition.X
        local trackAbsSize = track.AbsoluteSize.X
        local pct = math.clamp((x - trackAbsPos) / math.max(trackAbsSize, 1), 0, 1)
        local val = math.floor(minVal + pct * (maxVal - minVal))
        States[stateKey] = val
        valLabel.Text = tostring(val) .. (suffix or "")
        if onChange then onChange(val) end
        Tween(fill, {Size = UDim2.new(pct, 0, 1, 0)}, 0.05)
        Tween(sliderKnob, {Position = UDim2.new(pct, -8, 0.5, -8)}, 0.05)
    end
    -- Mouse support (PC)
    trackBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateSlider(input.Position.X)
        end
    end)
    -- Touch support (Mobile)
    trackBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateSlider(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    return container
end

local function CreateActionButton(parent, text, callback, accentColor)
    local container = Create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, isMobile and TOUCH_MIN or 38),
        BackgroundTransparency = 1,
    })
    local btn = Create("TextButton", {
        Parent = container,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Colors.BackgroundLighter,
        Text = "",
        BorderSizePixel = 0,
        AutoButtonColor = false,
    })
    CreateCorner(btn, 9)
    CreateStroke(btn, accentColor or Colors.Border, accentColor and 1.5 or 1)
    local lbl = Create("TextLabel", {
        Parent = btn,
        Size = UDim2.new(1, -44, 1, 0),
        Position = UDim2.new(0, 14, 0, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = accentColor or Colors.TextPrimary,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local arrow = Create("TextLabel", {
        Parent = btn,
        Size = UDim2.new(0, 20, 1, 0),
        Position = UDim2.new(1, -26, 0, 0),
        BackgroundTransparency = 1,
        Text = "›",
        TextColor3 = Colors.TextMuted,
        TextSize = 18,
        Font = Enum.Font.GothamBold,
    })
    btn.MouseEnter:Connect(function() Tween(btn, {BackgroundColor3 = Colors.Surface}, 0.15) end)
    btn.MouseLeave:Connect(function() Tween(btn, {BackgroundColor3 = Colors.BackgroundLighter}, 0.15) end)
    btn.MouseButton1Click:Connect(function()
        Tween(btn, {BackgroundColor3 = Colors.SurfaceLight}, 0.05)
        task.wait(0.1)
        Tween(btn, {BackgroundColor3 = Colors.BackgroundLighter}, 0.1)
        if callback then callback() end
    end)
    return container
end

local function CreateDropdown(parent, label, options, stateKey, onChange)
    local currentVal = States[stateKey] or options[1]
    local container = Create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, isMobile and TOUCH_MIN or 40),
        BackgroundTransparency = 1,
    })
    local btn = Create("TextButton", {
        Parent = container,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Colors.BackgroundLighter,
        Text = "",
        BorderSizePixel = 0,
        AutoButtonColor = false,
    })
    CreateCorner(btn, 9)
    CreateStroke(btn, Colors.Border, 1)
    local lbl = Create("TextLabel", {
        Parent = btn,
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.new(0, 14, 0, 0),
        BackgroundTransparency = 1,
        Text = label .. "  •  " .. currentVal,
        TextColor3 = Colors.TextPrimary,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local arr = Create("TextLabel", {
        Parent = btn,
        Size = UDim2.new(0, 30, 1, 0),
        Position = UDim2.new(1, -32, 0, 0),
        BackgroundTransparency = 1,
        Text = "▾",
        TextColor3 = Colors.TextMuted,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
    })
    btn.MouseEnter:Connect(function() Tween(btn, {BackgroundColor3 = Colors.Surface}, 0.15) end)
    btn.MouseLeave:Connect(function() Tween(btn, {BackgroundColor3 = Colors.BackgroundLighter}, 0.15) end)

    local isOpen = false
    local dropPanel = nil
    btn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        Tween(arr, {Rotation = isOpen and 180 or 0}, 0.2)
        if isOpen then
            dropPanel = Create("Frame", {
                Parent = ScreenGui,
                Size = UDim2.new(0, container.AbsoluteSize.X, 0, math.min(#options * 32, 160)),
                Position = UDim2.new(0, container.AbsolutePosition.X, 0, container.AbsolutePosition.Y + 44),
                BackgroundColor3 = Colors.BackgroundLighter,
                BorderSizePixel = 0,
                ZIndex = 150,
                ClipsDescendants = true,
            })
            CreateCorner(dropPanel, 9)
            CreateStroke(dropPanel, Colors.Border, 1)
            local scroll = Create("ScrollingFrame", {
                Parent = dropPanel,
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ScrollBarThickness = 3,
                CanvasSize = UDim2.new(0, 0, 0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ZIndex = 151,
            })
            CreateListLayout(scroll, 2)
            CreatePadding(scroll, 4)
            for _, opt in ipairs(options) do
                local item = Create("TextButton", {
                    Parent = scroll,
                    Size = UDim2.new(1, 0, 0, 28),
                    BackgroundTransparency = opt == currentVal and 0.8 or 1,
                    BackgroundColor3 = Colors.Surface,
                    Text = opt,
                    TextColor3 = opt == currentVal and Colors.Success or Colors.TextPrimary,
                    TextSize = 13,
                    Font = opt == currentVal and Enum.Font.GothamBold or Enum.Font.Gotham,
                    ZIndex = 152,
                    AutoButtonColor = false,
                })
                CreateCorner(item, 6)
                item.MouseEnter:Connect(function() item.BackgroundTransparency = 0.7 item.BackgroundColor3 = Colors.Surface end)
                item.MouseLeave:Connect(function() item.BackgroundTransparency = opt == currentVal and 0.8 or 1 end)
                item.MouseButton1Click:Connect(function()
                    currentVal = opt
                    States[stateKey] = opt
                    lbl.Text = label .. "  •  " .. opt
                    isOpen = false
                    Tween(arr, {Rotation = 0}, 0.2)
                    if dropPanel then dropPanel:Destroy() dropPanel = nil end
                    if onChange then task.defer(onChange, opt) end
                end)
            end
        else
            if dropPanel then dropPanel:Destroy() dropPanel = nil end
        end
    end)

    UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and isOpen then
            local mp = UserInputService:GetMouseLocation()
            if dropPanel then
                local ap = dropPanel.AbsolutePosition
                local as = dropPanel.AbsoluteSize
                if not (mp.X >= ap.X and mp.X <= ap.X + as.X and mp.Y >= ap.Y and mp.Y <= ap.Y + as.Y) then
                    isOpen = false
                    Tween(arr, {Rotation = 0}, 0.2)
                    dropPanel:Destroy()
                    dropPanel = nil
                end
            end
        end
    end)

    return container
end

-- Multi-select dropdown — style Axon Hub: inline expand, checkmark kiri
-- Inline: panel expand di bawah trigger, bagian dari layout card (AutomaticSize.Y).
local function CreateMultiSelect(parent, label, options, stateKey)
    if type(States[stateKey]) ~= "table" then States[stateKey] = {} end
    local selected = States[stateKey]

    -- Pisah emoji (karakter pertama) dari sisa teks label
    local pillIcon = label:match("^([%z\1-\127\194-\244][\128-\191]*)") or "•"
    local pillText = label:gsub("^[%z\1-\127\194-\244][\128-\191]*%s*", "")

    local function getShortText()
        if #selected == 0 then return pillText .. "  •  (belum dipilih)" end
        if #selected <= 2 then
            local names = {}
            for _, s in ipairs(selected) do names[#names+1] = s end
            return pillText .. "  •  " .. table.concat(names, ", ")
        end
        return pillText .. "  •  " .. #selected .. " dipilih"
    end

    -- ── Wrapper utama ──
    local wrapper = Create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
    })
    CreateListLayout(wrapper, 0)

    -- ── Header pill (trigger buka/tutup) ──
    local pillOuter = Create("Frame", {
        Parent = wrapper,
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundTransparency = 1,
        LayoutOrder = 0,
    })
    local pill = Create("TextButton", {
        Parent = pillOuter,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Colors.BackgroundLighter,
        Text = "",
        BorderSizePixel = 0,
        AutoButtonColor = false,
    })
    CreateCorner(pill, 9)
    local pillStroke = CreateStroke(pill, Colors.Border, 1)

    Create("TextLabel", {
        Parent = pill,
        Size = UDim2.new(0, 28, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = pillIcon,
        TextSize = 14,
        Font = Enum.Font.Gotham,
        TextColor3 = Colors.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local pillLabel = Create("TextLabel", {
        Parent = pill,
        Size = UDim2.new(1, -76, 1, 0),
        Position = UDim2.new(0, 40, 0, 0),
        BackgroundTransparency = 1,
        Text = getShortText(),
        TextColor3 = Colors.TextPrimary,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local arrowLbl = Create("TextLabel", {
        Parent = pill,
        Size = UDim2.new(0, 28, 1, 0),
        Position = UDim2.new(1, -34, 0, 0),
        BackgroundTransparency = 1,
        Text = "›",
        TextColor3 = Colors.TextMuted,
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    pill.MouseEnter:Connect(function() Tween(pill, {BackgroundColor3 = Colors.Surface}, 0.12) end)
    pill.MouseLeave:Connect(function() Tween(pill, {BackgroundColor3 = Colors.BackgroundLighter}, 0.12) end)

    -- ── Panel inline ──
    local panel = Create("Frame", {
        Parent = wrapper,
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = Colors.BackgroundLighter,
        BorderSizePixel = 0,
        LayoutOrder = 1,
        Visible = false,
        ClipsDescendants = true,
        AutomaticSize = Enum.AutomaticSize.Y,
    })
    CreateCorner(panel, 9)
    CreateStroke(panel, Colors.Border, 1)

    -- ── Header row: Select All + Clear ──
    local headerRow = Create("Frame", {
        Parent = panel,
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = Colors.Background,
        BorderSizePixel = 0,
    })
    CreateCorner(headerRow, 9)
    -- tutup pojok bawah header agar nyambung dengan list
    Create("Frame", {
        Parent = headerRow,
        Size = UDim2.new(1, 0, 0, 9),
        Position = UDim2.new(0, 0, 1, -9),
        BackgroundColor3 = Colors.Background,
        BorderSizePixel = 0,
        ZIndex = 2,
    })

    local selAllBtn = Create("TextButton", {
        Parent = headerRow,
        Size = UDim2.new(0, 60, 0, 22),
        Position = UDim2.new(0, 10, 0.5, -11),
        BackgroundColor3 = Colors.Surface,
        Text = "✔ All",
        TextColor3 = Colors.Accent,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        ZIndex = 3,
    })
    CreateCorner(selAllBtn, 5)
    selAllBtn.MouseEnter:Connect(function() Tween(selAllBtn, {BackgroundColor3 = Colors.SurfaceLight}, 0.1) end)
    selAllBtn.MouseLeave:Connect(function() Tween(selAllBtn, {BackgroundColor3 = Colors.Surface}, 0.1) end)

    local clearBtn = Create("TextButton", {
        Parent = headerRow,
        Size = UDim2.new(0, 52, 0, 22),
        Position = UDim2.new(0, 78, 0.5, -11),
        BackgroundColor3 = Colors.Surface,
        Text = "✗ Clear",
        TextColor3 = Colors.TextMuted,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        ZIndex = 3,
    })
    CreateCorner(clearBtn, 5)
    clearBtn.MouseEnter:Connect(function() Tween(clearBtn, {BackgroundColor3 = Colors.SurfaceLight}, 0.1) end)
    clearBtn.MouseLeave:Connect(function() Tween(clearBtn, {BackgroundColor3 = Colors.Surface}, 0.1) end)

    -- ── Scrolling list ──
    local LIST_MAX_H = 200
    local scroll = Create("ScrollingFrame", {
        Parent = panel,
        Size = UDim2.new(1, 0, 0, math.min(#options * 30, LIST_MAX_H)),
        Position = UDim2.new(0, 0, 0, 36),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Colors.BorderLight,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 2,
    })
    CreateListLayout(scroll, 0)
    Create("UIPadding", {Parent=scroll, PaddingLeft=UDim.new(0,6), PaddingRight=UDim.new(0,6), PaddingTop=UDim.new(0,4), PaddingBottom=UDim.new(0,6)})

    -- ── Build item rows ──
    local itemFrames = {}

    local function isSelected(opt)
        return table.find(selected, opt) ~= nil
    end

    local function updateRow(t)
        local sel = isSelected(t.opt)
        t.frame.BackgroundColor3 = sel and Colors.Surface or Colors.BackgroundLighter
        t.frame.BackgroundTransparency = sel and 0 or 1
        t.checkLbl.Text = sel and "✓" or ""
        t.checkLbl.TextColor3 = Colors.Accent
        t.nameLbl.TextColor3 = sel and Colors.Accent or Colors.TextPrimary
        t.nameLbl.Font = sel and Enum.Font.GothamBold or Enum.Font.Gotham
    end

    local function updatePill()
        pillLabel.Text = getShortText()
        pillLabel.TextColor3 = #selected > 0 and Colors.Accent or Colors.TextPrimary
        pillStroke.Color = #selected > 0 and Colors.BorderLight or Colors.Border
    end

    for _, opt in ipairs(options) do
        local sel = isSelected(opt)
        local row = Create("Frame", {
            Parent = scroll,
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = sel and Colors.Surface or Colors.BackgroundLighter,
            BackgroundTransparency = sel and 0 or 1,
            BorderSizePixel = 0,
            ZIndex = 3,
        })
        CreateCorner(row, 6)

        local checkLbl = Create("TextLabel", {
            Parent = row,
            Size = UDim2.new(0, 22, 1, 0),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text = sel and "✓" or "",
            TextColor3 = Colors.Accent,
            TextSize = 13,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 4,
        })
        local nameLbl = Create("TextLabel", {
            Parent = row,
            Size = UDim2.new(1, -36, 1, 0),
            Position = UDim2.new(0, 30, 0, 0),
            BackgroundTransparency = 1,
            Text = opt,
            TextColor3 = sel and Colors.Accent or Colors.TextPrimary,
            TextSize = 13,
            Font = sel and Enum.Font.GothamBold or Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 4,
        })
        local hitBtn = Create("TextButton", {
            Parent = row,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            ZIndex = 5,
        })

        local entry = {frame=row, checkLbl=checkLbl, nameLbl=nameLbl, opt=opt}
        itemFrames[#itemFrames+1] = entry

        hitBtn.MouseEnter:Connect(function()
            if not isSelected(opt) then
                Tween(row, {BackgroundColor3 = Colors.Surface, BackgroundTransparency = 0.5}, 0.1)
            end
        end)
        hitBtn.MouseLeave:Connect(function()
            if not isSelected(opt) then row.BackgroundTransparency = 1 end
        end)
        hitBtn.MouseButton1Click:Connect(function()
            local idx = table.find(selected, opt)
            if idx then table.remove(selected, idx)
            else table.insert(selected, opt) end
            States[stateKey] = selected
            updateRow(entry)
            updatePill()
        end)
    end

    selAllBtn.MouseButton1Click:Connect(function()
        table.clear(selected)
        for _, opt in ipairs(options) do table.insert(selected, opt) end
        States[stateKey] = selected
        for _, t in ipairs(itemFrames) do updateRow(t) end
        updatePill()
    end)
    clearBtn.MouseButton1Click:Connect(function()
        table.clear(selected)
        States[stateKey] = selected
        for _, t in ipairs(itemFrames) do updateRow(t) end
        updatePill()
    end)

    -- ── Toggle buka/tutup ──
    local isOpen = false
    pill.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        Tween(arrowLbl, {Rotation = isOpen and 90 or 0}, 0.2)
        if isOpen then
            panel.Visible = true
            panel.Size = UDim2.new(1, 0, 0, 0)
            local targetH = 36 + math.min(#options * 30, LIST_MAX_H) + 10
            Tween(panel, {Size = UDim2.new(1, 0, 0, targetH)}, 0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        else
            Tween(panel, {Size = UDim2.new(1, 0, 0, 0)}, 0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
            task.delay(0.19, function()
                if not isOpen then panel.Visible = false end
            end)
        end
    end)

    return wrapper
end

local function CreateInfoText(parent, title, desc, color)
    local c = Create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = Colors.BackgroundLighter,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
    })
    CreateCorner(c, 8)
    CreatePadding(c, 10)
    CreateListLayout(c, 4)
    if title then
        Create("TextLabel", {
            Parent = c,
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
            Text = title,
            TextColor3 = color or Colors.Accent,
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
    end
    Create("TextLabel", {
        Parent = c,
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = desc,
        TextColor3 = Colors.TextMuted,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
    })
    return c
end

local function CreateStatRow(parent, label, value, valColor)
    local r = Create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = Colors.BackgroundLighter,
        BorderSizePixel = 0,
    })
    CreateCorner(r, 6)
    Create("TextLabel", {
        Parent = r,
        Size = UDim2.new(0.5, 0, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = Colors.TextMuted,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local valLbl = Create("TextLabel", {
        Parent = r,
        Size = UDim2.new(0.5, -12, 1, 0),
        Position = UDim2.new(0.5, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(value),
        TextColor3 = valColor or Colors.TextPrimary,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    return r, valLbl
end

-- ======================== GAME LOGIC HELPERS ========================

-- Get my plot
local function GetMyPlot()
    local gardens = game:GetService("Workspace"):FindFirstChild("Gardens")
    if not gardens then return nil end
    return gardens:FindFirstChild("Plot" .. MY_PLOT_ID)
end

-- Get plants folder
local function GetPlantsFolder()
    local plot = GetMyPlot()
    if not plot then return nil end
    return plot:FindFirstChild("Plants")
end

-- Fire packet remote
local function FirePacket(id, ...)
    if PacketRemote then
        PacketRemote:FireServer(id, ...)
    end
end

-- Get mutation from plant/fruit
local function GetMutation(obj)
    return obj:GetAttribute("Mutation") or ""
end

-- Check if mutation should be skipped/kept
local function ShouldSkipMutation(mutation)
    if States.harvestFilterMutation == "None" then return false end
    return mutation == States.harvestFilterMutation
end

-- ======================== HARVEST CORE ========================
-- Berdasarkan decompile HarvestPromptController + Scanner:
--   CollectionService tag "HarvestPrompt" dipakai game sendiri — JAUH lebih cepat dari iterasi tree
--   Fire via: Networking.Garden.CollectFruit:Fire(PlantId, FruitId) → fallback fireproximityprompt
--   PlantId & FruitId = Attribute pada FruitModel
--   Buah siap dipanen = prompt.Enabled == true (bukan "PlantGrowthReady" yang tidak ada)
--   FruitCount check: hanya panen sampai MAX_FRUIT_CAP

local function GetReadyFruitCount()
    -- Hitung buah siap panen di plot kita pakai CollectionService (cepat)
    local myPlot = GetMyPlot()
    if not myPlot then return 0 end
    local count = 0
    for _, prompt in ipairs(CollectionService:GetTagged("HarvestPrompt")) do
        if prompt.Enabled
            and not prompt:GetAttribute("Collected")
            and prompt:IsDescendantOf(myPlot) then
            count += 1
        end
    end
    return count
end

local function DoHarvestAll(mutFilter, hardLimit)
    local myPlot = GetMyPlot()
    if not myPlot then return 0 end

    -- Hitung sisa kapasitas backpack
    local currentCount = player:GetAttribute("FruitCount") or 0
    local cap          = hardLimit or MAX_FRUIT_CAP
    local remaining    = cap - currentCount
    if remaining <= 0 then return 0 end

    local harvested = 0
    local delay     = math.max(States.perFruitDelay or 0, 0)

    -- Pakai CollectionService "HarvestPrompt" — game sendiri pakai cara ini di HarvestPromptController
    for _, prompt in ipairs(CollectionService:GetTagged("HarvestPrompt")) do
        -- Stop jika sudah penuh
        if harvested >= remaining then break end

        -- Harus milik plot kita & aktif di workspace
        if not prompt:IsDescendantOf(myPlot) then continue end
        if not prompt:IsDescendantOf(workspace) then continue end
        if not prompt.Enabled then continue end
        if prompt:GetAttribute("Collected") then continue end

        -- Struktur: HarvestPrompt ← HarvestPart ← FruitModel
        local harvestPart = prompt.Parent
        local fruit = harvestPart and harvestPart.Parent
        if not (fruit and fruit:IsA("Model")) then continue end

        -- Mutation filter
        local mut = fruit:GetAttribute("Mutation") or ""
        if mutFilter and mutFilter ~= "None" and mut == mutFilter then continue end

        -- Ambil IDs dari FruitModel
        local plantId = fruit:GetAttribute("PlantId")
        local fruitId = fruit:GetAttribute("FruitId")
        local fired   = false

        -- Method 1: Networking.Garden.CollectFruit (cara resmi dari game)
        if Networking then
            pcall(function()
                Networking.Garden.CollectFruit:Fire(plantId, fruitId or "")
                fired = true
            end)
        end

        -- Method 2: fireproximityprompt (executor fallback)
        if not fired then
            pcall(function()
                fireproximityprompt(prompt)
                fired = true
            end)
        end

        if fired then
            harvested += 1
            if delay > 0 then task.wait(delay) end
        end
    end

    return harvested
end

-- ======================== AUTO LOOPS ========================

-- AUTO HARVEST LOOP
-- Pakai busy-wait ringan: cek tiap 0.5s apakah ada buah ready, langsung panen
-- Loop delay = jeda ANTAR SIKLUS PANEN (bukan jeda cek)
local _harvestCooldown = 0
task.spawn(function()
    while _G._MiracleHubSession == _SESSION do
        task.wait(0.5)
        if not States.autoHarvest then continue end

        -- Cek kapasitas dulu (murah, tanpa iterasi)
        local currentCount = player:GetAttribute("FruitCount") or 0
        if currentCount >= MAX_FRUIT_CAP then continue end

        -- Cek apakah sudah lewat cooldown loop
        local now = os.clock()
        if now < _harvestCooldown then continue end

        -- Cek apakah ada buah siap (pakai CollectionService, ringan)
        local ready = GetReadyFruitCount()
        if ready == 0 then continue end

        -- Mulai panen
        pcall(function()
            local harvested = DoHarvestAll(States.harvestFilterMutation)
            if harvested > 0 and States.notifyHarvest then
                local after = player:GetAttribute("FruitCount") or 0
                Notify("Auto Harvest ✅", harvested .. " buah | Bag " .. after .. "/" .. MAX_FRUIT_CAP, Colors.Warning)
            end
        end)

        -- Set cooldown setelah panen (loop delay)
        _harvestCooldown = os.clock() + math.max(States.harvestLoopDelay or 2, 0.5)
    end
end)

-- ======================== AUTO PLANT CORE (v3 - full slot coverage fix) ========================
-- Root cause bugs lama:
--   1. Raycast pakai FilterType.Include ke plantAreas — area tipis (0.09 stud) sering miss
--   2. Transparency check (`< 1`) membuang PlantArea yang semi-transparent / invisible
--   3. GetExistingPlantPositions hanya scan Plants folder via GetPivot() yang bisa gagal
--      jika model belum sepenuhnya ter-replicate → posisi dianggap kosong padahal tidak
--   4. Grid STEP=1.8 menghasilkan titik yang tidak merata antar PlantArea kecil (16×44)
--      dan area besar (PlantAreaColumn 44×84) — banyak slot pojok yang terlewat
--   5. Fungsi return result segera saat #result >= maxCount SEBELUM shuffle →
--      selalu tanam di area yang sama (bagian awal dari list plantAreas)
-- Fix v3:
--   - Hapus raycast sama sekali — pakai bounding box CFrame:PointToWorldSpace langsung
--   - Grid STEP lebih kecil (1.5) agar tidak ada slot yang terlewat di area kecil
--   - GetExistingPlantPositions scan dari ATTRIBUTES (PosX/PosY/PosZ) sebagai fallback
--     sebelum GetPivot, agar tanaman yang baru ditanam terbaca walau belum ter-render
--   - Filter overlap menggunakan satu tabel unified (occupied) dari awal
--   - Kumpulkan SEMUA kandidat dulu, shuffle, baru potong ke maxCount

-- Helper: Dapatkan semua BasePart tag "PlantArea" di plot kita
local function GetMyPlantAreas()
    local myPlot = GetMyPlot()
    if not myPlot then return {} end
    local areas = {}
    -- Primary: CollectionService tag (resmi)
    pcall(function()
        for _, part in ipairs(CollectionService:GetTagged("PlantArea")) do
            if part:IsA("BasePart") and part:IsDescendantOf(myPlot) then
                table.insert(areas, part)
            end
        end
    end)
    -- Fallback: scan Visual folder untuk PlantAreaColumn jika CS kosong
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

-- Helper: Hitung slot tanaman milik kita di plot
local function CountPlantedSlots()
    local plantsFolder = GetPlantsFolder()
    if not plantsFolder then return 0 end
    local count = 0
    for _, plant in ipairs(plantsFolder:GetChildren()) do
        if plant:GetAttribute("UserId") == player.UserId then
            count += 1
        end
    end
    return count
end

-- Helper: Hitung jumlah tanaman per SeedName milik kita di plot
local function GetPlantedSeedCounts()
    local plantsFolder = GetPlantsFolder()
    local counts = {}
    local total = 0
    if not plantsFolder then return counts, total end
    for _, plant in ipairs(plantsFolder:GetChildren()) do
        if plant:GetAttribute("UserId") == player.UserId then
            local name = plant:GetAttribute("SeedName") or plant:GetAttribute("SeedTool") or "?"
            counts[name] = (counts[name] or 0) + 1
            total += 1
        end
    end
    return counts, total
end

-- Helper: Format counts jadi string "Bamboo - 800\nDragon's Breath - 4\n..."
local function FormatSeedCounts(counts, total)
    local lines = {}
    for name, cnt in pairs(counts) do
        table.insert(lines, name .. " - " .. cnt)
    end
    table.sort(lines, function(a, b)
        -- Sort by count descending
        local ca = tonumber(a:match("- (%d+)$")) or 0
        local cb = tonumber(b:match("- (%d+)$")) or 0
        return ca > cb
    end)
    return table.concat(lines, "\n"), total
end

-- Helper: Kumpulkan posisi XZ SEMUA tanaman di plot (milik siapapun) untuk cek overlap
-- Pakai attribute PosX/PosZ dulu (tersedia di GAG-Hub listener), fallback ke GetPivot
local function GetExistingPlantPositions()
    local plantsFolder = GetPlantsFolder()
    local occupied = {}
    if not plantsFolder then return occupied end
    for _, plant in ipairs(plantsFolder:GetChildren()) do
        local px, pz
        -- Method 1: attribute Positions (dari server sync, selalu up-to-date)
        local posX = plant:GetAttribute("PosX")
        local posZ = plant:GetAttribute("PosZ")
        if posX and posZ then
            px, pz = posX, posZ
        else
            -- Method 2: GetPivot (butuh model fully loaded)
            local ok, pivot = pcall(function() return plant:GetPivot() end)
            if ok and pivot then
                px, pz = pivot.Position.X, pivot.Position.Z
            else
                -- Method 3: PrimaryPart position
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

-- Helper: Cek apakah posisi terlalu dekat dengan salah satu posisi di list (jarak XZ)
local function IsTooClose(px, pz, posList, minDist)
    minDist = minDist or 1.5
    local md2 = minDist * minDist
    for _, p in ipairs(posList) do
        local dx = px - p.X
        local dz = pz - p.Y  -- Vector2: X=worldX, Y=worldZ
        if dx*dx + dz*dz < md2 then
            return true
        end
    end
    return false
end

-- Helper: Cek apakah worldPos (Vector3) masuk dalam bounding box CFrame+Size (XZ plane)
local function IsInsideAreaXZ(worldPos, areaCF, areaSize)
    -- Ubah worldPos ke lokal space area
    local local3 = areaCF:PointToObjectSpace(worldPos)
    local halfX = areaSize.X / 2
    local halfZ = areaSize.Z / 2
    return (local3.X >= -halfX and local3.X <= halfX and
            local3.Z >= -halfZ and local3.Z <= halfZ)
end

-- Helper: Generate semua posisi valid untuk satu cycle (tanpa raycast)
-- Strategi: sweep grid di setiap PlantArea, ambil world-pos permukaan atas,
-- filter terhadap tanaman existing + posisi yang sudah dipilih cycle ini.
local function BuildValidPlantPositions(plantAreas, maxCount)
    maxCount = maxCount or 200  -- default besar; loop utama tetap potong sesuai seed yg ada

    -- Kumpulkan posisi XZ semua tanaman existing (akan di-mutate selama build)
    local occupied = GetExistingPlantPositions()  -- {Vector2(worldX, worldZ), ...}

    local MIN_DIST   = 1.5   -- jarak minimum antar tanaman (stud)
    local STEP       = 1.5   -- grid step (stud) — lebih kecil agar area 16-wide tidak terlewat
    local candidates = {}

    for _, area in ipairs(plantAreas) do
        local cf  = area.CFrame
        local sz  = area.Size
        -- Y permukaan atas area dalam world space (diambil dari center + halfY)
        local surfaceY = cf.Position.Y + sz.Y / 2

        local halfX = sz.X / 2
        local halfZ = sz.Z / 2

        -- Sweep grid dalam local space area (X dan Z), margin kecil agar tidak di tepi persis
        local margin = 0.5
        local lx = -halfX + margin
        while lx <= halfX - margin do
            local lz = -halfZ + margin
            while lz <= halfZ - margin do
                -- World position di permukaan atas area
                local worldPt = cf:PointToWorldSpace(Vector3.new(lx, sz.Y / 2, lz))
                -- Gunakan Y dari worldPt (lebih akurat jika area dirotasi)
                local wx, wy, wz = worldPt.X, worldPt.Y, worldPt.Z

                -- Filter: tidak boleh terlalu dekat dengan tanaman existing ATAU kandidat sebelumnya
                if not IsTooClose(wx, wz, occupied, MIN_DIST) then
                    table.insert(candidates, Vector3.new(wx, wy, wz))
                    -- Tambahkan ke occupied agar kandidat berikutnya tidak overlap
                    table.insert(occupied, Vector2.new(wx, wz))
                end

                lz = lz + STEP
            end
            lx = lx + STEP
        end
    end

    -- Shuffle semua kandidat agar variasi posisi per cycle (tidak selalu sudut kiri atas)
    for i = #candidates, 2, -1 do
        local j = math.random(1, i)
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end

    -- Potong ke maxCount
    local result = {}
    for i = 1, math.min(#candidates, maxCount) do
        result[i] = candidates[i]
    end

    return result
end

-- Helper: Ambil SATU seed dari backpack (dipanggil ulang tiap iterasi)
-- Return nil jika tidak ada seed valid ATAU belum ada target dipilih
local function GetNextSeedFromBackpack()
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then return nil end

    -- Cek apakah ada target yang dipilih
    -- Jika autoPlantAllSeeds = false dan autoPlantTargets kosong → BLOCK (tidak tanam sembarangan)
    local allowedSeeds = nil  -- nil = allow all (hanya jika autoPlantAllSeeds = true)
    if States.autoPlantAllSeeds then
        allowedSeeds = nil  -- tanam semua
    else
        if #(States.autoPlantTargets or {}) == 0 then
            return nil  -- belum pilih seed apapun → jangan tanam
        end
        allowedSeeds = {}
        for _, name in ipairs(States.autoPlantTargets) do
            allowedSeeds[name] = true
        end
    end

    for _, tool in ipairs(backpack:GetChildren()) do
        if not tool:IsA("Tool") then continue end

        -- Resolve nama seed dari attribute
        local seedName = tool:GetAttribute("SeedTool")
        if type(seedName) ~= "string" or seedName == "" then
            local raw = tool:GetAttribute("SeedTool")
            if raw ~= nil then
                -- SeedTool ada tapi bukan string (misal boolean) → nama = tool.Name
                seedName = tool.Name
            else
                seedName = tool:GetAttribute("SeedName")
                if type(seedName) ~= "string" or seedName == "" then
                    seedName = nil
                    for _, s in ipairs(SEEDS) do
                        if tool.Name == s or tool.Name == s .. " Seed" then
                            seedName = s break
                        end
                    end
                end
            end
        end
        if not seedName then continue end

        -- Cek filter allowed
        if allowedSeeds ~= nil and not allowedSeeds[seedName] then continue end

        return {tool = tool, name = seedName}
    end
    return nil
end

-- Core: Fire Networking.Plant.PlantSeed dengan posisi hit yang valid
local _lastPlantFireTime = 0
local function DoPlantFire(tool, seedName, hitPos)
    -- Rate limit 0.05s (sama dengan game)
    local now = os.clock()
    local wait = 0.05 - (now - _lastPlantFireTime)
    if wait > 0 then task.wait(wait) end

    -- Resolve seedName akhir dari attribute (pastikan benar)
    local attr = tool:GetAttribute("SeedTool")
    if type(attr) == "string" and attr ~= "" then
        seedName = attr
    end

    local fired = false

    -- Cara 1: Networking.Plant.PlantSeed (persis game asli)
    if Networking then
        local ok = pcall(function()
            Networking.Plant.PlantSeed:Fire(hitPos, seedName, tool)
        end)
        fired = ok
    end

    -- Cara 2: PacketRemote fallback
    if not fired and PacketRemote then
        pcall(function()
            PacketRemote:FireServer(PACKET.PlantSeed, hitPos, seedName, tool)
        end)
        fired = true
    end

    _lastPlantFireTime = os.clock()
    return fired
end

-- AUTO PLANT LOOP
task.spawn(function()
    while _G._MiracleHubSession == _SESSION do
        if not States.autoPlant then
            task.wait(0.5)
            continue
        end

        -- 1. Cek PlantArea
        local plantAreas = GetMyPlantAreas()
        if #plantAreas == 0 then
            if States.autoPlantNotify then
                Notify("Auto Plant ⚠", "PlantArea tidak ditemukan di Plot " .. MY_PLOT_ID
                    .. ". Pastikan kamu di plotmu.", Colors.Warning, 5)
            end
            task.wait(5)
            continue
        end

        -- 2. Build semua posisi valid — scan semua slot kosong di semua PlantArea
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
            continue
        end

        -- 3. Tanam: re-scan backpack tiap iterasi (tool dikonsumsi server setelah tanam)
        local planted    = 0
        local noSeed     = false
        local plantedLog = {}  -- track {[seedName] = jumlah} untuk notif

        for _, hitPos in ipairs(validPositions) do
            if not States.autoPlant then break end

            local seedEntry = GetNextSeedFromBackpack()
            if not seedEntry then
                noSeed = true
                break
            end

            local ok = pcall(DoPlantFire, seedEntry.tool, seedEntry.name, hitPos)
            if ok then
                planted += 1
                plantedLog[seedEntry.name] = (plantedLog[seedEntry.name] or 0) + 1
            end

            task.wait(0.3)
        end

        -- 4. Notif hasil
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
                NotifyStok(lines, Colors.Success, 8, "🌱 Auto Plant (+" .. planted .. " ditanam)")
            elseif noSeed then
                Notify("Auto Plant", "Seed habis di backpack (sesuai filter).", Colors.Warning, 3)
            end
        end

        -- 5. Langsung loop kembali (cek apakah masih ada slot / seed)
        task.wait(0.5)
    end
end)

-- AUTO WATER LOOP
task.spawn(function()
    while _G._MiracleHubSession == _SESSION do
        task.wait(States.harvestLoopDelay or 5)
        if not States.autoWater then continue end
        pcall(function()
            local plants = GetPlantsFolder()
            if not plants then return end
            local watered = 0
            for _, plant in ipairs(plants:GetChildren()) do
                if not States.autoWater then break end
                -- Find water prompt or just trigger water via tool
                local wp = nil
                for _, desc in ipairs(plant:GetDescendants()) do
                    if desc:IsA("ProximityPrompt") and (desc.Name == "WaterPrompt" or desc.Name:lower():find("water")) then
                        wp = desc
                        break
                    end
                end
                if wp then
                    SafeFirePrompt(wp)
                    watered += 1
                    task.wait(0.1)
                end
            end
            -- Also try equipping watering can if no prompt found
            if watered == 0 then
                for _, tool in ipairs(player.Backpack:GetChildren()) do
                    if tool:GetAttribute("WateringCan") or tool.Name:lower():find("watering") then
                        tool.Parent = player.Character
                        task.wait(0.3)
                        local hum = player.Character:FindFirstChildOfClass("Humanoid")
                        if hum then hum:ActivateController() end
                        task.wait(0.5)
                        tool.Parent = player.Backpack
                        watered += 1
                        break
                    end
                end
            end
        end)
    end
end)

-- ======================== AUTO SELL LOOP (FIXED) ========================
-- Cara kerja benar dari decompile StevenController:
--   1. Networking.NPCS.SellAll:Fire() → jual semua sekaligus (paling efisien)
--   2. Networking.NPCS.SellFruit:Fire(fruitId) → jual per buah (kalau mau filter)
--   3. TIDAK perlu teleport ke Steven — bisa dilakukan dari mana saja
--   4. fruitId = tool:GetAttribute("Id") (bukan tool object)
--
-- Filter mutation/rarity SEBELUM fire jika ada mode selective sell

-- Helper: preview harga total di inventory (tanpa jual)
local function PreviewSellAll()
    if not Networking then return nil end
    local ok, result = pcall(function()
        return Networking.NPCS.PreviewSellAll:Fire()
    end)
    return ok and result or nil
end

-- Helper: jual semua buah di inventory (tidak ada filter)
local function SellAllFruits()
    if not Networking then return nil end
    local ok, result = pcall(function()
        return Networking.NPCS.SellAll:Fire()
    end)
    return ok and result or nil
end

-- Helper: jual 1 buah by FruitId (untuk mode filter)
local function SellFruitById(fruitId)
    if not Networking then return nil end
    local ok, result = pcall(function()
        return Networking.NPCS.SellFruit:Fire(fruitId)
    end)
    return ok and result or nil
end

-- Helper: cek dan gunakan daily deal (bonus 5x harga)
local function UseDailyDeal()
    if not Networking then return nil end
    local ok, result = pcall(function()
        return Networking.NPCS.UseDailyDealAll:Fire()
    end)
    return ok and result or nil
end

-- Helper: apakah fruit ini harus di-keep (tidak dijual)
local function ShouldKeepFruit(tool)
    local mut = GetMutation(tool)
    -- Keep semua yg punya mutation kalau toggle aktif
    if States.keepMutations and mut ~= "" and mut ~= "None" then
        return true
    end
    -- Keep mutation spesifik
    local keepMut = States.harvestFilterMutation or "None"
    if keepMut ~= "None" and mut == keepMut then
        return true
    end
    return false
end

-- Cek apakah inventory punya buah yg perlu difilter (butuh selective sell)
local function NeedsSelectiveSell()
    if not States.keepMutations and (States.harvestFilterMutation or "None") == "None" then
        return false -- jual semua, pakai SellAll (lebih cepat)
    end
    return true
end

task.spawn(function()
    while _G._MiracleHubSession == _SESSION do
        task.wait(States.sellLoopDelay or 3)
        if not States.autoSell then continue end
        if not Networking then
            Notify("Auto Sell", "❌ Networking module tidak ditemukan!", Colors.Error)
            task.wait(5)
            continue
        end
        pcall(function()
            -- Hitung berapa buah ada dulu
            local fruits = {}
            for _, tool in ipairs(player.Backpack:GetChildren()) do
                if tool:GetAttribute("HarvestedFruit") or tool:GetAttribute("FruitName") then
                    table.insert(fruits, tool)
                end
            end
            -- Cek tool di tangan juga
            if player.Character then
                local held = player.Character:FindFirstChildOfClass("Tool")
                if held and (held:GetAttribute("HarvestedFruit") or held:GetAttribute("FruitName")) then
                    table.insert(fruits, held)
                end
            end

            if #fruits == 0 then return end

            -- Mode: pakai daily deal kalau aktif dan tersedia
            if States.autoUseDailyDeal then
                local dealInfo = pcall(function() return Networking.NPCS.CheckDailyDeal:Fire() end)
                -- Coba daily deal dulu
                local dealResult = UseDailyDeal()
                if dealResult and dealResult.Success then
                    if States.notifySell then
                        Notify("Daily Deal! 🌈", "Sold " .. (dealResult.SoldCount or 0) .. " buah = " .. tostring(dealResult.SellPrice or 0) .. "¢ (5x bonus!)", Colors.Success, 10)
                    end
                    return
                end
            end

            if NeedsSelectiveSell() then
                -- Mode selective: jual per-buah, skip yg di-keep
                local soldCount = 0
                local skippedCount = 0
                for _, tool in ipairs(fruits) do
                    if not States.autoSell then break end
                    if ShouldKeepFruit(tool) then
                        skippedCount += 1
                        continue
                    end
                    local fruitId = tool:GetAttribute("Id")
                    if not fruitId then continue end
                    local result = SellFruitById(fruitId)
                    if result and result.Success then
                        soldCount += 1
                    elseif result and result.Reason == "Favorited" then
                        skippedCount += 1
                    end
                    task.wait(States.sellDelay or 0.1)
                end
                if States.notifySell and soldCount > 0 then
                    Notify("Auto Sell", "Sold " .. soldCount .. " buah (skip " .. skippedCount .. " mutation)", Colors.Gold, 10)
                end
            else
                -- Mode sell all: pakai SellAll sekaligus (paling cepat & aman)
                local result = SellAllFruits()
                if result and result.Success then
                    if States.notifySell then
                        Notify("Auto Sell ✅", "Sold " .. (result.SoldCount or #fruits) .. " buah = " .. tostring(result.SellPrice or 0) .. "¢", Colors.Gold, 10)
                    end
                elseif result then
                    -- SellAll gagal, tidak ada fruits atau error
                    if States.notifySell then
                        Notify("Auto Sell", "Gagal: " .. tostring(result.Reason or "unknown"), Colors.Error)
                    end
                end
            end
        end)
    end
end)

-- ======================== AUTO BUY SEEDS LOOP (FIXED) ========================
-- Cara kerja yg benar (dari investigasi scanner):
--   1. Stok seed ada di: ReplicatedStorage.StockValues.SeedShop.Items.<SeedName> (NumberValue)
--   2. Packet beli: PacketRemote:FireServer(120, seedName, quantity)
--   3. TIDAK perlu teleport ke shop — bisa langsung fire dari mana saja
--   4. Packet ID 120 = PurchaseSeed (dari Attribute RemoteEvent.PurchaseSeed = 120)
local function GetSeedStock(seedName)
    local rs = game:GetService("ReplicatedStorage")
    local sv = rs:FindFirstChild("StockValues")
    if not sv then return 0 end
    local ss = sv:FindFirstChild("SeedShop")
    if not ss then return 0 end
    local items = ss:FindFirstChild("Items")
    if not items then return 0 end
    local stockVal = items:FindFirstChild(seedName)
    return stockVal and stockVal.Value or 0
end

-- BuySeedPacket — kirim packet langsung ke server tanpa UI (UI simulation dihapus: trigger error sound)
-- Layer 1: Networking.SeedShop.PurchaseSeed:Fire (cara resmi)
-- Layer 2: PacketRemote:FireServer fallback
local function BuySeedPacket(seedName, quantity)
    quantity = quantity or 1

    -- Layer 1: Networking.SeedShop
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

    -- Layer 2: PacketRemote fallback
    if not PacketRemote then
        local rs = game:GetService("ReplicatedStorage")
        local sm = rs:FindFirstChild("SharedModules")
        PacketRemote = sm and sm:FindFirstChild("Packet") and sm.Packet:FindFirstChild("RemoteEvent")
    end
    if not PacketRemote then return false end

    pcall(function() PacketRemote:FireServer(PACKET.PurchaseSeed, seedName, quantity) end)
    return true
end

-- GetGearStock — baca stok gear dari ReplicatedStorage.StockValues.GearShop.Items
local function GetGearStock(gearName)
    local rs = game:GetService("ReplicatedStorage")
    local sv = rs:FindFirstChild("StockValues")
    if not sv then return 0 end
    local gs = sv:FindFirstChild("GearShop")
    if not gs then return 0 end
    local items = gs:FindFirstChild("Items")
    if not items then return 0 end
    local stockVal = items:FindFirstChild(gearName)
    return stockVal and stockVal.Value or 0
end

-- BuyGearPacket — kirim packet beli gear ke server
-- Layer 1: Networking.GearShop.Purchase:Fire (cara resmi)
-- Layer 2: PacketRemote:FireServer fallback (EquipGear=126)
local function BuyGearPacket(gearName, quantity)
    quantity = quantity or 1

    -- Layer 1: Networking.GearShop
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

    -- Layer 2: PacketRemote fallback
    if not PacketRemote then
        local rs = game:GetService("ReplicatedStorage")
        local sm = rs:FindFirstChild("SharedModules")
        PacketRemote = sm and sm:FindFirstChild("Packet") and sm.Packet:FindFirstChild("RemoteEvent")
    end
    if not PacketRemote then return false end

    pcall(function() PacketRemote:FireServer(PACKET.EquipGear, gearName, quantity) end)
    return true
end

-- ======================== FAILED SOUND MUTE (persistent) ========================
-- Game memainkan SFX.Failed setiap kali server menolak request beli (stok 0).
-- Karena auto buy loop jalan terus, suara error ikut bunyi tiap cycle.
-- Fix: Volume=0 + RollOffMaxDistance=0, lalu pasang listener agar tidak
-- di-reset oleh game. Koneksi disimpan agar bisa di-disconnect saat session berakhir.
local _sfxMuteConn = nil

local function MuteSFX_Failed()
    local ss = game:GetService("SoundService")
    local sfx = ss:FindFirstChild("SFX")
    local failedSnd = sfx and sfx:FindFirstChild("Failed")
    if not failedSnd then return end

    -- Set langsung
    failedSnd.Volume = 0
    failedSnd.RollOffMaxDistance = 0

    -- Putus koneksi lama kalau ada (re-enable lalu disable lagi)
    if _sfxMuteConn then
        _sfxMuteConn:Disconnect()
        _sfxMuteConn = nil
    end

    -- Pasang guard: kalau game coba kembalikan Volume, langsung di-reset ke 0
    _sfxMuteConn = failedSnd:GetPropertyChangedSignal("Volume"):Connect(function()
        if failedSnd.Volume ~= 0 then
            failedSnd.Volume = 0
        end
    end)
end

-- Jalankan sekali saat inject
pcall(MuteSFX_Failed)

-- Jaga-jaga kalau SFX belum ada saat inject (game masih loading)
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

-- ======================== AUTO BUY SEEDS LOOP ========================
-- Logika simpel: cek stok server tiap loop, kalau > 0 beli, kalau 0 skip.
-- Loop tetap jalan saat stok habis — langsung beli begitu server restock.
local _notifiedEmpty = {}  -- [seedName] = true → sudah notif habis, cegah spam

task.spawn(function()
    while _G._MiracleHubSession == _SESSION do
        task.wait(math.max(States.shopLoopDelay or 0.5, 0.1))
        if not States.autoBuySeed then continue end
        pcall(function()
            local rs = game:GetService("ReplicatedStorage")
            local items = rs:FindFirstChild("StockValues")
                and rs.StockValues:FindFirstChild("SeedShop")
                and rs.StockValues.SeedShop:FindFirstChild("Items")

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
                if not States.autoBuySeed then return end
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
        end)
    end
end)

-- ======================== AUTO BUY GEAR LOOP ========================
-- Sama persis pola dengan auto buy seeds: cek stok tiap loop, beli jika > 0, skip jika 0.
-- Loop tetap jalan saat stok habis — langsung beli begitu server restock.
local _notifiedEmptyGear = {}  -- [gearName] = true → sudah notif habis, cegah spam

task.spawn(function()
    while _G._MiracleHubSession == _SESSION do
        task.wait(math.max(States.gearShopLoopDelay or 0.5, 0.1))
        if not States.autoBuyGear then continue end
        pcall(function()
            local rs = game:GetService("ReplicatedStorage")
            local items = rs:FindFirstChild("StockValues")
                and rs.StockValues:FindFirstChild("GearShop")
                and rs.StockValues.GearShop:FindFirstChild("Items")

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
                if not States.autoBuyGear then return end
                local stock = GetGearStock(gearName)
                if stock > 0 then
                    _notifiedEmptyGear[gearName] = false
                    BuyGearPacket(gearName, 1)
                    if States.notifyBuyGear then
                        Notify("Auto Buy Gear", "✅ Beli: " .. gearName .. " (stok: " .. stock .. ")", Colors.Electric, 3)
                    end
                    task.wait(States.gearBuyDelay or 0.05)
                else
                    if States.notifyBuyGear and not _notifiedEmptyGear[gearName] then
                        _notifiedEmptyGear[gearName] = true
                        Notify("Auto Buy Gear", gearName .. " stok habis, menunggu restock...", Colors.TextMuted, 4)
                    end
                end
            end
        end)
    end
end)

-- ======================== AUTO BUY CRATE HELPERS ========================
-- GetCrateStock — baca stok crate dari ReplicatedStorage.StockValues.CrateShop.Items
local function GetCrateStock(crateName)
    local rs = game:GetService("ReplicatedStorage")
    local sv = rs:FindFirstChild("StockValues")
    if not sv then return 0 end
    local cs = sv:FindFirstChild("CrateShop")
    if not cs then return 0 end
    local items = cs:FindFirstChild("Items")
    if not items then return 0 end
    local stockVal = items:FindFirstChild(crateName)
    return stockVal and stockVal.Value or 0
end

-- BuyCratePacket — kirim packet beli crate ke server
-- Layer 1: Networking.CrateShop.Purchase (cara resmi)
-- Layer 2: PacketRemote:FireServer fallback (PurchaseCrate=122)
local function BuyCratePacket(crateName, quantity)
    quantity = quantity or 1

    -- Layer 1: Networking.CrateShop
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

    -- Layer 2: PacketRemote fallback
    if not PacketRemote then
        local rs = game:GetService("ReplicatedStorage")
        local sm = rs:FindFirstChild("SharedModules")
        PacketRemote = sm and sm:FindFirstChild("Packet") and sm.Packet:FindFirstChild("RemoteEvent")
    end
    if not PacketRemote then return false end

    pcall(function() PacketRemote:FireServer(PACKET.PurchaseCrate, crateName, quantity) end)
    return true
end

-- OpenCrateViaNetworking — buka crate by name (cara benar dari CrateController)
-- CrateController menggunakan: Networking.Crate.OpenCrate:Fire(crateName)
local function OpenCrateViaNetworking(crateName)
    if Networking then
        local crateNS = rawget(Networking, "Crate")
        if crateNS then
            local openFn = rawget(crateNS, "OpenCrate")
            if openFn and openFn.Fire then
                local ok, result = pcall(function()
                    return openFn:Fire(crateName)
                end)
                if ok and result then
                    return result
                end
                return ok
            end
        end
    end
    -- Fallback PacketRemote
    if PacketRemote then
        pcall(function() PacketRemote:FireServer(PACKET.OpenCrate, crateName) end)
        return true
    end
    return false
end

-- GetCratesInInventory — cari crate tools di backpack player
local function GetCratesInInventory()
    local found = {}
    for _, tool in ipairs(player.Backpack:GetChildren()) do
        local crateName = tool:GetAttribute("Crate")
        if crateName then
            table.insert(found, {tool = tool, name = crateName})
        end
    end
    -- Cek tangan juga
    if player.Character then
        local held = player.Character:FindFirstChildOfClass("Tool")
        if held and held:GetAttribute("Crate") then
            table.insert(found, {tool = held, name = held:GetAttribute("Crate")})
        end
    end
    return found
end

-- ======================== AUTO BUY CRATE LOOP ========================
-- Pola sama persis dengan auto buy seeds/gear:
-- Cek stok server tiap loop, kalau > 0 beli, kalau 0 skip.
local _notifiedEmptyCrate = {}  -- [crateName] = true → sudah notif habis, cegah spam

task.spawn(function()
    while _G._MiracleHubSession == _SESSION do
        task.wait(math.max(States.crateShopLoopDelay or 0.5, 0.1))
        if not States.autoBuyCrate then continue end
        pcall(function()
            local rs = game:GetService("ReplicatedStorage")
            local items = rs:FindFirstChild("StockValues")
                and rs.StockValues:FindFirstChild("CrateShop")
                and rs.StockValues.CrateShop:FindFirstChild("Items")

            local targets = {}
            if States.autoBuyCrateAll then
                if not items then return end
                for _, stockVal in ipairs(items:GetChildren()) do
                    if stockVal:IsA("NumberValue") then
                        table.insert(targets, stockVal.Name)
                    end
                end
                -- Fallback: pakai CRATES list kalau StockValues.CrateShop tidak ada
                if #targets == 0 then
                    targets = CRATES
                end
            else
                targets = States.autoBuyCrateTargets or {}
                if #targets == 0 then return end
            end

            for _, crateName in ipairs(targets) do
                if not States.autoBuyCrate then return end
                local stock = GetCrateStock(crateName)
                if stock > 0 then
                    _notifiedEmptyCrate[crateName] = false
                    BuyCratePacket(crateName, 1)
                    if States.notifyBuyCrate then
                        Notify("Auto Buy Crate", "✅ Beli: " .. crateName .. " (stok: " .. stock .. ")", Colors.Warning, 3)
                    end
                    task.wait(States.crateBuyDelay or 0.05)
                else
                    -- Stok habis: notif sekali saja (tidak spam)
                    if States.notifyBuyCrate and not _notifiedEmptyCrate[crateName] then
                        _notifiedEmptyCrate[crateName] = true
                        Notify("Auto Buy Crate", crateName .. " stok habis, menunggu restock...", Colors.TextMuted, 4)
                    end
                end
            end
        end)
    end
end)

-- ======================== AUTO OPEN CRATE LOOP ========================
-- Cek inventory tiap loop apakah ada crate tool, kalau ada open via Networking.
-- Delay crateOpenDelay detik antar open (beri waktu efek animasi selesai).
task.spawn(function()
    while _G._MiracleHubSession == _SESSION do
        task.wait(math.max(States.crateOpenDelay or 8, 1))
        if not States.autoOpenCrate then continue end
        pcall(function()
            local cratesInBag = GetCratesInInventory()
            if #cratesInBag == 0 then return end

            for _, entry in ipairs(cratesInBag) do
                if not States.autoOpenCrate then return end

                -- Equip tool dulu (wajib agar server terima)
                local tool = entry.tool
                local crateName = entry.name
                if tool.Parent ~= player.Character then
                    tool.Parent = player.Character
                    task.wait(0.2)
                end

                -- Open via Networking (cara benar dari CrateController)
                local ok, result = pcall(function()
                    return OpenCrateViaNetworking(crateName)
                end)

                if ok and States.notifyOpenCrate then
                    local wonItem = type(result) == "table" and result.WonItem
                    if wonItem then
                        Notify("📦 Crate Opened!", crateName .. " → " .. (wonItem.Name or "?") .. (wonItem.Chance and string.format(" (%.2f%%)", wonItem.Chance) or ""), Colors.Gold, 5)
                    else
                        Notify("📦 Crate Opened!", "Opened: " .. crateName, Colors.Warning, 3)
                    end
                end

                -- Kembalikan ke backpack setelah dipakai (biar bisa dipakai lagi)
                task.wait(0.5)
                if tool and tool.Parent == player.Character then
                    tool.Parent = player.Backpack
                end

                task.wait(States.crateOpenDelay or 8)
            end
        end)
    end
end)

-- Helper: ambil WildPetRef folder (pakai path yang sama dengan PetTeleporterController GAG)
local function GetWildPetRef()
    local map = workspace:FindFirstChild("Map")
    return map and map:FindFirstChild("WildPetRef")
end

-- ======================== SMART MOVE TO PET (30-stud hop loop) ========================
-- Perpindahan dilakukan dalam hop 30 studs, dengan jeda task.wait(0.15) di antaranya.
-- Ini meniru player yang "bergerak cepat" tapi tidak sekaligus 1 lompatan besar
-- sehingga server anti-cheat GAG tidak mendeteksi teleport dan tidak rollback.
-- HOP_SIZE = 30, WAIT = 0.15s → kecepatan efektif ~200 studs/detik

local HOP_SIZE   = 10    -- max studs per hop
local HOP_WAIT   = 0.50  -- detik jeda antar hop (turunkan kalau mau lebih cepat, min ~0.05)

local function SmartMoveToPet(targetPosition, onArrive)
    local c = player.Character
    if not c then if onArrive then onArrive() end return end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if not hrp then if onArrive then onArrive() end return end

    local dest = Vector3.new(targetPosition.X, targetPosition.Y + 5, targetPosition.Z)

    while true do
        -- Refresh char tiap iterasi (respawn-safe)
        local ch = player.Character
        if not ch then break end
        local r = ch:FindFirstChild("HumanoidRootPart")
        if not r then break end

        local currentPos = r.Position
        local remaining  = (dest - currentPos).Magnitude

        if remaining <= HOP_SIZE then
            -- Sudah cukup dekat, snap langsung ke tujuan
            r.CFrame = CFrame.new(dest)
            break
        end

        -- Gerak maju 30 studs ke arah target
        local direction  = (dest - currentPos).Unit
        local nextPos    = currentPos + direction * HOP_SIZE
        r.CFrame = CFrame.new(nextPos)

        task.wait(HOP_WAIT)
    end

    if onArrive then onArrive() end
end

-- Helper: scan semua wild pet aktif dari WildPetRef
-- Setiap child adalah BasePart dengan:
--   Attribute "Rarity"       → string rarity (e.g. "Legendary", "Mythic", "Super", "Common", "Uncommon", "Rare")
--   Attribute "OwnerUserId"  → number/nil; 0 = bebas, >0 = sudah dimiliki
local function ScanWildPets(rarityFilter)
    local ref = GetWildPetRef()
    if not ref then return {} end
    local results = {}
    for _, part in ipairs(ref:GetChildren()) do
        if part:IsA("BasePart") then
            local rarity = part:GetAttribute("Rarity") or "Unknown"
            local owner  = tonumber(part:GetAttribute("OwnerUserId")) or 0
            -- skip pet yang sudah ada pemiliknya
            if owner ~= 0 then continue end
            -- filter rarity
            if rarityFilter and rarityFilter ~= "All" and rarityFilter ~= rarity then continue end
            local dist = math.huge
            if player.Character then
                local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                if hrp then dist = (part.Position - hrp.Position).Magnitude end
            end
            -- Ambil nama species dari attribute atau Name part
            local petName = part:GetAttribute("Pet")
                or part:GetAttribute("Species")
                or part:GetAttribute("PetSpecies")
                or part:GetAttribute("PetName")
                or part.Name
            table.insert(results, {part=part, rarity=rarity, dist=dist, name=tostring(petName)})
        end
    end
    -- urutkan dari yg terdekat
    table.sort(results, function(a,b) return a.dist < b.dist end)
    return results
end

-- Humanize camelCase nama species → "BlackDragon" → "Black Dragon"
local function HumanizePetName(n)
    return (tostring(n):gsub("(%l)(%u)", "%1 %2"))
end

-- Warna per rarity — cocok persis dengan PetListController GAG
-- Mythic = merah (220,40,40), Super = putih (game pakai rainbow gradient)
local RarityColor = {
    Common    = Color3.fromRGB(180, 180, 180),
    Uncommon  = Color3.fromRGB(60, 200, 70),
    Rare      = Color3.fromRGB(60, 130, 255),
    Epic      = Color3.fromRGB(160, 60, 220),
    Legendary = Color3.fromRGB(255, 215, 0),
    Mythic    = Color3.fromRGB(220, 40, 40),
    Super     = Color3.fromRGB(255, 255, 255),
}

-- Lookup rarity per species — dari PetData GAG
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


-- Helper: beli wild pet via Networking.Pets.WildPetTame
-- CONFIRMED via sniffer:
--   Remote  : Networking.Pets.WildPetTame:Fire(petId)
--   petId   : part.Name (format "WildPet_<uuid>")
--   Bukti   : setelah fire, OwnerUserId berubah & pet masuk backpack
--   Attrs   : PetName, Price, OwnerUserId, OwnerName, State, Rarity
local function BuyWildPet(part)
    local petId = part.Name  -- "WildPet_<uuid>" — confirmed dari sniffer

    if Networking then
        local petsNS = rawget(Networking, "Pets")
        if petsNS then
            local tame = rawget(petsNS, "WildPetTame")
            if tame and tame.Fire then
                local ok = pcall(function() tame:Fire(petId) end)
                return ok
            end
        end
    end

    -- Fallback: PacketRemote
    if PacketRemote then
        pcall(function() PacketRemote:FireServer(petId) end)
        return true
    end

    return false
end

-- Helper: cek apakah wild pet masih bebas (belum ada pemilik)
-- State "walking_to_garden" = sudah dibeli orang lain
local function IsWildPetFree(part)
    if not part or not part.Parent then return false end
    if (tonumber(part:GetAttribute("OwnerUserId")) or 0) ~= 0 then return false end
    local state = part:GetAttribute("State") or ""
    if state == "walking_to_garden" then return false end
    return true
end

-- AUTO CATCH WILD PETS LOOP
-- Remote  : Networking.Pets.WildPetTame:Fire(part.Name)
-- petId   : part.Name = "WildPet_<uuid>" (confirmed dari sniffer)
-- Free    : OwnerUserId == 0 AND State ~= "walking_to_garden"
task.spawn(function()
    local lastWaitingNotif = 0

    while _G._MiracleHubSession == _SESSION do
        task.wait(2)
        if not States.autoCatchWild then continue end

        local map = workspace:FindFirstChild("Map")
        local ref = map and map:FindFirstChild("WildPetRef")
        if not ref then continue end

        local sel = States.wildCatchTargets or {}

        -- Kumpulkan pet valid sesuai filter nama
        local targets = {}
        for _, part in ipairs(ref:GetChildren()) do
            if not part:IsA("BasePart") then continue end
            if not IsWildPetFree(part) then continue end

            local petName = part:GetAttribute("PetName")
                or part:GetAttribute("Pet")
                or part:GetAttribute("Species")
                or part.Name

            -- Filter nama kalau ada pilihan
            if #sel > 0 then
                local match = false
                for _, target in ipairs(sel) do
                    if target == petName or target == tostring(petName) then
                        match = true; break
                    end
                end
                if not match then continue end
            end

            local rarity = part:GetAttribute("Rarity") or "Unknown"
            local price  = part:GetAttribute("Price") or 0
            table.insert(targets, {part=part, petName=tostring(petName), rarity=rarity, price=price})
        end

        -- Tidak ada pet → notif tunggu (max 1x per 15 detik)
        if #targets == 0 then
            local now = tick()
            if now - lastWaitingNotif >= 15 then
                lastWaitingNotif = now
                local filterStr = #sel > 0 and table.concat(sel, ", ") or "semua pet"
                Notify("Auto Catch", "⏳ Menunggu spawn: " .. filterStr, Colors.TextMuted, 5)
            end
            continue
        end

        -- Proses tiap pet satu per satu
        for _, entry in ipairs(targets) do
            if not States.autoCatchWild then break end

            local part    = entry.part
            local petName = entry.petName
            local rarity  = entry.rarity
            local price   = entry.price

            -- Validasi sebelum gerak
            if not IsWildPetFree(part) then continue end

            -- Hop ke pet (blocking)
            SmartMoveToPet(part.Position, nil)
            task.wait(0.15)

            -- Validasi ulang sesudah tiba
            if not IsWildPetFree(part) then continue end

            -- Fire Networking.Pets.WildPetTame:Fire(part.Name)
            local ok = BuyWildPet(part)
            if ok then
                Notify("Auto Catch",
                    "🎯 " .. HumanizePetName(petName) .. " (" .. rarity .. ") | " .. tostring(price) .. "¢",
                    RarityColor[rarity] or Colors.Warning, 4)
                task.wait(1.5)
            end
        end
    end
end)

-- AUTO EQUIP PETS LOOP (removed — FirePacket equip/unequip tidak valid di GAG)
-- Pet equip dilakukan langsung oleh game saat tool diaktifkan; tidak ada packet khusus.

-- AUTO OPEN EGGS LOOP (PacketID 139)
task.spawn(function()
    while _G._MiracleHubSession == _SESSION do
        task.wait(States.eggLoopDelay or 5)
        if not States.autoOpenEgg then continue end
        pcall(function()
            -- Teleport to gear shop
            local teleports = game:GetService("Workspace"):FindFirstChild("Teleports")
            if teleports then
                local gearPart = teleports:FindFirstChild("Gears")
                if gearPart and player.Character then
                    player.Character:PivotTo(gearPart.CFrame + Vector3.new(0, 5, 0))
                    task.wait(0.4)
                end
            end
            -- Find egg prompts in workspace
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
            -- Fire open egg packet directly
            FirePacket(PACKET.OpenEgg)
        end)
    end
end)

-- AUTO ACCEPT GIFTS / MAILBOX LOOP
task.spawn(function()
    while _G._MiracleHubSession == _SESSION do
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

-- ======================== ESP SYSTEM ========================
local espLabels = {}

local function ClearESP()
    for _, v in pairs(espLabels) do
        if v and v.Parent then v:Destroy() end
    end
    espLabels = {}
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
    table.insert(espLabels, billboard)
    return billboard
end

RunService.Heartbeat:Connect(function()
    -- ESP Players
    if States.espPlayers then
        for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
            if p ~= player and p.Character then
                local rootPart = p.Character:FindFirstChild("HumanoidRootPart")
                if rootPart and not rootPart:FindFirstChild("MiracleESP_Player") then
                    local bb = MakeESPLabel(rootPart, p.DisplayName .. "\n@" .. p.Name, Colors.Electric)
                    bb.Name = "MiracleESP_Player_" .. p.Name
                    Create("ObjectValue", {Parent = rootPart, Name = "MiracleESP_Player"})
                end
            end
        end
    else
        for _, v in pairs(espLabels) do
            if v and v.Name and v.Name:find("ESPPlayer") then
                v:Destroy()
            end
        end
    end

    -- ESP Wild Pets (pakai WildPetRef — path resmi GAG)
    if States.espItems then
        local map = workspace:FindFirstChild("Map")
        local ref = map and map:FindFirstChild("WildPetRef")
        if ref then
            for _, part in ipairs(ref:GetChildren()) do
                if part:IsA("BasePart") then
                    local owner = tonumber(part:GetAttribute("OwnerUserId")) or 0
                    if owner ~= 0 then continue end -- sudah dimiliki, skip
                    if not part:FindFirstChild("MiracleESP_WP") then
                        local rarity = part:GetAttribute("Rarity") or "?"
                        local col = RarityColor and RarityColor[rarity] or Colors.Warning
                        MakeESPLabel(part, "🐾 " .. rarity, col)
                        Create("ObjectValue", {Parent = part, Name = "MiracleESP_WP"})
                    end
                end
            end
        end
    end

    -- ESP Mutations (fruits on plants)
    if States.espMutations then
        local plants = GetPlantsFolder()
        if plants then
            for _, plant in ipairs(plants:GetChildren()) do
                local mut = GetMutation(plant)
                if mut and mut ~= "" and mut ~= "None" then
                    local rootPart = plant:FindFirstChildWhichIsA("BasePart")
                    if rootPart and not rootPart:FindFirstChild("MiracleESP_Mut") then
                        local sn = plant:GetAttribute("SeedName") or "Plant"
                        MakeESPLabel(rootPart, mut .. " " .. sn, GetMutationColor(mut))
                        Create("ObjectValue", {Parent = rootPart, Name = "MiracleESP_Mut"})
                    end
                end
            end
        end
    end

    -- Show Plant Age
    if States.showPlantAge then
        local plants = GetPlantsFolder()
        if plants then
            for _, plant in ipairs(plants:GetChildren()) do
                local age = plant:GetAttribute("Age")
                local maxAge = plant:GetAttribute("MaxAge")
                if age and maxAge then
                    local rootPart = plant:FindFirstChildWhichIsA("BasePart")
                    if rootPart and not rootPart:FindFirstChild("MiracleESP_Age") then
                        local sn = plant:GetAttribute("SeedName") or "Plant"
                        MakeESPLabel(rootPart, sn .. " " .. age .. "/" .. maxAge, age >= maxAge and Colors.Success or Colors.TextMuted)
                        Create("ObjectValue", {Parent = rootPart, Name = "MiracleESP_Age"})
                    end
                end
            end
        end
    end

    -- Visual Settings (apply every frame)
    local lighting = game:GetService("Lighting")
    if States.fullBright then
        lighting.Brightness = States.brightness
        lighting.Ambient = Color3.fromRGB(255, 255, 255)
        lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
    end
    if States.noFog then lighting.FogEnd = 100000 lighting.FogStart = 100000 end
    if States.noShadows then lighting.GlobalShadows = false end
    if States.lockWalkSpeed and humanoid then humanoid.WalkSpeed = States.walkSpeed end
    if States.lockJumpPower and humanoid then humanoid.JumpPower = States.jumpPower end
end)

-- Fly
local flyBody = nil
-- Mobile fly: track virtual joystick input jika ada (dari Roblox default mobile controls)
-- atau pakai gyroscope jika tidak ada joystick

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

            if isMobile then
                -- Mobile fly: pakai Humanoid MoveDirection (digerakkan joystick bawaan Roblox)
                local hum = player.Character:FindFirstChildOfClass("Humanoid")
                local moveDir = hum and hum.MoveDirection or Vector3.new()
                if moveDir.Magnitude > 0.1 then
                    vel = Vector3.new(moveDir.X, 0, moveDir.Z).Unit * States.flySpeed
                end
                -- Up/down: tidak ada tombol di mobile — pakai tilt kamera (cam.CFrame.LookVector.Y)
                local lookY = cf.LookVector.Y
                if math.abs(lookY) > 0.3 then
                    vel = vel + Vector3.new(0, lookY * States.flySpeed, 0)
                end
            else
                -- PC fly: WASD + Space + Ctrl
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then vel += cf.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then vel -= cf.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then vel -= cf.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then vel += cf.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vel += Vector3.new(0, 1, 0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then vel -= Vector3.new(0, 1, 0) end
            end

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

-- Anti AFK
-- Pakai active loop (setiap ~60s) biar idle timer selalu ke-reset
-- player.Idled tidak reliable di GAG karena di-suppress oleh game
local VirtualUser = game:GetService("VirtualUser")
task.spawn(function()
    while _G._MiracleHubSession == _SESSION do
        task.wait(60)
        if States.antiAfk then
            pcall(function()
                -- Simulasi klik kamera buat reset idle timer Roblox
                local cam = workspace.CurrentCamera
                VirtualUser:Button2Down(Vector2.new(0, 0), cam.CFrame)
                task.wait(0.1)
                VirtualUser:Button2Up(Vector2.new(0, 0), cam.CFrame)
            end)
        end
    end
end)
-- Tetap pasang Idled sebagai backup jaga-jaga
player.Idled:Connect(function()
    if States.antiAfk then
        pcall(function()
            local cam = workspace.CurrentCamera
            VirtualUser:Button2Down(Vector2.new(0, 0), cam.CFrame)
            task.wait(0.1)
            VirtualUser:Button2Up(Vector2.new(0, 0), cam.CFrame)
        end)
    end
end)

-- Character respawn handler
player.CharacterAdded:Connect(function(char)
    character = char
    humanoid = char:WaitForChild("Humanoid")
    flyBody = nil
end)

-- ======================== FEATURE: FARM PAGE ========================
Pages["Farm"] = function()
    local plantCard, plantContent = CreateSectionCard("🌱 Auto Plant", 1, Colors.Success)

    CreateInfoText(plantContent, "Cara Kerja",
        "Menanam seed secara otomatis ke plot kamu (Plot " .. MY_PLOT_ID .. "). "
        .. "Posisi tanam dideteksi langsung dari area tanam di plotmu. "
        .. "Selama Auto Plant aktif, loop akan terus berjalan — menanam ulang setelah plot penuh dan di-harvest."
    )

    -- Toggle utama: tidak bisa nyala jika belum pilih seed
    CreateToggle(plantContent, "Auto Plant", "autoPlant",
        "Aktifkan untuk menanam otomatis terus-menerus. Delay antar tanam: 0.3 detik.",
        function(newVal, revert)
            if newVal and not States.autoPlantAllSeeds then
                local targets = States.autoPlantTargets or {}
                if #targets == 0 then
                    revert()
                    Notify("Auto Plant", "⚠️ Pilih seed dulu di 'Pilih Seed yang Ditanam' sebelum aktifkan Auto Plant!", Colors.Warning, 5)
                    return
                end
            end
        end)

    -- Toggle: tanam semua atau hanya target yang dipilih
    CreateToggle(plantContent, "Tanam Semua Seed di Backpack", "autoPlantAllSeeds",
        "ON: tanam semua seed yang ada di backpack | OFF: hanya seed yang dipilih di bawah")

    -- Multi-select seed target
    CreateMultiSelect(plantContent, "🌱Pilih Seed yang Ditanam", SEEDS, "autoPlantTargets")

    CreateToggle(plantContent, "Notif Hasil Tanam", "autoPlantNotify",
        "Tampilkan notifikasi setiap kali satu siklus tanam selesai")

    -- Tombol: Tanam Sekarang (one-shot manual)
    CreateActionButton(plantContent, "⚡ Tanam Sekarang (Manual)", function()
        local plantAreas = GetMyPlantAreas()
        if #plantAreas == 0 then
            Notify("Farm", "❌ PlantArea tidak ditemukan di Plot " .. MY_PLOT_ID
                .. ". Pastikan kamu berada di plotmu.", Colors.Error)
            return
        end
        local firstSeed = GetNextSeedFromBackpack()
        if not firstSeed then
            Notify("Farm", "⚠ Tidak ada seed di backpack (sesuai filter).", Colors.Warning)
            return
        end
        Notify("Farm", "Mulai menanam di Plot " .. MY_PLOT_ID .. "...", Colors.Success)
        task.spawn(function()
            -- Build posisi valid (sudah filter overlap existing plants)
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
                    planted += 1
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
                NotifyStok(lines, Colors.Success, 8, "🌱 Tanam Sekarang (+" .. planted .. " ditanam)")
            else
                Notify("Farm", "Tidak ada yang ditanam.", Colors.Warning, 3)
            end
        end)
    end, Colors.Success)

    -- Tombol: Scan seed di backpack
    CreateActionButton(plantContent, "🔍 Scan Seed di Backpack", function()
        local backpack = player:FindFirstChildOfClass("Backpack")
        if not backpack then
            Notify("Farm", "Backpack tidak ditemukan.", Colors.Error)
            return
        end
        local counts = {}
        local total = 0
        for _, tool in ipairs(backpack:GetChildren()) do
            if not tool:IsA("Tool") then continue end
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
                total += 1
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

    -- Tombol: Info slot terisi (per seed name)
    CreateActionButton(plantContent, "📊 Cek Slot Terisi", function()
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
        NotifyStok(lines, Colors.Accent, 15, "📊 Milikku: " .. totalPlanted .. " | Plot: " .. totalAll)
    end)


    local harvestCard, harvestContent = CreateSectionCard("🍅 Auto Harvest", 2, Colors.Warning)
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
    CreateDropdown(harvestContent, "Skip This Mutation", {"None", table.unpack(MUTATIONS)}, "harvestFilterMutation")
    CreateActionButton(harvestContent, "⚡ Harvest All Now", function()
        local myPlot = GetMyPlot()
        if not myPlot then
            Notify("Harvest", "❌ Plot " .. MY_PLOT_ID .. " tidak ditemukan!", Colors.Error)
            return
        end
        -- Cek kapasitas backpack
        local currentCount = player:GetAttribute("FruitCount") or 0
        local remaining = MAX_FRUIT_CAP - currentCount
        if remaining <= 0 then
            Notify("Harvest", "🎒 Backpack penuh! (" .. currentCount .. "/" .. MAX_FRUIT_CAP .. ")", Colors.Warning)
            return
        end
        -- Hitung buah siap via CollectionService (cepat)
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
            Notify("Harvest ✅", "Panen " .. harvested .. " buah | Bag " .. after .. "/" .. MAX_FRUIT_CAP, Colors.Success)
        end)
    end, Colors.Warning)
    CreateActionButton(harvestContent, "🔍 Scan Fruits Ready", function()
        local myPlot = GetMyPlot()
        if not myPlot then Notify("Scan", "❌ Plot tidak ditemukan!", Colors.Error) return end
        local readyList, total = {}, 0
        for _, prompt in ipairs(CollectionService:GetTagged("HarvestPrompt")) do
            if not prompt:IsDescendantOf(myPlot) then continue end
            local harvestPart = prompt.Parent
            local fruit = harvestPart and harvestPart.Parent
            if not (fruit and fruit:IsA("Model")) then continue end
            total += 1
            if prompt.Enabled and not prompt:GetAttribute("Collected") then
                local plant = fruit.Parent and fruit.Parent.Parent  -- Fruits folder → plant model
                local sn = (plant and plant:GetAttribute("SeedName"))
                    or fruit:GetAttribute("SeedName") or "?"
                local mut = fruit:GetAttribute("Mutation") or ""
                table.insert(readyList, sn .. (mut ~= "" and " ["..mut.."]" or ""))
            end
        end
        local currentCount = player:GetAttribute("FruitCount") or 0
        local msg = #readyList .. "/" .. total .. " siap | Bag " .. currentCount .. "/" .. MAX_FRUIT_CAP
            .. "\n" .. table.concat(readyList, ", "):sub(1, 80)
        Notify("Fruit Scanner 🔍", msg, Colors.Success, 7)
    end)

    local waterCard, waterContent = CreateSectionCard("💧 Watering & Sprinklers", 3, Colors.Electric)
    CreateInfoText(waterContent, "Gear from scanner", "Common Watering Can ×338, Common Sprinkler ×2 detected via WateringCan/Sprinkler attributes.")
    CreateToggle(waterContent, "Auto Water Plants", "autoWater", "Fires WaterPrompt or uses WateringCan tool")
    CreateToggle(waterContent, "Auto Place Sprinklers", "autoSprinkler", "Uses Common Sprinkler from backpack")
    CreateSlider(waterContent, "Water Loop Delay (s)", 0, 30, "harvestLoopDelay")
    CreateActionButton(waterContent, "Water All Now", function()
        local plants = GetPlantsFolder()
        local watered = 0
        if plants then
            for _, plant in ipairs(plants:GetChildren()) do
                for _, desc in ipairs(plant:GetDescendants()) do
                    if desc:IsA("ProximityPrompt") and desc.Name:lower():find("water") then
                        SafeFirePrompt(desc)
                        watered += 1
                        task.wait(0.1)
                        break
                    end
                end
            end
        end
        Notify("Watering", "Watered " .. watered .. " plants on Plot " .. MY_PLOT_ID, Colors.Electric)
    end, Colors.Electric)
end

-- ======================== FEATURE: PLOT PAGE ========================
Pages["Plot"] = function()
    local plotCard, plotContent = CreateSectionCard("📐 My Plot — Plot " .. MY_PLOT_ID, 1, Colors.Accent)
    CreateInfoText(plotContent, "Detected from scanner", "PlotId = " .. MY_PLOT_ID .. " | Path: Workspace.Gardens.Plot" .. MY_PLOT_ID .. " | GardenExpansion = 1 | SpawnPoint detected | Signs: GreyMailBox, Garden (CustomiseTheme, GardenSign* prompts), Expand model")

    local statsGrid = Create("Frame", {
        Parent = plotContent,
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
    })
    CreateListLayout(statsGrid, 5)

    local _, plotLbl = CreateStatRow(statsGrid, "My Plot ID", MY_PLOT_ID, Colors.Success)
    local _, fruitCntLbl = CreateStatRow(statsGrid, "Fruit Count (Player Attr)", player:GetAttribute("FruitCount") or "?", Colors.Warning)
    local _, maxFruitLbl = CreateStatRow(statsGrid, "Max Fruit Capacity", MAX_FRUIT_CAP, Colors.Accent)
    local _, petSlotLbl = CreateStatRow(statsGrid, "Max Equipped Pets", MAX_EQUIPPED_PETS, Colors.Rainbow)
    local _, gardenLikesLbl = CreateStatRow(statsGrid, "Garden Likes", player:GetAttribute("GardenLikes") or 0, Colors.Gold)

    -- Live plant count
    local _, plantCntLbl = CreateStatRow(statsGrid, "Plants on Plot", "...", Colors.TextSecondary)
    local _, readyCntLbl = CreateStatRow(statsGrid, "Ready to Harvest", "...", Colors.Success)

    -- Live plant count — pakai task.spawn + task.wait(1) bukan Heartbeat
    -- Heartbeat bug: tidak pernah disconnect, setiap buka Plot page nambah listener baru
    local plotPageAlive = true
    task.spawn(function()
        while plotPageAlive and ActivePage == "Plot" do
            task.wait(1)
            if not plotPageAlive or ActivePage ~= "Plot" then break end
            local ok = pcall(function()
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
                        if p:IsA("Model") then
                            total += 1
                        end
                    end
                end
                -- Hitung ready via CollectionService (ringan)
                for _, prompt in ipairs(CollectionService:GetTagged("HarvestPrompt")) do
                    if prompt.Enabled and not prompt:GetAttribute("Collected")
                        and prompt:IsDescendantOf(myPlot) then
                        readyFruits += 1
                    end
                end
                plantCntLbl.Text = tostring(total)
                readyCntLbl.Text = tostring(readyFruits)
            end)
        end
    end)
    -- Stop loop saat halaman pindah
    local _plotConn
    _plotConn = game:GetService("RunService").Heartbeat:Connect(function()
        if ActivePage ~= "Plot" then
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

    local pottedCard, pottedContent = CreateSectionCard("🪴 Potted Plants", 2, Colors.Rainbow)
    CreateInfoText(pottedContent, "Scanner detected", "Blueberry [Rainbow][Potted] in backpack — PottedPlant=true, Age=3/3, SizeMultiplier=1.95, MaxFruitSpawnLocations=3. PickUpPottedPlantPrompt found in workspace.")
    CreateActionButton(pottedContent, "Auto Pickup Potted Plants", function()
        local picked = 0
        for _, desc in ipairs(game:GetService("Workspace"):GetDescendants()) do
            if desc:IsA("ProximityPrompt") and desc.Name == "PickUpPottedPlantPrompt" then
                SafeFirePrompt(desc)
                picked += 1
                task.wait(0.2)
            end
        end
        Notify("Potted", "Picked up " .. picked .. " potted plant(s)", Colors.Rainbow)
    end, Colors.Rainbow)
    CreateToggle(pottedContent, "Auto Place Potted Plants", "autoPlant", "Places potted plants via proximity prompt")
end

-- ======================== FEATURE: SHOP PAGE ========================
Pages["Shop"] = function()
    local buyCard, buyContent = CreateSectionCard("🛒 Auto Buy Seeds", 1, Colors.Success)

    CreateInfoText(buyContent, "Cara Pakai", "1. Pilih seed yang ingin dibeli di 'Pilih Seed Target' di bawah.\n2. Aktifkan toggle 'Auto Buy Seeds'.\n3. Script akan otomatis membeli 1 seed per cycle selama stok tersedia.\n4. Jika stok habis, loop tetap berjalan dan langsung beli begitu restock.\nGunakan 'Beli SEMUA yang ada stok' untuk auto-beli semua seed yang tersedia tanpa perlu pilih satu per satu.")

    CreateToggle(buyContent, "Auto Buy Seeds", "autoBuySeed", "Loop cepat beli seed yang dipilih, stop jika stok 0", function(newVal, revert)
        if newVal and not States.autoBuyAll then
            local targets = States.autoBuySeedTargets or {}
            if #targets == 0 then
                revert()
                Notify("Auto Buy", "⚠️ Pilih seed dulu di 'Pilih Seed Target' sebelum aktifkan Auto Buy!", Colors.Warning, 5)
                return
            end
        end
        -- Mute error sound setiap kali auto buy diaktifkan
        if newVal then
            pcall(MuteSFX_Failed)
        end
    end)
    CreateToggle(buyContent, "Beli SEMUA yang ada stok", "autoBuyAll", "ON: beli semua seed yg stok > 0 | OFF: hanya seed dipilih di bawah")

    -- Multi-select seed target
    CreateMultiSelect(buyContent, "🌱Pilih Seed Target", SEEDS, "autoBuySeedTargets")

    CreateSlider(buyContent, "Delay Antar Beli (s)", 0, 2, "buyDelay")
    CreateSlider(buyContent, "Loop Delay (s)", 0, 10, "shopLoopDelay")
    CreateToggle(buyContent, "Notif Saat Beli", "notifyBuy", "Tampilkan notif setiap seed dibeli")

    -- ======================== PREDICT NEXT STOCK SECTION ========================
    local predictCard, predictContent = CreateSectionCard("🔮 Predict Next Stock", 2, Colors.Rainbow)

    CreateInfoText(predictContent, "Cara Kerja",
        "Menggunakan RestockChance dari SeedData (data resmi game) untuk hitung rata-rata "
        .. "berapa restock lagi sampai seed muncul. Contoh: Dragon's Breath RestockChance=0.2% "
        .. "→ rata-rata muncul tiap 500 restock (~41 jam). "
        .. "Seed yang stoknya sudah habis, lacak via Changed event untuk tahu kapan terakhir muncul."
    )

    -- ===== DATA RESTOCKCHANCE dari SeedData (di-hardcode dari hasil require SeedData) =====
    -- Sumber: require(ReplicatedStorage.SharedModules.SeedData) — verified scanner
    local SEED_RESTOCK_DATA = {
        ["Carrot"]          = { chance = 100,   restockMin = 3,  restockMax = 4  },
        ["Strawberry"]      = { chance = 100,   restockMin = 4,  restockMax = 5  },
        ["Blueberry"]       = { chance = 100,   restockMin = 1,  restockMax = 2  },
        ["Tulip"]           = { chance = 100,   restockMin = 3,  restockMax = 4  },
        ["Tomato"]          = { chance = 90,    restockMin = 2,  restockMax = 3  },
        ["Apple"]           = { chance = 52.63, restockMin = 1,  restockMax = 1  },
        ["Bamboo"]          = { chance = 80,    restockMin = 7,  restockMax = 11 },
        ["Corn"]            = { chance = 35,    restockMin = 1,  restockMax = 1  },
        ["Cactus"]          = { chance = 16.668,restockMin = 1,  restockMax = 2  },
        ["Pineapple"]       = { chance = 12.501,restockMin = 1,  restockMax = 3  },
        ["Mushroom"]        = { chance = 9.092, restockMin = 2,  restockMax = 5  },
        ["Green Bean"]      = { chance = 15,    restockMin = 1,  restockMax = 2  },
        ["Banana"]          = { chance = 9,     restockMin = 1,  restockMax = 1  },
        ["Grape"]           = { chance = 6.668, restockMin = 1,  restockMax = 1  },
        ["Coconut"]         = { chance = 5.001, restockMin = 1,  restockMax = 1  },
        ["Mango"]           = { chance = 5.001, restockMin = 1,  restockMax = 1  },
        ["Dragon Fruit"]    = { chance = 4,     restockMin = 1,  restockMax = 1  },
        ["Acorn"]           = { chance = 2.942, restockMin = 1,  restockMax = 3  },
        ["Cherry"]          = { chance = 2.274, restockMin = 1,  restockMax = 1  },
        ["Sunflower"]       = { chance = 1.787, restockMin = 1,  restockMax = 1  },
        ["Venus Fly Trap"]  = { chance = 1.43,  restockMin = 1,  restockMax = 1  },
        ["Pomegranate"]     = { chance = 0.927, restockMin = 1,  restockMax = 1  },
        ["Poison Apple"]    = { chance = 0.533, restockMin = 1,  restockMax = 1  },
        ["Venom Spitter"]   = { chance = 0.475, restockMin = 1,  restockMax = 1  },
        ["Moon Bloom"]      = { chance = 0.35,  restockMin = 1,  restockMax = 1  },
        ["Hypno Bloom"]     = { chance = 0.275, restockMin = 1,  restockMax = 1  },
        ["Dragon's Breath"] = { chance = 0.2,   restockMin = 1,  restockMax = 1  },
        ["Ghost Pepper"]    = { chance = 0.533, restockMin = 1,  restockMax = 1  },
        ["Poison Ivy"]      = { chance = 0.533, restockMin = 1,  restockMax = 1  },
        ["Glow Mushroom"]   = { chance = 0.533, restockMin = 1,  restockMax = 1  },
        ["Romanesco"]       = { chance = 0.533, restockMin = 1,  restockMax = 1  },
        ["Horned Melon"]    = { chance = 0.533, restockMin = 1,  restockMax = 1  },
    }

    -- ===== TRACKER: kapan tiap seed terakhir kali punya stok =====
    -- Diisi otomatis via Changed listener saat inject
    local seedLastSeenRestock = {}   -- [seedName] = restockIndex (dari UnixLastRestock)
    local seedNeverSeen = {}         -- [seedName] = true jika belum pernah terlihat sejak inject

    -- ===== HELPERS =====
    local function GetRestockData()
        local rs = game:GetService("ReplicatedStorage")
        local sv = rs:FindFirstChild("StockValues")
        if not sv then return nil end
        local ss = sv:FindFirstChild("SeedShop")
        if not ss then return nil end
        local nextVal = ss:FindFirstChild("UnixNextRestock")
        local lastVal = ss:FindFirstChild("UnixLastRestock")
        if not nextVal or not lastVal then return nil end
        local interval = math.max(nextVal.Value - lastVal.Value, 1)
        return {
            nextRestock = nextVal.Value,
            lastRestock = lastVal.Value,
            interval    = interval,
        }
    end

    local function FormatSeconds(secs)
        secs = math.max(0, math.floor(secs))
        local h = math.floor(secs / 3600)
        local m = math.floor((secs % 3600) / 60)
        local s = secs % 60
        if h > 0 then
            return h .. "j " .. m .. "m " .. s .. "s"
        elseif m > 0 then
            return m .. "m " .. s .. "s"
        end
        return s .. "s"
    end

    local function FormatUnixTime(unix)
        local d = os.date("*t", unix)
        if d then
            return string.format("%02d:%02d:%02d", d.hour, d.min, d.sec)
        end
        return tostring(unix)
    end

    -- Hitung expected restock ke-N (expected value dari distribusi geometrik)
    -- Jika chance = p%, maka rata-rata butuh 100/p restock
    -- Kita hitung restock ke-N yang paling "masuk akal" dengan probabilitas kumulatif ≥ 75%
    -- P(muncul dalam N restock) = 1 - (1 - p/100)^N ≥ 0.75
    -- N = ceil(log(0.25) / log(1 - p/100))
    local function ExpectedRestocksUntilAppear(chance)
        if chance >= 100 then return 1 end
        local p = chance / 100
        -- Expected value (mean): 1/p restock
        local mean = math.ceil(1 / p)
        return mean
    end

    local function RestocksFor75Pct(chance)
        if chance >= 100 then return 1 end
        local p = chance / 100
        -- N = log(0.25) / log(1 - p)
        local n = math.ceil(math.log(0.25) / math.log(1 - p))
        return math.max(1, n)
    end

    -- Warna berdasarkan berapa restock lagi
    local function RestockColor(restocksLeft)
        if restocksLeft <= 1   then return Colors.Success  -- segera
        elseif restocksLeft <= 10  then return Colors.Warning  -- sebentar lagi
        elseif restocksLeft <= 50  then return Colors.Electric -- lumayan lama
        else                        return Colors.Error        -- sangat lama
        end
    end

    -- ===== LIVE TRACKER: pasang Changed listener untuk semua seed =====
    -- Setiap kali stok seed berubah dari 0 → >0, catat restockIndex saat itu
    local _trackerRestockIndex = 0  -- counter berapa kali restock sudah terjadi sejak inject
    task.spawn(function()
        local rs = game:GetService("ReplicatedStorage")
        local sv = rs:WaitForChild("StockValues", 5)
        if not sv then return end
        local ss = sv:WaitForChild("SeedShop", 5)
        if not ss then return end
        local items = ss:WaitForChild("Items", 5)
        if not items then return end

        -- Catat initial state (saat inject)
        for _, child in ipairs(items:GetChildren()) do
            if child:IsA("NumberValue") then
                if child.Value > 0 then
                    seedLastSeenRestock[child.Name] = 0  -- ada stok sekarang
                else
                    seedNeverSeen[child.Name] = true
                end
            end
        end

        -- Track UnixLastRestock untuk hitung restockIndex
        local lastRestockVal = ss:FindFirstChild("UnixLastRestock")
        if lastRestockVal then
            lastRestockVal.Changed:Connect(function()
                _trackerRestockIndex += 1
            end)
        end

        -- Pasang listener ke setiap seed
        for _, child in ipairs(items:GetChildren()) do
            if child:IsA("NumberValue") then
                local sn = child.Name
                local prevVal = child.Value
                child.Changed:Connect(function(newVal)
                    if newVal > 0 and prevVal == 0 then
                        -- Seed muncul! Catat restock index saat ini
                        seedLastSeenRestock[sn] = _trackerRestockIndex
                        seedNeverSeen[sn] = nil
                    end
                    prevVal = newVal
                end)
            end
        end
    end)

    -- ===== UI: Live Timer Header =====
    local timerRow = Create("Frame", {
        Parent = predictContent,
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
    })
    CreateListLayout(timerRow, 4)

    local _, nextRestockLbl = CreateStatRow(timerRow, "⏱ Restock Berikutnya", "...", Colors.Rainbow)
    local _, intervalLbl    = CreateStatRow(timerRow, "📐 Interval",           "...", Colors.TextSecondary)
    local _, stockCountLbl  = CreateStatRow(timerRow, "📦 Tersedia Sekarang",  "...", Colors.Success)

    local _predictTick = 0
    RunService.Heartbeat:Connect(function(dt)
        if ActivePage ~= "Shop" then return end
        _predictTick += dt
        if _predictTick < 0.5 then return end
        _predictTick = 0

        local data = GetRestockData()
        if not data then
            nextRestockLbl.Text = "⚠ StockValues tidak ditemukan"
            intervalLbl.Text    = "—"
            stockCountLbl.Text  = "—"
            return
        end

        local sisa = math.max(0, data.nextRestock - os.time())
        nextRestockLbl.Text = sisa > 0 and (FormatSeconds(sisa) .. "  (jam " .. FormatUnixTime(data.nextRestock) .. ")") or "🟢 RESTOCK SEKARANG!"
        intervalLbl.Text    = FormatSeconds(data.interval)

        local rs = game:GetService("ReplicatedStorage")
        local items = rs:FindFirstChild("StockValues") and rs.StockValues:FindFirstChild("SeedShop") and rs.StockValues.SeedShop:FindFirstChild("Items")
        local available = 0
        if items then
            for _, c in ipairs(items:GetChildren()) do
                if c:IsA("NumberValue") and c.Value > 0 then available += 1 end
            end
        end
        stockCountLbl.Text = available .. " seed ada stok"
    end)

    -- ===== UI: Cek per-seed =====
    CreateSubHeader(predictContent, "🌱 Prediksi Per Seed")

    States.predictSeedTarget = States.predictSeedTarget or SEEDS[1]
    CreateDropdown(predictContent, "Pilih Seed", SEEDS, "predictSeedTarget")

    CreateActionButton(predictContent, "🔍 Prediksi Seed Ini", function()
        local seedName = States.predictSeedTarget or SEEDS[1]
        local data = GetRestockData()
        if not data then
            Notify("Predict", "⚠️ Data restock tidak ditemukan!", Colors.Warning, 5)
            return
        end

        local stock   = GetSeedStock(seedName)
        local sdata   = SEED_RESTOCK_DATA[seedName]
        local now     = os.time()
        local sisa    = math.max(0, data.nextRestock - now)
        local interval = data.interval

        if stock > 0 then
            -- Ada stok sekarang
            Notify("🌱 " .. seedName, "✅ Ada stok: " .. stock, Colors.Success, 8)
            task.wait(0.1)
            Notify("⏱ Restock berikutnya", FormatSeconds(sisa), Colors.Accent, 8)
            return
        end

        -- Stok habis — hitung prediksi
        if not sdata then
            Notify("🌱 " .. seedName, "❌ Stok habis, data chance tidak ditemukan", Colors.Warning, 6)
            return
        end

        local chance  = sdata.chance
        local meanN   = ExpectedRestocksUntilAppear(chance)   -- expected value
        local n75     = RestocksFor75Pct(chance)               -- 75% probability

        -- Kalau kita tahu kapan terakhir seed ini terlihat, hitung dari situ
        local lastIdx = seedLastSeenRestock[seedName]
        local sinceLastSeen = lastIdx and (_trackerRestockIndex - lastIdx) or nil

        -- Estimasi: berapa restock lagi dari SEKARANG sampai muncul (expected)
        local restocksLeft
        if sinceLastSeen then
            -- Sudah sinceLastSeen restock berlalu tanpa muncul
            -- Karena geometric distribution memoryless, tetap = meanN dari sekarang
            restocksLeft = meanN
        else
            restocksLeft = meanN
        end

        local etaDetik  = sisa + (interval * (restocksLeft - 1))
        local eta75Detik = sisa + (interval * (n75 - 1))

        local col = RestockColor(restocksLeft)

        Notify("🌱 " .. seedName, "❌ Stok habis | Chance: " .. chance .. "%", col, 10)
        task.wait(0.1)
        Notify("📊 Expected muncul", "~" .. restocksLeft .. " restock lagi (~" .. FormatSeconds(etaDetik) .. ")", col, 10)
        task.wait(0.1)
        Notify("🎯 75% kemungkinan", "dalam " .. n75 .. " restock (~" .. FormatSeconds(eta75Detik) .. ")", Colors.Warning, 10)
        if sinceLastSeen then
            task.wait(0.1)
            Notify("🕐 Terakhir terlihat", sinceLastSeen .. " restock lalu (sejak inject)", Colors.TextSecondary, 10)
        end
    end, Colors.Rainbow)

    -- ===== Tombol: Scan semua seed + prediksi =====
    CreateActionButton(predictContent, "📋 Scan Semua + Prediksi", function()
        local data = GetRestockData()
        if not data then
            Notify("Predict", "⚠️ Data restock tidak ditemukan!", Colors.Warning, 5)
            return
        end

        local now      = os.time()
        local sisa     = math.max(0, data.nextRestock - now)
        local interval = data.interval

        -- Kelompokkan: ada stok vs habis
        local hasStock  = {}
        local noStock   = {}

        local rs    = game:GetService("ReplicatedStorage")
        local items = rs:FindFirstChild("StockValues") and rs.StockValues:FindFirstChild("SeedShop") and rs.StockValues.SeedShop:FindFirstChild("Items")

        if not items then
            Notify("Predict", "⚠️ Items tidak ditemukan!", Colors.Warning)
            return
        end

        for _, child in ipairs(items:GetChildren()) do
            if child:IsA("NumberValue") then
                local sn    = child.Name
                local sdata = SEED_RESTOCK_DATA[sn]
                if child.Value > 0 then
                    table.insert(hasStock, sn .. " x" .. child.Value)
                elseif sdata and sdata.chance < 100 then
                    local meanN    = ExpectedRestocksUntilAppear(sdata.chance)
                    local etaSecs  = sisa + (interval * (meanN - 1))
                    table.insert(noStock, { name = sn, eta = etaSecs, n = meanN, chance = sdata.chance })
                end
            end
        end

        -- Sort noStock dari yang paling cepat muncul
        table.sort(noStock, function(a, b) return a.eta < b.eta end)

        -- Notif: yang ada stok dulu
        if #hasStock > 0 then
            Notify("✅ Ada Stok (" .. #hasStock .. ")", table.concat(hasStock, "  ·  "), Colors.Success, 12)
        else
            Notify("✅ Ada Stok", "Tidak ada seed yang tersedia sekarang", Colors.TextMuted, 6)
        end

        -- Notif: prediksi per-seed yang habis (ambil 6 teratas = paling cepat muncul)
        task.wait(0.15)
        Notify("⏱ Restock Berikutnya", FormatSeconds(sisa), Colors.Rainbow, 12)

        local shown = 0
        for _, entry in ipairs(noStock) do
            if shown >= 8 then break end
            task.wait(0.12)
            local label = entry.name
            local etaStr = FormatSeconds(entry.eta)
            local chanceStr = string.format("%.3f", entry.chance) .. "%"
            Notify("🌱 " .. label, "~" .. entry.n .. " restock  (~" .. etaStr .. ")  [" .. chanceStr .. "]", RestockColor(entry.n), 12)
            shown += 1
        end
    end, Colors.Accent)

    -- ===== Tombol: Coming Next Restock (seperti LuminHub) =====
    CreateActionButton(predictContent, "🔜 Coming Next Restock", function()
        local data = GetRestockData()
        if not data then
            Notify("Predict", "⚠️ Data restock tidak ditemukan!", Colors.Warning, 5)
            return
        end

        local now  = os.time()
        local sisa = math.max(0, data.nextRestock - now)

        local rs    = game:GetService("ReplicatedStorage")
        local items = rs:FindFirstChild("StockValues") and rs.StockValues:FindFirstChild("SeedShop") and rs.StockValues.SeedShop:FindFirstChild("Items")
        if not items then return end

        -- Seed yang stok sekarang > 0 → pasti ada di restock ini
        -- Seed yang stok = 0 tapi chance = 100 → pasti muncul berikutnya
        -- Seed yang stok = 0 dan chance < 100 → mungkin muncul (berdasarkan chance)
        local certain  = {}  -- pasti muncul berikutnya (chance 100 atau sudah ada)
        local probable = {}  -- kemungkinan muncul (chance tinggi)

        for _, child in ipairs(items:GetChildren()) do
            if not child:IsA("NumberValue") then continue end
            local sn    = child.Name
            local sdata = SEED_RESTOCK_DATA[sn]
            if not sdata then continue end

            if child.Value > 0 then
                table.insert(certain, sn .. " x" .. child.Value)
            elseif sdata.chance >= 100 then
                table.insert(certain, sn .. " (pasti)")
            elseif sdata.chance >= 30 then
                table.insert(probable, sn .. " (" .. string.format("%.0f", sdata.chance) .. "%)")
            end
        end

        Notify("⏱ Next Restock", FormatSeconds(sisa) .. " lagi", Colors.Rainbow, 10)
        task.wait(0.12)
        if #certain > 0 then
            Notify("✅ Pasti Muncul", table.concat(certain, "  ·  "), Colors.Success, 10)
        end
        if #probable > 0 then
            task.wait(0.12)
            Notify("🎲 Kemungkinan Muncul", table.concat(probable, "  ·  "), Colors.Warning, 10)
        end
    end, Colors.Success)

    -- ======================== AUTO BUY GEAR SECTION ========================
    local gearCard, gearContent = CreateSectionCard("⚙️ Auto Buy Gear", 3, Colors.Electric)

    CreateInfoText(gearContent, "Cara Pakai", "1. Pilih gear yang ingin dibeli di 'Pilih Gear Target' di bawah.\n2. Aktifkan toggle 'Auto Buy Gear'.\n3. Script akan otomatis membeli 1 gear per cycle selama stok tersedia.\n4. Jika stok habis, loop tetap berjalan dan langsung beli begitu server restock.\nGunakan 'Beli SEMUA Gear yang ada stok' untuk auto-beli semua gear tanpa pilih satu per satu.")

    CreateToggle(gearContent, "Auto Buy Gear", "autoBuyGear", "Loop cepat beli gear yang dipilih, stop jika stok 0", function(newVal, revert)
        if newVal and not States.autoBuyGearAll then
            local targets = States.autoBuyGearTargets or {}
            if #targets == 0 then
                revert()
                Notify("Auto Buy Gear", "⚠️ Pilih gear dulu di 'Pilih Gear Target' sebelum aktifkan Auto Buy Gear!", Colors.Warning, 5)
                return
            end
        end
        if newVal then
            pcall(MuteSFX_Failed)
        end
    end)
    CreateToggle(gearContent, "Beli SEMUA Gear yang ada stok", "autoBuyGearAll", "ON: beli semua gear yg stok > 0 | OFF: hanya gear dipilih di bawah")

    -- Multi-select gear target
    CreateMultiSelect(gearContent, "⚙️Pilih Gear Target", GEARS, "autoBuyGearTargets")

    CreateSlider(gearContent, "Delay Antar Beli Gear (s)", 0, 2, "gearBuyDelay")
    CreateSlider(gearContent, "Loop Delay Gear (s)", 0, 10, "gearShopLoopDelay")
    CreateToggle(gearContent, "Notif Saat Beli Gear", "notifyBuyGear", "Tampilkan notif setiap gear dibeli")

    -- ======================== AUTO BUY CRATE SECTION ========================
    local crateCard, crateContent = CreateSectionCard("📦 Auto Buy Crate", 4, Colors.Warning)

    CreateInfoText(crateContent, "Cara Pakai", "1. Pilih crate yang ingin dibeli di 'Pilih Crate Target' di bawah.\n2. Aktifkan toggle 'Auto Buy Crate'.\n3. Script otomatis beli 1 crate per cycle selama stok tersedia.\n4. Stok dibaca dari StockValues.CrateShop.Items (sama dengan seed/gear).\nGunakan 'Beli SEMUA Crate yang ada stok' untuk beli semua tanpa pilih satu per satu.")

    CreateToggle(crateContent, "Auto Buy Crate", "autoBuyCrate", "Loop cepat beli crate yang dipilih, stop jika stok 0", function(newVal, revert)
        if newVal and not States.autoBuyCrateAll then
            local targets = States.autoBuyCrateTargets or {}
            if #targets == 0 then
                revert()
                Notify("Auto Buy Crate", "⚠️ Pilih crate dulu di 'Pilih Crate Target' sebelum aktifkan Auto Buy Crate!", Colors.Warning, 5)
                return
            end
        end
        if newVal then
            pcall(MuteSFX_Failed)
        end
    end)
    CreateToggle(crateContent, "Beli SEMUA Crate yang ada stok", "autoBuyCrateAll", "ON: beli semua crate yg stok > 0 | OFF: hanya crate dipilih di bawah")

    -- Multi-select crate target
    CreateMultiSelect(crateContent, "📦Pilih Crate Target", CRATES, "autoBuyCrateTargets")

    CreateSlider(crateContent, "Delay Antar Beli Crate (s)", 0, 2, "crateBuyDelay")
    CreateSlider(crateContent, "Loop Delay Crate (s)", 0, 10, "crateShopLoopDelay")
    CreateToggle(crateContent, "Notif Saat Beli Crate", "notifyBuyCrate", "Tampilkan notif setiap crate dibeli")

    -- Tombol beli manual
    CreateActionButton(crateContent, "🛒 Beli Crate yang Dipilih Sekarang", function()
        local targets = States.autoBuyCrateTargets or {}
        if #targets == 0 then
            Notify("Buy Crate", "⚠️ Pilih crate dulu di bawah!", Colors.Warning)
            return
        end
        local bought = 0
        for _, crateName in ipairs(targets) do
            local stock = GetCrateStock(crateName)
            if stock > 0 then
                BuyCratePacket(crateName, 1)
                bought += 1
                task.wait(0.1)
            end
        end
        Notify("Buy Crate", "Beli " .. bought .. " crate sekarang.", Colors.Warning)
    end, Colors.Warning)

    -- Harga info
    CreateActionButton(crateContent, "💰 Lihat Harga Crate", function()
        local lines = {}
        for _, name in ipairs(CRATES) do
            local cost = CRATE_COST[name] or 0
            local costStr = cost >= 1000000 and string.format("%.1fM", cost/1000000) or string.format("%dk", cost/1000)
            table.insert(lines, name:gsub(" Crate", "") .. ": ¢" .. costStr)
        end
        Notify("Harga Crate", table.concat(lines, " | "):sub(1, 200), Colors.Gold, 10)
    end)

    -- ======================== AUTO OPEN CRATE SECTION ========================
    local openCrateCard, openCrateContent = CreateSectionCard("🎁 Auto Open Crate", 5, Colors.Gold)

    CreateInfoText(openCrateContent, "Cara Kerja", "Script cek inventory tiap beberapa detik. Jika ada crate tool di backpack, otomatis equip lalu open via Networking.Crate.OpenCrate:Fire(crateName) — cara yang sama seperti CrateController game. Delay antar open penting agar animasi efek selesai dulu.\nPaling efektif dikombinasikan dengan Auto Buy Crate di atas.")

    CreateToggle(openCrateContent, "Auto Open Crate", "autoOpenCrate", "Open semua crate di inventory secara otomatis")
    CreateSlider(openCrateContent, "Delay Antar Open (s)", 1, 30, "crateOpenDelay")
    CreateToggle(openCrateContent, "Notif Hasil Open", "notifyOpenCrate", "Tampilkan item yang didapat saat open crate")

    -- Scan crate di inventory
    CreateActionButton(openCrateContent, "🔍 Scan Crate di Inventory", function()
        local cratesInBag = GetCratesInInventory()
        if #cratesInBag == 0 then
            Notify("Scan Crate", "Tidak ada crate di inventory.", Colors.TextMuted)
            return
        end
        local names = {}
        for _, entry in ipairs(cratesInBag) do
            table.insert(names, entry.name)
        end
        Notify("Crate di Bag (" .. #cratesInBag .. ")", table.concat(names, ", "):sub(1, 150), Colors.Warning, 6)
    end)

    -- Open semua sekarang (one-shot manual)
    CreateActionButton(openCrateContent, "⚡ Open Semua Crate Sekarang", function()
        local cratesInBag = GetCratesInInventory()
        if #cratesInBag == 0 then
            Notify("Open Crate", "Tidak ada crate di inventory!", Colors.Error)
            return
        end
        Notify("Open Crate", "Opening " .. #cratesInBag .. " crate(s)...", Colors.Warning)
        task.spawn(function()
            for _, entry in ipairs(cratesInBag) do
                local tool = entry.tool
                local crateName = entry.name

                -- Equip dulu
                if tool.Parent ~= player.Character then
                    tool.Parent = player.Character
                    task.wait(0.2)
                end

                local ok, result = pcall(function()
                    return OpenCrateViaNetworking(crateName)
                end)

                if ok then
                    local wonItem = type(result) == "table" and result.WonItem
                    if wonItem then
                        Notify("📦 " .. crateName, "Dapat: " .. (wonItem.Name or "?") .. (wonItem.Chance and string.format(" (%.2f%%)", wonItem.Chance) or ""), Colors.Gold, 5)
                    else
                        Notify("📦 Opened!", crateName, Colors.Warning, 3)
                    end
                end

                task.wait(0.5)
                if tool and tool.Parent == player.Character then
                    tool.Parent = player.Backpack
                end
                task.wait(States.crateOpenDelay or 8)
            end
        end)
    end, Colors.Gold)

    -- Copy Packet IDs (dev tool, dipindah ke sini)
    CreateActionButton(openCrateContent, "📋 Copy Semua Packet IDs", function()
        local ids = {}
        for k, v in pairs(PACKET) do
            table.insert(ids, k .. "=" .. v)
        end
        table.sort(ids)
        setclipboard(table.concat(ids, ", "))
        Notify("Dev", "Semua Packet IDs disalin ke clipboard.", Colors.Accent)
    end)
end

-- ======================== FEATURE: SELL PAGE ========================
Pages["Sell"] = function()
    local sellCard, sellContent = CreateSectionCard("💰 Auto Sell", 1, Colors.Gold)

    -- Status Networking
    local netStatus = Networking and "✅ Networking OK (Networking.NPCS.SellAll)" or "❌ Networking nil — sell tidak akan work!"
    CreateInfoText(sellContent, "Sell System (FIXED)", netStatus .. "\nCara benar: Networking.NPCS.SellAll:Fire() atau SellFruit:Fire(fruitId). TANPA teleport, TANPA ProximityPrompt.")

    CreateToggle(sellContent, "Auto Sell Fruits", "autoSell", "Loop otomatis jual semua buah via Networking.NPCS.SellAll")
    CreateToggle(sellContent, "Keep Mutations (Jangan Dijual)", "keepMutations", "Skip semua buah yg punya mutation apapun (pakai mode selective)")
    CreateDropdown(sellContent, "Keep Mutation Spesifik", {"None", table.unpack(MUTATIONS)}, "harvestFilterMutation")
    CreateSlider(sellContent, "Delay Antar Jual (s)", 0, 3, "sellDelay")
    CreateSlider(sellContent, "Loop Delay (s)", 1, 60, "sellLoopDelay")
    CreateToggle(sellContent, "Notif Saat Jual", "notifySell", "Tampilkan notif hasil penjualan + total ¢")

    -- Preview harga
    CreateActionButton(sellContent, "🔍 Preview Harga Inventory", function()
        if not Networking then
            Notify("Preview", "❌ Networking nil!", Colors.Error)
            return
        end
        local result = pcall(function() return Networking.NPCS.PreviewSellAll:Fire() end)
        local ok, data = pcall(function() return Networking.NPCS.PreviewSellAll:Fire() end)
        if ok and data and data.FruitCount then
            local dd = pcall(function() return Networking.NPCS.CheckDailyDeal:Fire() end)
            local ddok, dddata = pcall(function() return Networking.NPCS.CheckDailyDeal:Fire() end)
            local ddAvail = ddok and dddata and dddata.Available
            local msg = data.FruitCount .. " buah | Normal: " .. tostring(data.TotalValue or 0) .. "¢"
            if ddAvail then
                local ddPrice = math.max(1, math.floor((data.TotalBaseValue or data.TotalValue or 0) * 5))
                msg = msg .. " | Daily Deal: " .. tostring(ddPrice) .. "¢ (5x!) ⭐"
            end
            Notify("Preview Sell", msg, Colors.Gold, 6)
        else
            Notify("Preview Sell", "Tidak ada buah di inventory.", Colors.TextMuted)
        end
    end)

    -- Jual semua sekarang (one-shot)
    CreateActionButton(sellContent, "⚡ Jual Semua Sekarang", function()
        if not Networking then
            Notify("Sell", "❌ Networking nil! Coba reload hub.", Colors.Error)
            return
        end
        local ok, result = pcall(function() return Networking.NPCS.SellAll:Fire() end)
        if ok and result and result.Success then
            Notify("Sell ✅", "Sold " .. (result.SoldCount or "?") .. " buah = " .. tostring(result.SellPrice or 0) .. "¢", Colors.Gold, 10)
        else
            Notify("Sell", "Gagal: " .. tostring(result and result.Reason or "Networking error"), Colors.Error)
        end
    end, Colors.Gold)

    -- Jual selective (per-buah, dengan filter)
    CreateActionButton(sellContent, "🎯 Jual Selective (Pakai Filter)", function()
        if not Networking then
            Notify("Sell", "❌ Networking nil!", Colors.Error)
            return
        end
        local fruits = {}
        for _, tool in ipairs(player.Backpack:GetChildren()) do
            if tool:GetAttribute("FruitName") or tool:GetAttribute("HarvestedFruit") then
                table.insert(fruits, tool)
            end
        end
        if #fruits == 0 then
            Notify("Sell", "Tidak ada buah di backpack.", Colors.TextMuted)
            return
        end
        local sold, skipped = 0, 0
        for _, tool in ipairs(fruits) do
            if ShouldKeepFruit(tool) then skipped += 1; continue end
            local fruitId = tool:GetAttribute("Id")
            if not fruitId then skipped += 1; continue end
            local ok, result = pcall(function() return Networking.NPCS.SellFruit:Fire(fruitId) end)
            if ok and result and result.Success then
                sold += 1
            elseif result and result.Reason == "Favorited" then
                skipped += 1
            end
            task.wait(States.sellDelay or 0.1)
        end
        Notify("Sell Selective", "Sold " .. sold .. " buah, skip " .. skipped, Colors.Gold, 10)
    end)

    local bagCard, bagContent = CreateSectionCard("🎒 Bag Inspector", 2, Colors.Accent)
    CreateInfoText(bagContent, "Fruit attrs from scanner", "Weight, SizeMultiplier, DecayAlpha, OvertimeGrowth, Mutation, Seed, HarvestedFruit | Tomato [1.38kg] | Blueberry [Rainbow][Potted]")
    local _, fruitLbl = CreateStatRow(bagContent, "Harvested Fruits in Bag", "?", Colors.Warning)
    local _, seedLbl = CreateStatRow(bagContent, "Seeds in Bag", "?", Colors.Success)
    local _, petCntLbl = CreateStatRow(bagContent, "Pets in Bag", "?", Colors.Frozen)
    local _, capLbl = CreateStatRow(bagContent, "Capacity", "? / " .. MAX_FRUIT_CAP, Colors.Accent)

    local _bagTick = 0
    RunService.Heartbeat:Connect(function(dt)
        if ActivePage ~= "Sell" then return end
        _bagTick += dt
        if _bagTick < 0.5 then return end
        _bagTick = 0
        local fruits, seeds, pets = 0, 0, 0
        for _, t in ipairs(player.Backpack:GetChildren()) do
            if t:GetAttribute("HarvestedFruit") then fruits += 1
            elseif t:GetAttribute("SeedTool") or t:GetAttribute("SeedName") then seeds += 1
            elseif t:GetAttribute("Pet") then pets += 1 end
        end
        fruitLbl.Text = tostring(fruits)
        seedLbl.Text = tostring(seeds)
        petCntLbl.Text = tostring(pets)
        capLbl.Text = fruits .. " / " .. tostring(player:GetAttribute("MaxFruitCapacity") or MAX_FRUIT_CAP)
    end)

    CreateActionButton(bagContent, "Show Highest Value Fruit", function()
        local best, bestWeight = nil, 0
        for _, t in ipairs(player.Backpack:GetChildren()) do
            local w = t:GetAttribute("Weight")
            if w and w > bestWeight then bestWeight = w best = t end
        end
        if best then
            local fn = best:GetAttribute("FruitName") or best.Name
            local mut = GetMutation(best)
            local sm = best:GetAttribute("SizeMultiplier") or 1
            Notify("Best Fruit", fn .. " | " .. mut .. " | " .. string.format("%.2f",bestWeight) .. "kg | x"..string.format("%.2f",sm), Colors.Gold, 6)
        else
            Notify("Bag", "No harvested fruits found.", Colors.TextMuted)
        end
    end, Colors.Gold)
    CreateActionButton(bagContent, "💎 Cek Harga Akurat (Server)", function()
        if Networking then
            -- Pakai server untuk harga akurat (sama persis yang akan diterima)
            local ok, data = pcall(function() return Networking.NPCS.PreviewSellAll:Fire() end)
            if ok and data and data.FruitCount and data.FruitCount > 0 then
                -- Cek daily deal juga
                local ddOk, ddData = pcall(function() return Networking.NPCS.CheckDailyDeal:Fire() end)
                local ddAvail = ddOk and ddData and ddData.Available
                local normalPrice = data.TotalValue or data.TotalBaseValue or 0
                local msg = data.FruitCount .. " buah | Jual Normal: " .. tostring(normalPrice) .. "¢"
                if ddAvail then
                    local ddPrice = math.max(1, math.floor((data.TotalBaseValue or normalPrice) * 5))
                    msg = msg .. "\n🌈 Daily Deal: " .. tostring(ddPrice) .. "¢ (5x lebih untung!)"
                end
                Notify("Harga Inventory (Real)", msg, Colors.Gold, 8)
            else
                Notify("Preview", "Inventory kosong / tidak ada buah.", Colors.TextMuted)
            end
        else
            -- Fallback: estimasi lokal dengan SellValueData
            local total = 0
            local count = 0
            for _, t in ipairs(player.Backpack:GetChildren()) do
                local fn = t:GetAttribute("FruitName")
                if fn and SELL_VALUE_DATA[fn] then
                    local base = SELL_VALUE_DATA[fn]
                    local sm = t:GetAttribute("SizeMultiplier") or 1
                    local mut = GetMutation(t)
                    local mutBonus = mut == "Gold" and 2.5 or mut == "Rainbow" and 3 or mut == "Electric" and 2 or mut == "Frozen" and 1.5 or 1
                    total += math.floor(base * sm * mutBonus)
                    count += 1
                end
            end
            Notify("Estimasi Lokal", count .. " buah ~" .. math.floor(total) .. "¢ (Networking offline)", Colors.Warning)
        end
    end, Colors.Gold)

    CreateActionButton(bagContent, "📋 List Semua Buah di Bag", function()
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
        if #items == 0 then
            Notify("Bag", "Tidak ada buah di backpack.", Colors.TextMuted)
        else
            -- Tampilkan max 5 per notif karena character limit
            local preview = table.concat(items, ", "):sub(1, 150)
            Notify("Bag (" .. #items .. " buah)", preview .. (#items > 5 and "..." or ""), Colors.Accent, 7)
        end
    end)
end

-- ======================== FEATURE: PETS PAGE ========================



Pages["Pets"] = function()
    -- ── SECTION 1: Pet Inventory ──────────────────────────────────
    local petCard, petContent = CreateSectionCard("🐾 Pet Inventory", 1, Colors.Frozen)

    local rarityOrd = {Super=6, Mythic=5, Legendary=4, Rare=3, Uncommon=2, Common=1}
    local sizeOrd   = {Huge=3, Big=2, Normal=1}

    -- Container yang di-rebuild setiap kali backpack berubah
    local listArea = Create("Frame", {
        Parent = petContent,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    })
    CreateListLayout(listArea, 6)

    local function RebuildInventory()
        -- Bail kalau UI sudah destroyed (halaman sudah diganti)
        if not listArea or not listArea.Parent then return end

        for _, c in ipairs(listArea:GetChildren()) do
            if not c:IsA("UIListLayout") then c:Destroy() end
        end

        -- Scan backpack
        local playerPets = {}
        for _, t in ipairs(player.Backpack:GetChildren()) do
            local petName = t:GetAttribute("Pet") or t:GetAttribute("PetSpecies")
            local petSize = t:GetAttribute("PetSize") or "Normal"
            local petType = t:GetAttribute("PetType") or ""
            if petName then
                table.insert(playerPets, {name=petName, size=petSize, petType=petType})
            end
        end

        -- Sort: rarity dulu, lalu size
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

        -- ScrollingFrame — 8 baris visible, sisanya bisa discroll
        local ROW_H   = 28
        local ROW_GAP = 6
        local scrollH = 8 * ROW_H + 7 * ROW_GAP

        local scrollWrap = Create("Frame", {
            Parent = listArea,
            Size = UDim2.new(1, 0, 0, scrollH),
            BackgroundTransparency = 1,
        })
        local petScroll = Create("ScrollingFrame", {
            Parent = scrollWrap,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Colors.Border,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
        })
        CreateListLayout(petScroll, ROW_GAP)

        for i, pet in ipairs(playerPets) do
            local rarity    = PET_RARITY_LOOKUP[pet.name] or "Unknown"
            local rarityCol = RarityColor[rarity] or Colors.TextSecondary

            -- Label kanan: "Rarity" atau "Rarity (Big/Huge)"
            local valStr = rarity
            if pet.size ~= "Normal" then
                valStr = rarity .. " (" .. pet.size .. ")"
            end

            local displayName = (pet.petType == "Rainbow" and "🌈 " or "") .. pet.name
            CreateStatRow(petScroll, i .. ". " .. displayName, valStr, rarityCol)
        end
    end

    -- Build awal
    RebuildInventory()

    -- Realtime: rebuild saat pet masuk/keluar backpack
    player.Backpack.ChildAdded:Connect(function(child)
        local isPet = child:GetAttribute("Pet") or child:GetAttribute("PetSpecies")
        if isPet then task.defer(RebuildInventory) end
    end)
    player.Backpack.ChildRemoved:Connect(function(child)
        local isPet = child:GetAttribute("Pet") or child:GetAttribute("PetSpecies")
        if isPet then task.defer(RebuildInventory) end
    end)

    -- ── SECTION 2: Pet Finder (WildPetRef) — Realtime ────────────
    local finderCard, finderContent = CreateSectionCard("🔍 Pet Finder", 2, Colors.Warning)

    CreateInfoText(finderContent, "Cara Kerja",
        "Membaca Workspace.Map.WildPetRef — folder resmi GAG yang dipakai PetTeleporterController. " ..
        "Setiap pet adalah BasePart dengan Attribute \"Rarity\" dan \"OwnerUserId\" (0 = bebas).")

    -- Live list container
    local listContainer = Create("Frame", {
        Parent = finderContent,
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
    })
    CreateListLayout(listContainer, 4)

    local RebuildPetList

    RebuildPetList = function()
        -- Bail kalau container sudah destroyed
        if not listContainer or not listContainer.Parent then return end

        -- Hapus item lama
        for _, c in ipairs(listContainer:GetChildren()) do
            if not c:IsA("UIListLayout") then c:Destroy() end
        end

        -- Scan semua rarity (tanpa filter)
        local pets = ScanWildPets("All")

        if #pets == 0 then
            CreateInfoText(listContainer, nil,
                "Tidak ada wild pet bebas ditemukan di WildPetRef.",
                Colors.TextMuted)
            return
        end

        CreateSubHeader(listContainer, #pets .. " pet tersedia")

        for i, entry in ipairs(pets) do
            if i > 15 then
                CreateInfoText(listContainer, nil, "... dan " .. (#pets - 15) .. " lainnya.", Colors.TextMuted)
                break
            end

            local part    = entry.part
            local rarity  = entry.rarity
            local dist    = entry.dist
            local col     = RarityColor[rarity] or Colors.TextSecondary
            local distStr = dist < math.huge and string.format("%.0f studs", dist) or "?"
            local petName = HumanizePetName(entry.name or "Unknown")

            -- ── Row: [●] Nama Pet   Rarity          Jarak   [TP →] ──
            -- Layout: bullet(12) + name(26-170) + rarity(180-300) + dist(310-420) + tp(right)
            local row = Create("Frame", {
                Parent = listContainer,
                Size = UDim2.new(1, 0, 0, 40),
                BackgroundColor3 = Colors.BackgroundLighter,
                BorderSizePixel = 0,
            })
            CreateCorner(row, 8)
            CreateStroke(row, col, 1)

            -- Bullet bulat berwarna rarity
            local bullet = Create("Frame", {
                Parent = row,
                Size = UDim2.new(0, 7, 0, 7),
                Position = UDim2.new(0, 12, 0.5, -3),
                BackgroundColor3 = col,
                BorderSizePixel = 0,
            })
            CreateCorner(bullet, 4)

            -- Nama pet (bold, rarity color) — lebar 130px
            Create("TextLabel", {
                Parent = row,
                Size = UDim2.new(0, 130, 1, 0),
                Position = UDim2.new(0, 26, 0, 0),
                BackgroundTransparency = 1,
                Text = petName,
                TextColor3 = col,
                TextSize = 13,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
            })

            -- Rarity label — mulai di 164 (jarak 8px setelah nama berakhir di ~156)
            Create("TextLabel", {
                Parent = row,
                Size = UDim2.new(0, 90, 1, 0),
                Position = UDim2.new(0, 164, 0, 0),
                BackgroundTransparency = 1,
                Text = rarity,
                TextColor3 = col,
                TextSize = 12,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
            })

            -- Jarak (muted) — mulai di 262 (jarak 8px setelah rarity ~90px)
            Create("TextLabel", {
                Parent = row,
                Size = UDim2.new(0, 80, 1, 0),
                Position = UDim2.new(0, 262, 0, 0),
                BackgroundTransparency = 1,
                Text = distStr,
                TextColor3 = Colors.TextMuted,
                TextSize = 12,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
            })

            -- Tombol TP
            local tpBtn = Create("TextButton", {
                Parent = row,
                Size = UDim2.new(0, 64, 0, 26),
                Position = UDim2.new(1, -72, 0.5, -13),
                BackgroundColor3 = Colors.Surface,
                Text = "TP →",
                TextColor3 = col,
                TextSize = 12,
                Font = Enum.Font.GothamBold,
                BorderSizePixel = 0,
                AutoButtonColor = false,
            })
            CreateCorner(tpBtn, 6)
            tpBtn.MouseEnter:Connect(function()
                Tween(tpBtn, {BackgroundColor3 = Colors.SurfaceLight}, 0.1)
            end)
            tpBtn.MouseLeave:Connect(function()
                Tween(tpBtn, {BackgroundColor3 = Colors.Surface}, 0.1)
            end)
            tpBtn.MouseButton1Click:Connect(function()
                if not part or not part.Parent then
                    Notify("Pet Finder", "Pet sudah menghilang!", Colors.Error)
                    RebuildPetList()
                    return
                end
                local char = player.Character
                if not char then return end

                Notify("Pet Finder",
                    "Moving → " .. petName .. " (" .. rarity .. ") — " .. string.format("%.0f", dist) .. " studs",
                    col, 3)

                -- SmartMoveToPet: multi-hop kalau ada Teleporter tool, walk biasa kalau tidak
                task.spawn(function()
                    SmartMoveToPet(part.Position, function()
                        -- Setelah sampai, beli pet via Networking.Pets.WildPetTame
                        if part and part.Parent and IsWildPetFree(part) then
                            BuyWildPet(part)
                        end
                    end)
                end)
            end)
        end
    end

    -- Realtime polling: rebuild setiap 2 detik selama halaman Pets aktif
    local finderPageAlive = true
    task.spawn(function()
        while finderPageAlive and _G._MiracleHubSession == _SESSION do
            task.wait(2)
            if not finderPageAlive or ActivePage ~= "Pets" then continue end
            pcall(RebuildPetList)
        end
    end)

    -- Stop loop saat halaman pindah
    local _finderConn
    _finderConn = RunService.Heartbeat:Connect(function()
        if ActivePage ~= "Pets" then
            finderPageAlive = false
            _finderConn:Disconnect()
        end
    end)

    -- TP ke pet terdekat
    CreateActionButton(finderContent, "⚡ TP ke Pet Terdekat", function()
        local pets = ScanWildPets("All")
        if #pets == 0 then
            Notify("Pet Finder", "Tidak ada pet tersedia saat ini.", Colors.Error)
            return
        end
        local nearest = pets[1]
        local pName = HumanizePetName(nearest.name or "Unknown")

        Notify("Pet Finder",
            "Moving -> " .. pName .. " (" .. nearest.rarity .. ") ~" .. string.format("%.0f", nearest.dist) .. " studs",
            RarityColor[nearest.rarity] or Colors.Warning, 4)

        task.spawn(function()
            SmartMoveToPet(nearest.part.Position, function()
                Notify("Pet Finder",
                    "Tiba di " .. pName .. " (" .. nearest.rarity .. ")!",
                    RarityColor[nearest.rarity] or Colors.Warning, 3)
                if nearest.part and nearest.part.Parent then
                -- Beli pet via Networking.Pets.WildPetTame
                if nearest.part and nearest.part.Parent and IsWildPetFree(nearest.part) then
                    BuyWildPet(nearest.part)
                end
                end
            end)
        end)
    end, Colors.Warning)

    -- Build awal saat page dibuka
    task.defer(RebuildPetList)

    -- ── SECTION 3: Auto Catch Wild Pets ──────────────────────────
    local wildCard, wildContent = CreateSectionCard("🎯 Auto Catch Wild", 3, Colors.Warning)

    CreateInfoText(wildContent, "Auto Catch via WildPetRef",
        "Loop otomatis: hop ke tiap pet yang sesuai pilihan → fire BuyPrompt saat tiba.\n" ..
        "Kalau tidak ada yang dipilih = tangkap semua pet. Toggle tetap ON walau pet belum spawn — notif ⏳ muncul saat menunggu.")

    -- Multi-select berdasarkan NAMA PET (bukan rarity)
    -- Daftar semua nama pet yang ada di WildPetRef (dari PET_RARITY_LOOKUP + PETS)
    local WILD_PET_NAMES = {
        "Frog", "Bunny", "Owl", "Deer", "Turtle",
        "Robin", "Bee", "Monkey", "Bear", "Unicorn",
        "Golden Dragonfly", "Raccoon", "Black Dragon", "Ice Serpent",
    }
    CreateMultiSelect(wildContent, "🐾Pilih Pet Target", WILD_PET_NAMES, "wildCatchTargets")

    -- Toggle sederhana — toggle tetap ON, loop sendiri yang handle notif waiting
    CreateToggle(wildContent, "Auto Catch Wild Pets", "autoCatchWild",
        "ON: loop jalan terus, notif ⏳ saat menunggu spawn | OFF: loop berhenti",
        function(newVal)
            if newVal then
                local sel = States.wildCatchTargets or {}
                if #sel == 0 then
                    Notify("Auto Catch", "ON — mengejar semua pet yang spawn", Colors.Success, 3)
                else
                    Notify("Auto Catch", "ON — mengejar: " .. table.concat(sel, ", "), Colors.Success, 3)
                end
            else
                Notify("Auto Catch", "OFF", Colors.TextMuted, 2)
            end
        end)
end

-- ======================== FEATURE: EGGS PAGE ========================
Pages["Eggs"] = function()
    local eggCard, eggContent = CreateSectionCard("🥚 Egg Hatching", 1, Colors.Warning)
    CreateInfoText(eggContent, "🚧 Coming Soon",
        "Fitur Egg Hatching sedang dalam pengembangan.\n" ..
        "Belum banyak yang punya egg, jadi fitur ini belum diaktifkan.\n" ..
        "Stay tuned untuk update berikutnya!")
end

-- ======================== FEATURE: PLAYER PAGE ========================
Pages["Player"] = function()
    local statsCard, statsContent = CreateSectionCard("📊 Live Player Stats", 1, Colors.Accent)
    local _, hpLbl = CreateStatRow(statsContent, "Health", "100 / 100", Colors.Success)
    local _, wsLbl = CreateStatRow(statsContent, "WalkSpeed", tostring(humanoid and humanoid.WalkSpeed or "?"), Colors.Accent)
    local _, jpLbl = CreateStatRow(statsContent, "JumpPower", tostring(humanoid and humanoid.JumpPower or "?"), Colors.Accent)
    local _, plotLbl2 = CreateStatRow(statsContent, "Plot ID", MY_PLOT_ID, Colors.Warning)
    local _, bpLbl = CreateStatRow(statsContent, "Backpack Items", #player.Backpack:GetChildren(), Colors.TextSecondary)

    local _playerTick = 0
    RunService.Heartbeat:Connect(function(dt)
        if ActivePage ~= "Player" or not humanoid then return end
        hpLbl.Text = math.floor(humanoid.Health) .. " / " .. humanoid.MaxHealth
        wsLbl.Text = string.format("%.1f", humanoid.WalkSpeed)
        jpLbl.Text = string.format("%.1f", humanoid.JumpPower)
        _playerTick += dt
        if _playerTick < 0.5 then return end
        _playerTick = 0
        plotLbl2.Text = tostring(player:GetAttribute("PlotId") or MY_PLOT_ID)
        bpLbl.Text = tostring(#player.Backpack:GetChildren())
    end)

    local moveCard, moveContent = CreateSectionCard("🏃 Movement", 2, Colors.Electric)
    CreateToggle(moveContent, "Lock WalkSpeed", "lockWalkSpeed")
    CreateSlider(moveContent, "WalkSpeed", 1, 500, "walkSpeed")
    CreateToggle(moveContent, "Lock JumpPower", "lockJumpPower")
    CreateSlider(moveContent, "JumpPower", 1, 500, "jumpPower")
    CreateToggle(moveContent, "Infinite Jump", "infiniteJump")

    local utilCard, utilContent = CreateSectionCard("✈️ Fly", 3, Colors.TextSecondary)
    CreateInfoText(utilContent, "Controls", isMobile
        and "Fly menggunakan joystick kiri Roblox untuk bergerak. Arahkan kamera ke atas/bawah untuk naik/turun."
        or  "[F] — Toggle Fly  |  [W/A/S/D] — Move  |  [Space] — Up  |  [Ctrl] — Down")
    CreateToggle(utilContent, "Fly", "fly", isMobile and "Joystick kiri untuk gerak, tilt kamera untuk naik/turun" or "Hold WASD to fly, Space=up, Ctrl=down")
    CreateSlider(utilContent, "Fly Speed", 1, 300, "flySpeed")
    CreateInfoText(utilContent, "⚠️ Warning", "Speed di atas 25 bisa keliatan mencurigakan. Default: 25.")
    CreateToggle(utilContent, "Anti AFK", "antiAfk", "Prevents auto-disconnect")

    CreateActionButton(utilContent, "Reset Character", function()
        if humanoid then humanoid.Health = 0 end
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
end

-- ======================== FEATURE: VISUALS PAGE ========================
Pages["Visuals"] = function()
    local espCard, espContent = CreateSectionCard("👁 ESP & Highlights", 1, Colors.Electric)
    CreateInfoText(espContent, "ESP system", "Renders BillboardGuis on targets. Wild Pets dari Workspace.Map.WildPetRef (rarity-based), mutations dari plant attrs, plant ages dari Age/MaxAge attrs.")
    CreateToggle(espContent, "ESP Players", "espPlayers", "Shows player names/tags above heads")
    CreateToggle(espContent, "ESP Wild Pets", "espItems", "Highlights wild pets in workspace")
    CreateToggle(espContent, "ESP Mutations", "espMutations", "Shows mutation tags on plants")
    CreateToggle(espContent, "Show Plant Age", "showPlantAge", "Shows Age/MaxAge above each plant")
    CreateToggle(espContent, "Show Fruit Weight", "showFruitWeight", "Shows weight above harvested fruits")

    -- Mutation color swatches
    CreateSubHeader(espContent, "Mutation Colors")
    local mutGrid = Create("Frame", {
        Parent = espContent,
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
    })
    Create("UIListLayout", {Parent=mutGrid, FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0,8)})
    for _, mut in ipairs({"Gold", "Electric", "Rainbow", "Frozen"}) do
        local badge = Create("TextLabel", {
            Parent = mutGrid,
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = GetMutationColor(mut),
            BackgroundTransparency = 0.6,
            Text = " " .. mut .. " ",
            TextColor3 = GetMutationColor(mut),
            TextSize = 11,
            Font = Enum.Font.GothamBold,
        })
        CreateCorner(badge, 5)
    end

    CreateActionButton(espContent, "Clear All ESP Labels", function()
        ClearESP()
        Notify("Visuals", "All ESP labels cleared.", Colors.TextMuted)
    end)

    local visCard, visContent = CreateSectionCard("🌈 Visual Settings", 2, Colors.Accent)
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
end

-- ======================== FEATURE: TELEPORT PAGE ========================
Pages["Teleport"] = function()
    local tpCard, tpContent = CreateSectionCard("📍 Quick Teleport", 1, Colors.Accent)
    CreateInfoText(tpContent, "Scanner data", "Workspace.Teleports: Seeds, Sell, Gears, Props — all BasePart objects confirmed by scanner.")

    local gameTeleports = {
        {"🌱 Seeds Shop", "Seeds", Colors.Success},
        {"💰 Sell Area", "Sell", Colors.Gold},
        {"⚙ Gear Shop", "Gears", Colors.Electric},
        {"🏡 Props Shop", "Props", Colors.Accent},
    }
    CreateSubHeader(tpContent, "Game Locations")
    for _, tp in ipairs(gameTeleports) do
        CreateActionButton(tpContent, "Teleport to " .. tp[1], function()
            local teleports = game:GetService("Workspace"):FindFirstChild("Teleports")
            if teleports then
                local part = teleports:FindFirstChild(tp[2])
                if part and player.Character then
                    player.Character:PivotTo(part.CFrame + Vector3.new(0, 5, 0))
                    Notify("Teleport", "→ " .. tp[1], tp[3])
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

    -- Teleport to specific player
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

    local savedCard, savedContent = CreateSectionCard("💾 Saved Positions", 2, Colors.TextSecondary)
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
end

-- ======================== FEATURE: UTILITY PAGE ========================
Pages["Utility"] = function()
    local worthCard, worthContent = CreateSectionCard("💎 Item Inspector", 1, Colors.Gold)
    CreateInfoText(worthContent, "Fruit attrs from scanner", "Weight, SizeMultiplier, DecayAlpha, OvertimeGrowth, Mutation | Tomato [1.38kg, x1.53 size] | Blueberry [Rainbow][Potted, x1.95 size]")

    local toolNameLbl
    do
        local currentTool = player.Character and player.Character:FindFirstChildWhichIsA("Tool")
        local r, v = CreateStatRow(worthContent, "Currently Holding", currentTool and currentTool.Name or "Nothing", Colors.TextPrimary)
        toolNameLbl = v
    end
    RunService.Heartbeat:Connect(function()
        if ActivePage == "Utility" and toolNameLbl and toolNameLbl.Parent then
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
                Notify("Inspect: " .. fn,
                    string.format("Wt:%.2fkg | Mut:%s | x%.2f size | Decay:%.4f", weight, mut, sm or 1, decay or 0),
                    GetMutationColor(mut), 6)
            else
                local seedName = ct:GetAttribute("SeedTool") or ct:GetAttribute("SeedName")
                if seedName then
                    Notify("Inspect: Seed", "Type: " .. seedName, Colors.Success)
                else
                    Notify("Inspect", ct.Name .. " — no fruit/seed attrs.", Colors.TextMuted)
                end
            end
        else
            Notify("Inspect", "Not holding anything.", Colors.TextMuted)
        end
    end, Colors.Gold)
    CreateActionButton(worthContent, "Show Best Fruit in Bag", function()
        local best, bestScore = nil, 0
        for _, t in ipairs(player.Backpack:GetChildren()) do
            local w = t:GetAttribute("Weight") or 0
            local sm = t:GetAttribute("SizeMultiplier") or 1
            if w * sm > bestScore then bestScore = w * sm best = t end
        end
        if best then
            local mut = GetMutation(best)
            local fn = best:GetAttribute("FruitName") or best.Name
            Notify("Best Fruit", fn .. " | " .. mut .. " | Score: " .. string.format("%.3f", bestScore), GetMutationColor(mut), 5)
        else
            Notify("Bag", "No fruits found in backpack.", Colors.TextMuted)
        end
    end)
    CreateActionButton(worthContent, "Count Bag Contents", function()
        local f, s, p2, g = 0, 0, 0, 0
        for _, t in ipairs(player.Backpack:GetChildren()) do
            if t:GetAttribute("HarvestedFruit") then f += 1
            elseif t:GetAttribute("SeedTool") or t:GetAttribute("SeedName") then s += 1
            elseif t:GetAttribute("Pet") then p2 += 1
            else g += 1 end
        end
        Notify("Bag Contents", "Fruits:" .. f .. " | Seeds:" .. s .. " | Pets:" .. p2 .. " | Other:" .. g .. " | Cap:" .. MAX_FRUIT_CAP, Colors.Accent)
    end)

    local toolCard, toolContent = CreateSectionCard("🔧 Quick Tools", 2)
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
        for k, v in pairs(player:GetAttributes()) do
            table.insert(attrList, k .. "=" .. tostring(v))
        end
        table.sort(attrList)
        Notify("Player Attrs", table.concat(attrList, " | "):sub(1, 120), Colors.Accent, 8)
    end)
    CreateActionButton(toolContent, "Print Full Attrs to Console", function()
        print("[Miracle Hub] Player Attributes:")
        for k, v in pairs(player:GetAttributes()) do
            print("  " .. k .. " = " .. tostring(v))
        end
        Notify("Dev", "Attributes printed to console (F9)", Colors.TextMuted)
    end)

    local giftCard, giftContent = CreateSectionCard("🎁 Gifts & Mailbox", 3, Colors.Rainbow)
    CreateInfoText(giftContent, "Mailbox from scanner", "GreyMailBox in Plot" .. MY_PLOT_ID .. ".Signs with MailboxPrompt (ProximityPromptPart). BidPrice/BidsAsked attrs detected on Tomato fruit.")
    CreateToggle(giftContent, "Auto Accept Gifts", "autoAcceptGifts", "Triggers MailboxPrompt every 10 seconds")
    CreateToggle(giftContent, "Auto Accept Bids", "autoBidAccept", "BidPrice/BidsAsked attrs detected on fruits")
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
end

-- ======================== FEATURE: MAILER PAGE ========================
Pages["Mailer"] = function()
    local mailerCard, mailerContent = CreateSectionCard("✉ Mailer System", 1, Colors.Accent)
    CreateInfoText(mailerContent, "Mailer info", "Send items via GreyMailBox on plots. BidPrice and BidsAsked attrs detected on Tomato fruit — trading system active in game.")

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
    CreateInfoText(mailerContent, "Bid system detected", "Tomato fruit has BidPrice and BidsAsked attributes. Scanner found these attrs on harvested fruits in backpack.")
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
    CreateActionButton(mailerContent, "Scan Biddable Fruits in Bag", function()
        local biddable = {}
        for _, t in ipairs(player.Backpack:GetChildren()) do
            if t:GetAttribute("BidPrice") or t:GetAttribute("BidsAsked") then
                local fn = t:GetAttribute("FruitName") or t.Name
                local bp = t:GetAttribute("BidPrice") or "?"
                table.insert(biddable, fn .. "@" .. bp)
            end
        end
        if #biddable > 0 then
            Notify("Bids", #biddable .. " biddable: " .. table.concat(biddable, ", "):sub(1, 80), Colors.Gold)
        else
            Notify("Bids", "No biddable fruits in backpack.", Colors.TextMuted)
        end
    end)
end

-- ======================== FEATURE: INFO PAGE ========================
Pages["Info"] = function()
    local infoCard, infoContent = CreateSectionCard("ℹ About Miracle Hub", 1, Colors.Success)
    CreateStatRow(infoContent, "Hub Name", "Miracle Hub", Colors.Success)
    CreateStatRow(infoContent, "Game", "Grow A Garden 2", Colors.TextSecondary)
    CreateStatRow(infoContent, "Player", player.DisplayName or player.Name, Colors.Accent)
    CreateStatRow(infoContent, "UserId", player.UserId, Colors.TextMuted)
    CreateStatRow(infoContent, "PlotId (detected)", MY_PLOT_ID, Colors.Warning)
    CreateStatRow(infoContent, "Account Age", player:GetAttribute("AccountAge") or (player.AccountAge .. "d"), Colors.TextMuted)
    CreateStatRow(infoContent, "Prime Status", (player:GetAttribute("PrimeEnabled") and "✅ Enabled" or "❌ Disabled"), Colors.Warning)
    CreateStatRow(infoContent, "Packet Remote", PacketRemote and "✅ Found" or "⚠ Not Found", PacketRemote and Colors.Success or Colors.Error)

    local scanCard, scanContent = CreateSectionCard("🔍 Scanner Data Summary", 2, Colors.Accent)
    CreateInfoText(scanContent, "Seeds in Backpack", "Bamboo ×295, Blueberry ×1, Apple ×2, Sunflower ×1")
    CreateInfoText(scanContent, "Gear in Backpack", "Common Watering Can ×338, Trowel ×141, Common Sprinkler ×2, Flashbang ×22")
    CreateInfoText(scanContent, "Pets in Backpack", "Frog ×3, Bunny ×5, Big Frog ×1, Robin ×1  (total: 10)")
    CreateInfoText(scanContent, "Mutations Found", "Gold, Electric, Rainbow, Frozen (CollectionService tags)")
    CreateInfoText(scanContent, "Plants on Plot " .. MY_PLOT_ID, "Mushroom (89/89 ✅), Bamboo ×many, Tomato [Gold] ✅, Tomato [Electric] ✅, Pineapple [Gold] ✅, Blueberry [Rainbow][Potted]")
    CreateInfoText(scanContent, "Wild Pets (WildPetSpawns)", "WildPet_Bunny ×2 (¢20,000 each), WildPet_Frog ×2 (¢10,000 each) — in Workspace.Map.WildPetSpawns")
    CreateInfoText(scanContent, "Remote System (FIXED)", "ReplicatedStorage.SharedModules.Packet.RemoteEvent | PlantSeed=9, PurchaseSeed=120, SeedShopRestock=121, PurchaseCrate=122, SellFruit=167, OpenCrate=130, OpenEgg=139, LikeGarden=221 | StockValues: ReplicatedStorage.StockValues.SeedShop.Items.<SeedName>")
    CreateInfoText(scanContent, "Teleport Parts", "Workspace.Teleports: Seeds, Sell, Gears, Props")
    CreateInfoText(scanContent, "ProximityPrompts", "HarvestPrompt (on all fruits), MailboxPrompt, CustomiseTheme, GardenSign*, PickUpPottedPlantPrompt, BuyPrompt (wild pets & shop)")

    local keybindCard, keybindContent = CreateSectionCard("⌨ Keybinds", 3, Colors.TextSecondary)
    CreateInfoText(keybindContent, nil, isMobile
        and "Mobile: Tab bar bawah untuk navigasi halaman.\nFly: Toggle dari halaman Player.\nFly controls: Joystick kiri = gerak, tilt kamera = naik/turun."
        or  "[Insert] — Toggle GUI (minimize/restore)\n[F] — Toggle Fly\n[W/A/S/D] + Fly — Move direction\n[Space] + Fly — Ascend\n[Ctrl] + Fly — Descend")
end

-- ======================== FEATURE: SERVER PAGE ========================
Pages["Server"] = function()
    local serverCard, serverContent = CreateSectionCard("🌐 Server Info", 1, Colors.Electric)
    CreateStatRow(serverContent, "Job ID", game.JobId:sub(1, 20) .. "...", Colors.TextMuted)
    CreateStatRow(serverContent, "Place ID", tostring(game.PlaceId), Colors.TextMuted)
    local playerCount = #game:GetService("Players"):GetPlayers()
    local _, pcLbl = CreateStatRow(serverContent, "Players in Server", playerCount, Colors.Success)

    local _serverTick = 0
    local playerPlotLabels = {}

    CreateSubHeader(serverContent, "Other Players")
    for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
        if p ~= player then
            local _, pPlotLbl = CreateStatRow(serverContent, p.DisplayName .. " (@" .. p.Name .. ")", "Plot " .. (p:GetAttribute("PlotId") or "?"), Colors.TextMuted)
            table.insert(playerPlotLabels, {p = p, lbl = pPlotLbl})
        end
    end

    RunService.Heartbeat:Connect(function(dt)
        if ActivePage ~= "Server" then return end
        _serverTick += dt
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

    local autoCard, autoContent = CreateSectionCard("🔄 Auto Rejoin", 2, Colors.Warning)
    CreateToggle(autoContent, "Auto Rejoin on Disconnect", "autoRejoin", "Rejoins automatically when kicked/disconnected")
    CreateDropdown(autoContent, "Rejoin Condition", {"Server Full", "FPS Drop", "Disconnected", "Manual"}, "rejoinCondition")

    -- Auto rejoin implementation
    game:GetService("Players").PlayerRemoving:Connect(function(p)
        if p == player and States.autoRejoin then
            task.wait(2)
            game:GetService("TeleportService"):Teleport(game.PlaceId, player)
        end
    end)
end

-- ======================== FEATURE: SETTINGS PAGE ========================
Pages["Settings"] = function()
    local settCard, settContent = CreateSectionCard("⚙ General Settings", 1, Colors.Accent)
    CreateToggle(settContent, "Auto Save Config", "autoSaveConfig", "Saves your config automatically")
    CreateToggle(settContent, "Minimize to Tray on Close", "minimizeToTray", "Minimizes to M shield instead of closing")
    CreateToggle(settContent, "Show Notifications", "showNotifications", "Shows popup notifications")

    CreateSubHeader(settContent, "Config")
    CreateActionButton(settContent, "Export Config to Clipboard", function()
        local cfg = {}
        for k, v in pairs(States) do
            table.insert(cfg, k .. "=" .. tostring(v))
        end
        table.sort(cfg)
        setclipboard(table.concat(cfg, "\n"))
        Notify("Settings", "Full config exported to clipboard.", Colors.Success)
    end)
    CreateActionButton(settContent, "Reset All States", function()
        States.autoPlant = false
        States.autoHarvest = false
        States.autoSell = false
        States.autoBuySeed = false
        States.autoCrate = false
        States.autoBuyCrate = false
        States.autoOpenCrate = false
        States.autoCatchWild = false
        States.autoOpenEgg = false
        States.autoAcceptGifts = false
        States.fly = false
        States.espPlayers = false
        States.espItems = false
        States.espMutations = false
        States.fullBright = false
        States.noFog = false
        States.noShadows = false
        ClearESP()
        -- Restore Failed sound saat semua state di-reset
        if _sfxMuteConn then
            _sfxMuteConn:Disconnect()
            _sfxMuteConn = nil
        end
        pcall(function()
            local ss = game:GetService("SoundService")
            local sfx = ss:FindFirstChild("SFX")
            local failedSnd = sfx and sfx:FindFirstChild("Failed")
            if failedSnd then failedSnd.Volume = 1 end
        end)
        Notify("Settings", "All automation states reset to OFF.", Colors.Warning)
    end, Colors.Error)

    local keybindCard, keybindContent = CreateSectionCard("⌨ Keybinds", 2, Colors.TextSecondary)
    CreateInfoText(keybindContent, nil, isMobile
        and "Mobile: Tab bar bawah untuk navigasi.\nFly: Toggle dari halaman Player, gerak pakai joystick Roblox."
        or  "[Insert] — Toggle GUI (minimize/restore)\n[F] — Toggle Fly\n[Space] + Fly — Ascend\n[Ctrl] + Fly — Descend")

    local debugCard, debugContent = CreateSectionCard("🛠 Debug", 3, Colors.TextMuted)
    CreateActionButton(debugContent, "Test RemoteEvent Connection", function()
        if PacketRemote then
            Notify("Debug", "✅ PacketRemote found: " .. PacketRemote:GetFullName(), Colors.Success, 6)
        else
            -- Try to re-find it
            local rs = game:GetService("ReplicatedStorage")
            local sm = rs:FindFirstChild("SharedModules")
            local pk = sm and sm:FindFirstChild("Packet")
            local re = pk and pk:FindFirstChild("RemoteEvent")
            PacketRemote = re
            Notify("Debug", re and "✅ Found on retry!" or "❌ PacketRemote NOT found. Check ReplicatedStorage.SharedModules.Packet.RemoteEvent", re and Colors.Success or Colors.Error, 6)
        end
    end)
    CreateActionButton(debugContent, "Print Packet IDs", function()
        print("[Miracle Hub] Packet IDs:")
        if PacketRemote then
            for k, v in pairs(PacketRemote:GetAttributes()) do
                print("  " .. k .. " = " .. tostring(v))
            end
        else
            print("  PacketRemote not found!")
        end
        Notify("Debug", "Packet IDs printed to console (F9)", Colors.TextMuted)
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
end

-- ======================== SIDEBAR CONNECTIONS ========================
local pageMap = {
    [BtnFarm] = "Farm", [BtnPlot] = "Plot", [BtnShop] = "Shop",
    [BtnSell] = "Sell", [BtnPets] = "Pets", [BtnEggs] = "Eggs",
    [BtnPlayer] = "Player", [BtnVisuals] = "Visuals", [BtnTeleport] = "Teleport",
    [BtnUtility] = "Utility", [BtnMailer] = "Mailer", [BtnInfo] = "Info",
    [BtnServer] = "Server", [BtnSettings] = "Settings",
}
for btn, pageName in pairs(pageMap) do
    btn.MouseButton1Click:Connect(function()
        SetActivePage(pageName)
    end)
end

-- ======================== MOBILE TAB BAR CONNECTIONS ========================
if isMobile and MobileTabBar then
    local MAIN_TABS_MAP = {"Farm", "Shop", "Sell", "Pets", "More"}
    for _, tabName in ipairs(MAIN_TABS_MAP) do
        local entry = MobileTabButtons[tabName]
        if entry and entry.btn then
            entry.btn.MouseButton1Click:Connect(function()
                if tabName == "More" then
                    -- Toggle drawer
                    MobileMoreVisible = not MobileMoreVisible
                    if MobileMoreVisible then
                        MobileMoreDrawer.Visible = true
                        MobileMoreDrawer.Size = UDim2.new(1, 0, 0, 0)
                        MobileMoreDrawer.Position = UDim2.new(0, 0, 1, -TAB_BAR_H)
                        local drawerH = math.min(300, 8 * 56 + 20)
                        Tween(MobileMoreDrawer, {
                            Size = UDim2.new(1, 0, 0, drawerH),
                            Position = UDim2.new(0, 0, 1, -(TAB_BAR_H + drawerH))
                        }, 0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
                        -- Highlight More icon
                        if entry.icon then entry.icon.TextColor3 = Colors.Success end
                        if entry.text then entry.text.TextColor3 = Colors.Success end
                        if entry.indicator then entry.indicator.Visible = true end
                    else
                        Tween(MobileMoreDrawer, {
                            Size = UDim2.new(1, 0, 0, 0),
                            Position = UDim2.new(0, 0, 1, -TAB_BAR_H)
                        }, 0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
                        task.delay(0.23, function() MobileMoreDrawer.Visible = false end)
                        if entry.icon then entry.icon.TextColor3 = Colors.TextMuted end
                        if entry.text then entry.text.TextColor3 = Colors.TextMuted end
                        if entry.indicator then entry.indicator.Visible = false end
                    end
                else
                    -- Tutup drawer kalau terbuka
                    if MobileMoreVisible then
                        MobileMoreVisible = false
                        Tween(MobileMoreDrawer, {
                            Size = UDim2.new(1, 0, 0, 0),
                            Position = UDim2.new(0, 0, 1, -TAB_BAR_H)
                        }, 0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
                        task.delay(0.23, function() MobileMoreDrawer.Visible = false end)
                        -- Reset More button
                        local moreEntry = MobileTabButtons["More"]
                        if moreEntry then
                            if moreEntry.icon then moreEntry.icon.TextColor3 = Colors.TextMuted end
                            if moreEntry.text then moreEntry.text.TextColor3 = Colors.TextMuted end
                            if moreEntry.indicator then moreEntry.indicator.Visible = false end
                        end
                    end
                    SetActivePage(tabName)
                end
            end)
        end
    end
end

-- ======================== SEARCH FUNCTIONALITY ========================
local searchAllItems = {
    -- Map: keyword -> page name
    {"auto plant", "Farm"}, {"plant seed", "Farm"}, {"auto harvest", "Farm"}, {"harvest", "Farm"},
    {"water", "Farm"}, {"sprinkler", "Farm"}, {"bamboo", "Farm"}, {"blueberry", "Farm"},
    {"auto buy", "Shop"}, {"buy seed", "Shop"}, {"crate", "Shop"}, {"restock", "Shop"}, {"shop", "Shop"},
    {"auto buy crate", "Shop"}, {"open crate", "Shop"}, {"beli crate", "Shop"}, {"crate shop", "Shop"},
    {"sell", "Sell"}, {"auto sell", "Sell"}, {"bag", "Sell"}, {"fruit", "Sell"},
    {"pet", "Pets"}, {"wild pet", "Pets"}, {"bunny", "Pets"}, {"frog", "Pets"}, {"equip pet", "Pets"},
    {"egg", "Eggs"}, {"hatch", "Eggs"}, {"open egg", "Eggs"},
    {"walk", "Player"}, {"speed", "Player"}, {"fly", "Player"}, {"jump", "Player"},
    {"esp", "Visuals"}, {"highlight", "Visuals"}, {"bright", "Visuals"}, {"fog", "Visuals"},
    {"teleport", "Teleport"}, {"tp", "Teleport"}, {"seeds shop", "Teleport"},
    {"inspect", "Utility"}, {"mailbox", "Utility"}, {"gift", "Utility"}, {"bid", "Mailer"},
    {"server", "Server"}, {"rejoin", "Server"},
    {"settings", "Settings"}, {"config", "Settings"}, {"keybind", "Settings"},
}

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local query = SearchBox.Text:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if query == "" then
        if ActivePage and Pages[ActivePage] then
            ClearContent()
            Pages[ActivePage]()
        end
        return
    end
    -- Find best matching page
    local bestPage = nil
    for _, item in ipairs(searchAllItems) do
        if item[1]:find(query, 1, true) or query:find(item[1], 1, true) then
            bestPage = item[2]
            break
        end
    end
    if bestPage and bestPage ~= ActivePage then
        SetActivePage(bestPage)
    end
end)

-- ======================== MINIMIZED M LOGO ========================
-- PC only: minimize ke icon kecil M di layar
-- Mobile: tidak dipakai (minimize = tutup GUI saja)
local MinimizedLogo = Create("Frame", {
    Parent = ScreenGui,
    Size = UDim2.new(0, 60, 0, 60),
    Position = UDim2.new(0.5, -30, 0.5, -30),
    BackgroundColor3 = Colors.Background,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 50,
})
CreateCorner(MinimizedLogo, 12)
CreateStroke(MinimizedLogo, Colors.BorderLight, 2)

local ShieldOuter = Create("Frame", {
    Parent = MinimizedLogo,
    Size = UDim2.new(0, 44, 0, 44),
    Position = UDim2.new(0.5, -22, 0.5, -22),
    BackgroundColor3 = Colors.BackgroundLight,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 51,
})
CreateCorner(ShieldOuter, 4)
local ShieldStroke = CreateStroke(ShieldOuter, Colors.Accent, 2)
ShieldStroke.Transparency = 1

local mParts = {}
local mDefs = {
    {name="ML",  Size=UDim2.new(0,3,0,20), Position=UDim2.new(0,10,0.5,-10), Rotation=0},
    {name="MR",  Size=UDim2.new(0,3,0,20), Position=UDim2.new(1,-13,0.5,-10), Rotation=0},
    {name="MDL", Size=UDim2.new(0,3,0,12), Position=UDim2.new(0.5,-1,0.5,-10), Rotation=-30},
    {name="MDR", Size=UDim2.new(0,3,0,12), Position=UDim2.new(0.5,-1,0.5,-10), Rotation=30},
    {name="MC",  Size=UDim2.new(0,3,0,10), Position=UDim2.new(0.5,-1,0.5,0), Rotation=0},
}
for _, def in ipairs(mDefs) do
    local part = Create("Frame", {
        Parent = ShieldOuter,
        Size = def.Size,
        Position = def.Position,
        BackgroundColor3 = Colors.Accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Rotation = def.Rotation,
        ZIndex = 52,
    })
    CreateCorner(part, 2)
    table.insert(mParts, part)
end

local LogoGlow = Create("Frame", {
    Parent = MinimizedLogo,
    Size = UDim2.new(1,20,1,20),
    Position = UDim2.new(0,-10,0,-10),
    BackgroundColor3 = Colors.Accent,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 49,
})
CreateCorner(LogoGlow, 20)

local LogoClick = Create("TextButton", {
    Parent = MinimizedLogo,
    Size = UDim2.new(1,0,1,0),
    BackgroundTransparency = 1,
    Text = "",
    ZIndex = 60,
})

local function AnimateLogoParts(alpha)
    Tween(ShieldStroke, {Transparency = alpha}, 0.35)
    for _, p in ipairs(mParts) do
        Tween(p, {BackgroundTransparency = alpha}, 0.35)
    end
    Tween(LogoGlow, {BackgroundTransparency = alpha + 0.65}, 0.35)
end

LogoClick.MouseEnter:Connect(function()
    for _, p in ipairs(mParts) do Tween(p, {BackgroundColor3 = Colors.TextPrimary}, 0.2) end
    Tween(ShieldStroke, {Color = Colors.TextPrimary}, 0.2)
end)
LogoClick.MouseLeave:Connect(function()
    for _, p in ipairs(mParts) do Tween(p, {BackgroundColor3 = Colors.Accent}, 0.2) end
    Tween(ShieldStroke, {Color = Colors.Accent}, 0.2)
end)

local logoDragging, logoDragStart, logoStartPos, logoHasMoved = false, nil, nil, false
LogoClick.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        logoDragging = true
        logoHasMoved = false
        logoDragStart = input.Position
        logoStartPos = MinimizedLogo.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if logoDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - logoDragStart
        if delta.Magnitude > 5 then logoHasMoved = true end
        if logoHasMoved then
            MinimizedLogo.Position = UDim2.new(logoStartPos.X.Scale, logoStartPos.X.Offset + delta.X, logoStartPos.Y.Scale, logoStartPos.Y.Offset + delta.Y)
        end
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then logoDragging = false end
end)

-- ======================== WINDOW DRAG ========================
-- PC: drag via TopBar mouse
-- Mobile: fullscreen, tidak perlu drag (tapi tetap support kalau ada)
local dragging, dragStart, startPos = false, nil, nil
if not isMobile then
    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
end

-- ======================== MINIMIZE / RESTORE ========================
local minimized = false

local function DoMinimize()
    if isMobile then
        -- Mobile: tutup sepenuhnya dengan fade (tidak ada "minimize icon" kecil)
        minimized = true
        Tween(MainFrame, {BackgroundTransparency = 1}, 0.3)
        task.delay(0.3, function()
            MainFrame.Visible = false
            MainFrame.BackgroundTransparency = 0
            minimized = false
        end)
        return
    end
    minimized = true
    local ap = MainFrame.AbsolutePosition
    local as = MainFrame.AbsoluteSize
    local cx = ap.X + as.X / 2
    local cy = ap.Y + as.Y / 2

    MinimizedLogo.Position = UDim2.new(0, cx - 30, 0, cy - 30)

    Tween(MainFrame, {Size = UDim2.new(0,60,0,60), Position = UDim2.new(0, cx-30, 0, cy-30)}, 0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
    task.delay(0.25, function()
        Sidebar.Visible = false
        ContentArea.Visible = false
        TopBar.Visible = false
    end)
    task.delay(0.4, function()
        MainFrame.BackgroundTransparency = 1
        MinimizedLogo.Visible = true
        Tween(MinimizedLogo, {BackgroundTransparency = 0}, 0.3)
        AnimateLogoParts(0)
    end)
end

local function DoRestore()
    if isMobile then
        minimized = false
        MainFrame.Visible = true
        return
    end
    minimized = false
    AnimateLogoParts(1)
    Tween(MinimizedLogo, {BackgroundTransparency = 1}, 0.25)
    task.delay(0.2, function()
        MinimizedLogo.Visible = false
        TopBar.Visible = true
        Sidebar.Visible = true
        ContentArea.Visible = true
        MainFrame.BackgroundTransparency = 0
        Tween(MainFrame, {Size = originalSize, Position = UDim2.new(0.5,-450,0.5,-300)}, 0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    end)
end

MinimizeButton.MouseButton1Click:Connect(function()
    if minimized then DoRestore() else DoMinimize() end
end)
LogoClick.MouseButton1Click:Connect(function()
    if minimized and not logoHasMoved then DoRestore() end
end)

-- ======================== CONFIRM CLOSE MODAL ========================
local ConfirmModal = Create("Frame", {
    Parent = ScreenGui,
    Size = UDim2.new(1,0,1,0),
    BackgroundColor3 = Color3.fromRGB(0,0,0),
    BackgroundTransparency = 1,
    Visible = false,
    ZIndex = 1000,
})
local ConfirmBox = Create("Frame", {
    Parent = ConfirmModal,
    Size = UDim2.new(0, 380, 0, 200),
    Position = UDim2.new(0.5,-190,0.5,-100),
    BackgroundColor3 = Colors.BackgroundLight,
    BorderSizePixel = 0,
    ZIndex = 1001,
})
CreateCorner(ConfirmBox, 16)
CreateStroke(ConfirmBox, Colors.Border, 1)
local confContent = Create("Frame", {Parent=ConfirmBox, Size=UDim2.new(1,-48,1,-48), Position=UDim2.new(0,24,0,24), BackgroundTransparency=1, ZIndex=1002})
Create("UIListLayout", {Parent=confContent, Padding=UDim.new(0,10), HorizontalAlignment=Enum.HorizontalAlignment.Center, VerticalAlignment=Enum.VerticalAlignment.Center, SortOrder=Enum.SortOrder.LayoutOrder})
Create("TextLabel", {Parent=confContent, Size=UDim2.new(1,0,0,28), BackgroundTransparency=1, Text="Close Miracle Hub?", TextColor3=Colors.TextPrimary, TextSize=20, Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Center, LayoutOrder=1, ZIndex=1002})
Create("TextLabel", {Parent=confContent, Size=UDim2.new(1,0,0,36), BackgroundTransparency=1, Text="All automation loops will stop. Re-inject to use again.", TextColor3=Colors.TextSecondary, TextSize=13, Font=Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Center, TextWrapped=true, LayoutOrder=2, ZIndex=1002})
local btnRow = Create("Frame", {Parent=confContent, Size=UDim2.new(1,0,0,38), BackgroundTransparency=1, LayoutOrder=3, ZIndex=1002})
Create("UIListLayout", {Parent=btnRow, Padding=UDim.new(0,12), FillDirection=Enum.FillDirection.Horizontal, HorizontalAlignment=Enum.HorizontalAlignment.Center, VerticalAlignment=Enum.VerticalAlignment.Center})
local ConfYes = Create("TextButton", {Parent=btnRow, Size=UDim2.new(0,110,0,36), BackgroundColor3=Color3.fromRGB(180,80,80), Text="Yes, Close", TextColor3=Colors.TextPrimary, TextSize=13, Font=Enum.Font.GothamBold, BorderSizePixel=0, ZIndex=1002, AutoButtonColor=false})
CreateCorner(ConfYes, 8)
local ConfNo = Create("TextButton", {Parent=btnRow, Size=UDim2.new(0,110,0,36), BackgroundColor3=Colors.Surface, Text="Cancel", TextColor3=Colors.TextPrimary, TextSize=13, Font=Enum.Font.GothamBold, BorderSizePixel=0, ZIndex=1002, AutoButtonColor=false})
CreateCorner(ConfNo, 8)

CloseButton.MouseButton1Click:Connect(function()
    if States.minimizeToTray then
        DoMinimize()
        return
    end
    ConfirmModal.Visible = true
    Tween(ConfirmModal, {BackgroundTransparency = 0.55}, 0.25)
    Tween(ConfirmBox, {Size=UDim2.new(0,380,0,200)}, 0.3, Enum.EasingStyle.Back)
end)
ConfNo.MouseButton1Click:Connect(function()
    Tween(ConfirmModal, {BackgroundTransparency = 1}, 0.25)
    task.wait(0.3)
    ConfirmModal.Visible = false
end)
ConfYes.MouseButton1Click:Connect(function()
    Tween(ConfirmModal, {BackgroundTransparency = 1}, 0.2)
    task.wait(0.25)
    if isMobile then
        Tween(MainFrame, {BackgroundTransparency = 1}, 0.3)
    else
        Tween(MainFrame, {Size=UDim2.new(0,900,0,0)}, 0.3)
    end
    task.wait(0.3)
    ScreenGui:Destroy()
end)

-- ======================== KEYBINDS ========================
-- PC only: Insert to minimize, F to fly
-- Mobile: tidak ada keyboard, skip
if not isMobile then
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        -- Insert: toggle minimize
        if input.KeyCode == Enum.KeyCode.Insert then
            if minimized then DoRestore() else DoMinimize() end
        end
        -- F: toggle fly
        if input.KeyCode == Enum.KeyCode.F then
            States.fly = not States.fly
            Notify("Player", "Fly " .. (States.fly and "ON" or "OFF"), States.fly and Colors.Success or Colors.TextMuted)
        end
    end)
end

-- ======================== LOADING SCREEN ========================
local loadSteps = {
    {text = "Initializing core systems...", d = 0.3},
    {text = "Reading player attributes...", d = 0.3},
    {text = "Detecting PlotId = " .. MY_PLOT_ID .. "...", d = 0.3},
    {text = "Scanning backpack (Seeds, Pets, Gear)...", d = 0.4},
    {text = "Mapping Gardens.Plot" .. MY_PLOT_ID .. ".Plants...", d = 0.3},
    {text = "Locating Packet RemoteEvent...", d = 0.3},
    {text = "Packet IDs: PlantSeed=9, OpenEgg=139...", d = 0.3},
    {text = "Found mutations: Gold, Electric, Rainbow, Frozen...", d = 0.3},
    {text = "Mapping WildPetSpawns (BuyPrompt system)...", d = 0.3},
    {text = "Mapping teleport parts (Seeds, Sell, Gears, Props)...", d = 0.25},
    {text = "Building Farm & Harvest features...", d = 0.25},
    {text = "Building Shop & Auto-Buy (PurchaseSeed=120)...", d = 0.25},
    {text = "Building Sell & Bag Inspector...", d = 0.25},
    {text = "Building Pet Manager & Wild Pet Catcher...", d = 0.25},
    {text = "Building Visuals ESP system...", d = 0.25},
    {text = "Building Utility & Mailbox...", d = 0.2},
    {text = "Connecting search & keybinds...", d = 0.2},
    {text = "Finalizing Miracle Hub...", d = 0.3},
}

local totalDur = 0
for _, s in ipairs(loadSteps) do totalDur += s.d end

local elapsed = 0
local conn
conn = RunService.Heartbeat:Connect(function(dt)
    elapsed = elapsed + dt
    local pct = math.clamp(elapsed / totalDur, 0, 1)
    Tween(LoadingBarFill, {Size = UDim2.new(pct, 0, 1, 0)}, 0.05)
    LoadingPercent.Text = math.floor(pct * 100) .. "%"

    local acc = 0
    for _, s in ipairs(loadSteps) do
        acc += s.d
        if elapsed <= acc then
            LoadingStatus.Text = s.text
            break
        end
    end

    if pct >= 1 then
        conn:Disconnect()
        LoadingStatus.Text = "Ready!"
        task.wait(0.4)

        Tween(LoadingContainer, {BackgroundTransparency = 1}, 0.4)
        for _, c in ipairs(LoadingContainer:GetDescendants()) do
            if c:IsA("TextLabel") then Tween(c, {TextTransparency = 1}, 0.4)
            elseif c:IsA("Frame") then Tween(c, {BackgroundTransparency = 1}, 0.4) end
        end
        task.wait(0.5)
        LoadingScreen:Destroy()

        MainFrame.Visible = true
        if isMobile then
            MainFrame.Size = originalSize
            MainFrame.Position = originalPos
        else
            MainFrame.Size = UDim2.new(0, 900, 0, 0)
            Tween(MainFrame, {Size = originalSize}, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        end

        task.wait(0.3)
        SetActivePage("Farm")

        task.wait(0.8)
        local remoteStatus = PacketRemote and "Remote" or "Remote ⚠ (check console)"
        local controlsHint = isMobile and "Tab bar bawah untuk navigasi" or "[Insert] toggle | [F] fly"
        Notify("Miracle Hub", "Loaded! Plot " .. MY_PLOT_ID .. " | " .. remoteStatus .. " | " .. controlsHint, Colors.Success, 6)
    end
end)

print("[Miracle Hub] Full build loaded — Player: " .. player.Name)
print("[Miracle Hub] Keybinds: [Insert] = toggle GUI | [F] = toggle Fly")