-- ======================================================================
-- Miracle Hub — ui.lua  (REBUILT v2)
-- UI framework module. Loaded SECOND (after core).
--
-- Desain: dark theme, aksen hijau neon (#39FF14 style), topbar dengan
-- CONNECTED badge + FPS/MS monitor, sidebar clean dengan section headers,
-- komponen toggle, slider, dropdown, multi-select, action button, dll.
--
-- Provides on ctx:
--   ctx.UI          — component builders + Create helpers + Notify
--   ctx.ScreenGui, ctx.MainFrame, ctx.ContentScroll, ctx.LoadingScreen, ...
--   ctx.Pages       — table of pageName -> builder function (filled by pages.lua)
--   ctx.registerPage(name, builderFn)
--   ctx.SetActivePage(name)
--   ctx.GetActivePage()
--   ctx.SidebarButtons, ctx.sidebarButtonRefs (for bootstrap wiring)
-- ======================================================================

return function(ctx)
    local Colors           = ctx.Colors
    local States           = ctx.States
    local playerGui        = ctx.playerGui
    local player           = ctx.player
    local TweenService     = ctx.TweenService
    local UserInputService = ctx.UserInputService
    local RunService       = ctx.RunService

    -- Override Colors to match new design (neon green accent)
    Colors.Accent         = Color3.fromRGB(57, 255, 20)      -- neon green
    Colors.AccentHover    = Color3.fromRGB(80, 255, 50)
    Colors.AccentDim      = Color3.fromRGB(30, 120, 10)
    Colors.AccentText     = Color3.fromRGB(57, 255, 20)
    Colors.Background     = Color3.fromRGB(10, 10, 10)
    Colors.BackgroundLight  = Color3.fromRGB(16, 16, 16)
    Colors.BackgroundLighter = Color3.fromRGB(22, 22, 22)
    Colors.Surface        = Color3.fromRGB(32, 32, 32)
    Colors.SurfaceLight   = Color3.fromRGB(44, 44, 44)
    Colors.Border         = Color3.fromRGB(38, 38, 38)
    Colors.BorderLight    = Color3.fromRGB(55, 55, 55)
    Colors.TextPrimary    = Color3.fromRGB(240, 240, 240)
    Colors.TextSecondary  = Color3.fromRGB(160, 160, 160)
    Colors.TextMuted      = Color3.fromRGB(90, 90, 90)
    Colors.ToggleOn       = Color3.fromRGB(57, 255, 20)
    Colors.ToggleOnDark   = Color3.fromRGB(20, 80, 8)
    Colors.ToggleOff      = Color3.fromRGB(38, 38, 38)
    Colors.ToggleKnob     = Color3.fromRGB(255, 255, 255)
    Colors.SliderTrack    = Color3.fromRGB(30, 30, 30)
    Colors.SliderFill     = Color3.fromRGB(57, 255, 20)
    Colors.Success        = Color3.fromRGB(57, 255, 20)
    Colors.Error          = Color3.fromRGB(220, 60, 60)
    Colors.Warning        = Color3.fromRGB(255, 180, 30)
    Colors.Gold           = Color3.fromRGB(255, 215, 0)
    Colors.Electric       = Color3.fromRGB(80, 160, 255)
    Colors.Rainbow        = Color3.fromRGB(255, 100, 200)
    Colors.Frozen         = Color3.fromRGB(100, 210, 255)
    Colors.TopBar         = Color3.fromRGB(13, 13, 13)

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
        return Create("UIStroke", {
            Color = color or Colors.Border,
            Thickness = thickness or 1,
            Parent = parent,
        })
    end

    local function CreatePadding(parent, l, r, t, b)
        local p = l or 12
        return Create("UIPadding", {
            PaddingLeft   = UDim.new(0, l or p),
            PaddingRight  = UDim.new(0, r or p),
            PaddingTop    = UDim.new(0, t or p),
            PaddingBottom = UDim.new(0, b or p),
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
            TweenInfo.new(
                duration or 0.25,
                easingStyle or Enum.EasingStyle.Quart,
                easingDirection or Enum.EasingDirection.Out
            ),
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

    -- ====================== MUTATION COLOR HELPER ======================
    local function GetMutationColor(mutation)
        if mutation == "Gold"       then return Colors.Gold
        elseif mutation == "Electric"   then return Colors.Electric
        elseif mutation == "Rainbow"    then return Colors.Rainbow
        elseif mutation == "Frozen"     then return Colors.Frozen
        elseif mutation == "Bloodlit"   then return Colors.Bloodlit   or Color3.fromRGB(220, 40, 40)
        elseif mutation == "Starstruck" then return Colors.Starstruck or Color3.fromRGB(255, 230, 80)
        elseif mutation == "Aurora"     then return Colors.Aurora     or Color3.fromRGB(80, 255, 200)
        else return Colors.TextMuted end
    end
    UI.GetMutationColor = GetMutationColor

    -- ====================== NOTIFICATION SYSTEM ======================
    local notifCount = 0
    local function Notify(title, message, color, duration)
        if not States.showNotifications then return end
        duration = duration or 4
        notifCount = notifCount + 1
        local yOffset = (notifCount - 1) * 76

        local notifFrame = Create("Frame", {
            Parent = playerGui:FindFirstChild("MiracleHub"),
            Size = UDim2.new(0, 300, 0, 64),
            Position = UDim2.new(1, 10, 0, 16 + yOffset),
            BackgroundColor3 = Colors.BackgroundLight,
            BorderSizePixel = 0,
            ZIndex = 200,
        })
        CreateCorner(notifFrame, 10)
        CreateStroke(notifFrame, color or Colors.Border, 1)

        -- Accent left bar
        local bar = Create("Frame", {
            Parent = notifFrame,
            Size = UDim2.new(0, 3, 1, -16),
            Position = UDim2.new(0, 0, 0, 8),
            BackgroundColor3 = color or Colors.Success,
            BorderSizePixel = 0,
            ZIndex = 201,
        })
        CreateCorner(bar, 2)

        Create("TextLabel", {
            Parent = notifFrame,
            Size = UDim2.new(1, -52, 0, 20),
            Position = UDim2.new(0, 14, 0, 10),
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
            Size = UDim2.new(1, -24, 0, 18),
            Position = UDim2.new(0, 14, 0, 32),
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
            Size = UDim2.new(0, 22, 0, 22),
            Position = UDim2.new(1, -28, 0, 8),
            BackgroundColor3 = Colors.Surface,
            Text = "\195\151",
            TextColor3 = Colors.TextMuted,
            TextSize = 13,
            Font = Enum.Font.GothamBold,
            BorderSizePixel = 0,
            ZIndex = 202,
            AutoButtonColor = false,
        })
        CreateCorner(closeBtn, 5)

        -- Slide in
        Tween(notifFrame, {Position = UDim2.new(1, -310, 0, 16 + yOffset)}, 0.3, Enum.EasingStyle.Back)

        local dismissed = false
        local function Dismiss()
            if dismissed then return end
            dismissed = true
            Tween(notifFrame, {Position = UDim2.new(1, 10, 0, 16 + yOffset)}, 0.25)
            task.wait(0.3)
            if notifFrame and notifFrame.Parent then notifFrame:Destroy() end
            notifCount = math.max(0, notifCount - 1)
        end

        closeBtn.MouseButton1Click:Connect(Dismiss)
        task.delay(duration, Dismiss)
    end

    -- Stock notification (scrollable list)
    local _stockNotif = nil
    local function NotifyStok(available, color, duration, title)
        if not States.showNotifications then return end
        duration = duration or 30
        if _stockNotif and _stockNotif.Parent then
            _stockNotif:Destroy()
            _stockNotif = nil
        end

        local lineH      = 22
        local headerH    = 40
        local maxVisible = 8
        local visCount   = math.min(#available, maxVisible)
        local totalH     = headerH + visCount * lineH + 12

        local notifFrame = Create("Frame", {
            Parent = playerGui:FindFirstChild("MiracleHub"),
            Size = UDim2.new(0, 300, 0, totalH),
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
            Size = UDim2.new(0, 3, 1, -16),
            Position = UDim2.new(0, 0, 0, 8),
            BackgroundColor3 = color or Colors.Success,
            BorderSizePixel = 0,
            ZIndex = 201,
        })

        Create("TextLabel", {
            Parent = notifFrame,
            Size = UDim2.new(1, -52, 0, 22),
            Position = UDim2.new(0, 14, 0, 9),
            BackgroundTransparency = 1,
            Text = title or ("\226\156\148 Stock Available (" .. #available .. ")"),
            TextColor3 = Colors.TextPrimary,
            TextSize = 13,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 201,
        })

        local closeBtn = Create("TextButton", {
            Parent = notifFrame,
            Size = UDim2.new(0, 22, 0, 22),
            Position = UDim2.new(1, -28, 0, 9),
            BackgroundColor3 = Colors.Surface,
            Text = "\195\151",
            TextColor3 = Colors.TextMuted,
            TextSize = 13,
            Font = Enum.Font.GothamBold,
            BorderSizePixel = 0,
            ZIndex = 202,
            AutoButtonColor = false,
        })
        CreateCorner(closeBtn, 5)

        Create("Frame", {
            Parent = notifFrame,
            Size = UDim2.new(1, -28, 0, 1),
            Position = UDim2.new(0, 14, 0, 33),
            BackgroundColor3 = Colors.Border,
            BorderSizePixel = 0,
            ZIndex = 201,
        })

        local scrollFrame = Create("ScrollingFrame", {
            Parent = notifFrame,
            Size = UDim2.new(1, -28, 0, visCount * lineH),
            Position = UDim2.new(0, 14, 0, headerH),
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
                Text = "\226\128\162  " .. entry,
                TextColor3 = Colors.TextSecondary,
                TextSize = 11,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 202,
            })
        end

        Tween(notifFrame, {Position = UDim2.new(1, -310, 0, 16)}, 0.3, Enum.EasingStyle.Back)

        local dismissed = false
        local function DismissStok()
            if dismissed then return end
            dismissed = true
            Tween(notifFrame, {Position = UDim2.new(1, 10, 0, 16)}, 0.25)
            task.wait(0.3)
            if notifFrame and notifFrame.Parent then notifFrame:Destroy() end
            _stockNotif = nil
        end

        closeBtn.MouseButton1Click:Connect(DismissStok)
        task.delay(duration, DismissStok)
    end

    UI.Notify     = Notify
    UI.NotifyStok = NotifyStok

    -- ====================== MAIN SCREEN GUI ======================
    local ScreenGui = Create("ScreenGui", {
        Name = "MiracleHub",
        Parent = playerGui,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    ctx.ScreenGui = ScreenGui

    -- ====================== LOADING SCREEN ======================
    local LoadingScreen = Create("Frame", {
        Name = "LoadingScreen",
        Parent = ScreenGui,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.3,
        ZIndex = 100,
    })

    local LoadingContainer = Create("Frame", {
        Parent = LoadingScreen,
        Size = UDim2.new(0, 420, 0, 175),
        Position = UDim2.new(0.5, -210, 0.5, -87),
        BackgroundColor3 = Colors.BackgroundLight,
        BorderSizePixel = 0,
        ZIndex = 101,
    })
    CreateCorner(LoadingContainer, 16)
    CreateStroke(LoadingContainer, Colors.Border, 1)

    -- Logo title
    local loadLogoFrame = Create("Frame", {
        Parent = LoadingContainer,
        Size = UDim2.new(1, 0, 0, 32),
        Position = UDim2.new(0, 0, 0, 22),
        BackgroundTransparency = 1,
        ZIndex = 102,
    })
    Create("TextLabel", {
        Parent = loadLogoFrame,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "MIRACLE",
        TextColor3 = Colors.TextPrimary,
        TextSize = 22,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 102,
    })
    Create("TextLabel", {
        Parent = LoadingContainer,
        Size = UDim2.new(1, 0, 0, 18),
        Position = UDim2.new(0, 0, 0, 56),
        BackgroundTransparency = 1,
        Text = "Grow A Garden 2  \226\128\162  Full Feature Build",
        TextColor3 = Colors.TextMuted,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 102,
    })

    -- Progress bar background
    local LoadingBarBg = Create("Frame", {
        Parent = LoadingContainer,
        Size = UDim2.new(1, -60, 0, 6),
        Position = UDim2.new(0, 30, 0, 90),
        BackgroundColor3 = Colors.Surface,
        BorderSizePixel = 0,
        ZIndex = 102,
    })
    CreateCorner(LoadingBarBg, 3)

    local LoadingBarFill = Create("Frame", {
        Parent = LoadingBarBg,
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Colors.Success,
        BorderSizePixel = 0,
        ZIndex = 103,
    })
    CreateCorner(LoadingBarFill, 3)

    -- Glow on fill
    Create("UIGradient", {
        Parent = LoadingBarFill,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 160, 10)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(57, 255, 20)),
        }),
        Rotation = 90,
    })

    local LoadingPercent = Create("TextLabel", {
        Parent = LoadingContainer,
        Size = UDim2.new(1, 0, 0, 20),
        Position = UDim2.new(0, 0, 0, 108),
        BackgroundTransparency = 1,
        Text = "0%",
        TextColor3 = Colors.Success,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 102,
    })

    local LoadingStatus = Create("TextLabel", {
        Parent = LoadingContainer,
        Size = UDim2.new(1, 0, 0, 16),
        Position = UDim2.new(0, 0, 0, 146),
        BackgroundTransparency = 1,
        Text = "Initializing...",
        TextColor3 = Colors.TextMuted,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 102,
    })

    ctx.LoadingScreen    = LoadingScreen
    ctx.LoadingContainer = LoadingContainer
    ctx.LoadingBarFill   = LoadingBarFill
    ctx.LoadingPercent   = LoadingPercent
    ctx.LoadingStatus    = LoadingStatus

    -- ====================== MAIN FRAME ======================
    local originalSize = UDim2.new(0, 960, 0, 620)
    local MainFrame = Create("Frame", {
        Name = "MainFrame",
        Parent = ScreenGui,
        Size = originalSize,
        Position = UDim2.new(0.5, -480, 0.5, -310),
        BackgroundColor3 = Colors.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
    })
    CreateCorner(MainFrame, 12)
    CreateStroke(MainFrame, Colors.Border, 1)
    ctx.MainFrame    = MainFrame
    ctx.originalSize = originalSize

    -- ====================== TOP BAR ======================
    local TopBar = Create("Frame", {
        Name = "TopBar",
        Parent = MainFrame,
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = Colors.TopBar,
        BorderSizePixel = 0,
        ZIndex = 2,
    })
    ctx.TopBar = TopBar

    -- Bottom separator
    Create("Frame", {
        Parent = TopBar,
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = Colors.Border,
        BorderSizePixel = 0,
        ZIndex = 3,
    })

    -- CONNECTED indicator (left)
    local ConnectedDot = Create("Frame", {
        Parent = TopBar,
        Size = UDim2.new(0, 8, 0, 8),
        Position = UDim2.new(0, 16, 0.5, -4),
        BackgroundColor3 = Colors.Success,
        BorderSizePixel = 0,
        ZIndex = 3,
    })
    CreateCorner(ConnectedDot, 4)

    Create("TextLabel", {
        Parent = TopBar,
        Size = UDim2.new(0, 110, 1, 0),
        Position = UDim2.new(0, 30, 0, 0),
        BackgroundTransparency = 1,
        Text = "CONNECTED",
        TextColor3 = Colors.Success,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
    })

    -- Center logo
    local LogoFrame = Create("Frame", {
        Parent = TopBar,
        Size = UDim2.new(0, 160, 0, 32),
        Position = UDim2.new(0.5, -80, 0.5, -16),
        BackgroundColor3 = Colors.BackgroundLighter,
        BorderSizePixel = 0,
        ZIndex = 3,
    })
    CreateCorner(LogoFrame, 8)
    CreateStroke(LogoFrame, Colors.Border, 1)

    Create("TextLabel", {
        Parent = LogoFrame,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        RichText = true,
        Text = "<b><font color=\"#F0F0F0\">MIRACLE</font><font color=\"#39FF14\">HUB</font></b>",
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 4,
    })

    -- FPS counter (center right of logo)
    local FpsFrame = Create("Frame", {
        Parent = TopBar,
        Size = UDim2.new(0, 100, 0, 32),
        Position = UDim2.new(0.5, 90, 0.5, -16),
        BackgroundColor3 = Colors.BackgroundLighter,
        BorderSizePixel = 0,
        ZIndex = 3,
    })
    CreateCorner(FpsFrame, 8)
    CreateStroke(FpsFrame, Colors.Border, 1)

    Create("TextLabel", {
        Parent = FpsFrame,
        Size = UDim2.new(0, 18, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = "\240\159\148\136",
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextColor3 = Colors.Success,
        ZIndex = 4,
    })

    local FpsLabel = Create("TextLabel", {
        Parent = FpsFrame,
        Size = UDim2.new(1, -50, 1, 0),
        Position = UDim2.new(0, 30, 0, 0),
        BackgroundTransparency = 1,
        Text = "FPS  --",
        TextColor3 = Colors.TextPrimary,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    })
    ctx.FpsLabel = FpsLabel

    -- MS counter
    local MsFrame = Create("Frame", {
        Parent = TopBar,
        Size = UDim2.new(0, 100, 0, 32),
        Position = UDim2.new(0.5, 200, 0.5, -16),
        BackgroundColor3 = Colors.BackgroundLighter,
        BorderSizePixel = 0,
        ZIndex = 3,
    })
    CreateCorner(MsFrame, 8)
    CreateStroke(MsFrame, Colors.Border, 1)

    Create("TextLabel", {
        Parent = MsFrame,
        Size = UDim2.new(0, 18, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = "\240\159\146\171",
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextColor3 = Colors.Success,
        ZIndex = 4,
    })

    local MsLabel = Create("TextLabel", {
        Parent = MsFrame,
        Size = UDim2.new(1, -50, 1, 0),
        Position = UDim2.new(0, 30, 0, 0),
        BackgroundTransparency = 1,
        Text = "MS  --",
        TextColor3 = Colors.TextPrimary,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    })
    ctx.MsLabel = MsLabel

    -- FPS & MS updater loop
    task.spawn(function()
        local SESSION = ctx.SESSION
        local lastTime = tick()
        local frameCount = 0
        RunService.Heartbeat:Connect(function()
            if _G._MiracleHubSession ~= SESSION then return end
            frameCount += 1
            local now = tick()
            if now - lastTime >= 1 then
                local fps = math.floor(frameCount / (now - lastTime))
                FpsLabel.Text = "FPS  " .. fps
                lastTime = now
                frameCount = 0
            end
        end)
    end)

    task.spawn(function()
        local SESSION = ctx.SESSION
        while _G._MiracleHubSession == SESSION do
            local ok, ping = pcall(function()
                return ctx.Players.LocalPlayer:GetNetworkPing()
            end)
            if ok then
                MsLabel.Text = "MS  " .. math.floor(ping * 1000)
            end
            task.wait(2)
        end
    end)

    -- Close & Minimize buttons (right side)
    local CloseButton = Create("TextButton", {
        Parent = TopBar,
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -42, 0.5, -15),
        BackgroundColor3 = Colors.Surface,
        Text = "\195\151",
        TextColor3 = Colors.TextSecondary,
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        ZIndex = 3,
    })
    CreateCorner(CloseButton, 6)

    local MinimizeButton = Create("TextButton", {
        Parent = TopBar,
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -78, 0.5, -15),
        BackgroundColor3 = Colors.Surface,
        Text = "\226\136\146",
        TextColor3 = Colors.TextSecondary,
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        ZIndex = 3,
    })
    CreateCorner(MinimizeButton, 6)

    CloseButton.MouseEnter:Connect(function()
        Tween(CloseButton, {BackgroundColor3 = Colors.Error, TextColor3 = Colors.TextPrimary}, 0.15)
    end)
    CloseButton.MouseLeave:Connect(function()
        Tween(CloseButton, {BackgroundColor3 = Colors.Surface, TextColor3 = Colors.TextSecondary}, 0.15)
    end)
    MinimizeButton.MouseEnter:Connect(function()
        Tween(MinimizeButton, {BackgroundColor3 = Colors.SurfaceLight, TextColor3 = Colors.TextPrimary}, 0.15)
    end)
    MinimizeButton.MouseLeave:Connect(function()
        Tween(MinimizeButton, {BackgroundColor3 = Colors.Surface, TextColor3 = Colors.TextSecondary}, 0.15)
    end)

    ctx.CloseButton    = CloseButton
    ctx.MinimizeButton = MinimizeButton

    -- Drag support
    do
        local dragging, dragStart, startPos
        TopBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position
                startPos  = MainFrame.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - dragStart
                MainFrame.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
    end

    -- ====================== SIDEBAR ======================
    local Sidebar = Create("Frame", {
        Parent = MainFrame,
        Size = UDim2.new(0, 210, 1, -48),
        Position = UDim2.new(0, 0, 0, 48),
        BackgroundColor3 = Colors.BackgroundLight,
        BorderSizePixel = 0,
    })
    ctx.Sidebar = Sidebar

    -- Right border of sidebar
    Create("Frame", {
        Parent = Sidebar,
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, -1, 0, 0),
        BackgroundColor3 = Colors.Border,
        BorderSizePixel = 0,
    })

    -- Profile card at top of sidebar
    local ProfileCard = Create("Frame", {
        Parent = Sidebar,
        Size = UDim2.new(1, -24, 0, 60),
        Position = UDim2.new(0, 12, 0, 12),
        BackgroundColor3 = Colors.BackgroundLighter,
        BorderSizePixel = 0,
    })
    CreateCorner(ProfileCard, 10)
    CreateStroke(ProfileCard, Colors.Border, 1)

    local ProfileAvatar = Create("ImageLabel", {
        Parent = ProfileCard,
        Size = UDim2.new(0, 38, 0, 38),
        Position = UDim2.new(0, 10, 0.5, -19),
        BackgroundColor3 = Colors.Surface,
        Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150",
        BorderSizePixel = 0,
    })
    CreateCorner(ProfileAvatar, 19)

    local profileName = player.DisplayName or player.Name
    Create("TextLabel", {
        Parent = ProfileCard,
        Size = UDim2.new(1, -58, 0, 18),
        Position = UDim2.new(0, 56, 0, 10),
        BackgroundTransparency = 1,
        Text = profileName,
        TextColor3 = Colors.TextPrimary,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    -- Plan badge
    local isPrime = player:GetAttribute("PrimeEnabled")
    local PrimeBadge = Create("Frame", {
        Parent = ProfileCard,
        Size = UDim2.new(0, 60, 0, 18),
        Position = UDim2.new(0, 56, 0, 32),
        BackgroundColor3 = isPrime and Color3.fromRGB(40, 30, 0) or Colors.Surface,
        BorderSizePixel = 0,
    })
    CreateCorner(PrimeBadge, 5)
    CreateStroke(PrimeBadge, isPrime and Colors.Warning or Colors.Border, 1)
    Create("TextLabel", {
        Parent = PrimeBadge,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = isPrime and "\226\173\144 PRIME" or "FREE",
        TextColor3 = isPrime and Colors.Warning or Colors.TextMuted,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    -- Sidebar scroll (nav items)
    local SidebarContent = Create("ScrollingFrame", {
        Parent = Sidebar,
        Size = UDim2.new(1, 0, 1, -88),
        Position = UDim2.new(0, 0, 0, 84),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    })
    CreatePadding(SidebarContent, 10, 10, 6, 10)
    CreateListLayout(SidebarContent, 2)

    -- Powered by footer
    Create("TextLabel", {
        Parent = Sidebar,
        Size = UDim2.new(1, 0, 0, 32),
        Position = UDim2.new(0, 0, 1, -32),
        BackgroundTransparency = 1,
        Text = "\240\159\148\151 Powered by Miracle Labs",
        TextColor3 = Colors.TextMuted,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    local SidebarButtons = {}
    ctx.SidebarButtons = SidebarButtons
    local ActivePage = "Farm"
    ctx.GetActivePage = function() return ActivePage end

    -- Section header (AUTOMATION / PLAYER / MISC)
    local function CreateSectionHeader(parent, text, layoutOrder)
        local h = Create("Frame", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundTransparency = 1,
            LayoutOrder = layoutOrder,
        })
        Create("TextLabel", {
            Parent = h,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "// " .. text,
            TextColor3 = Colors.TextMuted,
            TextSize = 10,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        return h
    end

    -- Sidebar nav button
    local function CreateSidebarButton(parent, icon, text, layoutOrder)
        local button = Create("TextButton", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundTransparency = 1,
            Text = "",
            BorderSizePixel = 0,
            LayoutOrder = layoutOrder,
            AutoButtonColor = false,
        })
        CreateCorner(button, 8)

        -- Active left indicator
        local indicator = Create("Frame", {
            Parent = button,
            Size = UDim2.new(0, 3, 0, 20),
            Position = UDim2.new(0, 0, 0.5, -10),
            BackgroundColor3 = Colors.Success,
            BorderSizePixel = 0,
            Visible = false,
        })
        CreateCorner(indicator, 2)

        local iconLabel = Create("TextLabel", {
            Parent = button,
            Size = UDim2.new(0, 22, 0, 22),
            Position = UDim2.new(0, 14, 0.5, -11),
            BackgroundTransparency = 1,
            Text = icon,
            TextColor3 = Colors.TextMuted,
            TextSize = 16,
            Font = Enum.Font.Gotham,
        })

        local textLabel = Create("TextLabel", {
            Parent = button,
            Size = UDim2.new(1, -48, 1, 0),
            Position = UDim2.new(0, 42, 0, 0),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = Colors.TextSecondary,
            TextSize = 13,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
        })

        SidebarButtons[text] = {
            button    = button,
            indicator = indicator,
            icon      = iconLabel,
            label     = textLabel,
        }

        button.MouseEnter:Connect(function()
            if ActivePage ~= text then
                Tween(button, {BackgroundColor3 = Colors.Surface, BackgroundTransparency = 0}, 0.12)
                Tween(iconLabel, {TextColor3 = Colors.TextSecondary}, 0.12)
            end
        end)
        button.MouseLeave:Connect(function()
            if ActivePage ~= text then
                Tween(button, {BackgroundTransparency = 1}, 0.12)
                Tween(iconLabel, {TextColor3 = Colors.TextMuted}, 0.12)
            end
        end)

        return button
    end

    -- Build nav buttons
    local sb = {}
    CreateSectionHeader(SidebarContent, "AUTOMATION", 1)
    sb.Farm     = CreateSidebarButton(SidebarContent, "\240\159\140\177", "Farm",     2)
    sb.Plot     = CreateSidebarButton(SidebarContent, "\240\159\147\144", "Plot",     3)
    sb.Shop     = CreateSidebarButton(SidebarContent, "\240\159\155\146", "Shop",     4)
    sb.Sell     = CreateSidebarButton(SidebarContent, "\240\159\146\176", "Sell",     5)
    sb.Pets     = CreateSidebarButton(SidebarContent, "\240\159\144\190", "Pets",     6)
    sb.Eggs     = CreateSidebarButton(SidebarContent, "\240\159\165\154", "Eggs",     7)

    CreateSectionHeader(SidebarContent, "PLAYER", 8)
    sb.Player   = CreateSidebarButton(SidebarContent, "\240\159\145\164", "Player",   9)
    sb.Visuals  = CreateSidebarButton(SidebarContent, "\240\159\145\129", "Visuals",  10)
    sb.Teleport = CreateSidebarButton(SidebarContent, "\240\159\147\141", "Teleport", 11)

    CreateSectionHeader(SidebarContent, "MISC", 12)
    sb.Utility  = CreateSidebarButton(SidebarContent, "\240\159\148\167", "Utility",  13)
    sb.Mailer   = CreateSidebarButton(SidebarContent, "\226\156\137",     "Mailer",   14)
    sb.Info     = CreateSidebarButton(SidebarContent, "\226\132\185",     "Info",     15)
    sb.Server   = CreateSidebarButton(SidebarContent, "\240\159\140\144", "Server",   16)
    sb.Settings = CreateSidebarButton(SidebarContent, "\226\154\153",     "Settings", 17)

    ctx.sidebarButtonRefs = sb

    -- ====================== CONTENT AREA ======================
    local ContentArea = Create("Frame", {
        Parent = MainFrame,
        Size = UDim2.new(1, -210, 1, -48),
        Position = UDim2.new(0, 210, 0, 48),
        BackgroundColor3 = Colors.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    })
    ctx.ContentArea = ContentArea

    -- Page title bar inside content area
    local PageHeader = Create("Frame", {
        Parent = ContentArea,
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundColor3 = Colors.Background,
        BorderSizePixel = 0,
        ZIndex = 2,
    })

    -- Bottom separator
    Create("Frame", {
        Parent = PageHeader,
        Size = UDim2.new(1, -32, 0, 1),
        Position = UDim2.new(0, 16, 1, -1),
        BackgroundColor3 = Colors.Border,
        BorderSizePixel = 0,
        ZIndex = 3,
    })

    local PageIcon = Create("TextLabel", {
        Parent = PageHeader,
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(0, 20, 0.5, -14),
        BackgroundTransparency = 1,
        Text = "\240\159\140\177",
        TextColor3 = Colors.Success,
        TextSize = 18,
        Font = Enum.Font.Gotham,
        ZIndex = 3,
    })
    ctx.PageIcon = PageIcon

    local PageTitle = Create("TextLabel", {
        Parent = PageHeader,
        Size = UDim2.new(0, 300, 1, 0),
        Position = UDim2.new(0, 52, 0, 0),
        BackgroundTransparency = 1,
        Text = "FARM",
        TextColor3 = Colors.TextPrimary,
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
    })
    ctx.PageTitle = PageTitle

    -- Active badge (shown when a feature is running)
    local ActiveBadge = Create("Frame", {
        Parent = PageHeader,
        Size = UDim2.new(0, 80, 0, 26),
        Position = UDim2.new(1, -96, 0.5, -13),
        BackgroundColor3 = Color3.fromRGB(15, 35, 10),
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 3,
    })
    CreateCorner(ActiveBadge, 6)
    CreateStroke(ActiveBadge, Colors.Success, 1)
    Create("TextLabel", {
        Parent = ActiveBadge,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "ACTIVE",
        TextColor3 = Colors.Success,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 4,
    })
    ctx.ActiveBadge = ActiveBadge

    local ContentScroll = Create("ScrollingFrame", {
        Parent = ContentArea,
        Size = UDim2.new(1, 0, 1, -52),
        Position = UDim2.new(0, 0, 0, 52),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Colors.Surface,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    })
    CreatePadding(ContentScroll, 20, 20, 16, 20)
    CreateListLayout(ContentScroll, 12)
    ctx.ContentScroll = ContentScroll

    -- ====================== PAGE SYSTEM ======================
    local Pages = {}
    ctx.Pages = Pages

    local function SaveState(key, value) end
    ctx.SaveState = SaveState

    local _cardStates = {}

    local function ClearContent()
        for _, child in ipairs(ContentScroll:GetChildren()) do
            if child:IsA("GuiObject") and child.Name ~= "UIPadding" and child.Name ~= "UIListLayout" then
                child:Destroy()
            end
        end
    end
    ctx.ClearContent = ClearContent

    -- Icon map for page header
    local PAGE_ICONS = {
        Farm = "\240\159\140\177", Plot = "\240\159\147\144", Shop = "\240\159\155\146",
        Sell = "\240\159\146\176", Pets = "\240\159\144\190", Eggs = "\240\159\165\154",
        Player = "\240\159\145\164", Visuals = "\240\159\145\129", Teleport = "\240\159\147\141",
        Utility = "\240\159\148\167", Mailer = "\226\156\137", Info = "\226\132\185",
        Server = "\240\159\140\144", Settings = "\226\154\153",
    }

    local function SetActivePage(pageName)
        -- Deactivate old
        if SidebarButtons[ActivePage] then
            local s = SidebarButtons[ActivePage]
            s.indicator.Visible = false
            Tween(s.button, {BackgroundTransparency = 1, BackgroundColor3 = Colors.Surface}, 0.15)
            Tween(s.label, {TextColor3 = Colors.TextSecondary}, 0.15)
            s.label.Font = Enum.Font.Gotham
            Tween(s.icon, {TextColor3 = Colors.TextMuted}, 0.15)
        end

        ActivePage = pageName
        PageTitle.Text = pageName:upper()
        PageIcon.Text  = PAGE_ICONS[pageName] or "\240\159\148\165"

        -- Activate new
        if SidebarButtons[pageName] then
            local s = SidebarButtons[pageName]
            s.indicator.Visible = true
            s.button.BackgroundColor3 = Colors.Surface
            Tween(s.button, {BackgroundTransparency = 0}, 0.15)
            Tween(s.label, {TextColor3 = Colors.TextPrimary}, 0.15)
            s.label.Font = Enum.Font.GothamBold
            Tween(s.icon, {TextColor3 = Colors.Success}, 0.15)
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

    -- Section Card (collapsible)
    local function CreateSectionCard(title, layoutOrder, accentColor)
        local card = Create("Frame", {
            Parent = ContentScroll,
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = Colors.BackgroundLight,
            BorderSizePixel = 0,
            LayoutOrder = layoutOrder,
            AutomaticSize = Enum.AutomaticSize.Y,
        })
        CreateCorner(card, 10)
        CreateStroke(card, Colors.Border, 1)
        CreatePadding(card, 16, 16, 14, 16)
        CreateListLayout(card, 10)

        local header = Create("Frame", {
            Parent = card,
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            LayoutOrder = 0,
        })

        -- Accent bar
        local accentBar = Create("Frame", {
            Parent = header,
            Size = UDim2.new(0, 3, 0, 18),
            Position = UDim2.new(0, 0, 0.5, -9),
            BackgroundColor3 = accentColor or Colors.Success,
            BorderSizePixel = 0,
        })
        CreateCorner(accentBar, 2)

        Create("TextLabel", {
            Parent = header,
            Size = UDim2.new(1, -50, 1, 0),
            Position = UDim2.new(0, 12, 0, 0),
            BackgroundTransparency = 1,
            Text = title,
            TextColor3 = Colors.TextPrimary,
            TextSize = 14,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
        })

        local dropBtn = Create("TextButton", {
            Parent = header,
            Size = UDim2.new(0, 30, 0, 30),
            Position = UDim2.new(1, -30, 0.5, -15),
            BackgroundTransparency = 1,
            Text = "\226\150\190",
            TextColor3 = Colors.TextMuted,
            TextSize = 14,
            Font = Enum.Font.GothamBold,
            BorderSizePixel = 0,
            AutoButtonColor = false,
        })

        local content = Create("Frame", {
            Parent = card,
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            LayoutOrder = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            Visible = false,
        })
        CreateListLayout(content, 10)

        -- Separator
        local sep = Create("Frame", {
            Parent = card,
            Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = Colors.Border,
            BorderSizePixel = 0,
            LayoutOrder = 0.5,
            Visible = false,
        })

        local cardKey = ActivePage .. "|" .. title
        local collapsed = (_cardStates[cardKey] ~= false)
        content.Visible = not collapsed
        sep.Visible = not collapsed
        dropBtn.Rotation = collapsed and -90 or 0

        dropBtn.MouseButton1Click:Connect(function()
            collapsed = not collapsed
            _cardStates[cardKey] = collapsed
            content.Visible = not collapsed
            sep.Visible = not collapsed
            Tween(dropBtn, {Rotation = collapsed and -90 or 0}, 0.22)
        end)

        return card, content
    end

    -- Sub header (section label with divider line)
    local function CreateSubHeader(parent, text)
        local h = Create("Frame", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
        })
        Create("TextLabel", {
            Parent = h,
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = Colors.TextMuted,
            TextSize = 11,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        Create("Frame", {
            Parent = h,
            Size = UDim2.new(1, -120, 0, 1),
            Position = UDim2.new(0, 115, 0.5, 0),
            BackgroundColor3 = Colors.Border,
            BorderSizePixel = 0,
        })
        return h
    end

    -- Toggle (iOS style)
    local function CreateToggle(parent, text, stateKey, description, onToggle)
        local defaultState = States[stateKey] or false
        local rowH = description and 52 or 38

        local container = Create("Frame", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, rowH),
            BackgroundTransparency = 1,
        })

        Create("TextLabel", {
            Parent = container,
            Size = UDim2.new(1, -70, 0, 20),
            Position = UDim2.new(0, 0, 0, description and 6 or 9),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = Colors.TextPrimary,
            TextSize = 13,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
        })

        if description then
            Create("TextLabel", {
                Parent = container,
                Size = UDim2.new(1, -70, 0, 16),
                Position = UDim2.new(0, 0, 0, 28),
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
            Size = UDim2.new(0, 44, 0, 24),
            Position = UDim2.new(1, -44, 0, description and 14 or 7),
            BackgroundColor3 = defaultState and Colors.ToggleOn or Colors.ToggleOff,
            BorderSizePixel = 0,
        })
        CreateCorner(toggleBg, 12)

        local knob = Create("Frame", {
            Parent = toggleBg,
            Size = UDim2.new(0, 18, 0, 18),
            Position = UDim2.new(0, defaultState and 23 or 3, 0.5, -9),
            BackgroundColor3 = Colors.ToggleKnob,
            BorderSizePixel = 0,
        })
        CreateCorner(knob, 9)

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
            Tween(toggleBg, {BackgroundColor3 = state and Colors.ToggleOn or Colors.ToggleOff}, 0.18)
            Tween(knob, {Position = UDim2.new(0, state and 23 or 3, 0.5, -9)}, 0.18)
            if onToggle then
                onToggle(state, function()
                    state = false
                    States[stateKey] = false
                    SaveState(stateKey, false)
                    Tween(toggleBg, {BackgroundColor3 = Colors.ToggleOff}, 0.18)
                    Tween(knob, {Position = UDim2.new(0, 3, 0.5, -9)}, 0.18)
                end)
            end
        end)

        return container, function() return state end
    end

    -- Slider
    local function CreateSlider(parent, text, minVal, maxVal, stateKey, suffix, onChange)
        local defaultVal = States[stateKey] or minVal

        local container = Create("Frame", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, 58),
            BackgroundTransparency = 1,
        })

        Create("TextLabel", {
            Parent = container,
            Size = UDim2.new(1, -80, 0, 20),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = Colors.TextPrimary,
            TextSize = 13,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
        })

        -- Value pill
        local valLabel = Create("TextLabel", {
            Parent = container,
            Size = UDim2.new(0, 54, 0, 22),
            Position = UDim2.new(1, -54, 0, -1),
            BackgroundColor3 = Colors.Surface,
            Text = tostring(defaultVal) .. (suffix or ""),
            TextColor3 = Colors.TextPrimary,
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            BorderSizePixel = 0,
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        CreateCorner(valLabel, 6)
        CreateStroke(valLabel, Colors.Border, 1)

        -- Track
        local track = Create("Frame", {
            Parent = container,
            Size = UDim2.new(1, 0, 0, 5),
            Position = UDim2.new(0, 0, 0, 38),
            BackgroundColor3 = Colors.SliderTrack,
            BorderSizePixel = 0,
        })
        CreateCorner(track, 3)

        local fillPct = math.clamp((defaultVal - minVal) / math.max(maxVal - minVal, 1), 0, 1)
        local fill = Create("Frame", {
            Parent = track,
            Size = UDim2.new(fillPct, 0, 1, 0),
            BackgroundColor3 = Colors.SliderFill,
            BorderSizePixel = 0,
        })
        CreateCorner(fill, 3)

        local sliderKnob = Create("Frame", {
            Parent = track,
            Size = UDim2.new(0, 14, 0, 14),
            Position = UDim2.new(fillPct, -7, 0.5, -7),
            BackgroundColor3 = Colors.TextPrimary,
            BorderSizePixel = 0,
        })
        CreateCorner(sliderKnob, 7)

        local dragging = false
        local trackBtn = Create("TextButton", {
            Parent = container,
            Size = UDim2.new(1, 0, 0, 28),
            Position = UDim2.new(0, 0, 0, 28),
            BackgroundTransparency = 1,
            Text = "",
        })

        local function updateSlider(x, save)
            local pct = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
            local val = math.floor(minVal + pct * (maxVal - minVal))
            States[stateKey] = val
            if save then SaveState(stateKey, val) end
            valLabel.Text = tostring(val) .. (suffix or "")
            if onChange then onChange(val) end
            Tween(fill, {Size = UDim2.new(pct, 0, 1, 0)}, 0.05)
            Tween(sliderKnob, {Position = UDim2.new(pct, -7, 0.5, -7)}, 0.05)
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
                if dragging then SaveState(stateKey, States[stateKey]) end
                dragging = false
            end
        end)

        return container
    end

    -- Action Button (with arrow chevron, hover effect)
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
        CreateCorner(btn, 8)
        CreateStroke(btn, accentColor or Colors.Border, 1)

        Create("TextLabel", {
            Parent = btn,
            Size = UDim2.new(1, -40, 1, 0),
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
            Size = UDim2.new(0, 22, 1, 0),
            Position = UDim2.new(1, -26, 0, 0),
            BackgroundTransparency = 1,
            Text = "\226\128\186",
            TextColor3 = accentColor or Colors.TextMuted,
            TextSize = 16,
            Font = Enum.Font.GothamBold,
        })

        btn.MouseEnter:Connect(function()
            Tween(btn, {BackgroundColor3 = Colors.Surface}, 0.12)
        end)
        btn.MouseLeave:Connect(function()
            Tween(btn, {BackgroundColor3 = Colors.BackgroundLighter}, 0.12)
        end)
        btn.MouseButton1Click:Connect(function()
            Tween(btn, {BackgroundColor3 = Colors.SurfaceLight}, 0.05)
            task.wait(0.1)
            Tween(btn, {BackgroundColor3 = Colors.BackgroundLighter}, 0.1)
            if callback then callback() end
        end)

        return container
    end

    -- Dropdown (portal, renders above everything)
    local function CreateDropdown(parent, label, options, stateKey, onChange)
        local currentVal = States[stateKey] or options[1]

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
        CreateCorner(btn, 8)
        CreateStroke(btn, Colors.Border, 1)

        local lbl = Create("TextLabel", {
            Parent = btn,
            Size = UDim2.new(1, -56, 1, 0),
            Position = UDim2.new(0, 14, 0, 0),
            BackgroundTransparency = 1,
            Text = label .. "  \183  " .. currentVal,
            TextColor3 = Colors.TextPrimary,
            TextSize = 13,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
        })

        local arr = Create("TextLabel", {
            Parent = btn,
            Size = UDim2.new(0, 28, 1, 0),
            Position = UDim2.new(1, -30, 0, 0),
            BackgroundTransparency = 1,
            Text = "\226\150\190",
            TextColor3 = Colors.TextMuted,
            TextSize = 13,
            Font = Enum.Font.GothamBold,
        })

        btn.MouseEnter:Connect(function() Tween(btn, {BackgroundColor3 = Colors.Surface}, 0.12) end)
        btn.MouseLeave:Connect(function() Tween(btn, {BackgroundColor3 = Colors.BackgroundLighter}, 0.12) end)

        local isOpen = false
        local dropPanel = nil

        btn.MouseButton1Click:Connect(function()
            isOpen = not isOpen
            Tween(arr, {Rotation = isOpen and 180 or 0}, 0.18)

            if isOpen then
                local panelH = math.min(#options * 32, 180)
                dropPanel = Create("Frame", {
                    Parent = ScreenGui,
                    Size = UDim2.new(0, container.AbsoluteSize.X, 0, panelH),
                    Position = UDim2.new(0, container.AbsolutePosition.X, 0, container.AbsolutePosition.Y + 42),
                    BackgroundColor3 = Colors.BackgroundLighter,
                    BorderSizePixel = 0,
                    ZIndex = 150,
                    ClipsDescendants = true,
                })
                CreateCorner(dropPanel, 8)
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
                CreatePadding(scroll, 4, 4, 4, 4)

                for _, opt in ipairs(options) do
                    local isCurrent = opt == currentVal
                    local item = Create("TextButton", {
                        Parent = scroll,
                        Size = UDim2.new(1, 0, 0, 30),
                        BackgroundTransparency = isCurrent and 0.85 or 1,
                        BackgroundColor3 = Colors.Surface,
                        Text = "",
                        BorderSizePixel = 0,
                        ZIndex = 152,
                        AutoButtonColor = false,
                    })
                    CreateCorner(item, 6)

                    -- Checkmark for current
                    if isCurrent then
                        Create("TextLabel", {
                            Parent = item,
                            Size = UDim2.new(0, 22, 1, 0),
                            Position = UDim2.new(1, -26, 0, 0),
                            BackgroundTransparency = 1,
                            Text = "\226\156\147",
                            TextColor3 = Colors.Success,
                            TextSize = 13,
                            Font = Enum.Font.GothamBold,
                            ZIndex = 153,
                        })
                    end

                    Create("TextLabel", {
                        Parent = item,
                        Size = UDim2.new(1, -36, 1, 0),
                        Position = UDim2.new(0, 12, 0, 0),
                        BackgroundTransparency = 1,
                        Text = opt,
                        TextColor3 = isCurrent and Colors.Success or Colors.TextPrimary,
                        TextSize = 13,
                        Font = isCurrent and Enum.Font.GothamBold or Enum.Font.Gotham,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 153,
                    })

                    item.MouseEnter:Connect(function()
                        item.BackgroundTransparency = 0.7
                        item.BackgroundColor3 = Colors.Surface
                    end)
                    item.MouseLeave:Connect(function()
                        item.BackgroundTransparency = isCurrent and 0.85 or 1
                    end)
                    item.MouseButton1Click:Connect(function()
                        currentVal = opt
                        States[stateKey] = opt
                        SaveState(stateKey, opt)
                        lbl.Text = label .. "  \183  " .. opt
                        isOpen = false
                        Tween(arr, {Rotation = 0}, 0.18)
                        if dropPanel then dropPanel:Destroy() dropPanel = nil end
                        if onChange then task.defer(onChange, opt) end
                    end)
                end
            else
                if dropPanel then dropPanel:Destroy() dropPanel = nil end
            end
        end)

        UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 and isOpen and dropPanel then
                local mp = UserInputService:GetMouseLocation()
                local ap = dropPanel.AbsolutePosition
                local as = dropPanel.AbsoluteSize
                if not (mp.X >= ap.X and mp.X <= ap.X + as.X and mp.Y >= ap.Y and mp.Y <= ap.Y + as.Y) then
                    isOpen = false
                    Tween(arr, {Rotation = 0}, 0.18)
                    dropPanel:Destroy()
                    dropPanel = nil
                end
            end
        end)

        return container
    end

    -- Multi-select dropdown (inline expand, checkmarks, select-all/clear)
    local function CreateMultiSelect(parent, label, options, stateKey)
        if type(States[stateKey]) ~= "table" then States[stateKey] = {} end
        local selected = States[stateKey]

        local pillText = label:gsub("^[%z\1-\127\194-\244][\128-\191]*%s*", "")

        local function getShortText()
            if #selected == 0 then return pillText .. "  \183  (none)" end
            if #selected <= 2 then
                return pillText .. "  \183  " .. table.concat(selected, ", ")
            end
            return pillText .. "  \183  " .. #selected .. " selected"
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
            Size = UDim2.new(1, 0, 0, 38),
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
        CreateCorner(pill, 8)
        local pillStroke = CreateStroke(pill, Colors.Border, 1)

        local pillLabel = Create("TextLabel", {
            Parent = pill,
            Size = UDim2.new(1, -50, 1, 0),
            Position = UDim2.new(0, 14, 0, 0),
            BackgroundTransparency = 1,
            Text = getShortText(),
            TextColor3 = #selected > 0 and Colors.Success or Colors.TextPrimary,
            TextSize = 13,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })

        local arrowLbl = Create("TextLabel", {
            Parent = pill,
            Size = UDim2.new(0, 26, 1, 0),
            Position = UDim2.new(1, -30, 0, 0),
            BackgroundTransparency = 1,
            Text = "\226\150\190",
            TextColor3 = Colors.TextMuted,
            TextSize = 13,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center,
        })

        pill.MouseEnter:Connect(function() Tween(pill, {BackgroundColor3 = Colors.Surface}, 0.12) end)
        pill.MouseLeave:Connect(function() Tween(pill, {BackgroundColor3 = Colors.BackgroundLighter}, 0.12) end)

        -- Dropdown panel (inline)
        local panel = Create("Frame", {
            Parent = wrapper,
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = Colors.BackgroundLighter,
            BorderSizePixel = 0,
            LayoutOrder = 1,
            Visible = false,
            ClipsDescendants = true,
        })
        CreateCorner(panel, 8)
        CreateStroke(panel, Colors.Border, 1)

        -- Panel header row (Select All / Clear)
        local headerRow = Create("Frame", {
            Parent = panel,
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundColor3 = Colors.Background,
            BorderSizePixel = 0,
        })
        CreateCorner(headerRow, 8)
        -- Mask bottom corners of header
        Create("Frame", {
            Parent = headerRow,
            Size = UDim2.new(1, 0, 0, 10),
            Position = UDim2.new(0, 0, 1, -10),
            BackgroundColor3 = Colors.Background,
            BorderSizePixel = 0,
            ZIndex = 2,
        })

        local function makeSmallBtn(parent, text, xPos)
            local b = Create("TextButton", {
                Parent = parent,
                Size = UDim2.new(0, 56, 0, 22),
                Position = UDim2.new(0, xPos, 0.5, -11),
                BackgroundColor3 = Colors.Surface,
                Text = text,
                TextColor3 = Colors.TextSecondary,
                TextSize = 11,
                Font = Enum.Font.GothamBold,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                ZIndex = 3,
            })
            CreateCorner(b, 5)
            b.MouseEnter:Connect(function() Tween(b, {BackgroundColor3 = Colors.SurfaceLight}, 0.1) end)
            b.MouseLeave:Connect(function() Tween(b, {BackgroundColor3 = Colors.Surface}, 0.1) end)
            return b
        end

        local selAllBtn = makeSmallBtn(headerRow, "\226\156\148 All", 10)
        local clearBtn  = makeSmallBtn(headerRow, "\226\156\151 Clear", 72)

        local LIST_MAX_H = 200
        local scroll = Create("ScrollingFrame", {
            Parent = panel,
            Size = UDim2.new(1, 0, 0, math.min(#options * 30, LIST_MAX_H)),
            Position = UDim2.new(0, 0, 0, 38),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Colors.BorderLight,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ZIndex = 2,
        })
        CreateListLayout(scroll, 0)
        Create("UIPadding", {
            Parent = scroll,
            PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
            PaddingTop = UDim.new(0, 4),  PaddingBottom = UDim.new(0, 6),
        })

        local itemFrames = {}

        local function isSelected(opt)
            return table.find(selected, opt) ~= nil
        end

        local function updateRow(t)
            local sel = isSelected(t.opt)
            t.frame.BackgroundColor3 = sel and Colors.Surface or Colors.BackgroundLighter
            t.frame.BackgroundTransparency = sel and 0 or 1
            t.checkLbl.Text = sel and "\226\156\147" or ""
            t.checkLbl.TextColor3 = Colors.Success
            t.nameLbl.TextColor3 = sel and Colors.Success or Colors.TextPrimary
            t.nameLbl.Font = sel and Enum.Font.GothamBold or Enum.Font.Gotham
        end

        local function updatePill()
            pillLabel.Text = getShortText()
            pillLabel.TextColor3 = #selected > 0 and Colors.Success or Colors.TextPrimary
            pillStroke.Color = #selected > 0 and Colors.Success or Colors.Border
        end

        local isDisabled = false

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
                Size = UDim2.new(0, 24, 1, 0),
                Position = UDim2.new(0, 6, 0, 0),
                BackgroundTransparency = 1,
                Text = sel and "\226\156\147" or "",
                TextColor3 = Colors.Success,
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
                TextColor3 = sel and Colors.Success or Colors.TextPrimary,
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

            local entry = {frame = row, checkLbl = checkLbl, nameLbl = nameLbl, opt = opt}
            itemFrames[#itemFrames + 1] = entry

            hitBtn.MouseEnter:Connect(function()
                if isDisabled then return end
                if not isSelected(opt) then
                    Tween(row, {BackgroundColor3 = Colors.Surface, BackgroundTransparency = 0.6}, 0.1)
                end
            end)
            hitBtn.MouseLeave:Connect(function()
                if isDisabled then return end
                if not isSelected(opt) then row.BackgroundTransparency = 1 end
            end)
            hitBtn.MouseButton1Click:Connect(function()
                if isDisabled then return end
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
            if isDisabled then return end
            table.clear(selected)
            for _, opt in ipairs(options) do table.insert(selected, opt) end
            States[stateKey] = selected
            SaveState(stateKey, selected)
            for _, t in ipairs(itemFrames) do updateRow(t) end
            updatePill()
        end)

        clearBtn.MouseButton1Click:Connect(function()
            if isDisabled then return end
            table.clear(selected)
            States[stateKey] = selected
            SaveState(stateKey, selected)
            for _, t in ipairs(itemFrames) do updateRow(t) end
            updatePill()
        end)

        local isOpen = false

        pill.MouseButton1Click:Connect(function()
            if isDisabled then return end
            isOpen = not isOpen
            Tween(arrowLbl, {Rotation = isOpen and 180 or 0}, 0.18)
            if isOpen then
                panel.Visible = true
                panel.Size = UDim2.new(1, 0, 0, 0)
                local targetH = 38 + math.min(#options * 30, LIST_MAX_H) + 10
                Tween(panel, {Size = UDim2.new(1, 0, 0, targetH)}, 0.2, Enum.EasingStyle.Quart)
            else
                Tween(panel, {Size = UDim2.new(1, 0, 0, 0)}, 0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
                task.delay(0.17, function()
                    if not isOpen then panel.Visible = false end
                end)
            end
        end)

        local function SetDisabled(disabled)
            isDisabled = disabled
            if disabled and isOpen then
                isOpen = false
                Tween(arrowLbl, {Rotation = 0}, 0.16)
                Tween(panel, {Size = UDim2.new(1, 0, 0, 0)}, 0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
                task.delay(0.17, function()
                    if not isOpen then panel.Visible = false end
                end)
            end
            local dim = disabled and 0.5 or 0
            Tween(pill, {BackgroundColor3 = disabled and Colors.BackgroundLight or Colors.BackgroundLighter}, 0.16)
            Tween(pillLabel, {TextTransparency = dim}, 0.16)
            Tween(arrowLbl, {TextTransparency = dim}, 0.16)
            selAllBtn.Active = not disabled
            clearBtn.Active  = not disabled
            selAllBtn.TextTransparency = dim
            clearBtn.TextTransparency  = dim
            for _, t in ipairs(itemFrames) do
                t.nameLbl.TextTransparency  = dim
                t.checkLbl.TextTransparency = dim
                local hb = t.frame:FindFirstChildWhichIsA("TextButton")
                if hb then hb.Active = not disabled end
            end
        end

        return {instance = wrapper, SetDisabled = SetDisabled}
    end

    -- Info text box
    local function CreateInfoText(parent, title, desc, color)
        local c = Create("Frame", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(15, 25, 10),
            BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.Y,
        })
        CreateCorner(c, 8)
        CreateStroke(c, color or Colors.Success, 1)
        CreatePadding(c, 12, 12, 10, 10)
        CreateListLayout(c, 4)

        if title then
            Create("TextLabel", {
                Parent = c,
                Size = UDim2.new(1, 0, 0, 16),
                BackgroundTransparency = 1,
                Text = title,
                TextColor3 = color or Colors.Success,
                TextSize = 11,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left,
            })
        end
        Create("TextLabel", {
            Parent = c,
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            Text = desc,
            TextColor3 = Colors.TextSecondary,
            TextSize = 11,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            AutomaticSize = Enum.AutomaticSize.Y,
            TextWrapped = true,
        })
        return c
    end

    -- Stat row (label: value)
    local function CreateStatRow(parent, label, value, valColor)
        local r = Create("Frame", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundColor3 = Colors.BackgroundLighter,
            BorderSizePixel = 0,
        })
        CreateCorner(r, 6)
        CreateStroke(r, Colors.Border, 1)

        Create("TextLabel", {
            Parent = r,
            Size = UDim2.new(0.5, 0, 1, 0),
            Position = UDim2.new(0, 14, 0, 0),
            BackgroundTransparency = 1,
            Text = label,
            TextColor3 = Colors.TextSecondary,
            TextSize = 12,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
        })

        local valLbl = Create("TextLabel", {
            Parent = r,
            Size = UDim2.new(0.5, -14, 1, 0),
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

    -- Expose all component builders
    UI.CreateSectionCard  = CreateSectionCard
    UI.CreateSubHeader    = CreateSubHeader
    UI.CreateToggle       = CreateToggle
    UI.CreateSlider       = CreateSlider
    UI.CreateActionButton = CreateActionButton
    UI.CreateDropdown     = CreateDropdown
    UI.CreateMultiSelect  = CreateMultiSelect
    UI.CreateInfoText     = CreateInfoText
    UI.CreateStatRow      = CreateStatRow

    ctx.UI = UI
    return ctx
end