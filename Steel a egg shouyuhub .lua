-- ============================================================
-- ShouyuHub | Safe Hop Auto Steal
-- Part 1/8: Config / Dependencies
-- ============================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local localPlayer       = Players.LocalPlayer

local CFG = {
	-- ホップ移動設定
	HopStep = 60,       -- 1回のワープ距離 (スタッズ)
	HopDelay = 0.3,     -- ワープ間の待機時間 (秒)
	
	-- 掴み設定
	GrabRadius = 15,
	
	-- リトライ
	MaxRetries = 3,
}

local function safeRequire(getter)
	local ok, result = pcall(function() return require(getter()) end)
	return ok and result or nil
end

local networkingFolder  = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networking")
local EggState          = safeRequire(function() return ReplicatedStorage.Client.EggState end)
local Assets            = safeRequire(function() return ReplicatedStorage.Data.Assets end)

local function remote(name) return networkingFolder:FindFirstChild(name) end
local function root() return localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") end
local function hum() return localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid") end
local statusLabel = nil
local function status(text) if statusLabel then statusLabel.Text = tostring(text) end end-- ============================================================
-- Part 2/8: State + Events
-- ============================================================
local state = {
	Carrying      = false,
	Uid           = nil,
	Busy          = false,
	Cancel        = false,
	Delivered     = 0,
	SentDropAt    = 0,
}

if type(EggState) == "table" and type(EggState.CarryChanged) == "table" then
	EggState.CarryChanged:Connect(function(arg)
		local carrying = type(arg) == "table" and arg.IsCarrying == true
		if carrying and arg.GuardDisabled == true then carrying = false end
		if carrying and type(arg.Uid) == "string" then state.Uid = arg.Uid end
		state.Carrying = carrying
	end)
end

pcall(function()
	local re = remote("RE/EggWorld/FieldEggRedeemVerdict")
	if re and re:IsA("RemoteEvent") then
		re.OnClientEvent:Connect(function()
			state.Delivered = os.clock()
		end)
	end
end)

local function takeEgg(uid)
	if type(uid) == "string" and type(EggState) == "table" and type(EggState.CarryFieldEgg) == "function" then
		pcall(EggState.CarryFieldEgg, uid)
	end
end

local function dropEgg()
	if type(EggState) == "table" and type(EggState.DropFieldEgg) == "function" then
		state.SentDropAt = os.clock()
		pcall(EggState.DropFieldEgg, "PlayerRequest")
	end
	end-- ============================================================
-- Part 3/8: Helpers
-- ============================================================
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

local function promptNear(pos, rad)
	local best, dist = nil, rad
	for _, c in ipairs(workspace:GetChildren()) do
		if c.Name == "SmartPromptPart" and c:IsA("BasePart") then
			local p = c:FindFirstChild("CarryAreaEgg")
			if p and p:IsA("ProximityPrompt") and (c.Position - pos).Magnitude < dist then
				best, dist = p, (c.Position - pos).Magnitude
			end
		end
	end
	return best
end

local function getEggPos(uid)
	local re = remote("RF/EggWorld/AskFieldEggSnapshot")
	if re and re:IsA("RemoteFunction") then
		local ok, res = pcall(re.InvokeServer, re)
		local records = ok and type(res) == "table" and res.Records or nil
		if type(records) == "table" then
			for _, r in pairs(records) do
				if r.Uid == uid and (r.State == "Slot" or r.State == "Dropped") then
					return r.BottomCFrame.Position
				end
			end
		end
	end
	return nil
		end-- ============================================================
