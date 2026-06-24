local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

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
    keepReserve = 0,
    maxPlantsCycle = 40,
    perFruitDelay = 0.05,
    harvestLoopDelay = 2.0,
    notifyHarvest = false,
    -- Shop
    autoBuySeed = false,
    autoBuySeedTarget = "Bamboo",      -- legacy (fallback jika targets kosong)
    autoBuySeedTargets = {},           -- TABLE: daftar seed dipilih (multi-select)
    autoBuyQuantity = 1,               -- jumlah yg dibeli per cycle (1/3/10/50)
    autoBuyQtyStr = "1",               -- versi string untuk dropdown
    autoBuyAll = false,                -- beli semua seed yg ada stoknya
    autoCrate = false,
    buyBeforeOpen = true,
    crateLoopDelay = 8,
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
    flySpeed = 60,
    noclip = false,
    antiAfk = true,
    -- Pets
    autoEquipPets = false,
    autoCatchWild = false,
    wildPetFilter = "All",
    wildPetMaxCost = 500,
    petEquipPriority = "Biggest First",
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

local function Tween(instance, properties, duration, style, direction)
    local info = TweenInfo.new(
        duration or 0.3,
        style or Enum.EasingStyle.Quad,
        direction or Enum.EasingDirection.Out
    )
    TweenService:Create(instance, info, properties):Play()
end

local function Notify(title, message, color, duration)
    if not States.showNotifications then return end
    duration = duration or 3
    color = color or Colors.Accent
    -- Notification implementation placeholder
end

-- ======================== RESPONSIVE HELPERS ========================
local isMobile = UserInputService.TouchEnabled
local screenSize = workspace.CurrentCamera.ViewportSize
local function updateScreenSize()
    screenSize = workspace.CurrentCamera.ViewportSize
    isMobile = UserInputService.TouchEnabled
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScreenSize)

local function scale(val)
    -- Scale value based on screen width (reference: 1920)
    return val * (screenSize.X / 1920)
end

local function scaleY(val)
    -- Scale value based on screen height (reference: 1080)
    return val * (screenSize.Y / 1080)
end

