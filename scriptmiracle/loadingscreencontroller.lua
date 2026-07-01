-- https://lua.expert/
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local function arrivedViaPetTeleport() --[[ arrivedViaPetTeleport | Line: 18 | Upvalues: TeleportService (copy) ]]
	local ok, result = pcall(function() --[[ Line: 19 | Upvalues: TeleportService (ref) ]]
		return TeleportService:GetLocalPlayerTeleportData()
	end)

	return if ok then if type(result) == "table" then result.Source == "PetTeleporter" else false else ok
end

local ok, result = pcall(function() --[[ Line: 19 | Upvalues: TeleportService (copy) ]]
	return TeleportService:GetLocalPlayerTeleportData()
end)
local v1 = if ok then if type(result) == "table" then result.Source == "PetTeleporter" else false else ok

local function arrivedViaPetHunt() --[[ arrivedViaPetHunt | Line: 31 | Upvalues: TeleportService (copy) ]]
	local ok, result = pcall(function() --[[ Line: 32 | Upvalues: TeleportService (ref) ]]
		return TeleportService:GetLocalPlayerTeleportData()
	end)

	return if ok then if type(result) == "table" then result.Source == "PetHunt" else false else ok
end

local ok2, result2 = pcall(function() --[[ Line: 32 | Upvalues: TeleportService (copy) ]]
	return TeleportService:GetLocalPlayerTeleportData()
end)
local v2 = ok2 and (if type(result2) == "table" then result2.Source == "PetHunt" else false)
local v3 = v1 or v2
local t = {
	"Your garden literally grows while you are <b>offline</b>!",
	"The <i>best</i> seeds have a <i>small</i> chance of restocking!",
	"<font color=\"#FFFF00\">Private Servers</font> are free for everyone!",
	"Playing with friends makes the game even more fun!",
	"<font color=\"#FFFF00\">Gold</font> mutations are worth <b>15x</b> more!",
	"There is a small chance for <font color=\"#FF0000\">r</font><font color=\"#FF7F00\">a</font><font color=\"#FFFF00\">i</font><font color=\"#00FF00\">n</font><font color=\"#0000FF\">b</font><font color=\"#4B0082\">o</font><font color=\"#8B00FF\">w</font> mutations worth <b>40x</b> more!",
	"<b>Bigger</b> fruits sell for <b>more</b> money!",
	"Watering cans make plants grow faster, and maybe make seed packs luckier!",
	"Sprinklers <i>passively</i> water nearby plants for you!",
	"You can <b>steal</b> ripe fruits from other players\' gardens!",
	"Watch out for <font color=\"#FF4444\">gnomes</font> and <font color=\"#FF4444\">traps</font> when stealing!",
	"Some plants give <b>multiple harvests</b> per growth cycle!",
	"Mushrooms grant temporary buffs like <b>speed</b> and <b>invisibility</b>!",
	"You can <b>gift</b> harvested fruits to your friends!",
	"Send your favorite content creators gifts through the mail!",
	"Expand your garden up to <b>5 times</b> for maximum growing space!",
	"Fruits need to be ripe for maximum <b>value</b>!",
	"Visit other players\' gardens to see what they are growing!",
	"There is a very small, and we mean <i>small</i> chance a fruit can grow <b>x100000</b> as big",
	"The rarest seeds cost <i>millions</i> but yield legendary harvests!"
}
local t2 = {
	TextLabel = "TextTransparency",
	ImageLabel = "ImageTransparency",
	UIStroke = "Transparency"
}
local v4 = nil
local v5 = nil
local v6 = nil
local t3 = {}
local t4 = {}
local v7 = nil
local v8 = nil
local v9 = nil
local v10 = false
local v11 = nil
local v12 = false
local v13 = nil
local v14 = false
local v15 = nil
local v16 = false
local t5 = {}
local v17 = nil
local v18 = false
local v19 = 0
local v20 = 0
local v21 = 0

local function shuffleClone(p1) --[[ shuffleClone | Line: 99 ]]
	local v1 = table.clone(p1)

	for i = #v1, 2, -1 do
		local v2 = math.random(1, i)
		local v4 = v1[i]

		v1[i] = v1[v2]
		v1[v2] = v4
	end

	return v1
end

local function fadeUpdateText(p1, p2, p3) --[[ fadeUpdateText | Line: 108 | Upvalues: TweenService (copy), v16 (ref) ]]
	task.spawn(function() --[[ Line: 109 | Upvalues: p3 (copy), TweenService (ref), p1 (copy), v16 (ref), p2 (copy) ]]
		local v12 = TweenInfo.new(p3 / 2, Enum.EasingStyle.Linear)
		local v22 = TweenService:Create(p1, v12, {
			TextTransparency = 1
		})

		v22:Play()
		v22.Completed:Wait()

		if v16 then
			return
		end

		p1.Text = p2
		TweenService:Create(p1, v12, {
			TextTransparency = 0
		}):Play()
	end)
