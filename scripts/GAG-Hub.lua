local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local State = {
    AutoHarvest = false,
    PetTracker = false,
    HarvestESP = false,
    PetESP = false,
    AutoHarvestDelay = 0.5,
}

local ESPObjects = {}

local Colors = {
    Background  = Color3.fromRGB(30, 35, 28),
    Header      = Color3.fromRGB(45, 55, 40),
    Accent      = Color3.fromRGB(76, 175, 80),
    Text        = Color3.fromRGB(235, 240, 230),
    TextDim     = Color3.fromRGB(160, 170, 155),
    ButtonBg    = Color3.fromRGB(50, 60, 45),
    ToggleOff   = Color3.fromRGB(80, 40, 40),
    ToggleOn    = Color3.fromRGB(46, 125, 50),
    Panel       = Color3.fromRGB(35, 40, 32),
    Warning     = Color3.fromRGB(255, 152, 0),
    Error       = Color3.fromRGB(244, 67, 54),
    Success     = Color3.fromRGB(102, 187, 106),
}

-- Helpers

local function cleanESPByPrefix(prefix)
    for k, v in pairs(ESPObjects) do
        if k:sub(1, #prefix) == prefix then
            pcall(function() v:Destroy() end)
            ESPObjects[k] = nil
        end
    end
end

local function makeDraggable(window, handle)
    local dragging, dragStart, startPos = false, nil, nil
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = i.Position
            startPos = window.Position
        end
    end)
    handle.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    handle.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- Iterate every ProximityPrompt named "HarvestPrompt" across all plots
local function iterateHarvestPrompts(callback)
    local gardens = Workspace:FindFirstChild("Gardens")
    if not gardens then return end
    for _, plot in ipairs(gardens:GetChildren()) do
        if plot:IsA("Model") then
            local plants = plot:FindFirstChild("Plants")
            if plants then
                for _, plant in ipairs(plants:GetChildren()) do
                    -- Direct HarvestPart on plant
                    local hp = plant:FindFirstChild("HarvestPart")
                    if hp then
                        local prompt = hp:FindFirstChild("HarvestPrompt")
                        if prompt then callback(prompt, plant) end
                    end
                    -- HarvestParts inside Fruits folder
                    local fruits = plant:FindFirstChild("Fruits")
                    if fruits then
                        for _, fruit in ipairs(fruits:GetChildren()) do
                            local fhp = fruit:FindFirstChild("HarvestPart")
                            if fhp then
                                local fprompt = fhp:FindFirstChild("HarvestPrompt")
                                if fprompt then callback(fprompt, fruit) end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- GUI

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GAG_Hub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
if not pcall(function() ScreenGui.Parent = CoreGui end) then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local MainWindow = Instance.new("Frame")
MainWindow.Name = "MainWindow"
MainWindow.Size = UDim2.new(0, 480, 0, 360)
MainWindow.Position = UDim2.new(0.5, -240, 0.5, -180)
MainWindow.BackgroundColor3 = Colors.Background
MainWindow.BorderSizePixel = 0
MainWindow.Parent = ScreenGui

do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 10)
    c.Parent = MainWindow
end

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Colors.Header
Header.BorderSizePixel = 0
Header.Parent = MainWindow
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 10)
    c.Parent = Header
end

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -80, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "GAG Hub  v1.0"
Title.TextColor3 = Colors.Text
Title.TextSize = 15
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -33, 0, 6)
CloseBtn.BackgroundColor3 = Colors.Error
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Colors.Text
CloseBtn.TextSize = 13
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = Header
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = CloseBtn
end
CloseBtn.MouseButton1Click:Connect(function()
    cleanESPByPrefix("harvest_")
    cleanESPByPrefix("pet_")
    ScreenGui:Destroy()
end)

makeDraggable(MainWindow, Header)

-- Tab bar
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, 0, 0, 35)
TabBar.Position = UDim2.new(0, 0, 0, 40)
TabBar.BackgroundColor3 = Colors.Panel
TabBar.BorderSizePixel = 0
TabBar.Parent = MainWindow
do
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 2)
    layout.Parent = TabBar
end

local tabButtons, tabPages = {}, {}

local function createTab(name, index)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 90, 1, 0)
    btn.BackgroundColor3 = (index == 1) and Colors.Accent or Colors.ButtonBg
    btn.Text = name
    btn.TextColor3 = Colors.Text
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamMedium
    btn.Parent = TabBar
    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = btn
    end

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, -20, 1, -95)
    page.Position = UDim2.new(0, 10, 0, 80)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = Colors.Accent
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.Visible = (index == 1)
    page.Parent = MainWindow
    do
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 8)
        layout.Parent = page
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 16)
        end)
    end

    btn.MouseButton1Click:Connect(function()
        for _, t in pairs(tabButtons) do t.BackgroundColor3 = Colors.ButtonBg end
        for _, p in pairs(tabPages) do p.Visible = false end
        btn.BackgroundColor3 = Colors.Accent
        page.Visible = true
    end)

    tabButtons[index] = btn
    tabPages[index] = page
    return page
