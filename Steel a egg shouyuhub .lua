-- ================================================================
-- SHOUYU HUB (Moon) 完全版 v1
-- Part 1/7 : セットアップ + ヘルパー
-- ================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local localPlayer = Players.LocalPlayer

-- 月の色
local MOON_BG     = Color3.fromRGB(11, 15, 28)
local MOON_CARD   = Color3.fromRGB(20, 26, 46)
local MOON_CARD2  = Color3.fromRGB(30, 38, 62)
local MOON_STROKE = Color3.fromRGB(170, 185, 215)
local MOON_TEXT   = Color3.fromRGB(240, 244, 255)
local MOON_SUB    = Color3.fromRGB(160, 172, 200)
local MOON_ACCENT = Color3.fromRGB(130, 170, 240)
local MOON_GREEN  = Color3.fromRGB(110, 235, 150)
local MOON_RED    = Color3.fromRGB(240, 100, 110)
local MOON_GOLD   = Color3.fromRGB(255, 218, 140)
local MOON_GLOW   = Color3.fromRGB(210, 225, 255)

-- 速度（ここだけ変更可能）
local SPEED = 2500

local function parentGui()
	if typeof(gethui) == "function" then
		local ok, r = pcall(gethui)
		if ok and typeof(r) == "Instance" then return r end
	end
	return CoreGui
end

local function make(class, props)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do inst[k] = v end
	return inst
end

local function corner(p, r)
	make("UICorner", { CornerRadius = UDim.new(0, r or 8) }).Parent = p
end

local living = {}
local function bands(a, b, a2)
	a2 = a2 or a
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, a),
		ColorSequenceKeypoint.new(0.25, b),
		ColorSequenceKeypoint.new(0.5, a2),
		ColorSequenceKeypoint.new(0.75, b),
		ColorSequenceKeypoint.new(1, a),
	})
end

