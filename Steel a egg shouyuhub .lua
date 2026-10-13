local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local localPlayer = Players.LocalPlayer

local CFG = {
	SpeedCap = 1.15, HopRatio = 1.515, HopMin = 40,
	HopGap = 0.06, HopGapMin = 0.06, HopGapMax = 0.2,
	HopRetries = 6, HopLift = 42, LandOffset = 14,
	LandSettle = 0.08, DropDelay = 0.05, GrabInterval = 0.03,
	RegrabFar = 40, Height = 70, ClimbShare = 0.5,
	CarryRatio = 0.9, EasyRatio = 1.3,
}
local FPS = { 60, 30, 0.15 }

local function safeRequire(g)
	local ok, r = pcall(function() return require(g()) end)
	return ok and r or nil
end

local networkingFolder = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networking")
local EggState = safeRequire(function() return ReplicatedStorage.Client.EggState end)
local Assets = safeRequire(function() return ReplicatedStorage.Data.Assets end)
local Mutations = safeRequire(function() return ReplicatedStorage.Shared.Modules.Mutations end)

local function remote(n) return networkingFolder:FindFirstChild(n) end
local function root()
	local c = localPlayer.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local state = { Carrying=false, Uid=nil, Delivered=0, Busy=false, Cancel=false, Mult=1, PulledAt=0, HeldSeen=0, GuessedDrop=false }

print("[SHOUYU] Part1 OK")
local shield = { Original=nil, Clone=nil, Links={}, Connection=nil, Added=nil }

local function walkSpeed()
	local c = localPlayer.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	local speed = h and h.WalkSpeed or 16
	if shield.Original and shield.Original.Health > 0 then
		speed = math.min(speed, shield.Original.WalkSpeed)
	end
	local ok, r = pcall(function()
		local stat = localPlayer:FindFirstChild("leaderstats")
		stat = stat and stat:FindFirstChild("Speed")
		local util = require(ReplicatedStorage.Shared.Util.TreadmillUtil)
		return stat and util.SpeedPowerToWalkSpeed(stat.Value) or nil
	end)
	if ok and type(r) == "number" and r > 0 then
		speed = math.min(speed, r)
	end
	return speed
end

local function shieldControls(h)
	pcall(function()
		local ps = localPlayer:FindFirstChild("PlayerScripts")
		local m = ps and ps:FindFirstChild("PlayerModule")
		if m then
			local c = require(m):GetControls()
			if type(c) == "table" then c.humanoid = h end
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
	[Enum.HumanoidStateType.Running]=true,
	[Enum.HumanoidStateType.RunningNoPhysics]=true,
	[Enum.HumanoidStateType.Landed]=true,
}

local function grounded(h)
	if not h or h.Health <= 0 or h.FloorMaterial == Enum.Material.Air then return false end
	return groundedStates[h:GetState()] == true
end