end

-- Components

local function createToggle(parent, text, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 38)
    container.BackgroundTransparency = 1
    container.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -65, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Colors.Text
    lbl.TextSize = 13
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = container

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 52, 0, 24)
    toggle.Position = UDim2.new(1, -57, 0.5, -12)
    toggle.BackgroundColor3 = Colors.ToggleOff
    toggle.Text = "OFF"
    toggle.TextColor3 = Colors.Text
    toggle.TextSize = 10
    toggle.Font = Enum.Font.GothamBold
    toggle.Parent = container
    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 12)
        c.Parent = toggle
    end

    local on = false
    toggle.MouseButton1Click:Connect(function()
        on = not on
        toggle.BackgroundColor3 = on and Colors.ToggleOn or Colors.ToggleOff
        toggle.Text = on and "ON" or "OFF"
        callback(on)
    end)
end

local function createButton(parent, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 33)
    btn.BackgroundColor3 = Colors.ButtonBg
    btn.Text = text
    btn.TextColor3 = Colors.Text
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamMedium
    btn.Parent = parent
    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = btn
    end
    btn.MouseButton1Click:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Colors.Accent}):Play()
        task.delay(0.15, function()
            TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Colors.ButtonBg}):Play()
        end)
        callback()
    end)
end

local function createLabel(parent, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 18)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Colors.TextDim
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = parent
end

-- ============================================================
-- TAB 1: AUTO FARM
-- ============================================================
local farmPage = createTab("Auto Farm", 1)

createLabel(farmPage, "-- Harvest Automation --")

createToggle(farmPage, "Auto Harvest (all plots)", function(state)
    State.AutoHarvest = state
    if state then
        task.spawn(function()
            while State.AutoHarvest do
                iterateHarvestPrompts(function(prompt)
                    pcall(fireproximityprompt, prompt)
                end)
                task.wait(State.AutoHarvestDelay)
            end
        end)
    end
end)

createLabel(farmPage, "-- ESP / Highlight --")

createToggle(farmPage, "Harvest ESP (highlight ready)", function(state)
    State.HarvestESP = state
    if state then
        task.spawn(function()
            while State.HarvestESP do
                cleanESPByPrefix("harvest_")
                iterateHarvestPrompts(function(_, model)
                    local key = "harvest_" .. tostring(model)
                    if not ESPObjects[key] then
                        local hl = Instance.new("Highlight")
                        hl.FillColor = Colors.Success
                        hl.FillTransparency = 0.5
                        hl.OutlineColor = Colors.Text
                        hl.Adornee = model
                        hl.Parent = ScreenGui
                        ESPObjects[key] = hl
                    end
                end)
                task.wait(2)
            end
        end)
    else
        cleanESPByPrefix("harvest_")
    end
end)

createLabel(farmPage, "")
createLabel(farmPage, "Tip: panen semua HarvestPrompt di semua plot.")

-- ============================================================
-- TAB 2: WILD PETS
-- ============================================================
local petPage = createTab("Wild Pets", 2)

createLabel(petPage, "-- Wild Pet Tracker --")

