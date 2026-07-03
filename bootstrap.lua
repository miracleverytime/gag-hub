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
        [sb.Utility] = "Utility", [sb.Mailer] = "Mailer", [sb.Info] = "Info",
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

    -- ====================== MINIMIZED M LOGO ======================
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
    local ShieldStroke = CreateStroke(ShieldOuter, Color3.fromRGB(255, 255, 255), 1.5)
    ShieldStroke.Transparency = 0.4  -- selalu terlihat, warna senada M

    local mParts = {}
    -- M heraldik lebih kecil & proporsional dalam ShieldOuter 44×44px.
    -- Warna: krem hangat (bukan putih keras) agar clean dan classy.
    -- M menempati ~26×28px di tengah (offset dari tepi ~9px kiri/kanan, 8px atas/bawah).
    local LogoColor      = Color3.fromRGB(255, 255, 255)   -- putih tegas
    local LogoColorHover = Color3.fromRGB(180, 180, 180)   -- sedikit dim saat hover
    local mDefs = {
        -- Batang vertikal kiri (x=9, y=8, h=28, w=4)
        {Size=UDim2.new(0,4,0,28), Position=UDim2.new(0, 9, 0, 8), Rotation=0},
        -- Batang vertikal kanan (x=31, y=8, h=28, w=4)
        {Size=UDim2.new(0,4,0,28), Position=UDim2.new(0,31, 0, 8), Rotation=0},

        -- Serif horizontal atas kiri
        {Size=UDim2.new(0,10,0,3), Position=UDim2.new(0, 7, 0, 8), Rotation=0},
        -- Serif horizontal atas kanan
        {Size=UDim2.new(0,10,0,3), Position=UDim2.new(0,27, 0, 8), Rotation=0},
        -- Serif horizontal bawah kiri
        {Size=UDim2.new(0,10,0,3), Position=UDim2.new(0, 7, 0,33), Rotation=0},
        -- Serif horizontal bawah kanan
        {Size=UDim2.new(0,10,0,3), Position=UDim2.new(0,27, 0,33), Rotation=0},

        -- Diagonal kiri turun ke lembah V (pivot kiri atas, condong kanan-bawah)
        {Size=UDim2.new(0,3,0,20), Position=UDim2.new(0,12, 0, 6), Rotation=-30},
        -- Diagonal kanan turun ke lembah V (pivot kanan atas, condong kiri-bawah)
        {Size=UDim2.new(0,3,0,20), Position=UDim2.new(0,29, 0, 6), Rotation=30},

        -- Diamond kecil di lembah V tengah
        {Size=UDim2.new(0,5,0,5), Position=UDim2.new(0,20, 0,23), Rotation=45},
    }

    for _, def in ipairs(mDefs) do
        local part = Create("Frame", {
            Parent = ShieldOuter,
            Size = def.Size,
            Position = def.Position,
            BackgroundColor3 = LogoColor,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Rotation = def.Rotation,
            ZIndex = 52,
        })
        CreateCorner(part, 2)
        table.insert(mParts, part)
    end

    local LogoClick = Create("TextButton", {
        Parent = MinimizedLogo,
        Size = UDim2.new(1,0,1,0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 60,
    })

    local function AnimateLogoParts(alpha)
        Tween(ShieldStroke, {Transparency = alpha == 0 and 0.4 or 1}, 0.35)
        for _, p in ipairs(mParts) do
            Tween(p, {BackgroundTransparency = alpha}, 0.35)
        end
    end

    LogoClick.MouseEnter:Connect(function()
        for _, p in ipairs(mParts) do Tween(p, {BackgroundColor3 = LogoColorHover}, 0.2) end
        Tween(ShieldStroke, {Transparency = 0.6, Color = Color3.fromRGB(255, 255, 255)}, 0.2)
        Tween(MinimizedLogo, {BackgroundColor3 = Colors.BackgroundLighter}, 0.2)
    end)
    LogoClick.MouseLeave:Connect(function()
        for _, p in ipairs(mParts) do Tween(p, {BackgroundColor3 = LogoColor}, 0.2) end
        Tween(ShieldStroke, {Transparency = 0.4, Color = Color3.fromRGB(255, 255, 255)}, 0.2)
        Tween(MinimizedLogo, {BackgroundColor3 = Colors.Background}, 0.2)
    end)

    local logoDragging, logoDragStart, logoStartPos, logoHasMoved = false, nil, nil, false
    -- Simpan posisi logo terakhir yang diketahui (nil = belum pernah minimize/drag)
    local lastLogoPosition = nil
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
                local newPos = UDim2.new(logoStartPos.X.Scale, logoStartPos.X.Offset + delta.X, logoStartPos.Y.Scale, logoStartPos.Y.Offset + delta.Y)
                MinimizedLogo.Position = newPos
                lastLogoPosition = newPos  -- update posisi terakhir saat drag
            end
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then logoDragging = false end
    end)

    -- ====================== WINDOW DRAG ======================
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

    -- ====================== MINIMIZE / RESTORE ======================
    local minimized = false

    local function DoMinimize()
        minimized = true
        local ap = MainFrame.AbsolutePosition
        local as = MainFrame.AbsoluteSize
        local cx = ap.X + as.X / 2
        local cy = ap.Y + as.Y / 2
        -- Gunakan posisi logo terakhir jika sudah pernah di-drag, otherwise pakai tengah window
        local targetLogoPos = lastLogoPosition or UDim2.new(0, cx - 30, 0, cy - 30)
        MinimizedLogo.Position = targetLogoPos
        -- Animasikan MainFrame menyusut ke posisi logo, bukan selalu ke tengah
        local logoX = targetLogoPos.X.Offset
        local logoY = targetLogoPos.Y.Offset
        Tween(MainFrame, {Size = UDim2.new(0,60,0,60), Position = UDim2.new(0, logoX, 0, logoY)}, 0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
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
        minimized = false
        -- Simpan posisi logo saat ini sebelum disembunyikan (termasuk hasil drag terakhir)
        lastLogoPosition = MinimizedLogo.Position
        AnimateLogoParts(1)
        Tween(MinimizedLogo, {BackgroundTransparency = 1}, 0.25)
        task.delay(0.2, function()
            MinimizedLogo.Visible = false
            TopBar.Visible = true
            Sidebar.Visible = true
            ContentArea.Visible = true
            MainFrame.BackgroundTransparency = 0
            -- Snap MainFrame ke posisi logo terlebih dahulu agar animasi expand berasal dari sana
            MainFrame.Size = UDim2.new(0, 60, 0, 60)
            MainFrame.Position = lastLogoPosition
            Tween(MainFrame, {Size = originalSize, Position = UDim2.new(0.5,-450,0.5,-300)}, 0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        end)
    end

    MinimizeButton.MouseButton1Click:Connect(function()
        if minimized then DoRestore() else DoMinimize() end
    end)
    LogoClick.MouseButton1Click:Connect(function()
        if minimized and not logoHasMoved then DoRestore() end
    end)

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
        Tween(MainFrame, {Size=UDim2.new(0,900,0,0)}, 0.3)
        task.wait(0.3)
        ScreenGui:Destroy()
    end)

    -- ====================== KEYBINDS ======================
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.Insert then
            if minimized then DoRestore() else DoMinimize() end
        end
        if input.KeyCode == Enum.KeyCode.F then
            States.fly = not States.fly
            Notify("Player", "Fly " .. (States.fly and "ON" or "OFF"), States.fly and Colors.Success or Colors.TextMuted)
        end
    end)

    -- ====================== LOADING SCREEN ======================
    local loadSteps = {
        {text = "Initializing core systems...", d = 0.3},
        {text = "Reading player attributes...", d = 0.3},
        {text = "Detecting PlotId = " .. MY_PLOT_ID .. "...", d = 0.3},
        {text = "Scanning backpack (Seeds, Pets, Gear)...", d = 0.4},
        {text = "Mapping Gardens.Plot" .. MY_PLOT_ID .. ".Plants...", d = 0.3},
        {text = "Locating Packet RemoteEvent...", d = 0.3},
        {text = "Building Farm & Harvest features...", d = 0.25},
        {text = "Building Shop & Auto-Buy...", d = 0.25},
        {text = "Building Sell & Bag Inspector...", d = 0.25},
        {text = "Building Pet Manager & Wild Pet Catcher...", d = 0.25},
        {text = "Building Visuals ESP system...", d = 0.25},
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
            MainFrame.Size = UDim2.new(0, 900, 0, 0)
            Tween(MainFrame, {Size = originalSize}, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

            task.wait(0.3)
            SetActivePage("Farm")

            task.wait(0.8)
            local remoteStatus = ctx.PacketRemote and "Remote" or "Remote \226\154\160 (check console)"
            Notify("Miracle Hub", "Loaded! Plot " .. MY_PLOT_ID .. " | " .. remoteStatus .. " | [Insert] toggle | [F] fly", Colors.Success, 6)
        end
    end)

    print("[Miracle Hub] Full modular build loaded \226\128\148 Player: " .. player.Name)
    print("[Miracle Hub] Keybinds: [Insert] = toggle GUI | [F] = toggle Fly")

    return ctx
end