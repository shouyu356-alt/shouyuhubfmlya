-- ============================================================
-- ShouyuHub | Auto Steal (Pure Physics Build)
-- Part 1/8: Header / Config / Dependencies
-- ============================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local localPlayer       = Players.LocalPlayer

local CFG = {
	-- 移動
	SpeedToEgg      = 3000,    -- 行きの速度
	SpeedHome       = 1000,    -- 帰りの速度
	ArriveDist      = 5,       -- 到着判定の水平距離
	Decel           = 50000,   -- 減速度（オーバーシュート防止）

	-- 掴み
	GrabRadius      = 12,
	GrabRetrySec    = 1.5,

	-- タイムアウト
	StealTimeLimit  = 120,
	HomeTimeLimit   = 45,
	RagdollTimeout  = 5,

	-- リトライ
	MaxRetries      = 3,
	BlockedSec      = 30,
	
	SnapshotTTL     = 0.5,
	AutoRefresh     = 3,
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
	Danger     = Color3.fromRGB(255, 90, 90),
}

local function safeRequire(getter)
	local ok, result = pcall(function() return require(getter()) end)
	return ok and result or nil
end

local networkingFolder  = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networking")
local EggState          = safeRequire(function() return ReplicatedStorage.Client.EggState end)
local Assets            = safeRequire(function() return ReplicatedStorage.Data.Assets end)
local Mutations         = safeRequire(function() return ReplicatedStorage.Shared.Modules.Mutations end)
local AreaEggCycle      = safeRequire(function() return ReplicatedStorage.Shared.Util.AreaEggCycle end)
local AreaEggResetWall  = safeRequire(function() return ReplicatedStorage.Client.AreaEggResetWall end)
local RagdollModule     = safeRequire(function() return ReplicatedStorage.Shared.Modules.Ragdoll end)

local function remote(name) return networkingFolder:FindFirstChild(name) end
local function root()
	local c = localPlayer.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end
local function hum()
	local c = localPlayer.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local statusLabel = nil
local function status(text)
	if statusLabel then statusLabel.Text = tostring(text) end
end

print("[ShouyuHub] Part 1/8 ready")-- ============================================================
-- Part 2/8: Shield
-- ============================================================
local shield = { Original = nil, Clone = nil, Links = {}, Connection = nil, Added = nil }

local groundedStates = {
	[Enum.HumanoidStateType.Running] = true,
	[Enum.HumanoidStateType.RunningNoPhysics] = true,
	[Enum.HumanoidStateType.Landed] = true,
}
local function grounded(h)
	if not h or h.Health <= 0 or h.FloorMaterial == Enum.Material.Air then return false end
	return groundedStates[h:GetState()] == true
end

local function shieldControls(h)
	pcall(function()
		local ps = localPlayer:FindFirstChild("PlayerScripts")
		local mod = ps and ps:FindFirstChild("PlayerModule")
		if mod then
			local controls = require(mod):GetControls()
			if type(controls) == "table" then controls.humanoid = h end
		end
	end)
end

local function shieldAnimate(c)
	local animate = c and c:FindFirstChild("Animate")
	if animate and animate:IsA("LocalScript") then
		task.spawn(function()
			animate.Enabled = false
			task.wait()
			animate.Enabled = true
		end)
	end
end

local function shieldUnlink()
	for _, l in ipairs(shield.Links) do pcall(function() l:Disconnect() end) end
	table.clear(shield.Links)
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
	shieldControls(clone)
	shieldAnimate(c)
	shield.Original, shield.Clone = h, clone

	pcall(function()
		local cam = workspace.CurrentCamera
		if cam then cam.CameraSubject = clone end
	end)

	table.insert(shield.Links, h:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if clone.Parent ~= nil then clone.WalkSpeed = h.WalkSpeed end
	end))

	table.insert(shield.Links, clone.Died:Connect(function()
		shieldUnlink()
		shield.Original, shield.Clone = nil, nil
		local cur = localPlayer.Character
		if cur and h.Parent == nil then
			h.Parent = cur
			pcall(function()
				local cam = workspace.CurrentCamera
				if cam then cam.CameraSubject = h end
			end)
			shieldControls(h)
		end
		pcall(function() clone:Destroy() end)
		h.Health = 0
	end))
