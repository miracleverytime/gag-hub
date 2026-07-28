-- ======================================================================
-- Miracle Hub — ui.mobile.lua
-- Mobile UI framework module. Loaded SECOND (after core) when
-- ctx.isMobile == true.
--
-- Visual language: same Neo palette as desktop, but fullscreen layout,
-- bottom tab bar instead of sidebar, touch-optimized (≥40px targets,
-- ≥13px text, no hover effects). All ctx signatures are IDENTICAL
-- to ui.lua — pages.lua and bootstrap.lua run unchanged.
-- ======================================================================

return function(ctx)
    local Colors             = ctx.Colors
    local States             = ctx.States
    local playerGui          = ctx.playerGui
    local player             = ctx.player
    local TweenService       = ctx.TweenService
    local UserInputService   = ctx.UserInputService
    local RunService         = ctx.RunService

    -- ====================== NEO PALETTE OVERRIDE ======================
    -- Identik dengan desktop ui.lua
    Colors.Background        = Color3.fromRGB(10, 13, 16)
    Colors.BackgroundLight   = Color3.fromRGB(18, 22, 27)
    Colors.BackgroundLighter = Color3.fromRGB(26, 31, 38)
    Colors.Surface           = Color3.fromRGB(32, 38, 46)
    Colors.SurfaceLight      = Color3.fromRGB(40, 48, 58)
    Colors.Border            = Color3.fromRGB(30, 37, 45)
    Colors.BorderLight       = Color3.fromRGB(40, 100, 95)
    Colors.TextPrimary       = Color3.fromRGB(209, 213, 219)
    Colors.TextSecondary     = Color3.fromRGB(148, 155, 165)
    Colors.TextMuted         = Color3.fromRGB(113, 113, 122)
    Colors.Accent            = Color3.fromRGB(77, 214, 201)
    Colors.Success           = Color3.fromRGB(77, 214, 201)
    Colors.Warning           = Color3.fromRGB(251, 191, 36)
    Colors.Error             = Color3.fromRGB(248, 113, 113)
    Colors.Electric          = Color3.fromRGB(56, 189, 248)
    Colors.Rainbow           = Color3.fromRGB(244, 114, 182)
    Colors.Frozen            = Color3.fromRGB(103, 232, 249)
    Colors.Gold              = Color3.fromRGB(250, 204, 21)
    Colors.ToggleOn          = Color3.fromRGB(77, 214, 201)
    Colors.ToggleOff         = Color3.fromRGB(30, 37, 45)
    Colors.ToggleKnob        = Color3.fromRGB(10, 13, 16)
    Colors.SliderTrack       = Color3.fromRGB(26, 31, 38)
    Colors.SliderFill        = Color3.fromRGB(77, 214, 201)

    local LIME_HEX   = "#4DD6C9"
    local FONT_MONO  = Enum.Font.Code
    local FONT_BODY  = Enum.Font.Gotham
    local FONT_BOLD  = Enum.Font.GothamBold

    -- Platform label
    ctx.Platform = "Mobile"

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
        if not instance then return end
        local ok, result = pcall(function()
            if not instance.Parent then return end
            local tween = TweenService:Create(
                instance,
                TweenInfo.new(duration or 0.3, easingStyle or Enum.EasingStyle.Quad, easingDirection or Enum.EasingDirection.Out),
                properties
            )
            tween:Play()
            return tween
        end)
        if ok then return result end
    end

    UI.Create           = Create
    UI.CreateCorner     = CreateCorner
    UI.CreateStroke     = CreateStroke
    UI.CreatePadding    = CreatePadding
    UI.CreateListLayout = CreateListLayout
    UI.Tween            = Tween

    -- ============ NOTIFICATION SYSTEM ============
    -- Identik dengan ui.lua (Terminal Line design)
    local NOTIF_W      = 340
    local NOTIF_H      = 54
    local NOTIF_GAP    = 8
    local NOTIF_MARGIN = 16
    local UNDERLINE_H  = 2

    local NOTIF_BORDER       = Color3.fromRGB(30, 37, 45)
    local NOTIF_BORDER_HOVER = Colors.BorderLight
    local NOTIF_TRACK        = Color3.fromRGB(20, 26, 32)

    local GLYPH_SUCCESS = utf8.char(0x2713)
    local GLYPH_WARN    = "!"
    local GLYPH_ERROR   = "\195\151"
    local GLYPH_INFO    = "\226\128\162"
    local SPIN_FRAMES   = {"|", "/", "-", "\\"}

    local HAIR = utf8.char(0x200A)
    local function TrackText(s)
        local out = {}
        for _, cp in utf8.codes(s) do
            out[#out + 1] = utf8.char(cp)
        end
        return table.concat(out, HAIR)
    end

    local activeNotifs = {}
    local function NotifSlotY(index)
        return NOTIF_MARGIN + (index - 1) * (NOTIF_H + NOTIF_GAP)
    end
    local function ReflowNotifs()
        local alive = {}
        for _, frame in ipairs(activeNotifs) do
            if frame and frame.Parent then
                alive[#alive + 1] = frame
            end
        end
        for i = #activeNotifs, 1, -1 do activeNotifs[i] = nil end
        for i, frame in ipairs(alive) do
            activeNotifs[i] = frame
            Tween(frame, {Position = UDim2.new(1, -(NOTIF_W + 10), 0, NotifSlotY(i))}, 0.25)
        end
    end

    local function Notify(title, message, color, duration, opts)
        if not States.showNotifications then return end
        opts     = opts or {}
        duration = duration or 4

        local gui = playerGui:FindFirstChild("MiracleHub")
        if not gui then return end

        local accent, glyph
        if color == Colors.Warning then
            accent, glyph = Colors.Warning, GLYPH_WARN
        elseif color == Colors.Error then
            accent, glyph = Colors.Error, GLYPH_ERROR
        elseif color == Colors.TextMuted or color == Colors.TextSecondary then
            accent, glyph = Colors.TextMuted, GLYPH_INFO
        elseif color then
            accent, glyph = color, GLYPH_INFO
        else
            accent, glyph = Colors.Accent, GLYPH_SUCCESS
        end
        if opts.glyph then glyph = opts.glyph end
        local titleColor = (accent == Colors.TextMuted) and Colors.TextPrimary or accent

        local loading = opts.loading == true

        local notifFrame = Create("Frame", {
            Name = "TerminalToast",
            Parent = gui,
            Size = UDim2.new(0, NOTIF_W, 0, NOTIF_H),
            Position = UDim2.new(1, 10, 0, NotifSlotY(#activeNotifs + 1)),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ClipsDescendants = false,
            ZIndex = 200,
        })
        local notifBg = Create("Frame", {
            Parent = notifFrame,
            Size = UDim2.new(1, 0, 1, 0),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundColor3 = Colors.BackgroundLighter,
            BorderSizePixel = 0,
            ZIndex = 200,
        })
        CreateCorner(notifBg, 6)
        local stroke = CreateStroke(notifBg, NOTIF_BORDER, 1)

        local accentBar = Create("Frame", {
            Parent = notifBg,
            Size = UDim2.new(0, 3, 1, -UNDERLINE_H),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundColor3 = accent,
            BorderSizePixel = 0,
            ZIndex = 201,
        })

        local glyphLabel = Create("TextLabel", {
            Parent = notifBg,
            Size = UDim2.new(0, 16, 0, 16),
            Position = UDim2.new(0, 15, 0, 11),
            BackgroundTransparency = 1,
            Text = glyph,
            TextColor3 = accent,
            TextSize = 13,
            Font = FONT_BOLD,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 201,
        })

        local titleRow = Create("Frame", {
            Parent = notifBg,
            Size = UDim2.new(1, -(41 + 46), 0, 14),
            Position = UDim2.new(0, 41, 0, 9),
            BackgroundTransparency = 1,
            ZIndex = 201,
        })
        CreateListLayout(titleRow, 6, Enum.FillDirection.Horizontal)
        local titleLabel = Create("TextLabel", {
            Parent = titleRow,
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 1,
            Text = TrackText(string.upper(title)),
            TextColor3 = titleColor,
            TextSize = 11,
            Font = FONT_BOLD,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 201,
        })
        local spinnerLabel = Create("TextLabel", {
            Parent = titleRow,
            Size = UDim2.new(0, 12, 1, 0),
            BackgroundTransparency = 1,
            Text = SPIN_FRAMES[1],
            TextColor3 = Colors.TextMuted,
            TextSize = 11,
            Font = FONT_MONO,
            Visible = loading,
            ZIndex = 201,
        })

        local countLabel = Create("TextLabel", {
            Parent = notifBg,
            Size = UDim2.new(0, 34, 0, 12),
            Position = UDim2.new(1, -46, 0, 10),
            BackgroundTransparency = 1,
            Text = loading and ".." or (tostring(duration) .. "s"),
            TextColor3 = Color3.new(1, 1, 1),
            TextTransparency = 0.75,
            TextSize = 10,
            Font = FONT_MONO,
            TextXAlignment = Enum.TextXAlignment.Right,
            ZIndex = 201,
        })

        local msgLabel = Create("TextLabel", {
            Parent = notifBg,
            Size = UDim2.new(1, -(41 + 14), 0, 16),
            Position = UDim2.new(0, 41, 0, 26),
            BackgroundTransparency = 1,
            Text = message,
            TextColor3 = Colors.TextMuted,
            TextSize = 12,
            Font = FONT_MONO,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 201,
        })

        local track = Create("Frame", {
            Parent = notifBg,
            Size = UDim2.new(1, 0, 0, UNDERLINE_H),
            Position = UDim2.new(0, 0, 1, -UNDERLINE_H),
            BackgroundColor3 = NOTIF_TRACK,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            ZIndex = 201,
        })
        local fill = Create("Frame", {
            Parent = track,
            Size = UDim2.new(loading and 0.33 or 1, 0, 1, 0),
            Position = UDim2.new(loading and -0.33 or 0, 0, 0, 0),
            BackgroundColor3 = accent,
            BackgroundTransparency = loading and 0.3 or 0,
            BorderSizePixel = 0,
            ZIndex = 202,
        })

        local dismissed = false
        local hovered   = false
        local conns     = {}

        table.insert(activeNotifs, notifFrame)
        Tween(notifFrame, {Position = UDim2.new(1, -(NOTIF_W + 10), 0, NotifSlotY(#activeNotifs))}, 0.32, Enum.EasingStyle.Back)

        local function Cleanup()
            for _, c in ipairs(conns) do c:Disconnect() end
            table.clear(conns)
        end

        local function DismissNotif()
            if dismissed then return end
            dismissed = true
            Cleanup()
            for i, f in ipairs(activeNotifs) do
                if f == notifFrame then
                    table.remove(activeNotifs, i)
                    break
                end
            end
            if notifFrame and notifFrame.Parent then
                local slideY = notifFrame.Position.Y.Offset
                Tween(notifFrame, {Position = UDim2.new(1, 10, 0, slideY)}, 0.28)
            end
            ReflowNotifs()
            task.delay(0.32, function()
                if notifFrame and notifFrame.Parent then notifFrame:Destroy() end
            end)
        end

        local remaining = duration
        local function StartCountdown()
            conns[#conns + 1] = RunService.RenderStepped:Connect(function(dt)
                if hovered then return end
                remaining = remaining - dt
                if remaining <= 0 then
                    fill.Size = UDim2.new(0, 0, 1, 0)
                    countLabel.Text = "0s"
                    DismissNotif()
                    return
                end
                fill.Size = UDim2.new(remaining / duration, 0, 1, 0)
                countLabel.Text = tostring(math.ceil(remaining)) .. "s"
            end)
        end

        local loadingConns = {}
        local function StartLoading()
            local t = 0
            loadingConns[#loadingConns + 1] = RunService.RenderStepped:Connect(function(dt)
                t = (t + dt / 1.1) % 1
                fill.Position = UDim2.new(-0.33 + t * 1.33, 0, 0, 0)
            end)
            local acc, fi = 0, 1
            loadingConns[#loadingConns + 1] = RunService.RenderStepped:Connect(function(dt)
                acc = acc + dt
                if acc >= 0.09 then
                    acc = 0
                    fi = fi % #SPIN_FRAMES + 1
                    spinnerLabel.Text = SPIN_FRAMES[fi]
                end
            end)
            for _, c in ipairs(loadingConns) do conns[#conns + 1] = c end
        end
        local function StopLoading()
            for _, c in ipairs(loadingConns) do c:Disconnect() end
            table.clear(loadingConns)
            spinnerLabel.Visible = false
        end

        if loading then StartLoading() else StartCountdown() end

        local hitArea = Create("TextButton", {
            Parent = notifBg,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            ZIndex = 203,
            AutoButtonColor = false,
        })
        hitArea.MouseEnter:Connect(function()
            hovered = true
            Tween(stroke, {Color = NOTIF_BORDER_HOVER}, 0.15)
        end)
        hitArea.MouseLeave:Connect(function()
            hovered = false
            Tween(stroke, {Color = NOTIF_BORDER}, 0.15)
        end)
        hitArea.MouseButton1Click:Connect(DismissNotif)

        local handle = {}
        function handle.SetMessage(newMessage)
            if dismissed then return end
            msgLabel.Text = newMessage
        end
        function handle.Complete(newTitle, newMessage, newColor, newDuration)
            if dismissed then return end
            StopLoading()
            local doneAccent = newColor or Colors.Accent
            local doneTitleColor = (doneAccent == Colors.TextMuted) and Colors.TextPrimary or doneAccent
            if newTitle then titleLabel.Text = TrackText(string.upper(newTitle)) end
            if newMessage then msgLabel.Text = newMessage end
            titleLabel.TextColor3 = doneTitleColor
            glyphLabel.Text = (newColor == Colors.Error and GLYPH_ERROR)
                or (newColor == Colors.Warning and GLYPH_WARN)
                or GLYPH_SUCCESS
            glyphLabel.TextColor3 = doneAccent
            accentBar.BackgroundColor3 = doneAccent
            fill.BackgroundColor3 = doneAccent
            fill.BackgroundTransparency = 0
            fill.Position = UDim2.new(0, 0, 0, 0)
            fill.Size = UDim2.new(1, 0, 1, 0)
            duration = newDuration or 4
            remaining = duration
            countLabel.Text = tostring(duration) .. "s"
            StartCountdown()
        end
        function handle.Dismiss()
            DismissNotif()
        end

        return handle
    end

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
        local totalH     = headerH + listH + 16 + UNDERLINE_H

        local accent = color or Colors.Accent

        local notifFrame = Create("Frame", {
            Parent = playerGui:FindFirstChild("MiracleHub"),
            Size = UDim2.new(0, NOTIF_W, 0, totalH),
            Position = UDim2.new(1, 10, 0, 16),
            BackgroundColor3 = Colors.BackgroundLighter,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            ZIndex = 200,
        })
        CreateCorner(notifFrame, 6)
        CreateStroke(notifFrame, NOTIF_BORDER, 1)
        _stockNotif = notifFrame

        Create("Frame", {
            Parent = notifFrame,
            Size = UDim2.new(0, 3, 1, -UNDERLINE_H),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundColor3 = accent,
            BorderSizePixel = 0,
            ZIndex = 201,
        })

        Create("TextLabel", {
            Parent = notifFrame,
            Size = UDim2.new(1, -50, 0, 22),
            Position = UDim2.new(0, 15, 0, 7),
            BackgroundTransparency = 1,
            Text = TrackText(string.upper(title or ("Stok Ada (" .. #available .. " seed)"))),
            TextColor3 = accent,
            TextSize = 11,
            Font = FONT_BOLD,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
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
            Font = FONT_BOLD,
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
            Position = UDim2.new(0, 15, 0, headerH),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 6,
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
                Font = FONT_MONO,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 202,
            })
        end

        local track = Create("Frame", {
            Parent = notifFrame,
            Size = UDim2.new(1, 0, 0, UNDERLINE_H),
            Position = UDim2.new(0, 0, 1, -UNDERLINE_H),
            BackgroundColor3 = NOTIF_TRACK,
            BorderSizePixel = 0,
            ZIndex = 201,
        })
        local fill = Create("Frame", {
            Parent = track,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = accent,
            BorderSizePixel = 0,
            ZIndex = 202,
        })

        Tween(notifFrame, {Position = UDim2.new(1, -(NOTIF_W + 10), 0, 16)}, 0.32, Enum.EasingStyle.Back)

        local dismissed = false
        local timerConn = nil
        local function DismissStok()
            if dismissed then return end
            dismissed = true
            if timerConn then timerConn:Disconnect() timerConn = nil end
            Tween(notifFrame, {Position = UDim2.new(1, 10, 0, 16)}, 0.3)
            task.wait(0.35)
            if notifFrame and notifFrame.Parent then notifFrame:Destroy() end
            _stockNotif = nil
        end

        local remaining = duration
        timerConn = RunService.RenderStepped:Connect(function(dt)
            remaining = remaining - dt
            if remaining <= 0 then
                task.spawn(DismissStok)
                return
            end
            fill.Size = UDim2.new(remaining / duration, 0, 1, 0)
        end)

        closeBtn.MouseButton1Click:Connect(function() task.spawn(DismissStok) end)
    end

    local function GetMutationColor(mutation)
        if mutation == "Gold"       then return Colors.Gold
        elseif mutation == "Electric"   then return Colors.Electric
        elseif mutation == "Rainbow"    then return Colors.Rainbow
        elseif mutation == "Frozen"     then return Colors.Frozen
        elseif mutation == "Bloodlit"   then return Color3.fromRGB(220, 40,  40)
        elseif mutation == "Starstruck" then return Color3.fromRGB(255, 230, 80)
        elseif mutation == "Aurora"     then return Color3.fromRGB(80,  255, 200)
        elseif mutation == "Chained"    then return Color3.fromRGB(160, 160, 255)
        elseif mutation == "Ignited"    then return Color3.fromRGB(255, 100, 30)
        elseif mutation == "Glow"       then return Color3.fromRGB(180, 255, 180)
        elseif mutation == "Eclipsed"   then return Color3.fromRGB(90,  30,  120)
        else return Colors.TextMuted end
    end

    UI.Notify           = Notify
    UI.NotifyStok       = NotifyStok
    UI.GetMutationColor = GetMutationColor

    -- ====================== MAIN GUI SHELL (MOBILE) ======================
    local ScreenGui = Create("ScreenGui", {
        Name = "MiracleHub",
        Parent = playerGui,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    ctx.ScreenGui = ScreenGui

    -- Loading Screen (Neo — identik desktop)
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
    CreateCorner(LoadingContainer, 14)
    CreateStroke(LoadingContainer, Colors.Border, 1)
    Create("TextLabel", {Parent=LoadingContainer, Size=UDim2.new(1,0,0,30), Position=UDim2.new(0,0,0,20), BackgroundTransparency=1, RichText=true, Text='MIRACLE<font color="'..LIME_HEX..'">HUB</font>', TextColor3=Colors.TextPrimary, TextSize=24, Font=FONT_BOLD, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=102})
    Create("TextLabel", {Parent=LoadingContainer, Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,0,0,52), BackgroundTransparency=1, Text="Grow A Garden 2  \226\128\162  Mobile", TextColor3=Colors.TextMuted, TextSize=12, Font=FONT_MONO, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=102})
    local LoadingBarBg = Create("Frame", {Parent=LoadingContainer, Size=UDim2.new(1,-60,0,6), Position=UDim2.new(0,30,0,94), BackgroundColor3=Colors.SliderTrack, BorderSizePixel=0, ZIndex=102})
    CreateCorner(LoadingBarBg, 3)
    local LoadingBarFill = Create("Frame", {Parent=LoadingBarBg, Size=UDim2.new(0,0,1,0), BackgroundColor3=Colors.Success, BorderSizePixel=0, ZIndex=103})
    CreateCorner(LoadingBarFill, 3)
    local LoadingPercent = Create("TextLabel", {Parent=LoadingContainer, Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,0,0,110), BackgroundTransparency=1, Text="0%", TextColor3=Colors.Success, TextSize=14, Font=FONT_MONO, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=102})
    local LoadingStatus = Create("TextLabel", {Parent=LoadingContainer, Size=UDim2.new(1,0,0,18), Position=UDim2.new(0,0,0,138), BackgroundTransparency=1, Text="Initializing...", TextColor3=Colors.TextMuted, TextSize=11, Font=FONT_MONO, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=102})

    ctx.LoadingScreen    = LoadingScreen
    ctx.LoadingContainer = LoadingContainer
    ctx.LoadingBarFill   = LoadingBarFill
    ctx.LoadingPercent   = LoadingPercent
    ctx.LoadingStatus    = LoadingStatus

    -- ====================== MAIN FRAME (MOBILE — FULLSCREEN) ======================
    local originalSize = UDim2.fromScale(0.97, 0.94)
    local MainFrame = Create("Frame", {
        Name = "MainFrame",
        Parent = ScreenGui,
        Size = originalSize,
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundColor3 = Colors.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
    })
    CreateCorner(MainFrame, 14)
    CreateStroke(MainFrame, Colors.Border, 1)

    -- Pixel snap
    local function SnapMainFramePosition()
        if ctx.isMinimized then return end
        local vp = ScreenGui.AbsoluteSize
        if vp.X <= 0 or vp.Y <= 0 then return end
        local x = math.floor((vp.X - MainFrame.AbsoluteSize.X) / 2 + 0.5)
        local y = math.floor((vp.Y - MainFrame.AbsoluteSize.Y) / 2 + 0.5)
        MainFrame.Position = UDim2.fromOffset(x, y)
    end
    ScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(SnapMainFramePosition)
    MainFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(SnapMainFramePosition)
    task.defer(SnapMainFramePosition)

    ctx.MainFrame    = MainFrame
    ctx.originalSize = originalSize
    ctx.SnapMainFramePosition = SnapMainFramePosition

    -- ====================== TOP BAR (MOBILE) ======================
    local TOPBAR_H = 48
    local BOTTOMBAR_H = 52
    local TopBar = Create("Frame", {
        Name = "TopBar",
        Parent = MainFrame,
        Size = UDim2.new(1, 0, 0, TOPBAR_H),
        BackgroundColor3 = Colors.BackgroundLight,
        BorderSizePixel = 0,
    })
    ctx.TopBar = TopBar
    CreateCorner(TopBar, 14)
    Create("Frame", {
        Parent = TopBar,
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, 1, -14),
        BackgroundColor3 = Colors.BackgroundLight,
        BorderSizePixel = 0,
    })
    Create("Frame", {
        Parent = TopBar,
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = Colors.Border,
        BorderSizePixel = 0,
    })

    -- ConnDot + CONNECTED
    local ConnDot = Create("Frame", {
        Parent = TopBar,
        Size = UDim2.new(0, 7, 0, 7),
        Position = UDim2.new(0, 14, 0.5, -3),
        BackgroundColor3 = Colors.Accent,
        BorderSizePixel = 0,
    })
    CreateCorner(ConnDot, 4)
    Create("TextLabel", {
        Parent = TopBar,
        Size = UDim2.new(0, 120, 1, 0),
        Position = UDim2.new(0, 28, 0, 0),
        BackgroundTransparency = 1,
        Text = "CONNECTED",
        TextColor3 = Colors.Accent,
        TextSize = 12,
        Font = FONT_MONO,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    task.spawn(function()
        while ConnDot.Parent do
            Tween(ConnDot, {BackgroundTransparency = 0.6}, 0.9)
            task.wait(1)
            Tween(ConnDot, {BackgroundTransparency = 0}, 0.9)
            task.wait(1)
        end
    end)

    -- Hidden SearchBox for bootstrap compatibility
    local SearchBox = Create("TextBox", {
        Parent = TopBar,
        Size = UDim2.new(0, 1, 0, 1),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        TextTransparency = 1,
        Text = "",
        Visible = false,
    })
    ctx.SearchBox = SearchBox

    -- BrandCard (smaller on mobile — centered, no FPS/MS to save space)
    local BrandCard = Create("Frame", {
        Parent = TopBar,
        Size = UDim2.new(0, 180, 0, 30),
        Position = UDim2.new(0.5, -90, 0.5, -15),
        BackgroundColor3 = Colors.BackgroundLighter,
        BorderSizePixel = 0,
    })
    CreateCorner(BrandCard, 8)
    CreateStroke(BrandCard, Colors.Border, 1)

    Create("ImageLabel", {
        Parent = BrandCard,
        Size = UDim2.new(0, 22, 0, 22),
        Position = UDim2.new(0, 8, 0.5, -11),
        BackgroundTransparency = 1,
        Image = "rbxassetid://74186782815011",
        ScaleType = Enum.ScaleType.Fit,
    })
    Create("TextLabel", {
        Parent = BrandCard,
        Size = UDim2.new(0, 130, 1, 0),
        Position = UDim2.new(0, 33, 0, 0),
        BackgroundTransparency = 1,
        RichText = true,
        Text = 'MIRACLE<font color="' .. LIME_HEX .. '">HUB</font>',
        TextColor3 = Colors.TextPrimary,
        TextSize = 13,
        Font = FONT_BOLD,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    -- PageTitle hidden (bootstrap compat)
    local PageTitle = Create("TextLabel", {
        Parent = TopBar,
        Size = UDim2.new(0, 1, 0, 1),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = "Farm",
        TextTransparency = 1,
    })
    ctx.PageTitle = PageTitle

    -- Right controls (close button only — minimize handled by bootstrap mobile)
    local RightControls = Create("Frame", {
        Parent = TopBar,
        Size = UDim2.new(0, 52, 1, 0),
        Position = UDim2.new(1, -52, 0, 0),
        BackgroundTransparency = 1,
    })

    -- CloseButton — touch target minimal 40×40
    local CloseButton = Create("ImageButton", {
        Parent = RightControls,
        Size = UDim2.new(0, 40, 0, 40),
        Position = UDim2.new(0, 6, 0.5, -20),
        BackgroundTransparency = 1,
        Image = "rbxassetid://82747583388019",
        ImageColor3 = Colors.TextPrimary,
        ScaleType = Enum.ScaleType.Fit,
        BorderSizePixel = 0,
        AutoButtonColor = false,
    })
    ctx.CloseButton = CloseButton

    -- MinimizeButton — touch target minimal 40×40 (icon tetap 14×14 di dalam)
    local MinimizeButton = Create("ImageButton", {
        Parent = RightControls,
        Size = UDim2.new(0, 40, 0, 40),
        Position = UDim2.new(0, -40, 0.5, -20),
        BackgroundTransparency = 1,
        Image = "rbxassetid://99157156810403",
        ImageColor3 = Colors.TextPrimary,
        ScaleType = Enum.ScaleType.Fit,
        BorderSizePixel = 0,
        AutoButtonColor = false,
    })
    ctx.MinimizeButton = MinimizeButton

    -- No hover effects on mobile

    -- ====================== CONTENT AREA ======================
    -- Fills MainFrame minus TopBar (48px) and BottomBar (52px)
    local ContentArea = Create("Frame", {
        Parent = MainFrame,
        Size = UDim2.new(1, 0, 1, -(TOPBAR_H + BOTTOMBAR_H)),
        Position = UDim2.new(0, 0, 0, TOPBAR_H),
        BackgroundColor3 = Colors.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    })
    ctx.ContentArea = ContentArea
    -- bottom-right corner untuk ContentArea
    CreateCorner(ContentArea, 14)

    -- Page header (sama seperti desktop)
    local PAGE_HEADER_H = 42
    local LUCIDE_ICONS = {
        Farm     = "rbxassetid://80777208164591",
        Plot     = "rbxassetid://87316251149405",
        Shop     = "rbxassetid://76080467452382",
        Sell     = "rbxassetid://140657030512024",
        Pets     = "rbxassetid://116007211295034",
        Eggs     = "rbxassetid://100365523847172",
        Player   = "rbxassetid://89538326699568",
        Visuals  = "rbxassetid://109331875518738",
        Teleport = "rbxassetid://102771272796313",
        Utility  = "rbxassetid://114046395678554",
        Mailer   = "rbxassetid://131932847752233",
        Server   = "rbxassetid://85074479673177",
        Settings = "rbxassetid://133886562604149",
    }

    local PageHeader = Create("Frame", {
        Parent = ContentArea,
        Size = UDim2.new(1, 0, 0, PAGE_HEADER_H),
        BackgroundTransparency = 1,
    })
    Create("Frame", {
        Parent = PageHeader,
        Size = UDim2.new(1, -24, 0, 1),
        Position = UDim2.new(0, 12, 1, -1),
        BackgroundColor3 = Colors.Border,
        BorderSizePixel = 0,
    })
    local PageHeaderIcon = Create("ImageLabel", {
        Parent = PageHeader,
        Size = UDim2.new(0, 18, 0, 18),
        Position = UDim2.new(0, 12, 0.5, -9),
        BackgroundTransparency = 1,
        Image = LUCIDE_ICONS["Farm"] or "",
        ImageColor3 = Colors.TextPrimary,
        ImageTransparency = 0.15,
        ScaleType = Enum.ScaleType.Fit,
    })
    local PageHeaderTitle = Create("TextLabel", {
        Parent = PageHeader,
        Size = UDim2.new(1, -140, 1, 0),
        Position = UDim2.new(0, 38, 0, 0),
        BackgroundTransparency = 1,
        Text = "PROFILE",
        TextColor3 = Colors.TextPrimary,
        TextSize = 14,
        Font = FONT_MONO,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local PageChip = Create("TextLabel", {
        Parent = PageHeader,
        Size = UDim2.new(0, 58, 0, 22),
        Position = UDim2.new(1, -70, 0.5, -11),
        BackgroundColor3 = Colors.BackgroundLighter,
        Text = "IDLE",
        TextColor3 = Colors.TextMuted,
        TextSize = 11,
        Font = FONT_MONO,
        BorderSizePixel = 0,
        Visible = false,
    })
    CreateCorner(PageChip, 5)
    local PageChipStroke = CreateStroke(PageChip, Colors.Border, 1)

    local ContentScroll = Create("ScrollingFrame", {
        Parent = ContentArea,
        Size = UDim2.new(1, 0, 1, -PAGE_HEADER_H),
        Position = UDim2.new(0, 0, 0, PAGE_HEADER_H),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 6,
        ScrollBarImageColor3 = Colors.Border,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    })
    CreatePadding(ContentScroll, 12)
    CreateListLayout(ContentScroll, 8)
    ctx.ContentScroll = ContentScroll

    -- ====================== BOTTOM TAB BAR (pengganti Sidebar) ======================
    local BottomBar = Create("Frame", {
        Name = "BottomBar",
        Parent = MainFrame,
        Size = UDim2.new(1, 0, 0, BOTTOMBAR_H),
        Position = UDim2.new(0, 0, 1, -BOTTOMBAR_H),
        BackgroundColor3 = Colors.BackgroundLight,
        BorderSizePixel = 0,
    })
    -- rounded bottom corners
    CreateCorner(BottomBar, 14)
    Create("Frame", { -- patch atas agar rounded hanya di bawah
        Parent = BottomBar,
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Colors.BackgroundLight,
        BorderSizePixel = 0,
    })
    Create("Frame", { -- top hairline
        Parent = BottomBar,
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Colors.Border,
        BorderSizePixel = 0,
    })

    -- BottomBar di-set sebagai ctx.Sidebar agar bootstrap.lua tidak error
    ctx.Sidebar = BottomBar

    -- Tabs layout — horizontal, evenly spaced
    local TabLayout = Create("UIListLayout", {
        Parent = BottomBar,
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    -- Tab buttons — auto-size ke lebar yang sama (pakai UISizeConstraint di tiap tab)
    local tabDefs = {
        {key = "Farm",     icon = LUCIDE_ICONS.Farm,     order = 1},
        {key = "Plot",     icon = LUCIDE_ICONS.Plot,     order = 2},
        {key = "Shop",     icon = LUCIDE_ICONS.Shop,     order = 3},
        {key = "Sell",     icon = LUCIDE_ICONS.Sell,     order = 4},
        {key = "Pets",     icon = LUCIDE_ICONS.Pets,     order = 5},
        {key = "Eggs",     icon = LUCIDE_ICONS.Eggs,     order = 6},
        {key = "Player",   icon = LUCIDE_ICONS.Player,   order = 7},
        {key = "Visuals",  icon = LUCIDE_ICONS.Visuals,  order = 8},
        {key = "Teleport", icon = LUCIDE_ICONS.Teleport, order = 9},
        {key = "Utility",  icon = LUCIDE_ICONS.Utility,  order = 10},
        {key = "Mailer",   icon = LUCIDE_ICONS.Mailer,   order = 11},
        {key = "Server",   icon = LUCIDE_ICONS.Server,   order = 12},
        {key = "Settings", icon = LUCIDE_ICONS.Settings, order = 13},
    }

    local SidebarButtons = {}
    ctx.SidebarButtons = SidebarButtons
    local ActivePage = "Profile"
    ctx.GetActivePage = function() return ActivePage end

    local sb = {}
    local tabButtons = {} -- semua tab button references

    local ACTIVE_TAB_COLOR = Color3.fromRGB(22, 48, 50)  -- teal surface (active)
    local TAB_IDLE_ALPHA = 0.4

    for _, def in ipairs(tabDefs) do
        local btn = Create("ImageButton", {
            Parent = BottomBar,
            Size = UDim2.new(0, 44, 0, 44),
            BackgroundTransparency = 1,
            BackgroundColor3 = ACTIVE_TAB_COLOR,
            Image = def.icon,
            ImageColor3 = Colors.TextSecondary,
            ImageTransparency = TAB_IDLE_ALPHA,
            ScaleType = Enum.ScaleType.Fit,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            LayoutOrder = def.order,
        })
        CreateCorner(btn, 10)
        tabButtons[def.key] = btn

        btn.MouseButton1Click:Connect(function()
            SetActivePage(def.key)
        end)

        sb[def.key] = btn
    end

    -- BottomBar scrollable (kalau terlalu banyak tab, pake ScrollingFrame)
    -- Tapi dengan 13 tab × 44px = 572px, lebih kecil dari layar minimum 360px.
    -- Jadi kita wrap dalam ScrollingFrame horizontal.
    -- Hapus tabButtons langsung dari BottomBar, masukkan ke ScrollingFrame
    for _, btn in pairs(tabButtons) do
        btn.Parent = nil
    end

    -- Hapus UIListLayout dari BottomBar
    TabLayout:Destroy()

    -- Buat ScrollingFrame horizontal di BottomBar
    local TabScroll = Create("ScrollingFrame", {
        Parent = BottomBar,
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,  -- hide scrollbar, user swipe
        ScrollingDirection = Enum.ScrollingDirection.X,
        CanvasSize = UDim2.new(0, #tabDefs * 52, 0, 0),
        ElasticBehavior = Enum.ElasticBehavior.Always,
    })
    Create("UIListLayout", {
        Parent = TabScroll,
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    Create("UIPadding", {
        Parent = TabScroll,
        PaddingLeft = UDim.new(0, 4),
        PaddingRight = UDim.new(0, 4),
    })

    for _, def in ipairs(tabDefs) do
        local btn = tabButtons[def.key]
        btn.Parent = TabScroll
        btn.LayoutOrder = def.order
    end

    ctx.sidebarButtonRefs = sb

    -- Profile card (top of page, accessed via tab button in header or Profile tab)
    -- Untuk mobile, Profile cukup akses lewat tab Player atau dari PageHeader
    local ProfileCard = Create("TextButton", {
        Parent = TopBar,
        Size = UDim2.new(0, 40, 0, 40),
        Position = UDim2.new(0, 60, 0.5, -20),
        BackgroundColor3 = Colors.BackgroundLighter,
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    })
    CreateCorner(ProfileCard, 10)
    local ProfileStroke = CreateStroke(ProfileCard, Colors.Border, 1)
    local ProfileAvatar = Create("ImageLabel", {
        Parent = ProfileCard,
        Size = UDim2.new(0, 32, 0, 32),
        Position = UDim2.new(0.5, -16, 0.5, -16),
        BackgroundColor3 = Colors.Surface,
        Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150",
        BorderSizePixel = 0,
    })
    CreateCorner(ProfileAvatar, 6)
    local ProfileAvatarStroke = CreateStroke(ProfileAvatar, Colors.Border, 1)

    ProfileCard.MouseButton1Click:Connect(function()
        SetActivePage("Profile")
    end)

    -- ====================== PAGE SYSTEM ======================
    local Pages = {}
    ctx.Pages = Pages

    local function SaveState(key, value) end
    ctx.SaveState = SaveState

    local ColLeft, ColRight = nil, nil
    local _sectionCount = 0
    local _pageToggleKeys = {}

    local function RegisterPageToggleKey(stateKey)
        table.insert(_pageToggleKeys, stateKey)
    end
    local function RefreshPageChip()
        local anyOn = false
        for _, k in ipairs(_pageToggleKeys) do
            if States[k] then anyOn = true break end
        end
        if anyOn then
            PageChip.Text = "ACTIVE"
            PageChip.TextColor3 = Colors.Accent
            PageChipStroke.Color = Colors.BorderLight
        else
            PageChip.Text = "IDLE"
            PageChip.TextColor3 = Colors.TextMuted
            PageChipStroke.Color = Colors.Border
        end
    end

    local function BuildColumns()
        local wrap = Create("Frame", {
            Parent = ContentScroll,
            Name = "PageColumns",
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
        })
        ColLeft = Create("Frame", {
            Parent = wrap,
            Name = "ColLeft",
            Size = UDim2.new(0.5, -6, 0, 0),
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
        })
        CreateListLayout(ColLeft, 8)
        ColRight = Create("Frame", {
            Parent = wrap,
            Name = "ColRight",
            Size = UDim2.new(0.5, -6, 0, 0),
            Position = UDim2.new(0.5, 6, 0, 0),
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
        })
        CreateListLayout(ColRight, 8)
        return wrap
    end

    local function ClearContent()
        for _, child in ipairs(ContentScroll:GetChildren()) do
            if child:IsA("GuiObject") and child.Name ~= "UIPadding" and child.Name ~= "UIListLayout" then
                child:Destroy()
            end
        end
        _sectionCount = 0
        _pageToggleKeys = {}
        BuildColumns()
    end
    ctx.ClearContent = ClearContent

    local function SetActivePage(pageName)
        ActivePage = pageName
        PageTitle.Text = pageName

        -- Update tab button visuals
        local activeIcon = LUCIDE_ICONS[pageName]
        if activeIcon then
            PageHeaderIcon.Image = activeIcon
            PageHeaderIcon.ImageColor3 = Color3.new(1, 1, 1)
            PageHeaderIcon.ImageTransparency = 0
        else
            PageHeaderIcon.Image = LUCIDE_ICONS["Farm"] or ""
            PageHeaderIcon.ImageColor3 = Colors.TextPrimary
            PageHeaderIcon.ImageTransparency = 0.15
        end

        -- Update tab bar highlights
        for key, btn in pairs(tabButtons) do
            if key == pageName then
                btn.BackgroundColor3 = ACTIVE_TAB_COLOR
                Tween(btn, {BackgroundTransparency = 0, ImageTransparency = 0, ImageColor3 = Colors.Accent}, 0.15)
            else
                Tween(btn, {BackgroundTransparency = 1, ImageTransparency = TAB_IDLE_ALPHA, ImageColor3 = Colors.TextSecondary}, 0.15)
            end
        end

        PageHeaderTitle.Text = string.upper(pageName)

        ClearContent()
        if Pages[pageName] then Pages[pageName]() end

        if pageName == "Profile" then
            PageChip.Visible = false
        else
            PageChip.Visible = true
            RefreshPageChip()
        end

        -- Single-column fallback
        if ColLeft and ColRight then
            local rightHasChildren = false
            for _, ch in ipairs(ColRight:GetChildren()) do
                if ch:IsA("GuiObject") then rightHasChildren = true break end
            end
            if not rightHasChildren then
                ColLeft.Size = UDim2.new(1, 0, 0, 0)
                ColRight.Visible = false
            end
        end

        ContentScroll.CanvasPosition = Vector2.new(0, 0)
    end
    ctx.SetActivePage = SetActivePage

    local function registerPage(name, builderFn)
        Pages[name] = builderFn
    end
    ctx.registerPage = registerPage

    -- ====================== UI COMPONENT BUILDERS ======================
    -- Identik dengan desktop. Semua builder menggunakan MouseButton1Click
    -- yang juga di-fire oleh touch di Roblox.

    local function CreateSectionCard(title, layoutOrder, accentColor)
        _sectionCount = _sectionCount + 1
        local col = (_sectionCount % 2 == 1) and ColLeft or ColRight

        local block = Create("Frame", {
            Parent = col,
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            LayoutOrder = _sectionCount,
            AutomaticSize = Enum.AutomaticSize.Y,
        })
        CreateListLayout(block, 8)

        local cleanTitle = title:gsub("^[%z\1-\127\194-\244][\128-\191]*%s*", "")
        if cleanTitle == "" then cleanTitle = title end

        local header = Create("Frame", {
            Parent = block,
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            LayoutOrder = 0,
        })
        local titleLbl = Create("TextLabel", {
            Parent = header,
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = string.upper(cleanTitle),
            TextColor3 = accentColor or Colors.Accent,
            TextSize = 11,
            Font = FONT_MONO,
            TextXAlignment = Enum.TextXAlignment.Left,
            AutomaticSize = Enum.AutomaticSize.X,
        })
        local divider = Create("Frame", {
            Parent = header,
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.new(0, 0, 0.5, 0),
            BackgroundColor3 = Colors.Border,
            BorderSizePixel = 0,
        })
        task.defer(function()
            if titleLbl.Parent and divider.Parent then
                local w = titleLbl.AbsoluteSize.X + 10
                divider.Position = UDim2.new(0, w, 0.5, 0)
                divider.Size = UDim2.new(1, -w, 0, 1)
            end
        end)

        local content = Create("Frame", {
            Parent = block,
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            LayoutOrder = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
        })
        CreateListLayout(content, 8)

        return block, content
    end

    local function CreateSubHeader(parent, text)
        local h = Create("Frame", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, 20),
            BackgroundTransparency = 1,
        })
        Create("TextLabel", {
            Parent = h,
            Size = UDim2.new(0, 180, 1, 0),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = Colors.TextSecondary,
            TextSize = 13,
            Font = FONT_MONO,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        Create("Frame", {
            Parent = h,
            Size = UDim2.new(1, -190, 0, 1),
            Position = UDim2.new(0, 190, 0.5, 0),
            BackgroundColor3 = Colors.Border,
            BorderSizePixel = 0,
        })
        return h
    end

    local function CreateToggle(parent, text, stateKey, description, onToggle)
        local defaultState = States[stateKey] or false
        RegisterPageToggleKey(stateKey)
        local container = Create("Frame", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, 48),
            BackgroundColor3 = Colors.BackgroundLighter,
            BorderSizePixel = 0,
        })
        CreateCorner(container, 10)
        CreateStroke(container, Colors.Border, 1)

        Create("TextLabel", {
            Parent = container,
            Size = UDim2.new(1, -80, 1, 0),
            Position = UDim2.new(0, 14, 0, 0),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = Colors.TextPrimary,
            TextSize = 14,
            Font = FONT_BODY,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })

        local toggleBg = Create("Frame", {
            Parent = container,
            Size = UDim2.new(0, 44, 0, 24),
            Position = UDim2.new(1, -56, 0.5, -12),
            BackgroundColor3 = defaultState and Colors.ToggleOn or Colors.ToggleOff,
            BorderSizePixel = 0,
        })
        CreateCorner(toggleBg, 12)
        local knob = Create("Frame", {
            Parent = toggleBg,
            Size = UDim2.new(0, 18, 0, 18),
            Position = UDim2.new(0, defaultState and 23 or 3, 0.5, -9),
            BackgroundColor3 = defaultState and Colors.ToggleKnob or Colors.TextSecondary,
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
            Tween(toggleBg, {BackgroundColor3 = state and Colors.ToggleOn or Colors.ToggleOff}, 0.2)
            Tween(knob, {
                Position = UDim2.new(0, state and 23 or 3, 0.5, -9),
                BackgroundColor3 = state and Colors.ToggleKnob or Colors.TextSecondary,
            }, 0.2)
            if onToggle then
                onToggle(state, function()
                    state = false
                    States[stateKey] = false
                    SaveState(stateKey, false)
                    Tween(toggleBg, {BackgroundColor3 = Colors.ToggleOff}, 0.2)
                    Tween(knob, {Position = UDim2.new(0, 3, 0.5, -9), BackgroundColor3 = Colors.TextSecondary}, 0.2)
                    RefreshPageChip()
                end)
            end
            RefreshPageChip()
        end)

        local function setVisual(newState)
            if container.Parent == nil then return end
            state = newState
            Tween(toggleBg, {BackgroundColor3 = newState and Colors.ToggleOn or Colors.ToggleOff}, 0.2)
            Tween(knob, {
                Position = UDim2.new(0, newState and 23 or 3, 0.5, -9),
                BackgroundColor3 = newState and Colors.ToggleKnob or Colors.TextSecondary,
            }, 0.2)
            RefreshPageChip()
        end

        return container, function() return state end, setVisual
    end

    local function CreateSlider(parent, text, minVal, maxVal, stateKey, suffix, onChange)
        local defaultVal = States[stateKey] or minVal
        local container = Create("Frame", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, 66),
            BackgroundColor3 = Colors.BackgroundLighter,
            BorderSizePixel = 0,
        })
        CreateCorner(container, 10)
        CreateStroke(container, Colors.Border, 1)
        Create("TextLabel", {
            Parent = container,
            Size = UDim2.new(1, -90, 0, 20),
            Position = UDim2.new(0, 14, 0, 8),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = Colors.TextPrimary,
            TextSize = 14,
            Font = FONT_BODY,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })
        local valLabel = Create("TextLabel", {
            Parent = container,
            Size = UDim2.new(0, 60, 0, 24),
            Position = UDim2.new(1, -72, 0, 7),
            BackgroundColor3 = Colors.Background,
            Text = tostring(defaultVal) .. (suffix or ""),
            TextColor3 = Colors.Accent,
            TextSize = 13,
            Font = FONT_MONO,
            BorderSizePixel = 0,
        })
        CreateCorner(valLabel, 6)
        CreateStroke(valLabel, Colors.BorderLight, 1)

        local track = Create("Frame", {
            Parent = container,
            Size = UDim2.new(1, -28, 0, 6),
            Position = UDim2.new(0, 14, 0, 44),
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
            BackgroundColor3 = Colors.Accent,
            BorderSizePixel = 0,
        })
        CreateCorner(sliderKnob, 8)

        local dragging = false
        local trackBtn = Create("TextButton", {
            Parent = container,
            Size = UDim2.new(1, -28, 0, 28),
            Position = UDim2.new(0, 14, 0, 34),
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
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                updateSlider(input.Position.X, false)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                updateSlider(input.Position.X, false)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                if dragging then
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
            Size = UDim2.new(1, 0, 0, 48),
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
        CreateCorner(btn, 10)
        CreateStroke(btn, accentColor or Colors.Border, 1)
        Create("TextLabel", {
            Parent = btn,
            Size = UDim2.new(1, -48, 1, 0),
            Position = UDim2.new(0, 14, 0, 0),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = accentColor or Colors.TextPrimary,
            TextSize = 14,
            Font = FONT_BODY,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })
        Create("TextLabel", {
            Parent = btn,
            Size = UDim2.new(0, 20, 1, 0),
            Position = UDim2.new(1, -28, 0, 0),
            BackgroundTransparency = 1,
            Text = "\226\128\186",
            TextColor3 = accentColor or Colors.Accent,
            TextSize = 17,
            Font = FONT_BOLD,
        })
        -- No hover effects on mobile
        btn.MouseButton1Click:Connect(function()
            if callback then callback() end
        end)
        return container
    end

    -- Dropdown — sama dengan desktop, tapi tanpa hover effects
    local function CreateDropdown(parent, label, options, stateKey, onChange)
        local currentVal = States[stateKey] or options[1]
        local container = Create("Frame", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, 48),
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
        CreateCorner(btn, 10)
        CreateStroke(btn, Colors.Border, 1)
        local lbl = Create("TextLabel", {
            Parent = btn,
            Size = UDim2.new(1, -56, 1, 0),
            Position = UDim2.new(0, 14, 0, 0),
            BackgroundTransparency = 1,
            RichText = true,
            Text = label .. '  <font color="#71717A">\194\183 ' .. tostring(currentVal) .. '</font>',
            TextColor3 = Colors.TextPrimary,
            TextSize = 14,
            Font = FONT_BODY,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })
        local arr = Create("TextLabel", {
            Parent = btn,
            Size = UDim2.new(0, 26, 1, 0),
            Position = UDim2.new(1, -30, 0, 0),
            BackgroundTransparency = 1,
            Text = "\226\150\190",
            TextColor3 = Colors.Accent,
            TextSize = 14,
            Font = FONT_BOLD,
            TextXAlignment = Enum.TextXAlignment.Center,
        })

        -- Dropdown panel — muncul di atas content (overlay)
        local dropdownOpen = false
        local overlay = Create("Frame", {
            Parent = ScreenGui,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Visible = false,
            ZIndex = 300,
        })
        local panel = Create("ScrollingFrame", {
            Parent = overlay,
            Size = UDim2.new(0, 200, 0, 0),
            BackgroundColor3 = Colors.BackgroundLight,
            BorderSizePixel = 0,
            ScrollBarThickness = 6,
            ScrollBarImageColor3 = Colors.Border,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ZIndex = 301,
        })
        CreateCorner(panel, 10)
        CreateStroke(panel, Colors.Border, 1)
        CreateListLayout(panel, 0)

        local itemBtns = {}
        for _, opt in ipairs(options) do
            local item = Create("TextButton", {
                Parent = panel,
                Size = UDim2.new(1, 0, 0, 40),
                BackgroundTransparency = 1,
                BackgroundColor3 = Colors.Surface,
                Text = tostring(opt),
                TextColor3 = Colors.TextPrimary,
                TextSize = 14,
                Font = FONT_BODY,
                TextXAlignment = Enum.TextXAlignment.Left,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                ZIndex = 302,
            })
            Create("UIPadding", {
                Parent = item,
                PaddingLeft = UDim.new(0, 12),
            })
            item.MouseButton1Click:Connect(function()
                if onChange then onChange(opt) end
                States[stateKey] = opt
                SaveState(stateKey, opt)
                lbl.Text = label .. '  <font color="#71717A">\194\183 ' .. tostring(opt) .. '</font>'
                dropdownOpen = false
                overlay.Visible = false
            end)
            itemBtns[#itemBtns+1] = item
        end

        local function positionPanel()
            local absPos = btn.AbsolutePosition
            local absSize = btn.AbsoluteSize
            local panH = math.min(#options * 40, 240)
            panel.Size = UDim2.new(0, 200, 0, panH)
            local x = absPos.X
            local y = absPos.Y + absSize.Y + 4
            local vp = ScreenGui.AbsoluteSize
            if x + 200 > vp.X then x = vp.X - 210 end
            if y + panH > vp.Y then y = absPos.Y - panH - 4 end
            if y < 4 then y = 4 end
            panel.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
        end

        btn.MouseButton1Click:Connect(function()
            dropdownOpen = not dropdownOpen
            if dropdownOpen then
                positionPanel()
                overlay.Visible = true
            else
                overlay.Visible = false
            end
        end)

        -- Close overlay when tapping outside
        overlay.MouseButton1Click:Connect(function()
            dropdownOpen = false
            overlay.Visible = false
        end)

        -- Block clicks on overlay from reaching panel
        -- Panel absorbs clicks via its own buttons

        return container
    end

    -- Multi-select (sama dengan desktop, touch-friendly)
    local function CreateMultiSelect(parent, label, options, stateKey, displayLabels)
        if type(States[stateKey]) ~= "table" then States[stateKey] = {} end
        local selected = States[stateKey]
        displayLabels = displayLabels or {}

        local pillText = label:gsub("^[%z\1-\127\194-\244][\128-\191]*%s*", "")
        if pillText == "" then pillText = label end

        local function getShortText()
            if #selected == 0 then
                return pillText .. '  <font color="#71717A">\194\183 none</font>'
            end
            if #selected <= 2 then
                local names = {}
                for _, s in ipairs(selected) do
                    names[#names+1] = displayLabels[s] or s
                end
                return pillText .. '  <font color="#71717A">\194\183 ' .. table.concat(names, ", ") .. '</font>'
            end
            return pillText .. '  <font color="#71717A">\194\183 ' .. #selected .. ' selected</font>'
        end

        local wrapper = Create("Frame", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = Colors.BackgroundLighter,
            BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.Y,
        })
        CreateCorner(wrapper, 10)
        local pillStroke = CreateStroke(wrapper, Colors.Border, 1)
        CreateListLayout(wrapper, 0)

        local pillOuter = Create("Frame", {
            Parent = wrapper,
            Size = UDim2.new(1, 0, 0, 48),
            BackgroundTransparency = 1,
            LayoutOrder = 0,
        })
        local pill = Create("TextButton", {
            Parent = pillOuter,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            BorderSizePixel = 0,
            AutoButtonColor = false,
        })
        local pillLabel = Create("TextLabel", {
            Parent = pill,
            Size = UDim2.new(1, -50, 1, 0),
            Position = UDim2.new(0, 14, 0, 0),
            BackgroundTransparency = 1,
            RichText = true,
            Text = getShortText(),
            TextColor3 = Colors.TextPrimary,
            TextSize = 14,
            Font = FONT_BODY,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })
        local arrowLbl = Create("ImageLabel", {
            Parent = pill,
            Size = UDim2.new(0, 16, 0, 16),
            Position = UDim2.new(1, -28, 0.5, -8),
            BackgroundTransparency = 1,
            Image = "rbxassetid://76183523786785",
            ImageColor3 = Color3.fromRGB(255, 255, 255),
        })

        local panel = Create("Frame", {
            Parent = wrapper,
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = 1,
            Visible = false,
            ClipsDescendants = true,
        })
        Create("Frame", {
            Parent = panel,
            Size = UDim2.new(1, -16, 0, 1),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundColor3 = Colors.Border,
            BorderSizePixel = 0,
        })

        local LIST_MAX_H = 220
        local scroll = Create("ScrollingFrame", {
            Parent = panel,
            Size = UDim2.new(1, 0, 0, math.min(#options * 32, LIST_MAX_H)),
            Position = UDim2.new(0, 0, 0, 8),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 6,
            ScrollBarImageColor3 = Colors.Border,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ZIndex = 2,
        })
        CreateListLayout(scroll, 2)
        Create("UIPadding", {Parent=scroll, PaddingLeft=UDim.new(0,6), PaddingRight=UDim.new(0,6), PaddingTop=UDim.new(0,2), PaddingBottom=UDim.new(0,6)})

        local itemFrames = {}
        local isOpen = false
        local isDisabled = false

        local function isSelected(opt)
            return table.find(selected, opt) ~= nil
        end

        local function updateRow(t)
            local sel = isSelected(t.opt)
            t.frame.BackgroundColor3 = Colors.Accent
            t.frame.BackgroundTransparency = sel and 0.92 or 1
            t.checkLbl.Text = sel and "\226\156\147" or ""
            t.checkLbl.TextColor3 = Colors.Accent
            t.nameLbl.TextColor3 = sel and Colors.Accent or Colors.TextSecondary
            t.nameLbl.Font = sel and FONT_BOLD or FONT_BODY
        end

        local function updatePill()
            pillLabel.Text = getShortText()
            pillStroke.Color = #selected > 0 and Colors.BorderLight or Colors.Border
        end

        for _, opt in ipairs(options) do
            local sel = isSelected(opt)
            local row = Create("Frame", {
                Parent = scroll,
                Size = UDim2.new(1, 0, 0, 32),
                BackgroundColor3 = Colors.Accent,
                BackgroundTransparency = sel and 0.92 or 1,
                BorderSizePixel = 0,
                ZIndex = 3,
            })
            CreateCorner(row, 6)
            local nameLbl = Create("TextLabel", {
                Parent = row,
                Size = UDim2.new(1, -40, 1, 0),
                Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                Text = displayLabels[opt] or opt,
                TextColor3 = sel and Colors.Accent or Colors.TextSecondary,
                TextSize = 13,
                Font = sel and FONT_BOLD or FONT_BODY,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 4,
            })
            local checkLbl = Create("TextLabel", {
                Parent = row,
                Size = UDim2.new(0, 22, 1, 0),
                Position = UDim2.new(1, -28, 0, 0),
                BackgroundTransparency = 1,
                Text = sel and "\226\156\147" or "",
                TextColor3 = Colors.Accent,
                TextSize = 14,
                Font = FONT_BOLD,
                TextXAlignment = Enum.TextXAlignment.Center,
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
            -- No hover effects on mobile
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

        pill.MouseButton1Click:Connect(function()
            if isDisabled then return end
            isOpen = not isOpen
            arrowLbl.Image = isOpen and "rbxassetid://70479509562650" or "rbxassetid://76183523786785"
            if isOpen then
                panel.Visible = true
                panel.Size = UDim2.new(1, 0, 0, 0)
                local targetH = 8 + math.min(#options * 32, LIST_MAX_H) + 8
                Tween(panel, {Size = UDim2.new(1, 0, 0, targetH)}, 0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            else
                Tween(panel, {Size = UDim2.new(1, 0, 0, 0)}, 0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
                task.delay(0.19, function()
                    if not isOpen then panel.Visible = false end
                end)
            end
        end)

        local function SetDisabled(disabled)
            isDisabled = disabled
            if disabled and isOpen then
                isOpen = false
                arrowLbl.Image = "rbxassetid://76183523786785"
                Tween(panel, {Size = UDim2.new(1, 0, 0, 0)}, 0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
                task.delay(0.19, function()
                    if not isOpen then panel.Visible = false end
                end)
            end
            local dimAlpha = disabled and 0.55 or 0
            Tween(wrapper, {BackgroundTransparency = disabled and 0.5 or 0}, 0.18)
            Tween(pillLabel, {TextTransparency = dimAlpha}, 0.18)
            Tween(arrowLbl,  {ImageTransparency = dimAlpha}, 0.18)
            for _, t in ipairs(itemFrames) do
                t.nameLbl.TextTransparency  = dimAlpha
                t.checkLbl.TextTransparency = dimAlpha
                local hb = t.frame:FindFirstChildWhichIsA("TextButton")
                if hb then hb.Active = not disabled end
            end
        end

        return { instance = wrapper, SetDisabled = SetDisabled }
    end

    local function CreateInfoText(parent, title, desc, color)
        local c = Create("Frame", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = Colors.BackgroundLighter,
            BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.Y,
        })
        CreateCorner(c, 10)
        CreateStroke(c, Colors.Border, 1)
        CreatePadding(c, 12)
        CreateListLayout(c, 5)
        if title then
            Create("TextLabel", {
                Parent = c,
                Size = UDim2.new(1, 0, 0, 16),
                BackgroundTransparency = 1,
                Text = string.upper(title),
                TextColor3 = color or Colors.Accent,
                TextSize = 13,
                Font = FONT_MONO,
                TextXAlignment = Enum.TextXAlignment.Left,
            })
        end
        Create("TextLabel", {
            Parent = c,
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            Text = desc,
            TextColor3 = Colors.TextMuted,
            TextSize = 13,
            Font = FONT_BODY,
            TextXAlignment = Enum.TextXAlignment.Left,
            AutomaticSize = Enum.AutomaticSize.Y,
            TextWrapped = true,
        })
        return c
    end

    local function CreateStatRow(parent, label, value, valColor)
        local r = Create("Frame", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, 44),
            BackgroundColor3 = Colors.BackgroundLighter,
            BorderSizePixel = 0,
        })
        CreateCorner(r, 10)
        CreateStroke(r, Colors.Border, 1)
        Create("TextLabel", {
            Parent = r,
            Size = UDim2.new(0.5, -14, 1, 0),
            Position = UDim2.new(0, 14, 0, 0),
            BackgroundTransparency = 1,
            Text = label,
            TextColor3 = Colors.TextSecondary,
            TextSize = 14,
            Font = FONT_BODY,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        local valLbl = Create("TextLabel", {
            Parent = r,
            Size = UDim2.new(0.5, -14, 1, 0),
            Position = UDim2.new(0.5, 0, 0, 0),
            BackgroundTransparency = 1,
            Text = tostring(value),
            TextColor3 = valColor or Colors.Accent,
            TextSize = 14,
            Font = FONT_MONO,
            TextXAlignment = Enum.TextXAlignment.Right,
        })
        return r, valLbl
    end

    UI.CreateSectionHeader = function(parent, text, layoutOrder)
        return Create("TextLabel", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1,
            Text = "// " .. text,
            TextColor3 = Colors.TextMuted,
            TextSize = 13,
            Font = FONT_MONO,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = layoutOrder,
        })
    end
    UI.CreateSectionCard   = CreateSectionCard
    UI.CreateSubHeader     = CreateSubHeader
    UI.CreateToggle        = CreateToggle
    UI.CreateSlider        = CreateSlider
    UI.CreateActionButton  = CreateActionButton
    UI.CreateDropdown      = CreateDropdown
    UI.CreateMultiSelect   = CreateMultiSelect
    UI.CreateInfoText      = CreateInfoText
    UI.CreateStatRow       = CreateStatRow

    -- ====================== BUILT-IN PROFILE PAGE ======================
    -- Simplified for mobile — same data, more compact
    local sessionStart = os.clock()
    registerPage("Profile", function()
        local col = ColLeft

        local isPrime = player:GetAttribute("PrimeEnabled") and true or false

        -- Identity card
        local idCard = Create("Frame", {
            Parent = col,
            Size = UDim2.new(1, 0, 0, 80),
            BackgroundColor3 = Colors.BackgroundLighter,
            BorderSizePixel = 0,
            LayoutOrder = 1,
        })
        CreateCorner(idCard, 12)
        CreateStroke(idCard, Colors.Border, 1)

        local av = Create("ImageLabel", {
            Parent = idCard,
            Size = UDim2.new(0, 48, 0, 48),
            Position = UDim2.new(0, 12, 0.5, -24),
            BackgroundColor3 = Colors.Surface,
            Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150",
            BorderSizePixel = 0,
        })
        CreateCorner(av, 8)
        CreateStroke(av, Colors.BorderLight, 1)

        Create("TextLabel", {
            Parent = idCard,
            Size = UDim2.new(1, -76, 0, 20),
            Position = UDim2.new(0, 72, 0, 16),
            BackgroundTransparency = 1,
            Text = player.DisplayName or player.Name,
            TextColor3 = Colors.TextPrimary,
            TextSize = 16,
            Font = FONT_BOLD,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })
        Create("TextLabel", {
            Parent = idCard,
            Size = UDim2.new(1, -76, 0, 16),
            Position = UDim2.new(0, 72, 0, 40),
            BackgroundTransparency = 1,
            Text = player.Name,
            TextColor3 = Colors.TextMuted,
            TextSize = 13,
            Font = FONT_MONO,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })

        -- 4-stat row (compact)
        local statRow = Create("Frame", {
            Parent = col,
            Size = UDim2.new(1, 0, 0, 76),
            BackgroundTransparency = 1,
            LayoutOrder = 2,
        })
        Create("UIListLayout", {
            Parent = statRow,
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })

        local function statCell(order, iconId, valueText, labelText)
            local cell = Create("Frame", {
                Parent = statRow,
                Size = UDim2.new(0.25, -5, 1, 0),
                BackgroundColor3 = Colors.BackgroundLighter,
                BorderSizePixel = 0,
                LayoutOrder = order,
            })
            CreateCorner(cell, 10)
            CreateStroke(cell, Colors.Border, 1)
            Create("ImageLabel", {
                Parent = cell,
                Size = UDim2.new(0, 16, 0, 16),
                Position = UDim2.new(0, 10, 0, 10),
                BackgroundTransparency = 1,
                Image = "rbxassetid://" .. iconId,
                ImageColor3 = Colors.Accent,
            })
            local v = Create("TextLabel", {
                Parent = cell,
                Size = UDim2.new(1, -10, 0, 22),
                Position = UDim2.new(0, 10, 0, 30),
                BackgroundTransparency = 1,
                Text = valueText,
                TextColor3 = Colors.TextPrimary,
                TextSize = 17,
                Font = FONT_MONO,
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            Create("TextLabel", {
                Parent = cell,
                Size = UDim2.new(1, -10, 0, 12),
                Position = UDim2.new(0, 10, 0, 54),
                BackgroundTransparency = 1,
                Text = labelText,
                TextColor3 = Colors.TextMuted,
                TextSize = 9,
                Font = FONT_MONO,
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            return v, cell
        end

        local sessionVal  = statCell(1, 136103650662391, "00:00:00", "SESSION")
        local playersVal  = statCell(2, 124978844700371, "0",        "PLAYERS")
        local memoryVal   = statCell(3, 118492548320850, "0",        "MEMORY MB")
        local activeVal   = statCell(4, 120958905213540, "0",        "ACTIVE")

        local AUTOMATION_KEYS = {
            "autoPlant", "autoPlantAllSeeds", "autoHarvest",
            "autoWater", "autoSprinkler", "autoBuySeed",
            "autoBuyAll", "autoBuyGear", "autoBuyGearAll",
            "autoBuyCrate", "autoBuyCrateAll", "autoOpenCrate",
            "autoSell", "autoCatchWild", "fly",
            "espPlayers", "espItems", "espFruits", "espMutations",
            "lockWalkSpeed", "lockJumpPower", "infiniteJump",
            "fullBright", "noFog", "noShadows",
            "autoAcceptGifts", "autoRejoin", "antiAfk",
        }

        local Stats   = game:GetService("Stats")
        local Players = game:GetService("Players")

        task.spawn(function()
            while sessionVal.Parent do
                local el = os.clock() - sessionStart
                sessionVal.Text = string.format("%02d:%02d:%02d",
                    math.floor(el/3600), math.floor(el%3600/60), math.floor(el%60))
                playersVal.Text = tostring(#Players:GetPlayers())
                memoryVal.Text  = tostring(math.floor(Stats:GetTotalMemoryUsageMb()))
                local count = 0
                for _, k in ipairs(AUTOMATION_KEYS) do
                    if States[k] then count = count + 1 end
                end
                activeVal.Text = tostring(count)
                task.wait(1)
            end
        end)

        -- INFORMATION section
        local infoHeader = Create("Frame", {
            Parent = col,
            Size = UDim2.new(1, 0, 0, 20),
            BackgroundTransparency = 1,
            LayoutOrder = 3,
        })
        Create("TextLabel", {
            Parent = infoHeader,
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "INFORMATION",
            TextColor3 = Colors.Accent,
            TextSize = 11,
            Font = FONT_MONO,
            TextXAlignment = Enum.TextXAlignment.Left,
            AutomaticSize = Enum.AutomaticSize.X,
        })
        local infoDivider = Create("Frame", {
            Parent = infoHeader,
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.new(0, 0, 0.5, 0),
            BackgroundColor3 = Colors.Border,
            BorderSizePixel = 0,
        })
        task.defer(function()
            if infoDivider.Parent then
                local w = infoHeader:FindFirstChildWhichIsA("TextLabel")
                if w then
                    local ww = w.AbsoluteSize.X + 10
                    infoDivider.Position = UDim2.new(0, ww, 0.5, 0)
                    infoDivider.Size = UDim2.new(1, -ww, 0, 1)
                end
            end
        end)

        local accountBlock = Create("Frame", {
            Parent = col,
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 4,
        })
        CreateListLayout(accountBlock, 6)

        local function accountRow(iconId, labelText, valueText)
            local r = Create("Frame", {
                Parent = accountBlock,
                Size = UDim2.new(1, 0, 0, 44),
                BackgroundColor3 = Colors.BackgroundLighter,
                BorderSizePixel = 0,
            })
            CreateCorner(r, 10)
            CreateStroke(r, Colors.Border, 1)
            Create("ImageLabel", {
                Parent = r,
                Size = UDim2.new(0, 16, 0, 16),
                Position = UDim2.new(0, 12, 0.5, -8),
                BackgroundTransparency = 1,
                Image = "rbxassetid://" .. iconId,
                ImageColor3 = Colors.TextMuted,
            })
            Create("TextLabel", {
                Parent = r,
                Size = UDim2.new(0.5, -44, 1, 0),
                Position = UDim2.new(0, 38, 0, 0),
                BackgroundTransparency = 1,
                Text = labelText,
                TextColor3 = Colors.TextPrimary,
                TextSize = 14,
                Font = FONT_BODY,
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            Create("TextLabel", {
                Parent = r,
                Size = UDim2.new(0.5, -12, 1, 0),
                Position = UDim2.new(0.5, 0, 0, 0),
                BackgroundTransparency = 1,
                Text = valueText,
                TextColor3 = Colors.Accent,
                TextSize = 13,
                Font = FONT_MONO,
                TextXAlignment = Enum.TextXAlignment.Right,
            })
        end

        local isFounder = (player.UserId == 9039505358)
        accountRow(84171650897655,  "Plan",        isFounder and "-" or (isPrime and "Prime \194\183 Lifetime" or "Free"))
        accountRow(100521852773201, "Game",        "Grow A Garden 2")
        accountRow(79697495020129,  "Hub Version", ctx.HubVersion or "v2.0.1")
        accountRow(88921554280153,  "Platform",    "Mobile")
    end)

    ctx.UI = UI
    return ctx
end
