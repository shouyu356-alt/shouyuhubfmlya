-- ShouyuHub | Steal an Egg (Light Blue) - Fixed & Scaled
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local CoreGui           = game:GetService("CoreGui")
local localPlayer       = Players.LocalPlayer

local CFG = {
	SpeedToEgg   = 6500,
	SpeedHome    = 300,
	GrabInterval = 0.03,
	RegrabFar    = 40,
	Height       = 70,
	ClimbShare   = 0.5,
	AutoRefresh  = 4,
}

local THEME = {
	Bg         = Color3.fromRGB(15, 20, 30),
	Panel      = Color3.fromRGB(25, 35, 50),
	Card       = Color3.fromRGB(35, 50, 70),
	Accent     = Color3.fromRGB(120, 220, 255),
	AccentSoft = Color3.fromRGB(200, 240, 255),
	AccentDeep = Color3.fromRGB(40, 100, 140),
	Text       = Color3.fromRGB(240, 245, 255),
	TextDim    = Color3.fromRGB(160, 190, 210),
	Stroke     = Color3.fromRGB(60, 100, 130),
}

local function safeRequire(getter)
	local ok, result = pcall(function() return require(getter()) end)
	return ok and result or nil
end

local networkingFolder = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networking")
local EggState  = safeRequire(function() return ReplicatedStorage.Client.EggState end)
local Assets    = safeRequire(function() return ReplicatedStorage.Data.Assets end)
local Mutations = safeRequire(function() return ReplicatedStorage.Shared.Modules.Mutations end)

local function remote(name) return networkingFolder:FindFirstChild(name) end
local function root()
	local character = localPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- シールド
local shield = { Original = nil, Clone = nil, Links = {}, Connection = nil, Added = nil }

local function walkSpeed()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local speed = humanoid and humanoid.WalkSpeed or 16
	if shield.Original and shield.Original.Health > 0 then
		speed = math.min(speed, shield.Original.WalkSpeed)
	end
	return speed
end

local function shieldControls(humanoid)
	pcall(function()
		local scripts = localPlayer:FindFirstChild("PlayerScripts")
		local module = scripts and scripts:FindFirstChild("PlayerModule")
		if module then
			local controls = require(module):GetControls()
			if type(controls) == "table" then controls.humanoid = humanoid end
		end
	end)
end

local function shieldAnimate(character)
	local animate = character and character:FindFirstChild("Animate")
	if animate and animate:IsA("LocalScript") then
		task.spawn(function()
			animate.Enabled = false
			task.wait()
			animate.Enabled = true
		end)
	end
end

local function shieldUnlink()
	for _, link in ipairs(shield.Links) do
		pcall(function() link:Disconnect() end)
	end
	table.clear(shield.Links)
end

local groundedStates = {
	[Enum.HumanoidStateType.Running] = true,
	[Enum.HumanoidStateType.RunningNoPhysics] = true,
	[Enum.HumanoidStateType.Landed] = true,
}

local function grounded(humanoid)
	if not humanoid or humanoid.Health <= 0 or humanoid.FloorMaterial == Enum.Material.Air then
		return false
	end
	return groundedStates[humanoid:GetState()] == true
end