end

local function shieldUndo()
	shieldUnlink()
	local c = localPlayer.Character
	local orig, clone = shield.Original, shield.Clone
	shield.Original, shield.Clone = nil, nil
	if orig and clone and c and orig.Parent == nil and clone.Parent == c then
		orig.Parent = c
		pcall(function()
			local cam = workspace.CurrentCamera
			if cam then cam.CameraSubject = orig end
		end)
		shieldControls(orig)
		pcall(function() clone:Destroy() end)
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

local function walkSpeed()
	local h = hum()
	local speed = h and h.WalkSpeed or 16
	if shield.Original and shield.Original.Health > 0 then
		speed = math.min(speed, shield.Original.WalkSpeed)
	end
	return speed
end

print("[ShouyuHub] Part 2/8 ready")-- ============================================================
-- Part 3/8: State + Events
-- ============================================================
local state = {
	Carrying      = false,
	Uid           = nil,
	Mult          = 1,
	HeldSeen      = 0,
	GuessedDrop   = false,
	Delivered     = 0,
	Busy          = false,
	Cancel        = false,
	SentDropAt    = 0,
}

if type(EggState) == "table" and type(EggState.CarryChanged) == "table"
	and type(EggState.CarryChanged.Connect) == "function" then
	EggState.CarryChanged:Connect(function(arg)
		local carrying = type(arg) == "table" and arg.IsCarrying == true
		if carrying and arg.GuardDisabled == true then carrying = false end
		state.GuessedDrop = false
		if carrying then
			state.HeldSeen = os.clock()
			if type(arg.Uid) == "string" then state.Uid = arg.Uid end
			local mult = tonumber(arg.SpeedMultiplier)
			if mult and mult > 0 then state.Mult = mult end
		end
		state.Carrying = carrying
	end)
end

pcall(function()
	local re = remote("RE/EggWorld/FieldEggRedeemVerdict")
	if not re or not re:IsA("RemoteEvent") then return end
	re.OnClientEvent:Connect(function(...)
		local args = { ... }
		local uid = nil
		for _, v in ipairs(args) do
			if type(v) == "table" and type(v.Uid) == "string" then uid = v.Uid; break
			elseif type(v) == "string" and v == state.Uid then uid = v; break end
		end
		if uid ~= nil then
			if uid == state.Uid or state.Carrying == false then
				state.Delivered = os.clock()
			end
		elseif state.SentDropAt > 0 and os.clock() - state.SentDropAt < 3 then
			state.Delivered = os.clock()
		end
	end)
end)

local function takeEgg(uid)
	if type(uid) == "string" and type(EggState) == "table"
		and type(EggState.CarryFieldEgg) == "function" then
		pcall(EggState.CarryFieldEgg, uid)
	end
end

-- ★ 絶対に必要な卵落とし
local function dropEgg()
	if type(EggState) == "table" and type(EggState.DropFieldEgg) == "function" then
		state.SentDropAt = os.clock()
		local ok = pcall(EggState.DropFieldEgg, "PlayerRequest")
		if ok then return true end
	end
	local re = remote("RE/EggWorld/RequestDrop")
	if re and re:IsA("RemoteEvent") then
		state.SentDropAt = os.clock()
		pcall(function() re:FireServer("PlayerRequest") end)
		return true
	end
	return false
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
			if state.GuessedDrop and state.Uid and heldByMe(state.Uid) then
				state.GuessedDrop, state.Carrying, state.HeldSeen = false, true, os.clock()
			end
		elseif state.Uid and heldByMe(state.Uid) then
			state.HeldSeen = os.clock()
		elseif os.clock() - state.HeldSeen > 0.8 then
			state.Carrying, state.GuessedDrop = false, true
		end
	end
end)

print("[ShouyuHub] Part 3/8 ready")-- ============================================================
-- Part 4/8: Snapshot + Navigation
-- ============================================================
local function money(value)
	value = tonumber(value) or 0
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
end

