-- Shouyu Hub Fmly v1.0
-- 完全自己完結型・外部URL不要・Delta対応

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- 設定
local config = {
    SpeedHack = false,
    SpeedValue = 16,
    InfJump = false,
    Noclip = false,
    ESP = false,
    Fly = false,
    FlySpeed = 100,
    AutoFarm = false,
    WallHack = false,
    Aimbot = false,
    Teleport = false,
    GodMode = false
}

-- GUI 作成
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ShouyuHub"
ScreenGui.Parent = player:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 350, 0, 600)
MainFrame.Position = UDim2.new(0.5, -175, 0.5, -300)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 15, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 50)
Title.BackgroundColor3 = Color3.fromRGB(40, 25, 50)
Title.Text = "Shouyu Hub Fmly"
Title.TextColor3 = Color3.fromRGB(255, 150, 0)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 22
Title.Parent = MainFrame

-- トグルボタン作成関数
local function createToggle(text, yPos, settingKey)
    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Size = UDim2.new(0.9, 0, 0, 40)
    ToggleButton.Position = UDim2.new(0.05, 0, 0, yPos)
    ToggleButton.BackgroundColor3 = Color3.fromRGB(60, 45, 70)
    ToggleButton.Text = text .. ": OFF"
    ToggleButton.TextColor3 = Color3.new(1, 1, 1)
    ToggleButton.Font = Enum.Font.Gotham
    ToggleButton.TextSize = 15
    ToggleButton.Parent = MainFrame
    
    local ToggleCorner = Instance.new("UICorner")
    ToggleCorner.CornerRadius = UDim.new(0, 5)
    ToggleCorner.Parent = ToggleButton
    
    ToggleButton.MouseButton1Click:Connect(function()
        config[settingKey] = not config[settingKey]
        ToggleButton.Text = text .. ": " .. (config[settingKey] and "ON" or "OFF")
        ToggleButton.BackgroundColor3 = config[settingKey] and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(60, 45, 70)
    end)
end

-- ボタン配置
createToggle("スピードハック", 60, "SpeedHack")
createToggle("無限ジャンプ", 105, "InfJump")
createToggle("Noclip", 150, "Noclip")
createToggle("ESP", 195, "ESP")
createToggle("飛行モード", 240, "Fly")
createToggle("自動ファーム", 285, "AutoFarm")
createToggle("ウォールハック", 330, "WallHack")
createToggle("エイムボット", 375, "Aimbot")
createToggle("テレポート", 420, "Teleport")
createToggle("ゴッドモード", 465, "GodMode")

-- 速度調整
local SpeedButton = Instance.new("TextButton")
SpeedButton.Size = UDim2.new(0.9, 0, 0, 40)
SpeedButton.Position = UDim2.new(0.05, 0, 0, 510)
SpeedButton.BackgroundColor3 = Color3.fromRGB(60, 45, 70)
SpeedButton.Text = "速度: 16"
SpeedButton.TextColor3 = Color3.new(1, 1, 1)
SpeedButton.Font = Enum.Font.Gotham
SpeedButton.TextSize = 15
SpeedButton.Parent = MainFrame

local SpeedCorner = Instance.new("UICorner")
SpeedCorner.CornerRadius = UDim.new(0, 5)
SpeedCorner.Parent = SpeedButton

SpeedButton.MouseButton1Click:Connect(function()
    config.SpeedValue = config.SpeedValue + 5
    if config.SpeedValue > 200 then config.SpeedValue = 16 end
    SpeedButton.Text = "速度: " .. config.SpeedValue
end)

-- 飛行速度調整
local FlySpeedButton = Instance.new("TextButton")
FlySpeedButton.Size = UDim2.new(0.9, 0, 0, 40)
FlySpeedButton.Position = UDim2.new(0.05, 0, 0, 555)
FlySpeedButton.BackgroundColor3 = Color3.fromRGB(60, 45, 70)
FlySpeedButton.Text = "飛行速度: 100"
FlySpeedButton.TextColor3 = Color3.new(1, 1, 1)
FlySpeedButton.Font = Enum.Font.Gotham
FlySpeedButton.TextSize = 15
FlySpeedButton.Parent = MainFrame

local FlySpeedCorner = Instance.new("UICorner")
FlySpeedCorner.CornerRadius = UDim.new(0, 5)
FlySpeedCorner.Parent = FlySpeedButton

FlySpeedButton.MouseButton1Click:Connect(function()
    config.FlySpeed = config.FlySpeed + 10
    if config.FlySpeed > 300 then config.FlySpeed = 50 end
    FlySpeedButton.Text = "飛行速度: " .. config.FlySpeed
end)