-- Part 4/8: Hop Engine (60 studs / 0.3 sec)
-- ============================================================
local function hopTo(targetPos, checkFn)
	local r = root()
	if not r then return false end
	
	local step = CFG.HopStep
	local delay = CFG.HopDelay
	
	-- アンチチート対策：カメラ固定
	local cam = workspace.CurrentCamera
	local oldType = cam.CameraType
	pcall(function() cam.CameraType = Enum.CameraType.Scriptable; cam.CFrame = cam.CFrame end)

	while not state.Cancel do
		if checkFn and checkFn() then break end
		
		r = root()
		if not r then break end
		
		local currentPos = r.Position
		local flat = Vector3.new(targetPos.X - currentPos.X, 0, targetPos.Z - currentPos.Z)
		
		-- 目的地に十分近づいたら終了
		if flat.Magnitude <= step then
			pcall(function()
				r.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
				r.AssemblyLinearVelocity = Vector3.zero
			end)
			break
		end
		
		-- 次のワープ先を計算 (60スタッズ先)
		local dir = flat.Unit
		local nextPos = currentPos + dir * step + Vector3.new(0, 3, 0)
		
		-- ワープ実行
		pcall(function()
			r.CFrame = CFrame.new(nextPos) * r.CFrame.Rotation
			r.AssemblyLinearVelocity = Vector3.zero
			r.AssemblyAngularVelocity = Vector3.zero
		end)
		
		-- 0.3秒待機（これがアンチチートを欺く鍵）
		task.wait(delay)
		
		-- サーバーに引き戻されたかチェック
		local check = root()
		if check and (check.Position - nextPos).Magnitude > 20 then
			-- 引き戻されたら少し長めに待ってリトライ
			task.wait(0.2)
		end
	end
	
	-- カメラを戻す
	pcall(function() cam.CameraType = oldType end)
	return true
			end-- ============================================================
-- Part 5/8: Grab Logic
-- ============================================================
local function grabEgg(uid, pos)
	status("掴み中")
	
	-- 卵の真上にワープ
	local r = root()
	if r and pos then
		pcall(function()
			r.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
			r.AssemblyLinearVelocity = Vector3.zero
		end)
		task.wait(0.1)
	end
	
	-- プロンプトとモジュールを同時に叩く
	local prompt = promptNear(pos, CFG.GrabRadius)
	if prompt and typeof(fireproximityprompt) == "function" then
		pcall(function() prompt.HoldDuration = 0 end)
		task.spawn(function() pcall(fireproximityprompt, prompt) end)
	end
	task.spawn(takeEgg, uid)
	
	-- 掴めるまで待機
	local waited = 0
	while not (state.Carrying and state.Uid == uid) and waited < 1.5 and not state.Cancel do
		if math.floor(waited * 10) % 2 == 0 then
			local p = promptNear(pos, CFG.GrabRadius)
			if p and typeof(fireproximityprompt) == "function" then
				pcall(function() p.HoldDuration = 0; fireproximityprompt(p) end)
			end
			task.spawn(takeEgg, uid)
		end
		waited += RunService.Heartbeat:Wait()
	end
	
	return state.Carrying and state.Uid == uid
				end-- ============================================================
-- Part 7/8: UI
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name = "ShouyuHop"
gui.ResetOnSpawn = false
gui.Parent = localPlayer:WaitForChild("PlayerGui")

local main = Instance.new("Frame", gui)
main.Size = UDim2.fromOffset(250, 320)
main.Position = UDim2.new(0.5, -125, 0.5, -160)
main.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
main.BorderSizePixel = 0
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
local stroke = Instance.new("UIStroke", main)
stroke.Color = Color3.fromRGB(120, 220, 255)
stroke.Thickness = 1.5

local header = Instance.new("TextLabel", main)
header.Size = UDim2.new(1, 0, 0, 40)
header.BackgroundTransparency = 1
header.Text = "HOP AUTO STEAL"
header.TextColor3 = Color3.fromRGB(200, 240, 255)
header.Font = Enum.Font.GothamBlack
header.TextSize = 16

statusLabel = Instance.new("TextLabel", main)
statusLabel.Size = UDim2.new(1, -20, 0, 20)
statusLabel.Position = UDim2.fromOffset(10, 45)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "待機中"
statusLabel.TextColor3 = Color3.fromRGB(160, 190, 210)
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 12
statusLabel.TextXAlignment = Enum.TextXAlignment.Left