local snapshotCache = { At = 0, List = {} }
local function snapshot(force)
	local now = os.clock()
	if not force and (now - snapshotCache.At) < CFG.SnapshotTTL then return snapshotCache.List end
	local list = {}
	local re = remote("RF/EggWorld/AskFieldEggSnapshot")
	if re and re:IsA("RemoteFunction") then
		local ok, result = pcall(re.InvokeServer, re)
		local records = ok and type(result) == "table" and result.Records or nil
		if type(records) == "table" then
			for _, record in pairs(records) do
				if type(record) == "table" and type(record.Uid) == "string"
					and (record.State == "Slot" or record.State == "Dropped")
					and typeof(record.BottomCFrame) == "CFrame" then
					list[#list + 1] = record
				end
			end
		end
	end
	snapshotCache.At = now
	snapshotCache.List = list
	return list
end

local function eggPosition(uid, force)
	for _, record in ipairs(snapshot(force)) do
		if record.Uid == uid then return record.BottomCFrame.Position end
	end
	return nil
end

local function describe(record)
	local directory = type(Assets) == "table" and Assets.Directory or nil
	local entry = type(directory) == "table" and directory[tostring(record.AssetCategory)] or nil
	local info = {
		Uid = record.Uid, Category = tostring(record.AssetCategory),
		Name = tostring(record.AssetCategory), Icon = "",
		Rarity = 0, Value = 0,
	}
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

print("[ShouyuHub] Part 4/8 ready")-- ============================================================
-- Part 5/8: Field + Ragdoll + Helpers
-- ============================================================
local function isNight()
	if type(AreaEggCycle) == "table" and type(AreaEggCycle.IsNightPhase) == "function" then
		local ok, res = pcall(AreaEggCycle.IsNightPhase, workspace:GetServerTimeNow())
		return ok and res == true
	end
	return false
end

local function wallSealed()
	if type(AreaEggResetWall) == "table" and type(AreaEggResetWall.IsSealed) == "function" then
		local ok, res = pcall(AreaEggResetWall.IsSealed)
		return ok and res == true
	end
	return false
end

local function fieldLocked()
	return isNight() or wallSealed()
end

local function isRagdolled()
	if type(RagdollModule) == "table" and type(RagdollModule.IsRagdolled) == "function" then
		local ok, res = pcall(RagdollModule.IsRagdolled, localPlayer.Character)
		if ok and res == true then return true end
	end
	local t = tonumber(localPlayer:GetAttribute("RagdollEndTime"))
	if t and t > workspace:GetServerTimeNow() then return true end
	local h = hum()
	if h then
		local st = h:GetState()
		if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown then
			return true
		end
	end
	return false
end

local function waitRagdollEnd(timeout)
	local started = os.clock()
	while isRagdolled() and (os.clock() - started) < (timeout or CFG.RagdollTimeout) and not state.Cancel do
		RunService.Heartbeat:Wait()
	end
	return not isRagdolled()
end

local function promptNear(position, radius)
	local best, bestDist = nil, radius
	for _, child in ipairs(workspace:GetChildren()) do
		if child.Name == "SmartPromptPart" and child:IsA("BasePart") then
			local prompt = child:FindFirstChild("CarryAreaEgg")
			if prompt and prompt:IsA("ProximityPrompt") then
				local d = (child.Position - position).Magnitude
				if d < bestDist then best, bestDist = prompt, d end
			end
		end
	end
	return best
end

print("[ShouyuHub] Part 5/8 ready")-- ============================================================
-- Part 6/8: Movement (Pure Physics Only)
-- ============================================================
local Fly = { Active = false, Target = nil, Character = nil, Arrived = false }

local function flyStop()
	Fly.Active = false
	Fly.Target, Fly.Character, Fly.Arrived = nil, nil, false
	local r = root()
	if r then pcall(function()
		r.AssemblyLinearVelocity = Vector3.new(0, r.AssemblyLinearVelocity.Y, 0)
	end) end
	local h = hum()
	if h then pcall(function() h:Move(Vector3.zero, false) end) end
end

-- 汎用物理移動（行きも帰りもこれを使う）
local function flyToGround(targetPos, speed, checkFn, timeout)
	speed = speed or 3000
	timeout = timeout or 60
	if Fly.Active then flyStop() end

	local c = localPlayer.Character
	local r = root()
	if not r or not c then return false end

	Fly.Active = true
	Fly.Target = targetPos
	Fly.Character = c
	Fly.Arrived = false
	local started = os.clock()
	local targetFlat = Vector3.new(targetPos.X, 0, targetPos.Z)
	local lastPos = r.Position
	local stuckTimer = 0
	local h = hum()

	while Fly.Active do
		local dt = RunService.Heartbeat:Wait()
		if state.Cancel then break end
		if os.clock() - started > timeout then break end
		if checkFn and checkFn() then break end

		local rp = root()
		if not rp or rp.Parent ~= c then break end
		h = hum()

		if isRagdolled() then
			if h then h:Move(Vector3.zero, false) end
			rp.AssemblyLinearVelocity = Vector3.zero
			while isRagdolled() and os.clock() - started < timeout and not state.Cancel do RunService.Heartbeat:Wait() end
			if state.Cancel or os.clock() - started > timeout then break end
			rp = root()
			if not rp then break end
			task.wait(0.1)
			dt = 1/60
		end

		local posFlat = Vector3.new(rp.Position.X, 0, rp.Position.Z)
		local diff = targetFlat - posFlat
		local dist = diff.Magnitude

		if dist <= CFG.ArriveDist then
			Fly.Arrived = true
			break
		end

		if (rp.Position - lastPos).Magnitude < 1 then
			stuckTimer += dt
			if stuckTimer > 0.5 then
				if h then pcall(function() h.Jump = true end) end
				stuckTimer = 0
			end
		else stuckTimer = 0 end
		lastPos = rp.Position

		local moveDist = diff.Magnitude
		local unit = diff.Unit
		
		-- 速度制限と減速計算
		local desiredSpeed = math.min(speed, math.sqrt(2 * CFG.Decel * moveDist))
		local v = unit * desiredSpeed

		pcall(function()
			rp.AssemblyLinearVelocity = Vector3.new(v.X, rp.AssemblyLinearVelocity.Y, v.Z)
			if h then h:Move(unit, false) end
		end)
	end

	flyStop()
	return Fly.Arrived
end

print("[ShouyuHub] Part 6/8 ready")-- ============================================================
-- Part 7/8: Actions
-- ============================================================
local function grabEggAt(uid, eggPos)
	status("掴み中")
	
	local rp = root()
	local prompt = promptNear(eggPos, CFG.GrabRadius)
	
	-- プロンプトとモジュールを同時に叩く
	if prompt and typeof(fireproximityprompt) == "function" then
		pcall(function() prompt.HoldDuration = 0 end)
		task.spawn(function() pcall(fireproximityprompt, prompt) end)
	end
	task.spawn(takeEgg, uid)

	local waited = 0
	while not (state.Carrying and state.Uid == uid) and waited < CFG.GrabRetrySec and not state.Cancel do
		-- 0.2秒ごとに再試行
		if math.floor(waited * 10) % 2 == 0 then
			local eggNow = eggPosition(uid, true)
			if not eggNow then break end
			
			-- 万が一離れていたら物理的に近づく
			if rp then
				local flat = Vector3.new(eggNow.X - rp.Position.X, 0, eggNow.Z - rp.Position.Z)
				if flat.Magnitude > 3 then
					local v = flat.Unit * math.min(50, flat.Magnitude / 0.05)
					pcall(function() rp.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z) end)
				end
			end
			
			local p = promptNear(eggNow, CFG.GrabRadius)
			if p and typeof(fireproximityprompt) == "function" then
				pcall(function() p.HoldDuration = 0; fireproximityprompt(p) end)
			end
			task.spawn(takeEgg, uid)
		end
		waited += RunService.Heartbeat:Wait()
	end
	return state.Carrying and state.Uid == uid
