-- CORPORATION DEVOURFPS - Painel atualizado e estilizado

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remove acessórios ao spawn
local function removeAllAccessoriesFromCharacter()
    local character = player.Character
    if not character then return end
    for _, item in ipairs(character:GetChildren()) do
        if item:IsA("Accessory") or item:IsA("LayeredClothing") 
        or item:IsA("Shirt") or item:IsA("ShirtGraphic") 
        or item:IsA("Pants") or item:IsA("BodyColors") 
        or item:IsA("CharacterMesh") then
            pcall(function() item:Destroy() end)
        end
    end
end
player.CharacterAdded:Connect(function() task.wait(0.2) removeAllAccessoriesFromCharacter() end)
if player.Character then task.defer(removeAllAccessoriesFromCharacter) end

-- Loop do DevourFPS
local Devour = {}
Devour.running = false
local TOOL_NAME = "Tung Bat"
local function equipBat()
    local char, bp = player.Character, player:FindFirstChild("Backpack")
    if char and bp then
        local tool = bp:FindFirstChild(TOOL_NAME)
        if tool then tool.Parent = char return true end
    end
end
local function unequipBat()
    local char, bp = player.Character, player:FindFirstChild("Backpack")
    if char and bp then
        local tool = char:FindFirstChild(TOOL_NAME)
        if tool then tool.Parent = bp return true end
    end
end
function Devour:Start()
    if self.running then return end
    self.running = true
    task.spawn(function()
        while self.running do
            equipBat()
            task.wait(0.035)
            unequipBat()
            task.wait(0.035)
        end
    end)
end
function Devour:Stop()
    self.running = false
    unequipBat()
end
player.CharacterAdded:Connect(function() Devour:Stop() end)

-- Remove painel antigo
local old = playerGui:FindFirstChild("CorporationDevourFPSPanel")
if old then old:Destroy() end

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "CorporationDevourFPSPanel"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local main = Instance.new("Frame", gui)
main.Size = UDim2.new(0, 210, 0, 100)
main.Position = UDim2.new(1, -230, 0, 15)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
main.BorderSizePixel = 0
main.Active = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)

-- Gradient no fundo
local grad = Instance.new("UIGradient", main)
grad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(20,20,60)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(90,20,120))
}
grad.Rotation = 45

-- Stroke elegante
local stroke = Instance.new("UIStroke", main)
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(255, 215, 0)
stroke.Transparency = 0.3

-- Título
local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1,0,0,30)
title.Text = "CORPORATION DEVOURFPS"
title.Font = Enum.Font.GothamBlack
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(255,215,0)
title.BackgroundTransparency = 1
title.TextStrokeTransparency = 0.5
title.TextStrokeColor3 = Color3.fromRGB(0,0,0)

-- Botão toggle
local btn = Instance.new("TextButton", main)
btn.Size = UDim2.new(0.9, 0, 0, 40)
btn.Position = UDim2.new(0.05, 0, 0, 45)
btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
btn.Text = "DevourFPS OFF"
btn.Font = Enum.Font.GothamBold
btn.TextSize = 16
btn.TextColor3 = Color3.fromRGB(255, 255, 255)
btn.BorderSizePixel = 0
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

local circle = Instance.new("ImageLabel", btn)
circle.Size = UDim2.new(0,18,0,18)
circle.Position = UDim2.new(1,-26,0.5,-9)
circle.BackgroundTransparency = 1
circle.Image = "rbxassetid://10137946418"
circle.ImageColor3 = Color3.fromRGB(255,50,50)

-- Toggle
local state = false
local function update()
    if state then
        btn.Text = "DevourFPS ON"
        btn.BackgroundColor3 = Color3.fromRGB(40,80,40)
        circle.ImageColor3 = Color3.fromRGB(50,255,60)
    else
        btn.Text = "DevourFPS OFF"
        btn.BackgroundColor3 = Color3.fromRGB(60,30,30)
        circle.ImageColor3 = Color3.fromRGB(255,50,50)
    end
end
btn.MouseButton1Click:Connect(function()
    state = not state
    if state then Devour:Start() else Devour:Stop() end
    update()
end)
update()

-- Drag
do
    local dragging, dragInput, dragStart, startPos
    main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging=false end end)
        end
    end)
    main.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                      startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end