local list = Instance.new("ScrollingFrame", main)
list.Size = UDim2.new(1, -20, 1, -140)
list.Position = UDim2.fromOffset(10, 70)
list.BackgroundColor3 = Color3.fromRGB(25, 35, 50)
list.BorderSizePixel = 0
list.ScrollBarThickness = 4
list.ScrollBarImageColor3 = Color3.fromRGB(120, 220, 255)
Instance.new("UICorner", list).CornerRadius = UDim.new(0, 8)
local lLayout = Instance.new("UIListLayout", list)
lLayout.Padding = UDim.new(0, 4)
lLayout.SortOrder = Enum.SortOrder.LayoutOrder

local selectedUid = nil
local rows = {}

local function rebuild()
	for _, r in pairs(rows) do r:Destroy() end
	table.clear(rows)
	
	local re = remote("RF/EggWorld/AskFieldEggSnapshot")
	if not re or not re:IsA("RemoteFunction") then return end
	
	local ok, res = pcall(re.InvokeServer, re)
	local records = ok and type(res) == "table" and res.Records or {}
	
	local listArr = {}
	for _, r in pairs(records) do
		if type(r) == "table" and (r.State == "Slot" or r.State == "Dropped") then
			table.insert(listArr, r)
		end
	end
	
	for i, record in ipairs(listArr) do
		local btn = Instance.new("TextButton", list)
		btn.Size = UDim2.new(1, 0, 0, 36)
		btn.BackgroundColor3 = Color3.fromRGB(35, 50, 70)
		btn.Text = ""
		btn.LayoutOrder = i
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
		
		local name = Instance.new("TextLabel", btn)
		name.Size = UDim2.new(1, -10, 1, 0)
		name.Position = UDim2.fromOffset(10, 0)
		name.BackgroundTransparency = 1
		name.Text = tostring(record.AssetCategory)
		name.TextColor3 = Color3.fromRGB(255, 255, 255)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Font = Enum.Font.GothamBold
		
		rows[record.Uid] = btn
		
		btn.MouseButton1Click:Connect(function()
			selectedUid = record.Uid
			for uid, r in pairs(rows) do
				r.BackgroundColor3 = (uid == selectedUid) and Color3.fromRGB(40, 100, 140) or Color3.fromRGB(35, 50, 70)
			end
			status("選択中: " .. name.Text)
		end)
	end
end

local stealBtn = Instance.new("TextButton", main)
stealBtn.Size = UDim2.new(1, -20, 0, 40)
stealBtn.Position = UDim2.new(0, 10, 1, -55)
stealBtn.BackgroundColor3 = Color3.fromRGB(40, 100, 140)
stealBtn.Text = "選択した卵を盗む"
stealBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
stealBtn.Font = Enum.Font.GothamBold
stealBtn.TextSize = 14
Instance.new("UICorner", stealBtn).CornerRadius = UDim.new(0, 8)

stealBtn.MouseButton1Click:Connect(function()
	if state.Busy then
		state.Cancel = true
		status("キャンセル中...")
	elseif selectedUid then
		task.spawn(stealAndDeliver, selectedUid)
	else
		status("卵を選んでください")
	end
end)-- ============================================================
-- Part 8/8: Init
-- ============================================================
task.spawn(function()
	while gui.Parent do
		task.wait(3)
		if not state.Busy then pcall(rebuild) end
	end
end)

task.spawn(function()
	while gui.Parent do
		task.wait(0.2)
		if state.Busy then
			stealBtn.Text = "キャンセル"
			stealBtn.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
		else
			stealBtn.Text = "選択した卵を盗む"
			stealBtn.BackgroundColor3 = Color3.fromRGB(40, 100, 140)
		end
	end
end)

task.spawn(function()
	task.wait(0.5)
	pcall(rebuild)
	status("待機中")
end)

print("[ShouyuHub] Hop Auto Steal 起動完了")