end

local function runToEgg(uid, egg)
	local started = os.clock()
	if fieldLocked() then
		status(isNight() and "夜: 待機" or "壁UP: 待機")
		while fieldLocked() and not state.Cancel do RunService.Heartbeat:Wait() end
	end

	for attempt = 1, CFG.MaxRetries do
		if state.Cancel then return false end
		local eggNow = eggPosition(uid, true)
		if not eggNow then return false end

		status("卵へ移動中" .. (attempt > 1 and (" (" .. attempt .. ")") or ""))
		-- 速度3000で物理移動
		local ok = flyToGround(eggNow, CFG.SpeedToEgg, function()
			return state.Cancel or os.clock() - started > CFG.StealTimeLimit
		end, CFG.StealTimeLimit)

		-- 到着したら、または近くなら掴む
		local rp = root()
		if ok or (rp and Vector3.new(eggNow.X - rp.Position.X, 0, eggNow.Z - rp.Position.Z).Magnitude <= CFG.ArriveDist + 3) then
			if grabEggAt(uid, eggNow) then return true end
		end

		if isRagdolled() then waitRagdollEnd() end
		if attempt < CFG.MaxRetries and not state.Cancel then task.wait(1) end
	end
	return false
end

-- ★ 帰還（速度1000の物理移動 ＋ 最後にDropFieldEgg）
local function runHome(deliveryStartAt)
	local r = root()
	if not r then return false end
	local home = homePoint()

	local function carryStop()
		return state.Delivered >= deliveryStartAt or state.Cancel or not state.Carrying
	end

	status("帰還中")
	-- 速度1000で家まで物理移動
	flyToGround(home, CFG.SpeedHome, carryStop, CFG.HomeTimeLimit)

	-- 着地して落ち着くのを待つ
	status("着地")
	local settle = 0
	while settle < 2 and state.Carrying and state.Delivered < deliveryStartAt and not state.Cancel do
		settle += RunService.Heartbeat:Wait()
	end

	-- ★ 絶対に卵を落とす
	if state.Carrying and state.Delivered < deliveryStartAt and not state.Cancel then
		status("納品中")
		local h = hum()
		if h then pcall(function() h.PlatformStand = false; h:Move(Vector3.zero, false) end) end
		task.wait(0.2)
		dropEgg()
		
		local waited = 0
		while state.Delivered < deliveryStartAt and waited < 1.5 do
			waited += RunService.Heartbeat:Wait()
		end
	end
	return state.Delivered >= deliveryStartAt