createToggle(petPage, "Pet Notifier (popup alert)", function(state)
    State.PetTracker = state
    if not state then return end
    local knownPets = {}
    task.spawn(function()
        while State.PetTracker do
            local wildPetSpawns = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("WildPetSpawns")
            if wildPetSpawns then
                -- detect new
                for _, pet in ipairs(wildPetSpawns:GetChildren()) do
                    if not knownPets[pet] then
                        knownPets[pet] = true
                        local petType = pet.Name:match("WildPet_(.-)_WildPet_")
                        if petType then
                            task.spawn(function()
                                local notif = Instance.new("Frame")
                                notif.Size = UDim2.new(0, 300, 0, 58)
                                notif.Position = UDim2.new(0.5, -150, 0, -70)
                                notif.BackgroundColor3 = Colors.Header
                                notif.Parent = ScreenGui
                                do
                                    local c = Instance.new("UICorner")
                                    c.CornerRadius = UDim.new(0, 8)
                                    c.Parent = notif
                                end

                                local t1 = Instance.new("TextLabel")
                                t1.Size = UDim2.new(1, -16, 0, 24)
                                t1.Position = UDim2.new(0, 8, 0, 4)
                                t1.BackgroundTransparency = 1
                                t1.Text = "Wild Pet Spawned!"
                                t1.TextColor3 = Colors.Warning
                                t1.TextSize = 13
                                t1.Font = Enum.Font.GothamBold
                                t1.TextXAlignment = Enum.TextXAlignment.Left
                                t1.Parent = notif

                                local t2 = Instance.new("TextLabel")
                                t2.Size = UDim2.new(1, -16, 0, 20)
                                t2.Position = UDim2.new(0, 8, 0, 30)
                                t2.BackgroundTransparency = 1
                                t2.Text = "Type: " .. petType
                                t2.TextColor3 = Colors.Text
                                t2.TextSize = 12
                                t2.Font = Enum.Font.Gotham
                                t2.TextXAlignment = Enum.TextXAlignment.Left
                                t2.Parent = notif

                                TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {Position = UDim2.new(0.5, -150, 0, 10)}):Play()
                                task.wait(5)
                                TweenService:Create(notif, TweenInfo.new(0.3), {Position = UDim2.new(0.5, -150, 0, -70)}):Play()
                                task.wait(0.35)
                                pcall(function() notif:Destroy() end)
                            end)
                        end
                    end
                end
                -- clean despawned
                for pet, _ in pairs(knownPets) do
                    if not pet.Parent then
                        knownPets[pet] = nil
                    end
                end
            end
            task.wait(1)
        end
    end)
end)

createToggle(petPage, "Pet ESP (highlight wild pets)", function(state)
    State.PetESP = state
    if state then
        task.spawn(function()
            while State.PetESP do
                cleanESPByPrefix("pet_")
                local wildPetSpawns = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("WildPetSpawns")
                if wildPetSpawns then
                    for _, pet in ipairs(wildPetSpawns:GetChildren()) do
                        if pet:IsA("Model") then
                            local key = "pet_" .. tostring(pet)
                            local hl = Instance.new("Highlight")
                            hl.FillColor = Colors.Warning
                            hl.FillTransparency = 0.4
                            hl.OutlineColor = Colors.Text
                            hl.Adornee = pet
                            hl.Parent = ScreenGui
                            ESPObjects[key] = hl
                        end
                    end
                end
                task.wait(1)
            end
        end)
    else
        cleanESPByPrefix("pet_")
    end
end)

createLabel(petPage, "")
createLabel(petPage, "Deteksi Bunny, Frog, Owl, Robin, dll.")

-- ============================================================
-- TAB 3: TELEPORT
-- ============================================================
local tpPage = createTab("Teleport", 3)

local function tpTo(target)
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp and target then
        local pos = target:IsA("BasePart") and target.Position or target:GetPivot().Position
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 5, 5))
    end
end

createLabel(tpPage, "-- NPC & Shops --")

local namedLocations = {
    {"Seeds Shop",    function() return Workspace.Map.Stands.Seeds end},
    {"Sell Stand",    function() return Workspace.Map.Stands.Sell end},
    {"Props Shop",    function() return Workspace.Map.Stands.Props end},
    {"Steven NPC",    function() return Workspace.NPCS.Steven end},
    {"Charlotte NPC", function() return Workspace.NPCS.Charlotte end},
    {"Gilbert NPC",   function() return Workspace.NPCS.Gilbert end},
    {"George NPC",    function() return Workspace.NPCS.Model.George end},
    {"Sam NPC",       function() return Workspace.NPCS.Sam end},
}

for _, loc in ipairs(namedLocations) do
    local name, getTarget = loc[1], loc[2]
    createButton(tpPage, "TP: " .. name, function()
        pcall(function() tpTo(getTarget()) end)
    end)
end

createLabel(tpPage, "")
createLabel(tpPage, "-- Garden Plots --")

for i = 1, 8 do
    createButton(tpPage, "TP: Plot " .. i, function()
        local plot = Workspace.Gardens and Workspace.Gardens:FindFirstChild("Plot" .. i)
        if plot then
            -- Use PlotSizeReference part (confirmed in scanner)
            local ref = plot:FindFirstChild("PlotSizeReference")
            tpTo(ref or plot)
        end
    end)
end

-- ============================================================
-- TAB 4: WEATHER
-- ============================================================
local worldPage = createTab("Weather", 4)

createLabel(worldPage, "-- Active Weather Monitor --")

local weatherTypes = {
    {name = "Rain",      color = Colors.Accent},
    {name = "Lightning", color = Colors.Warning},
    {name = "Bloodmoon", color = Colors.Error},
    {name = "Snowfall",  color = Colors.Text},
    {name = "Starfall",  color = Colors.Warning},
    {name = "Rainbow",   color = Colors.Success},
    {name = "Night",     color = Colors.TextDim},
}

local weatherStatusLabels = {}