local function shieldSwap()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	if shield.Clone and shield.Clone.Parent == character then return end
	if not grounded(humanoid) then return end

	local clone = humanoid:Clone()
	humanoid.Parent = nil
	clone.Parent = character
	workspace.CurrentCamera.CameraSubject = clone
	shieldControls(clone)
	shieldAnimate(character)
	shield.Original, shield.Clone = humanoid, clone

	table.insert(shield.Links, humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if clone.Parent ~= nil then clone.WalkSpeed = humanoid.WalkSpeed end
	end))

	local animator  = humanoid:FindFirstChildOfClass("Animator")
	local animator2 = clone:FindFirstChildOfClass("Animator")
	if animator and animator2 then
		table.insert(shield.Links, animator.AnimationPlayed:Connect(function(played)
			local animation = played.Animation
			if not animation or clone.Parent == nil then return end
			local ok, track = pcall(function() return animator2:LoadAnimation(animation) end)
			if not ok or not track then return end
			pcall(function()
				track.Priority = played.Priority
				track.Looped = played.Looped
				track:Play(0.05, math.max(played.WeightTarget, 0.01), played.Speed)
			end)
			local stopped
			stopped = played.Stopped:Connect(function()
				stopped:Disconnect()
				pcall(function() track:Stop(0.1) end)
			end)
		end))
	end

	table.insert(shield.Links, clone.Died:Connect(function()
		shieldUnlink()
		shield.Original, shield.Clone = nil, nil
		local current = localPlayer.Character
		if current and humanoid.Parent == nil then
			humanoid.Parent = current
			workspace.CurrentCamera.CameraSubject = humanoid
			shieldControls(humanoid)
		end
		pcall(function() clone:Destroy() end)
		humanoid.Health = 0
	end))
end

local function shieldUndo()
	shieldUnlink()
	local character = localPlayer.Character
	local original, clone = shield.Original, shield.Clone
	shield.Original, shield.Clone = nil, nil
	if original and clone and character and original.Parent == nil and clone.Parent == character then
		original.Parent = character
		workspace.CurrentCamera.CameraSubject = original
		shieldControls(original)
		pcall(function() clone:Destroy() end)
		shieldAnimate(character)
	end
end

local function shieldStart()
	shieldSwap()
	local n = 0
	shield.Connection = RunService.Heartbeat:Connect(function(dt)
		n += dt
		local character = localPlayer.Character
		local missing = not (shield.Clone and character and shield.Clone.Parent == character)
		if (missing and 0.25 or 3) <= n then
			n = 0
			shieldSwap()
		end
	end)
	shield.Added = localPlayer.CharacterAdded:Connect(function(character)
		shieldUnlink()
		shield.Original, shield.Clone = nil, nil
		task.spawn(function()
			character:WaitForChild("Humanoid", 10)
			task.wait(1)
			if shield.Connection and localPlayer.Character == character then
				shieldSwap()
			end
		end)
	end)
end

local function shieldStop()
	if shield.Connection then shield.Connection:Disconnect(); shield.Connection = nil end
	if shield.Added then shield.Added:Disconnect(); shield.Added = nil end
	shieldUndo()
end-- ステート
local state = { Carrying = false, Uid = nil, Delivered = 0, Busy = false, Cancel = false, Mult = 1, HeldSeen = 0, GuessedDrop = false }

if type(EggState) == "table" and type(EggState.CarryChanged) == "table" and type(EggState.CarryChanged.Connect) == "function" then
	EggState.CarryChanged:Connect(function(arg)
		local carrying = type(arg) == "table" and arg.IsCarrying == true
		if carrying and arg.GuardDisabled == true then carrying = false end
		state.GuessedDrop = false
		if carrying then state.HeldSeen = os.clock() end
		if carrying and type(arg.Uid) == "string" then
			state.Uid = arg.Uid
			local mult = tonumber(arg.SpeedMultiplier)
			if mult and mult > 0 then state.Mult = mult end
		end
		state.Carrying = carrying
	end)
end

pcall(function()
	remote("RE/EggWorld/FieldEggRedeemVerdict").OnClientEvent:Connect(function()
		state.Delivered = os.clock()
	end)
end)

local function takeEgg(uid)
	if type(uid) == "string" and type(EggState) == "table" and type(EggState.CarryFieldEgg) == "function" then
		pcall(EggState.CarryFieldEgg, uid)
	end
end

local function dropEgg()
	if type(EggState) == "table" and type(EggState.DropFieldEgg) == "function" then
		pcall(EggState.DropFieldEgg, "PlayerRequest")
	end
end

local function promptNear(position, radius)
	local best, bestDistance = nil, radius
	for _, child in ipairs(workspace:GetChildren()) do
		if child.Name == "SmartPromptPart" and child:IsA("BasePart") then
			local prompt = child:FindFirstChild("CarryAreaEgg")
			if prompt and prompt:IsA("ProximityPrompt") then
				local distance = (child.Position - position).Magnitude
				if distance < bestDistance then best, bestDistance = prompt, distance end
			end
		end
	end
	return best
