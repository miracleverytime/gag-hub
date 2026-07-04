-- ======================================================================
-- Miracle Hub — ui.lua
-- UI framework module. Loaded SECOND (after core).
--
-- Provides on ctx:
--   ctx.UI          — component builders + Create helpers + Notify
--   ctx.ScreenGui, ctx.MainFrame, ctx.ContentScroll, ctx.LoadingScreen, ...
--   ctx.Pages       — table of pageName -> builder function (filled by pages.lua)
--   ctx.registerPage(name, builderFn)
--   ctx.SetActivePage(name)
--   ctx.GetActivePage()  / ctx.ActivePage is kept in sync via getter
--   ctx.SidebarButtons, ctx.sidebarButtonRefs (for bootstrap wiring)
-- ======================================================================

return function(ctx)
    local Colors             = ctx.Colors
    local States             = ctx.States
    local playerGui          = ctx.playerGui
    local player             = ctx.player
    local TweenService       = ctx.TweenService
    local UserInputService   = ctx.UserInputService

    local UI = {}

    -- ====================== BASIC CREATE HELPERS ======================
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

    UI.Create           = Create
    UI.CreateCorner     = CreateCorner
    UI.CreateStroke     = CreateStroke
    UI.CreatePadding    = CreatePadding
    UI.CreateListLayout = CreateListLayout
    UI.Tween            = Tween

    -- ====================== NOTIFICATION SYSTEM ======================
    local notifCount = 0
    local function Notify(title, message, color, duration)
        if not States.showNotifications then return end
        duration = duration or 4
        notifCount = notifCount + 1
        local yOffset = (notifCount - 1) * 72

        local notifFrame = Create("Frame", {
            Parent = playerGui:FindFirstChild("MiracleHub"),
            Size = UDim2.new(0, 280, 0, 60),
            Position = UDim2.new(1, -290, 0, 16 + yOffset),
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

        local closeBtn = Create("TextButton", {
            Parent = notifFrame,
            Size = UDim2.new(0, 20, 0, 20),
            Position = UDim2.new(1, -26, 0, 6),
            BackgroundTransparency = 1,
            Text = "\195\151",
            TextColor3 = Colors.TextMuted,
            TextSize = 15,
            Font = Enum.Font.GothamBold,
            BorderSizePixel = 0,
            ZIndex = 202,
            AutoButtonColor = false,
        })

        notifFrame.Position = UDim2.new(1, 10, 0, 16 + yOffset)
        Tween(notifFrame, {Position = UDim2.new(1, -290, 0, 16 + yOffset)}, 0.3, Enum.EasingStyle.Back)

        local dismissed = false
        local function DismissNotif()
            if dismissed then return end
            dismissed = true
            Tween(notifFrame, {Position = UDim2.new(1, 10, 0, 16 + yOffset)}, 0.3)
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

        Create("Frame", {
            Parent = notifFrame,
            Size = UDim2.new(0, 3, 1, 0),
            BackgroundColor3 = color or Colors.Success,
            BorderSizePixel = 0,
            ZIndex = 201,
        })

        Create("TextLabel", {
            Parent = notifFrame,
            Size = UDim2.new(1, -50, 0, 22),
            Position = UDim2.new(0, 12, 0, 7),
            BackgroundTransparency = 1,
            Text = title or ("\240\159\140\177 Stok Ada (" .. #available .. " seed)"),
            TextColor3 = Colors.TextPrimary,
            TextSize = 13,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 201,
        })

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

        Create("Frame", {
            Parent = notifFrame,
            Size = UDim2.new(1, -18, 0, 1),
            Position = UDim2.new(0, 9, 0, 31),
            BackgroundColor3 = Colors.Border,
            BorderSizePixel = 0,
            ZIndex = 201,
        })

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
                Text = "\226\128\162 " .. entry,
                TextColor3 = Colors.TextSecondary,
                TextSize = 11,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 202,
            })
        end

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
        if mutation == "Gold"       then return Colors.Gold
        elseif mutation == "Electric"   then return Colors.Electric
        elseif mutation == "Rainbow"    then return Colors.Rainbow
        elseif mutation == "Frozen"     then return Colors.Frozen
        elseif mutation == "Bloodlit"   then return Colors.Bloodlit   or Color3.fromRGB(220, 40,  40)
        elseif mutation == "Starstruck" then return Colors.Starstruck or Color3.fromRGB(255, 230, 80)
        elseif mutation == "Aurora"     then return Colors.Aurora     or Color3.fromRGB(80,  255, 200)
        else return Colors.TextMuted end
    end

    UI.Notify          = Notify
    UI.NotifyStok      = NotifyStok
    UI.GetMutationColor = GetMutationColor

    -- ====================== MAIN GUI SHELL ======================
    local ScreenGui = Create("ScreenGui", {
        Name = "MiracleHub",
        Parent = playerGui,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    ctx.ScreenGui = ScreenGui

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
    Create("TextLabel", {Parent=LoadingContainer, Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,0,0,52), BackgroundTransparency=1, Text="Grow A Garden 2  \226\128\162  Full Feature Build", TextColor3=Colors.TextMuted, TextSize=13, Font=Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=102})
    local LoadingBarBg = Create("Frame", {Parent=LoadingContainer, Size=UDim2.new(1,-60,0,8), Position=UDim2.new(0,30,0,92), BackgroundColor3=Colors.BackgroundLighter, BorderSizePixel=0, ZIndex=102})
    CreateCorner(LoadingBarBg, 4)
    local LoadingBarFill = Create("Frame", {Parent=LoadingBarBg, Size=UDim2.new(0,0,1,0), BackgroundColor3=Colors.Success, BorderSizePixel=0, ZIndex=103})
    CreateCorner(LoadingBarFill, 4)
    local LoadingPercent = Create("TextLabel", {Parent=LoadingContainer, Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,0,0,112), BackgroundTransparency=1, Text="0%", TextColor3=Colors.Success, TextSize=14, Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=102})
    local LoadingStatus = Create("TextLabel", {Parent=LoadingContainer, Size=UDim2.new(1,0,0,18), Position=UDim2.new(0,0,0,138), BackgroundTransparency=1, Text="Initializing...", TextColor3=Colors.TextMuted, TextSize=12, Font=Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=102})

    ctx.LoadingScreen    = LoadingScreen
    ctx.LoadingContainer = LoadingContainer
    ctx.LoadingBarFill   = LoadingBarFill
    ctx.LoadingPercent   = LoadingPercent
    ctx.LoadingStatus    = LoadingStatus

    -- Main Frame
    local originalSize = UDim2.new(0, 900, 0, 600)
    local MainFrame = Create("Frame", {
        Name = "MainFrame",
        Parent = ScreenGui,
        Size = originalSize,
        Position = UDim2.new(0.5, -450, 0.5, -300),
        BackgroundColor3 = Colors.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
    })
    CreateCorner(MainFrame, 16)
    ctx.MainFrame    = MainFrame
    ctx.originalSize = originalSize

    -- Top Bar
    local TopBar = Create("Frame", {
        Name = "TopBar",
        Parent = MainFrame,
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundColor3 = Colors.BackgroundLight,
        BorderSizePixel = 0,
    })
    CreateCorner(TopBar, 0)
    ctx.TopBar = TopBar

    for i, xpos in ipairs({0, 16, 32}) do
        local dot = Create("Frame", {
            Parent = TopBar,
            Size = UDim2.new(0, 10, 0, 10),
            Position = UDim2.new(0, 16 + xpos, 0.5, -5),
            BackgroundColor3 = Colors.TextPrimary,
            BorderSizePixel = 0,
        })
        CreateCorner(dot, 5)
    end

    local SearchBar = Create("Frame", {
        Parent = TopBar,
        Size = UDim2.new(0, 280, 0, 34),
        Position = UDim2.new(0, 120, 0.5, -17),
        BackgroundColor3 = Colors.Background,
        BorderSizePixel = 0,
    })
    CreateCorner(SearchBar, 8)
    CreateStroke(SearchBar, Colors.Border, 1)
    Create("TextLabel", {Parent=SearchBar, Size=UDim2.new(0,30,1,0), BackgroundTransparency=1, Text="\240\159\148\141", TextColor3=Colors.TextMuted, TextSize=14, Font=Enum.Font.Gotham})
    local SearchBox = Create("TextBox", {
        Parent = SearchBar,
        Size = UDim2.new(1,-40,1,0),
        Position = UDim2.new(0,30,0,0),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = "Search features...",
        PlaceholderColor3 = Colors.TextMuted,
        TextColor3 = Colors.TextPrimary,
        TextSize = 14,
        Font = Enum.Font.Gotham,
        ClearTextOnFocus = false,
    })
    ctx.SearchBox = SearchBox

    local PageTitle = Create("TextLabel", {
        Parent = TopBar,
        Size = UDim2.new(0, 200, 1, 0),
        Position = UDim2.new(0.5, -100, 0, 0),
        BackgroundTransparency = 1,
        Text = "Farm",
        TextColor3 = Colors.TextPrimary,
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    ctx.PageTitle = PageTitle

    local RightControls = Create("Frame", {
        Parent = TopBar,
        Size = UDim2.new(0, 80, 1, 0),
        Position = UDim2.new(1, -80, 0, 0),
        BackgroundTransparency = 1,
    })

    local CloseButton = Create("TextButton", {
        Parent = RightControls,
        Size = UDim2.new(0, 32, 0, 32),
        Position = UDim2.new(0, 44, 0.5, -16),
        BackgroundColor3 = Colors.Surface,
        Text = "\195\151",
        TextColor3 = Colors.TextSecondary,
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
        AutoButtonColor = false,
    })
    CreateCorner(CloseButton, 6)
    ctx.CloseButton = CloseButton

    local MinimizeButton = Create("TextButton", {
        Parent = RightControls,
        Size = UDim2.new(0, 32, 0, 32),
        Position = UDim2.new(0, 8, 0.5, -16),
        BackgroundColor3 = Colors.Surface,
        Text = "\226\136\146",
        TextColor3 = Colors.TextSecondary,
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
        AutoButtonColor = false,
    })
    CreateCorner(MinimizeButton, 6)
    ctx.MinimizeButton = MinimizeButton

    CloseButton.MouseEnter:Connect(function() Tween(CloseButton, {BackgroundColor3 = Color3.fromRGB(180, 80, 80), TextColor3 = Colors.TextPrimary}, 0.2) end)
    CloseButton.MouseLeave:Connect(function() Tween(CloseButton, {BackgroundColor3 = Colors.Surface, TextColor3 = Colors.TextSecondary}, 0.2) end)
    MinimizeButton.MouseEnter:Connect(function() Tween(MinimizeButton, {BackgroundColor3 = Colors.SurfaceLight, TextColor3 = Colors.TextPrimary}, 0.2) end)
    MinimizeButton.MouseLeave:Connect(function() Tween(MinimizeButton, {BackgroundColor3 = Colors.Surface, TextColor3 = Colors.TextSecondary}, 0.2) end)

    -- Sidebar
    local Sidebar = Create("Frame", {
        Parent = MainFrame,
        Size = UDim2.new(0, 240, 1, -50),
        Position = UDim2.new(0, 0, 0, 50),
        BackgroundColor3 = Colors.BackgroundLight,
        BorderSizePixel = 0,
    })
    ctx.Sidebar = Sidebar

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
    Create("TextLabel", {Parent=HubCard, Size=UDim2.new(1,0,0,16), Position=UDim2.new(0,0,0,24), BackgroundTransparency=1, Text="Grow A Garden 2", TextColor3=Colors.TextMuted, TextSize=11, Font=Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Left})

    local SidebarButtons = {}
    ctx.SidebarButtons = SidebarButtons
    local ActivePage = "Farm"
    ctx.GetActivePage = function() return ActivePage end

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

    -- Build sidebar buttons; store refs on ctx for bootstrap wiring
    local sb = {}
    CreateSectionHeader(SidebarContent, "AUTOMATION", 1)
    sb.Farm     = CreateSidebarButton(SidebarContent, "\240\159\140\177", "Farm", 2)
    sb.Plot     = CreateSidebarButton(SidebarContent, "\240\159\147\144", "Plot", 3)
    sb.Shop     = CreateSidebarButton(SidebarContent, "\240\159\155\146", "Shop", 4)
    sb.Sell     = CreateSidebarButton(SidebarContent, "\240\159\146\176", "Sell", 5)
    sb.Pets     = CreateSidebarButton(SidebarContent, "\240\159\144\190", "Pets", 6)
    sb.Eggs     = CreateSidebarButton(SidebarContent, "\240\159\165\154", "Eggs", 7)

    CreateSectionHeader(SidebarContent, "PLAYER", 8)
    sb.Player   = CreateSidebarButton(SidebarContent, "\240\159\145\164", "Player", 9)
    sb.Visuals  = CreateSidebarButton(SidebarContent, "\240\159\145\129", "Visuals", 10)
    sb.Teleport = CreateSidebarButton(SidebarContent, "\240\159\147\141", "Teleport", 11)

    CreateSectionHeader(SidebarContent, "MISC", 12)
    sb.Utility  = CreateSidebarButton(SidebarContent, "\240\159\148\167", "Utility", 13)
    sb.Mailer   = CreateSidebarButton(SidebarContent, "\226\156\137", "Mailer", 14)
    sb.Info     = CreateSidebarButton(SidebarContent, "\226\132\185", "Info", 15)
    sb.Server   = CreateSidebarButton(SidebarContent, "\240\159\140\144", "Server", 16)
    sb.Settings = CreateSidebarButton(SidebarContent, "\226\154\153", "Settings", 17)
    ctx.sidebarButtonRefs = sb

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
    local PrimeLabel = Create("TextLabel", {Parent=ProfileCard, Size=UDim2.new(0,50,0,16), Position=UDim2.new(0,62,0,46), BackgroundTransparency=1, Text="\226\173\144 Prime", TextColor3=Colors.Warning, TextSize=10, Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left})
    if player:GetAttribute("PrimeEnabled") then
        PrimeLabel.Text = "\226\173\144 Prime"
        PrimeLabel.TextColor3 = Colors.Warning
    else
        PrimeLabel.Text = "Free"
        PrimeLabel.TextColor3 = Colors.TextMuted
    end

    -- Content Area
    local ContentArea = Create("Frame", {
        Parent = MainFrame,
        Size = UDim2.new(1, -240, 1, -50),
        Position = UDim2.new(0, 240, 0, 50),
        BackgroundColor3 = Colors.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    })
    ctx.ContentArea = ContentArea

    local ContentScroll = Create("ScrollingFrame", {
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
    CreateListLayout(ContentScroll, 14)
    ctx.ContentScroll = ContentScroll

    -- ====================== PAGE SYSTEM ======================
    local Pages = {}
    ctx.Pages = Pages

    -- SaveState: no-op. Config persist dihapus;
    -- state sudah hidup di ctx.States selama sesi berjalan.
    local function SaveState(key, value) end
    ctx.SaveState = SaveState

    -- Cache collapsed/expanded state tiap section card per page.
    -- Variabel lokal — state tetap tersimpan selama GUI tidak di-destroy.
    -- Key: pageName .. "|"… cardTitle — boolean (true = collapsed)
    local _cardStates = {}

    local function ClearContent()
        for _, child in ipairs(ContentScroll:GetChildren()) do
            if child:IsA("GuiObject") and child.Name ~= "UIPadding" and child.Name ~= "UIListLayout" then
                child:Destroy()
            end
        end
    end
    ctx.ClearContent = ClearContent

    local function SetActivePage(pageName)
        if SidebarButtons[ActivePage] then
            local s = SidebarButtons[ActivePage]
            s.indicator.Visible = false
            Tween(s.button, {BackgroundTransparency = 1}, 0.15)
            s.label.TextColor3 = Colors.TextSecondary
            s.icon.TextColor3 = Colors.TextSecondary
            s.button.BackgroundColor3 = Colors.Surface
        end

        ActivePage = pageName
        PageTitle.Text = pageName

        if SidebarButtons[pageName] then
            local s = SidebarButtons[pageName]
            s.indicator.Visible = true
            s.button.BackgroundColor3 = Colors.BackgroundLighter
            Tween(s.button, {BackgroundTransparency = 0}, 0.15)
            s.label.TextColor3 = Colors.TextPrimary
            s.label.Font = Enum.Font.GothamBold
            s.icon.TextColor3 = Colors.TextPrimary
        end

        ClearContent()
        if Pages[pageName] then Pages[pageName]() end
        ContentScroll.CanvasPosition = Vector2.new(0, 0)
    end
    ctx.SetActivePage = SetActivePage

    local function registerPage(name, builderFn)
        Pages[name] = builderFn
    end
    ctx.registerPage = registerPage

    -- ====================== UI COMPONENT BUILDERS ======================

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
        CreateListLayout(card, 12)

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
            Text = "\226\150\188",
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

        -- Baca state card dari cache; default collapsed jika belum pernah di-set
        local cardKey = ActivePage .. "|" .. title
        local collapsed = (_cardStates[cardKey] ~= false)  -- true jika nil (default collapsed) atau true
        content.Visible = not collapsed
        dropBtn.Rotation = collapsed and -90 or 0

        dropBtn.MouseButton1Click:Connect(function()
            collapsed = not collapsed
            _cardStates[cardKey] = collapsed  -- simpan state
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
        local container = Create("Frame", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, description and 54 or 36),
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
            SaveState(stateKey, state)
            Tween(toggleBg, {BackgroundColor3 = state and Colors.ToggleOn or Colors.ToggleOff}, 0.2)
            Tween(knob, {Position = UDim2.new(0, state and 25 or 3, 0.5, -10)}, 0.2)
            if onToggle then
                onToggle(state, function()
                    state = false
                    States[stateKey] = false
                    SaveState(stateKey, false)
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
        local function updateSlider(x, save)
            local trackAbsPos = track.AbsolutePosition.X
            local trackAbsSize = track.AbsoluteSize.X
            local pct = math.clamp((x - trackAbsPos) / math.max(trackAbsSize, 1), 0, 1)
            local val = math.floor(minVal + pct * (maxVal - minVal))
            States[stateKey] = val
            if save then SaveState(stateKey, val) end
            valLabel.Text = tostring(val) .. (suffix or "")
            if onChange then onChange(val) end
            Tween(fill, {Size = UDim2.new(pct, 0, 1, 0)}, 0.05)
            Tween(sliderKnob, {Position = UDim2.new(pct, -8, 0.5, -8)}, 0.05)
        end
        trackBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                updateSlider(input.Position.X, false)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                updateSlider(input.Position.X, false)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                if dragging then
                    -- Save hanya saat drag selesai, bukan setiap frame
                    SaveState(stateKey, States[stateKey])
                end
                dragging = false
            end
        end)
        return container
    end

    local function CreateActionButton(parent, text, callback, accentColor)
        local container = Create("Frame", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, 38),
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
        Create("TextLabel", {
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
        Create("TextLabel", {
            Parent = btn,
            Size = UDim2.new(0, 20, 1, 0),
            Position = UDim2.new(1, -26, 0, 0),
            BackgroundTransparency = 1,
            Text = "\226\128\186",
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
            Size = UDim2.new(1, 0, 0, 40),
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
            Text = label .. "  \226\128\162  " .. currentVal,
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
            Text = "\226\150\190",
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
                        SaveState(stateKey, opt)
                        lbl.Text = label .. "  \226\128\162  " .. opt
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

    -- Multi-select dropdown — inline expand, checkmark kiri
    local function CreateMultiSelect(parent, label, options, stateKey)
        if type(States[stateKey]) ~= "table" then States[stateKey] = {} end
        local selected = States[stateKey]

        local pillIcon = label:match("^([%z\1-\127\194-\244][\128-\191]*)") or "\226\128\162"
        local pillText = label:gsub("^[%z\1-\127\194-\244][\128-\191]*%s*", "")

        local function getShortText()
            if #selected == 0 then return pillText .. "  \226\128\162  (none selected)" end
            if #selected <= 2 then
                local names = {}
                for _, s in ipairs(selected) do names[#names+1] = s end
                return pillText .. "  \226\128\162  " .. table.concat(names, ", ")
            end
            return pillText .. "  \226\128\162  " .. #selected .. " selected"
        end

        local wrapper = Create("Frame", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
        })
        CreateListLayout(wrapper, 0)

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
            Text = "\226\128\186",
            TextColor3 = Colors.TextMuted,
            TextSize = 18,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        pill.MouseEnter:Connect(function() Tween(pill, {BackgroundColor3 = Colors.Surface}, 0.12) end)
        pill.MouseLeave:Connect(function() Tween(pill, {BackgroundColor3 = Colors.BackgroundLighter}, 0.12) end)

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

        local headerRow = Create("Frame", {
            Parent = panel,
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundColor3 = Colors.Background,
            BorderSizePixel = 0,
        })
        CreateCorner(headerRow, 9)
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
            Text = "\226\156\148 All",
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
            Text = "\226\156\151 Clear",
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

        local itemFrames = {}

        local function isSelected(opt)
            return table.find(selected, opt) ~= nil
        end

        local function updateRow(t)
            local sel = isSelected(t.opt)
            t.frame.BackgroundColor3 = sel and Colors.Surface or Colors.BackgroundLighter
            t.frame.BackgroundTransparency = sel and 0 or 1
            t.checkLbl.Text = sel and "\226\156\147" or ""
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
                Text = sel and "\226\156\147" or "",
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
                SaveState(stateKey, selected)
                updateRow(entry)
                updatePill()
            end)
        end

        selAllBtn.MouseButton1Click:Connect(function()
            table.clear(selected)
            for _, opt in ipairs(options) do table.insert(selected, opt) end
            States[stateKey] = selected
            SaveState(stateKey, selected)
            for _, t in ipairs(itemFrames) do updateRow(t) end
            updatePill()
        end)
        clearBtn.MouseButton1Click:Connect(function()
            table.clear(selected)
            States[stateKey] = selected
            SaveState(stateKey, selected)
            for _, t in ipairs(itemFrames) do updateRow(t) end
            updatePill()
        end)

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

    -- Expose component builders
    UI.CreateSectionHeader = CreateSectionHeader
    UI.CreateSectionCard   = CreateSectionCard
    UI.CreateSubHeader     = CreateSubHeader
    UI.CreateToggle        = CreateToggle
    UI.CreateSlider        = CreateSlider
    UI.CreateActionButton  = CreateActionButton
    UI.CreateDropdown      = CreateDropdown
    UI.CreateMultiSelect   = CreateMultiSelect
    UI.CreateInfoText      = CreateInfoText
    UI.CreateStatRow       = CreateStatRow

    ctx.UI = UI
    return ctx
end