for _, weather in ipairs(weatherTypes) do
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 28)
    row.BackgroundTransparency = 1
    row.Parent = worldPage

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 10, 0, 10)
    dot.Position = UDim2.new(0, 4, 0.5, -5)
    dot.BackgroundColor3 = weather.color
    dot.Parent = row
    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(1, 0)
        c.Parent = dot
    end

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(0, 160, 1, 0)
    nameLbl.Position = UDim2.new(0, 22, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = weather.name
    nameLbl.TextColor3 = Colors.Text
    nameLbl.TextSize = 12
    nameLbl.Font = Enum.Font.Gotham
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.Parent = row

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(0, 120, 1, 0)
    statusLbl.Position = UDim2.new(1, -125, 0, 0)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = "Inactive"
    statusLbl.TextColor3 = Colors.TextDim
    statusLbl.TextSize = 11
    statusLbl.Font = Enum.Font.GothamMedium
    statusLbl.TextXAlignment = Enum.TextXAlignment.Right
    statusLbl.Parent = row

    weatherStatusLabels[weather.name] = statusLbl
end

-- Weather monitor - reads SoundService.WeatherSFX which is confirmed in scanner
task.spawn(function()
    while true do
        local weatherSFX = game:GetService("SoundService"):FindFirstChild("WeatherSFX")
        for _, weather in ipairs(weatherTypes) do
            local lbl = weatherStatusLabels[weather.name]
            if lbl then
                local active = false
                if weatherSFX then
                    local node = weatherSFX:FindFirstChild(weather.name)
                    if node then
                        -- Rain is a Sound directly; Lightning is a folder with SFX sounds
                        if node:IsA("Sound") then
                            active = node.Playing or node.Volume > 0
                        else
                            -- For folder types check if any child Sound is playing
                            for _, s in ipairs(node:GetDescendants()) do
                                if s:IsA("Sound") and s.Playing then
                                    active = true
                                    break
                                end
                            end
                        end
                    end
                end
                lbl.Text = active and "ACTIVE" or "Inactive"
                lbl.TextColor3 = active and weather.color or Colors.TextDim
            end
        end
        task.wait(1)
    end
end)

createLabel(worldPage, "")
createLabel(worldPage, "Monitor via SoundService.WeatherSFX.")

-- ============================================================
-- TAB 5: SETTINGS
-- ============================================================
local settingsPage = createTab("Settings", 5)

createLabel(settingsPage, "-- Auto Harvest Delay --")

local delayValues = {0.1, 0.25, 0.5, 1.0, 2.0, 3.0}

local delayDisplay = Instance.new("TextLabel")
delayDisplay.Size = UDim2.new(1, 0, 0, 22)
delayDisplay.BackgroundTransparency = 1
delayDisplay.Text = "Delay: 0.5s"
delayDisplay.TextColor3 = Colors.Text
delayDisplay.TextSize = 13
delayDisplay.Font = Enum.Font.GothamMedium
delayDisplay.TextXAlignment = Enum.TextXAlignment.Left
delayDisplay.Parent = settingsPage

local delayRow = Instance.new("Frame")
delayRow.Size = UDim2.new(1, 0, 0, 33)
delayRow.BackgroundTransparency = 1
delayRow.Parent = settingsPage
do
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 6)
    layout.Parent = delayRow
end

for _, val in ipairs(delayValues) do
    local v = val
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 68, 1, 0)
    btn.BackgroundColor3 = (v == 0.5) and Colors.Accent or Colors.ButtonBg
    btn.Text = v .. "s"
    btn.TextColor3 = Colors.Text
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamMedium
    btn.Parent = delayRow
    do
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = btn
    end
    btn.MouseButton1Click:Connect(function()
        State.AutoHarvestDelay = v
        delayDisplay.Text = "Delay: " .. v .. "s"
        for _, child in ipairs(delayRow:GetChildren()) do
            if child:IsA("TextButton") then
                child.BackgroundColor3 = (child.Text == (v .. "s")) and Colors.Accent or Colors.ButtonBg
            end
        end
    end)
end

createLabel(settingsPage, "")
createLabel(settingsPage, "-- Info --")
createLabel(settingsPage, "GAG Hub v1.0 | Grow a Garden")
createLabel(settingsPage, "Drag header untuk pindah window.")
createLabel(settingsPage, "Klik X untuk tutup.")

-- Fade-in
MainWindow.Size = UDim2.new(0, 480, 0, 0)
TweenService:Create(MainWindow, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 480, 0, 360)}):Play()

print(string.format("\27[32m[GAG Hub] Loaded by %s! Auto-Harvest, Pet Tracker, Weather, Teleport, ESP ready.\27[0m", LocalPlayer.Name))
