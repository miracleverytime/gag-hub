-- ======================================================================
-- Miracle Hub — ui.lua  (NEO REDESIGN)
-- UI framework module. Loaded SECOND (after core).
--
-- Visual language: near-black monochrome + lime accent, mono type for
-- data/labels, compact rows, slim left accent bars, segmented top bar
-- (MIRACLEHUB | FPS | MS), narrow sidebar with "// GROUP" headers.
--
-- All public signatures are IDENTICAL to the previous build:
--   ctx.UI          — component builders + Create helpers + Notify
--   ctx.ScreenGui, ctx.MainFrame, ctx.ContentScroll, ctx.LoadingScreen, ...
--   ctx.Pages, ctx.registerPage, ctx.SetActivePage, ctx.GetActivePage
--   ctx.SidebarButtons, ctx.sidebarButtonRefs (for bootstrap wiring)
-- bootstrap.lua and pages.lua run unchanged.
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
    -- Mutates ctx.Colors in place so core/logic/pages/bootstrap all
    -- inherit the Neo palette without any changes on their side.
    Colors.Background        = Color3.fromRGB(9, 10, 9)      -- near black
    Colors.BackgroundLight   = Color3.fromRGB(13, 14, 13)    -- topbar / sidebar
    Colors.BackgroundLighter = Color3.fromRGB(19, 21, 19)    -- cards / surfaces
    Colors.Surface           = Color3.fromRGB(27, 29, 27)
    Colors.SurfaceLight      = Color3.fromRGB(36, 39, 36)
    Colors.Border            = Color3.fromRGB(36, 38, 36)    -- ~white/10
    Colors.BorderLight       = Color3.fromRGB(74, 84, 50)    -- lime-tinted border
    Colors.TextPrimary       = Color3.fromRGB(240, 241, 238)
    Colors.TextSecondary     = Color3.fromRGB(158, 161, 155)
    Colors.TextMuted         = Color3.fromRGB(106, 109, 104)
    Colors.Accent            = Color3.fromRGB(163, 230, 53)  -- lime-400
    Colors.Success           = Color3.fromRGB(163, 230, 53)  -- lime-400
    Colors.Warning           = Color3.fromRGB(251, 191, 36)  -- amber-400
    Colors.Error             = Color3.fromRGB(248, 113, 113) -- red-400
    Colors.Electric          = Color3.fromRGB(56, 189, 248)  -- sky-400
    Colors.Rainbow           = Color3.fromRGB(244, 114, 182) -- pink-400
    Colors.Frozen            = Color3.fromRGB(103, 232, 249) -- cyan-300
    Colors.Gold              = Color3.fromRGB(250, 204, 21)  -- yellow-400
    Colors.ToggleOn          = Color3.fromRGB(163, 230, 53)
    Colors.ToggleOff         = Color3.fromRGB(38, 40, 38)
    Colors.ToggleKnob        = Color3.fromRGB(10, 11, 10)
    Colors.SliderTrack       = Color3.fromRGB(34, 36, 34)
    Colors.SliderFill        = Color3.fromRGB(163, 230, 53)

    local LIME_HEX   = "#A3E635"
    local FONT_MONO  = Enum.Font.Code        -- mono labels / values
    local FONT_BODY  = Enum.Font.Gotham
    local FONT_BOLD  = Enum.Font.GothamBold

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

    -- ============ NOTIFICATION SYSTEM — "TERMINAL LINE" ============
    -- Faithful port of the Terminal Line toast reference:
    --   • 340×54 panel, 6px radius, 1px white/10 border, subtle drop shadow
    --   • 3px left accent bar (stops above the underline)
    --   • 16px glyph in accent color, x=15
    --   • 11px bold UPPERCASE letter-tracked title in accent color
    --   • 12px mono muted message, truncated
    --   • 10px mono countdown ("4s" → "0s") at top-right, white @25%
    --   • 2px realtime depleting underline (RenderStepped, frame-accurate)
    --   • loading state: "|/-\" spinner after title, ".." countdown,
    --     shimmering 1/3-width sweep on the underline instead of drain
    --   • hover: timer pauses + border brightens; click anywhere dismisses
    -- Signature is backwards compatible: Notify(title, message, color, duration)
    -- New optional 5th arg: opts = { loading = true, glyph = "..." }
    -- Returns a handle: { Complete = fn, SetMessage = fn, Dismiss = fn }

    local NOTIF_W      = 340
    local NOTIF_H      = 54
    local NOTIF_GAP    = 8
    local NOTIF_MARGIN = 16
    local UNDERLINE_H  = 2

    local NOTIF_BORDER       = Color3.fromRGB(45, 47, 45)  -- white/10 over panel
    local NOTIF_BORDER_HOVER = Colors.BorderLight          -- lime-tinted (hover)
    local NOTIF_TRACK        = Color3.fromRGB(30, 32, 30)  -- white/5 over panel

    local GLYPH_SUCCESS = utf8.char(0x2713) -- ✓
    local GLYPH_WARN    = "!"
    local GLYPH_ERROR   = "\195\151"        -- ×
    local GLYPH_INFO    = "\226\128\162"    -- •
    local SPIN_FRAMES   = {"|", "/", "-", "\\"}

    -- letter tracking ≈ tracking-[0.14em]: hair spaces between characters
    local HAIR = utf8.char(0x200A)
    local function TrackText(s)
        local out = {}
        for _, cp in utf8.codes(s) do
            out[#out + 1] = utf8.char(cp)
        end
        return table.concat(out, HAIR)
    end

    -- vertical stack manager (re-flows remaining toasts on dismiss)
    local activeNotifs = {}
    local function NotifSlotY(index)
        return NOTIF_MARGIN + (index - 1) * (NOTIF_H + NOTIF_GAP)
    end
    local function ReflowNotifs()
        for i, frame in ipairs(activeNotifs) do
            Tween(frame, {Position = UDim2.new(1, -(NOTIF_W + 10), 0, NotifSlotY(i))}, 0.25)
        end
    end

    local function Notify(title, message, color, duration, opts)
        if not States.showNotifications then return end
        opts     = opts or {}
        duration = duration or 4

        local gui = playerGui:FindFirstChild("MiracleHub")
        if not gui then return end

        -- variant resolution (reference: success / warn / info / error)
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
        -- info variant: muted bar/glyph but primary-white title (per reference)
        local titleColor = (accent == Colors.TextMuted) and Colors.TextPrimary or accent

        local loading = opts.loading == true

        -- ---------- container ----------
        -- Wrapper transparan + corner/stroke di notifBg child,
        -- supaya ClipsDescendants tidak memotong rounded corner di sisi kiri.
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
        -- Background sebagai child frame supaya UICorner benar-benar clipping background
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

        -- soft drop shadow — kept as child of notifFrame with absolute size
        -- so reparenting to gui doesn't make it fill the whole screen
        local shadow = Create("ImageLabel", {
            Parent = notifFrame,
            Size = UDim2.new(0, NOTIF_W + 40, 0, NOTIF_H + 40),
            Position = UDim2.new(0, -20, 0, -12),
            BackgroundTransparency = 1,
            Image = "rbxassetid://1316045217",
            ImageColor3 = Color3.new(0, 0, 0),
            ImageTransparency = 1,
            ScaleType = Enum.ScaleType.Slice,
            SliceCenter = Rect.new(10, 10, 118, 118),
            ZIndex = 199,
        })

        -- ---------- 3px left accent bar (stops above the underline) ----------
        local accentBar = Create("Frame", {
            Parent = notifBg,
            Size = UDim2.new(0, 3, 1, -UNDERLINE_H),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundColor3 = accent,
            BorderSizePixel = 0,
            ZIndex = 201,
        })

        -- ---------- glyph (16px, mt-0.5) ----------
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

        -- ---------- title row: tracked uppercase title + optional spinner ----------
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

        -- ---------- countdown (top-right, mono 10, white @25%) ----------
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

        -- ---------- message (12px mono muted, truncated) ----------
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

        -- ---------- 2px depleting underline ----------
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

        -- ---------- state / lifecycle ----------
        local dismissed = false
        local hovered   = false
        local conns     = {}

        table.insert(activeNotifs, notifFrame)
        -- slide in from the right (hub-in)
        -- shadow is a child of notifFrame so it moves automatically with the parent
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
                if f == notifFrame then table.remove(activeNotifs, i) break end
            end
            Tween(notifFrame, {Position = UDim2.new(1, 10, 0, notifFrame.Position.Y.Offset)}, 0.28)
            ReflowNotifs()
            task.delay(0.32, function()
                if notifFrame and notifFrame.Parent then notifFrame:Destroy() end
            end)
        end

        -- ---------- realtime countdown (frame-accurate depleting underline) ----------
        local remaining = duration
        local function StartCountdown()
            conns[#conns + 1] = RunService.RenderStepped:Connect(function(dt)
                if hovered then return end -- hover pauses the timer
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

        -- ---------- loading drivers: shimmer sweep + terminal spinner ----------
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

        -- ---------- hover + click-to-dismiss (full-surface, invisible) ----------
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

        -- ---------- handle (resolve loading toasts, live updates) ----------
        local handle = {}

        function handle.SetMessage(newMessage)
            if dismissed then return end
            msgLabel.Text = newMessage
        end

        -- Flip a loading toast into a resolved (counting-down) toast.
        -- handle.Complete(newTitle?, newMessage?, newColor?, newDuration?)
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

        Create("Frame", { -- 3px left accent bar (Terminal Line)
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
                Font = FONT_MONO,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 202,
            })
        end

        -- 2px realtime depleting underline (Terminal Line)
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
        elseif mutation == "Bloodlit"   then return Colors.Bloodlit   or Color3.fromRGB(220, 40,  40)
        elseif mutation == "Starstruck" then return Colors.Starstruck or Color3.fromRGB(255, 230, 80)
        elseif mutation == "Aurora"     then return Colors.Aurora     or Color3.fromRGB(80,  255, 200)
        else return Colors.TextMuted end
    end

    UI.Notify           = Notify
    UI.NotifyStok       = NotifyStok
    UI.GetMutationColor = GetMutationColor

    -- ====================== MAIN GUI SHELL ======================
    local ScreenGui = Create("ScreenGui", {
        Name = "MiracleHub",
        Parent = playerGui,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    ctx.ScreenGui = ScreenGui

    -- Loading Screen (Neo)
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
    Create("TextLabel", {Parent=LoadingContainer, Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,0,0,52), BackgroundTransparency=1, Text="Grow A Garden 2  \226\128\162  Full Feature Build", TextColor3=Colors.TextMuted, TextSize=12, Font=FONT_MONO, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=102})
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

    -- Main Frame
    -- Frame biasa (bukan CanvasGroup — CanvasGroup me-rasterize konten dan bikin blur).
    -- Sudut luar dibulatkan dengan UICorner di sini + UICorner & patch pada children
    -- yang menyentuh sudut (TopBar, Sidebar, ContentArea).
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
    CreateCorner(MainFrame, 14)
    CreateStroke(MainFrame, Colors.Border, 1)

    -- Pixel snap: posisi Scale 0.5 bisa jatuh di setengah pixel (viewport ganjil,
    -- mis. 1237px -> 168.5px) dan membuat SEMUA teks di window jadi blur.
    -- Snap posisi center window ke pixel bulat berbasis ukuran ScreenGui.
    local function SnapMainFramePosition()
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

    -- ====================== TOP BAR (Neo) ======================
    local TopBar = Create("Frame", {
        Name = "TopBar",
        Parent = MainFrame,
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = Colors.BackgroundLight,
        BorderSizePixel = 0,
    })
    ctx.TopBar = TopBar
    -- rounded top corners: UICorner + patch persegi di bagian bawah TopBar
    CreateCorner(TopBar, 14)
    Create("Frame", { -- patch: menutup lengkungan bawah agar hanya sudut atas yang rounded
        Parent = TopBar,
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, 1, -14),
        BackgroundColor3 = Colors.BackgroundLight,
        BorderSizePixel = 0,
    })
    Create("Frame", { -- bottom hairline
        Parent = TopBar,
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = Colors.Border,
        BorderSizePixel = 0,
    })

    -- left: "● CONNECTED" status (Neo redesign)
    local ConnDot = Create("Frame", {
        Parent = TopBar,
        Size = UDim2.new(0, 7, 0, 7),
        Position = UDim2.new(0, 18, 0.5, -3),
        BackgroundColor3 = Colors.Accent,
        BorderSizePixel = 0,
    })
    CreateCorner(ConnDot, 4)
    Create("TextLabel", {
        Parent = TopBar,
        Size = UDim2.new(0, 140, 1, 0),
        Position = UDim2.new(0, 32, 0, 0),
        BackgroundTransparency = 1,
        Text = "CONNECTED",
        TextColor3 = Colors.Accent,
        TextSize = 12,
        Font = FONT_MONO,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    -- pulse the dot subtly
    task.spawn(function()
        while ConnDot.Parent do
            Tween(ConnDot, {BackgroundTransparency = 0.6}, 0.9)
            task.wait(1)
            Tween(ConnDot, {BackgroundTransparency = 0}, 0.9)
            task.wait(1)
        end
    end)

    -- hidden SearchBox kept for bootstrap compatibility (search UI removed in redesign)
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

    -- center: unified segmented card — MIRACLEHUB | FPS n | MS n.n
    local BrandCard = Create("Frame", {
        Parent = TopBar,
        Size = UDim2.new(0, 300, 0, 30),
        Position = UDim2.new(0.5, -150, 0.5, -15),
        BackgroundColor3 = Colors.BackgroundLighter,
        BorderSizePixel = 0,
    })
    CreateCorner(BrandCard, 8)
    -- clean static border, no lime animation
    CreateStroke(BrandCard, Colors.Border, 1)

    local BrandSeg = Create("TextLabel", {
        Parent = BrandCard,
        Size = UDim2.new(0, 116, 1, 0),
        BackgroundTransparency = 1,
        RichText = true,
        Text = 'MIRACLE<font color="'..LIME_HEX..'">HUB</font>',
        TextColor3 = Colors.TextPrimary,
        TextSize = 14,
        Font = FONT_BOLD,
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    Create("Frame", { -- divider 1
        Parent = BrandCard,
        Size = UDim2.new(0, 1, 1, -10),
        Position = UDim2.new(0, 116, 0, 5),
        BackgroundColor3 = Colors.Border,
        BorderSizePixel = 0,
    })
    local FpsSeg = Create("TextLabel", {
        Parent = BrandCard,
        Size = UDim2.new(0, 92, 1, 0),
        Position = UDim2.new(0, 117, 0, 0),
        BackgroundTransparency = 1,
        RichText = true,
        Text = '<font color="#6A6D68">FPS</font>  <font color="'..LIME_HEX..'">--</font>',
        TextColor3 = Colors.TextSecondary,
        TextSize = 12,
        Font = FONT_MONO,
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    Create("Frame", { -- divider 2
        Parent = BrandCard,
        Size = UDim2.new(0, 1, 1, -10),
        Position = UDim2.new(0, 209, 0, 5),
        BackgroundColor3 = Colors.Border,
        BorderSizePixel = 0,
    })
    local MsSeg = Create("TextLabel", {
        Parent = BrandCard,
        Size = UDim2.new(0, 90, 1, 0),
        Position = UDim2.new(0, 210, 0, 0),
        BackgroundTransparency = 1,
        RichText = true,
        Text = '<font color="#6A6D68">MS</font>  --',
        TextColor3 = Colors.TextSecondary,
        TextSize = 12,
        Font = FONT_MONO,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    -- live FPS / MS meter
    do
        local frames, acc = 0, 0
        RunService.Heartbeat:Connect(function(dt)
            frames += 1
            acc += dt
            if acc >= 0.5 then
                local fps = math.floor(frames / acc + 0.5)
                ctx.CurrentFPS = fps
                local ping = 0
                pcall(function() ping = player:GetNetworkPing() * 1000 end)
                FpsSeg.Text = '<font color="#6A6D68">FPS</font>  <font color="'..LIME_HEX..'">' .. fps .. '</font>'
                MsSeg.Text  = '<font color="#6A6D68">MS</font>  ' .. string.format("%.1f", ping)
                frames, acc = 0, 0
            end
        end)
    end

    -- PageTitle kept for compatibility (bootstrap sets .Text) — hidden label
    local PageTitle = Create("TextLabel", {
        Parent = TopBar,
        Size = UDim2.new(0, 1, 0, 1),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = "Farm",
        TextTransparency = 1,
    })
    ctx.PageTitle = PageTitle

    -- right controls
    local RightControls = Create("Frame", {
        Parent = TopBar,
        Size = UDim2.new(0, 80, 1, 0),
        Position = UDim2.new(1, -80, 0, 0),
        BackgroundTransparency = 1,
    })

    local CloseButton = Create("TextButton", {
        Parent = RightControls,
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(0, 44, 0.5, -14),
        BackgroundTransparency = 1,
        Text = "\195\151",
        TextColor3 = Colors.TextSecondary,
        TextSize = 16,
        Font = FONT_BOLD,
        BorderSizePixel = 0,
        AutoButtonColor = false,
    })
    ctx.CloseButton = CloseButton

    local MinimizeButton = Create("TextButton", {
        Parent = RightControls,
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(0, 12, 0.5, -14),
        BackgroundTransparency = 1,
        Text = "\226\128\148",
        TextColor3 = Colors.TextSecondary,
        TextSize = 14,
        Font = FONT_BOLD,
        BorderSizePixel = 0,
        AutoButtonColor = false,
    })
    ctx.MinimizeButton = MinimizeButton

    CloseButton.MouseEnter:Connect(function() Tween(CloseButton, {TextColor3 = Colors.Error}, 0.15) end)
    CloseButton.MouseLeave:Connect(function() Tween(CloseButton, {TextColor3 = Colors.TextSecondary}, 0.15) end)
    MinimizeButton.MouseEnter:Connect(function() Tween(MinimizeButton, {TextColor3 = Colors.TextPrimary}, 0.15) end)
    MinimizeButton.MouseLeave:Connect(function() Tween(MinimizeButton, {TextColor3 = Colors.TextSecondary}, 0.15) end)

    -- ====================== SIDEBAR (Neo, narrow) ======================
    local SIDEBAR_W = 170
    local Sidebar = Create("Frame", {
        Parent = MainFrame,
        Size = UDim2.new(0, SIDEBAR_W, 1, -48),
        Position = UDim2.new(0, 0, 0, 48),
        BackgroundColor3 = Colors.BackgroundLight,
        BorderSizePixel = 0,
    })
    ctx.Sidebar = Sidebar
    -- rounded bottom-left corner: UICorner + patch di sisi atas & kanan
    CreateCorner(Sidebar, 14)
    Create("Frame", { -- patch atas
        Parent = Sidebar,
        Size = UDim2.new(1, 0, 0, 14),
        BackgroundColor3 = Colors.BackgroundLight,
        BorderSizePixel = 0,
    })
    Create("Frame", { -- patch kanan
        Parent = Sidebar,
        Size = UDim2.new(0, 14, 1, 0),
        Position = UDim2.new(1, -14, 0, 0),
        BackgroundColor3 = Colors.BackgroundLight,
        BorderSizePixel = 0,
    })
    Create("Frame", { -- right hairline
        Parent = Sidebar,
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, -1, 0, 0),
        BackgroundColor3 = Colors.Border,
        BorderSizePixel = 0,
    })

    local SidebarContent = Create("ScrollingFrame", {
        Parent = Sidebar,
        Size = UDim2.new(1, -1, 1, -118),
        Position = UDim2.new(0, 0, 0, 76),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Colors.Border,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    })
    CreatePadding(SidebarContent, 10)
    CreateListLayout(SidebarContent, 2)

    local SidebarButtons = {}
    ctx.SidebarButtons = SidebarButtons
    local ActivePage = "Profile"
    ctx.GetActivePage = function() return ActivePage end

    local function CreateSectionHeader(parent, text, layoutOrder)
        return Create("TextLabel", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1,
            Text = "// " .. text,
            TextColor3 = Colors.TextMuted,
            TextSize = 11,
            Font = FONT_MONO,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = layoutOrder,
        })
    end

    -- ====================== LUCIDE ICON ASSET IDs ======================
    -- Lucide Icons diupload sebagai Decal ke Roblox, lalu dipakai via ImageLabel.
    -- ImageColor3 diubah saat active/hover untuk tinting effect.
    local LUCIDE_ICONS = {
        Farm     = "rbxassetid://11818627075",  -- Leaf
        Plot     = "rbxassetid://16898674182",  -- Grid
        Shop     = "rbxassetid://16898734664",  -- ShoppingCart
        Sell     = "rbxassetid://16898669433",  -- Dollar
        Pets     = "rbxassetid://16898731301",  -- PawPrint
        Eggs     = "rbxassetid://16898669689",  -- Egg
        Player   = "rbxassetid://16898790259",  -- User
        Visuals  = "rbxassetid://16898669897",  -- Eye
        Teleport = "rbxassetid://16898675359",  -- MapPin
        Utility  = "rbxassetid://16898791187",  -- Wrench
        Mailer   = "rbxassetid://16898675156",  -- Mail
        Info     = "rbxassetid://16898673523",  -- Info
        Server   = "rbxassetid://16898729141",  -- Server
        Settings = "rbxassetid://16898619015",  -- Cog
    }

    -- =============== UNIFIED SIDEBAR INTERACTION SYSTEM ===============
    -- Every nav item shares the exact same states (matches redesign):
    --   Idle    : no bg, no glow, gray icon + gray text (low emphasis)
    --   Hover   : soft bg fade-in w/ slight green tint, brighter icon/text
    --   Pressed : slightly deeper bg
    --   Active  : dark translucent green bg + soft lime glow + left accent
    --             bar, lime icon and bright text (integrated, not a block)
    local SIDE_TWEEN      = 0.18                          -- premium, subtle
    local ACTIVE_BG_COLOR = Color3.fromRGB(38, 50, 20)    -- dark green surface
    local HOVER_BG_COLOR  = Color3.fromRGB(31, 36, 27)    -- gray w/ green tint

    local function CreateSidebarButton(parent, icon, text, layoutOrder)
        local button = Create("TextButton", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundTransparency = 1,
            BackgroundColor3 = HOVER_BG_COLOR,
            Text = "",
            BorderSizePixel = 0,
            LayoutOrder = layoutOrder,
            AutoButtonColor = false,
        })
        CreateCorner(button, 7)

        -- soft glow ring: invisible saat idle, lime lembut saat active
        local glow = Create("UIStroke", {
            Parent = button,
            Color = Colors.Accent,
            Thickness = 1,
            Transparency = 1,
        })

        -- slim lime accent bar (left edge) — grows in when active
        local indicator = Create("Frame", {
            Parent = button,
            Size = UDim2.new(0, 2, 0, 0),
            Position = UDim2.new(0, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = Colors.Accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        })
        CreateCorner(indicator, 1)

        -- Coba pakai ImageLabel dulu (Lucide asset), fallback ke TextLabel
        local assetId = LUCIDE_ICONS[text]
        local iconLabel

        if assetId then
            iconLabel = Create("ImageLabel", {
                Parent = button,
                Size = UDim2.new(0, 16, 0, 16),
                Position = UDim2.new(0, 11, 0.5, -8),
                BackgroundTransparency = 1,
                Image = assetId,
                ImageColor3 = Colors.TextMuted,      -- gray saat idle
                ImageTransparency = 0.25,
                ScaleType = Enum.ScaleType.Fit,
            })
        else
            -- fallback: TextLabel unicode seperti sebelumnya
            iconLabel = Create("TextLabel", {
                Parent = button,
                Size = UDim2.new(0, 20, 0, 20),
                Position = UDim2.new(0, 10, 0.5, -10),
                BackgroundTransparency = 1,
                Text = icon,
                TextColor3 = Colors.TextMuted,
                TextTransparency = 0.15,
                TextSize = 15,
                Font = FONT_BODY,
            })
        end

        local textLabel = Create("TextLabel", {
            Parent = button,
            Size = UDim2.new(1, -38, 1, 0),
            Position = UDim2.new(0, 34, 0, 0),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = Colors.TextSecondary,
            TextSize = 14,
            Font = FONT_BODY,
            TextXAlignment = Enum.TextXAlignment.Left,
        })

        local ref = {
            button = button, indicator = indicator, glow = glow,
            icon = iconLabel, label = textLabel, isImage = (assetId ~= nil),
            hovered = false,
        }
        SidebarButtons[text] = ref

        -- ---- shared state applicators (identical for every nav item) ----
        local function applyIdle(animate)
            local d = animate and SIDE_TWEEN or 0
            Tween(button, {BackgroundTransparency = 1}, d)
            Tween(glow, {Transparency = 1}, d)
            Tween(indicator, {Size = UDim2.new(0, 2, 0, 0), BackgroundTransparency = 1}, d)
            Tween(textLabel, {TextColor3 = Colors.TextSecondary}, d)
            textLabel.Font = FONT_BODY
            if assetId then
                Tween(iconLabel, {ImageColor3 = Colors.TextMuted, ImageTransparency = 0.25}, d)
            else
                Tween(iconLabel, {TextColor3 = Colors.TextMuted, TextTransparency = 0.15}, d)
            end
        end

        local function applyHover()
            button.BackgroundColor3 = HOVER_BG_COLOR
            Tween(button, {BackgroundTransparency = 0.45}, SIDE_TWEEN)
            Tween(textLabel, {TextColor3 = Colors.TextPrimary}, SIDE_TWEEN)
            if assetId then
                Tween(iconLabel, {ImageColor3 = Colors.TextSecondary, ImageTransparency = 0.05}, SIDE_TWEEN)
            else
                Tween(iconLabel, {TextColor3 = Colors.TextSecondary, TextTransparency = 0}, SIDE_TWEEN)
            end
        end

        local function applyPressed()
            Tween(button, {BackgroundTransparency = 0.25}, 0.08)
        end

        local function applyActive(animate)
            local d = animate and SIDE_TWEEN or 0
            button.BackgroundColor3 = ACTIVE_BG_COLOR
            Tween(button, {BackgroundTransparency = 0.15}, d)
            Tween(glow, {Transparency = 0.7}, d)
            Tween(indicator, {Size = UDim2.new(0, 2, 0, 16), BackgroundTransparency = 0}, d)
            Tween(textLabel, {TextColor3 = Colors.Accent}, d)
            textLabel.Font = FONT_BOLD
            if assetId then
                Tween(iconLabel, {ImageColor3 = Colors.Accent, ImageTransparency = 0}, d)
            else
                Tween(iconLabel, {TextColor3 = Colors.Accent, TextTransparency = 0}, d)
            end
        end

        ref.applyIdle   = applyIdle
        ref.applyActive = applyActive

        button.MouseEnter:Connect(function()
            ref.hovered = true
            if ActivePage ~= text then applyHover() end
        end)
        button.MouseLeave:Connect(function()
            ref.hovered = false
            if ActivePage ~= text then applyIdle(true) end
        end)
        button.MouseButton1Down:Connect(function()
            if ActivePage ~= text then applyPressed() end
        end)
        button.MouseButton1Up:Connect(function()
            if ActivePage ~= text and ref.hovered then applyHover() end
        end)

        return button
    end

    -- Build sidebar buttons; store refs on ctx for bootstrap wiring
    local sb = {}
    CreateSectionHeader(SidebarContent, "AUTOMATION", 1)
    sb.Farm     = CreateSidebarButton(SidebarContent, "\226\157\167", "Farm", 2)       -- ❧ leaf/plant outline
    sb.Plot     = CreateSidebarButton(SidebarContent, "\226\138\158", "Plot", 3)       -- ⊞ grid outline
    sb.Shop     = CreateSidebarButton(SidebarContent, "\226\138\161", "Shop", 4)       -- ⊡ box outline
    sb.Sell     = CreateSidebarButton(SidebarContent, "\226\138\153", "Sell", 5)       -- ⊙ circle outline
    sb.Pets     = CreateSidebarButton(SidebarContent, "\226\151\139", "Pets", 6)       -- ○ half circle outline
    sb.Eggs     = CreateSidebarButton(SidebarContent, "\226\151\141", "Eggs", 7)       -- ◍ dotted circle outline

    CreateSectionHeader(SidebarContent, "PLAYER", 8)
    sb.Player   = CreateSidebarButton(SidebarContent, "\226\138\156", "Player", 9)    -- ⊜ person outline
    sb.Visuals  = CreateSidebarButton(SidebarContent, "\226\151\142", "Visuals", 10)  -- ◎ eye/circle outline
    sb.Teleport = CreateSidebarButton(SidebarContent, "\226\150\183", "Teleport", 11) -- ▷ arrow outline

    CreateSectionHeader(SidebarContent, "MISC", 12)
    sb.Utility  = CreateSidebarButton(SidebarContent, "\226\152\134", "Utility", 13)  -- ☆ star outline (hollow)
    sb.Mailer   = CreateSidebarButton(SidebarContent, "\226\156\137", "Mailer", 14)   -- ✉ envelope outline
    sb.Info     = CreateSidebarButton(SidebarContent, "\226\132\185", "Info", 15)     -- ℹ info outline
    sb.Server   = CreateSidebarButton(SidebarContent, "\226\151\183", "Server", 16)   -- ◷ clock outline
    sb.Settings = CreateSidebarButton(SidebarContent, "\226\152\134", "Settings", 17) -- ☆ cog outline
    ctx.sidebarButtonRefs = sb

    -- ====================== PROFILE CARD (top of sidebar, Neo) ======================
    -- Same interaction system as sidebar nav items:
    -- Idle subtle, Hover slightly brighter, Pressed deeper, Active = lime glow
    local ProfileCard = Create("TextButton", {
        Parent = Sidebar,
        Size = UDim2.new(1, -20, 0, 60),
        Position = UDim2.new(0, 10, 0, 10),
        BackgroundColor3 = Colors.BackgroundLighter,
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    })
    CreateCorner(ProfileCard, 10)
    local ProfileStroke = CreateStroke(ProfileCard, Colors.Border, 1)
    local ProfileAvatarStroke -- assigned after ProfileAvatar is created (forward decl for hover handlers)
    local profileHovered = false

    ProfileCard.MouseEnter:Connect(function()
        profileHovered = true
        if ActivePage ~= "Profile" then
            Tween(ProfileCard, {BackgroundTransparency = 0.25}, SIDE_TWEEN)
            Tween(ProfileStroke, {Color = Colors.BorderLight}, SIDE_TWEEN)
            if ProfileAvatarStroke then
                Tween(ProfileAvatarStroke, {Color = Colors.BorderLight}, SIDE_TWEEN)
            end
        end
    end)
    ProfileCard.MouseLeave:Connect(function()
        profileHovered = false
        if ActivePage ~= "Profile" then
            Tween(ProfileCard, {BackgroundTransparency = 0.55}, SIDE_TWEEN)
            Tween(ProfileStroke, {Color = Colors.Border}, SIDE_TWEEN)
            if ProfileAvatarStroke then
                Tween(ProfileAvatarStroke, {Color = Colors.Border}, SIDE_TWEEN)
            end
        end
    end)
    ProfileCard.MouseButton1Down:Connect(function()
        if ActivePage ~= "Profile" then
            Tween(ProfileCard, {BackgroundTransparency = 0.1}, 0.08)
        end
    end)
    ProfileCard.MouseButton1Up:Connect(function()
        if ActivePage ~= "Profile" and profileHovered then
            Tween(ProfileCard, {BackgroundTransparency = 0.25}, SIDE_TWEEN)
        end
    end)

    -- Avatar: lebih besar, corner kecil, border tipis
    local ProfileAvatar = Create("ImageLabel", {
        Parent = ProfileCard,
        Size = UDim2.new(0, 42, 0, 42),
        Position = UDim2.new(0, 8, 0.5, -21),
        BackgroundColor3 = Colors.Surface,
        Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150",
        BorderSizePixel = 0,
    })
    CreateCorner(ProfileAvatar, 7)
    ProfileAvatarStroke = CreateStroke(ProfileAvatar, Colors.Border, 1)

    Create("TextLabel", {
        Parent = ProfileCard,
        Size = UDim2.new(1, -62, 0, 18),
        Position = UDim2.new(0, 58, 0, 11),
        BackgroundTransparency = 1,
        Text = player.DisplayName or player.Name,
        TextColor3 = Colors.TextPrimary,
        TextSize = 13,
        Font = FONT_BOLD,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local isPrime = player:GetAttribute("PrimeEnabled")
    -- ★ solid star untuk PRIME (U+2605), ☆ outline untuk FREE (U+2606)
    local PrimeLabel = Create("TextLabel", {
        Parent = ProfileCard,
        Size = UDim2.new(1, -62, 0, 16),
        Position = UDim2.new(0, 58, 0, 31),
        BackgroundTransparency = 1,
        Text = isPrime and "\226\152\133 PRIME" or "\226\152\134 FREE",
        TextColor3 = isPrime and Colors.Accent or Colors.TextMuted,
        TextSize = 11,
        Font = FONT_MONO,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    -- footer: Powered by Miracle Labs (single centered label, no icon)
    Create("TextLabel", {
        Parent = Sidebar,
        Size = UDim2.new(1, 0, 0, 16),
        Position = UDim2.new(0, 0, 1, -22),
        BackgroundTransparency = 1,
        Text = "Powered by Miracle Labs",
        TextColor3 = Colors.TextMuted,
        TextTransparency = 0.3,
        TextSize = 11,
        Font = FONT_MONO,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    -- ====================== CONTENT AREA ======================
    local ContentArea = Create("Frame", {
        Parent = MainFrame,
        Size = UDim2.new(1, -SIDEBAR_W, 1, -48),
        Position = UDim2.new(0, SIDEBAR_W, 0, 48),
        BackgroundColor3 = Colors.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    })
    ctx.ContentArea = ContentArea
    -- rounded bottom-right corner; sudut lain tak terlihat karena warna bg sama dengan MainFrame
    CreateCorner(ContentArea, 14)

    -- Page header (Neo): icon + PAGE TITLE (mono caps) + status chip, hairline below
    local PAGE_HEADER_H = 46
    local PageHeader = Create("Frame", {
        Parent = ContentArea,
        Size = UDim2.new(1, 0, 0, PAGE_HEADER_H),
        BackgroundTransparency = 1,
    })
    Create("Frame", { -- bottom hairline
        Parent = PageHeader,
        Size = UDim2.new(1, -32, 0, 1),
        Position = UDim2.new(0, 16, 1, -1),
        BackgroundColor3 = Colors.Border,
        BorderSizePixel = 0,
    })
    -- PageHeaderIcon: ImageLabel yang support ImageColor3 tinting
    -- (bisa tampil gambar Lucide atau Unicode teks sebagai fallback)
    local PageHeaderIcon = Create("ImageLabel", {
        Parent = PageHeader,
        Size = UDim2.new(0, 18, 0, 18),
        Position = UDim2.new(0, 16, 0.5, -9),
        BackgroundTransparency = 1,
        Image = LUCIDE_ICONS["Farm"] or "",  -- default ke Farm icon
        ImageColor3 = Colors.TextPrimary,
        ImageTransparency = 0.15,
        ScaleType = Enum.ScaleType.Fit,
    })
    local PageHeaderTitle = Create("TextLabel", {
        Parent = PageHeader,
        Size = UDim2.new(1, -160, 1, 0),
        Position = UDim2.new(0, 44, 0, 0),
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
        Position = UDim2.new(1, -74, 0.5, -11),
        BackgroundColor3 = Colors.BackgroundLighter,
        Text = "IDLE",
        TextColor3 = Colors.TextMuted,
        TextSize = 11,
        Font = FONT_MONO,
        BorderSizePixel = 0,
    })
    CreateCorner(PageChip, 5)
    local PageChipStroke = CreateStroke(PageChip, Colors.Border, 1)

    local ContentScroll = Create("ScrollingFrame", {
        Parent = ContentArea,
        Size = UDim2.new(1, 0, 1, -PAGE_HEADER_H),
        Position = UDim2.new(0, 0, 0, PAGE_HEADER_H),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Colors.Border,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    })
    CreatePadding(ContentScroll, 16)
    CreateListLayout(ContentScroll, 10)
    ctx.ContentScroll = ContentScroll

    -- ====================== PAGE SYSTEM (two-column masonry) ======================
    local Pages = {}
    ctx.Pages = Pages

    -- SaveState: no-op. Config persist dihapus;
    -- state sudah hidup di ctx.States selama sesi berjalan.
    local function SaveState(key, value) end
    ctx.SaveState = SaveState

    -- Column frames rebuilt on each page switch.
    local ColLeft, ColRight = nil, nil
    local _sectionCount = 0

    -- Page status chip: tracks toggle stateKeys created while building the
    -- current page; ACTIVE (lime) when any is on, IDLE otherwise.
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
        CreateListLayout(ColLeft, 10)
        ColRight = Create("Frame", {
            Parent = wrap,
            Name = "ColRight",
            Size = UDim2.new(0.5, -6, 0, 0),
            Position = UDim2.new(0.5, 6, 0, 0),
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
        })
        CreateListLayout(ColRight, 10)
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
        -- Deactivate previous item via the shared Idle applicator
        if SidebarButtons[ActivePage] and SidebarButtons[ActivePage].applyIdle then
            SidebarButtons[ActivePage].applyIdle(true)
        end

        ActivePage = pageName
        PageTitle.Text = pageName

        if SidebarButtons[pageName] then
            local s = SidebarButtons[pageName]
            -- Activate via the shared Active applicator (identical for all items)
            s.applyActive(true)
            if s.isImage then
                PageHeaderIcon.Image = s.icon.Image
                PageHeaderIcon.ImageColor3 = Color3.new(1, 1, 1)
                PageHeaderIcon.ImageTransparency = 0
            else
                -- Fallback: tunjukkan ikon default Farm jika tidak ada asset
                PageHeaderIcon.Image = LUCIDE_ICONS["Farm"] or ""
                PageHeaderIcon.ImageColor3 = Colors.TextPrimary
                PageHeaderIcon.ImageTransparency = 0.15
            end
        else
            -- Profile atau page tanpa sidebar button
            PageHeaderIcon.Image = LUCIDE_ICONS["Farm"] or ""
            PageHeaderIcon.ImageTransparency = 0.5
        end
        -- Profile card: exact same Active styling as nav items
        -- (dark green translucent bg + lime glow border); subtle saat idle
        if pageName == "Profile" then
            ProfileCard.BackgroundColor3 = ACTIVE_BG_COLOR
            Tween(ProfileCard, {BackgroundTransparency = 0.15}, SIDE_TWEEN)
            -- Strong lime outline on both the card and the avatar border
            Tween(ProfileStroke, {Color = Colors.Accent, Transparency = 0.1}, SIDE_TWEEN)
            if ProfileAvatarStroke then
                Tween(ProfileAvatarStroke, {Color = Colors.Accent, Transparency = 0.1}, SIDE_TWEEN)
            end
        else
            ProfileCard.BackgroundColor3 = Colors.BackgroundLighter
            Tween(ProfileCard, {BackgroundTransparency = 0.55}, SIDE_TWEEN)
            Tween(ProfileStroke, {Color = Colors.Border, Transparency = 0}, SIDE_TWEEN)
            if ProfileAvatarStroke then
                Tween(ProfileAvatarStroke, {Color = Colors.Border, Transparency = 0}, SIDE_TWEEN)
            end
        end
        PageHeaderTitle.Text = string.upper(pageName)

        ClearContent()
        if Pages[pageName] then Pages[pageName]() end
        RefreshPageChip()

        -- Single-column fallback: if the page only filled the left column,
        -- let it span the full width.
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

    -- Neo redesign: a "section card" is no longer a bordered collapsible box.
    -- Each section becomes a column block: a small mono divider header
    -- (like SHARED / ACCOUNT in the redesign) + a stack of control cards.
    -- Sections alternate between the two masonry columns.
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

        -- strip leading emoji from title (Neo uses clean mono headers)
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
        -- divider line fills the remaining width
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
            TextSize = 11,
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

    -- Neo: compact row — descriptions are accepted for compatibility but
    -- NOT rendered (redesign removed per-feature descriptions; use
    -- CreateInfoText "How It Works" blocks for explanations).
    local function CreateToggle(parent, text, stateKey, description, onToggle)
        local defaultState = States[stateKey] or false
        RegisterPageToggleKey(stateKey)
        local container = Create("Frame", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, 44),
            BackgroundColor3 = Colors.BackgroundLighter,
            BorderSizePixel = 0,
        })
        CreateCorner(container, 10)
        CreateStroke(container, Colors.Border, 1)

        Create("TextLabel", {
            Parent = container,
            Size = UDim2.new(1, -74, 1, 0),
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
            Size = UDim2.new(0, 40, 0, 22),
            Position = UDim2.new(1, -50, 0.5, -11),
            BackgroundColor3 = defaultState and Colors.ToggleOn or Colors.ToggleOff,
            BorderSizePixel = 0,
        })
        CreateCorner(toggleBg, 11)
        local knob = Create("Frame", {
            Parent = toggleBg,
            Size = UDim2.new(0, 16, 0, 16),
            Position = UDim2.new(0, defaultState and 21 or 3, 0.5, -8),
            BackgroundColor3 = defaultState and Colors.ToggleKnob or Colors.TextSecondary,
            BorderSizePixel = 0,
        })
        CreateCorner(knob, 8)

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
                Position = UDim2.new(0, state and 21 or 3, 0.5, -8),
                BackgroundColor3 = state and Colors.ToggleKnob or Colors.TextSecondary,
            }, 0.2)
            if onToggle then
                onToggle(state, function()
                    state = false
                    States[stateKey] = false
                    SaveState(stateKey, false)
                    Tween(toggleBg, {BackgroundColor3 = Colors.ToggleOff}, 0.2)
                    Tween(knob, {Position = UDim2.new(0, 3, 0.5, -8), BackgroundColor3 = Colors.TextSecondary}, 0.2)
                    RefreshPageChip()
                end)
            end
            RefreshPageChip()
        end)
        return container, function() return state end
    end

    local function CreateSlider(parent, text, minVal, maxVal, stateKey, suffix, onChange)
        local defaultVal = States[stateKey] or minVal
        local container = Create("Frame", {
            Parent = parent,
            Size = UDim2.new(1, 0, 0, 62),
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
            TextSize = 12,
            Font = FONT_MONO,
            BorderSizePixel = 0,
        })
        CreateCorner(valLabel, 6)
        CreateStroke(valLabel, Colors.BorderLight, 1)

        local track = Create("Frame", {
            Parent = container,
            Size = UDim2.new(1, -28, 0, 4),
            Position = UDim2.new(0, 14, 0, 44),
            BackgroundColor3 = Colors.SliderTrack,
            BorderSizePixel = 0,
        })
        CreateCorner(track, 2)
        local fillPct = (defaultVal - minVal) / math.max(maxVal - minVal, 1)
        local fill = Create("Frame", {
            Parent = track,
            Size = UDim2.new(fillPct, 0, 1, 0),
            BackgroundColor3 = Colors.SliderFill,
            BorderSizePixel = 0,
        })
        CreateCorner(fill, 2)
        local sliderKnob = Create("Frame", {
            Parent = track,
            Size = UDim2.new(0, 12, 0, 12),
            Position = UDim2.new(fillPct, -6, 0.5, -6),
            BackgroundColor3 = Colors.Accent,
            BorderSizePixel = 0,
        })
        CreateCorner(sliderKnob, 6)

        local dragging = false
        local trackBtn = Create("TextButton", {
            Parent = container,
            Size = UDim2.new(1, -28, 0, 24),
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
            Tween(sliderKnob, {Position = UDim2.new(pct, -6, 0.5, -6)}, 0.05)
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
            Size = UDim2.new(1, 0, 0, 44),
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
            Size = UDim2.new(1, 0, 0, 44),
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
            Text = label .. '  <font color="#6A6D68">\194\183 ' .. tostring(currentVal) .. '</font>',
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
            TextSize = 12,
            Font = FONT_BOLD,
        })
        btn.MouseEnter:Connect(function() Tween(btn, {BackgroundColor3 = Colors.Surface, BackgroundTransparency = 0}, 0.15) end)
        btn.MouseLeave:Connect(function() Tween(btn, {BackgroundColor3 = Colors.Background, BackgroundTransparency = 0.35}, 0.15) end)

        local isOpen = false
        local dropPanel = nil
        btn.MouseButton1Click:Connect(function()
            isOpen = not isOpen
            Tween(arr, {Rotation = isOpen and 180 or 0}, 0.2)
            if isOpen then
                dropPanel = Create("Frame", {
                    Parent = ScreenGui,
                    Size = UDim2.new(0, container.AbsoluteSize.X, 0, math.min(#options * 30, 160)),
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
                CreatePadding(scroll, 4)
                for _, opt in ipairs(options) do
                    local isCur = (opt == currentVal)
                    local item = Create("TextButton", {
                        Parent = scroll,
                        Size = UDim2.new(1, 0, 0, 26),
                        BackgroundTransparency = isCur and 0.88 or 1,
                        BackgroundColor3 = Colors.Accent,
                        Text = "",
                        ZIndex = 152,
                        AutoButtonColor = false,
                    })
                    CreateCorner(item, 6)
                    Create("TextLabel", {
                        Parent = item,
                        Size = UDim2.new(1, -34, 1, 0),
                        Position = UDim2.new(0, 10, 0, 0),
                        BackgroundTransparency = 1,
                        Text = opt,
                        TextColor3 = isCur and Colors.Accent or Colors.TextSecondary,
                        TextSize = 13,
                        Font = isCur and FONT_BOLD or FONT_BODY,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 153,
                    })
                    if isCur then
                        Create("TextLabel", {
                            Parent = item,
                            Size = UDim2.new(0, 20, 1, 0),
                            Position = UDim2.new(1, -26, 0, 0),
                            BackgroundTransparency = 1,
                            Text = "\226\156\147",
                            TextColor3 = Colors.Accent,
                            TextSize = 13,
                            Font = FONT_BOLD,
                            ZIndex = 153,
                        })
                    end
                    item.MouseEnter:Connect(function()
                        if opt ~= currentVal then
                            item.BackgroundColor3 = Colors.Surface
                            item.BackgroundTransparency = 0.5
                        end
                    end)
                    item.MouseLeave:Connect(function()
                        item.BackgroundColor3 = (opt == currentVal) and Colors.Accent or Colors.Surface
                        item.BackgroundTransparency = (opt == currentVal) and 0.88 or 1
                    end)
                    item.MouseButton1Click:Connect(function()
                        currentVal = opt
                        States[stateKey] = opt
                        SaveState(stateKey, opt)
                        lbl.Text = label .. '  <font color="#6A6D68">\194\183 ' .. tostring(opt) .. '</font>'
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

    -- Multi-select — Neo: header pill "Label · summary" + inline list,
    -- checkmark on the RIGHT, lime tint on selected rows.
    -- Returns { instance, SetDisabled } (same as before).
    local function CreateMultiSelect(parent, label, options, stateKey)
        if type(States[stateKey]) ~= "table" then States[stateKey] = {} end
        local selected = States[stateKey]

        -- strip leading emoji from label (Neo uses clean text labels)
        local pillText = label:gsub("^[%z\1-\127\194-\244][\128-\191]*%s*", "")
        if pillText == "" then pillText = label end

        local function getShortText()
            if #selected == 0 then
                return pillText .. '  <font color="#6A6D68">\194\183 none</font>'
            end
            if #selected <= 2 then
                local names = {}
                for _, s in ipairs(selected) do names[#names+1] = s end
                return pillText .. '  <font color="#6A6D68">\194\183 ' .. table.concat(names, ", ") .. '</font>'
            end
            return pillText .. '  <font color="#6A6D68">\194\183 ' .. #selected .. ' selected</font>'
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
            Size = UDim2.new(1, 0, 0, 44),
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
        local arrowLbl = Create("TextLabel", {
            Parent = pill,
            Size = UDim2.new(0, 26, 1, 0),
            Position = UDim2.new(1, -32, 0, 0),
            BackgroundTransparency = 1,
            Text = "\226\150\190",
            TextColor3 = Colors.Accent,
            TextSize = 12,
            Font = FONT_BOLD,
            TextXAlignment = Enum.TextXAlignment.Center,
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

        -- top hairline separating header from list
        local headerRow = Create("Frame", {
            Parent = panel,
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        })
        Create("Frame", {
            Parent = headerRow,
            Size = UDim2.new(1, -16, 0, 1),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundColor3 = Colors.Border,
            BorderSizePixel = 0,
        })

        local selAllBtn = Create("TextButton", {
            Parent = headerRow,
            Size = UDim2.new(0, 56, 0, 22),
            Position = UDim2.new(0, 10, 0.5, -9),
            BackgroundColor3 = Colors.Surface,
            Text = "\226\156\148 All",
            TextColor3 = Colors.Accent,
            TextSize = 11,
            Font = FONT_MONO,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            ZIndex = 3,
        })
        CreateCorner(selAllBtn, 5)
        CreateStroke(selAllBtn, Colors.Border, 1)
        selAllBtn.MouseEnter:Connect(function() Tween(selAllBtn, {BackgroundColor3 = Colors.SurfaceLight}, 0.1) end)
        selAllBtn.MouseLeave:Connect(function() Tween(selAllBtn, {BackgroundColor3 = Colors.Surface}, 0.1) end)

        local clearBtn = Create("TextButton", {
            Parent = headerRow,
            Size = UDim2.new(0, 60, 0, 22),
            Position = UDim2.new(0, 72, 0.5, -9),
            BackgroundColor3 = Colors.Surface,
            Text = "\226\156\151 Clear",
            TextColor3 = Colors.TextMuted,
            TextSize = 11,
            Font = FONT_MONO,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            ZIndex = 3,
        })
        CreateCorner(clearBtn, 5)
        CreateStroke(clearBtn, Colors.Border, 1)
        clearBtn.MouseEnter:Connect(function() Tween(clearBtn, {BackgroundColor3 = Colors.SurfaceLight}, 0.1) end)
        clearBtn.MouseLeave:Connect(function() Tween(clearBtn, {BackgroundColor3 = Colors.Surface}, 0.1) end)

        local LIST_MAX_H = 190
        local scroll = Create("ScrollingFrame", {
            Parent = panel,
            Size = UDim2.new(1, 0, 0, math.min(#options * 28, LIST_MAX_H)),
            Position = UDim2.new(0, 0, 0, 32),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Colors.Border,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ZIndex = 2,
        })
        CreateListLayout(scroll, 1)
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
                Size = UDim2.new(1, 0, 0, 28),
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
                Text = opt,
                TextColor3 = sel and Colors.Accent or Colors.TextSecondary,
                TextSize = 13,
                Font = sel and FONT_BOLD or FONT_BODY,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 4,
            })
            -- checkmark on the RIGHT (Neo)
            local checkLbl = Create("TextLabel", {
                Parent = row,
                Size = UDim2.new(0, 22, 1, 0),
                Position = UDim2.new(1, -28, 0, 0),
                BackgroundTransparency = 1,
                Text = sel and "\226\156\147" or "",
                TextColor3 = Colors.Accent,
                TextSize = 13,
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

            hitBtn.MouseEnter:Connect(function()
                if isDisabled then return end
                if not isSelected(opt) then
                    row.BackgroundColor3 = Colors.Surface
                    row.BackgroundTransparency = 0.5
                end
            end)
            hitBtn.MouseLeave:Connect(function()
                if isDisabled then return end
                if not isSelected(opt) then
                    row.BackgroundColor3 = Colors.Accent
                    row.BackgroundTransparency = 1
                end
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

        pill.MouseButton1Click:Connect(function()
            if isDisabled then return end
            isOpen = not isOpen
            Tween(arrowLbl, {Rotation = isOpen and 180 or 0}, 0.2)
            if isOpen then
                panel.Visible = true
                panel.Size = UDim2.new(1, 0, 0, 0)
                local targetH = 32 + math.min(#options * 28, LIST_MAX_H) + 8
                Tween(panel, {Size = UDim2.new(1, 0, 0, targetH)}, 0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            else
                Tween(panel, {Size = UDim2.new(1, 0, 0, 0)}, 0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
                task.delay(0.19, function()
                    if not isOpen then panel.Visible = false end
                end)
            end
        end)

        -- Expose disable/enable API — dipanggil dari luar (e.g. Buy ALL toggle)
        local function SetDisabled(disabled)
            isDisabled = disabled

            if disabled and isOpen then
                isOpen = false
                Tween(arrowLbl, {Rotation = 0}, 0.18)
                Tween(panel, {Size = UDim2.new(1, 0, 0, 0)}, 0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
                task.delay(0.19, function()
                    if not isOpen then panel.Visible = false end
                end)
            end

            local dimAlpha = disabled and 0.55 or 0
            Tween(wrapper, {BackgroundTransparency = disabled and 0.5 or 0}, 0.18)
            Tween(pillLabel, {TextTransparency = dimAlpha}, 0.18)
            Tween(arrowLbl,  {TextTransparency = dimAlpha}, 0.18)

            selAllBtn.Active  = not disabled
            clearBtn.Active   = not disabled
            selAllBtn.TextTransparency = dimAlpha
            clearBtn.TextTransparency  = dimAlpha
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
                TextSize = 11,
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
            TextSize = 12,
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
            Size = UDim2.new(1, 0, 0, 40),
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
            TextSize = 13,
            Font = FONT_MONO,
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


    -- ====================== BUILT-IN PROFILE PAGE (Neo redesign) ======================
    local sessionStart = os.clock()
    registerPage("Profile", function()
        -- Profile page uses full-width single column (ColLeft spans full width)
        -- Layout order (matching redesign): identity card → 4 stat boxes → ACCOUNT section
        local col = ColLeft

        local isPrime = player:GetAttribute("PrimeEnabled") and true or false

        -- ── Identity card (avatar + display name + username + prime badge) ──
        local idCard = Create("Frame", {
            Parent = col,
            Size = UDim2.new(1, 0, 0, 88),
            BackgroundColor3 = Colors.BackgroundLighter,
            BorderSizePixel = 0,
            LayoutOrder = 1,
        })
        CreateCorner(idCard, 12)
        CreateStroke(idCard, Colors.Border, 1)

        -- Avatar (left side)
        local av = Create("ImageLabel", {
            Parent = idCard,
            Size = UDim2.new(0, 56, 0, 56),
            Position = UDim2.new(0, 16, 0.5, -28),
            BackgroundColor3 = Colors.Surface,
            Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150",
            BorderSizePixel = 0,
        })
        CreateCorner(av, 10)
        CreateStroke(av, Colors.BorderLight, 1)

        -- Display name (bold, 18px — biggest text on the card)
        Create("TextLabel", {
            Parent = idCard,
            Size = UDim2.new(1, -170, 0, 24),
            Position = UDim2.new(0, 88, 0, 20),
            BackgroundTransparency = 1,
            Text = player.DisplayName or player.Name,
            TextColor3 = Colors.TextPrimary,
            TextSize = 18,
            Font = FONT_BOLD,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })

        -- Username subtitle (@name, mono, muted, 13px)
        Create("TextLabel", {
            Parent = idCard,
            Size = UDim2.new(1, -170, 0, 18),
            Position = UDim2.new(0, 88, 0, 48),
            BackgroundTransparency = 1,
            Text = player.Name,
            TextColor3 = Colors.TextMuted,
            TextSize = 13,
            Font = FONT_MONO,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })

        -- Prime badge (top-right of card)
        local badge = Create("TextLabel", {
            Parent = idCard,
            Size = UDim2.new(0, 78, 0, 22),
            Position = UDim2.new(1, -94, 0, 20),
            BackgroundColor3 = Colors.Background,
            Text = isPrime and "\226\152\133 PRIME" or "FREE",
            TextColor3 = isPrime and Colors.Accent or Colors.TextMuted,
            TextSize = 11,
            Font = FONT_MONO,
            BorderSizePixel = 0,
        })
        CreateCorner(badge, 5)
        CreateStroke(badge, isPrime and Colors.BorderLight or Colors.Border, 1)

        -- ── 4-stat row (SESSION · ACTIONS RUN · AVG FPS · UPTIME) ──
        -- Uses a horizontal UIListLayout for equal-width cells
        local statRow = Create("Frame", {
            Parent = col,
            Size = UDim2.new(1, 0, 0, 88),
            BackgroundTransparency = 1,
            LayoutOrder = 2,
        })
        Create("UIListLayout", {
            Parent = statRow,
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })

        local function statCell(order, icon, valueText, labelText)
            local cell = Create("Frame", {
                Parent = statRow,
                -- 4 cells with 3 gaps of 8px each: (1 - 3*8/totalW) / 4
                Size = UDim2.new(0.25, -6, 1, 0),
                BackgroundColor3 = Colors.BackgroundLighter,
                BorderSizePixel = 0,
                LayoutOrder = order,
            })
            CreateCorner(cell, 10)
            CreateStroke(cell, Colors.Border, 1)

            -- Small icon/symbol (accent color, top-left inside cell)
            Create("TextLabel", {
                Parent = cell,
                Size = UDim2.new(0, 20, 0, 20),
                Position = UDim2.new(0, 14, 0, 12),
                BackgroundTransparency = 1,
                Text = icon,
                TextColor3 = Colors.Accent,
                TextSize = 13,
                Font = FONT_BODY,
            })

            -- Value (large, bold mono — the number people care about)
            local v = Create("TextLabel", {
                Parent = cell,
                Size = UDim2.new(1, -14, 0, 26),
                Position = UDim2.new(0, 14, 0, 34),
                BackgroundTransparency = 1,
                Text = valueText,
                TextColor3 = Colors.TextPrimary,
                TextSize = 20,
                Font = FONT_MONO,
                TextXAlignment = Enum.TextXAlignment.Left,
            })

            -- Label (all-caps mono, muted, small but legible)
            Create("TextLabel", {
                Parent = cell,
                Size = UDim2.new(1, -14, 0, 14),
                Position = UDim2.new(0, 14, 0, 62),
                BackgroundTransparency = 1,
                Text = labelText,
                TextColor3 = Colors.TextMuted,
                TextSize = 10,
                Font = FONT_MONO,
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            return v
        end

        local sessionVal = statCell(1, "\226\143\177", "00:00:00", "SESSION")
        local actionsVal = statCell(2, "\226\154\161", tostring(States.ActionsRun or 0), "ACTIONS RUN")
        local fpsVal     = statCell(3, "\226\151\148", "60", "AVG FPS")
        statCell(4, "\226\136\191", "99.8%", "UPTIME")

        -- Live session clock + FPS + actions counter
        task.spawn(function()
            while sessionVal.Parent do
                local el = os.clock() - sessionStart
                sessionVal.Text = string.format("%02d:%02d:%02d",
                    math.floor(el/3600), math.floor(el%3600/60), math.floor(el%60))
                if ctx.CurrentFPS then fpsVal.Text = tostring(ctx.CurrentFPS) end
                if States.ActionsRun then actionsVal.Text = tostring(States.ActionsRun) end
                task.wait(1)
            end
        end)

        -- ── ACCOUNT section label ──
        Create("TextLabel", {
            Parent = col,
            Size = UDim2.new(1, 0, 0, 20),
            BackgroundTransparency = 1,
            Text = "ACCOUNT",
            TextColor3 = Colors.TextMuted,
            TextSize = 11,
            Font = FONT_MONO,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 3,
        })

        -- ── ACCOUNT rows (Plan · Member Since · Hub Version · Game) ──
        local accountBlock = Create("Frame", {
            Parent = col,
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 4,
        })
        CreateListLayout(accountBlock, 6)

        local function accountRow(icon, labelText, valueText)
            local r = Create("Frame", {
                Parent = accountBlock,
                Size = UDim2.new(1, 0, 0, 48),
                BackgroundColor3 = Colors.BackgroundLighter,
                BorderSizePixel = 0,
            })
            CreateCorner(r, 10)
            CreateStroke(r, Colors.Border, 1)

            -- Icon (left, muted)
            Create("TextLabel", {
                Parent = r,
                Size = UDim2.new(0, 20, 1, 0),
                Position = UDim2.new(0, 16, 0, 0),
                BackgroundTransparency = 1,
                Text = icon,
                TextColor3 = Colors.TextMuted,
                TextSize = 14,
                Font = FONT_BODY,
            })

            -- Label (left side, primary text, 14px Gotham)
            Create("TextLabel", {
                Parent = r,
                Size = UDim2.new(0.5, -50, 1, 0),
                Position = UDim2.new(0, 44, 0, 0),
                BackgroundTransparency = 1,
                Text = labelText,
                TextColor3 = Colors.TextPrimary,
                TextSize = 14,
                Font = FONT_BODY,
                TextXAlignment = Enum.TextXAlignment.Left,
            })

            -- Value (right side, accent lime mono, 13px)
            Create("TextLabel", {
                Parent = r,
                Size = UDim2.new(0.5, -16, 1, 0),
                Position = UDim2.new(0.5, 0, 0, 0),
                BackgroundTransparency = 1,
                Text = valueText,
                TextColor3 = Colors.Accent,
                TextSize = 13,
                Font = FONT_MONO,
                TextXAlignment = Enum.TextXAlignment.Right,
            })
        end

        accountRow("\226\151\136", "Plan",         isPrime and "Prime \194\183 Lifetime" or "Free")
        accountRow("\226\143\177", "Member Since",  os.date("%b %Y"))
        accountRow("\226\154\161", "Hub Version",   ctx.HubVersion or "v3.2.1")
        accountRow("\240\159\140\177", "Game",      "Grow A Garden 2")
    end)

    ProfileCard.MouseButton1Click:Connect(function()
        SetActivePage("Profile")
    end)

    ctx.UI = UI
    return ctx
end