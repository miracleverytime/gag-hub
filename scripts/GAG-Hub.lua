--[[
    Miracle Hub - Modern Elegant GUI for Roblox
    Theme: Black & White (Monochrome)
    Features: Sidebar navigation, collapsible sections, toggles, sliders, dropdowns
    Pure GUI only - no functional logic
--]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remove existing GUI if any
local existingGui = playerGui:FindFirstChild("MiracleHub")
if existingGui then
    existingGui:Destroy()
end

-- Color Palette (Black & White Theme)
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
    ToggleOn = Color3.fromRGB(80, 80, 90),
    ToggleOff = Color3.fromRGB(40, 40, 48),
    ToggleKnob = Color3.fromRGB(200, 200, 210),
    SliderTrack = Color3.fromRGB(40, 40, 48),
    SliderFill = Color3.fromRGB(200, 200, 210),
    Success = Color3.fromRGB(50, 255, 100),
    Error = Color3.fromRGB(180, 80, 80),
}

-- Utility Functions
local function Create(className, properties)
    local instance = Instance.new(className)
    for prop, value in pairs(properties or {}) do
        instance[prop] = value
    end
    return instance
end

local function CreateCorner(parent, radius)
    local corner = Create("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
        Parent = parent,
    })
    return corner
end

local function CreateStroke(parent, color, thickness)
    local stroke = Create("UIStroke", {
        Color = color or Colors.Border,
        Thickness = thickness or 1,
        Parent = parent,
    })
    return stroke
end

local function CreatePadding(parent, padding)
    local pad = Create("UIPadding", {
        PaddingLeft = UDim.new(0, padding or 12),
        PaddingRight = UDim.new(0, padding or 12),
        PaddingTop = UDim.new(0, padding or 12),
        PaddingBottom = UDim.new(0, padding or 12),
        Parent = parent,
    })
    return pad
end

