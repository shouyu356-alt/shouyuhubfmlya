-- Shouyu Hub Fmly v2.0 - NeoHub Complete Edition
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

local config = {
    SpeedHack = false,
    SpeedValue = 16,
    AutoSteer = false,
    Underground = false,
    GodMode = false
}

-- メインGUI作成
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SH_NeoHub_Complete_" .. math.random(1000, 9999)
ScreenGui.Parent = player:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

-- 開閉用フロートアイコン (NeoHub風)
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

-- メインウィンドウ (NeoHubスタイル)
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 440, 0, 360)
MainFrame.Position = UDim2.new(0.5, -220, 0.5, -180)
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
TopBar.Size = UDim2.new(1, 0, 0, 36)
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

-- フッター
local Footer = Instance.new("Frame")
Footer.Size = UDim2.new(1, 0, 0, 26)
Footer.Position = UDim2.new(0, 0, 1, -26)
Footer.BackgroundColor3 = Color3.fromRGB(12, 11, 16)
Footer.BorderSizePixel = 0
Footer.Parent = MainFrame

local FooterText = Instance.new("TextLabel")
FooterText.Size = UDim2.new(1, -12, 1, 0)
FooterText.Position = UDim2.new(0, 12, 0, 0)
FooterText.BackgroundTransparency = 1
FooterText.Text = "Status: Online | Mode: Auto-Steal & Underground"
FooterText.TextColor3 = Color3.fromRGB(110, 110, 125)
FooterText.Font = Enum.Font.Code
FooterText.TextSize = 10
FooterText.TextXAlignment = Enum.TextXAlignment.Left
FooterText.Parent = Footer

-- スクロールコンテンツエリア
local ContentArea = Instance.new("ScrollingFrame")
ContentArea.Size = UDim2.new(1, -10, 1, -70)
ContentArea.Position = UDim2.new(0, 5, 0, 40)
ContentArea.BackgroundTransparency = 1
ContentArea.CanvasSize = UDim2.new(0, 0, 0, 320)
ContentArea.ScrollBarThickness = 4
ContentArea.Parent = MainFrame

-- トグルボタン生成関数
local function createToggle(text, yPos, settingKey)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.95, 0, 0, 35)
    btn.Position = UDim2.new(0.025, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(30, 27, 40)
    btn.Text = text .. " : OFF"
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.Parent = ContentArea
    
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn
    
    btn.MouseButton1Click:Connect(function()
        config[settingKey] = not config[settingKey]
        btn.Text = text .. " : " .. (config[settingKey] and "ON" or "OFF")
        btn.BackgroundColor3 = config[settingKey] and Color3.fromRGB(90, 40, 160) or Color3.fromRGB(30, 27, 40)
    end)
end

-- 各機能の配置
createToggle("スピードアップ (WalkSpeed)", 10, "SpeedHack")
createToggle("オートスティール (Auto Steal)", 52, "AutoSteer")
createToggle("地面に埋まる (Underground)", 94, "Underground")
createToggle("無敵 (God Mode)", 136, "GodMode")

-- 速度調整ボタン
local SpeedBtn = Instance.new("TextButton")
SpeedBtn.Size = UDim2.new(0.95, 0, 0, 35)
SpeedBtn.Position = UDim2.new(0.025, 0, 0, 178)
SpeedBtn.BackgroundColor3 = Color3.fromRGB(30, 27, 40)
SpeedBtn.Text = "速度調整 (現在: 16)"
SpeedBtn.TextColor3 = Color3.new(1, 1, 1)
SpeedBtn.Font = Enum.Font.GothamMedium
SpeedBtn.TextSize = 13
SpeedBtn.Parent = ContentArea

local sc = Instance.new("UICorner")
sc.CornerRadius = UDim.new(0, 6)
sc.Parent = SpeedBtn

SpeedBtn.MouseButton1Click:Connect(function()
    config.SpeedValue = config.SpeedValue + 10
    if config.SpeedValue > 100 then config.SpeedValue = 16 end
    SpeedBtn.Text = "速度調整 (現在: " .. config.SpeedValue .. ")"
end)

-- --- 機能の処理ロジック (軽量化・最適化済み) ---

RunService.RenderStepped:Connect(function()
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return end

    -- スピード調整
    if config.SpeedHack then
        humanoid.WalkSpeed = config.SpeedValue
    else
        humanoid.WalkSpeed = 16
    end

    -- 無敵 (ゴッドモード)
    if config.GodMode then
        humanoid.Health = humanoid.MaxHealth
    end

    -- 地面に埋まる (少しだけ下に座標を移動させる)
    if config.Underground then
        rootPart.CFrame = rootPart.CFrame - Vector3.new(0, 4.5, 0)
    end
end)

-- オートスティール（周囲のプレイヤーに自動接近する軽量処理）
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
                if dist < 40 and dist > 4 then
                    rootPart.CFrame = CFrame.new(targetRoot.Position + Vector3.new(0, 2, 0))
                end
            end
        end
    end
end)

-- 起動通知
StarterGui:SetCore("SendNotification", {
    Title = "NeoHub x Shouyu",
    Text = "NeoHubモデルのロードが完了しました！",
    Duration = 3
})