print("[SHOUYU] Part2 OK")
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
	table.insert(shield.Links, h:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if clone.Parent ~= nil then clone.WalkSpeed = h.WalkSpeed end
	end))
	local a1 = h:FindFirstChildOfClass("Animator")
	local a2 = clone:FindFirstChildOfClass("Animator")
	if a1 and a2 then
		table.insert(shield.Links, a1.AnimationPlayed:Connect(function(played)
			local anim = played.Animation
			if not anim or clone.Parent == nil then return end
			local ok, track = pcall(function() return a2:LoadAnimation(anim) end)
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

local function shieldUndo()
	shieldUnlink()
	local c = localPlayer.Character
	local o, cl = shield.Original, shield.Clone
	shield.Original, shield.Clone = nil, nil
	if o and cl and c and o.Parent == nil and cl.Parent == c then
		o.Parent = c
		workspace.CurrentCamera.CameraSubject = o
		shieldControls(o)
		pcall(function() cl:Destroy() end)
		shieldAnimate(c)
	end
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

local function shieldStop()
	if shield.Connection then shield.Connection:Disconnect(); shield.Connection = nil end
	if shield.Added then shield.Added:Disconnect(); shield.Added = nil end
	shieldUndo()
end

print("[SHOUYU] Part3 OK")
if type(EggState) == "table" and type(EggState.CarryChanged) == "table"
	and type(EggState.CarryChanged.Connect) == "function" then
	EggState.CarryChanged:Connect(function(a)
		local c = type(a) == "table" and a.IsCarrying == true
		if c and a.GuardDisabled == true then c = false end
		state.GuessedDrop = false
		if c then state.HeldSeen = os.clock() end
		if c and type(a.Uid) == "string" then
			state.Uid = a.Uid
			local m = tonumber(a.SpeedMultiplier)
			if m and m > 0 then state.Mult = m end
		end
		state.Carrying = c
	end)
end

pcall(function()
	remote("RE/EggWorld/FieldEggRedeemVerdict").OnClientEvent:Connect(function()
		state.Delivered = os.clock()
	end)
end)

pcall(function()
	remote("RE/RigSync/Refresh").OnClientEvent:Connect(function(a)
		if type(a) == "table" and a.Action == "Relocate" then
			state.PulledAt = os.clock()
		end
	end)
end)

local function takeEgg(uid)
	if type(uid) == "string" and type(EggState) == "table"
		and type(EggState.CarryFieldEgg) == "function" then
		pcall(EggState.CarryFieldEgg, uid)
	end
end

local function dropEgg()
	if type(EggState) == "table" and type(EggState.DropFieldEgg) == "function" then
		pcall(EggState.DropFieldEgg, "PlayerRequest")
	end
end

local function promptNear(pos, radius)
	local best, bestD = nil, radius
	for _, c in ipairs(workspace:GetChildren()) do
		if c.Name == "SmartPromptPart" and c:IsA("BasePart") then
			local p = c:FindFirstChild("CarryAreaEgg")
			if p and p:IsA("ProximityPrompt") then
				local d = (c.Position - pos).Magnitude
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
	local ok, r = pcall(function()
		return remote("RF/EggWorld/AskFieldEggSnapshot"):InvokeServer()
	end)
	local recs = ok and type(r) == "table" and r.Records or nil
	if type(recs) ~= "table" then return out end
	for _, rec in pairs(recs) do
		if type(rec) == "table" and type(rec.Uid) == "string"
			and (rec.State == "Slot" or rec.State == "Dropped")
			and typeof(rec.BottomCFrame) == "CFrame" then
			out[#out + 1] = rec
		end
	end
	return out
end

local function eggPosition(uid)
	for _, rec in ipairs(snapshot()) do
		if rec.Uid == uid then return rec.BottomCFrame.Position end
	end
	return nil
end

local function describe(rec)
	local dir = type(Assets) == "table" and Assets.Directory or nil
	local e = type(dir) == "table" and dir[tostring(rec.AssetCategory)] or nil
	local info = { Uid=rec.Uid, Name=tostring(rec.AssetCategory), Icon="", Rarity=0, Value=0 }
	if type(e) == "table" then
		info.Name = tostring(e.DisplayName or rec.AssetCategory)
		local ic = e.Icon
		if ic ~= nil and tostring(ic) ~= "" then
			ic = tostring(ic)
			info.Icon = tonumber(ic) and ("rbxassetid://" .. ic) or ic
		end
		if type(e.Rarity) == "table" then
			info.Rarity = tonumber(e.Rarity.RarityNumber or e.Rarity.Rank) or 0
		end
		local s = tonumber(rec.AssetScale) or 1
		local f = s > 5 and (s / 5) ^ 1.2 * 19.637875755794113 or s ^ 1.85
		local m = 1
		if type(Mutations) == "table" and type(Mutations.EarningsFor) == "function" then
			local okM, resM = pcall(Mutations.EarningsFor,
				type(rec.Mutations) == "table" and rec.Mutations or {})
			if okM and type(resM) == "number" then m = resM end
		end
		info.Value = (tonumber(e.EarningRate) or 0) * f * m
	end
	return info
end

local function money(v)
	local u = { {1e12,"T"}, {1e9,"B"}, {1e6,"M"}, {1e3,"K"} }
	for _, x in ipairs(u) do
		if v >= x[1] then return string.format("$%.2f%s/s", v/x[1], x[2]) end
	end
	return string.format("$%d/s", math.floor(v + 0.5))
end

local status = function() end

print("[SHOUYU] Part4 OK")
local function frozenCamera()
	local cam = workspace.CurrentCamera
	if not cam then return function() end end
	local ot = cam.CameraType
	local cf = cam.CFrame
	pcall(function()
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = cf
	end)
	return function()
		pcall(function() cam.CameraType = ot end)
	end
end

local fpsGen = 0
local function fpsOn()
	if typeof(setfpscap) ~= "function" then return end
	fpsGen += 1
	local mine = fpsGen
	task.spawn(function()
		local high = true
		local s = os.clock()
		while fpsGen == mine and os.clock() - s < 60 do
			pcall(setfpscap, high and FPS[1] or FPS[2])
			high = not high
			task.wait(FPS[3])
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
		local n = workspace
		for _, name in ipairs(def[1]) do
			n = n and n:FindFirstChild(name) or nil
		end
		if n and n:IsA("BasePart") then
			return n.CFrame:PointToWorldSpace(def[2])
		end
	end
	return Vector3.new(528.7, 70.57, -364.11)
end

local function place(pos)
	local r = root()
	if not r then return end
	pcall(function()
		r.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(90), 0)
		r.AssemblyLinearVelocity = Vector3.zero
		r.AssemblyAngularVelocity = Vector3.zero
	end)
end

print("[SHOUYU] Part5 OK")
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
		local flat = Vector3.new(target.X - r.Position.X, 0, target.Z - r.Position.Z)
		local unit = flat.Magnitude > 0.01 and flat.Unit or Vector3.zero
		local speed = 3500
		local v = unit * math.min(speed, flat.Magnitude / 0.05)
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
	return state.Carrying or (r ~= nil and Vector3.new(egg.X - r.Position.X, 0, egg.Z - r.Position.Z).Magnitude <= 6)
end

local function eggNow(uid, cache)
	local node = workspace:FindFirstChild(uid)
	local slots = workspace:FindFirstChild("AreaEggSlotsClient")
	node = node or (slots and slots:FindFirstChild(uid))
	if node then
		local ok, pos = pcall(function() return node:GetPivot().Position end)
		if ok and pos then
			cache.Pos, cache.At = pos, os.clock()
			return pos
		end
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
		local dt = math.max(RunService.Heartbeat:Wait(), 1/240)
		waited += dt
		since += dt
		if r and egg then
			local delta = egg - r.Position
			if delta.Magnitude > 2 then
				local pace = math.max(walkSpeed() * CFG.SpeedCap, 16)
				local v = delta / math.max(0.08, dt)
				if v.Magnitude > pace then v = v.Unit * pace end
				pcall(function()
					r.AssemblyLinearVelocity = v + Vector3.new(0, workspace.Gravity * dt * 0.5, 0)
					r.AssemblyAngularVelocity = Vector3.zero
				end)
			end
			if since >= CFG.GrabInterval then
				since = 0
				local p = promptNear(egg - Vector3.new(0, 3, 0), 10)
				if p and typeof(fireproximityprompt) == "function" then
					pcall(function() p.HoldDuration = 0 end)
					pcall(fireproximityprompt, p)
				end
				task.spawn(takeEgg, uid)
			end
		elseif since >= CFG.GrabInterval then
			since = 0
			task.spawn(takeEgg, uid)
		end
	end
	local r = root()
	if r then pcall(function() r.AssemblyLinearVelocity = Vector3.zero end) end
	return state.Carrying and state.Uid == uid
end

print("[SHOUYU] Part6 OK")
local function regrab(uid)
	if state.Carrying then return true end
	local r = root()
	local egg = eggPosition(uid)
	if r and egg and Vector3.new(r.Position.X - egg.X, 0, r.Position.Z - egg.Z).Magnitude > CFG.RegrabFar then
		status("The egg fell far behind, teleporting onto it")
		place(egg + Vector3.new(0, 3, 0))
	else
		status("The egg fell close, taking it back")
	end
	return grab(uid, 3)
end

local function groundY(pos, fallback)
	local y = fallback
	pcall(function()
		local p = RaycastParams.new()
		p.FilterType = Enum.RaycastFilterType.Exclude
		p.FilterDescendantsInstances = { localPlayer.Character }
		p.IgnoreWater = true
		local hit = workspace:Raycast(pos + Vector3.new(0, 60, 0), Vector3.new(0, -140, 0), p)
		if hit and hit.Material ~= Enum.Material.Water
			and math.abs(hit.Position.Y - fallback) < 40 then
			y = hit.Position.Y + 3.5
		end
	end)
	return y
end

local function carrySpeed(distance)
	local ws = walkSpeed()
	local base = ws * math.min(CFG.CarryRatio, CFG.SpeedCap) * state.Mult
	local fast = base * 1.5
	local excess = 5.5 * base
	local limit = fast
	if distance and distance > excess then
		limit = math.min(fast, base * distance / (distance - excess))
	end
	return math.min(math.max(math.min(base * CFG.EasyRatio, limit), base), math.max(ws * CFG.SpeedCap, base))
end

local function runHome(lineX, laneZ)
	local started = os.clock()
	local home = homePoint()
	local checkpoint = lineX - 7
	local height = CFG.Height
	local share = math.clamp(CFG.ClimbShare, 0.1, 0.9)
	local descent = height * math.sqrt(1 - share * share) / share
	local c = localPlayer.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if h then h.PlatformStand = false end
	local r = root()
	if r and c and height > 0.5 and home.Y + height - 2 > r.Position.Y then
		pcall(function()
			c:PivotTo(CFrame.new(Vector3.new(r.Position.X, home.Y + height, r.Position.Z)) * r.CFrame.Rotation)
			r.AssemblyLinearVelocity = Vector3.zero
			r.AssemblyAngularVelocity = Vector3.zero
		end)
	end
	local start = root()
	local speed = carrySpeed(start and (Vector3.new(start.Position.X - home.X, 0, start.Position.Z - home.Z).Magnitude + math.max(0, height) * 2) or nil)
	local last = os.clock()
	local timeout = 0
	status("Safe zone")
	while state.Carrying and state.Delivered < started and not state.Cancel and timeout < 25 do
		r = root()
		if not r then return false end
		local now = os.clock()
		local dt = math.max(now - last, 1/240)
		last = now
		timeout += dt
		local toHome = r.Position.X <= checkpoint + 2
		local target = toHome and home or Vector3.new(checkpoint, home.Y, laneZ)
		if toHome and Vector3.new(home.X - r.Position.X, 0, home.Z - r.Position.Z).Magnitude < 2 then
			break
		end
		local flat = Vector3.new(target.X - r.Position.X, 0, target.Z - r.Position.Z)
		local remaining = toHome and 0 or math.max(0, r.Position.X - checkpoint)
		local wantY = home.Y + height
		if toHome or remaining <= descent then
			wantY = home.Y + height * math.clamp(remaining / math.max(descent, 1), 0, 1)
		end
		local vy = math.clamp((wantY - r.Position.Y) / 0.12, -speed * share, speed * share)
		local horizontal = math.sqrt(math.max(speed * speed - vy * vy, 0))
		local v = flat.Magnitude > 0.01 and flat.Unit * math.min(horizontal, flat.Magnitude / 0.05) or Vector3.zero
		pcall(function()
			r.AssemblyLinearVelocity = Vector3.new(v.X, vy, v.Z)
		end)
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
		local w = 0
		while state.Delivered < started and w < 1 do
			w += RunService.Heartbeat:Wait()
		end
	end
	return state.Delivered >= started
end

local function instantTP(uid)
	local started = os.clock()
	local lineX, lineY = lineInfo()
	local r = root()
	if not r then return false end
	local laneZ = math.clamp(r.Position.Z, -425, -300)
	local landing = Vector3.new(lineX + CFG.LandOffset, lineY + 3.35, laneZ)
	local hopStep = math.max(walkSpeed() * CFG.HopRatio, CFG.HopMin)
	local hopY = r.Position.Y + CFG.HopLift
	local x = r.Position.X
	local retries = 0
	local releaseCamera = frozenCamera()
	state.ReleaseCamera = releaseCamera
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
		while held < CFG.HopGap do
			place(Vector3.new(nextX, hopY, laneZ))
			held += RunService.Heartbeat:Wait()
		end
		local check = root()
		local pulled = state.PulledAt > pulledBefore
			or (check ~= nil and (check.Position.X - nextX > 10
				or check.AssemblyLinearVelocity.Magnitude > 150))
		if pulled and state.Carrying and not state.Cancel then
			retries += 1
			CFG.HopGap = math.min(CFG.HopGapMax, CFG.HopGap + 0.02)
			if retries > CFG.HopRetries then break end
			local s = 0
			while s < 0.12 and not state.Cancel do
				place(Vector3.new(x, hopY, laneZ))
				s += RunService.Heartbeat:Wait()
			end
		else
			x = nextX
			CFG.HopGap = math.max(CFG.HopGapMin, CFG.HopGap - 0.01)
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
		local s = 0
		while s < CFG.LandSettle and not state.Cancel do
			s += RunService.Heartbeat:Wait()
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
		while delay < CFG.DropDelay do
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
	if state.Carrying then
		ok = runHome(lineX, laneZ)
	end
	fpsOff()
	return ok or state.Delivered >= started
end

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
				local w = 0
				while state.Carrying and w < 1 do
					w += RunService.Heartbeat:Wait()
				end
			end
			fpsOn()
			status("Going to the egg")
			if not runToEgg(uid, egg) then
				fpsOff()
				status("Could not reach the egg")
				return
			end
			status("Taking the egg")
			if not grab(uid, 4) then
				fpsOff()
				status("The egg would not come free")
				return
			end
			local delivered = instantTP(uid)
			status(delivered and "Delivered" or "Delivery failed")
		end)
		fpsOff()
		dropClone()
		if state.ReleaseCamera then
			pcall(state.ReleaseCamera)
			state.ReleaseCamera = nil
		end
		if not ok then status("Error: " .. tostring(err)) end
		state.Busy = false
	end)
end

_G.SHOUYU_STEAL = stealAndDeliver
_G.SHOUYU_DATA = { Snapshot=snapshot, Describe=describe, Money=money, State=state }

print("[SHOUYU] Part7 OK - ロジック完成")
local function allRoots()
    local list = { game:GetService("CoreGui") }
    if typeof(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and typeof(hui) == "Instance" then table.insert(list, hui) end
    end
    local pg = localPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then table.insert(list, pg) end
    return list
end

for _, r in ipairs(allRoots()) do
    for _, c in ipairs(r:GetChildren()) do
        if c.Name == "ShouyuStealUI" then
            pcall(function() c:Destroy() end)
        end
    end
end

local gui = Instance.new("ScreenGui")
gui.Name = "ShouyuStealUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 2147483647

for _, r in ipairs(allRoots()) do
    if pcall(function() gui.Parent = r end) and gui.Parent then break end
end

local T = {
    Bg = Color3.fromRGB(13, 10, 14),
    Panel = Color3.fromRGB(24, 16, 22),
    Card = Color3.fromRGB(28, 18, 24),
    Deep = Color3.fromRGB(80, 20, 30),
    Accent = Color3.fromRGB(255, 90, 90),
    Soft = Color3.fromRGB(255, 170, 170),
    Text = Color3.fromRGB(240, 230, 235),
    Dim = Color3.fromRGB(160, 140, 150),
}

local function mk(cls, props)
    local i = Instance.new(cls)
    for k, v in pairs(props or {}) do i[k] = v end
    return i
end

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
end

local W, H = 300, 420
local win = mk("Frame", {
    Size = UDim2.fromOffset(W, H),
    Position = UDim2.new(0.5, -W/2, 0.5, -H/2),
    BackgroundColor3 = T.Bg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
})
win.Parent = gui
corner(win, 14)

mk("UIStroke", { Thickness = 2, Color = T.Accent, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }).Parent = win

local header = mk("Frame", {
    Size = UDim2.new(1, -10, 0, 52),
    Position = UDim2.fromOffset(5, 5),
    BackgroundColor3 = T.Panel,
    BorderSizePixel = 0,
})
header.Parent = win
corner(header, 10)

mk("TextLabel", {
    Size = UDim2.new(1, -100, 0, 20), Position = UDim2.fromOffset(52, 6),
    BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left, Text = "SHOUYU HUB", TextColor3 = T.Soft,
    Parent = header,
})

local minBtn = mk("TextButton", {
    Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -66, 0.5, -14),
    BackgroundColor3 = T.Deep, Font = Enum.Font.GothamBold, TextSize = 18,
    TextColor3 = T.Soft, Text = "-", AutoButtonColor = false, BorderSizePixel = 0,
})
minBtn.Parent = header
corner(minBtn, 7)

local closeBtn = mk("TextButton", {
    Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -34, 0.5, -14),
    BackgroundColor3 = T.Deep, Font = Enum.Font.GothamBold, TextSize = 16,
    TextColor3 = T.Soft, Text = "X", AutoButtonColor = false, BorderSizePixel = 0,
})
closeBtn.Parent = header
corner(closeBtn, 7)

