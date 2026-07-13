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

    -- ====================== MINIMIZED PILL BAR ======================
    -- Pill bar: clone visual dari BrandCard di TopBar (300×30, BackgroundLighter,
    -- corner 8, border Colors.Border, font identik). Saat minimize, MainFrame
    -- "menyedot" semua konten ke arah TopBar lalu mengecil jadi pill ini.
    -- Saat restore, pill "meledak" expand balik ke full window.
    --
    -- Pill ini hidup di ScreenGui (bukan di MainFrame) supaya bisa draggable
    -- bebas di luar bounds MainFrame.

    local PILL_W = 300
    local PILL_H = 30
    local LIME_HEX_LOCAL = "#A3E635"

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

    -- Segmen MIRACLEHUB (116px, identik BrandSeg)
    local PillBrand = Create("TextLabel", {
        Parent = PillInner,
        Size = UDim2.new(0, 116, 1, 0),
        BackgroundTransparency = 1,
        RichText = true,
        Text = 'MIRACLE<font color="' .. LIME_HEX_LOCAL .. '">HUB</font>',
        TextColor3 = Colors.TextPrimary,
        TextTransparency = 1,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 52,
    })

    -- Divider 1 (identik divider pertama di BrandCard)
    local PillDiv1 = Create("Frame", {
        Parent = PillInner,
        Size = UDim2.new(0, 1, 1, -10),
        Position = UDim2.new(0, 116, 0, 5),
        BackgroundColor3 = Colors.Border,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 52,
    })

    -- FPS icon (identik BrandCard: gauge/speedometer lucide, x=123)
    local PillFpsIcon = Create("ImageLabel", {
        Parent = PillInner,
        Size = UDim2.new(0, 13, 0, 13),
        Position = UDim2.new(0, 123, 0.5, -6),
        BackgroundTransparency = 1,
        Image = "rbxassetid://91865147593924",
        ImageColor3 = Colors.Accent,
        ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 52,
    })

    -- Segmen FPS (identik FpsSeg: x=145, w=79, TextXAlignment Left)
    local PillFps = Create("TextLabel", {
        Parent = PillInner,
        Size = UDim2.new(0, 79, 1, 0),
        Position = UDim2.new(0, 145, 0, 0),
        BackgroundTransparency = 1,
        RichText = true,
        Text = '<font color="#6A6D68">FPS</font>  <font color="' .. LIME_HEX_LOCAL .. '">--</font>',
        TextColor3 = Colors.TextSecondary,
        TextTransparency = 1,
        TextSize = 12,
        Font = Enum.Font.Code,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 52,
    })

    -- Divider 2 (identik BrandCard: x=209)
    local PillDiv2 = Create("Frame", {
        Parent = PillInner,
        Size = UDim2.new(0, 1, 1, -10),
        Position = UDim2.new(0, 209, 0, 5),
        BackgroundColor3 = Colors.Border,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 52,
    })

    -- MS icon (identik BrandCard: activity/waveform lucide, x=215)
    local PillMsIcon = Create("ImageLabel", {
        Parent = PillInner,
        Size = UDim2.new(0, 13, 0, 13),
        Position = UDim2.new(0, 215, 0.5, -6),
        BackgroundTransparency = 1,
        Image = "rbxassetid://90043289378344",
        ImageColor3 = Colors.Accent,
        ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 52,
    })

    -- Segmen MS (identik MsSeg: x=237, w=77, TextXAlignment Left)
    local PillMs = Create("TextLabel", {
        Parent = PillInner,
        Size = UDim2.new(0, 77, 1, 0),
        Position = UDim2.new(0, 237, 0, 0),
        BackgroundTransparency = 1,
        RichText = true,
        Text = '<font color="#6A6D68">MS</font>  --',
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
                PillFps.Text = '<font color="#6A6D68">FPS</font>  <font color="' .. LIME_HEX_LOCAL .. '">' .. fps .. '</font>'
                PillMs.Text  = '<font color="#6A6D68">MS</font>  ' .. string.format("%.1f", ping)
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
    end
    local function TweenPillTransparency(alpha, dur)
        dur = dur or 0.25
        Tween(PillInner,   {BackgroundTransparency = alpha}, dur)
        Tween(PillStroke,  {Transparency           = alpha}, dur)
        Tween(PillBrand,   {TextTransparency       = alpha}, dur)
        Tween(PillFps,     {TextTransparency       = alpha}, dur)
        Tween(PillMs,      {TextTransparency       = alpha}, dur)
        Tween(PillDiv1,    {BackgroundTransparency = alpha}, dur)
        Tween(PillDiv2,    {BackgroundTransparency = alpha}, dur)
        Tween(PillFpsIcon, {ImageTransparency      = alpha}, dur)
        Tween(PillMsIcon,  {ImageTransparency      = alpha}, dur)
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
    -- Efek "sedot": saat minimize, semua konten MainFrame seolah tersedot ke arah
    -- TopBar — frame menyusut dari full window ke ukuran pill (300×30) sambil
    -- konten fade out. Saat restore, pill meledak expand balik ke full window.
    --
    -- Pill muncul di posisi yang sama dengan BrandCard di TopBar (center screen, y=10).
    -- Setelah muncul, pill bisa di-drag bebas. Posisi drag disimpan di lastPillPosition
    -- dan dipakai sebagai titik asal animasi expand berikutnya.

    -- Breathing loop untuk PillStroke — lime glow seperti ConnDot saat minimized.
    -- Loop jalan di coroutine terpisah, berhenti begitu minimized = false.
    local function StartPillBreathing()
        task.spawn(function()
            while minimized and MinimizedPill.Parent do
                -- FASE 1: Border naik ke lime dominan, tebal, fully visible
                Tween(PillStroke, {Color = Colors.Accent, Transparency = 0, Thickness = 2}, 1.0,
                    Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
                task.wait(1.1)
                if not minimized then break end
                -- FASE 2: Fade out border perlahan hampir hilang
                Tween(PillStroke, {Transparency = 0.85}, 1.2,
                    Enum.EasingStyle.Sine, Enum.EasingDirection.In)
                task.wait(1.3)
                if not minimized then break end
                -- FASE 3: Fade in border kembali lime dominan
                Tween(PillStroke, {Transparency = 0, Thickness = 2}, 0.9,
                    Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
                task.wait(1.0)
            end
            -- Pastikan stroke kembali ke default saat loop berhenti
            if PillStroke and PillStroke.Parent then
                Tween(PillStroke, {Color = Colors.Border, Transparency = 0, Thickness = 1}, 0.3)
            end
        end)
    end
    -- selama animasi minimize/restore, AbsoluteSize MainFrame berubah dan bisa
    -- memicu snap ke tengah → blink. Flag ini mencegah hal itu.
    -- FIX: `minimized` was never declared — it silently read as nil (global) in
    -- Xeno's isolated environment, breaking DoMinimize/DoRestore state tracking.
    local minimized = false
    ctx.isMinimized = false

    -- Hitung posisi pill default: rata tengah viewport, y=10px dari atas.
    -- Ini meniru posisi BrandCard yang ada di tengah TopBar.
    local function DefaultPillPosition()
        local vp = ScreenGui.AbsoluteSize
        local cx = math.floor(vp.X / 2 - PILL_W / 2 - 10 + 0.5)  -- -10 utk offset container
        return UDim2.new(0, cx, 0, 10)
    end

    -- Snapshot transparansi asli semua elemen — diambil sekali, dipakai berulang kali.
    -- Kunci: instance reference (bukan nama), value: {bg, text, image} nilai aslinya.
    local transparencySnapshot = {}
    local function BuildSnapshot()
        transparencySnapshot = {}
        -- Snapshot ContentArea, Sidebar, plus MinimizeButton & CloseButton (di TopBar)
        local targets = {ContentArea, Sidebar}
        for _, root in ipairs(targets) do
            transparencySnapshot[root] = {bg = root.BackgroundTransparency}
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("GuiObject") then
                    local entry = {bg = d.BackgroundTransparency}
                    if d:IsA("TextLabel") or d:IsA("TextButton") then entry.text = d.TextTransparency end
                    if d:IsA("ImageLabel") or d:IsA("ImageButton") then entry.img = d.ImageTransparency end
                    transparencySnapshot[d] = entry
                end
            end
        end
        -- Tombol di TopBar: MinimizeButton & CloseButton + semua descendant-nya
        for _, btn in ipairs({MinimizeButton, CloseButton}) do
            if btn then
                local e = {bg = btn.BackgroundTransparency}
                if btn:IsA("TextLabel") or btn:IsA("TextButton") then e.text = btn.TextTransparency end
                if btn:IsA("ImageLabel") or btn:IsA("ImageButton") then e.img = btn.ImageTransparency end
                transparencySnapshot[btn] = e
                for _, d in ipairs(btn:GetDescendants()) do
                    if d:IsA("GuiObject") then
                        local de = {bg = d.BackgroundTransparency}
                        if d:IsA("TextLabel") or d:IsA("TextButton") then de.text = d.TextTransparency end
                        if d:IsA("ImageLabel") or d:IsA("ImageButton") then de.img = d.ImageTransparency end
                        transparencySnapshot[d] = de
                    end
                end
            end
        end
    end

    -- Terapkan snapshot (restore ke nilai asli), dengan optional tween duration
    local function RestoreFromSnapshot(duration)
        for obj, snap in pairs(transparencySnapshot) do
            if obj and obj.Parent then
                if duration and duration > 0 then
                    local props = {BackgroundTransparency = snap.bg}
                    if snap.text then props.TextTransparency  = snap.text end
                    if snap.img  then props.ImageTransparency = snap.img  end
                    Tween(obj, props, duration)
                else
                    obj.BackgroundTransparency = snap.bg
                    if snap.text then obj.TextTransparency  = snap.text end
                    if snap.img  then obj.ImageTransparency = snap.img  end
                end
            end
        end
    end

    -- Fade semua elemen ke fully transparan
    local function FadeOutContent(duration)
        for obj, _ in pairs(transparencySnapshot) do
            if obj and obj.Parent then
                local props = {BackgroundTransparency = 1}
                if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                    props.TextTransparency = 1
                end
                if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                    props.ImageTransparency = 1
                end
                Tween(obj, props, duration)
            end
        end
    end

    local function DoMinimize()
        minimized = true
        ctx.isMinimized = true

        local targetPillPos = lastPillPosition or DefaultPillPosition()
        local pillAbsX = targetPillPos.X.Offset + 10 + PILL_W / 2
        local pillAbsY = targetPillPos.Y.Offset + 10 + PILL_H / 2

        local topBarOriginalPos  = TopBar.Position
        local topBarOriginalSize = TopBar.Size

        -- Snapshot nilai transparansi asli sebelum diubah apapun
        BuildSnapshot()

        -- FASE 1 (0.00s): MinimizeButton & CloseButton hilang instan —
        -- keduanya paling kanan, paling terakhir ter-clip saat frame shrink ke kiri,
        -- jadi harus fade duluan sebelum animasi apapun dimulai.
        local function FadeButton(btn, dur)
            if not btn then return end
            Tween(btn, {BackgroundTransparency = 1}, dur)
            if btn:IsA("TextLabel") or btn:IsA("TextButton") then
                Tween(btn, {TextTransparency = 1}, dur)
            end
            if btn:IsA("ImageLabel") or btn:IsA("ImageButton") then
                Tween(btn, {ImageTransparency = 1}, dur)
            end
            for _, d in ipairs(btn:GetDescendants()) do
                if d:IsA("GuiObject") then
                    local props = {BackgroundTransparency = 1}
                    if d:IsA("TextLabel") or d:IsA("TextButton") then props.TextTransparency = 1 end
                    if d:IsA("ImageLabel") or d:IsA("ImageButton") then props.ImageTransparency = 1 end
                    Tween(d, props, dur)
                end
            end
        end
        FadeButton(MinimizeButton, 0.06)
        FadeButton(CloseButton,    0.06)

        -- Konten lainnya fade sedikit lebih lambat
        FadeOutContent(0.12)

        -- FASE 2 (0.10s): Frame mulai mengecil setelah konten hampir hilang
        task.delay(0.10, function()
            if not minimized then return end
            Tween(TopBar, {
                Size     = UDim2.new(topBarOriginalSize.X.Scale, topBarOriginalSize.X.Offset, 0, PILL_H),
                Position = UDim2.new(topBarOriginalPos.X.Scale, topBarOriginalPos.X.Offset, 0, 0),
            }, 0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
            Tween(MainFrame, {
                Size     = UDim2.new(0, PILL_W, 0, PILL_H),
                Position = UDim2.new(0, pillAbsX - PILL_W/2, 0, pillAbsY - PILL_H/2),
            }, 0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
        end)

        -- FASE 3 (0.47s): Shrink selesai → swap ke pill, restore transparansi asli (hidden)
        task.delay(0.47, function()
            if not minimized then return end

            MinimizedPill.Position = targetPillPos
            SetPillTransparency(0)
            MinimizedPill.Visible = true
            StartPillBreathing()  -- lime glow breathing mulai

            Sidebar.Visible     = false
            ContentArea.Visible = false
            MainFrame.Visible   = false

            -- Restore nilai asli (snap, bukan tween) — aman karena sudah hidden
            RestoreFromSnapshot(0)
            TopBar.Size     = topBarOriginalSize
            TopBar.Position = topBarOriginalPos
        end)
    end

    local function DoRestore()
        minimized = false

        lastPillPosition = MinimizedPill.Position
        local pillAbsX = lastPillPosition.X.Offset + 10 + PILL_W / 2
        local pillAbsY = lastPillPosition.Y.Offset + 10 + PILL_H / 2

        -- Set konten ke transparan dulu (dari nilai asli via snapshot → 1)
        -- Snapshot sudah ada dari DoMinimize terakhir, tinggal fade ke invisible
        FadeOutContent(0)  -- instant, karena belum visible

        -- FASE 1: Swap pill → MainFrame tanpa gap
        Sidebar.Visible     = true
        ContentArea.Visible = true
        MainFrame.Size     = UDim2.new(0, PILL_W, 0, PILL_H)
        MainFrame.Position = UDim2.new(0, pillAbsX - PILL_W/2, 0, pillAbsY - PILL_H/2)
        MainFrame.Visible  = true
        MinimizedPill.Visible = false

        -- FASE 2: Frame expand
        Tween(MainFrame, {
            Size     = originalSize,
            Position = UDim2.new(0.5, -450, 0.5, -300),
        }, 0.40, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

        -- FASE 3 (0.20s): Konten fade-in ke nilai aslinya masing-masing
        task.delay(0.20, function()
            if minimized then return end
            RestoreFromSnapshot(0.18)
        end)

        -- FASE 4: Clear guard
        task.delay(0.45, function()
            ctx.isMinimized = false
            ctx.SnapMainFramePosition()
        end)
    end

    MinimizeButton.MouseButton1Click:Connect(function()
        if minimized then DoRestore() else DoMinimize() end
    end)
    PillClick.MouseButton1Click:Connect(function()
        if minimized and not pillHasMoved then DoRestore() end
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
        MainFrame.Size    = UDim2.new(0, 900, 0, 0)
        Tween(MainFrame, {Size = originalSize}, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

        task.wait(0.3)
        SetActivePage("Profile")

        task.wait(0.8)
        local remoteStatus = ctx.PacketRemote and "Remote" or "Remote \226\154\160 (check console)"
        Notify("Miracle Hub", "Loaded! Plot " .. MY_PLOT_ID .. " | " .. remoteStatus .. " | [Insert] toggle | [F] fly", Colors.Success, 6)
    end

    return ctx
end