-- 機能実装
local bodyVelocity = nil
local flying = false

-- スピードハック
RunService.RenderStepped:Connect(function()
    if config.SpeedHack then
        humanoid.WalkSpeed = config.SpeedValue
    else
        humanoid.WalkSpeed = 16
    end
end)

-- 無限ジャンプ
UserInputService.JumpRequest:Connect(function()
    if config.InfJump then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        task.wait(0.1)
        humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
    end
end)

-- Noclip
RunService.Stepped:Connect(function()
    if config.Noclip then
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

-- 飛行
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F and config.Fly then
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
    if flying and bodyVelocity then
        local camera = workspace.CurrentCamera
        local moveDir = Vector3.new()
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0, 1, 0) end
        
        if moveDir.Magnitude > 0 then
            moveDir = moveDir.Unit * config.FlySpeed
        end
        bodyVelocity.Velocity = moveDir
    end
end)

-- ESP
local function createESP(targetPlayer)
    local targetChar = targetPlayer.Character
    if not targetChar then return end
    local targetRoot = targetChar:WaitForChild("HumanoidRootPart")
    
    local BillboardGui = Instance.new("BillboardGui")
    BillboardGui.Size = UDim2.new(0, 100, 0, 30)
    BillboardGui.Adornee = targetRoot
    BillboardGui.AlwaysOnTop = true
    
    local TextLabel = Instance.new("TextLabel")
    TextLabel.Size = UDim2.new(1, 0, 1, 0)
    TextLabel.BackgroundTransparency = 1
    TextLabel.Text = targetPlayer.Name
    TextLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
    TextLabel.TextStrokeTransparency = 0
    TextLabel.Font = Enum.Font.GothamBold
    TextLabel.TextSize = 14
    TextLabel.Parent = BillboardGui
    
    BillboardGui.Parent = targetRoot
end

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        if config.ESP then createESP(plr) end
    end)
end)

for _, plr in pairs(Players:GetPlayers()) do
    if plr ~= player then
        plr.CharacterAdded:Connect(function()
            if config.ESP then createESP(plr) end
        end)
    end
end

-- 自動ファーム
RunService.RenderStepped:Connect(function()
    if config.AutoFarm and rootPart then
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character and plr.Character:FindFirstChild("Humanoid") then
                local targetHumanoid = plr.Character.Humanoid
                local distance = (rootPart.Position - plr.Character.HumanoidRootPart.Position).Magnitude
                if distance < 20 then
                    targetHumanoid:TakeDamage(5)
                end
            end
        end
    end
end)

-- ウォールハック
RunService.RenderStepped:Connect(function()
    if config.WallHack then
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local targetRoot = plr.Character.HumanoidRootPart
                local highlight = targetRoot:FindFirstChild("Highlight")
                if not highlight then
                    local newHighlight = Instance.new("Highlight")
                    newHighlight.FillColor = Color3.fromRGB(255, 150, 0)
                    newHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                    newHighlight.FillTransparency = 0.5
                    newHighlight.Parent = targetRoot
                end
            end
        end
    end
end)

-- エイムボット
RunService.RenderStepped:Connect(function()
    if config.Aimbot then
        local nearestPlayer = nil
        local nearestDistance = math.huge
        
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local targetRoot = plr.Character.HumanoidRootPart
                local distance = (rootPart.Position - targetRoot.Position).Magnitude
                if distance < nearestDistance then
                    nearestDistance = distance
                    nearestPlayer = plr
                end
            end
        end
        
        if nearestPlayer and nearestPlayer.Character then
            local targetRoot = nearestPlayer.Character.HumanoidRootPart
            local camera = workspace.CurrentCamera
            camera.CFrame = CFrame.new(camera.CFrame.Position, targetRoot.Position)
        end
    end
end)

-- テレポート
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.T and config.Teleport then
        local mouse = player:GetMouse()
        local target = mouse.Hit
        if target then
            rootPart.CFrame = target
        end
    end
end)

-- ゴッドモード
RunService.RenderStepped:Connect(function()
    if config.GodMode then
        humanoid.MaxHealth = math.huge
        humanoid.Health = math.huge
    else
        humanoid.MaxHealth = 100
        humanoid.Health = math.min(humanoid.Health, 100)
    end
end)

-- 通知
StarterGui:SetCore("SendNotification", {
    Title = "Shouyu Hub Fmly",
    Text = "ロード完了！Fキーで飛行 / Tキーでテレポート",
    Duration = 3
})