end

local function stealAndDeliver(uid, retry)
	if state.Busy then return false end
	state.Busy = true
	state.Cancel = false
	local attempts = retry and CFG.MaxRetries or 1

	for attempt = 1, attempts do
		if state.Cancel then break end
		local deliveryStartAt = os.clock()
		local ok, err = pcall(function()
			local egg = eggPosition(uid, true)
			if not egg then return end
			if state.Carrying and state.Uid ~= uid then
				dropEgg()
				local waited = 0
				while state.Carrying and waited < 1 do waited += RunService.Heartbeat:Wait() end
			end
			if runToEgg(uid, egg) then
				local delivered = runHome(deliveryStartAt)
				status(delivered and "納品完了" or "納品失敗")
			end
		end)
		if state.Delivered >= deliveryStartAt then break end
		if attempt < attempts and not state.Cancel then task.wait(1) end
	end
	state.Busy = false
	return true
end

local autoFilter = { MinRarity = 0, MinValue = 0 }
local blocked = {}
local autoLoop = { Active = false, Thread = nil }

local function pickBest()
	local list = snapshot(true)
	local best, bestVal = nil, -1
	local now = os.clock()
	for _, record in ipairs(list) do
		if not blocked[record.Uid] or now > blocked[record.Uid] then
			local info = describe(record)
			if (autoFilter.MinRarity <= 0 or info.Rarity >= autoFilter.MinRarity) and (autoFilter.MinValue <= 0 or info.Value >= autoFilter.MinValue) then
				if info.Value > bestVal then best, bestVal = record, info.Value end
			end
		end
	end
	return best
end

