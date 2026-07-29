-- ======================================================================
-- Miracle Hub — bootstrap.lua
-- Final wiring module. Loaded LAST (after core, ui, logic, pages).
--
-- Wires: sidebar buttons, search, window drag, minimize/restore + M logo,
--   confirm-close modal, keybinds, and the loading sequence that reveals
--   the window and calls SetActivePage("Farm").
--
-- Reads from ctx: Colors, States, MY_PLOT_ID, UI.*, ScreenGui, MainFrame,
--   TopBar, Sidebar, ContentArea, SearchBox, CloseButton, MinimizeButton,
--   sidebarButtonRefs, SetActivePage, GetActivePage, Pages, PacketRemote,
--   Loading* refs, originalSize, player
-- ======================================================================

return function(ctx)
    local Colors           = ctx.Colors
    local States           = ctx.States
    local MY_PLOT_ID       = ctx.MY_PLOT_ID
    local player           = ctx.player
    local UserInputService  = ctx.UserInputService
    local RunService       = ctx.RunService

    local UI     = ctx.UI
    local Create = UI.Create
    local CreateCorner = UI.CreateCorner
    local CreateStroke = UI.CreateStroke
    local Tween  = UI.Tween
    local Notify = UI.Notify

    local ScreenGui      = ctx.ScreenGui
    local MainFrame      = ctx.MainFrame
    local TopBar         = ctx.TopBar
    local Sidebar        = ctx.Sidebar
    local ContentArea    = ctx.ContentArea
    local SearchBox      = ctx.SearchBox
    local CloseButton    = ctx.CloseButton
    local MinimizeButton = ctx.MinimizeButton
    local sb             = ctx.sidebarButtonRefs
    local SetActivePage  = ctx.SetActivePage
    local GetActivePage  = ctx.GetActivePage
    local Pages          = ctx.Pages
    local originalSize   = ctx.originalSize

    local LoadingScreen    = ctx.LoadingScreen
    local LoadingContainer = ctx.LoadingContainer
    local LoadingBarFill   = ctx.LoadingBarFill
    local LoadingPercent   = ctx.LoadingPercent
    local LoadingStatus    = ctx.LoadingStatus

    -- ====================== SIDEBAR CONNECTIONS ======================
    local pageMap = {
        [sb.Farm] = "Farm", [sb.Plot] = "Plot", [sb.Shop] = "Shop",
        [sb.Sell] = "Sell", [sb.Pets] = "Pets", [sb.Eggs] = "Eggs",
        [sb.Player] = "Player", [sb.Visuals] = "Visuals", [sb.Teleport] = "Teleport",
        [sb.Utility] = "Utility", [sb.Mailer] = "Mailer",
        [sb.Server] = "Server", [sb.Settings] = "Settings",
    }
    for btn, pageName in pairs(pageMap) do
        btn.MouseButton1Click:Connect(function()
            SetActivePage(pageName)
        end)
    end

    -- ====================== SEARCH FUNCTIONALITY ======================
    local searchAllItems = {
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
            local active = GetActivePage()
            if active and Pages[active] then
                ctx.ClearContent()
                Pages[active]()
            end
            return
        end
        local bestPage = nil
        for _, item in ipairs(searchAllItems) do
            if item[1]:find(query, 1, true) or query:find(item[1], 1, true) then
                bestPage = item[2]
                break
            end
        end
        if bestPage and bestPage ~= GetActivePage() then
            SetActivePage(bestPage)
        end
    end)

    -- ====================== MINIMIZE / RESTORE ======================
    -- selama animasi minimize/restore, AbsoluteSize MainFrame berubah dan bisa
    -- memicu snap ke tengah → blink. Flag ini mencegah hal itu.
    -- FIX: `minimized` was never declared — it silently read as nil (global) in
    -- Xeno's isolated environment, breaking DoMinimize/DoRestore state tracking.
    local minimized = false
    ctx.isMinimized = false

    if ctx.isMobile then
        -- ====================== MOBILE MINIMIZE ======================
        -- Floating button 60×60 di pojok kanan bawah — pakai logo Miracle Hub
        local MobileMinBtn = Create("ImageButton", {
            Name = "MobileMinimizeBtn",
            Parent = ScreenGui,
            Size = UDim2.new(0, 60, 0, 60),
            Position = UDim2.new(1, -72, 1, -72),
            BackgroundColor3 = Colors.BackgroundLighter,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 100,
        })
        CreateCorner(MobileMinBtn, 14)
        CreateStroke(MobileMinBtn, Colors.BorderLight, 1)
        -- Logo M
        Create("ImageLabel", {
            Parent = MobileMinBtn,
            Size = UDim2.new(0, 34, 0, 34),
            Position = UDim2.new(0.5, -17, 0.5, -17),
            BackgroundTransparency = 1,
            Image = "rbxassetid://74186782815011",
            ImageColor3 = Colors.Accent,
            ScaleType = Enum.ScaleType.Fit,
        })

        MobileMinBtn.MouseButton1Click:Connect(function()
            if minimized then
                -- Restore
                minimized = false
                ctx.isMinimized = false
                MobileMinBtn.Visible = false
                MainFrame.Visible = true
                ctx.SnapMainFramePosition()
            end
        end)

        local function DoMinimize()
            minimized = true
            ctx.isMinimized = true
            MainFrame.Visible = false
            MobileMinBtn.Visible = true
        end

        local function DoRestore()
            if not minimized then return end
            minimized = false
            ctx.isMinimized = false
            MobileMinBtn.Visible = false
            MainFrame.Visible = true
            ctx.SnapMainFramePosition()
        end

        MinimizeButton.MouseButton1Click:Connect(DoMinimize)
    else
        -- ====================== DESKTOP MINIMIZE PILL BAR ======================
        -- Pill bar: clone visual dari BrandCard di TopBar (300×30, BackgroundLighter,
        -- corner 8, border Colors.Border, font identik). Saat minimize, MainFrame
        -- "menyedot" semua konten ke arah TopBar lalu mengecil jadi pill ini.
        -- Saat restore, pill "meledak" expand balik ke full window.
        --
        -- Pill ini hidup di ScreenGui (bukan di MainFrame) supaya bisa draggable
        -- bebas di luar bounds MainFrame.

        local PILL_W = 304
        local PILL_H = 30
        local LIME_HEX_LOCAL = "#4DD6C9"

        -- Container transparan (ghost box prevention — identik dengan pola MinimizedLogo lama)
        local MinimizedPill = Create("Frame", {
            Name = "MinimizedPill",
            Parent = ScreenGui,
            Size = UDim2.new(0, PILL_W + 20, 0, PILL_H + 20),  -- padding 10px semua sisi untuk hit area drag
            Position = UDim2.new(0.5, -(PILL_W/2 + 10), 0, 10),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 50,
        })

        -- Visual pill — ukuran & warna identik BrandCard
        local PillInner = Create("Frame", {
            Name = "PillInner",
            Parent = MinimizedPill,
            Size = UDim2.new(0, PILL_W, 0, PILL_H),
            Position = UDim2.new(0, 10, 0, 10),  -- offset 10px dari container
            BackgroundColor3 = Colors.BackgroundLighter,
            BackgroundTransparency = 1,           -- start transparan, fade in setelah muncul
            BorderSizePixel = 0,
            ZIndex = 51,
        })
        CreateCorner(PillInner, 8)
        local PillStroke = CreateStroke(PillInner, Colors.Border, 1)
        PillStroke.Transparency = 1  -- sync fade dengan PillInner

        -- Miracle logo icon (kiri PillBrand, identik dengan BrandCard di TopBar)
        local PillLogoIcon = Create("ImageLabel", {
            Parent = PillInner,
            Size = UDim2.new(0, 26, 0, 26),
            Position = UDim2.new(0, 10, 0.5, -13),
            BackgroundTransparency = 1,
            Image = "rbxassetid://74186782815011",
            ImageTransparency = 1,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 52,
        })
        -- Segmen MIRACLEHUB (90px, geser kanan untuk beri ruang logo)
        local PillBrand = Create("TextLabel", {
            Parent = PillInner,
            Size = UDim2.new(0, 82, 1, 0),
            Position = UDim2.new(0, 39, 0, 0),
            BackgroundTransparency = 1,
            RichText = true,
            Text = 'MIRACLE<font color="' .. LIME_HEX_LOCAL .. '">HUB</font>',
            TextColor3 = Colors.TextPrimary,
            TextTransparency = 1,
            TextSize = 14,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 52,
        })

        -- Divider 1 (identik divider pertama di BrandCard)
        local PillDiv1 = Create("Frame", {
            Parent = PillInner,
            Size = UDim2.new(0, 1, 1, -10),
            Position = UDim2.new(0, 135, 0, 5),
            BackgroundColor3 = Color3.fromRGB(58, 68, 80),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 52,
        })

        -- FPS icon (identik BrandCard: gauge/speedometer lucide, x=123)
        local PillFpsIcon = Create("ImageLabel", {
            Parent = PillInner,
            Size = UDim2.new(0, 13, 0, 13),
            Position = UDim2.new(0, 147, 0.5, -6),
            BackgroundTransparency = 1,
            Image = "rbxassetid://104426509560089",
            ImageColor3 = Colors.Accent,
            ImageTransparency = 1,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 52,
        })

        -- Segmen FPS (identik FpsSeg: x=167, w=44, TextXAlignment Left)
        local PillFps = Create("TextLabel", {
            Parent = PillInner,
            Size = UDim2.new(0, 44, 1, 0),
            Position = UDim2.new(0, 167, 0, 0),
            BackgroundTransparency = 1,
            RichText = true,
            Text = '<font color="#71717A">FPS</font><font size="4"> </font><font color="' .. LIME_HEX_LOCAL .. '">--</font>',
            TextColor3 = Colors.TextSecondary,
            TextTransparency = 1,
            TextSize = 12,
            Font = Enum.Font.Code,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 52,
        })

        -- Divider 2 (identik BrandCard: x=213)
        local PillDiv2 = Create("Frame", {
            Parent = PillInner,
            Size = UDim2.new(0, 1, 1, -10),
            Position = UDim2.new(0, 213, 0, 5),
            BackgroundColor3 = Color3.fromRGB(58, 68, 80),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 52,
        })

        -- MS icon (identik BrandCard: activity/waveform lucide, x=225)
        local PillMsIcon = Create("ImageLabel", {
            Parent = PillInner,
            Size = UDim2.new(0, 13, 0, 13),
            Position = UDim2.new(0, 225, 0.5, -6),
            BackgroundTransparency = 1,
            Image = "rbxassetid://84466565972313",
            ImageColor3 = Colors.Accent,
            ImageTransparency = 1,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 52,
        })

        -- Segmen MS (identik MsSeg: x=245, w=55, TextXAlignment Left)
        local PillMs = Create("TextLabel", {
            Parent = PillInner,
            Size = UDim2.new(0, 55, 1, 0),
            Position = UDim2.new(0, 245, 0, 0),
            BackgroundTransparency = 1,
            RichText = true,
            Text = '<font color="#71717A">MS</font><font size="4"> </font>--',
            TextColor3 = Colors.TextSecondary,
            TextTransparency = 1,
            TextSize = 12,
            Font = Enum.Font.Code,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 52,
        })

        -- Sync FPS/MS live dari ctx (update tiap frame saat pill visible)
        task.spawn(function()
            while MinimizedPill.Parent do
                if MinimizedPill.Visible then
                    local fps = ctx.CurrentFPS or 0
                    local ping = 0
                    pcall(function() ping = ctx.player:GetNetworkPing() * 1000 end)
                    PillFps.Text = '<font color="#71717A">FPS</font><font size="4"> </font><font color="' .. LIME_HEX_LOCAL .. '">' .. fps .. '</font>'
                    PillMs.Text  = '<font color="#71717A">MS</font><font size="4"> </font>' .. string.format("%.1f", ping)
                end
                task.wait(0.5)
            end
        end)

        -- Hover effect: border sedikit terang (identik dengan feel TopBar)
        local PillClick = Create("TextButton", {
            Parent = MinimizedPill,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            ZIndex = 60,
            AutoButtonColor = false,
        })
        PillClick.MouseEnter:Connect(function()
            Tween(PillStroke, {Color = Colors.BorderLight}, 0.15)
            Tween(PillInner, {BackgroundColor3 = Colors.Surface}, 0.15)
        end)
        PillClick.MouseLeave:Connect(function()
            Tween(PillStroke, {Color = Colors.Border}, 0.15)
            Tween(PillInner, {BackgroundColor3 = Colors.BackgroundLighter}, 0.15)
        end)

        -- Fade-in semua elemen pill (alpha 0 = opak, 1 = transparan)
        local function SetPillTransparency(alpha)
            PillInner.BackgroundTransparency  = alpha
            PillStroke.Transparency           = alpha
            PillBrand.TextTransparency        = alpha
            PillFps.TextTransparency          = alpha
            PillMs.TextTransparency           = alpha
            PillDiv1.BackgroundTransparency   = alpha
            PillDiv2.BackgroundTransparency   = alpha
            PillFpsIcon.ImageTransparency     = alpha
            PillMsIcon.ImageTransparency      = alpha
            PillLogoIcon.ImageTransparency    = alpha
        end
        local function TweenPillTransparency(alpha, dur)
            dur = dur or 0.25
            Tween(PillInner,    {BackgroundTransparency = alpha}, dur)
            Tween(PillStroke,   {Transparency           = alpha}, dur)
            Tween(PillBrand,    {TextTransparency       = alpha}, dur)
            Tween(PillFps,      {TextTransparency       = alpha}, dur)
            Tween(PillMs,       {TextTransparency       = alpha}, dur)
            Tween(PillDiv1,     {BackgroundTransparency = alpha}, dur)
            Tween(PillDiv2,     {BackgroundTransparency = alpha}, dur)
            Tween(PillFpsIcon,  {ImageTransparency      = alpha}, dur)
            Tween(PillMsIcon,   {ImageTransparency      = alpha}, dur)
            Tween(PillLogoIcon, {ImageTransparency      = alpha}, dur)
        end

        -- Drag pill (identik pola drag logo lama)
        local pillDragging, pillDragStart, pillStartPos, pillHasMoved = false, nil, nil, false
        local lastPillPosition = nil

        PillClick.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                pillDragging  = true
                pillHasMoved  = false
                pillDragStart = input.Position
                pillStartPos  = MinimizedPill.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if pillDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - pillDragStart
                if delta.Magnitude > 5 then pillHasMoved = true end
                if pillHasMoved then
                    local np = UDim2.new(
                        pillStartPos.X.Scale, pillStartPos.X.Offset + delta.X,
                        pillStartPos.Y.Scale, pillStartPos.Y.Offset + delta.Y
                    )
                    MinimizedPill.Position = np
                    lastPillPosition = np
                end
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                pillDragging = false
            end
        end)

    -- ====================== WINDOW DRAG ======================
    local dragging, dragStart, startPos = false, nil, nil
    local function IsInsideTopBar(p)
        local topbarPos = TopBar.AbsolutePosition
        local topbarSize = TopBar.AbsoluteSize
        return p.X >= topbarPos.X
            and p.X <= topbarPos.X + topbarSize.X
            and p.Y >= topbarPos.Y
            and p.Y <= topbarPos.Y + topbarSize.Y
    end

    local function BeginDrag(p)
        if IsInsideTopBar(p) then
            dragging = true
            dragStart = p
            startPos = MainFrame.Position
        end
    end

    local function MoveDrag(p)
        if dragging then
            local delta = p - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end

    if ctx.isMobile then
        -- Explicit touch events are more reliable than InputChanged on mobile.
        UserInputService.TouchStarted:Connect(function(touch)
            BeginDrag(touch.Position)
        end)
        UserInputService.TouchMoved:Connect(function(touch)
            MoveDrag(touch.Position)
        end)
        UserInputService.TouchEnded:Connect(function()
            dragging = false
        end)
    else
        UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                BeginDrag(input.Position)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                MoveDrag(input.Position)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
    end

    end -- end if ctx.isMobile/else untuk minimize

    -- ====================== CONFIRM CLOSE MODAL ======================
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
        Tween(MainFrame, {Size=UDim2.new(0,900,0,0)}, 0.3)
        task.wait(0.3)
        ScreenGui:Destroy()
    end)

    -- ====================== SHARED FLY TOGGLE ======================
    -- Satu fungsi terpusat untuk toggle fly.
    -- Dipanggil dari:
    --   (1) Keybind F          → forceState = nil  → flip States.fly + sync visual widget
    --   (2) UI toggle widget   → forceState = state → States.fly sudah diset widget,
    --                            cukup kirim Notify (setVisual TIDAK dipanggil agar
    --                            tidak loop balik ke widget yang baru saja klik sendiri)
    --
    -- ctx._setFlyVisual: diset oleh pages.lua setiap kali halaman Player dirender.
    -- Saat halaman lain aktif nilainya nil (atau menunjuk fungsi widget lama yg sudah
    -- di-destroy dan aman karena setVisual cek container.Parent == nil lebih dulu).
    ctx.ToggleFly = function(forceState)
        local fromKeybind = forceState == nil

        if fromKeybind then
            -- Keybind F: flip state secara manual (widget tidak terlibat)
            States.fly = not States.fly
            -- Sync visual toggle jika halaman Player sedang terbuka
            if ctx._setFlyVisual then
                pcall(ctx._setFlyVisual, States.fly)
            end
        else
            -- Dari UI widget: States.fly sudah diset oleh CreateToggle sebelum onToggle
            -- dipanggil — jangan flip lagi, langsung ke Notify
            States.fly = forceState
        end

        Notify("Player", "Fly " .. (States.fly and "ON" or "OFF"), States.fly and Colors.Success or Colors.TextMuted)
    end

    -- ====================== KEYBINDS ======================
    if not ctx.isMobile then
        UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.KeyCode == Enum.KeyCode.Insert then
                if minimized then DoRestore() else DoMinimize() end
            end
            if input.KeyCode == Enum.KeyCode.F then
                -- Gunakan ctx.ToggleFly agar state & notif selalu sinkron
                -- dengan toggle UI di tab Player → tidak ada notif ganda/konflik
                ctx.ToggleFly()
            end
        end)
    end

    -- ====================== LOADING SCREEN REVEAL ======================
    -- loader.lua sudah mengisi LoadingBarFill/Percent/Status secara real-time.
    -- Bootstrap tinggal: snap bar ke 100%, teks "Ready!", fade out, reveal window.
    do
        -- Snap bar ke 100% dengan tween singkat (biar smooth dari ~83% ke 100%)
        Tween(LoadingBarFill, {Size = UDim2.new(1, 0, 1, 0)}, 0.3)
        LoadingPercent.Text = "100%"
        LoadingStatus.Text  = "Ready!"

        task.wait(0.5)

        -- Fade out loading container
        Tween(LoadingContainer, {BackgroundTransparency = 1}, 0.4)
        for _, c in ipairs(LoadingContainer:GetDescendants()) do
            if c:IsA("TextLabel") then
                Tween(c, {TextTransparency = 1}, 0.4)
            elseif c:IsA("Frame") then
                Tween(c, {BackgroundTransparency = 1}, 0.4)
            end
        end
        task.wait(0.5)
        LoadingScreen:Destroy()

        -- Reveal main window
        MainFrame.Visible = true
        -- Keep the mobile/desktop target width during the reveal animation.
        -- A hardcoded 900px here briefly forced the mobile window to desktop width.
        MainFrame.Size    = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, 0)
        Tween(MainFrame, {Size = originalSize}, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

        task.wait(0.3)
        SetActivePage("Profile")

        task.wait(0.8)
        local remoteStatus = ctx.PacketRemote and "Remote" or "Remote \226\154\160 (check console)"
        local buildTag = ctx.isMobile and " | Mobile a36b029" or ""
        Notify("Miracle Hub", "Loaded! Plot " .. MY_PLOT_ID .. " | " .. remoteStatus .. buildTag .. " | [Insert] toggle | [F] fly", Colors.Success, 6)
    end

    return ctx
end
