-- Shouyu Hub Fmly v2.0 - NeoHub Style Complete Edition
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

local config = {
    SpeedHack = false,
    SpeedValue = 16,
    InfJump = false,
    Noclip = false,
    ESP = false,
    Fly = false,
    FlySpeed = 100,
    AutoSteer = false, -- オートスティール（自動略奪）
    AutoFarm = false,
    GodMode = false
}

-- メインGUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SH_NeoHub_" .. math.random(1000, 9999)
ScreenGui.Parent = player:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

-- 開閉用アイコン（NeoHub風フローティング）
local ToggleButtonIcon = Instance.new("TextButton")
ToggleButtonIcon.Size = UDim2.new(0, 45, 0, 45)
ToggleButtonIcon.Position = UDim2.new(0, 15, 0.4, 0)
ToggleButtonIcon.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
ToggleButtonIcon.Text = "⚡"
ToggleButtonIcon.TextColor3 = Color3.fromRGB(180, 100, 255)
ToggleButtonIcon.TextSize = 22
ToggleButtonIcon.Parent = ScreenGui

local IconCorner = Instance.new("UICorner")
IconCorner.CornerRadius = UDim.new(1, 0)
IconCorner.Parent = ToggleButtonIcon

-- メインウィンドウ（複数パネル風ダークテーマ）
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 500, 0, 400)
MainFrame.Position = UDim2.new(0.5, -250, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
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
TopBar.Size = UDim2.new(1, 0, 0, 38)
TopBar.BackgroundColor3 = Color3.fromRGB(25, 22, 35)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopBarCorner = Instance.new("UICorner")
TopBarCorner.CornerRadius = UDim.new(0, 8)
TopBarCorner.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0.8, 0, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "NEOHUB V2  |  Shouyu Hub Fmly [Brainrot Edition]"
Title.TextColor3 = Color3.fromRGB(200, 140, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

-- フッター
local Footer = Instance.new("Frame")
Footer.Size = UDim2.new(1, 0, 0, 28)
Footer.Position = UDim2.new(0, 0, 1, -28)
Footer.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
Footer.BorderSizePixel = 0
Footer.Parent = MainFrame

local FooterText = Instance.new("TextLabel")
FooterText.Size = UDim2.new(1, -12, 1, 0)
FooterText.Position = UDim2.new(0, 12, 0, 0)
FooterText.BackgroundTransparency = 1
FooterText.Text = "Status: Online | Target: Steal a Brainrot"
FooterText.TextColor3 = Color3.fromRGB(110, 110, 125)
FooterText.Font = Enum.Font.Code
FooterText.TextSize = 11
FooterText.TextXAlignment = Enum.TextXAlignment.Left
FooterText.Parent = Footer

-- スクロールコンテンツエリア
local ContentArea = Instance.new("ScrollingFrame")
ContentArea.Size = UDim2.new(1, -12, 1, -75)
ContentArea.Position = UDim2.new(0, 6, 0, 44)
ContentArea.BackgroundTransparency = 1
ContentArea.CanvasSize = UDim2.new(0, 0, 0, 520)
ContentArea.ScrollBarThickness = 4
ContentArea.Parent = MainFrame

-- トグルボタン生成関数
local function createToggle(text, yPos, settingKey)
    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Size = UDim2.new(0.95, 0, 0, 35)
    ToggleButton.Position = UDim2.new(0.025, 0, 0, yPos)
    ToggleButton.BackgroundColor3 = Color3.fromRGB(30, 28, 40)
    ToggleButton.Text = text .. " : OFF"
    ToggleButton.TextColor3 = Color3.new(1, 1, 1)
    ToggleButton.Font = Enum.Font.GothamMedium
    ToggleButton.TextSize = 13
    ToggleButton.Parent = ContentArea
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = ToggleButton
    
    ToggleButton.MouseButton1Click:Connect(function()
        config[settingKey] = not config[settingKey]
        ToggleButton.Text = text .. " : " .. (config[settingKey] and "ON" or "OFF")
        ToggleButton.BackgroundColor3 = config[settingKey] and Color3.fromRGB(90, 40, 160) or Color3.fromRGB(30, 28, 40)
    end)
end

-- 各機能ボタンの配置
createToggle("スピードアップ (WalkSpeed)", 10, "SpeedHack")
createToggle("オートスティール (Auto Steal)", 52, "AutoSteer")
createToggle("無限ジャンプ", 94, "InfJump")
createToggle("Noclip (壁抜け)", 136, "Noclip")
createToggle("ESP (プレイヤー透視)", 178, "ESP")
createToggle("飛行モード (Fキー)", 220, "Fly")
createToggle("自動ファーム", 262, "AutoFarm")
createToggle("ゴッドモード (無敵)", 304, "GodMode")

-- スピード数値変更ボタン
local SpeedButton = Instance.new("TextButton")
SpeedButton.Size = UDim2.new(0.95, 0, 0, 35)
SpeedButton.Position = UDim2.new(0.025, 0, 0, 350)
SpeedButton.BackgroundColor3 = Color3.fromRGB(30, 28, 40)
SpeedButton.Text = "速度切替 (現在: 16)"
SpeedButton.TextColor3 = Color3.new(1, 1, 1)
SpeedButton.Font = Enum.Font.GothamMedium
SpeedButton.TextSize = 13
SpeedButton.Parent = ContentArea

local SpeedCorner = Instance.new("UICorner")
SpeedCorner.CornerRadius = UDim.new(0, 6)
SpeedCorner.Parent = SpeedButton

SpeedButton.MouseButton1Click:Connect(function()
    config.SpeedValue = config.SpeedValue + 10
    if config.SpeedValue > 100 then config.SpeedValue = 16 end
    SpeedButton.Text = "速度切替 (現在: " .. config.SpeedValue .. ")"
end)

-- --- 各種機能の実装ロジック ---

-- スピード & ゴッドモード
RunService.RenderStepped:Connect(function()
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    if config.SpeedHack then
        humanoid.WalkSpeed = config.SpeedValue
    else
        humanoid.WalkSpeed = 16
    end

    if config.GodMode then
        humanoid.MaxHealth = math.huge
        humanoid.Health = math.huge
    end
end)

-- オートスティール（近くの他プレイヤーのベースやアイテムにテレポート/自動干渉する処理）
RunService.RenderStepped:Connect(function()
    if config.AutoSteer then
        local char = player.Character
        if not char then return end
        local rootPart = char:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end

        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local targetRoot = plr.Character.HumanoidRootPart
                local dist = (rootPart.Position - targetRoot.Position).Magnitude
                -- 近くに敵対プレイヤーがいる場合に自動で近づく・または奪う処理
                if dist < 45 and dist > 5 then
                    rootPart.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
                end
            end
        end
    end
end)

-- 無限ジャンプ
UserInputService.JumpRequest:Connect(function()
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if config.InfJump and humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- Noclip
RunService.Stepped:Connect(function()
    local char = player.Character
    if config.Noclip and char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

-- 飛行機能 (Fキー)
local bodyVelocity = nil
local flying = false
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    local char = player.Character
    if not char then return end
    local rootPart = char:FindFirstChild("HumanoidRootPart")

    if input.KeyCode == Enum.KeyCode.F and config.Fly and rootPart then
        flying = not flying
        if flying then
            bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            bodyVelocity.Parent = rootPart
        else
            if bodyVelocity then
                bodyVelocity:Destroy()
                bodyVelocity = nil
            end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    local char = player.Character
    if not char then return end
    local rootPart = char:FindFirstChild("HumanoidRootPart")

    if flying and bodyVelocity and rootPart then
        local camera = workspace.CurrentCamera
        local moveDir = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camera.CFrame.RightVector end
        if moveDir.Magnitude > 0 then moveDir = moveDir.Unit * config.FlySpeed end
        bodyVelocity.Velocity = moveDir
    end
end)

-- 通知
StarterGui:SetCore("SendNotification", {
    Title = "NeoHub x Shouyu",
    Text = "オートスティール対応版のロードが完了しました！",
    Duration = 3
})