local function startAutoLoop()
	if autoLoop.Active then return end
	autoLoop.Active = true
	autoLoop.Thread = task.spawn(function()
		while autoLoop.Active and gui and gui.Parent do
			if not state.Busy then
				if fieldLocked() then
					status(isNight() and "夜: 待機" or "壁UP: 待機")
					while fieldLocked() and autoLoop.Active do RunService.Heartbeat:Wait() end
				else
					local best = pickBest()
					if best then
						local ok = stealAndDeliver(best.Uid, true)
						if not ok and not state.Cancel then blocked[best.Uid] = os.clock() + CFG.BlockedSec end
					else
						status("条件に合う卵なし")
						task.wait(0.5)
					end
				end
			end
			task.wait(0.2)
		end
		autoLoop.Active = false
	end)
end

local function stopAutoLoop()
	autoLoop.Active = false
	if autoLoop.Thread then pcall(task.cancel, autoLoop.Thread); autoLoop.Thread = nil end
end

print("[ShouyuHub] Part 7/8 ready")-- ============================================================
-- Part 8/8: UI + Init
-- ============================================================
print("[ShouyuHub] UI 構築開始")

local UI_W, UI_H, UI_H_MIN = 300, 440, 64

local gui = Instance.new("ScreenGui")
gui.Name = "ShouyuHub_LightBlue"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = localPlayer:WaitForChild("PlayerGui")

local main = Instance.new("Frame", gui)
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Size = UDim2.fromOffset(UI_W, UI_H)
main.Position = UDim2.new(0.5, 0, 0.5, 0)
main.BackgroundColor3 = THEME.Bg
main.BorderSizePixel = 0
main.Active = true
main.ClipsDescendants = true

local us = Instance.new("UIScale", main)
us.Scale = 0.9
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)
local stroke = Instance.new("UIStroke", main)
stroke.Color = THEME.Accent
stroke.Thickness = 1.5
stroke.Transparency = 0.25

local header = Instance.new("Frame", main)
header.Size = UDim2.new(1, -16, 0, 52)
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

local avFrame = Instance.new("Frame", header)
avFrame.Size = UDim2.fromOffset(36, 36)
avFrame.Position = UDim2.fromOffset(8, 8)
avFrame.BackgroundColor3 = THEME.AccentDeep
avFrame.BorderSizePixel = 0
avFrame.ZIndex = 6
Instance.new("UICorner", avFrame).CornerRadius = UDim.new(1, 0)
local avImg = Instance.new("ImageLabel", avFrame)
avImg.Size = UDim2.fromScale(0.88, 0.88)
avImg.Position = UDim2.fromScale(0.06, 0.06)
avImg.BackgroundTransparency = 1
avImg.Image = "rbxthumb://type=AvatarHeadShot&id=" .. localPlayer.UserId .. "&w=150&h=150"
avImg.ZIndex = 7
Instance.new("UICorner", avImg).CornerRadius = UDim.new(1, 0)

local title = Instance.new("TextLabel", header)
title.Size = UDim2.new(1, -140, 0, 20)
title.Position = UDim2.fromOffset(52, 6)
title.BackgroundTransparency = 1
title.Text = "SHOUYU HUB"
title.TextColor3 = THEME.AccentSoft
title.Font = Enum.Font.GothamBlack
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 6

local minBtn = Instance.new("TextButton", header)
minBtn.Size = UDim2.fromOffset(28, 28)
minBtn.Position = UDim2.new(1, -70, 0.5, -14)
minBtn.BackgroundColor3 = THEME.AccentDeep
minBtn.BorderSizePixel = 0
minBtn.Text = "−"
minBtn.TextColor3 = THEME.AccentSoft
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 18
minBtn.ZIndex = 6
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 8)

local closeBtn = Instance.new("TextButton", header)
closeBtn.Size = UDim2.fromOffset(28, 28)
closeBtn.Position = UDim2.new(1, -38, 0.5, -14)
closeBtn.BackgroundColor3 = THEME.AccentDeep
closeBtn.BorderSizePixel = 0
closeBtn.Text = "×"
closeBtn.TextColor3 = THEME.AccentSoft
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.ZIndex = 6
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

local body = Instance.new("Frame", main)
body.Size = UDim2.new(1, -16, 1, -68)
body.Position = UDim2.fromOffset(8, 68)
body.BackgroundTransparency = 1
body.ZIndex = 5