local body = mk("Frame", {
    Size = UDim2.new(1, -10, 1, -67), Position = UDim2.fromOffset(5, 62),
    BackgroundTransparency = 1,
})
body.Parent = win

local statusL = mk("TextLabel", {
    Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(2, 0),
    BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left, Text = "Pick a pet", TextColor3 = T.Dim,
})
statusL.Parent = body

local list = mk("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, -76), Position = UDim2.fromOffset(0, 20),
    BackgroundColor3 = T.Panel, BackgroundTransparency = 0.15, BorderSizePixel = 0,
    ScrollBarThickness = 4, ScrollBarImageColor3 = T.Accent,
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
})
list.Parent = body
corner(list, 10)

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.Parent = list

local refreshBtn = mk("TextButton", {
    Size = UDim2.new(0.4, -3, 0, 38), Position = UDim2.new(0, 0, 1, -44),
    BackgroundColor3 = T.Card, Font = Enum.Font.GothamBold, TextSize = 13,
    TextColor3 = T.Text, Text = "更新", AutoButtonColor = false, BorderSizePixel = 0,
})
refreshBtn.Parent = body
corner(refreshBtn, 10)

local stealBtn = mk("TextButton", {
    Size = UDim2.new(0.6, -3, 0, 38), Position = UDim2.new(0.4, 3, 1, -44),
    BackgroundColor3 = T.Deep, Font = Enum.Font.GothamBold, TextSize = 13,
    TextColor3 = T.Text, Text = "Steal", AutoButtonColor = false, BorderSizePixel = 0,
})
stealBtn.Parent = body
corner(stealBtn, 10)

closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

_G.SHOUYU_UI = {
    Gui = gui, Win = win, Body = body, List = list,
    Status = statusL, RefreshBtn = refreshBtn, StealBtn = stealBtn,
}

print("[UI] ★★★ 起動完了 ★★★")
