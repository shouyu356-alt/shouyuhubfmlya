-- Shouyuhub - Soul & Chest Infinite Edition
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")

-- 既存UIのクリーンアップ
for _, v in pairs(pgui:GetChildren()) do
    if v.Name == "Shouyuhub_InfiniteGui" then
        v:Destroy()
    end
end

local function notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 2
        })
    end)
end

-- GUI作成
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Shouyuhub_InfiniteGui"
ScreenGui.Parent = pgui
ScreenGui.ResetOnSpawn = false

-- 開閉アイコン（💎）
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 48, 0, 48)
ToggleBtn.Position = UDim2.new(0, 15, 0.4, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 15, 30)
ToggleBtn.Text = "💎"
ToggleBtn.TextColor3 = Color3.fromRGB(150, 200, 255)
ToggleBtn.TextSize = 24
ToggleBtn.Parent = ScreenGui

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(1, 0)
ToggleCorner.Parent = ToggleBtn

-- メインフレーム
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 380, 0, 250)
MainFrame.Position = UDim2.new(0.5, -190, 0.5, -125)
MainFrame.BackgroundColor3 = Color3.fromRGB(14, 12, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

ToggleBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

-- ヘッダー
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 35)
Header.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 10)
HeaderCorner.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -20, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Shouyuhub - Soul & Chest Hack"
Title.TextColor3 = Color3.fromRGB(180, 220, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

-- ボタン生成関数
local function createButton(text, yPos, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -24, 0, 42)
    btn.Position = UDim2.new(0, 12, 0, yPos)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.Parent = MainFrame

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn

    btn.MouseButton1Click:Connect(callback)
    return btn
end

-- 1. ソウル無限（強奪）機能
createButton("🔮 ソウル強制獲得 (Soul Exploit)", 45, Color3.fromRGB(60, 30, 80), function()
    notify("Shouyuhub", "ソウル関連のリモートを探しています...")
    task.spawn(function()
        local count = 0
        for _, v in pairs(ReplicatedStorage:GetDescendants()) do
            if v:IsA("RemoteEvent") then
                local name = string.lower(v.Name)
                if string.find(name, "soul") or string.find(name, "spirit") or string.find(name, "collect") then
                    pcall(function()
                        v:FireServer(9999999)
                        v:FireServer("Soul", 9999999)
                        v:FireServer(true, 999999)
                        count = count + 1
                    end)
                end
            end
        end
        notify("Shouyuhub", count .. " 個のソウル用リモートを叩きました！")
    end)
end)

-- 2. 宝箱無限（強奪）機能
createButton("🎁 宝箱・報酬一括開封 (Chest Exploit)", 95, Color3.fromRGB(80, 50, 20), function()
    notify("Shouyuhub", "宝箱関連のリモートを探しています...")
    task.spawn(function()
        local count = 0
        for _, v in pairs(ReplicatedStorage:GetDescendants()) do
            if v:IsA("RemoteEvent") then
                local name = string.lower(v.Name)
                if string.find(name, "chest") or string.find(name, "box") or string.find(name, "reward") or string.find(name, "open") then
                    pcall(function()
                        v:FireServer("Chest", 1)
                        v:FireServer(9999, true)
                        v:FireServer("OpenAll")
                        v:FireServer(1, 2, 3, 4, 5)
                        count = count + 1
                    end)
                end
            end
        end
        notify("Shouyuhub", count .. " 個の宝箱用リモートを叩きました！")
    end)
end)

-- 3. 全部まとめて暴走させる最終手段
createButton("💥 全報酬・通貨リモート爆撃", 145, Color3.fromRGB(80, 20, 30), function()
    notify("Shouyuhub", "全サーバー通信に負荷テスト中...")
    task.spawn(function()
        local count = 0
        for _, v in pairs(ReplicatedStorage:GetDescendants()) do
            if v:IsA("RemoteEvent") then
                pcall(function()
                    v:FireServer(9999999, "Max", true)
                    count = count + 1
                end)
            end
        end
        notify("Shouyuhub", "合計 " .. count .. " 個のリモートを強制実行しました！")
    end)
end)

notify("Shouyuhub", "ソウル・宝箱ハック版をロードしました！")