local function CreateListLayout(parent, padding, direction)
    local layout = Create("UIListLayout", {
        Padding = UDim.new(0, padding or 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        FillDirection = direction or Enum.FillDirection.Vertical,
        Parent = parent,
    })
    return layout
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

-- Main GUI
local ScreenGui = Create("ScreenGui", {
    Name = "MiracleHub",
    Parent = playerGui,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

-- Loading Screen (shown first, GUI hidden until done)
local LoadingScreen = Create("Frame", {
    Name = "LoadingScreen",
    Parent = ScreenGui,
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = Colors.Background,
    BorderSizePixel = 0,
    ZIndex = 100,
})

local LoadingContainer = Create("Frame", {
    Name = "LoadingContainer",
    Parent = LoadingScreen,
    Size = UDim2.new(0, 400, 0, 160),
    Position = UDim2.new(0.5, -200, 0.5, -80),
    BackgroundColor3 = Colors.BackgroundLight,
    BorderSizePixel = 0,
    ZIndex = 101,
})
CreateCorner(LoadingContainer, 16)
CreateStroke(LoadingContainer, Colors.Border, 1)

local LoadingTitle = Create("TextLabel", {
    Name = "LoadingTitle",
    Parent = LoadingContainer,
    Size = UDim2.new(1, 0, 0, 30),
    Position = UDim2.new(0, 0, 0, 20),
    BackgroundTransparency = 1,
    Text = "Miracle Hub",
    TextColor3 = Colors.Success,
    TextSize = 24,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 102,
})

local LoadingSubtitle = Create("TextLabel", {
    Name = "LoadingSubtitle",
    Parent = LoadingContainer,
    Size = UDim2.new(1, 0, 0, 20),
    Position = UDim2.new(0, 0, 0, 52),
    BackgroundTransparency = 1,
    Text = "Grow A Garden 2",
    TextColor3 = Colors.TextMuted,
    TextSize = 14,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 102,
})

local LoadingBarBg = Create("Frame", {
    Name = "LoadingBarBg",
    Parent = LoadingContainer,
    Size = UDim2.new(1, -60, 0, 8),
    Position = UDim2.new(0, 30, 0, 90),
    BackgroundColor3 = Colors.BackgroundLighter,
    BorderSizePixel = 0,
    ZIndex = 102,
})
CreateCorner(LoadingBarBg, 4)

local LoadingBarFill = Create("Frame", {
    Name = "LoadingBarFill",
    Parent = LoadingBarBg,
    Size = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = Colors.Success,
    BorderSizePixel = 0,
    ZIndex = 103,
})
CreateCorner(LoadingBarFill, 4)

local LoadingPercent = Create("TextLabel", {
    Name = "LoadingPercent",
    Parent = LoadingContainer,
    Size = UDim2.new(1, 0, 0, 20),
    Position = UDim2.new(0, 0, 0, 110),
    BackgroundTransparency = 1,
    Text = "0%",
    TextColor3 = Colors.Success,
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 102,
})

local LoadingStatus = Create("TextLabel", {
    Name = "LoadingStatus",
    Parent = LoadingContainer,
    Size = UDim2.new(1, 0, 0, 18),
    Position = UDim2.new(0, 0, 0, 132),
    BackgroundTransparency = 1,
    Text = "Initializing...",
    TextColor3 = Colors.TextMuted,
    TextSize = 12,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 102,
})

-- Main Frame (hidden initially)
local MainFrame = Create("Frame", {
    Name = "MainFrame",
    Parent = ScreenGui,
    Size = UDim2.new(0, 900, 0, 600),
    Position = UDim2.new(0.5, -450, 0.5, -300),
    BackgroundColor3 = Colors.Background,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Visible = false,
})
CreateCorner(MainFrame, 16)

-- Top Bar
local TopBar = Create("Frame", {
    Name = "TopBar",
    Parent = MainFrame,
    Size = UDim2.new(1, 0, 0, 50),
    BackgroundColor3 = Colors.BackgroundLight,
    BorderSizePixel = 0,
})
CreateCorner(TopBar, 0)

-- Window Controls (Top Left)
local WindowControls = Create("Frame", {
    Name = "WindowControls",
    Parent = TopBar,
    Size = UDim2.new(0, 70, 1, 0),
    BackgroundTransparency = 1,
})
CreatePadding(WindowControls, 16)

local CloseButton = Create("TextButton", {
    Name = "CloseButton",
    Parent = WindowControls,
    Size = UDim2.new(0, 12, 0, 12),
    Position = UDim2.new(0, 0, 0.5, -6),
    BackgroundColor3 = Color3.fromRGB(255, 95, 87),
    Text = "",
    BorderSizePixel = 0,
})
CreateCorner(CloseButton, 6)

local MinimizeButton = Create("TextButton", {
    Name = "MinimizeButton",
    Parent = WindowControls,
    Size = UDim2.new(0, 12, 0, 12),
    Position = UDim2.new(0, 20, 0.5, -6),
    BackgroundColor3 = Color3.fromRGB(255, 189, 46),
    Text = "",
    BorderSizePixel = 0,
})
CreateCorner(MinimizeButton, 6)

local MaximizeButton = Create("TextButton", {
    Name = "MaximizeButton",
    Parent = WindowControls,
    Size = UDim2.new(0, 12, 0, 12),
    Position = UDim2.new(0, 40, 0.5, -6),
    BackgroundColor3 = Color3.fromRGB(40, 200, 64),
    Text = "",
    BorderSizePixel = 0,
})
CreateCorner(MaximizeButton, 6)

-- Search Bar
local SearchBar = Create("Frame", {
    Name = "SearchBar",
    Parent = TopBar,
    Size = UDim2.new(0, 280, 0, 34),
    Position = UDim2.new(0, 90, 0.5, -17),
    BackgroundColor3 = Colors.Background,
    BorderSizePixel = 0,
})
CreateCorner(SearchBar, 8)
CreateStroke(SearchBar, Colors.Border, 1)

local SearchIcon = Create("TextLabel", {
    Name = "SearchIcon",
    Parent = SearchBar,
    Size = UDim2.new(0, 30, 1, 0),
    BackgroundTransparency = 1,
    Text = "🔍",
    TextColor3 = Colors.TextMuted,
    TextSize = 14,
    Font = Enum.Font.Gotham,
})

local SearchBox = Create("TextBox", {
    Name = "SearchBox",
    Parent = SearchBar,
    Size = UDim2.new(1, -40, 1, 0),
    Position = UDim2.new(0, 30, 0, 0),
    BackgroundTransparency = 1,
    Text = "",
    PlaceholderText = "Search...",
    PlaceholderColor3 = Colors.TextMuted,
    TextColor3 = Colors.TextPrimary,
    TextSize = 14,
    Font = Enum.Font.Gotham,
    ClearTextOnFocus = false,
})

-- Page Title
local PageTitle = Create("TextLabel", {
    Name = "PageTitle",
    Parent = TopBar,
    Size = UDim2.new(0, 200, 1, 0),
    Position = UDim2.new(0.5, -100, 0, 0),
    BackgroundTransparency = 1,
    Text = "Player",
    TextColor3 = Colors.TextPrimary,
    TextSize = 18,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Center,
})

-- Right Controls
local RightControls = Create("Frame", {
    Name = "RightControls",
    Parent = TopBar,
    Size = UDim2.new(0, 80, 1, 0),
    Position = UDim2.new(1, -80, 0, 0),
    BackgroundTransparency = 1,
})

local LayoutButton = Create("TextButton", {
    Name = "LayoutButton",
    Parent = RightControls,
    Size = UDim2.new(0, 32, 0, 32),
    Position = UDim2.new(0, 8, 0.5, -16),
    BackgroundColor3 = Colors.Surface,
    Text = "☰",
    TextColor3 = Colors.TextSecondary,
    TextSize = 16,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0,
})
CreateCorner(LayoutButton, 6)

local FullscreenButton = Create("TextButton", {
    Name = "FullscreenButton",
    Parent = RightControls,
    Size = UDim2.new(0, 32, 0, 32),
    Position = UDim2.new(0, 44, 0.5, -16),
    BackgroundColor3 = Colors.Surface,
    Text = "⛶",
    TextColor3 = Colors.TextSecondary,
    TextSize = 16,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0,
})
CreateCorner(FullscreenButton, 6)

-- Sidebar
local Sidebar = Create("Frame", {
    Name = "Sidebar",
    Parent = MainFrame,
    Size = UDim2.new(0, 240, 1, -50),
    Position = UDim2.new(0, 0, 0, 50),
    BackgroundColor3 = Colors.BackgroundLight,
    BorderSizePixel = 0,
})

local SidebarContent = Create("ScrollingFrame", {
    Name = "SidebarContent",
    Parent = Sidebar,
    Size = UDim2.new(1, 0, 1, -90),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Colors.Border,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
})
CreatePadding(SidebarContent, 16)

local SidebarLayout = CreateListLayout(SidebarContent, 4)

-- Hub Info Card
local HubCard = Create("Frame", {
    Name = "HubCard",
    Parent = SidebarContent,
    Size = UDim2.new(1, 0, 0, 70),
    BackgroundColor3 = Colors.BackgroundLighter,
    BorderSizePixel = 0,
    LayoutOrder = 0,
})
CreateCorner(HubCard, 12)
CreatePadding(HubCard, 16)

local HubTitle = Create("TextLabel", {
    Name = "HubTitle",
    Parent = HubCard,
    Size = UDim2.new(1, 0, 0, 22),
    BackgroundTransparency = 1,
    Text = "Miracle Hub",
    TextColor3 = Colors.Accent,
    TextSize = 18,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
})

local HubSubtitle = Create("TextLabel", {
    Name = "HubSubtitle",
    Parent = HubCard,
    Size = UDim2.new(1, 0, 0, 18),
    Position = UDim2.new(0, 0, 0, 24),
    BackgroundTransparency = 1,
    Text = "Grow A Garden 2",
    TextColor3 = Colors.TextMuted,
    TextSize = 13,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
})

-- Section Header Function
local function CreateSectionHeader(parent, text, layoutOrder)
    local header = Create("TextLabel", {
        Name = text .. "Header",
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Colors.TextMuted,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = layoutOrder,
    })
    return header
end

-- Sidebar Button Function
local function CreateSidebarButton(parent, icon, text, isActive, layoutOrder)
    local button = Create("TextButton", {
        Name = text .. "Button",
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = isActive and Colors.BackgroundLighter or Color3.new(1, 1, 1),
        BackgroundTransparency = isActive and 0 or 1,
        Text = "",
        BorderSizePixel = 0,
        LayoutOrder = layoutOrder,
        AutoButtonColor = false,
    })
    CreateCorner(button, 10)
    
    local indicator = Create("Frame", {
        Name = "Indicator",
        Parent = button,
        Size = UDim2.new(0, 3, 0, 20),
        Position = UDim2.new(0, 0, 0.5, -10),
        BackgroundColor3 = Colors.Accent,
        BorderSizePixel = 0,
        Visible = isActive,
    })
    CreateCorner(indicator, 2)
    
    local iconLabel = Create("TextLabel", {
        Name = "Icon",
        Parent = button,
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(0, 16, 0.5, -12),
        BackgroundTransparency = 1,
        Text = icon,
        TextColor3 = isActive and Colors.TextPrimary or Colors.TextSecondary,
        TextSize = 18,
        Font = Enum.Font.Gotham,
    })
    
    local textLabel = Create("TextLabel", {
        Name = "Text",
        Parent = button,
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.new(0, 48, 0, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = isActive and Colors.TextPrimary or Colors.TextSecondary,
        TextSize = 14,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    -- Hover effects
    button.MouseEnter:Connect(function()
        if not isActive then
            Tween(button, {BackgroundTransparency = 0.9}, 0.2)
        end
    end)
    
    button.MouseLeave:Connect(function()
        if not isActive then
            Tween(button, {BackgroundTransparency = 1}, 0.2)
        end
    end)
    
    return button
end

-- Create Sidebar Sections and Buttons
CreateSectionHeader(SidebarContent, "AUTOMATION", 1)
CreateSidebarButton(SidebarContent, "🌱", "Farm", false, 2)
CreateSidebarButton(SidebarContent, "📐", "Plot", false, 3)
CreateSidebarButton(SidebarContent, "🛒", "Shop", false, 4)
CreateSidebarButton(SidebarContent, "💰", "Sell", false, 5)
CreateSidebarButton(SidebarContent, "🐾", "Pets", false, 6)
CreateSidebarButton(SidebarContent, "🥚", "Eggs", false, 7)

CreateSectionHeader(SidebarContent, "PLAYER", 8)
CreateSidebarButton(SidebarContent, "👤", "Player", true, 9)
CreateSidebarButton(SidebarContent, "👁", "Visuals", false, 10)
CreateSidebarButton(SidebarContent, "📍", "Teleport", false, 11)

CreateSectionHeader(SidebarContent, "MISC", 12)
CreateSidebarButton(SidebarContent, "🔧", "Utility", false, 13)
CreateSidebarButton(SidebarContent, "✉", "Mailer", false, 14)
CreateSidebarButton(SidebarContent, "ℹ", "Info", false, 15)
CreateSidebarButton(SidebarContent, "🌐", "Server", false, 16)
CreateSidebarButton(SidebarContent, "⚙", "Settings", false, 17)

-- User Profile Card (Bottom of Sidebar)
local ProfileCard = Create("Frame", {
    Name = "ProfileCard",
    Parent = Sidebar,
    Size = UDim2.new(1, -32, 0, 70),
    Position = UDim2.new(0, 16, 1, -80),
    BackgroundColor3 = Colors.BackgroundLighter,
    BorderSizePixel = 0,
})
CreateCorner(ProfileCard, 12)

local ProfileAvatar = Create("ImageLabel", {
    Name = "Avatar",
    Parent = ProfileCard,
    Size = UDim2.new(0, 44, 0, 44),
    Position = UDim2.new(0, 12, 0.5, -22),
    BackgroundColor3 = Colors.Surface,
    Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150",
    BorderSizePixel = 0,
})
CreateCorner(ProfileAvatar, 22)

local ProfileName = Create("TextLabel", {
    Name = "ProfileName",
    Parent = ProfileCard,
    Size = UDim2.new(1, -72, 0, 18),
    Position = UDim2.new(0, 64, 0, 14),
    BackgroundTransparency = 1,
    Text = player.DisplayName or player.Name,
    TextColor3 = Colors.TextPrimary,
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
})

local ProfileUsername = Create("TextLabel", {
    Name = "ProfileUsername",
    Parent = ProfileCard,
    Size = UDim2.new(1, -72, 0, 16),
    Position = UDim2.new(0, 64, 0, 34),
    BackgroundTransparency = 1,
    Text = "@" .. player.Name,
    TextColor3 = Colors.TextMuted,
    TextSize = 12,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
})

local ProfileStatus = Create("TextLabel", {
    Name = "ProfileStatus",
    Parent = ProfileCard,
    Size = UDim2.new(0, 40, 0, 16),
    Position = UDim2.new(0, 64, 0, 50),
    BackgroundTransparency = 1,
    Text = "Free",
    TextColor3 = Colors.TextMuted,
    TextSize = 11,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
})

-- Content Area
local ContentArea = Create("Frame", {
    Name = "ContentArea",
    Parent = MainFrame,
    Size = UDim2.new(1, -240, 1, -50),
    Position = UDim2.new(0, 240, 0, 50),
    BackgroundColor3 = Colors.Background,
    BorderSizePixel = 0,
    ClipsDescendants = true,
})

local ContentScroll = Create("ScrollingFrame", {
    Name = "ContentScroll",
    Parent = ContentArea,
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Colors.Border,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
})
CreatePadding(ContentScroll, 20)

local ContentLayout = CreateListLayout(ContentScroll, 16)

-- Section Card Function
local function CreateSectionCard(parent, title, layoutOrder)
    local card = Create("Frame", {
        Name = title .. "Card",
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = Colors.BackgroundLight,
        BorderSizePixel = 0,
        LayoutOrder = layoutOrder,
        AutomaticSize = Enum.AutomaticSize.Y,
    })
    CreateCorner(card, 14)
    CreatePadding(card, 20)
    
    local cardLayout = CreateListLayout(card, 16)
    
    -- Section Header with Dropdown
    local header = Create("Frame", {
        Name = "Header",
        Parent = card,
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        LayoutOrder = 0,
    })
    
    local titleLabel = Create("TextLabel", {
        Name = "Title",
        Parent = header,
        Size = UDim2.new(1, -40, 1, 0),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Colors.Accent,
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    local dropdownBtn = Create("TextButton", {
        Name = "DropdownBtn",
        Parent = header,
        Size = UDim2.new(0, 36, 0, 36),
        Position = UDim2.new(1, -36, 0, -4),
        BackgroundColor3 = Colors.Surface,
        Text = "▼",
        TextColor3 = Colors.TextSecondary,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
    })
    CreateCorner(dropdownBtn, 8)
    
    local content = Create("Frame", {
        Name = "Content",
        Parent = card,
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
    })
    local contentLayout = CreateListLayout(content, 12)
    
    -- Toggle collapse
    local collapsed = false
    dropdownBtn.MouseButton1Click:Connect(function()
        collapsed = not collapsed
        content.Visible = not collapsed
        Tween(dropdownBtn, {Rotation = collapsed and -90 or 0}, 0.3)
    end)
    
    return card, content
end

-- Subsection Header
local function CreateSubsectionHeader(parent, text)
    local header = Create("Frame", {
        Name = text .. "SubHeader",
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
    })
    
    local label = Create("TextLabel", {
        Name = "Label",
        Parent = header,
        Size = UDim2.new(0, 200, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Colors.TextSecondary,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    local line = Create("Frame", {
        Name = "Line",
        Parent = header,
        Size = UDim2.new(1, -210, 0, 1),
        Position = UDim2.new(0, 210, 0.5, -0.5),
        BackgroundColor3 = Colors.Border,
        BorderSizePixel = 0,
    })
    
    return header
end

-- Toggle Switch Function
local function CreateToggle(parent, text, defaultState, description)
    local container = Create("Frame", {
        Name = text .. "Toggle",
        Parent = parent,
        Size = UDim2.new(1, 0, 0, description and 56 or 36),
        BackgroundTransparency = 1,
    })
    
    local label = Create("TextLabel", {
        Name = "Label",
        Parent = container,
        Size = UDim2.new(1, -70, 0, 20),
        Position = UDim2.new(0, 0, 0, description and 8 or 8),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Colors.TextPrimary,
        TextSize = 14,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    if description then
        local descLabel = Create("TextLabel", {
            Name = "Description",
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
        Name = "ToggleBg",
        Parent = container,
        Size = UDim2.new(0, 48, 0, 26),
        Position = UDim2.new(1, -48, 0, description and 15 or 5),
        BackgroundColor3 = defaultState and Colors.ToggleOn or Colors.ToggleOff,
        BorderSizePixel = 0,
    })
    CreateCorner(toggleBg, 13)
    CreateStroke(toggleBg, Colors.Border, 1)
    
    local knob = Create("Frame", {
        Name = "Knob",
        Parent = toggleBg,
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(0, defaultState and 26 or 2, 0.5, -10),
        BackgroundColor3 = Colors.ToggleKnob,
        BorderSizePixel = 0,
    })
    CreateCorner(knob, 10)
    
    local state = defaultState
    local toggleBtn = Create("TextButton", {
        Name = "ToggleBtn",
        Parent = container,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
    })
    
    toggleBtn.MouseButton1Click:Connect(function()
        state = not state
        Tween(toggleBg, {BackgroundColor3 = state and Colors.ToggleOn or Colors.ToggleOff}, 0.2)
        Tween(knob, {Position = UDim2.new(0, state and 26 or 2, 0.5, -10)}, 0.2)
    end)
    
    return container, function() return state end
end

-- Slider Function
local function CreateSlider(parent, text, min, max, default, valueFormat)
    local container = Create("Frame", {
        Name = text .. "Slider",
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundTransparency = 1,
    })
    
    local label = Create("TextLabel", {
        Name = "Label",
        Parent = container,
        Size = UDim2.new(0, 120, 0, 20),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Colors.TextPrimary,
        TextSize = 14,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    local valueLabel = Create("TextLabel", {
        Name = "Value",
        Parent = container,
        Size = UDim2.new(0, 50, 0, 24),
        Position = UDim2.new(1, -50, 0, 0),
        BackgroundColor3 = Colors.BackgroundLighter,
        Text = tostring(default),
        TextColor3 = Colors.TextSecondary,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        BorderSizePixel = 0,
    })
    CreateCorner(valueLabel, 6)
    
    local track = Create("Frame", {
        Name = "Track",
        Parent = container,
        Size = UDim2.new(1, -70, 0, 6),
        Position = UDim2.new(0, 0, 0, 32),
        BackgroundColor3 = Colors.SliderTrack,
        BorderSizePixel = 0,
    })
    CreateCorner(track, 3)
    
    local fill = Create("Frame", {
        Name = "Fill",
        Parent = track,
        Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = Colors.SliderFill,
        BorderSizePixel = 0,
    })
    CreateCorner(fill, 3)
    
    local knob = Create("Frame", {
        Name = "Knob",
        Parent = track,
        Size = UDim2.new(0, 16, 0, 16),
        Position = UDim2.new((default - min) / (max - min), -8, 0.5, -8),
        BackgroundColor3 = Colors.TextPrimary,
        BorderSizePixel = 0,
    })
    CreateCorner(knob, 8)
    
    -- Slider interaction (visual only)
    local dragging = false
    local trackBtn = Create("TextButton", {
        Name = "TrackBtn",
        Parent = container,
        Size = UDim2.new(1, -70, 0, 30),
        Position = UDim2.new(0, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = "",
    })
    
    return container
end

-- Action Button Function
local function CreateActionButton(parent, text, hasArrow)
    local container = Create("Frame", {
        Name = text .. "Action",
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
    })
    
    local btn = Create("TextButton", {
        Name = "Btn",
        Parent = container,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Colors.BackgroundLighter,
        Text = "",
        BorderSizePixel = 0,
        AutoButtonColor = false,
    })
    CreateCorner(btn, 10)
    CreateStroke(btn, Colors.Border, 1)
    
    local label = Create("TextLabel", {
        Name = "Label",
        Parent = btn,
        Size = UDim2.new(1, hasArrow and -40 or -20, 1, 0),
        Position = UDim2.new(0, 16, 0, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Colors.TextPrimary,
        TextSize = 14,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    if hasArrow then
        local arrow = Create("TextLabel", {
            Name = "Arrow",
            Parent = btn,
            Size = UDim2.new(0, 24, 1, 0),
            Position = UDim2.new(1, -32, 0, 0),
            BackgroundTransparency = 1,
            Text = ">",
            TextColor3 = Colors.TextMuted,
            TextSize = 16,
            Font = Enum.Font.GothamBold,
        })
    end
    
    btn.MouseEnter:Connect(function()
        Tween(btn, {BackgroundColor3 = Colors.Surface}, 0.2)
    end)
    
    btn.MouseLeave:Connect(function()
        Tween(btn, {BackgroundColor3 = Colors.BackgroundLighter}, 0.2)
    end)
    
    return container
end

-- Dropdown/Selector Function
local function CreateSelector(parent, text, selectedText)
    local container = Create("Frame", {
        Name = text .. "Selector",
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
    })
    
    local btn = Create("TextButton", {
        Name = "Btn",
        Parent = container,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Colors.BackgroundLighter,
        Text = "",
        BorderSizePixel = 0,
        AutoButtonColor = false,
    })
    CreateCorner(btn, 10)
    CreateStroke(btn, Colors.Border, 1)
    
    local label = Create("TextLabel", {
        Name = "Label",
        Parent = btn,
        Size = UDim2.new(1, -50, 1, 0),
        Position = UDim2.new(0, 16, 0, 0),
        BackgroundTransparency = 1,
        Text = text .. " • " .. selectedText,
        TextColor3 = Colors.TextPrimary,
        TextSize = 14,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    local icon = Create("TextLabel", {
        Name = "Icon",
        Parent = btn,
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(1, -36, 0.5, -12),
        BackgroundTransparency = 1,
        Text = "📦",
        TextColor3 = Colors.TextMuted,
        TextSize = 16,
        Font = Enum.Font.Gotham,
    })
    
    btn.MouseEnter:Connect(function()
        Tween(btn, {BackgroundColor3 = Colors.Surface}, 0.2)
    end)
    
    btn.MouseLeave:Connect(function()
        Tween(btn, {BackgroundColor3 = Colors.BackgroundLighter}, 0.2)
    end)
    
    return container
end

-- Info Text Function
local function CreateInfoText(parent, title, description)
    local container = Create("Frame", {
        Name = title .. "Info",
        Parent = parent,
        Size = UDim2.new(1, 0, 0, 60),
        BackgroundTransparency = 1,
    })
    
    local titleLabel = Create("TextLabel", {
        Name = "Title",
        Parent = container,
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Colors.Accent,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    local descLabel = Create("TextLabel", {
        Name = "Description",
        Parent = container,
        Size = UDim2.new(1, 0, 0, 36),
        Position = UDim2.new(0, 0, 0, 22),
        BackgroundTransparency = 1,
        Text = description,
        TextColor3 = Colors.TextMuted,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
    })
    
    return container
end

-- ==================== PLAYER PAGE ====================
local function BuildPlayerPage()
    -- Movement Section
    local movementCard, movementContent = CreateSectionCard(ContentScroll, "Movement", 1)
    CreateSubsectionHeader(movementContent, "Speed & Jump")
    CreateToggle(movementContent, "Lock WalkSpeed", false)
    CreateSlider(movementContent, "WalkSpeed", 1, 100, 16)
    CreateToggle(movementContent, "Lock JumpPower", false)
    CreateSlider(movementContent, "JumpPower", 1, 100, 50)
    CreateToggle(movementContent, "Infinite Jump", false)
    
    -- Utility Section
    local utilityCard, utilityContent = CreateSectionCard(ContentScroll, "Utility", 2)
    CreateSubsectionHeader(utilityContent, "Fly & Noclip")
    CreateToggle(utilityContent, "Fly (WASD + Space/Ctrl)", false)
    CreateSlider(utilityContent, "Fly Speed", 1, 200, 60)
    CreateToggle(utilityContent, "Noclip", false)
    CreateSubsectionHeader(utilityContent, "Misc")
    CreateToggle(utilityContent, "Anti AFK", true)
end

-- ==================== FARM PAGE ====================
local function BuildFarmPage()
    -- Planting Section
    local plantingCard, plantingContent = CreateSectionCard(ContentScroll, "Planting", 1)
    CreateSubsectionHeader(plantingContent, "Auto Plant")
    CreateInfoText(plantingContent, "How it works", "Plants seeds automatically across your plots. Leave empty to plant all seeds, or select specific ones.")
    CreateToggle(plantingContent, "Auto Plant", false)
    CreateSelector(plantingContent, "Seeds To Plant", "All Seeds")
    CreateActionButton(plantingContent, "Plant Once Now", true)
    CreateActionButton(plantingContent, "Refresh Seed List", true)
    CreateSelector(plantingContent, "Only These Rarities", "All")
    CreateSlider(plantingContent, "Keep In Reserve (per seed)", 0, 50, 0)
    CreateSlider(plantingContent, "Max Plants / Cycle", 1, 100, 40)
    
    -- Harvest Section
    local harvestCard, harvestContent = CreateSectionCard(ContentScroll, "Harvest", 2)
    CreateSubsectionHeader(harvestContent, "Auto Harvest")
    CreateInfoText(harvestContent, "Ready fruit only", "Collects grown fruit on your plot. Use filters to only pick up certain fruit or mutations.")
    CreateToggle(harvestContent, "Auto Harvest", false)
    CreateSlider(harvestContent, "Per-Fruit Delay", 0, 1, 0.05)
    CreateSlider(harvestContent, "Loop Delay", 0, 10, 2.0)
    CreateToggle(harvestContent, "Notify On Harvest", false)
    CreateActionButton(harvestContent, "Harvest Now", true)
    CreateSubsectionHeader(harvestContent, "Filters")
    CreateSelector(harvestContent, "Only These Fruits", "All")
end

-- ==================== SHOP PAGE ====================
local function BuildShopPage()
    -- Auto Buy Section
    local buyCard, buyContent = CreateSectionCard(ContentScroll, "Auto Buy", 1)
    CreateSelector(buyContent, "Alert From Rarity", "Legendary")
    CreateActionButton(buyContent, "Copy Full Restock Odds", true)
    CreateToggle(buyContent, "Auto Buy Seeds", true)
    CreateSelector(buyContent, "Seeds To Buy", "Bamboo, Mushroom")
    
    -- Crate Section
    local crateCard, crateContent = CreateSectionCard(ContentScroll, "Crates", 2)
    CreateToggle(crateContent, "Auto Buy & Open Crates", false)
    CreateToggle(crateContent, "Buy Before Opening", true)
    CreateActionButton(crateContent, "Open All Crates Now", true)
    CreateSlider(crateContent, "Crate Loop Delay", 1, 30, 8)
    CreateToggle(crateContent, "Notify On Crate", true)
    
    -- Shared Section
    local sharedCard, sharedContent = CreateSectionCard(ContentScroll, "Shared", 3)
    CreateSlider(sharedContent, "Buy Delay", 0, 1, 0.05)
    CreateSlider(sharedContent, "Restock Loop Delay", 1, 30, 6)
    CreateToggle(sharedContent, "Notify On Buy", false)
    CreateActionButton(sharedContent, "Refresh Shop Lists", true)
end

-- ==================== UTILITY PAGE ====================
local function BuildUtilityPage()
    -- Item Worth Section
    local worthCard, worthContent = CreateSectionCard(ContentScroll, "Item Worth", 1)
    CreateInfoText(worthContent, "Held item", "Live worth and stats of whatever you're holding (equip a harvested fruit to see its sell value).")
    CreateInfoText(worthContent, "Now Holding", "You're not holding anything. Equip a fruit/seed to inspect it.")
    CreateActionButton(worthContent, "Show Held Item Worth", true)
    CreateActionButton(worthContent, "Highest Value Fruit In Bag", true)
    CreateActionButton(worthContent, "Total Bag Worth (preview)", true)
    CreateActionButton(worthContent, "Count Fruit In Bag", true)
    
    -- Quick Tools Section
    local toolsCard, toolsContent = CreateSectionCard(ContentScroll, "Quick Tools", 2)
    CreateSubsectionHeader(toolsContent, "Copy & Info")
    CreateActionButton(toolsContent, "Copy My Position", true)
    CreateActionButton(toolsContent, "Copy Job Id", true)
    CreateActionButton(toolsContent, "Show My Stats", true)
    CreateActionButton(toolsContent, "Show Restock Timers", true)
    
    -- Gifts Section
    local giftsCard, giftsContent = CreateSectionCard(ContentScroll, "Gifts", 3)
    CreateInfoText(giftsContent, "Gifts", "Automatically accept any gift another player sends you.")
end

-- ==================== VISUALS PAGE ====================
local function BuildVisualsPage()
    local visualsCard, visualsContent = CreateSectionCard(ContentScroll, "Visuals", 1)
    CreateToggle(visualsContent, "ESP Players", false)
    CreateToggle(visualsContent, "ESP Items", false)
    CreateToggle(visualsContent, "ESP Fruits", false)
    CreateToggle(visualsContent, "Full Bright", false)
    CreateSlider(visualsContent, "Brightness", 0, 10, 5)
    CreateToggle(visualsContent, "No Fog", false)
    CreateToggle(visualsContent, "No Shadows", false)
end

-- ==================== TELEPORT PAGE ====================
local function BuildTeleportPage()
    local tpCard, tpContent = CreateSectionCard(ContentScroll, "Teleport", 1)
    CreateActionButton(tpContent, "Teleport to Shop", false)
    CreateActionButton(tpContent, "Teleport to Farm", false)
    CreateActionButton(tpContent, "Teleport to Spawn", false)
    CreateActionButton(tpContent, "Save Current Position", false)
    CreateActionButton(tpContent, "Load Saved Position", false)
    CreateSlider(tpContent, "Teleport Delay", 0, 5, 0)
end

-- ==================== SETTINGS PAGE ====================
local function BuildSettingsPage()
    local settingsCard, settingsContent = CreateSectionCard(ContentScroll, "Settings", 1)
    CreateToggle(settingsContent, "Auto Save Config", true)
    CreateToggle(settingsContent, "Minimize to Tray", false)
    CreateToggle(settingsContent, "Show Notifications", true)
    CreateToggle(settingsContent, "Dark Mode", true)
    CreateActionButton(settingsContent, "Reset All Settings", false)
    CreateActionButton(settingsContent, "Export Config", true)
    CreateActionButton(settingsContent, "Import Config", true)
end

-- Build all pages (stacked, visibility toggled)
BuildPlayerPage()
BuildFarmPage()
BuildShopPage()
BuildUtilityPage()
BuildVisualsPage()
BuildTeleportPage()
BuildSettingsPage()

-- Window Dragging
local dragging = false
local dragStart = nil
local startPos = nil

TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- Close button with smooth animation
local originalSize = UDim2.new(0, 900, 0, 600)
CloseButton.MouseButton1Click:Connect(function()
    Tween(MainFrame, {Size = UDim2.new(0, 900, 0, 0)}, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    task.wait(0.35)
    ScreenGui.Enabled = false
    MainFrame.Size = originalSize
end)

-- Minimize button with smooth animation
local minimized = false
MinimizeButton.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        Tween(MainFrame, {Size = UDim2.new(0, 900, 0, 50)}, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        task.delay(0.2, function()
            Sidebar.Visible = false
            ContentArea.Visible = false
        end)
    else
        Sidebar.Visible = true
        ContentArea.Visible = true
        Tween(MainFrame, {Size = originalSize}, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end
end)

-- Toggle GUI with Insert key (works for both open and close)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.Insert then
        if ScreenGui.Enabled then
            Tween(MainFrame, {Size = UDim2.new(0, 900, 0, 0)}, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            task.wait(0.3)
            ScreenGui.Enabled = false
            MainFrame.Size = originalSize
        else
            ScreenGui.Enabled = true
            MainFrame.Size = UDim2.new(0, 900, 0, 0)
            Tween(MainFrame, {Size = originalSize}, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        end
    end
end)

-- ==================== REALTIME LOADING SCREEN ====================
local loadingSteps = {
    {text = "Initializing core...", duration = 0.4},
    {text = "Loading player data...", duration = 0.5},
    {text = "Building UI components...", duration = 0.6},
    {text = "Setting up sidebar...", duration = 0.4},
    {text = "Loading player page...", duration = 0.3},
    {text = "Loading farm page...", duration = 0.3},
    {text = "Loading shop page...", duration = 0.3},
    {text = "Loading utility page...", duration = 0.3},
    {text = "Loading visuals page...", duration = 0.3},
    {text = "Loading teleport page...", duration = 0.3},
    {text = "Loading settings page...", duration = 0.3},
    {text = "Finalizing...", duration = 0.4},
}

local totalDuration = 0
for _, step in ipairs(loadingSteps) do
    totalDuration = totalDuration + step.duration
end

local currentTime = 0
local connection

connection = RunService.Heartbeat:Connect(function(dt)
    currentTime = currentTime + dt
    local progress = math.clamp(currentTime / totalDuration, 0, 1)
    local percent = math.floor(progress * 100)
    
    -- Update bar
    Tween(LoadingBarFill, {Size = UDim2.new(progress, 0, 1, 0)}, 0.05)
    LoadingPercent.Text = percent .. "%"
    
    -- Update status text based on current step
    local accumulated = 0
    for _, step in ipairs(loadingSteps) do
        accumulated = accumulated + step.duration
        if currentTime <= accumulated then
            LoadingStatus.Text = step.text
            break
        end
    end
    
    if progress >= 1 then
        connection:Disconnect()
        LoadingStatus.Text = "Done!"
        task.wait(0.3)
        
        -- Fade out loading screen
        Tween(LoadingContainer, {BackgroundTransparency = 1}, 0.4)
        Tween(LoadingTitle, {TextTransparency = 1}, 0.4)
        Tween(LoadingSubtitle, {TextTransparency = 1}, 0.4)
        Tween(LoadingBarBg, {BackgroundTransparency = 1}, 0.4)
        Tween(LoadingBarFill, {BackgroundTransparency = 1}, 0.4)
        Tween(LoadingPercent, {TextTransparency = 1}, 0.4)
        Tween(LoadingStatus, {TextTransparency = 1}, 0.4)
        Tween(LoadingScreen, {BackgroundTransparency = 1}, 0.5)
        
        task.wait(0.5)
        LoadingScreen:Destroy()
        
        -- Show main GUI
        MainFrame.Visible = true
        MainFrame.Size = UDim2.new(0, 900, 0, 0)
        Tween(MainFrame, {Size = originalSize}, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        
        -- Print green console messages (using RichText for output window)
        print("[Miracle Hub] GUI Loaded Successfully for player: " .. (player.DisplayName ~= "" and player.DisplayName or player.Name))
        print("[Miracle Hub] Press Insert to toggle the GUI")
    end
end)