end

local function heldByMe(uid)
	local character = localPlayer.Character
	if type(uid) ~= "string" or not character then return false end
	local egg = workspace:FindFirstChild(uid)
	if not egg then return false end
	for _, d in ipairs(egg:GetDescendants()) do
		if d:IsA("WeldConstraint") or d:IsA("JointInstance") then
			local ok, a, b = pcall(function() return d.Part0, d.Part1 end)
			if ok and ((a and a:IsDescendantOf(character)) or (b and b:IsDescendantOf(character))) then
				return true
			end
		end
	end
	return false
end

task.spawn(function()
	while true do
		task.wait(0.2)
		if not state.Carrying then
			if state.GuessedDrop and heldByMe(state.Uid) then
				state.GuessedDrop, state.Carrying, state.HeldSeen = false, true, os.clock()
			end
		elseif heldByMe(state.Uid) then
			state.HeldSeen = os.clock()
		elseif os.clock() - state.HeldSeen > 0.8 then
			state.Carrying, state.GuessedDrop = false, true
		end
	end
end)

local function snapshot()
	local list = {}
	local ok, result = pcall(function()
		return remote("RF/EggWorld/AskFieldEggSnapshot"):InvokeServer()
	end)
	local records = ok and type(result) == "table" and result.Records or nil
	if type(records) ~= "table" then return list end
	for _, record in pairs(records) do
		if type(record) == "table" and type(record.Uid) == "string"
			and (record.State == "Slot" or record.State == "Dropped")
			and typeof(record.BottomCFrame) == "CFrame" then
			list[#list + 1] = record
		end
	end
	return list
end

local function eggPosition(uid)
	for _, record in ipairs(snapshot()) do
		if record.Uid == uid then return record.BottomCFrame.Position end
	end
	return nil
end

local function describe(record)
	local directory = type(Assets) == "table" and Assets.Directory or nil
	local entry = type(directory) == "table" and directory[tostring(record.AssetCategory)] or nil
	local info = { Uid = record.Uid, Category = tostring(record.AssetCategory), Name = tostring(record.AssetCategory), Icon = "", Rarity = 0, Value = 0 }
	if type(entry) == "table" then
		info.Name = tostring(entry.DisplayName or record.AssetCategory)
		local icon = entry.Icon
		if icon ~= nil and tostring(icon) ~= "" then
			icon = tostring(icon)
			info.Icon = tonumber(icon) and ("rbxassetid://" .. icon) or icon
		end
		if type(entry.Rarity) == "table" then
			info.Rarity = tonumber(entry.Rarity.RarityNumber or entry.Rarity.Rank) or 0
		end
		local scale = tonumber(record.AssetScale) or 1
		local factor = scale > 5 and (scale / 5) ^ 1.2 * 19.637875755794113 or scale ^ 1.85
		local mutation = 1
		if type(Mutations) == "table" and type(Mutations.EarningsFor) == "function" then
			local okM, resM = pcall(Mutations.EarningsFor, type(record.Mutations) == "table" and record.Mutations or {})
			if okM and type(resM) == "number" then mutation = resM end
		end
		info.Value = (tonumber(entry.EarningRate) or 0) * factor * mutation
	end
	return info
end

local function money(value)
	local units = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
	for _, u in ipairs(units) do
		if value >= u[1] then return string.format("$%.2f%s/s", value / u[1], u[2]) end
	end
	return string.format("$%d/s", math.floor(value + 0.5))
end

local function lineInfo()
	local world = workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
	world = world and world:FindFirstChild("Areas")
	world = world and world:FindFirstChild("SeparationLine")
	local ok = world and world:IsA("BasePart")
	return ok and world.Position.X or 552.2, ok and world.Position.Y or 67.67
end

local function homePoint()
	for _, def in ipairs({
		{ { "GearGiver_Slap", "Podium" }, Vector3.new(-16.415, 21.072, -6.106) },
		{ { "World", "Machines", "RiftMachine", "Rift", "Meshes/VoidPortal_Cube.003" }, Vector3.new(-26.776, 1.75, 18.665) },
		{ { "__OBJECTS", "Machines", "RiftMachine", "Rift", "Meshes/VoidPortal_Cube.003" }, Vector3.new(-26.776, 1.75, 18.665) },
	}) do
		local node = workspace
		for _, name in ipairs(def[1]) do node = node and node:FindFirstChild(name) or nil end
		if node and node:IsA("BasePart") then return node.CFrame:PointToWorldSpace(def[2]) end
	end
	return Vector3.new(528.7, 70.57, -364.11)
	end-- 走りロジック
local status = function(text) end

local function runToEgg(uid, egg)
	local lineX = lineInfo()
	local home = homePoint()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
		if character:FindFirstChildWhichIsA("Tool") then pcall(function() humanoid:UnequipTools() end) end
	end

	local r = root()
	if not r then return false end
	local stage = "field"
	if r.Position.X < lineX - 2 and Vector3.new(r.Position.X - home.X, 0, r.Position.Z - home.Z).Magnitude > 20 then
		stage = "safe"
	end

	local started, lastCheck, lastPos, lastTake = os.clock(), os.clock(), r.Position, 0
	while os.clock() - started < 120 and not state.Cancel do
		r = root()
		if not r then return false end
		local flatEgg = Vector3.new(egg.X - r.Position.X, 0, egg.Z - r.Position.Z)
		if stage == "field" and flatEgg.Magnitude <= 2.5 then break end
		local target = egg
		if stage == "safe" then
			if Vector3.new(home.X - r.Position.X, 0, home.Z - r.Position.Z).Magnitude <= 6 then
				stage = "field"
			else
				target = home
			end
		end

		local flat = Vector3.new(target.X - r.Position.X, 0, target.Z - r.Position.Z)
		local unit = flat.Magnitude > 0.01 and flat.Unit or Vector3.zero
		
		-- ★ 速度6500のCFrameワープ
		local dt = math.max(RunService.Heartbeat:Wait(), 1/60)
		local step = math.min(CFG.SpeedToEgg * dt, flat.Magnitude)
		pcall(function()
			if step > 0 then
				local newPos = r.Position + unit * step
				r.CFrame = CFrame.lookAt(newPos, newPos + unit)
				r.AssemblyLinearVelocity = Vector3.zero
			end
		end)

		if os.clock() - lastCheck >= 1.5 then
			lastPos, lastCheck = r.Position, os.clock()
		end

		if stage == "field" and flatEgg.Magnitude <= 9 and os.clock() - lastTake > 0.1 then
			lastTake = os.clock()
			takeEgg(uid)
		end
	end

	r = root()
	if r then
		pcall(function()
			r.AssemblyLinearVelocity = Vector3.zero
			if humanoid then humanoid:Move(Vector3.zero, false) end
		end)
	end
	return state.Carrying or (r ~= nil and Vector3.new(egg.X - r.Position.X, 0, egg.Z - r.Position.Z).Magnitude <= 6)
end

local function grab(uid, timeout)
	local cache = { At = 0 }
	local waited, since = 0, 1
	while not state.Carrying and waited < timeout and not state.Cancel do
		local r = root()
		local egg = eggPosition(uid)
		if r and egg then
			local flat = Vector3.new(egg.X - r.Position.X, 0, egg.Z - r.Position.Z)
			if flat.Magnitude > 2 then
				local v = flat.Unit * math.min(walkSpeed() * 1.15, flat.Magnitude / 0.05)
				pcall(function()
					r.AssemblyLinearVelocity = Vector3.new(v.X, r.AssemblyLinearVelocity.Y, v.Z)
				end)
			end
		end

		if since >= CFG.GrabInterval then
			since = 0
			local r2 = root()
			if r2 and egg then
				local prompt = promptNear(egg - Vector3.new(0, 3, 0), 10)
				if prompt and typeof(fireproximityprompt) == "function" then
					pcall(function() prompt.HoldDuration = 0 end)
					pcall(fireproximityprompt, prompt)
				end
			end
			task.spawn(takeEgg, uid)
		end
		
		local dt = math.max(RunService.Heartbeat:Wait(), 1/240)
		waited += dt
		since += dt
	end
	return state.Carrying and state.Uid == uid
		end-- 帰る（Instant TPなし / 空中移動 速度300）
local function runHome(lineX, laneZ)
	local started = os.clock()
	local home = homePoint()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.PlatformStand = true end

	local r = root()
	if not r then return false end

	local flyY = home.Y + CFG.Height
	local timeout = 0
	status("Flying home")
	
	while state.Carrying and state.Delivered < started and not state.Cancel and timeout < 30 do
		r = root()
		if not r then return false end
		local dt = math.max(RunService.Heartbeat:Wait(), 1 / 60)
		timeout += dt

		local target = Vector3.new(home.X, flyY, home.Z)
		local flat = Vector3.new(target.X - r.Position.X, 0, target.Z - r.Position.Z)
		local unit = flat.Magnitude > 0.01 and flat.Unit or Vector3.zero
		
		local v = unit * math.min(CFG.SpeedHome, flat.Magnitude / 0.05)
		
		pcall(function()
			r.AssemblyLinearVelocity = Vector3.new(v.X, (flyY - r.Position.Y) * 3, v.Z)
		end)
		
		if flat.Magnitude < 15 then break end
	end

	if humanoid then humanoid.PlatformStand = false end
	task.wait(0.5)

	local settle = 0
	while settle < 2 and state.Delivered < started and state.Carrying and not state.Cancel do
		settle += RunService.Heartbeat:Wait()
	end
	if state.Carrying and state.Delivered < started and not state.Cancel then
		dropEgg()
		local waited = 0
		while state.Delivered < started and waited < 1 do
			waited += RunService.Heartbeat:Wait()
		end
	end
	return state.Delivered >= started
end

-- 盗んで納品
local function stealAndDeliver(uid)
	if state.Busy then return end
	state.Busy = true
	state.Cancel = false
	task.spawn(function()
		local ok, err = pcall(function()
			status("Looking for the egg")
			local egg = eggPosition(uid)
			if not egg then
				status("That egg is gone")
				return
			end
			if state.Carrying and state.Uid ~= uid then
				dropEgg()
				local waited = 0
				while state.Carrying and waited < 1 do
					waited += RunService.Heartbeat:Wait()
				end
			end
			
			status("Going to the egg")
			if not runToEgg(uid, egg) then
				status("Could not reach the egg")
				return
			end
			
			status("Taking the egg")
			if not grab(uid, 4) then
				status("The egg would not come free")
				return
			end
			
			local lineX, _ = lineInfo()
			local current = root()
			local laneZ = current and math.clamp(current.Position.Z, -425, -300) or -360
			
			local delivered = runHome(lineX, laneZ)
			status(delivered and "Delivered" or "Delivery failed")
		end)
		
		if not ok then
			status("Error: " .. tostring(err))
		end
		state.Busy = false
	end)
			end-- UI構築
print("[ShouyuHub] UI構築開始")

-- ★ サイズを0.45に変更
local UI = { W = 340, H = 500, Scale = 0.45, Minimized = false }
local UI_W, UI_H, UI_H_MIN = UI.W, UI.H, 68

local function getParent()
	local pg = localPlayer:FindFirstChildOfClass("PlayerGui")
	return pg or localPlayer:WaitForChild("PlayerGui")
end

local gui = Instance.new("ScreenGui")
gui.Name = "ShouyuHub_LightBlue"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = true
gui.Parent = getParent()

local main = Instance.new("Frame", gui)
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Size = UDim2.fromOffset(UI_W, UI_H)
main.Position = UDim2.new(0.5, 0, 0.5, 0)
main.BackgroundColor3 = THEME.Bg
main.BorderSizePixel = 0
main.Active = true
main.ClipsDescendants = true

local us = Instance.new("UIScale", main)
us.Scale = UI.Scale

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)
local stroke = Instance.new("UIStroke", main)
stroke.Color = THEME.Accent
stroke.Thickness = 1.5
stroke.Transparency = 0.25