end

local function popRandomTip() --[[ popRandomTip | Line: 122 | Upvalues: t5 (ref), shuffleClone (copy), t (copy) ]]
	if #t5 ~= 0 then
		return table.remove(t5, #t5)
	end

	t5 = shuffleClone(t)

	return table.remove(t5, #t5)
end

local function isMobile() --[[ isMobile | Line: 129 | Upvalues: UserInputService (copy) ]]
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function collectPreloadAssets() --[[ collectPreloadAssets | Line: 133 | Upvalues: PlayerGui (copy), ReplicatedStorage (copy) ]]
	local t = {}

	for k, v in pairs(PlayerGui:GetChildren()) do
		if v:IsA("ScreenGui") then
			for k2, v2 in pairs(v:GetDescendants()) do
				if (v2:IsA("ImageLabel") or v2:IsA("ImageButton")) and (v2.Image and v2.Image ~= "") then
					table.insert(t, v2)
				end
			end
		end
	end

	local Assets = ReplicatedStorage:FindFirstChild("Assets")

	if Assets then
		for k, v in pairs(Assets:GetDescendants()) do
			if v:IsA("ImageLabel") or (v:IsA("ImageButton") or (v:IsA("Decal") or v:IsA("Texture"))) then
				table.insert(t, v)

				continue
			end

			if v:IsA("MeshPart") or v:IsA("Sound") then
				table.insert(t, v)
			end
		end
	end

	local SharedModules = ReplicatedStorage:FindFirstChild("SharedModules")

	if SharedModules then
		local tbl = { "GearImages", "PropImages" }
		local SeedData = SharedModules:FindFirstChild("SeedData")

		if SeedData then
			for k, v in pairs({ "SeedImages", "FruitImages", "PlantImages" }) do
				local v1 = SeedData:FindFirstChild(v)

				if v1 then
					table.insert(tbl, v1)
				end
			end
		end

		for k, v in pairs(tbl) do
			local v2 = if typeof(v) == "string" then SharedModules:FindFirstChild(v) else v

			if v2 then
				for k2, v3 in pairs(v2:GetChildren()) do
					if v3:IsA("StringValue") and v3.Value ~= "" then
						table.insert(t, v3.Value)
					end
				end
			end
		end
	end

	return t
end

local function preloadAssetsAsync() --[[ preloadAssetsAsync | Line: 188 | Upvalues: collectPreloadAssets (copy), v20 (ref), v18 (ref), v19 (ref), ContentProvider (copy), v21 (ref) ]]
	local v1 = collectPreloadAssets()

	v20 = #v1
	v18 = true

	if v20 == 0 then
		v19 = 1
	else
		ContentProvider:PreloadAsync(v1, function(p1, p2) --[[ Line: 198 | Upvalues: v21 (ref), v19 (ref), v20 (ref) ]]
			v21 = v21 + 1
			v19 = math.clamp(v21 / v20, 0, 1)
		end)
		v21 = v20
		v19 = 1
	end
end

local function hideOtherGui(p1) --[[ hideOtherGui | Line: 208 | Upvalues: t3 (ref), t4 (copy) ]]
	if p1.Enabled then
		t3[p1] = p1.Enabled
		p1.Enabled = false
	end

	t4[p1] = p1:GetPropertyChangedSignal("Enabled"):Connect(function() --[[ Line: 213 | Upvalues: p1 (copy), t3 (ref) ]]
		if not p1.Enabled then
			return
		end

		t3[p1] = p1.Enabled
		p1.Enabled = false
	end)
end

local function hideGuis() --[[ hideGuis | Line: 221 | Upvalues: t3 (ref), v7 (ref), PlayerGui (copy), v4 (ref), t4 (copy) ]]
	t3 = {}
	v7 = PlayerGui.ChildAdded:Connect(function(p1) --[[ Line: 223 | Upvalues: v4 (ref), t3 (ref), t4 (ref) ]]
		if not p1:IsA("ScreenGui") or p1 == v4 then
			return
		end

		if p1.Enabled then
			t3[p1] = p1.Enabled
			p1.Enabled = false
		end

		t4[p1] = p1:GetPropertyChangedSignal("Enabled"):Connect(function() --[[ Line: 213 | Upvalues: p1 (copy), t3 (ref) ]]
			if not p1.Enabled then
				return
			end

			t3[p1] = p1.Enabled
			p1.Enabled = false
		end)
	end)

	for k, v in pairs(PlayerGui:GetChildren()) do
		if v:IsA("ScreenGui") and v ~= v4 then
			if v.Enabled then
				t3[v] = v.Enabled
				v.Enabled = false
			end

			t4[v] = v:GetPropertyChangedSignal("Enabled"):Connect(function() --[[ Line: 213 | Upvalues: v (copy), t3 (ref) ]]
				if not v.Enabled then
					return
				end

				t3[v] = v.Enabled
				v.Enabled = false
			end)
		end
	end
end

local function showGuis() --[[ showGuis | Line: 235 | Upvalues: t4 (copy), v7 (ref), t3 (ref) ]]
	for k, v in pairs(t4) do
		v:Disconnect()
	end

	table.clear(t4)

	if v7 then
		v7:Disconnect()
		v7 = nil
	end

	for k, v in pairs(t3) do
		k.Enabled = v
	end

	table.clear(t3)
end

local function getPlayerPlot() --[[ getPlayerPlot | Line: 250 | Upvalues: LocalPlayer (copy) ]]
	local v1 = LocalPlayer:GetAttribute("PlotId")

	if not v1 then
		return nil
	end

	local Gardens = workspace:FindFirstChild("Gardens")

	if Gardens then
		return Gardens:FindFirstChild("Plot" .. v1)
	end

	return nil
end

local function setCam() --[[ setCam | Line: 258 | Upvalues: v13 (ref), LocalPlayer (copy), v14 (ref) ]]
	workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	workspace.CurrentCamera.FieldOfView = 45

	if not v13 then
		local v1 = LocalPlayer:GetAttribute("PlotId")
		local v2

		if v1 then
			local Gardens = workspace:FindFirstChild("Gardens")

			v2 = if Gardens then Gardens:FindFirstChild("Plot" .. v1) else nil
		else
			v2 = nil
		end

		if v2 then
			local LoadingScreenCam = v2:FindFirstChild("LoadingScreenCam")

			if LoadingScreenCam and LoadingScreenCam:IsA("BasePart") then
				v13 = LoadingScreenCam
			end
		end
	end

	if v13 then
		v14 = true
		workspace.CurrentCamera.CFrame = v13.CFrame

		return
	end

	if v14 then
		return
	end

	workspace.CurrentCamera.CFrame = CFrame.new(239.094, 156.83, -134.733) * CFrame.fromOrientation(-0.2794097599517722, -1.8222633654222395, 0)
end

local function startTransparentBGfx() --[[ startTransparentBGfx | Line: 286 | Upvalues: v10 (ref), ReplicatedStorage (copy), v9 (ref), v8 (ref), Lighting (copy), v12 (ref), setCam (copy), RunService (copy) ]]
	game.Lighting:WaitForChild("DepthOfField").Enabled = false
	v10 = true
	task.spawn(function() --[[ Line: 295 | Upvalues: ReplicatedStorage (ref), v9 (ref), v10 (ref), v8 (ref), Lighting (ref) ]]
		local Blur = require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("Blur"))

		v9 = Blur

		if v10 then
			Blur.SetBlur(20)
			v8 = Lighting:FindFirstChild("Blur")
		end
	end)
	v12 = true
	task.spawn(function() --[[ Line: 309 | Upvalues: v12 (ref), setCam (ref), RunService (ref) ]]
		while v12 do
			setCam()
			RunService.RenderStepped:Wait()
		end
	end)
end

local function endTransparentBGfx(p1) --[[ endTransparentBGfx | Line: 317 | Upvalues: v10 (ref), v9 (ref), v8 (ref), v12 (ref), v11 (ref) ]]
	if p1 then
		workspace.CurrentCamera.FieldOfView = 70
	else
		workspace.CurrentCamera.FieldOfView = 45
		task.spawn(function() --[[ Line: 323 ]]
			local v1 = os.clock()

			while os.clock() - v1 < 3 do
				workspace.CurrentCamera.FieldOfView = math.clamp((os.clock() - v1) / 3, 0, 1) * 25 + 45
				task.wait()
			end

			workspace.CurrentCamera.FieldOfView = 70
		end)
	end

	v10 = false

	if v9 and v8 then
		v9.SetBlur(0, if p1 then 0 else 1)
	end

	v8 = nil

	if game.Lighting:FindFirstChild("DepthOfField") then
		game.Lighting.DepthOfField.Enabled = true
	end

	v12 = false

	if not v11 then
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom

		return
	end

	v11:Disconnect()
	v11 = nil
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end

local function revealLogo() --[[ revealLogo | Line: 358 | Upvalues: v6 (ref), TweenService (copy) ]]
	local LogoImg = v6:FindFirstChild("LogoImg")

	if LogoImg then
		TweenService:Create(LogoImg, TweenInfo.new(1, Enum.EasingStyle.Linear), {
			ImageTransparency = 0
		}):Play()
		task.wait(1)
	end
end

local function startRotateTween() --[[ startRotateTween | Line: 368 | Upvalues: v6 (ref), v17 (ref), TweenService (copy) ]]
	local LogoImg = v6:FindFirstChild("LogoImg")

	if not LogoImg then
		return
	end

	v17 = TweenService:Create(LogoImg, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, (1 / 0), true), {
		Rotation = 5
	})
	v17:Play()