statusLabel = Instance.new("TextLabel", body)
statusLabel.Size = UDim2.new(1, -4, 0, 20)
statusLabel.Position = UDim2.fromOffset(4, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "待機中"
statusLabel.TextColor3 = THEME.TextDim
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 11
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.ZIndex = 6

local list = Instance.new("ScrollingFrame", body)
list.Size = UDim2.new(1, -4, 1, -130)
list.Position = UDim2.fromOffset(2, 24)
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
lLayout.Padding = UDim.new(0, 4)
lLayout.SortOrder = Enum.SortOrder.LayoutOrder

local RARITY_COLORS = {
	Color3.fromRGB(190, 190, 190), Color3.fromRGB(110, 210, 110),
	Color3.fromRGB(90, 160, 255), Color3.fromRGB(190, 110, 255),
	Color3.fromRGB(255, 170, 50), Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(255, 90, 200), Color3.fromRGB(80, 235, 235),
}
local function rarityColor(n)
	return RARITY_COLORS[math.clamp(tonumber(n) or 1, 1, #RARITY_COLORS)] or THEME.Text
end

local selectedUid = nil
local rows = {}

local function setSelected(uid)
	selectedUid = uid
	for rowUid, row in pairs(rows) do
		local on = rowUid == uid
		row.Stroke.Thickness = on and 2.2 or 1
		row.Stroke.Color = on and THEME.Accent or THEME.Stroke
		row.Stroke.Transparency = on and 0 or 0.6
		row.Frame.BackgroundColor3 = on and THEME.AccentDeep or THEME.Card
	end
end

local function createRow(info)
	local frame = Instance.new("TextButton", list)
	frame.Size = UDim2.new(1, 0, 0, 44)
	frame.BackgroundColor3 = THEME.Card
	frame.BorderSizePixel = 0
	frame.Text = ""
	frame.AutoButtonColor = true
	frame.LayoutOrder = info.Rarity or 0
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

	local fS = Instance.new("UIStroke", frame)
	fS.Color = THEME.Stroke
	fS.Thickness = 1
	fS.Transparency = 0.6

	local icon = Instance.new("ImageLabel", frame)
	icon.Size = UDim2.fromOffset(34, 34)
	icon.Position = UDim2.fromOffset(4, 5)
	icon.BackgroundTransparency = 1
	icon.Image = ""
	icon.ScaleType = Enum.ScaleType.Fit

	local name = Instance.new("TextLabel", frame)
	name.Size = UDim2.new(1, -46, 0, 20)
	name.Position = UDim2.fromOffset(44, 3)
	name.BackgroundTransparency = 1
	name.Text = ""
	name.TextColor3 = THEME.Text
	name.Font = Enum.Font.GothamBold
	name.TextSize = 13
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd

	local value = Instance.new("TextLabel", frame)
	value.Size = UDim2.new(1, -46, 0, 16)
	value.Position = UDim2.fromOffset(44, 23)
	value.BackgroundTransparency = 1
	value.Text = ""
	value.TextColor3 = THEME.AccentSoft
	value.Font = Enum.Font.GothamMedium
	value.TextSize = 12
	value.TextXAlignment = Enum.TextXAlignment.Left

	local row = { Frame = frame, Stroke = fS, Icon = icon, Name = name, Value = value }

	frame.MouseButton1Click:Connect(function()
		setSelected(info.Uid)
		status("選択中: " .. tostring(name.Text))
	end)

	rows[info.Uid] = row
	return row
end

local function updateRow(row, info)
	if row.Name.Text ~= info.Name then row.Name.Text = info.Name end
	local c = rarityColor(info.Rarity)
	if row.Name.TextColor3 ~= c then row.Name.TextColor3 = c end
	local moneyStr = money(info.Value)
	if row.Value.Text ~= moneyStr then row.Value.Text = moneyStr end
	if info.Icon ~= "" and row.Icon.Image ~= info.Icon then
		row.Icon.Image = info.Icon
	end
end

local function rebuild()
	local infos = {}
	local ok, records = pcall(snapshot)
	if ok and type(records) == "table" then
		for _, record in ipairs(records) do
			local okD, info = pcall(describe, record)
			if okD and info then infos[#infos + 1] = info end
		end
	end
	table.sort(infos, function(a, b) return (a.Value or 0) > (b.Value or 0) end)

	local seen = {}
	for i, info in ipairs(infos) do
		seen[info.Uid] = true
		local row = rows[info.Uid]
		if not row then row = createRow(info) end
		updateRow(row, info)
		if row.Frame.LayoutOrder ~= i then row.Frame.LayoutOrder = i end
	end

	for uid, row in pairs(rows) do
		if not seen[uid] then
			row.Frame:Destroy()
			rows[uid] = nil
		end
	end

	setSelected(selectedUid and rows[selectedUid] and selectedUid or nil)
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
	b.TextSize = 13
	b.AutoButtonColor = true
	b.ZIndex = 6
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
	local s = Instance.new("UIStroke", b)
	s.Color = THEME.Accent
	s.Thickness = 1.2
	s.Transparency = 0.4
	return b
end

local autoBtn    = mkBtn("自動盗み: OFF", UDim2.new(0, 0, 1, -144), UDim2.new(1, 0, 0, 44), THEME.Card)
local refreshBtn = mkBtn("更新",         UDim2.new(0, 0, 1, -96),  UDim2.new(0.4, -2, 0, 44), THEME.Card)
local instantBtn = mkBtn("即盗み",        UDim2.new(0.4, 2, 1, -96), UDim2.new(0.6, -2, 0, 44), THEME.AccentDeep)
local minValBtn  = mkBtn("Min価値: OFF", UDim2.new(0, 0, 1, -48),  UDim2.new(1, 0, 0, 44), THEME.Card)

autoBtn.MouseButton1Click:Connect(function()
	if autoLoop.Active then
		stopAutoLoop()
		autoBtn.Text = "自動盗み: OFF"
		autoBtn.BackgroundColor3 = THEME.Card
		status("自動盗み停止")
	else
		startAutoLoop()
		autoBtn.Text = "自動盗み: ON"
		autoBtn.BackgroundColor3 = THEME.AccentDeep
		status("自動盗み開始")
	end
end)

refreshBtn.MouseButton1Click:Connect(function()
	if not state.Busy then rebuild(); status("更新完了") end
end)

instantBtn.MouseButton1Click:Connect(function()
	if state.Busy then
		state.Cancel = true
		status("キャンセル中...")
		return
	end
	if selectedUid then
		task.spawn(function() stealAndDeliver(selectedUid, false) end)
	else
		status("卵を選んでください")
	end
end)

local valueSteps = { 0, 5e6, 5e7, 5e8, 5e9 }
local valueIdx = 1
minValBtn.MouseButton1Click:Connect(function()
	valueIdx = valueIdx % #valueSteps + 1
	autoFilter.MinValue = valueSteps[valueIdx]
	local label = autoFilter.MinValue == 0 and "OFF" or money(autoFilter.MinValue):gsub("/s", "")
	minValBtn.Text = "Min価値: " .. label
	status("Min価値: " .. label)
end)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	if minimized then
		TweenService:Create(main, TweenInfo.new(0.25), { Size = UDim2.fromOffset(UI_W, UI_H_MIN) }):Play()
		task.delay(0.12, function() body.Visible = false end)
	else
		body.Visible = true
		TweenService:Create(main, TweenInfo.new(0.25), { Size = UDim2.fromOffset(UI_W, UI_H) }):Play()
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	state.Cancel = true
	stopAutoLoop()
	shieldStop()
	gui:Destroy()
end)

local drag, dragStart, startPos = false, nil, nil
header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		drag = true
		dragStart = input.Position
		startPos = main.Position
	end
end)
header.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		drag = false
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if not drag then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement
		and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local d = input.Position - dragStart
	main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
		startPos.Y.Scale, startPos.Y.Offset + d.Y)
end)

task.spawn(function()
	while gui.Parent do
		task.wait(CFG.AutoRefresh)
		if not state.Busy then pcall(rebuild) end
	end
end)

task.spawn(function()
	while gui.Parent do
		task.wait(0.2)
		if state.Busy then
			instantBtn.Text = "キャンセル"
			instantBtn.BackgroundColor3 = THEME.Danger
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
status("待機中")
print("[ShouyuHub] 起動完了 (8/8)")