-- 背景
local bg = Instance.new("Frame", main)
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = THEME.AccentDeep
bg.BackgroundTransparency = 0.7
bg.BorderSizePixel = 0
bg.ZIndex = 1
Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 14)
local bgG = Instance.new("UIGradient", bg)
bgG.Rotation = 90
bgG.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, THEME.AccentDeep),
	ColorSequenceKeypoint.new(0.5, THEME.Bg),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 10, 15)),
})

-- ヘッダー
local header = Instance.new("Frame", main)
header.Size = UDim2.new(1, -16, 0, 56)
header.Position = UDim2.fromOffset(8, 8)
header.BackgroundColor3 = THEME.Panel
header.BackgroundTransparency = 0.05
header.BorderSizePixel = 0
header.ZIndex = 5
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

local hS = Instance.new("UIStroke", header)
hS.Color = THEME.Accent
hS.Thickness = 1.2
hS.Transparency = 0.35

-- アバター
local avatarFrame = Instance.new("Frame", header)
avatarFrame.Size = UDim2.fromOffset(40, 40)
avatarFrame.Position = UDim2.fromOffset(8, 8)
avatarFrame.BackgroundColor3 = THEME.AccentDeep
avatarFrame.BorderSizePixel = 0
avatarFrame.ZIndex = 6
Instance.new("UICorner", avatarFrame).CornerRadius = UDim.new(1, 0)