end

local function stopRotateTween() --[[ stopRotateTween | Line: 377 | Upvalues: v17 (ref) ]]
	if not v17 then
		return
	end

	v17:Pause()
	v17 = nil
end

local function updateTip(p1) --[[ updateTip | Line: 384 | Upvalues: v6 (ref), t5 (ref), shuffleClone (copy), t (copy), TweenService (copy), v16 (ref) ]]
	local TipLabel = v6:FindFirstChild("TipLabel")

	if not TipLabel then
		return
	end

	if #t5 == 0 then
		t5 = shuffleClone(t)
	end

	local v2 = "[" .. table.remove(t5, #t5) .. "]"

	if p1 then
		local v3 = 0.6

		task.spawn(function() --[[ Line: 109 | Upvalues: v3 (copy), TweenService (ref), TipLabel (copy), v16 (ref), v2 (copy) ]]
			local v12 = TweenInfo.new(v3 / 2, Enum.EasingStyle.Linear)
			local v22 = TweenService:Create(TipLabel, v12, {
				TextTransparency = 1
			})

			v22:Play()
			v22.Completed:Wait()

			if v16 then
				return
			end

			TipLabel.Text = v2
			TweenService:Create(TipLabel, v12, {
				TextTransparency = 0
			}):Play()
		end)
	else
		TipLabel.Text = v2
	end
end

local function startTipCycle() --[[ startTipCycle | Line: 396 | Upvalues: t5 (ref), shuffleClone (copy), t (copy), v6 (ref), v15 (ref), TweenService (copy), v16 (ref) ]]
	t5 = shuffleClone(t)

	local TipLabel = v6:FindFirstChild("TipLabel")

	if not TipLabel then
		v15 = task.spawn(function() --[[ Line: 400 | Upvalues: v6 (ref), t5 (ref), shuffleClone (ref), t (ref), TweenService (ref), v16 (ref) ]]
			while true do
				local v1

				repeat
					task.wait(7)
					v1 = v6:FindFirstChild("TipLabel")
				until v1

				if #t5 == 0 then
					t5 = shuffleClone(t)
				end

				local v3 = "[" .. table.remove(t5, #t5) .. "]"
				local v4 = 0.6

				task.spawn(function() --[[ Line: 109 | Upvalues: v4 (copy), TweenService (ref), v1 (copy), v16 (ref), v3 (copy) ]]
					local v12 = TweenInfo.new(v4 / 2, Enum.EasingStyle.Linear)
					local v22 = TweenService:Create(v1, v12, {
						TextTransparency = 1
					})

					v22:Play()
					v22.Completed:Wait()

					if v16 then
						return
					end

					v1.Text = v3
					TweenService:Create(v1, v12, {
						TextTransparency = 0
					}):Play()
				end)
			end
		end)

		return
	end

	if #t5 == 0 then
		t5 = shuffleClone(t)
	end

	TipLabel.Text = "[" .. table.remove(t5, #t5) .. "]"
	v15 = task.spawn(function() --[[ Line: 400 | Upvalues: v6 (ref), t5 (ref), shuffleClone (ref), t (ref), TweenService (ref), v16 (ref) ]]
		while true do
			local v1

			repeat
				task.wait(7)
				v1 = v6:FindFirstChild("TipLabel")
			until v1

			if #t5 == 0 then
				t5 = shuffleClone(t)
			end

			local v3 = "[" .. table.remove(t5, #t5) .. "]"
			local v4 = 0.6

			task.spawn(function() --[[ Line: 109 | Upvalues: v4 (copy), TweenService (ref), v1 (copy), v16 (ref), v3 (copy) ]]
				local v12 = TweenInfo.new(v4 / 2, Enum.EasingStyle.Linear)
				local v22 = TweenService:Create(v1, v12, {
					TextTransparency = 1
				})

				v22:Play()
				v22.Completed:Wait()

				if v16 then
					return
				end

				v1.Text = v3
				TweenService:Create(v1, v12, {
					TextTransparency = 0
				}):Play()
			end)
		end
	end)
end

local function endTipCycle() --[[ endTipCycle | Line: 408 | Upvalues: v16 (ref), v15 (ref) ]]
	v16 = true

	if not v15 then
		return
	end

	task.cancel(v15)
	v15 = nil
end

local function changeAllTransparency(p1, p2) --[[ changeAllTransparency | Line: 416 | Upvalues: v6 (ref), t2 (copy), TweenService (copy) ]]
	local v1 = TweenInfo.new(p2, Enum.EasingStyle.Linear)

	for k, v in pairs(v6:GetDescendants()) do
		if not v:HasTag("Skip") then
			local v2 = t2[v.ClassName]

			if v2 then
				TweenService:Create(v, v1, {
					[v2] = p1
				}):Play()
			end
		end
	end
end

local function hideFrame() --[[ hideFrame | Line: 430 | Upvalues: changeAllTransparency (copy), TweenService (copy), v5 (ref) ]]
	changeAllTransparency(1, 1)

	local v1 = TweenService:Create(v5, TweenInfo.new(1, Enum.EasingStyle.Linear), {
		BackgroundTransparency = 1
	})

	v1:Play()
	v1.Completed:Wait()
end

local function getLoadingProgress() --[[ getLoadingProgress | Line: 444 | Upvalues: CollectionService (copy), LocalPlayer (copy), v18 (ref), v21 (ref), v20 (ref), v19 (ref) ]]
	if not CollectionService:HasTag(LocalPlayer, "PersistentLoaded") then
		return 0, "Loading player data..."
	end

	if not game:IsLoaded() then
		return 0.05, "Loading game..."
	end

	if not v18 then
		return v19 * 0.2 + 0.05, "Preloading assets... (" .. math.min(v21, v20) .. "/" .. v20 .. ")"
	end

	if not CollectionService:HasTag(LocalPlayer, "ControllersStarted") then
		return 0.25, "Initializing controllers..."
	end

	if not CollectionService:HasTag(LocalPlayer, "DataLoaded") then
		return 0.35, "Loading player save..."
	end

	local v3 = LocalPlayer:GetAttribute("GardenLoadingTotal")
	local v4 = LocalPlayer:GetAttribute("GardenLoadingProgress")

	if v3 and v3 > 0 then
		return math.clamp((v4 or 0) / v3, 0, 1) * 0.55 + 0.45, "Spawning garden... (" .. (v4 or 0) .. "/" .. v3 .. ")"
	end

	return 1, "Ready!"
end

local v22 = nil
local v23 = Instance.new("BindableEvent")
local v24 = 0
local v25 = false
local t6 = { "Polishing fruits...", "Watering gardens...", "Waking up gnomes...", "Planting seeds...", "Counting leaves..." }

local function startCounter() --[[ startCounter | Line: 490 | Upvalues: v6 (ref), TweenService (copy), preloadAssetsAsync (copy), v22 (ref), getLoadingProgress (copy), v24 (ref), v2 (copy), v25 (ref), t6 (copy), v23 (copy) ]]
	local CounterTxt = v6:FindFirstChild("CounterTxt")
	local ProgressBar = v6:FindFirstChild("ProgressBar")

	if CounterTxt then
		TweenService:Create(CounterTxt, TweenInfo.new(0.3, Enum.EasingStyle.Linear), {
			TextTransparency = 0
		}):Play()
	end

	task.spawn(preloadAssetsAsync)
	v22 = task.spawn(function() --[[ Line: 500 | Upvalues: getLoadingProgress (ref), v24 (ref), v2 (ref), v25 (ref), t6 (ref), CounterTxt (copy), ProgressBar (copy), v23 (ref) ]]
		local v1 = nil
		local v22 = 0
		local v3 = 0
		local v4 = 1
		local v5 = "Loading..."

		while true do
			local v6
			local v7, v8 = getLoadingProgress()
			local v9 = os.clock() - v24

			if v2 and v8 ~= v1 then
				warn((("[LoadingScreen][PetHunt] phase=\"%*\" target=%*%%"):format(v8, (math.floor(v7 * 100)))))
				v1 = v8
			end

			if v7 >= 1 and not v25 then
				v25 = true
			end

			if v25 and v9 < 5 then
				v6 = math.min(v7, (math.max(math.clamp(v9 / 5, 0, 0.95), v22)))

				if v3 == 0 or v9 - v3 >= 3 then
					v8 = t6[v4]
					v4 = v4 % #t6 + 1
					v3 = v9
				else
					v8 = t6[(v4 - 2) % #t6 + 1]
				end
			else
				v6 = v7
			end

			local v14 = math.min(v22 + math.clamp((v6 - v22) * 0.06, 0.001, 0.015), v6, 1)

			if v6 - 0.01 <= v14 then
				v5 = v8
			end

			if CounterTxt then
				game.TweenService:Create(ProgressBar.Bar, TweenInfo.new(0.05), {
					Size = UDim2.new(v14, 0, 1, 0)
				}):Play()
				CounterTxt.Text = v5 .. " " .. math.floor(v14 * 100) .. "%"
			end

			v22 = v14

			if v25 and (v9 >= 5 and v14 >= 0.95) then
				if not CounterTxt then
					game.TweenService:Create(ProgressBar.Bar, TweenInfo.new(0.05), {
						Size = UDim2.new(1, 0, 1, 0)
					}):Play()
					v23:Fire()

					return
				end

				CounterTxt.Text = "Ready! 100%"
				game.TweenService:Create(ProgressBar.Bar, TweenInfo.new(0.05), {
					Size = UDim2.new(1, 0, 1, 0)
				}):Play()
				v23:Fire()

				return
			end

			task.wait(0.05)
		end
	end)
end

local function endCounter() --[[ endCounter | Line: 570 | Upvalues: v22 (ref) ]]
	if not v22 then
		return
	end

	task.cancel(v22)
	v22 = nil
end

(function() --[[ startLoading | Line: 577 | Upvalues: v4 (ref), LocalPlayer (copy), v5 (ref), v6 (ref), ProximityPromptService (copy), startTransparentBGfx (copy), hideGuis (copy), v24 (ref), startRotateTween (copy), t5 (ref), shuffleClone (copy), t (copy), v15 (ref), TweenService (copy), v16 (ref), startCounter (copy), UserInputService (copy), RunService (copy), v3 (copy), v23 (copy), v25 (ref), v14 (ref), v2 (copy), v12 (ref), v22 (ref), v17 (ref), v10 (ref), v9 (ref), v8 (ref), v11 (ref), showGuis (copy), hideFrame (copy), endTransparentBGfx (copy) ]]
	local v1 = game.ReplicatedFirst.LoadingScreenMenu:Clone()

	v1.Parent = workspace
	v4 = v1:WaitForChild("LoadingGui", 15)

	local v26 = true

	task.spawn(function() --[[ Line: 585 | Upvalues: v26 (ref), v4 (ref), v1 (copy) ]]
		while v26 do
			game:GetService("RunService").RenderStepped:Wait()

			local v3 = math.tan((math.rad(workspace.CurrentCamera.FieldOfView / 2))) * 32
			local v42 = v3 * (workspace.CurrentCamera.ViewportSize.X / workspace.CurrentCamera.ViewportSize.Y)

			v4.CanvasSize = workspace.CurrentCamera.ViewportSize
			v1.Size = Vector3.new(v42, v3, 0.1)
			v1.CFrame = workspace.CurrentCamera.CFrame * CFrame.new(0, 0, -16)
		end
	end)

	if v4 then
		v5 = v4:FindFirstChild("Variant1Frame")

		if not v5 then
			v4.Enabled = false
		else
			v6 = v5:FindFirstChild("InnerFrame")

			if not v6 then
				v4.Enabled = false
			else
				LocalPlayer:SetAttribute("LoadingScreenActive", true)
				ProximityPromptService.Enabled = false

				local v32 = false

				local function anchorCharacter(p1) --[[ anchorCharacter | Line: 627 | Upvalues: v32 (ref) ]]
					if v32 then
						return
					end

					local v1 = p1:FindFirstChild("HumanoidRootPart") or p1:WaitForChild("HumanoidRootPart", 10)

					if v32 then
						return
					end

					if not (v1 and v1:IsA("BasePart")) then
						return
					end

					v1.Anchored = true
				end

				local Character = LocalPlayer.Character

				if Character then
					Character:FindFirstChild("HumanoidRootPart")
				end

				if Character then
					task.spawn(anchorCharacter, Character)
				end

				local v42 = LocalPlayer.CharacterAdded:Connect(anchorCharacter)

				startTransparentBGfx()
				hideGuis()
				v4.Enabled = true
				v5.Visible = true
				v24 = os.clock()
				startRotateTween()
				t5 = shuffleClone(t)

				local TipLabel = v6:FindFirstChild("TipLabel")

				if TipLabel then
					if #t5 == 0 then
						t5 = shuffleClone(t)
					end

					TipLabel.Text = "[" .. table.remove(t5, #t5) .. "]"
				end

				v15 = task.spawn(function() --[[ Line: 400 | Upvalues: v6 (ref), t5 (ref), shuffleClone (ref), t (ref), TweenService (ref), v16 (ref) ]]
					while true do
						local v1

						repeat
							task.wait(7)
							v1 = v6:FindFirstChild("TipLabel")
						until v1

						if #t5 == 0 then
							t5 = shuffleClone(t)
						end

						local v3 = "[" .. table.remove(t5, #t5) .. "]"
						local v4 = 0.6

						task.spawn(function() --[[ Line: 109 | Upvalues: v4 (copy), TweenService (ref), v1 (copy), v16 (ref), v3 (copy) ]]
							local v12 = TweenInfo.new(v4 / 2, Enum.EasingStyle.Linear)
							local v22 = TweenService:Create(v1, v12, {
								TextTransparency = 1
							})

							v22:Play()
							v22.Completed:Wait()

							if v16 then
								return
							end

							v1.Text = v3
							TweenService:Create(v1, v12, {
								TextTransparency = 0
							}):Play()
						end)
					end
				end)
				startCounter()

				local v62 = false
				local v7 = false
				local v82 = false
				local SkipTxt = v6:FindFirstChild("SkipTxt")
				local v92 = UserInputService.InputBegan:Connect(function() --[[ Line: 662 | Upvalues: v82 (ref), v62 (ref) ]]
					if not v82 then
						return
					end

					v62 = true
				end)

				if RunService:IsStudio() or v3 then
					task.spawn(function() --[[ Line: 673 | Upvalues: v62 (ref), v82 (ref) ]]
						while not v62 do
							if v82 then
								v62 = true

								return
							end

							task.wait()
						end
					end)
				end

				v23.Event:Connect(function() --[[ Line: 684 | Upvalues: v7 (ref), v6 (ref), TweenService (ref), v16 (ref), SkipTxt (copy) ]]
					v7 = true

					local CounterTxt = v6:FindFirstChild("CounterTxt")

					if CounterTxt then
						local v1 = 0.6
						local v2 = "Fully Loaded!"

						task.spawn(function() --[[ Line: 109 | Upvalues: v1 (copy), TweenService (ref), CounterTxt (copy), v16 (ref), v2 (copy) ]]
							local v12 = TweenInfo.new(v1 / 2, Enum.EasingStyle.Linear)
							local v22 = TweenService:Create(CounterTxt, v12, {
								TextTransparency = 1
							})

							v22:Play()
							v22.Completed:Wait()

							if v16 then
								return
							end

							CounterTxt.Text = v2
							TweenService:Create(CounterTxt, v12, {
								TextTransparency = 0
							}):Play()
						end)
					end

					if not SkipTxt then
						return
					end

					local v3 = SkipTxt
					local v4 = 0.6
					local v5 = ""

					task.spawn(function() --[[ Line: 109 | Upvalues: v4 (copy), TweenService (ref), v3 (copy), v16 (ref), v5 (copy) ]]
						local v12 = TweenInfo.new(v4 / 2, Enum.EasingStyle.Linear)
						local v22 = TweenService:Create(v3, v12, {
							TextTransparency = 1
						})

						v22:Play()
						v22.Completed:Wait()

						if v16 then
							return
						end

						v3.Text = v5
						TweenService:Create(v3, v12, {
							TextTransparency = 0
						}):Play()
					end)
				end)

				local function v() --[[ elapsedTime | Line: 695 | Upvalues: v24 (ref) ]]
					return os.clock() - v24
				end

				while not v7 do
					if not v82 and (v25 and (v14 or v2)) and os.clock() - v24 >= 0 then
						v82 = true

						if SkipTxt then
							local v102 = 0.6
							local v112 = "Click to skip!"

							task.spawn(function() --[[ Line: 109 | Upvalues: v102 (copy), TweenService (ref), SkipTxt (copy), v16 (ref), v112 (copy) ]]
								local v12 = TweenInfo.new(v102 / 2, Enum.EasingStyle.Linear)
								local v22 = TweenService:Create(SkipTxt, v12, {
									TextTransparency = 1
								})

								v22:Play()
								v22.Completed:Wait()

								if v16 then
									return
								end

								SkipTxt.Text = v112
								TweenService:Create(SkipTxt, v12, {
									TextTransparency = 0
								}):Play()
							end)
						end
					end

					if v62 then
						break
					end

					task.wait()
				end

				pcall(function() --[[ Line: 716 ]]
					game.SoundService.SFX.Click:Play()
				end)

				if v7 then
					local v142 = "<font color=\'#FFFF00\'>[" .. (if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "Tap anywhere to play!" else "Press any key to play!") .. "]</font>"
					local PressAnyTxt = v6:FindFirstChild("PressAnyTxt")

					if PressAnyTxt then
						local v152 = 0.6

						task.spawn(function() --[[ Line: 109 | Upvalues: v152 (copy), TweenService (ref), PressAnyTxt (copy), v16 (ref), v142 (copy) ]]
							local v12 = TweenInfo.new(v152 / 2, Enum.EasingStyle.Linear)
							local v22 = TweenService:Create(PressAnyTxt, v12, {
								TextTransparency = 1
							})

							v22:Play()
							v22.Completed:Wait()

							if v16 then
								return
							end

							PressAnyTxt.Text = v142
							TweenService:Create(PressAnyTxt, v12, {
								TextTransparency = 0
							}):Play()
						end)
					end

					v82 = true

					while not v62 do
						task.wait()
					end
				end

				if RunService:IsStudio() or v3 then
					v26 = false
					v12 = false

					if v22 then
						task.cancel(v22)
						v22 = nil
					end

					v16 = true

					if v15 then
						task.cancel(v15)
						v15 = nil
					end

					if v17 then
						v17:Pause()
						v17 = nil
					end

					v92:Disconnect()
					workspace.CurrentCamera.FieldOfView = 70
					v10 = false

					if v9 and v8 then
						v9.SetBlur(0, 0)
					end

					v8 = nil

					if game.Lighting:FindFirstChild("DepthOfField") then
						game.Lighting.DepthOfField.Enabled = true
					end

					v12 = false

					if v11 then
						v11:Disconnect()
						v11 = nil
					end

					workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
					showGuis()
					LocalPlayer:SetAttribute("LoadingScreenActive", false)
					v32 = true

					if v42 then
						v42:Disconnect()
					end

					local Character2 = LocalPlayer.Character
					local v162 = Character2 and Character2:FindFirstChild("HumanoidRootPart")

					if v162 and v162:IsA("BasePart") then
						if not v2 then
							local v172 = LocalPlayer:GetAttribute("PlotId")
							local v18

							if v172 then
								local Gardens = workspace:FindFirstChild("Gardens")

								v18 = if Gardens then Gardens:FindFirstChild("Plot" .. v172) else nil
							else
								v18 = nil
							end

							local v19 = v18 and v18:FindFirstChild("SpawnPoint")

							if v19 then
								Character2:PivotTo(v19.CFrame)
							end
						end

						v162.Anchored = false
					end
				else
					v26 = false
					v12 = false

					local v20 = false

					task.spawn(function() --[[ Line: 783 | Upvalues: v10 (ref), v8 (ref), v9 (ref), LocalPlayer (ref), v20 (ref) ]]
						local sum = 0
						local v1 = workspace.CurrentCamera.CFrame
						local v2 = v1 * CFrame.new(0, -5, -35)
						local v3 = false

						v10 = false
						v8 = nil

						if v9 then
							v9.SetBlur(0, 1.8)
						end

						while sum < 2.2 do
							local v4

							sum = sum + game:GetService("RunService").Heartbeat:Wait()

							if sum > 1.8 and not v3 then
								game.SoundService.SFX.Whoosh:Play()
								v3 = true
							end

							local function lerp(p1, p2, p3) --[[ lerp | Line: 812 ]]
								return p1 + (p2 - p1) * p3
							end

							if sum < 1.8 then
								local v5 = sum / 1.8

								workspace.CurrentCamera.FieldOfView = 45 + 5 * game.TweenService:GetValue(v5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
								v4 = v5 ^ 4 * 0.08
							elseif sum < 2.2 then
								local v6 = (sum - 1.8) / 0.4

								workspace.CurrentCamera.FieldOfView = 55 + -15 * game.TweenService:GetValue(v6, Enum.EasingStyle.Back, Enum.EasingDirection.InOut)
								v4 = v6 * v6 * (3 - v6 * 2) * 0.92 + 0.08
							else
								v4 = 1
							end

							workspace.CurrentCamera.CFrame = v1:Lerp(v2, v4)
						end

						local v7 = CFrame.new(0, 4.70700073, 12.081604, 1, 1.47265382e-8, -5.58793545e-8, -6.82366663e-12, 0.966528356, 0.256560236, 5.77419996e-8, -0.256560266, 0.966528296)
						local Character = LocalPlayer.Character
						local v82 = if Character then Character:FindFirstChild("HumanoidRootPart") else Character

						if not (v82 and v82:IsA("BasePart")) then
							v20 = true

							return
						end

						local v92 = game.TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							CFrame = v82.CFrame * v7
						})

						v92:Play()
						v92.Completed:Wait()
						v20 = true
					end)

					if v22 then
						task.cancel(v22)
						v22 = nil
					end

					v16 = true

					if v15 then
						task.cancel(v15)
						v15 = nil
					end

					v92:Disconnect()
					hideFrame()
					task.wait(1)
					task.wait(0.6)
					endTransparentBGfx()

					if v17 then
						v17:Pause()
						v17 = nil
					end

					showGuis()
					LocalPlayer:SetAttribute("LoadingScreenActive", false)

					local v21 = os.clock()

					while not v20 and os.clock() - v21 < 2 do
						task.wait()
					end

					v32 = true

					if v42 then
						v42:Disconnect()
					end

					local Character2 = LocalPlayer.Character
					local v222 = Character2 and Character2:FindFirstChild("HumanoidRootPart")

					if v222 then
						local v232 = LocalPlayer:GetAttribute("PlotId")
						local v242

						if v232 then
							local Gardens = workspace:FindFirstChild("Gardens")

							v242 = if Gardens then Gardens:FindFirstChild("Plot" .. v232) else nil
						else
							v242 = nil
						end

						local v252 = if v242 then v242:FindFirstChild("SpawnPoint") else v242

						if v252 then
							Character2:PivotTo(v252.CFrame)
						end

						v222.Anchored = false
					end
				end

				ProximityPromptService.Enabled = true
				v4.Enabled = false
				v1:Destroy()
			end
		end
	end

	LocalPlayer:SetAttribute("LoadingScreenDone", true)
end)()