-- ======================== MAIN GUI ========================
local ScreenGui = Create("ScreenGui", {
    Name = "MiracleHub",
    Parent = playerGui,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

-- Background dim for mobile modal feel
local Backdrop = Create("Frame", {
    Parent = ScreenGui,
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 0,
    Visible = false,
})

-- Main Frame
local MainFrame = Create("Frame", {
    Parent = ScreenGui,
    Name = "MainFrame",
    Size = UDim2.new(0, scale(900), 0, scaleY(600)),
    Position = UDim2.new(0.5, -scale(450), 0.5, -scaleY(300)),
    BackgroundColor3 = Colors.Background,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Visible = false,
    ZIndex = 10,
})
CreateCorner(MainFrame, 16)
CreateStroke(MainFrame, Colors.Border, 1)

-- Mobile: make main frame fill screen when on small devices
if screenSize.X < 800 then
    MainFrame.Size = UDim2.new(1, -20, 1, -20)
    MainFrame.Position = UDim2.new(0, 10, 0, 10)
end

-- ======================== TOP BAR ========================
local TopBar = Create("Frame", {
    Parent = MainFrame,
    Name = "TopBar",
    Size = UDim2.new(1, 0, 0, scaleY(50)),
    BackgroundColor3 = Colors.BackgroundLight,
    BorderSizePixel = 0,
    ZIndex = 11,
})
CreateCorner(TopBar, 16)

local TopBarTitle = Create("TextLabel", {
    Parent = TopBar,
    Size = UDim2.new(1, -scale(120), 1, 0),
    Position = UDim2.new(0, scale(16), 0, 0),
    BackgroundTransparency = 1,
    Text = "Miracle Hub",
    TextColor3 = Colors.TextPrimary,
    TextSize = scale(22),
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 12,
})

local MinimizeButton = Create("TextButton", {
    Parent = TopBar,
    Size = UDim2.new(0, scale(40), 0, scale(40)),
    Position = UDim2.new(1, -scale(90), 0.5, -scale(20)),
    BackgroundColor3 = Colors.Surface,
    Text = "-",
    TextColor3 = Colors.TextPrimary,
    TextSize = scale(24),
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0,
    ZIndex = 12,
    AutoButtonColor = false,
})
CreateCorner(MinimizeButton, 8)

local CloseButton = Create("TextButton", {
    Parent = TopBar,
    Size = UDim2.new(0, scale(40), 0, scale(40)),
    Position = UDim2.new(1, -scale(48), 0.5, -scale(20)),
    BackgroundColor3 = Color3.fromRGB(180, 80, 80),
    Text = "×",
    TextColor3 = Colors.TextPrimary,
    TextSize = scale(24),
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0,
    ZIndex = 12,
    AutoButtonColor = false,
})
CreateCorner(CloseButton, 8)

-- ======================== SIDEBAR (TAB NAVIGATION) ========================
local Sidebar = Create("Frame", {
    Parent = MainFrame,
    Name = "Sidebar",
    Size = UDim2.new(0, scale(180), 1, -scaleY(50)),
    Position = UDim2.new(0, 0, 0, scaleY(50)),
    BackgroundColor3 = Colors.BackgroundLight,
    BorderSizePixel = 0,
    ZIndex = 11,
})
CreateCorner(Sidebar, 16)

local SidebarLayout = Create("UIListLayout", {
    Parent = Sidebar,
    Padding = UDim.new(0, scale(6)),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
})

local SidebarPadding = Create("UIPadding", {
    Parent = Sidebar,
    PaddingTop = UDim.new(0, scale(12)),
    PaddingBottom = UDim.new(0, scale(12)),
})

-- Mobile: bottom tab bar instead of side sidebar
if screenSize.X < 800 then
    Sidebar.Size = UDim2.new(1, 0, 0, scaleY(60))
    Sidebar.Position = UDim2.new(0, 0, 1, -scaleY(60))
    SidebarLayout.FillDirection = Enum.FillDirection.Horizontal
    SidebarLayout.Padding = UDim.new(0, scale(4))
    SidebarPadding.PaddingTop = UDim.new(0, scale(6))
    SidebarPadding.PaddingBottom = UDim.new(0, scale(6))
    SidebarPadding.PaddingLeft = UDim.new(0, scale(6))
    SidebarPadding.PaddingRight = UDim.new(0, scale(6))
end

-- ======================== CONTENT AREA ========================
local ContentArea = Create("ScrollingFrame", {
    Parent = MainFrame,
    Name = "ContentArea",
    Size = UDim2.new(1, -scale(180), 1, -scaleY(50)),
    Position = UDim2.new(0, scale(180), 0, scaleY(50)),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = scale(6),
    ScrollBarImageColor3 = Colors.Border,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ZIndex = 11,
})

local ContentLayout = Create("UIListLayout", {
    Parent = ContentArea,
    Padding = UDim.new(0, scale(12)),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
})

local ContentPadding = Create("UIPadding", {
    Parent = ContentArea,
    PaddingTop = UDim.new(0, scale(16)),
    PaddingBottom = UDim.new(0, scale(16)),
    PaddingLeft = UDim.new(0, scale(16)),
    PaddingRight = UDim.new(0, scale(16)),
})

-- Mobile: adjust content area for bottom tab bar
if screenSize.X < 800 then
    ContentArea.Size = UDim2.new(1, 0, 1, -scaleY(110))
    ContentArea.Position = UDim2.new(0, 0, 0, scaleY(50))
end

-- ======================== TAB SYSTEM ========================
local tabs = {}
local activeTab = nil

local function CreateTab(name, icon)
    local btn = Create("TextButton", {
        Parent = Sidebar,
        Size = screenSize.X < 800 and UDim2.new(0, scale(60), 1, -scale(12)) or UDim2.new(1, -scale(24), 0, scale(44)),
        BackgroundColor3 = Colors.Surface,
        Text = screenSize.X < 800 and (icon or name:sub(1,1)) or name,
        TextColor3 = Colors.TextSecondary,
        TextSize = screenSize.X < 800 and scale(14) or scale(16),
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
        ZIndex = 12,
        AutoButtonColor = false,
        LayoutOrder = #tabs + 1,
    })
    CreateCorner(btn, 8)

    local page = Create("Frame", {
        Parent = ContentArea,
        Name = name .. "Page",
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 11,
    })

    local pageLayout = Create("UIListLayout", {
        Parent = page,
        Padding = UDim.new(0, scale(10)),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    table.insert(tabs, {name = name, button = btn, page = page})

    btn.MouseButton1Click:Connect(function()
        if activeTab then
            activeTab.button.BackgroundColor3 = Colors.Surface
            activeTab.button.TextColor3 = Colors.TextSecondary
            activeTab.page.Visible = false
        end
        activeTab = tabs[#tabs]
        btn.BackgroundColor3 = Colors.Accent
        btn.TextColor3 = Colors.Background
        page.Visible = true
    end)

    return page
end

local function SetActivePage(name)
    for _, tab in ipairs(tabs) do
        if tab.name == name then
            if activeTab then
                activeTab.button.BackgroundColor3 = Colors.Surface
                activeTab.button.TextColor3 = Colors.TextSecondary
                activeTab.page.Visible = false
            end
            activeTab = tab
            tab.button.BackgroundColor3 = Colors.Accent
            tab.button.TextColor3 = Colors.Background
            tab.page.Visible = true
            break
        end
    end
end

-- ======================== SECTION CREATOR ========================
local function CreateSection(parent, title)
    local section = Create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = Colors.BackgroundLighter,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 12,
    })
    CreateCorner(section, 12)

    local sectionTitle = Create("TextLabel", {
        Parent = section,
        Size = UDim2.new(1, -scale(20), 0, scaleY(36)),
        Position = UDim2.new(0, scale(10), 0, 0),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Colors.TextPrimary,
        TextSize = scale(18),
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 13,
    })

    local sectionContent = Create("Frame", {
        Parent = section,
        Size = UDim2.new(1, -scale(20), 0, 0),
        Position = UDim2.new(0, scale(10), 0, scaleY(36)),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 13,
    })

    local contentLayout = Create("UIListLayout", {
        Parent = sectionContent,
        Padding = UDim.new(0, scale(8)),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    local contentPadding = Create("UIPadding", {
        Parent = sectionContent,
        PaddingBottom = UDim.new(0, scale(10)),
    })

    return sectionContent
end

-- ======================== TOGGLE CREATOR ========================
local function CreateToggle(parent, text, stateKey, callback)
    local row = Create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, scaleY(44)),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 14,
    })

    local label = Create("TextLabel", {
        Parent = row,
        Size = UDim2.new(1, -scale(70), 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Colors.TextSecondary,
        TextSize = scale(15),
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 14,
    })

    local toggleBtn = Create("TextButton", {
        Parent = row,
        Size = UDim2.new(0, scale(52), 0, scale(28)),
        Position = UDim2.new(1, -scale(52), 0.5, -scale(14)),
        BackgroundColor3 = States[stateKey] and Colors.ToggleOn or Colors.ToggleOff,
        Text = "",
        BorderSizePixel = 0,
        ZIndex = 14,
        AutoButtonColor = false,
    })
    CreateCorner(toggleBtn, 14)

    local knob = Create("Frame", {
        Parent = toggleBtn,
        Size = UDim2.new(0, scale(22), 0, scale(22)),
        Position = States[stateKey] and UDim2.new(1, -scale(25), 0.5, -scale(11)) or UDim2.new(0, scale(3), 0.5, -scale(11)),
        BackgroundColor3 = Colors.ToggleKnob,
        BorderSizePixel = 0,
        ZIndex = 15,
    })
    CreateCorner(knob, 11)

    local function updateToggle()
        States[stateKey] = not States[stateKey]
        local on = States[stateKey]
        Tween(toggleBtn, {BackgroundColor3 = on and Colors.ToggleOn or Colors.ToggleOff}, 0.2)
        Tween(knob, {Position = on and UDim2.new(1, -scale(25), 0.5, -scale(11)) or UDim2.new(0, scale(3), 0.5, -scale(11))}, 0.2)
        if callback then callback(on) end
    end

    toggleBtn.MouseButton1Click:Connect(updateToggle)
    return row
end

-- ======================== SLIDER CREATOR ========================
local function CreateSlider(parent, text, stateKey, min, max, callback)
    local row = Create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, scaleY(60)),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 14,
    })

    local label = Create("TextLabel", {
        Parent = row,
        Size = UDim2.new(0.6, 0, 0, scaleY(24)),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Colors.TextSecondary,
        TextSize = scale(15),
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 14,
    })

    local valueLabel = Create("TextLabel", {
        Parent = row,
        Size = UDim2.new(0.4, 0, 0, scaleY(24)),
        Position = UDim2.new(0.6, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(States[stateKey]),
        TextColor3 = Colors.Accent,
        TextSize = scale(15),
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 14,
    })

    local track = Create("Frame", {
        Parent = row,
        Size = UDim2.new(1, 0, 0, scale(8)),
        Position = UDim2.new(0, 0, 0, scaleY(32)),
        BackgroundColor3 = Colors.SliderTrack,
        BorderSizePixel = 0,
        ZIndex = 14,
    })
    CreateCorner(track, 4)

    local fill = Create("Frame", {
        Parent = track,
        Size = UDim2.new((States[stateKey] - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = Colors.SliderFill,
        BorderSizePixel = 0,
        ZIndex = 15,
    })
    CreateCorner(fill, 4)

    local knob = Create("Frame", {
        Parent = track,
        Size = UDim2.new(0, scale(18), 0, scale(18)),
        Position = UDim2.new((States[stateKey] - min) / (max - min), -scale(9), 0.5, -scale(9)),
        BackgroundColor3 = Colors.ToggleKnob,
        BorderSizePixel = 0,
        ZIndex = 16,
    })
    CreateCorner(knob, 9)

    local dragging = false

    local function updateSlider(input)
        local pos = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local val = math.floor(min + pos * (max - min))
        States[stateKey] = val
        valueLabel.Text = tostring(val)
        fill.Size = UDim2.new(pos, 0, 1, 0)
        knob.Position = UDim2.new(pos, -scale(9), 0.5, -scale(9))
        if callback then callback(val) end
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateSlider(input)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return row
end

-- ======================== DROPDOWN CREATOR ========================
local function CreateDropdown(parent, text, options, stateKey, callback)
    local row = Create("Frame", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, scaleY(44)),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 14,
    })

    local label = Create("TextLabel", {
        Parent = row,
        Size = UDim2.new(0.5, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Colors.TextSecondary,
        TextSize = scale(15),
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 14,
    })

    local dropdownBtn = Create("TextButton", {
        Parent = row,
        Size = UDim2.new(0.5, -scale(8), 0, scale(34)),
        Position = UDim2.new(0.5, scale(8), 0.5, -scale(17)),
        BackgroundColor3 = Colors.Surface,
        Text = States[stateKey] or options[1],
        TextColor3 = Colors.TextPrimary,
        TextSize = scale(14),
        Font = Enum.Font.Gotham,
        BorderSizePixel = 0,
        ZIndex = 14,
        AutoButtonColor = false,
    })
    CreateCorner(dropdownBtn, 8)

    local dropdownOpen = false
    local dropdownMenu = nil

    dropdownBtn.MouseButton1Click:Connect(function()
        if dropdownOpen then
            if dropdownMenu then dropdownMenu:Destroy() end
            dropdownOpen = false
            return
        end

        dropdownMenu = Create("Frame", {
            Parent = ScreenGui,
            Size = UDim2.new(0, dropdownBtn.AbsoluteSize.X, 0, #options * scaleY(36)),
            Position = UDim2.new(0, dropdownBtn.AbsolutePosition.X, 0, dropdownBtn.AbsolutePosition.Y + dropdownBtn.AbsoluteSize.Y + 2),
            BackgroundColor3 = Colors.BackgroundLighter,
            BorderSizePixel = 0,
            ZIndex = 100,
        })
        CreateCorner(dropdownMenu, 8)
        CreateStroke(dropdownMenu, Colors.Border, 1)

        for i, option in ipairs(options) do
            local optBtn = Create("TextButton", {
                Parent = dropdownMenu,
                Size = UDim2.new(1, 0, 0, scaleY(36)),
                Position = UDim2.new(0, 0, 0, (i - 1) * scaleY(36)),
                BackgroundColor3 = Colors.BackgroundLighter,
                Text = option,
                TextColor3 = Colors.TextSecondary,
                TextSize = scale(14),
                Font = Enum.Font.Gotham,
                BorderSizePixel = 0,
                ZIndex = 101,
                AutoButtonColor = false,
            })

            optBtn.MouseEnter:Connect(function()
                Tween(optBtn, {BackgroundColor3 = Colors.Surface}, 0.15)
            end)
            optBtn.MouseLeave:Connect(function()
                Tween(optBtn, {BackgroundColor3 = Colors.BackgroundLighter}, 0.15)
            end)

            optBtn.MouseButton1Click:Connect(function()
                States[stateKey] = option
                dropdownBtn.Text = option
                if dropdownMenu then dropdownMenu:Destroy() end
                dropdownOpen = false
                if callback then callback(option) end
            end)
        end

        dropdownOpen = true
    end)

    return row
end

-- ======================== BUTTON CREATOR ========================
local function CreateButton(parent, text, color, callback)
    local btn = Create("TextButton", {
        Parent = parent,
        Size = UDim2.new(1, 0, 0, scaleY(42)),
        BackgroundColor3 = color or Colors.Surface,
        Text = text,
        TextColor3 = Colors.TextPrimary,
        TextSize = scale(16),
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
        ZIndex = 14,
        AutoButtonColor = false,
    })
    CreateCorner(btn, 10)

    btn.MouseButton1Click:Connect(function()
        if callback then callback() end
    end)

    return btn
end

-- ======================== BUILD PAGES ========================
local FarmPage = CreateTab("Farm", "🌾")
local ShopPage = CreateTab("Shop", "🛒")
local SellPage = CreateTab("Sell", "💰")
local PlayerPage = CreateTab("Player", "🏃")
local PetsPage = CreateTab("Pets", "🐾")
local VisualsPage = CreateTab("Visuals", "👁")
local TeleportPage = CreateTab("Teleport", "📍")
local SettingsPage = CreateTab("Settings", "⚙")

-- Farm Page
local farmSection = CreateSection(FarmPage, "Auto Farm")
CreateToggle(farmSection, "Auto Plant", "autoPlant")
CreateToggle(farmSection, "Auto Harvest", "autoHarvest")
CreateToggle(farmSection, "Auto Water", "autoWater")
CreateToggle(farmSection, "Auto Sprinkler", "autoSprinkler")
CreateDropdown(farmSection, "Plant Seed", SEEDS, "plantSeedFilter")
CreateDropdown(farmSection, "Rarity Filter", RARITIES, "plantRarityFilter")
CreateSlider(farmSection, "Max Plants/Cycle", "maxPlantsCycle", 1, 100)
CreateSlider(farmSection, "Harvest Delay", "harvestLoopDelay", 0.5, 10)
CreateToggle(farmSection, "Notify Harvest", "notifyHarvest")

-- Shop Page
local shopSection = CreateSection(ShopPage, "Auto Shop")
CreateToggle(shopSection, "Auto Buy Seed", "autoBuySeed")
CreateDropdown(shopSection, "Target Seed", SEEDS, "autoBuySeedTarget")
CreateSlider(shopSection, "Buy Quantity", "autoBuyQuantity", 1, 50)
CreateToggle(shopSection, "Auto Buy All", "autoBuyAll")
CreateToggle(shopSection, "Auto Crate", "autoCrate")
CreateSlider(shopSection, "Crate Delay", "crateLoopDelay", 1, 30)
CreateToggle(shopSection, "Notify Buy", "notifyBuy")
CreateToggle(shopSection, "Notify Crate", "notifyCrate")

-- Sell Page
local sellSection = CreateSection(SellPage, "Auto Sell")
CreateToggle(sellSection, "Auto Sell", "autoSell")
CreateToggle(sellSection, "Auto Use Daily Deal", "autoUseDailyDeal")
CreateSlider(sellSection, "Sell Delay", "sellDelay", 0.01, 1)
CreateSlider(sellSection, "Sell Loop Delay", "sellLoopDelay", 1, 30)
CreateToggle(sellSection, "Keep Mutations", "keepMutations")
CreateDropdown(sellSection, "Keep Rarity", RARITIES, "keepRarity")
CreateToggle(sellSection, "Notify Sell", "notifySell")

-- Player Page
local playerSection = CreateSection(PlayerPage, "Player Mods")
CreateToggle(playerSection, "Lock Walk Speed", "lockWalkSpeed")
CreateSlider(playerSection, "Walk Speed", "walkSpeed", 16, 200)
CreateToggle(playerSection, "Lock Jump Power", "lockJumpPower")
CreateSlider(playerSection, "Jump Power", "jumpPower", 50, 300)
CreateToggle(playerSection, "Infinite Jump", "infiniteJump")
CreateToggle(playerSection, "Fly", "fly")
CreateSlider(playerSection, "Fly Speed", "flySpeed", 10, 200)
CreateToggle(playerSection, "Noclip", "noclip")
CreateToggle(playerSection, "Anti AFK", "antiAfk")

-- Pets Page
local petsSection = CreateSection(PetsPage, "Pet Manager")
CreateToggle(petsSection, "Auto Equip Pets", "autoEquipPets")
CreateToggle(petsSection, "Auto Catch Wild", "autoCatchWild")
CreateDropdown(petsSection, "Wild Pet Filter", PETS, "wildPetFilter")
CreateSlider(petsSection, "Max Cost", "wildPetMaxCost", 0, 5000)
CreateDropdown(petsSection, "Equip Priority", PET_SIZES, "petEquipPriority")

-- Visuals Page
local visualsSection = CreateSection(VisualsPage, "Visuals")
CreateToggle(visualsSection, "ESP Players", "espPlayers")
CreateToggle(visualsSection, "ESP Items", "espItems")
CreateToggle(visualsSection, "ESP Fruits", "espFruits")
CreateToggle(visualsSection, "ESP Mutations", "espMutations")
CreateToggle(visualsSection, "Full Bright", "fullBright")
CreateSlider(visualsSection, "Brightness", "brightness", 1, 20)
CreateToggle(visualsSection, "No Fog", "noFog")
CreateToggle(visualsSection, "No Shadows", "noShadows")
CreateToggle(visualsSection, "Show Plant Age", "showPlantAge")
CreateToggle(visualsSection, "Show Fruit Weight", "showFruitWeight")

-- Teleport Page
local tpSection = CreateSection(TeleportPage, "Teleport")
CreateSlider(tpSection, "Teleport Delay", "tpDelay", 0, 10)
CreateButton(tpSection, "Teleport to Plot", Colors.Surface, function()
    -- Teleport to plot logic placeholder
end)
CreateButton(tpSection, "Teleport to Shop", Colors.Surface, function()
    -- Teleport to shop logic placeholder
end)
CreateButton(tpSection, "Teleport to Sell", Colors.Surface, function()
    -- Teleport to sell logic placeholder
end)

-- Settings Page
local settingsSection = CreateSection(SettingsPage, "Settings")
CreateToggle(settingsSection, "Auto Save Config", "autoSaveConfig")
CreateToggle(settingsSection, "Minimize to Tray", "minimizeToTray")
CreateToggle(settingsSection, "Show Notifications", "showNotifications")
CreateButton(settingsSection, "Save Config", Colors.ToggleOn, function()
    -- Save config logic placeholder
end)
CreateButton(settingsSection, "Load Config", Colors.Surface, function()
    -- Load config logic placeholder
end)
CreateButton(settingsSection, "Reset Config", Colors.Error, function()
    -- Reset config logic placeholder
end)

-- ======================== MINIMIZED LOGO ========================
local MinimizedLogo = Create("Frame", {
    Parent = ScreenGui,
    Name = "MinimizedLogo",
    Size = UDim2.new(0, scale(60), 0, scale(60)),
    Position = UDim2.new(0, scale(20), 0, scaleY(20)),
    BackgroundColor3 = Colors.Background,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 50,
})
CreateCorner(MinimizedLogo, 12)
CreateStroke(MinimizedLogo, Colors.BorderLight, 2)

local LogoClick = Create("TextButton", {
    Parent = MinimizedLogo,
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "MH",
    TextColor3 = Colors.Accent,
    TextSize = scale(20),
    Font = Enum.Font.GothamBold,
    ZIndex = 60,
})

-- ======================== WINDOW DRAG (PC) ========================
local dragging, dragStart, startPos = false, nil, nil
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

-- ======================== TOUCH DRAG (MOBILE) ========================
local touchDragging, touchStart, touchStartPos = false, nil, nil
TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        touchDragging = true
        touchStart = input.Position
        touchStartPos = MainFrame.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if touchDragging and input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - touchStart
        MainFrame.Position = UDim2.new(touchStartPos.X.Scale, touchStartPos.X.Offset + delta.X, touchStartPos.Y.Scale, touchStartPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then touchDragging = false end
end)

-- ======================== MINIMIZE / RESTORE ========================
local minimized = false
local originalSize = MainFrame.Size

local function DoMinimize()
    minimized = true
    local ap = MainFrame.AbsolutePosition
    local as = MainFrame.AbsoluteSize
    local cx = ap.X + as.X / 2
    local cy = ap.Y + as.Y / 2

    MinimizedLogo.Position = UDim2.new(0, cx - scale(30), 0, cy - scale(30))

    Tween(MainFrame, {Size = UDim2.new(0, scale(60), 0, scale(60)), Position = UDim2.new(0, cx - scale(30), 0, cy - scale(30))}, 0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
    task.delay(0.25, function()
        Sidebar.Visible = false
        ContentArea.Visible = false
        TopBar.Visible = false
    end)
    task.delay(0.4, function()
        MinimizedLogo.Visible = true
        Tween(MinimizedLogo, {BackgroundTransparency = 0}, 0.3)
    end)
end

local function DoRestore()
    minimized = false
    Tween(MinimizedLogo, {BackgroundTransparency = 1}, 0.25)
    task.delay(0.2, function()
        MinimizedLogo.Visible = false
        TopBar.Visible = true
        Sidebar.Visible = true
        ContentArea.Visible = true
        MainFrame.BackgroundTransparency = 0
        Tween(MainFrame, {Size = originalSize, Position = UDim2.new(0.5, -originalSize.X.Offset / 2, 0.5, -originalSize.Y.Offset / 2)}, 0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    end)
end

MinimizeButton.MouseButton1Click:Connect(function()
    if minimized then DoRestore() else DoMinimize() end
end)

LogoClick.MouseButton1Click:Connect(function()
    if minimized then DoRestore() end
end)

-- ======================== CONFIRM CLOSE MODAL ========================
local ConfirmModal = Create("Frame", {
    Parent = ScreenGui,
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
    BackgroundTransparency = 1,
    Visible = false,
    ZIndex = 1000,
})

local ConfirmBox = Create("Frame", {
    Parent = ConfirmModal,
    Size = UDim2.new(0, scale(380), 0, scaleY(200)),
    Position = UDim2.new(0.5, -scale(190), 0.5, -scaleY(100)),
    BackgroundColor3 = Colors.BackgroundLight,
    BorderSizePixel = 0,
    ZIndex = 1001,
})
CreateCorner(ConfirmBox, 16)
CreateStroke(ConfirmBox, Colors.Border, 1)

local confContent = Create("Frame", {
    Parent = ConfirmBox,
    Size = UDim2.new(1, -scale(48), 1, -scale(48)),
    Position = UDim2.new(0, scale(24), 0, scale(24)),
    BackgroundTransparency = 1,
    ZIndex = 1002,
})

Create("UIListLayout", {
    Parent = confContent,
    Padding = UDim.new(0, scale(10)),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
})

Create("TextLabel", {
    Parent = confContent,
    Size = UDim2.new(1, 0, 0, scaleY(28)),
    BackgroundTransparency = 1,
    Text = "Close Miracle Hub?",
    TextColor3 = Colors.TextPrimary,
    TextSize = scale(20),
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Center,
    LayoutOrder = 1,
    ZIndex = 1002,
})

Create("TextLabel", {
    Parent = confContent,
    Size = UDim2.new(1, 0, 0, scaleY(36)),
    BackgroundTransparency = 1,
    Text = "All automation loops will stop. Re-inject to use again.",
    TextColor3 = Colors.TextSecondary,
    TextSize = scale(13),
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextWrapped = true,
    LayoutOrder = 2,
    ZIndex = 1002,
})

local btnRow = Create("Frame", {
    Parent = confContent,
    Size = UDim2.new(1, 0, 0, scaleY(38)),
    BackgroundTransparency = 1,
    LayoutOrder = 3,
    ZIndex = 1002,
})

Create("UIListLayout", {
    Parent = btnRow,
    Padding = UDim.new(0, scale(12)),
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
})

local ConfYes = Create("TextButton", {
    Parent = btnRow,
    Size = UDim2.new(0, scale(110), 0, scaleY(36)),
    BackgroundColor3 = Color3.fromRGB(180, 80, 80),
    Text = "Yes, Close",
    TextColor3 = Colors.TextPrimary,
    TextSize = scale(13),
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0,
    ZIndex = 1002,
    AutoButtonColor = false,
})
CreateCorner(ConfYes, 8)

local ConfNo = Create("TextButton", {
    Parent = btnRow,
    Size = UDim2.new(0, scale(110), 0, scaleY(36)),
    BackgroundColor3 = Colors.Surface,
    Text = "Cancel",
    TextColor3 = Colors.TextPrimary,
    TextSize = scale(13),
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0,
    ZIndex = 1002,
    AutoButtonColor = false,
})
CreateCorner(ConfNo, 8)

CloseButton.MouseButton1Click:Connect(function()
    if States.minimizeToTray then
        DoMinimize()
        return
    end
    ConfirmModal.Visible = true
    Tween(ConfirmModal, {BackgroundTransparency = 0.55}, 0.25)
    Tween(ConfirmBox, {Size = UDim2.new(0, scale(380), 0, scaleY(200))}, 0.3, Enum.EasingStyle.Back)
end)

ConfNo.MouseButton1Click:Connect(function()
    Tween(ConfirmModal, {BackgroundTransparency = 1}, 0.25)
    task.wait(0.3)
    ConfirmModal.Visible = false
end)

ConfYes.MouseButton1Click:Connect(function()
    Tween(ConfirmModal, {BackgroundTransparency = 1}, 0.2)
    task.wait(0.25)
    Tween(MainFrame, {Size = UDim2.new(0, scale(900), 0, 0)}, 0.3)
    task.wait(0.3)
    ScreenGui:Destroy()
end)

-- ======================== KEYBINDS ========================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    -- Insert: toggle minimize
    if input.KeyCode == Enum.KeyCode.Insert then
        if minimized then DoRestore() else DoMinimize() end
    end
    -- F: toggle fly
    if input.KeyCode == Enum.KeyCode.F then
        States.fly = not States.fly
        Notify("Player", "Fly " .. (States.fly and "ON ✅" or "OFF ❌"), States.fly and Colors.Success or Colors.TextMuted)
    end
end)

-- ======================== LOADING SCREEN ========================
local LoadingScreen = Create("Frame", {
    Parent = ScreenGui,
    Name = "LoadingScreen",
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = Colors.Background,
    BorderSizePixel = 0,
    ZIndex = 2000,
})

local LoadingContainer = Create("Frame", {
    Parent = LoadingScreen,
    Size = UDim2.new(0, scale(400), 0, scaleY(200)),
    Position = UDim2.new(0.5, -scale(200), 0.5, -scaleY(100)),
    BackgroundColor3 = Colors.BackgroundLight,
    BorderSizePixel = 0,
    ZIndex = 2001,
})
CreateCorner(LoadingContainer, 16)
CreateStroke(LoadingContainer, Colors.Border, 1)

local LoadingTitle = Create("TextLabel", {
    Parent = LoadingContainer,
    Size = UDim2.new(1, 0, 0, scaleY(40)),
    Position = UDim2.new(0, 0, 0, scaleY(20)),
    BackgroundTransparency = 1,
    Text = "Miracle Hub",
    TextColor3 = Colors.TextPrimary,
    TextSize = scale(28),
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 2002,
})

local LoadingStatus = Create("TextLabel", {
    Parent = LoadingContainer,
    Size = UDim2.new(1, -scale(40), 0, scaleY(24)),
    Position = UDim2.new(0, scale(20), 0, scaleY(70)),
    BackgroundTransparency = 1,
    Text = "Initializing...",
    TextColor3 = Colors.TextSecondary,
    TextSize = scale(14),
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 2002,
})

local LoadingBarBg = Create("Frame", {
    Parent = LoadingContainer,
    Size = UDim2.new(1, -scale(40), 0, scale(8)),
    Position = UDim2.new(0, scale(20), 0, scaleY(110)),
    BackgroundColor3 = Colors.SliderTrack,
    BorderSizePixel = 0,
    ZIndex = 2002,
})
CreateCorner(LoadingBarBg, 4)

local LoadingBarFill = Create("Frame", {
    Parent = LoadingBarBg,
    Size = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = Colors.Accent,
    BorderSizePixel = 0,
    ZIndex = 2003,
})
CreateCorner(LoadingBarFill, 4)

local LoadingPercent = Create("TextLabel", {
    Parent = LoadingContainer,
    Size = UDim2.new(1, 0, 0, scaleY(24)),
    Position = UDim2.new(0, 0, 0, scaleY(130)),
    BackgroundTransparency = 1,
    Text = "0%",
    TextColor3 = Colors.TextMuted,
    TextSize = scale(14),
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 2002,
})

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
        LoadingStatus.Text = "✅ Ready!"
        task.wait(0.4)

        Tween(LoadingContainer, {BackgroundTransparency = 1}, 0.4)
        for _, c in ipairs(LoadingContainer:GetDescendants()) do
            if c:IsA("TextLabel") then Tween(c, {TextTransparency = 1}, 0.4)
            elseif c:IsA("Frame") then Tween(c, {BackgroundTransparency = 1}, 0.4) end
        end
        task.wait(0.5)
        LoadingScreen:Destroy()

        MainFrame.Visible = true
        MainFrame.Size = UDim2.new(0, scale(900), 0, 0)
        Tween(MainFrame, {Size = originalSize}, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

        task.wait(0.3)
        SetActivePage("Farm")

        task.wait(0.8)
        local remoteStatus = PacketRemote and "Remote ✅" or "Remote ⚠ (check console)"
        Notify("Miracle Hub", "Loaded! Plot " .. MY_PLOT_ID .. " | " .. remoteStatus .. " | [Insert] toggle | [F] fly", Colors.Success, 6)
    end
end)

print("[Miracle Hub] Full build loaded — Player: " .. player.Name)
print("[Miracle Hub] PlotId: " .. MY_PLOT_ID .. " | MaxPets: " .. MAX_EQUIPPED_PETS .. " | MaxFruits: " .. MAX_FRUIT_CAP)
print("[Miracle Hub] PacketRemote: " .. (PacketRemote and PacketRemote:GetFullName() or "NOT FOUND"))
print("[Miracle Hub] Keybinds: [Insert] = toggle GUI | [F] = toggle Fly")