local avatarStroke = Instance.new("UIStroke", avatarFrame)
avatarStroke.Color = THEME.Accent
avatarStroke.Thickness = 1.5
avatarStroke.Transparency = 0.3

local avatarImg = Instance.new("ImageLabel", avatarFrame)
avatarImg.Size = UDim2.fromScale(0.88, 0.88)
avatarImg.Position = UDim2.fromScale(0.06, 0.06)
avatarImg.BackgroundTransparency = 1
avatarImg.Image = "rbxthumb://type=AvatarHeadShot&id=" .. localPlayer.UserId .. "&w=150&h=150"
avatarImg.ZIndex = 7
Instance.new("UICorner", avatarImg).CornerRadius = UDim.new(1, 0)

local title = Instance.new("TextLabel", header)
title.Size = UDim2.new(1, -150, 0, 22)
title.Position = UDim2.fromOffset(58, 8)
title.BackgroundTransparency = 1
title.Text = "SHOUYU HUB"
title.TextColor3 = THEME.AccentSoft
title.Font = Enum.Font.GothamBlack
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 6

local sub = Instance.new("TextLabel", header)
sub.Size = UDim2.new(1, -150, 0, 14)
sub.Position = UDim2.fromOffset(58, 30)
sub.BackgroundTransparency = 1
sub.Text = "GO: 6500 / RETURN: 300"
sub.TextColor3 = THEME.TextDim
sub.Font = Enum.Font.GothamBold
sub.TextSize = 10
sub.TextXAlignment = Enum.TextXAlignment.Left
sub.ZIndex = 6