local function livingStroke(parent, thickness, bright)
	local s = make("UIStroke", {
		Thickness = thickness or 1,
		Color = bright and MOON_GLOW or MOON_STROKE,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	s.Parent = parent
	local g = make("UIGradient", {
		Rotation = 45,
		Color = bands(bright and MOON_GLOW or MOON_STROKE, MOON_BG),
	})
	g.Parent = s
	living[#living+1] = g
	return s, g
end

local function livingText(label)
	local g = make("UIGradient", { Color = bands(MOON_TEXT, MOON_STROKE) })
	g.Parent = label
	living[#living+1] = g
	return g
end

local function txt(parent, props)
	local alive = props.Living ~= false
	props.Living = nil
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or MOON_TEXT
	local l = make("TextLabel", props)
	l.Parent = parent
	if alive then livingText(l) end
	return l
end

-- ネットワーク
local networking = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networking")
local function safeRequire(g)
	local ok, r = pcall(function() return require(g()) end)
	return ok and r or nil
end
local EggState = safeRequire(function() return ReplicatedStorage.Client.EggState end)
local Assets = safeRequire(function() return ReplicatedStorage.Data.Assets end)
local Mutations = safeRequire(function() return ReplicatedStorage.Shared.Modules.Mutations end)

local function remote(name)
	return networking:FindFirstChild(name)
end

local function root()
	local c = localPlayer.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

-- 状態
local state = {
	Carrying = false, Uid = nil, Delivered = 0,
	Busy = false, Cancel = false, Mult = 1,
	PulledAt = 0, HeldSeen = 0, GuessedDrop = false,
}

-- ステータス通知
local statusCallback = function(s) end
local function setStatus(s)
	pcall(statusCallback, s)
end

print("[SHOUYU] Part1 OK")-- ================================================================
-- Part 2/7 : Shield + Carry監視 + 卵ヘルパー
-- ================================================================

-- Shield (Humanoid Swap)
local shield = { Original = nil, Clone = nil, Links = {}, Connection = nil, Added = nil }

local function shieldControls(h)
	pcall(function()
		local scripts = localPlayer:FindFirstChild("PlayerScripts")
		local module = scripts and scripts:FindFirstChild("PlayerModule")
		if module then
			local controls = require(module):GetControls()
			if type(controls) == "table" then controls.humanoid = h end
		end
	end)
end

local function shieldAnimate(c)
	local a = c and c:FindFirstChild("Animate")
	if a and a:IsA("LocalScript") then
		task.spawn(function()
			a.Enabled = false
			task.wait()
			a.Enabled = true
		end)
	end
end

local function shieldUnlink()
	for _, l in ipairs(shield.Links) do
		pcall(function() l:Disconnect() end)
	end
	table.clear(shield.Links)
end

local groundedStates = {
	[Enum.HumanoidStateType.Running] = true,
	[Enum.HumanoidStateType.RunningNoPhysics] = true,
	[Enum.HumanoidStateType.Landed] = true,
}

local function grounded(h)
	if not h or h.Health <= 0 or h.FloorMaterial == Enum.Material.Air then return false end
	return groundedStates[h:GetState()] == true
end

local function shieldSwap()
	local c = localPlayer.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 then return end
	if shield.Clone and shield.Clone.Parent == c then return end
	if not grounded(h) then return end
	local clone = h:Clone()
	h.Parent = nil
	clone.Parent = c
	workspace.CurrentCamera.CameraSubject = clone
	shieldControls(clone)
	shieldAnimate(c)
	shield.Original = h
	shield.Clone = clone
	table.insert(shield.Links, clone.Died:Connect(function()
		shieldUnlink()
		shield.Original, shield.Clone = nil, nil
		local cur = localPlayer.Character
		if cur and h.Parent == nil then
			h.Parent = cur
			workspace.CurrentCamera.CameraSubject = h
			shieldControls(h)
		end
		pcall(function() clone:Destroy() end)
		h.Health = 0
	end))
end

local function shieldStart()
	shieldSwap()
	local n = 0
	shield.Connection = RunService.Heartbeat:Connect(function(dt)
		n += dt
		local c = localPlayer.Character
		local missing = not (shield.Clone and c and shield.Clone.Parent == c)
		if (missing and 0.25 or 3) <= n then
			n = 0
			shieldSwap()
		end
	end)
	shield.Added = localPlayer.CharacterAdded:Connect(function(c)
		shieldUnlink()
		shield.Original, shield.Clone = nil, nil
		task.spawn(function()
			c:WaitForChild("Humanoid", 10)
			task.wait(1)
			if shield.Connection and localPlayer.Character == c then
				shieldSwap()
			end
		end)
	end)
end

-- Carry 監視
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
	local r = remote("RE/EggWorld/FieldEggRedeemVerdict")
	if r then r.OnClientEvent:Connect(function() state.Delivered = os.clock() end) end
end)

pcall(function()
	local r = remote("RE/RigSync/Refresh")
	if r then
		r.OnClientEvent:Connect(function(arg)
			if type(arg) == "table" and arg.Action == "Relocate" then
				state.PulledAt = os.clock()
			end
		end)
	end
end)

-- 卵ヘルパー
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
	local best, bestD = nil, radius
	for _, child in ipairs(workspace:GetChildren()) do
		if child.Name == "SmartPromptPart" and child:IsA("BasePart") then
			local p = child:FindFirstChild("CarryAreaEgg")
			if p and p:IsA("ProximityPrompt") then
				local d = (child.Position - position).Magnitude
				if d < bestD then best, bestD = p, d end
			end
		end
	end
	return best
end

local function heldByMe(uid)
	local c = localPlayer.Character
	if type(uid) ~= "string" or not c then return false end
	local egg = workspace:FindFirstChild(uid)
	if not egg then return false end
	for _, d in ipairs(egg:GetDescendants()) do
		if d:IsA("WeldConstraint") or d:IsA("JointInstance") then
			local ok, a, b = pcall(function() return d.Part0, d.Part1 end)
			if ok and ((a and a:IsDescendantOf(c)) or (b and b:IsDescendantOf(c))) then
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
	local out = {}
	local rf = remote("RF/EggWorld/AskFieldEggSnapshot")
	if not rf or not rf:IsA("RemoteFunction") then return out end
	local ok, result = pcall(rf.InvokeServer, rf)
	local records = ok and type(result) == "table" and result.Records or nil
	if type(records) ~= "table" then return out end
	for _, r in pairs(records) do
		if type(r) == "table" and type(r.Uid) == "string"
			and (r.State == "Slot" or r.State == "Dropped")
			and typeof(r.BottomCFrame) == "CFrame" then
			out[#out+1] = r
		end
	end
	return out
end

local function eggPosition(uid)
	for _, r in ipairs(snapshot()) do
		if r.Uid == uid then return r.BottomCFrame.Position end
	end
	return nil
end

local function describe(r)
	local dir = type(Assets) == "table" and Assets.Directory or nil
	local e = type(dir) == "table" and dir[tostring(r.AssetCategory)] or nil
	local info = { Uid = r.Uid, Name = tostring(r.AssetCategory), Icon = "", Value = 0, Rarity = 0 }
	if type(e) == "table" then
		info.Name = tostring(e.DisplayName or r.AssetCategory)
		local icon = e.Icon
		if icon ~= nil and tostring(icon) ~= "" then
			icon = tostring(icon)
			info.Icon = tonumber(icon) and ("rbxassetid://" .. icon) or icon
		end
		if type(e.Rarity) == "table" then
			info.Rarity = tonumber(e.Rarity.RarityNumber or e.Rarity.Rank) or 0
		end
		local scale = tonumber(r.AssetScale) or 1
		local factor = scale > 5 and (scale / 5) ^ 1.2 * 19.637875755794113 or scale ^ 1.85
		local m = 1
		if type(Mutations) == "table" and type(Mutations.EarningsFor) == "function" then
			local ok, res = pcall(Mutations.EarningsFor, type(r.Mutations) == "table" and r.Mutations or {})
			if ok and type(res) == "number" then m = res end
		end
		info.Value = (tonumber(e.EarningRate) or 0) * factor * m
	end
	return info
end

local function money(v)
	local u = { {1e12,"T"}, {1e9,"B"}, {1e6,"M"}, {1e3,"K"} }
	for _, x in ipairs(u) do
		if v >= x[1] then return string.format("$%.2f%s/s", v/x[1], x[2]) end
	end
	return string.format("$%d/s", math.floor(v+0.5))
end

print("[SHOUYU] Part2 OK")-- ================================================================
-- Part 3/7 : 移動ヘルパー
-- ================================================================

local function lineInfo()
	local w = workspace:FindFirstChild("World") or workspace:FindFirstChild("__OBJECTS")
	w = w and w:FindFirstChild("Areas")
	w = w and w:FindFirstChild("SeparationLine")
	local ok = w and w:IsA("BasePart")
	return ok and w.Position.X or 552.2, ok and w.Position.Y or 67.67
end

local function homePoint()
	for _, def in ipairs({
		{ { "GearGiver_Slap", "Podium" }, Vector3.new(-16.415, 21.072, -6.106) },
		{ { "World", "Machines", "RiftMachine", "Rift", "Meshes/VoidPortal_Cube.003" }, Vector3.new(-26.776, 1.75, 18.665) },
		{ { "__OBJECTS", "Machines", "RiftMachine", "Rift", "Meshes/VoidPortal_Cube.003" }, Vector3.new(-26.776, 1.75, 18.665) },
	}) do
		local node = workspace
		for _, name in ipairs(def[1]) do
			node = node and node:FindFirstChild(name) or nil
		end
		if node and node:IsA("BasePart") then
			return node.CFrame:PointToWorldSpace(def[2])
		end
	end
	return Vector3.new(528.7, 70.57, -364.11)
end

local function place(position)
	local r = root()
	if not r then return end
	pcall(function()
		r.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(90), 0)
		r.AssemblyLinearVelocity = Vector3.zero
		r.AssemblyAngularVelocity = Vector3.zero
	end)
end

-- danger 避け
local dangerCache, dangerAt = {}, 0
local function dangers()
	if os.clock() - dangerAt < 1 then return dangerCache end
	dangerAt = os.clock()
	local list = {}
	local function add(inst)
		local ok, cf, size = pcall(function()
			if inst:IsA("Model") then return inst:GetBoundingBox()
			elseif inst:IsA("BasePart") then return inst.CFrame, inst.Size end
		end)
		if ok and cf and size then
			local half = Vector3.new(math.abs(size.X), 0, math.abs(size.Z)) * 0.5
			local rot = (cf - cf.Position):VectorToWorldSpace(half)
			local rx = math.max(math.abs(rot.X), half.X, half.Z)
			local rz = math.max(math.abs(rot.Z), half.X, half.Z)
			list[#list+1] = {
				MinX = cf.Position.X - rx, MaxX = cf.Position.X + rx,
				MinZ = cf.Position.Z - rz, MaxZ = cf.Position.Z + rz,
			}
		end
	end
	local function bad(name)
		if name == "ScrambleLocalVisuals" or name == "DrScrambleEvent" then return false end
		name = string.lower(name)
		return string.find(name, "portal", 1, true)
			or string.find(name, "teleport", 1, true)
			or string.find(name, "mech", 1, true)
			or string.find(name, "arena", 1, true)
			or string.find(name, "scramble", 1, true)
	end
	for _, child in ipairs(workspace:GetChildren()) do
		if (child:IsA("Model") or child:IsA("BasePart") or child:IsA("Folder")) and bad(child.Name) then
			if child:IsA("Folder") then
				for _, inner in ipairs(child:GetChildren()) do add(inner) end
			else
				add(child)
			end
		end
	end
	local build = workspace:FindFirstChild("World")
	build = build and build:FindFirstChild("Build")
	if build then
		for _, child in ipairs(build:GetChildren()) do
			if bad(child.Name) then
				for _, inner in ipairs(child:GetChildren()) do add(inner) end
			end
		end
	end
	dangerCache = list
	return list
end

local function avoid(from, to)
	for _, d in ipairs(dangers()) do
		local x0, x1, z0, z1 = d.MinX - 12, d.MaxX + 12, d.MinZ - 12, d.MaxZ + 12
		local inside = from.X >= x0 and from.X <= x1 and from.Z >= z0 and from.Z <= z1
		if not inside then
			local t0, t1, hit = 0, 1, true
			for _, axis in ipairs({
				{ from.X, to.X - from.X, x0, x1 },
				{ from.Z, to.Z - from.Z, z0, z1 },
			}) do
				local pos, delta, lo, hi = axis[1], axis[2], axis[3], axis[4]
				if math.abs(delta) < 1e-6 then
					if pos < lo or pos > hi then hit = false end
				else
					local ta, tb = (lo - pos) / delta, (hi - pos) / delta
					if ta > tb then ta, tb = tb, ta end
					t0, t1 = math.max(t0, ta), math.min(t1, tb)
					if t0 > t1 then hit = false end
				end
			end
			if hit then
				local zLow, zHigh = z0 - 2, z1 + 2
				local z = math.abs(from.Z - zLow) <= math.abs(from.Z - zHigh) and zLow or zHigh
				if z < -440 or z > -290 then z = z == zLow and zHigh or zLow end
				local x = math.abs(from.X - x0) <= math.abs(from.X - x1) and x0 or x1
				if math.abs(from.Z - z) < 3 then
					x = math.abs(to.X - x0) <= math.abs(to.X - x1) and x0 or x1
				end
				return Vector3.new(x, to.Y, z)
			end
		end
	end
	return to
end

-- runToEgg
local function runToEgg(uid, egg)
	local lineX = lineInfo()
	local home = homePoint()
	local c = localPlayer.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if h then
		h.PlatformStand = false
		if c:FindFirstChildWhichIsA("Tool") then
			pcall(function() h:UnequipTools() end)
		end
	end

	local r = root()
	if not r then return false end
	local stage = "field"
	if r.Position.X < lineX - 2
		and Vector3.new(r.Position.X - home.X, 0, r.Position.Z - home.Z).Magnitude > 20 then
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
		local waypoint = avoid(r.Position, target)
		local flat = Vector3.new(waypoint.X - r.Position.X, 0, waypoint.Z - r.Position.Z)
		local unit = flat.Magnitude > 0.01 and flat.Unit or Vector3.zero
		local v = unit * math.min(SPEED, flat.Magnitude / 0.05)
		pcall(function()
			r.AssemblyLinearVelocity = Vector3.new(v.X, r.AssemblyLinearVelocity.Y, v.Z)
			if h and unit.Magnitude > 0 then h:Move(unit, false) end
		end)
		if os.clock() - lastCheck >= 1.5 then
			if (r.Position - lastPos).Magnitude < 3 and h and flatEgg.Magnitude > 15 then
				pcall(function() h.Jump = true end)
			end
			lastPos, lastCheck = r.Position, os.clock()
		end
		if stage == "field" and flatEgg.Magnitude <= 9 and os.clock() - lastTake > 0.1 then
			lastTake = os.clock()
			takeEgg(uid)
		end
		RunService.Heartbeat:Wait()
	end
	r = root()
	if r then
		pcall(function()
			r.AssemblyLinearVelocity = Vector3.new(0, r.AssemblyLinearVelocity.Y, 0)
			if h then h:Move(Vector3.zero, false) end
		end)
	end
	return state.Carrying
		or (r ~= nil and Vector3.new(egg.X - r.Position.X, 0, egg.Z - r.Position.Z).Magnitude <= 6)
end

-- grab
local function eggNow(uid, cache)
	local node = workspace:FindFirstChild(uid)
	local slots = workspace:FindFirstChild("AreaEggSlotsClient")
	node = node or (slots and slots:FindFirstChild(uid))
	if node then
		local ok, pos = pcall(function() return node:GetPivot().Position end)
		if ok and pos then cache.Pos, cache.At = pos, os.clock(); return pos end
	end
	if os.clock() - cache.At >= 0.5 then
		cache.At = os.clock()
		cache.Pos = eggPosition(uid) or cache.Pos
	end
	return cache.Pos
end

local function grab(uid, timeout)
	local cache = { At = 0 }
	local waited, since = 0, 1
	while not state.Carrying and waited < timeout and not state.Cancel do
		local r = root()
		local egg = eggNow(uid, cache)
		local dt = math.max(RunService.Heartbeat:Wait(), 1 / 240)
		waited += dt
		since += dt
		if r and egg then
			local delta = egg - r.Position
			if delta.Magnitude > 2 then
				local v = delta / math.max(0.08, dt)
				if v.Magnitude > SPEED then v = v.Unit * SPEED end
				pcall(function()
					r.AssemblyLinearVelocity = v + Vector3.new(0, workspace.Gravity * dt * 0.5, 0)
					r.AssemblyAngularVelocity = Vector3.zero
				end)
			end
			if since >= 0.03 then
				since = 0
				local p = promptNear(egg - Vector3.new(0, 3, 0), 10)
				if p and typeof(fireproximityprompt) == "function" then
					pcall(function() p.HoldDuration = 0 end)
					pcall(fireproximityprompt, p)
				end
				task.spawn(takeEgg, uid)
			end
		elseif since >= 0.03 then
			since = 0
			task.spawn(takeEgg, uid)
		end
	end
	local r = root()
	if r then pcall(function() r.AssemblyLinearVelocity = Vector3.zero end) end
	return state.Carrying and state.Uid == uid
end

local function regrab(uid)
	if state.Carrying then return true end
	local r = root()
	local egg = eggPosition(uid)
	if r and egg
		and Vector3.new(r.Position.X - egg.X, 0, r.Position.Z - egg.Z).Magnitude > 40 then
		place(egg + Vector3.new(0, 3, 0))
	end
	return grab(uid, 3)
end

-- runHome
local function runHome(lineX, laneZ)
	local started = os.clock()
	local home = homePoint()
	local checkpoint = lineX - 7
	local height = 70
	local share = 0.5
	local descent = height * math.sqrt(1 - share * share) / share
	local c = localPlayer.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if h then h.PlatformStand = false end

	local r = root()
	if r and c and home.Y + height - 2 > r.Position.Y then
		pcall(function()
			c:PivotTo(CFrame.new(Vector3.new(r.Position.X, home.Y + height, r.Position.Z)) * r.CFrame.Rotation)
			r.AssemblyLinearVelocity = Vector3.zero
			r.AssemblyAngularVelocity = Vector3.zero
		end)
	end

	local last = os.clock()
	local timeout = 0
	while state.Carrying and state.Delivered < started and not state.Cancel and timeout < 25 do
		r = root()
		if not r then return false end
		local now = os.clock()
		local dt = math.max(now - last, 1 / 240)
		last = now
		timeout += dt
		local toHome = r.Position.X <= checkpoint + 2
		local target = toHome and home or Vector3.new(checkpoint, home.Y, laneZ)
		if toHome and Vector3.new(home.X - r.Position.X, 0, home.Z - r.Position.Z).Magnitude < 2 then break end
		local aim = avoid(r.Position, target)
		local flat = Vector3.new(aim.X - r.Position.X, 0, aim.Z - r.Position.Z)
		local remaining = toHome and 0 or math.max(0, r.Position.X - checkpoint)
		local wantY = home.Y + height
		if toHome or remaining <= descent then
			wantY = home.Y + height * math.clamp(remaining / math.max(descent, 1), 0, 1)
		end
		local vy = math.clamp((wantY - r.Position.Y) / 0.12, -SPEED * share, SPEED * share)
		local horizontal = math.sqrt(math.max(SPEED * SPEED - vy * vy, 0))
		local v = flat.Magnitude > 0.01
			and flat.Unit * math.min(horizontal, flat.Magnitude / 0.05)
			or Vector3.zero
		pcall(function() r.AssemblyLinearVelocity = Vector3.new(v.X, vy, v.Z) end)
		RunService.Heartbeat:Wait()
	end

	if h then pcall(function() h:Move(Vector3.zero, false) end) end
	local settle = 0
	while settle < 2 and state.Delivered < started and state.Carrying and not state.Cancel do
		settle += RunService.Heartbeat:Wait()
	end
	if state.Carrying and state.Delivered < started and not state.Cancel then
		task.wait(0.2)
		dropEgg()
		local waited = 0
		while state.Delivered < started and waited < 1 do
			waited += RunService.Heartbeat:Wait()
		end
	end
	return state.Delivered >= started
end

print("[SHOUYU] Part3 OK")-- ================================================================
-- Part 4/7 : Instant TP + スティール実行
-- ================================================================

local function frozenCamera()
	local cam = workspace.CurrentCamera
	if not cam then return function() end end
	local oldType = cam.CameraType
	local frame = cam.CFrame
	pcall(function()
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = frame
	end)
	return function()
		pcall(function() cam.CameraType = oldType end)
	end
end

local fpsGen = 0
local function fpsOn()
	if typeof(setfpscap) ~= "function" then return end
	fpsGen += 1
	local mine = fpsGen
	task.spawn(function()
		local high = true
		local started = os.clock()
		while fpsGen == mine and os.clock() - started < 60 do
			pcall(setfpscap, high and 60 or 30)
			high = not high
			task.wait(0.15)
		end
	end)
end
local function fpsOff()
	fpsGen += 1
	if typeof(setfpscap) == "function" then pcall(setfpscap, 240) end
end

local stealClone = nil
local function dropClone()
	local c = stealClone
	stealClone = nil
	if c then pcall(function() c:Destroy() end) end
end
local function postClone()
	dropClone()
	local c = localPlayer.Character
	if not c then return end
	local was = c.Archivable
	c.Archivable = true
	local copy = c:Clone()
	c.Archivable = was
	if copy then
		for _, d in ipairs(copy:GetDescendants()) do
			if d:IsA("LuaSourceContainer") or d:IsA("Humanoid") then
				pcall(function() d:Destroy() end)
			elseif d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
			end
		end
		copy.Name = "Clone"
		copy.Parent = workspace
		stealClone = copy
	end
end

local function groundY(position, fallback)
	local y = fallback
	pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { localPlayer.Character }
		params.IgnoreWater = true
		local hit = workspace:Raycast(position + Vector3.new(0, 60, 0), Vector3.new(0, -140, 0), params)
		if hit and hit.Material ~= Enum.Material.Water
			and math.abs(hit.Position.Y - fallback) < 40 then
			y = hit.Position.Y + 3.5
		end
	end)
	return y
end

-- Instant TP
local function instantTP(uid)
	local started = os.clock()
	local lineX, lineY = lineInfo()
	local r = root()
	if not r then return false end
	local laneZ = math.clamp(r.Position.Z, -425, -300)
	local landing = Vector3.new(lineX + 14, lineY + 3.35, laneZ)

	local hopStep = math.max(16 * 1.515, 40)
	local hopY = r.Position.Y + 42
	local x = r.Position.X
	local retries = 0
	local hopGap = 0.06
	local releaseCamera = frozenCamera()
	pcall(postClone)
	fpsOn()

	while x - hopStep > landing.X and not state.Cancel do
		if not state.Carrying then
			if not regrab(uid) then break end
			local cur = root()
			if cur then x = math.min(x, cur.Position.X) end
			continue
		end
		local nextX = x - hopStep
		local pulledBefore = state.PulledAt
		local held = 0
		while held < hopGap do
			place(Vector3.new(nextX, hopY, laneZ))
			held += RunService.Heartbeat:Wait()
		end
		local check = root()
		local pulled = state.PulledAt > pulledBefore
			or (check ~= nil and (check.Position.X - nextX > 10
				or check.AssemblyLinearVelocity.Magnitude > 150))
		if pulled and state.Carrying and not state.Cancel then
			retries += 1
			hopGap = math.min(0.2, hopGap + 0.02)
			if retries > 6 then break end
			local settle = 0
			while settle < 0.12 and not state.Cancel do
				place(Vector3.new(x, hopY, laneZ))
				settle += RunService.Heartbeat:Wait()
			end
		else
			x = nextX
			hopGap = math.max(0.06, hopGap - 0.01)
		end
	end

	landing = Vector3.new(landing.X, groundY(landing, landing.Y), landing.Z)
	local function land()
		local cur = root()
		if cur and cur.Position.X <= landing.X + 1 and cur.Position.Y > landing.Y - 25 then
			pcall(function() cur.AssemblyLinearVelocity = Vector3.zero end)
			return
		end
		place(landing)
	end
	land()
	for _ = 1, 3 do
		local settle = 0
		while settle < 0.08 and not state.Cancel do
			settle += RunService.Heartbeat:Wait()
		end
		local landed = root()
		if state.Carrying and landed
			and (landed.Position.X - landing.X > 12 or landed.Position.Y < landing.Y - 25) then
			land()
		else
			break
		end
	end
	dropClone()

	if state.Carrying and not state.Cancel then
		local delay = 0
		while delay < 0.05 do
			delay += RunService.Heartbeat:Wait()
		end
		dropEgg()
		local waited = 0
		while state.Carrying and waited < 1 and not state.Cancel do
			waited += RunService.Heartbeat:Wait()
		end
		local cur = root()
		if cur then
			pcall(function()
				cur.AssemblyLinearVelocity = Vector3.zero
				cur.AssemblyAngularVelocity = Vector3.zero
			end)
		end
		releaseCamera()
		dropClone()
		if not grab(uid, 3) and not regrab(uid) then
			fpsOff()
			return false
		end
		dropClone()
	end
	releaseCamera()
	local ok = false
	if state.Carrying then ok = runHome(lineX, laneZ) end
	fpsOff()
	return ok or state.Delivered >= started
end

-- スティール実行（外から呼ぶ）
local function stealAndDeliver(uid, instant)
	if state.Busy then return end
	state.Busy = true
	state.Cancel = false
	task.spawn(function()
		local ok, err = pcall(function()
			setStatus("卵を探しています")
			local egg = eggPosition(uid)
			if not egg then
				setStatus("卵が消えました")
				return
			end
			if state.Carrying and state.Uid ~= uid then
				dropEgg()
				local waited = 0
				while state.Carrying and waited < 1 do
					waited += RunService.Heartbeat:Wait()
				end
			end
			fpsOn()

			if instant then
				setStatus("即盗み開始")
				local r = root()
				if r then
					pcall(function()
						r.CFrame = CFrame.new(egg + Vector3.new(0, 3, 0))
						r.AssemblyLinearVelocity = Vector3.zero
						r.AssemblyAngularVelocity = Vector3.zero
					end)
				end
				task.wait(0.05)
				if not grab(uid, 1.5) then
					fpsOff()
					setStatus("掴めませんでした")
					return
				end
			else
				setStatus("卵に向かっています")
				if not runToEgg(uid, egg) then
					fpsOff()
					setStatus("卵にたどり着けません")
					return
				end
				setStatus("卵を掴んでいます")
				if not grab(uid, 4) then
					fpsOff()
					setStatus("卵を掴めませんでした")
					return
				end
			end

			local delivered = instantTP(uid)
			setStatus(delivered and "納品完了" or "納品失敗")
		end)
		fpsOff()
		dropClone()
		if not ok then setStatus("エラー: " .. tostring(err)) end
		state.Busy = false
	end)
end

print("[SHOUYU] Part4 OK")-- ================================================================
-- ================================================================
-- Part 5 : UI本体
-- ================================================================
local prev = parentGui():FindFirstChild("ShouyuHubMoon")
if prev then prev:Destroy() end

local gui = make("ScreenGui", {
	Name = "ShouyuHubMoon",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	IgnoreGuiInset = true,
	DisplayOrder = 100,
})
gui.Parent = parentGui()

local W, H = 240, 460
local HEADER_H = 70

local window = make("Frame", {
	Size = UDim2.fromOffset(W, H),
	Position = UDim2.new(0.5, -W/2, 0.5, -H/2),
	BackgroundColor3 = MOON_BG,
	BorderSizePixel = 0,
	ClipsDescendants = true,
})
window.Parent = gui
corner(window, 14)
livingStroke(window, 1.5, true)

-- 動く光
do
	local tick, rot = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		tick += 1
		if tick % 2 ~= 0 then return end
		rot = (rot + dt * 60) % 360
		for _, g in ipairs(living) do
			if g.Parent then
				g.Rotation = g.Parent:IsA("UIStroke") and (45 + rot) % 360 or rot
			end
		end
	end)
end

-- ヘッダー
local header = make("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, HEADER_H),
	Position = UDim2.fromOffset(0, 0),
	BackgroundColor3 = MOON_CARD,
	BorderSizePixel = 0,
})
header.Parent = window
make("Frame", {
	Size = UDim2.new(1, 0, 0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	BackgroundColor3 = MOON_STROKE,
	BackgroundTransparency = 0.6,
	BorderSizePixel = 0,
}).Parent = header

-- 月ロゴ
local logoSize = 42
local logoFrame = make("Frame", {
	Size = UDim2.fromOffset(logoSize, logoSize),
	Position = UDim2.fromOffset(12, 14),
	BackgroundColor3 = MOON_GLOW,
	BorderSizePixel = 0,
})
logoFrame.Parent = header
corner(logoFrame, logoSize / 2)

local moonShadow = make("Frame", {
	Size = UDim2.fromOffset(logoSize - 10, logoSize - 10),
	Position = UDim2.fromOffset(12, -2),
	BackgroundColor3 = MOON_CARD,
	BorderSizePixel = 0,
})
moonShadow.Parent = logoFrame
corner(moonShadow, (logoSize - 10) / 2)

txt(header, {
	Size = UDim2.new(1, -110, 0, 20),
	Position = UDim2.fromOffset(62, 14),
	Font = Enum.Font.GothamBlack,
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "SHOUYU HUB",
	TextColor3 = Color3.fromRGB(255, 120, 120),
	Living = false,
})
txt(header, {
	Size = UDim2.new(1, -110, 0, 14),
	Position = UDim2.fromOffset(62, 38),
	Font = Enum.Font.Gotham,
	TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "STEAL AN EGG",
	TextColor3 = MOON_SUB,
	Living = false,
})

local minBtn = make("TextButton", {
	Size = UDim2.fromOffset(30, 30),
	Position = UDim2.new(1, -74, 0, 20),
	BackgroundColor3 = MOON_CARD2,
	Font = Enum.Font.GothamBlack,
	TextSize = 18,
	TextColor3 = MOON_TEXT,
	Text = "-",
	AutoButtonColor = false,
	BorderSizePixel = 0,
	ZIndex = 5,
})
minBtn.Parent = header
corner(minBtn, 7)
livingStroke(minBtn, 1, false)

local closeBtn = make("TextButton", {
	Size = UDim2.fromOffset(30, 30),
	Position = UDim2.new(1, -40, 0, 20),
	BackgroundColor3 = MOON_RED,
	Font = Enum.Font.GothamBlack,
	TextSize = 16,
	TextColor3 = MOON_TEXT,
	Text = "X",
	AutoButtonColor = false,
	BorderSizePixel = 0,
	ZIndex = 5,
})
closeBtn.Parent = header
corner(closeBtn, 7)

-- ステータス行
local statusRow = make("Frame", {
	Name = "StatusRow",
	Size = UDim2.new(1, -16, 0, 26),
	Position = UDim2.fromOffset(8, HEADER_H + 8),
	BackgroundTransparency = 1,
})
statusRow.Parent = window

local statusLabel = txt(statusRow, {
	Size = UDim2.new(1, -100, 1, 0),
	Position = UDim2.fromOffset(4, 0),
	Font = Enum.Font.GothamMedium,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "待機中...",
	TextColor3 = MOON_ACCENT,
})
statusCallback = function(s) statusLabel.Text = tostring(s) end

local autoUpdateBtn = make("TextButton", {
	Size = UDim2.fromOffset(90, 24),
	Position = UDim2.new(1, -94, 0, 1),
	BackgroundColor3 = MOON_CARD2,
	Font = Enum.Font.GothamBold,
	TextSize = 10,
	TextColor3 = MOON_TEXT,
	Text = "自動更新 ON",
	AutoButtonColor = false,
	BorderSizePixel = 0,
})
autoUpdateBtn.Parent = statusRow
corner(autoUpdateBtn, 6)
livingStroke(autoUpdateBtn, 1, false)

local autoUpdateOn = true
autoUpdateBtn.MouseButton1Click:Connect(function()
	autoUpdateOn = not autoUpdateOn
	autoUpdateBtn.Text = autoUpdateOn and "自動更新 ON" or "自動更新 OFF"
	autoUpdateBtn.TextColor3 = autoUpdateOn and MOON_GREEN or MOON_SUB
end)

-- 卵リスト
local BOTTOM_BTN_H = 44
local listTop = HEADER_H + 8 + 26 + 8
local listH = H - listTop - BOTTOM_BTN_H - 16

local list = make("ScrollingFrame", {
	Name = "EggList",
	Size = UDim2.new(1, -16, 0, listH),
	Position = UDim2.fromOffset(8, listTop),
	BackgroundColor3 = MOON_CARD,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = MOON_STROKE,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
})
list.Parent = window
corner(list, 10)
livingStroke(list, 1, false)
make("UIListLayout", {
	Padding = UDim.new(0, 4),
	SortOrder = Enum.SortOrder.LayoutOrder,
}).Parent = list
make("UIPadding", {
	PaddingTop = UDim.new(0, 6),
	PaddingBottom = UDim.new(0, 6),
	PaddingLeft = UDim.new(0, 6),
	PaddingRight = UDim.new(0, 6),
}).Parent = list

local rarityColors = {
	Color3.fromRGB(210, 220, 240),
	Color3.fromRGB(160, 220, 200),
	Color3.fromRGB(140, 190, 240),
	Color3.fromRGB(190, 180, 250),
	Color3.fromRGB(230, 205, 145),
	Color3.fromRGB(245, 165, 165),
	Color3.fromRGB(245, 185, 225),
	Color3.fromRGB(180, 235, 240),
}

local rows = {}
local selectedUid = nil

local function setSelected(uid)
	selectedUid = uid
	for rowUid, row in pairs(rows) do
		local on = rowUid == uid
		row.Stroke.Thickness = on and 1.8 or 1
		row.Stroke.Color = on and MOON_GLOW or MOON_STROKE
		row.Frame.BackgroundColor3 = on and MOON_CARD2 or MOON_CARD
	end
end

local function rebuild()
	for _, row in pairs(rows) do row.Frame:Destroy() end
	table.clear(rows)

	local infos = {}
	for _, r in ipairs(snapshot()) do infos[#infos+1] = describe(r) end
	table.sort(infos, function(a, b) return a.Value > b.Value end)

	if #infos == 0 then
		txt(list, {
			Size = UDim2.new(1, 0, 0, 40),
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = MOON_SUB,
			Text = "フィールドに卵がありません",
		})
		statusLabel.Text = "待機中..."
		return
	end

	for i, info in ipairs(infos) do
		local frame = make("TextButton", {
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundColor3 = MOON_CARD,
			LayoutOrder = i,
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
		})
		frame.Parent = list
		corner(frame, 8)
		local rowStroke = livingStroke(frame, 1, false)

		local iconBox = make("Frame", {
			Size = UDim2.fromOffset(34, 34),
			Position = UDim2.fromOffset(6, 6),
			BackgroundColor3 = MOON_BG,
			BorderSizePixel = 0,
		})
		iconBox.Parent = frame
		corner(iconBox, 6)
		if info.Icon ~= "" then
			make("ImageLabel", {
				Size = UDim2.fromScale(0.9, 0.9),
				Position = UDim2.fromScale(0.05, 0.05),
				BackgroundTransparency = 1,
				Image = info.Icon,
				ScaleType = Enum.ScaleType.Fit,
				Parent = iconBox,
			})
		end

		txt(frame, {
			Size = UDim2.new(1, -50, 0, 18),
			Position = UDim2.fromOffset(46, 6),
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = info.Name,
			TextColor3 = rarityColors[math.clamp(info.Rarity, 1, #rarityColors)] or MOON_TEXT,
		})
		txt(frame, {
			Size = UDim2.new(1, -50, 0, 14),
			Position = UDim2.fromOffset(46, 25),
			Font = Enum.Font.GothamMedium,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = money(info.Value),
			TextColor3 = MOON_SUB,
		})

		rows[info.Uid] = { Frame = frame, Stroke = rowStroke }
		frame.MouseButton1Click:Connect(function()
			setSelected(info.Uid)
			statusLabel.Text = "選択: " .. info.Name
		end)
	end
	statusLabel.Text = string.format("%d 個の卵を検出", #infos)
end

print("[SHOUYU] Part5 OK (240x460)")
-- ================================================================
-- Part 6 : ボタン + 開け閉め
-- ================================================================
local btnRow = make("Frame", {
	Name = "BtnRow",
	Size = UDim2.new(1, -16, 0, 36),
	Position = UDim2.new(0, 8, 1, -44),
	BackgroundTransparency = 1,
})
btnRow.Parent = window

local function bottomButton(label, posX, sizeX, bg, textColor)
	local b = make("TextButton", {
		Size = UDim2.new(sizeX, -4, 1, 0),
		Position = UDim2.new(posX, 4, 0, 0),
		BackgroundColor3 = bg,
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = textColor,
		Text = label,
		AutoButtonColor = false,
		BorderSizePixel = 0,
	})
	b.Parent = btnRow
	corner(b, 8)
	livingStroke(b, 1, true)
	return b
end

local refreshBtn = bottomButton("更新", 0, 0.34, MOON_CARD2, MOON_TEXT)
local autoBtn = bottomButton("自動盗み", 0.34, 0.33, MOON_CARD2, MOON_TEXT)
local instantBtn = bottomButton("即盗み", 0.67, 0.33, MOON_ACCENT, MOON_BG)

refreshBtn.MouseButton1Click:Connect(function()
	if state.Busy then
		statusLabel.Text = "実行中は更新できません"
		return
	end
	rebuild()
	statusLabel.Text = "更新しました"
end)

local autoRunning = false
autoBtn.MouseButton1Click:Connect(function()
	if autoRunning then
		autoRunning = false
		autoBtn.Text = "自動盗み"
		autoBtn.BackgroundColor3 = MOON_CARD2
		autoBtn.TextColor3 = MOON_TEXT
		state.Cancel = true
		statusLabel.Text = "自動盗み 停止"
		return
	end
	autoRunning = true
	autoBtn.Text = "自動盗み ON"
	autoBtn.BackgroundColor3 = MOON_GREEN
	autoBtn.TextColor3 = MOON_BG
	statusLabel.Text = "自動盗み 開始"
	task.spawn(function()
		while autoRunning do
			if not state.Busy and not state.Carrying then
				local infos = {}
				for _, r in ipairs(snapshot()) do infos[#infos+1] = describe(r) end
				table.sort(infos, function(a, b) return a.Value > b.Value end)
				local best = infos[1]
				if best then stealAndDeliver(best.Uid, false) end
			end
			task.wait(1.5)
		end
	end)
end)

instantBtn.MouseButton1Click:Connect(function()
	if not selectedUid then
		statusLabel.Text = "先に卵を選んでください"
		return
	end
	if state.Busy then
		statusLabel.Text = "実行中です"
		return
	end
	stealAndDeliver(selectedUid, true)
end)

-- 開け閉め
local minimized = false
local function setMinimized(v)
	minimized = v
	if minimized then
		window.Size = UDim2.fromOffset(W, HEADER_H)
		statusRow.Visible = false
		list.Visible = false
		btnRow.Visible = false
		minBtn.Text = "+"
	else
		window.Size = UDim2.fromOffset(W, H)
		statusRow.Visible = true
		list.Visible = true
		btnRow.Visible = true
		minBtn.Text = "-"
	end
end

minBtn.MouseButton1Click:Connect(function()
	setMinimized(not minimized)
end)

-- ヘッダーをタップでも開け閉め（min/closeボタン以外）
local headerHit = make("TextButton", {
	Size = UDim2.new(1, -80, 1, 0),
	Position = UDim2.fromOffset(0, 0),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 1,
})
headerHit.Parent = header
headerHit.MouseButton1Click:Connect(function()
	setMinimized(not minimized)
end)

-- ドラッグ
do
	local dragging, startPos, startInput
	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging, startPos, startInput = true, window.Position, input.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - startInput
			window.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + d.X,
				startPos.Y.Scale, startPos.Y.Offset + d.Y
			)
		end
	end)
end

closeBtn.MouseButton1Click:Connect(function()
	autoRunning = false
	state.Cancel = true
	gui.Enabled = false
end)

print("[SHOUYU] Part6 OK")
-- Part 7/7 : 起動
-- ================================================================

-- 自動更新ループ
task.spawn(function()
	while gui.Parent do
		task.wait(5)
		if gui.Enabled and autoUpdateOn and not minimized and not state.Busy then
			pcall(rebuild)
		end
	end
end)

-- 公開API
_G.ShouyuHubMoon = {
	Rebuild = rebuild,
	GetSelected = function() return selectedUid end,
	SetStatus = function(s) statusLabel.Text = tostring(s) end,
	Steal = function(uid, instant) stealAndDeliver(uid, instant == true) end,
	Show = function() gui.Enabled = true end,
	Hide = function() gui.Enabled = false end,
	Speed = SPEED,
}

-- Shield 起動
shieldStart()

-- 初回リスト構築
rebuild()

print("[SHOUYU HUB Moon] ★起動完了★")
print("  サイズ: " .. W .. "x" .. H)
print("  速度: " .. SPEED)
print("  即盗みボタン → 選択卵を即スティール")
print("  自動盗みボタン → 最高値卵を自動スティール")
