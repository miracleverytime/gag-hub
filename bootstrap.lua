-- ======================================================================
-- Miracle Hub — bootstrap.lua
-- Final wiring module. Loaded LAST (after core, ui, logic, pages).
--
-- Wires: sidebar buttons, search, window drag, minimize/restore + M logo,
--   confirm-close modal, keybinds, and the loading sequence that reveals
--   the window and calls SetActivePage("Automatic").
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
    local DragHandle     = ctx.DragHandle or TopBar
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

    -- ====================== SIDEBAR CONNECTIONS (RESTRUCTURED - 5 pages) ======================
    local pageMap = {
        [sb.Automatic] = "Automatic",
        [sb.Inventory] = "Inventory",
        [sb.Show] = "Show",
        [sb.Misc] = "Misc",
        [sb.Settings] = "Settings",
    }
    for btn, pageName in pairs(pageMap) do
        btn.MouseButton1Click:Connect(function()
            SetActivePage(pageName)
        end)
    end

    -- ====================== SEARCH FUNCTIONALITY (RESTRUCTURED) ======================
    local searchAllItems = {
        {"auto plant", "Automatic"}, {"plant seed", "Automatic"}, {"auto harvest", "Automatic"}, {"harvest", "Automatic"},
        {"water", "Automatic"}, {"sprinkler", "Automatic"}, {"farming", "Automatic"},
        {"auto buy", "Automatic"}, {"buy seed", "Automatic"}, {"crate", "Automatic"}, {"shop", "Automatic"},
        {"auto buy crate", "Automatic"}, {"open crate", "Automatic"}, {"shopping", "Automatic"},
        {"sell", "Automatic"}, {"auto sell", "Automatic"}, {"selling", "Automatic"},
        {"pet", "Inventory"}, {"wild pet", "Inventory"}, {"bunny", "Inventory"}, {"frog", "Inventory"},
        {"catch", "Automatic"}, {"auto catch", "Automatic"},
        {"bag", "Inventory"}, {"fruit", "Inventory"}, {"inventory", "Inventory"}, {"backpack", "Inventory"},
        {"inspect", "Inventory"}, {"scan", "Inventory"},
        {"walk", "Misc"}, {"speed", "Misc"}, {"fly", "Misc"}, {"jump", "Misc"}, {"movement", "Misc"},
        {"esp", "Show"}, {"highlight", "Show"}, {"visual", "Show"}, {"stats", "Show"},
        {"mailbox", "Misc"}, {"gift", "Automatic"}, {"server", "Misc"}, {"rejoin", "Automatic"},
        {"settings", "Settings"}, {"config", "Settings"},
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
    -- Hoisted so CloseButton / keybinds (outside the platform branch) can call them.
    local DoMinimize, DoRestore

    if ctx.isMobile then
        -- ====================== MOBILE MINIMIZE (BrandCard Pill) ======================
        -- Saat minimize, MainFrame disembunyikan & diganti dengan pill berisi
        -- BrandCard only (MIRACLEHUB | FPS | MS) — mirip desktop MinimizedPill
        -- tapi ukuran mobile & touch-optimized.
        -- Referensi: bootstrap.lua desktop pill (PILL_W=304, PILL_H=30) &
        -- ui.mobile.lua BrandCard (200×26, TextSize 10).

        local PILL_W = 200
        local PILL_H = 26
        local LIME_HEX_LOCAL = "#4DD6C9"

        -- Container transparan dengan padding 10px semua sisi untuk hit area drag
        local MinimizedPill = Create("Frame", {
            Name = "MinimizedPill",
            Parent = ScreenGui,
            Size = UDim2.new(0, PILL_W + 20, 0, PILL_H + 20),
            Position = UDim2.new(1, -80, 1, -80),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 50,
        })

        -- Visual pill — ukuran & warna identik BrandCard di ui.mobile.lua
        -- Start transparan (alpha 1) seperti desktop; fade in saat minimize selesai.
        local PillInner = Create("Frame", {
            Name = "PillInner",
            Parent = MinimizedPill,
            Size = UDim2.new(0, PILL_W, 0, PILL_H),
            Position = UDim2.new(0, 10, 0, 10),
            BackgroundColor3 = Colors.BackgroundLighter,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 51,
        })
        CreateCorner(PillInner, 6)
        local PillStroke = CreateStroke(PillInner, Colors.Border, 1)
        PillStroke.Transparency = 1

        -- Logo (identik ui.mobile.lua: 14×14, x=5)
        local PillLogoIcon = Create("ImageLabel", {
            Parent = PillInner,
            Size = UDim2.new(0, 14, 0, 14),
            Position = UDim2.new(0, 5, 0.5, -7),
            BackgroundTransparency = 1,
            Image = "rbxassetid://74186782815011",
            ImageTransparency = 1,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 52,
        })

        -- BrandSeg (identik ui.mobile.lua: 62px, x=22, TextSize 10)
        local PillBrand = Create("TextLabel", {
            Parent = PillInner,
            Size = UDim2.new(0, 62, 1, 0),
            Position = UDim2.new(0, 22, 0, 0),
            BackgroundTransparency = 1,
            RichText = true,
            Text = 'MIRACLE<font color="' .. LIME_HEX_LOCAL .. '">HUB</font>',
            TextColor3 = Colors.TextPrimary,
            TextTransparency = 1,
            TextSize = 10,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 52,
        })

        -- Divider 1 (identik ui.mobile.lua: x=87)
        local PillDiv1 = Create("Frame", {
            Parent = PillInner,
            Size = UDim2.new(0, 1, 1, -6),
            Position = UDim2.new(0, 87, 0, 3),
            BackgroundColor3 = Color3.fromRGB(58, 68, 80),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 52,
        })

        -- FPS icon (identik ui.mobile.lua: 11×11, x=95)
        local PillFpsIcon = Create("ImageLabel", {
            Parent = PillInner,
            Size = UDim2.new(0, 11, 0, 11),
            Position = UDim2.new(0, 95, 0.5, -5),
            BackgroundTransparency = 1,
            Image = "rbxassetid://104426509560089",
            ImageColor3 = Colors.Accent,
            ImageTransparency = 1,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 52,
        })

        -- FpsSeg (identik ui.mobile.lua: 30px, x=107, TextSize 10)
        local PillFps = Create("TextLabel", {
            Parent = PillInner,
            Size = UDim2.new(0, 30, 1, 0),
            Position = UDim2.new(0, 107, 0, 0),
            BackgroundTransparency = 1,
            RichText = true,
            Text = '<font color="#71717A">FPS</font><font size="3"> </font><font color="' .. LIME_HEX_LOCAL .. '">--</font>',
            TextColor3 = Colors.TextSecondary,
            TextTransparency = 1,
            TextSize = 10,
            Font = Enum.Font.Code,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 52,
        })

        -- Divider 2 (identik ui.mobile.lua: x=139)
        local PillDiv2 = Create("Frame", {
            Parent = PillInner,
            Size = UDim2.new(0, 1, 1, -6),
            Position = UDim2.new(0, 139, 0, 3),
            BackgroundColor3 = Color3.fromRGB(58, 68, 80),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 52,
        })

        -- MS icon (identik ui.mobile.lua: 11×11, x=147)
        local PillMsIcon = Create("ImageLabel", {
            Parent = PillInner,
            Size = UDim2.new(0, 11, 0, 11),
            Position = UDim2.new(0, 147, 0.5, -5),
            BackgroundTransparency = 1,
            Image = "rbxassetid://84466565972313",
            ImageColor3 = Colors.Accent,
            ImageTransparency = 1,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 52,
        })

        -- MsSeg (identik ui.mobile.lua: 32px, x=161, TextSize 10)
        local PillMs = Create("TextLabel", {
            Parent = PillInner,
            Size = UDim2.new(0, 32, 1, 0),
            Position = UDim2.new(0, 161, 0, 0),
            BackgroundTransparency = 1,
            RichText = true,
            Text = '<font color="#71717A">MS</font><font size="3"> </font>--',
            TextColor3 = Colors.TextSecondary,
            TextTransparency = 1,
            TextSize = 10,
            Font = Enum.Font.Code,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 52,
        })

        -- Sync FPS/MS live dari ctx (update tiap 0.5s saat pill visible)
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

        -- Fade functions (identik desktop TweenPillTransparency)
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

        -- lastPillPosition: diingat saat drag / restore (pola desktop)
        -- Restore selalu ke tengah; minimize berikutnya kembali ke posisi pill terakhir.
        local lastPillPosition = nil

        -- ====================== MOBILE MINIMIZE / RESTORE ======================
        -- Animasi 1:1 mirror desktop: content fade → TopBar shrink → MainFrame
        -- shrink ke pill → pill appear + breathing. Restore: expand + fade-in content.
        -- Input touch/drag tetap di blok terpisah di bawah (tidak diubah).

        local function StartPillBreathing()
            task.spawn(function()
                while minimized and MinimizedPill.Parent do
                    Tween(PillStroke, {Color = Colors.Accent, Transparency = 0, Thickness = 2}, 1.0,
                        Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
                    task.wait(1.1)
                    if not minimized then break end
                    Tween(PillStroke, {Transparency = 0.85}, 1.2,
                        Enum.EasingStyle.Sine, Enum.EasingDirection.In)
                    task.wait(1.3)
                    if not minimized then break end
                    Tween(PillStroke, {Transparency = 0, Thickness = 2}, 0.9,
                        Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
                    task.wait(1.0)
                end
                if PillStroke and PillStroke.Parent then
                    Tween(PillStroke, {Color = Colors.Border, Transparency = 0, Thickness = 1}, 0.3)
                end
            end)
        end

        local function DefaultPillPosition()
            -- BrandCard centered di TopBar MainFrame (42px) → Y = mf.Y + 8
            -- MinimizedPill padding 10px → offset -10
            local mfPos  = MainFrame.AbsolutePosition
            local mfSize = MainFrame.AbsoluteSize
            return UDim2.fromOffset(
                math.floor(mfPos.X + (mfSize.X - PILL_W) / 2 - 10),
                math.floor(mfPos.Y + 8 - 10)
            )
        end

        local function CenterMainFramePosition()
            local vp = ScreenGui.AbsoluteSize
            local mfW = vp.X * originalSize.X.Scale + originalSize.X.Offset
            local mfH = vp.Y * originalSize.Y.Scale + originalSize.Y.Offset
            local x = math.floor((vp.X - mfW) / 2 + 0.5)
            local y = math.floor((vp.Y - mfH) / 2 + 0.5)
            return UDim2.fromOffset(x, y)
        end

        local transparencySnapshot = {}
        local function BuildSnapshot()
            transparencySnapshot = {}
            local targets = {ContentArea, Sidebar}
            for _, root in ipairs(targets) do
                if root then
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
            end
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

        -- Layout asli (sebelum animasi minimize) — wajib di-reset setelah min/max
        -- supaya tidak ada gap antara TopBar (42) vs Sidebar/Content (Y=TOPBAR_H).
        local layoutTopBarSize   = TopBar.Size
        local layoutTopBarPos    = TopBar.Position
        local layoutSidebarSize  = Sidebar and Sidebar.Size or nil
        local layoutSidebarPos   = Sidebar and Sidebar.Position or nil
        local layoutContentSize  = ContentArea and ContentArea.Size or nil
        local layoutContentPos   = ContentArea and ContentArea.Position or nil

        local activeTopBarTween, activeMainFrameTween = nil, nil
        local function CancelLayoutTweens()
            if activeTopBarTween then pcall(function() activeTopBarTween:Cancel() end) activeTopBarTween = nil end
            if activeMainFrameTween then pcall(function() activeMainFrameTween:Cancel() end) activeMainFrameTween = nil end
        end

        local function ResetMobileShellLayout()
            CancelLayoutTweens()
            TopBar.Size     = layoutTopBarSize
            TopBar.Position = layoutTopBarPos
            if Sidebar and layoutSidebarSize then
                Sidebar.Size     = layoutSidebarSize
                Sidebar.Position = layoutSidebarPos
            end
            if ContentArea and layoutContentSize then
                ContentArea.Size     = layoutContentSize
                ContentArea.Position = layoutContentPos
            end
        end

        -- DoMinimize / DoRestore — timing & easing identik desktop
        -- MY_SESSION: guard semua task.delay supaya callback dari inject lama
        -- tidak mengacak-acak GUI inject baru saat reinject.
        local MY_SESSION = ctx.SESSION

        DoMinimize = function()
            if minimized then return end
            minimized = true
            ctx.isMinimized = true

            local targetPillPos = lastPillPosition or DefaultPillPosition()
            local pillAbsX = targetPillPos.X.Offset + 10 + PILL_W / 2
            local pillAbsY = targetPillPos.Y.Offset + 10 + PILL_H / 2

            BuildSnapshot()

            FadeButton(MinimizeButton, 0.06)
            FadeButton(CloseButton,    0.06)
            FadeOutContent(0.12)

            task.delay(0.10, function()
                if _G._MiracleHubSession ~= MY_SESSION then return end
                if not minimized then return end
                activeTopBarTween = Tween(TopBar, {
                    Size     = UDim2.new(layoutTopBarSize.X.Scale, layoutTopBarSize.X.Offset, 0, PILL_H),
                    Position = UDim2.new(layoutTopBarPos.X.Scale, layoutTopBarPos.X.Offset, 0, 0),
                }, 0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
                activeMainFrameTween = Tween(MainFrame, {
                    Size     = UDim2.new(0, PILL_W, 0, PILL_H),
                    Position = UDim2.new(0, pillAbsX - PILL_W/2, 0, pillAbsY - PILL_H/2),
                }, 0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
            end)

            task.delay(0.47, function()
                if _G._MiracleHubSession ~= MY_SESSION then return end
                if not minimized then return end
                MinimizedPill.Position = targetPillPos
                SetPillTransparency(0)
                MinimizedPill.Visible = true
                StartPillBreathing()
                if Sidebar then Sidebar.Visible = false end
                if ContentArea then ContentArea.Visible = false end
                MainFrame.Visible = false
                RestoreFromSnapshot(0)
                -- Hard-reset shell layout SEBELUM MainFrame invisible dibiarkan
                -- (tween TopBar → PILL_H bisa nyangkut jika di-cancel/race)
                ResetMobileShellLayout()
            end)
        end

        DoRestore = function()
            if not minimized then return end
            minimized = false

            lastPillPosition = MinimizedPill.Position
            local pillAbsX = lastPillPosition.X.Offset + 10 + PILL_W / 2
            local pillAbsY = lastPillPosition.Y.Offset + 10 + PILL_H / 2

            FadeOutContent(0)

            -- Reset layout dulu (cancel residual TopBar tween) supaya gap hilang
            ResetMobileShellLayout()

            if Sidebar then Sidebar.Visible = true end
            if ContentArea then ContentArea.Visible = true end
            MainFrame.Size     = UDim2.new(0, PILL_W, 0, PILL_H)
            MainFrame.Position = UDim2.new(0, pillAbsX - PILL_W/2, 0, pillAbsY - PILL_H/2)
            MainFrame.Visible  = true
            MinimizedPill.Visible = false

            -- Expand ke tengah (mobile default), bukan fixed 900×600 desktop
            local centerPos = CenterMainFramePosition()
            activeMainFrameTween = Tween(MainFrame, {
                Size     = originalSize,
                Position = centerPos,
            }, 0.40, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

            task.delay(0.20, function()
                if _G._MiracleHubSession ~= MY_SESSION then return end
                if minimized then return end
                RestoreFromSnapshot(0.18)
            end)

            task.delay(0.45, function()
                if _G._MiracleHubSession ~= MY_SESSION then return end
                if minimized then return end
                -- Pastikan layout shell masih original setelah expand selesai
                ResetMobileShellLayout()
                if ctx._setUserHasDragged then ctx._setUserHasDragged(false) end
                ctx.isMinimized = false
                -- pcall: guard kalau MainFrame sudah di-Destroy oleh reinject
                pcall(function()
                    if ctx.SnapMainFramePosition then ctx.SnapMainFramePosition() end
                end)
            end)
        end

        MinimizeButton.MouseButton1Click:Connect(DoMinimize)

        -- Tap-to-restore + touch drag
        local pillClick = Create("TextButton", {
            Parent = MinimizedPill,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            ZIndex = 60,
            AutoButtonColor = false,
            Active = true,
        })

        -- Drag logic (touch + mouse) — simpan lastPillPosition saat digeser
        local pillDragging, pillDragStart, pillStartPos, pillHasMoved = false, nil, nil, false
        pillClick.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch
                or input.UserInputType == Enum.UserInputType.MouseButton1 then
                pillDragging = true
                pillHasMoved = false
                pillDragStart = input.Position
                pillStartPos = MinimizedPill.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        pillDragging = false
                        if pillHasMoved then
                            lastPillPosition = MinimizedPill.Position
                        elseif minimized then
                            DoRestore()
                        end
                    end
                end)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if pillDragging and (input.UserInputType == Enum.UserInputType.Touch
                or input.UserInputType == Enum.UserInputType.MouseMovement) then
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

        -- ====================== DESKTOP MINIMIZE / RESTORE ======================
        -- Efek "sedot": MainFrame shrink ke pill, konten fade out.
        -- Saat restore, pill expand balik ke full window.
        local function StartPillBreathing()
            task.spawn(function()
                while minimized and MinimizedPill.Parent do
                    Tween(PillStroke, {Color = Colors.Accent, Transparency = 0, Thickness = 2}, 1.0,
                        Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
                    task.wait(1.1)
                    if not minimized then break end
                    Tween(PillStroke, {Transparency = 0.85}, 1.2,
                        Enum.EasingStyle.Sine, Enum.EasingDirection.In)
                    task.wait(1.3)
                    if not minimized then break end
                    Tween(PillStroke, {Transparency = 0, Thickness = 2}, 0.9,
                        Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
                    task.wait(1.0)
                end
                if PillStroke and PillStroke.Parent then
                    Tween(PillStroke, {Color = Colors.Border, Transparency = 0, Thickness = 1}, 0.3)
                end
            end)
        end

        local function DefaultPillPosition()
            local vp = ScreenGui.AbsoluteSize
            local cx = math.floor(vp.X / 2 - PILL_W / 2 - 10 + 0.5)
            return UDim2.new(0, cx, 0, 10)
        end

        local transparencySnapshot = {}
        local function BuildSnapshot()
            transparencySnapshot = {}
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

        -- MY_SESSION_DESK: guard task.delay desktop supaya callback lama
        -- tidak mengacak-acak GUI inject baru saat reinject.
        local MY_SESSION_DESK = ctx.SESSION

        DoMinimize = function()
            if minimized then return end
            minimized = true
            ctx.isMinimized = true

            local targetPillPos = lastPillPosition or DefaultPillPosition()
            local pillAbsX = targetPillPos.X.Offset + 10 + PILL_W / 2
            local pillAbsY = targetPillPos.Y.Offset + 10 + PILL_H / 2

            local topBarOriginalPos  = TopBar.Position
            local topBarOriginalSize = TopBar.Size

            BuildSnapshot()

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
            FadeOutContent(0.12)

            task.delay(0.10, function()
                if _G._MiracleHubSession ~= MY_SESSION_DESK then return end
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

            task.delay(0.47, function()
                if _G._MiracleHubSession ~= MY_SESSION_DESK then return end
                if not minimized then return end
                MinimizedPill.Position = targetPillPos
                SetPillTransparency(0)
                MinimizedPill.Visible = true
                StartPillBreathing()
                Sidebar.Visible     = false
                ContentArea.Visible = false
                MainFrame.Visible   = false
                RestoreFromSnapshot(0)
                TopBar.Size     = topBarOriginalSize
                TopBar.Position = topBarOriginalPos
            end)
        end

        DoRestore = function()
            if not minimized then return end
            minimized = false

            lastPillPosition = MinimizedPill.Position
            local pillAbsX = lastPillPosition.X.Offset + 10 + PILL_W / 2
            local pillAbsY = lastPillPosition.Y.Offset + 10 + PILL_H / 2

            FadeOutContent(0)

            Sidebar.Visible     = true
            ContentArea.Visible = true
            MainFrame.Size     = UDim2.new(0, PILL_W, 0, PILL_H)
            MainFrame.Position = UDim2.new(0, pillAbsX - PILL_W/2, 0, pillAbsY - PILL_H/2)
            MainFrame.Visible  = true
            MinimizedPill.Visible = false

            Tween(MainFrame, {
                Size     = originalSize,
                Position = UDim2.new(0.5, -450, 0.5, -300),
            }, 0.40, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

            task.delay(0.20, function()
                if _G._MiracleHubSession ~= MY_SESSION_DESK then return end
                if minimized then return end
                RestoreFromSnapshot(0.18)
            end)

            task.delay(0.45, function()
                if _G._MiracleHubSession ~= MY_SESSION_DESK then return end
                ctx.isMinimized = false
                pcall(function()
                    ctx.SnapMainFramePosition()
                end)
            end)
        end

        MinimizeButton.MouseButton1Click:Connect(function()
            if minimized then DoRestore() else DoMinimize() end
        end)
        PillClick.MouseButton1Click:Connect(function()
            if minimized and not pillHasMoved then DoRestore() end
        end)
    end -- end if ctx.isMobile/else untuk minimize

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
        if minimized then return end
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
        -- Use a concrete TextButton target. Some mobile executors do not
        -- propagate TouchStarted from non-interactive Frames consistently.
        local dragInput = nil
        DragHandle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                BeginDrag(input.Position)
                if input.UserInputType == Enum.UserInputType.Touch then
                    dragInput = input
                end
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                        dragInput = nil
                    end
                end)
            end
        end)
        DragHandle.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input == dragInput then
                MoveDrag(input.Position)
            end
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

    -- ====================== CONFIRM CLOSE MODAL ======================
    -- Desktop: 380×200. Mobile: compact 240×148 agar tidak hampir seukuran menu.
    local confW, confH, confPad, confGap, confTitleSz, confBodySz, confBtnW, confBtnH, confCorner
    if ctx.isMobile then
        confW, confH, confPad, confGap = 240, 148, 14, 8
        confTitleSz, confBodySz = 15, 11
        confBtnW, confBtnH, confCorner = 88, 32, 10
    else
        confW, confH, confPad, confGap = 380, 200, 24, 10
        confTitleSz, confBodySz = 20, 13
        confBtnW, confBtnH, confCorner = 110, 36, 16
    end
    local confTargetSize = UDim2.new(0, confW, 0, confH)

    -- Overlay transparan (tanpa shadow/dim). Pop animasi pakai UIScale
    -- supaya ukuran box tetap → wrap teks tidak bergeser saat muncul.
    local ConfirmModal = Create("Frame", {
        Parent = ScreenGui,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 1000,
    })
    local ConfirmBox = Create("Frame", {
        Parent = ConfirmModal,
        Size = confTargetSize,
        Position = UDim2.new(0.5, -math.floor(confW / 2), 0.5, -math.floor(confH / 2)),
        BackgroundColor3 = Colors.BackgroundLight,
        BorderSizePixel = 0,
        ZIndex = 1001,
    })
    CreateCorner(ConfirmBox, confCorner)
    CreateStroke(ConfirmBox, Colors.Border, 1)
    local ConfScale = Instance.new("UIScale")
    ConfScale.Scale = 1
    ConfScale.Parent = ConfirmBox

    local confContent = Create("Frame", {
        Parent = ConfirmBox,
        Size = UDim2.new(1, -confPad * 2, 1, -confPad * 2),
        Position = UDim2.new(0, confPad, 0, confPad),
        BackgroundTransparency = 1,
        ZIndex = 1002,
    })
    Create("UIListLayout", {
        Parent = confContent,
        Padding = UDim.new(0, confGap),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    Create("TextLabel", {
        Parent = confContent,
        Size = UDim2.new(1, 0, 0, ctx.isMobile and 20 or 28),
        BackgroundTransparency = 1,
        Text = "Close Miracle Hub?",
        TextColor3 = Colors.TextPrimary,
        TextSize = confTitleSz,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        LayoutOrder = 1,
        ZIndex = 1002,
    })
    -- Body: fixed 2-line break via RichText newline agar wrap tidak berubah
    Create("TextLabel", {
        Parent = confContent,
        Size = UDim2.new(1, 0, 0, ctx.isMobile and 34 or 36),
        BackgroundTransparency = 1,
        RichText = true,
        Text = ctx.isMobile
            and "All automation loops will stop.<br/>Re-inject to use again."
            or "All automation loops will stop. Re-inject to use again.",
        TextColor3 = Colors.TextSecondary,
        TextSize = confBodySz,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = true,
        LayoutOrder = 2,
        ZIndex = 1002,
    })
    local btnRow = Create("Frame", {
        Parent = confContent,
        Size = UDim2.new(1, 0, 0, confBtnH + 2),
        BackgroundTransparency = 1,
        LayoutOrder = 3,
        ZIndex = 1002,
    })
    Create("UIListLayout", {
        Parent = btnRow,
        Padding = UDim.new(0, ctx.isMobile and 8 or 12),
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
    })
    local ConfYes = Create("TextButton", {
        Parent = btnRow,
        Size = UDim2.new(0, confBtnW, 0, confBtnH),
        BackgroundColor3 = Color3.fromRGB(180, 80, 80),
        Text = "Yes, Close",
        TextColor3 = Colors.TextPrimary,
        TextSize = ctx.isMobile and 12 or 13,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
        ZIndex = 1002,
        AutoButtonColor = false,
    })
    CreateCorner(ConfYes, 8)
    local ConfNo = Create("TextButton", {
        Parent = btnRow,
        Size = UDim2.new(0, confBtnW, 0, confBtnH),
        BackgroundColor3 = Colors.Surface,
        Text = "Cancel",
        TextColor3 = Colors.TextPrimary,
        TextSize = ctx.isMobile and 12 or 13,
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
        ConfirmBox.Size = confTargetSize
        ConfirmBox.Position = UDim2.new(0.5, -math.floor(confW / 2), 0.5, -math.floor(confH / 2))
        ConfScale.Scale = 0.85
        ConfirmModal.Visible = true
        Tween(ConfScale, {Scale = 1}, 0.3, Enum.EasingStyle.Back)
    end)
    ConfNo.MouseButton1Click:Connect(function()
        Tween(ConfScale, {Scale = 0.9}, 0.15)
        task.wait(0.15)
        ConfirmModal.Visible = false
        ConfScale.Scale = 1
    end)
    ConfYes.MouseButton1Click:Connect(function()
        Tween(ConfScale, {Scale = 0.9}, 0.12)
        task.wait(0.12)
        ConfirmModal.Visible = false
        local collapseSize = ctx.isMobile
            and UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, 0)
            or UDim2.new(0, 900, 0, 0)
        Tween(MainFrame, {Size = collapseSize}, 0.3)
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
    -- SESSION_REVEAL: guard seluruh sequence supaya reinject cepat tidak
    -- menjalankan reveal dari sesi lama setelah GUI baru sudah terbentuk.
    do
        local SESSION_REVEAL = ctx.SESSION

        -- Snap bar ke 100% dengan tween singkat (biar smooth dari ~83% ke 100%)
        Tween(LoadingBarFill, {Size = UDim2.new(1, 0, 1, 0)}, 0.3)
        LoadingPercent.Text = "100%"
        LoadingStatus.Text  = "Ready!"

        task.wait(0.5)
        if _G._MiracleHubSession ~= SESSION_REVEAL then return end

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
        if _G._MiracleHubSession ~= SESSION_REVEAL then return end
        LoadingScreen:Destroy()

        -- Reveal main window
        MainFrame.Visible = true
        -- Keep the mobile/desktop target width during the reveal animation.
        -- A hardcoded 900px here briefly forced the mobile window to desktop width.
        MainFrame.Size    = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, 0)
        Tween(MainFrame, {Size = originalSize}, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

        task.wait(0.3)
        if _G._MiracleHubSession ~= SESSION_REVEAL then return end
        SetActivePage("Automatic")

        task.wait(0.8)
        if _G._MiracleHubSession ~= SESSION_REVEAL then return end
        local remoteStatus = ctx.PacketRemote and "Remote" or "Remote \226\154\160 (check console)"
        local buildTag = ctx.isMobile and " | Mobile a36b029" or ""
        Notify("Miracle Hub", "Loaded! Plot " .. MY_PLOT_ID .. " | " .. remoteStatus .. buildTag .. " | [Insert] toggle | [F] fly", Colors.Success, 6)
    end

    return ctx
end