local minBtn = Instance.new("TextButton", header)
minBtn.Size = UDim2.fromOffset(32, 32)
minBtn.Position = UDim2.new(1, -78, 0.5, -16)
minBtn.BackgroundColor3 = THEME.AccentDeep
minBtn.BorderSizePixel = 0
minBtn.Text = "−"
minBtn.TextColor3 = THEME.AccentSoft
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 20
minBtn.AutoButtonColor = true
minBtn.ZIndex = 6
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 8)

local closeBtn = Instance.new("TextButton", header)
closeBtn.Size = UDim2.fromOffset(32, 32)
closeBtn.Position = UDim2.new(1, -42, 0.5, -16)
closeBtn.BackgroundColor3 = THEME.AccentDeep
closeBtn.BorderSizePixel = 0
closeBtn.Text = "×"
closeBtn.TextColor3 = THEME.AccentSoft
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 20
closeBtn.AutoButtonColor = true
closeBtn.ZIndex = 6
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

-- ボディ
local body = Instance.new("Frame", main)
body.Size = UDim2.new(1, -16, 1, -72)
body.Position = UDim2.fromOffset(8, 72)
body.BackgroundTransparency = 1
body.ZIndex = 5

local statusLbl = Instance.new("TextLabel", body)
statusLbl.Size = UDim2.new(1, -110, 0, 22)
statusLbl.Position = UDim2.fromOffset(6, 0)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "待機中"
statusLbl.TextColor3 = THEME.TextDim
statusLbl.Font = Enum.Font.GothamMedium
statusLbl.TextSize = 12
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.ZIndex = 6

