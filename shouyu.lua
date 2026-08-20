-- Shouyu Hub Fmly v2.0 - Brainrot Steal Dedicated Edition
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer

local config = {
    SpeedHack = false,
    SpeedValue = 120, -- このゲームで確実に機能する高速値
    AutoSteer = false, -- 自動移動＆オート盗み
    Underground = false, -- リスポーン防止（地面埋め）
    GodMode = false
}

-- 通知関数
local function notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 2
        })
    end)
end

-- メインGUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SH_BrainrotHub_" .. math.random(1000, 9999)
ScreenGui.Parent = player:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

-- 開閉用アイコン
local ToggleButtonIcon = Instance.new("TextButton")
ToggleButtonIcon.Size = UDim2.new(0, 45, 0, 45)
ToggleButtonIcon.Position = UDim2.new(0, 15, 0.4, 0)
ToggleButtonIcon.BackgroundColor3 = Color3.fromRGB(20, 18, 25)
ToggleButtonIcon.Text = "⚡"
ToggleButtonIcon.TextColor3 = Color3.fromRGB(200, 130, 255)
ToggleButtonIcon.TextSize = 22
ToggleButtonIcon.Parent = ScreenGui

local IconCorner = Instance.new("UICorner")
IconCorner.CornerRadius = UDim.new(1, 0)
IconCorner.Parent = ToggleButtonIcon

-- メインウィンドウ
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 460, 0, 280)
MainFrame.Position = UDim2.new(0.5, -230, 0.5, -140)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 14, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

ToggleButtonIcon.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

-- トップバー
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 32)
TopBar.BackgroundColor3 = Color3.fromRGB(25, 22, 35)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopBarCorner = Instance.new("UICorner")
TopBarCorner.CornerRadius = UDim.new(0, 8)
TopBarCorner.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -12, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "NEOHUB V2  |  Shouyu Hub Fmly [Brainrot Edition]"
Title.TextColor3 = Color3.fromRGB(200, 140, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

-- 左側タブメニュー
local TabMenu = Instance.new("Frame")
TabMenu.Size = UDim2.new(0, 125, 1, -32)
TabMenu.Position = UDim2.new(0, 0, 0, 32)
TabMenu.BackgroundColor3 = Color3.fromRGB(18, 16, 24)
TabMenu.BorderSizePixel = 0
TabMenu.Parent = MainFrame

-- 右側コンテンツ表示コンテナ
local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, -125, 1, -32)
Container.Position = UDim2.new(0, 125, 0, 32)
Container.BackgroundTransparency = 1
Container.Parent = MainFrame

local Tabs = {}
local function createTabContent(name)
    local scrolling = Instance.new("ScrollingFrame")
    scrolling.Size = UDim2.new(1, -10, 1, -10)
    scrolling.Position = UDim2.new(0, 5, 0, 5)
    scrolling.BackgroundTransparency = 1
    scrolling.CanvasSize = UDim2.new(0, 0, 0, 220)
    scrolling.ScrollBarThickness = 3
    scrolling.Visible = false
    scrolling.Parent = Container
    Tabs[name] = scrolling
    return scrolling
end

local tab1 = createTabContent("Main")
local tab2 = createTabContent("Misc")
local tab3 = createTabContent("Joiner")