local list = Instance.new("ScrollingFrame", body)
list.Size = UDim2.new(1, -4, 1, -150)
list.Position = UDim2.fromOffset(2, 26)
list.BackgroundColor3 = THEME.Panel
list.BackgroundTransparency = 0.15
list.BorderSizePixel = 0
list.ScrollBarThickness = 5
list.ScrollBarImageColor3 = THEME.Accent
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ZIndex = 5
Instance.new("UICorner", list).CornerRadius = UDim.new(0, 10)

local lLayout = Instance.new("UIListLayout", list)
lLayout.Padding = UDim.new(0, 5)
lLayout.SortOrder = Enum.SortOrder.LayoutOrder

local lPad = Instance.new("UIPadding", list)
lPad.PaddingTop = UDim.new(0, 6)
lPad.PaddingBottom = UDim.new(0, 6)
lPad.PaddingLeft = UDim.new(0, 6)
lPad.PaddingRight = UDim.new(0, 8)

local RARITY_COLORS = {
	Color3.fromRGB(190, 190, 190), Color3.fromRGB(110, 210, 110),
	Color3.fromRGB(90, 160, 255), Color3.fromRGB(190, 110, 255),
	Color3.fromRGB(255, 170, 50), Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(255, 90, 200), Color3.fromRGB(80, 235, 235),
}

local selectedUid = nil
local rows = {}

local function setSelected(uid)
	selectedUid = uid
	for rowUid, row in pairs(rows) do
		local on = rowUid == uid
		row.Stroke.Thickness = on and 2.5 or 1
		row.Stroke.Color = on and THEME.Accent or THEME.Stroke
		row.Stroke.Transparency = on and 0 or 0.6
		row.Frame.BackgroundColor3 = on and THEME.AccentDeep or THEME.Card
	end
end

local function rebuild()
	for _, row in pairs(rows) do
		pcall(function() row.Frame:Destroy() end)
	end
	table.clear(rows)

	local infos = {}
	local ok, records = pcall(snapshot)
	if ok and type(records) == "table" then
		for _, record in ipairs(records) do
			local okD, info = pcall(describe, record)
			if okD and info then infos[#infos + 1] = info end
		end
	end
	table.sort(infos, function(a, b) return (a.Value or 0) > (b.Value or 0) end)

	local still = false
	for index, info in ipairs(infos) do
		still = still or info.Uid == selectedUid

		local frame = Instance.new("TextButton", list)
		frame.Size = UDim2.new(1, 0, 0, 48)
		frame.BackgroundColor3 = THEME.Card
		frame.BorderSizePixel = 0
		frame.Text = ""
		frame.LayoutOrder = index
		frame.AutoButtonColor = true
		Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

		local fS = Instance.new("UIStroke", frame)
		fS.Color = THEME.Stroke
		fS.Thickness = 1
		fS.Transparency = 0.6

		local icon = Instance.new("ImageLabel", frame)
		icon.Size = UDim2.fromOffset(38, 38)
		icon.Position = UDim2.fromOffset(5, 5)
		icon.BackgroundTransparency = 1
		icon.Image = info.Icon or ""
		icon.ScaleType = Enum.ScaleType.Fit

		local name = Instance.new("TextLabel", frame)
		name.Size = UDim2.new(1, -52, 0, 22)
		name.Position = UDim2.fromOffset(50, 4)
		name.BackgroundTransparency = 1
		name.Text = info.Name or "?"
		name.TextColor3 = RARITY_COLORS[math.clamp(info.Rarity or 1, 1, #RARITY_COLORS)] or THEME.Text
		name.Font = Enum.Font.GothamBold
		name.TextSize = 15
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd

		local value = Instance.new("TextLabel", frame)
		value.Size = UDim2.new(1, -52, 0, 16)
		value.Position = UDim2.fromOffset(50, 26)
		value.BackgroundTransparency = 1
		value.Text = money(info.Value or 0)
		value.TextColor3 = THEME.AccentSoft
		value.Font = Enum.Font.GothamMedium
		value.TextSize = 13
		value.TextXAlignment = Enum.TextXAlignment.Left

		rows[info.Uid] = { Frame = frame, Stroke = fS }

		frame.MouseButton1Click:Connect(function()
			setSelected(info.Uid)
			statusLbl.Text = "選択中: " .. (info.Name or "?")
		end)
	end
	setSelected(still and selectedUid or nil)
end

local function mkBtn(text, pos, size, color)
	local b = Instance.new("TextButton", body)
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Text = text
	b.TextColor3 = THEME.Text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.AutoButtonColor = true
	b.ZIndex = 6
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 12)
	local s = Instance.new("UIStroke", b)
	s.Color = THEME.Accent
	s.Thickness = 1.2
	s.Transparency = 0.4
	return b
end

local refreshBtn = mkBtn("更新", UDim2.new(0, 0, 1, -60), UDim2.new(0.4, -3, 0, 52), THEME.Card)
local instantBtn = mkBtn("即盗み", UDim2.new(0.4, 3, 1, -60), UDim2.new(0.6, -3, 0, 52), THEME.AccentDeep)

refreshBtn.MouseButton1Click:Connect(function()
	if not state.Busy then
		rebuild()
		statusLbl.Text = "更新完了"
	end
end)

instantBtn.MouseButton1Click:Connect(function()
	if state.Busy then
		state.Cancel = true
		statusLbl.Text = "キャンセル中..."
		return
	end
	if selectedUid then
		stealAndDeliver(selectedUid)
		statusLbl.Text = "即盗み実行中..."
	else
		statusLbl.Text = "卵を選択してください"
	end
end)

minBtn.MouseButton1Click:Connect(function()
	UI.Minimized = not UI.Minimized
	if UI.Minimized then
		TweenService:Create(main, TweenInfo.new(0.25), {Size = UDim2.fromOffset(UI_W, UI_H_MIN)}):Play()
		task.delay(0.12, function() body.Visible = false end)
	else
		body.Visible = true
		TweenService:Create(main, TweenInfo.new(0.25), {Size = UDim2.fromOffset(UI_W, UI_H)}):Play()
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	state.Cancel = true
	shieldStop()
	gui:Destroy()
end)

local drag, dragStart, startPos = false, nil, nil
header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		drag = true
		dragStart = input.Position
		startPos = main.Position
	end
end)
header.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		drag = false
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if not drag then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local d = input.Position - dragStart
	main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
end)

task.spawn(function()
	while gui.Parent do
		task.wait(CFG.AutoRefresh)
		if not state.Busy then pcall(rebuild) end
	end
end)

task.spawn(function()
	while gui.Parent do
		task.wait(0.3)
		if state.Busy then
			instantBtn.Text = "キャンセル"
			instantBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
		else
			instantBtn.Text = "即盗み"
			instantBtn.BackgroundColor3 = THEME.AccentDeep
		end
	end
end)

task.spawn(function()
	task.wait(0.3)
	pcall(rebuild)
end)

shieldStart()
print("[ShouyuHub] 起動完了")