local function createTabButton(text, yPos, targetTab)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 32)
    btn.Position = UDim2.new(0, 5, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(25, 22, 35)
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    btn.Parent = TabMenu
    
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn
    
    btn.MouseButton1Click:Connect(function()
        for _, t in pairs(Tabs) do t.Visible = false end
        targetTab.Visible = true
    end)
end

tab1.Visible = true
createTabButton("⚡ メイン機能", 10, tab1)
createTabButton("🛠️ 特殊機能", 48, tab2)
createTabButton("🔗 ジョイナー", 86, tab3)

local function createToggleInTab(parent, text, yPos, settingKey)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.95, 0, 0, 32)
    btn.Position = UDim2.new(0.025, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(30, 27, 40)
    btn.Text = text .. " : OFF"
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    btn.Parent = parent
    
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn
    
    btn.MouseButton1Click:Connect(function()
        config[settingKey] = not config[settingKey]
        local stateStr = config[settingKey] and "ON" or "OFF"
        btn.Text = text .. " : " .. stateStr
        btn.BackgroundColor3 = config[settingKey] and Color3.fromRGB(90, 40, 160) or Color3.fromRGB(30, 27, 40)
        notify("機能切替", text .. " を " .. stateStr)
    end)
end

-- --- タブ1 ---
createToggleInTab(tab1, "スピードアップ", 10, "SpeedHack")
createToggleInTab(tab1, "無敵 (God Mode)", 50, "GodMode")

local SpeedBtn = Instance.new("TextButton")
SpeedBtn.Size = UDim2.new(0.95, 0, 0, 32)
SpeedBtn.Position = UDim2.new(0.025, 0, 0, 90)
SpeedBtn.BackgroundColor3 = Color3.fromRGB(30, 27, 40)
SpeedBtn.Text = "速度調整 (現在: 120)"
SpeedBtn.TextColor3 = Color3.new(1, 1, 1)
SpeedBtn.Font = Enum.Font.GothamMedium
SpeedBtn.TextSize = 12
SpeedBtn.Parent = tab1

local sc = Instance.new("UICorner")
sc.CornerRadius = UDim.new(0, 6)
sc.Parent = SpeedBtn

SpeedBtn.MouseButton1Click:Connect(function()
    if config.SpeedValue == 120 then
        config.SpeedValue = 200
    elseif config.SpeedValue == 200 then
        config.SpeedValue = 80
    else
        config.SpeedValue = 120
    end
    SpeedBtn.Text = "速度調整 (現在: " .. config.SpeedValue .. ")"
    notify("速度変更", "速度を " .. config.SpeedValue .. " に設定")
end)

-- --- タブ2 ---
createToggleInTab(tab2, "オートスティール(自動移動)", 10, "AutoSteer")
createToggleInTab(tab2, "地面に埋まる(リスポーン防止)", 50, "Underground")

-- --- タブ3 ---
local RejoinBtn = Instance.new("TextButton")
RejoinBtn.Size = UDim2.new(0.95, 0, 0, 32)
RejoinBtn.Position = UDim2.new(0.025, 0, 0, 10)
RejoinBtn.BackgroundColor3 = Color3.fromRGB(30, 27, 40)
RejoinBtn.Text = "サーバー再参加 (Rejoin)"
RejoinBtn.TextColor3 = Color3.new(1, 1, 1)
RejoinBtn.Font = Enum.Font.GothamMedium
RejoinBtn.TextSize = 12
RejoinBtn.Parent = tab3

local rc = Instance.new("UICorner")
rc.CornerRadius = UDim.new(0, 6)
rc.Parent = RejoinBtn

RejoinBtn.MouseButton1Click:Connect(function()
    notify("再参加", "サーバーを再接続中...")
    task.wait(0.3)
    pcall(function()
        TeleportService:Teleport(game.PlaceId, player)
    end)
end)

-- --- 実行コア（Brainrot専用・常時高速化＆無敵＆地面埋め） ---
RunService.Heartbeat:Connect(function()
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return end

    -- 常時高速移動（ゲームの制限を突破するカスタム適用）
    if config.SpeedHack then
        humanoid.WalkSpeed = config.SpeedValue
        -- 移動キー入力時に物理 Velocity もブーストして確実に高速化
        if humanoid.MoveDirection.Magnitude > 0 then
            rootPart.AssemblyLinearVelocity = Vector3.new(
                humanoid.MoveDirection.X * config.SpeedValue,
                rootPart.AssemblyLinearVelocity.Y,
                humanoid.MoveDirection.Z * config.SpeedValue
            )
        end
    end

    -- 無敵維持
    if config.GodMode then
        humanoid.Health = humanoid.MaxHealth
    end

    -- リスポーン防止の地面埋め（当たり判定を下にずらす）
    if config.Underground then
        rootPart.CFrame = rootPart.CFrame - Vector3.new(0, 4.2, 0)
    end
end)

-- --- オートスティール（良いキャラ自動接近・クローン密着） ---
RunService.Stepped:Connect(function()
    if config.AutoSteer then
        local char = player.Character
        if not char then return end
        local rootPart = char:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end

        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local targetRoot = plr.Character.HumanoidRootPart
                local dist = (rootPart.Position - targetRoot.Position).Magnitude
                -- 近くにターゲットが来たら滑らかに吸い付いて盗む
                if dist < 85 and dist > 2 then
                    rootPart.CFrame = rootPart.CFrame:Lerp(targetRoot.CFrame + Vector3.new(0, 1.0, 0), 0.3)
                end
            end
        end
    end
end)

notify("Shouyu Hub", "Brainrot専用の最強動作版をロードしました！")
