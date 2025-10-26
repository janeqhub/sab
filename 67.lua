local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ScriptVerseDesyncUnPatchedForever"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 280, 0, 140)
mainFrame.Position = UDim2.new(0.5, 0, 0.15, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -10, 0, 25)
titleLabel.Position = UDim2.new(0, 5, 0, 5)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "ScriptVerseDesyncUnPatchedForever"
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 12
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextXAlignment = Enum.TextXAlignment.Center
titleLabel.TextScaled = true
titleLabel.Parent = mainFrame

local desyncActive = false

local stateButton = Instance.new("TextButton")
stateButton.Name = "StateButton"
stateButton.Size = UDim2.new(0, 240, 0, 80)
stateButton.Position = UDim2.new(0.5, 0, 0, 50)
stateButton.AnchorPoint = Vector2.new(0.5, 0)
stateButton.BackgroundColor3 = Color3.fromRGB(150, 100, 220)
stateButton.BorderSizePixel = 0
stateButton.Font = Enum.Font.GothamBold
stateButton.TextSize = 32
stateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
stateButton.Text = "State: OFF"
stateButton.Parent = mainFrame

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 10)
buttonCorner.Parent = stateButton

local tpbutton = Instance.new("TextButton")
tpbutton.Name = "StateButton"
tpbutton.Size = UDim2.new(0, 240, 0, 80)
tpbutton.Position = UDim2.new(0.5, 0, 1, 50)
tpbutton.AnchorPoint = Vector2.new(0.5, 0)
tpbutton.BackgroundColor3 = Color3.fromRGB(150, 100, 220)
tpbutton.BorderSizePixel = 0
tpbutton.Font = Enum.Font.GothamBold
tpbutton.TextSize = 32
tpbutton.TextColor3 = Color3.fromRGB(255, 255, 255)
tpbutton.Text = "TP base: OFF"
tpbutton.Parent = mainFrame

local buttonCornera = Instance.new("UICorner")
buttonCornera.CornerRadius = UDim.new(0, 10)
buttonCornera.Parent = tpbutton

local dragging = false
local dragInput, dragStart, startPos

local function update(input)
    local delta = input.Position - dragStart
    mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

mainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)

local function enableMobileDesync()
    local success, error = pcall(function()
        local backpack = LocalPlayer:WaitForChild("Backpack")
        local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local humanoid = character:WaitForChild("Humanoid")
        
        local packages = ReplicatedStorage:WaitForChild("Packages", 5)
        if not packages then warn("❌ Packages não encontrado") return false end
        
        local netFolder = packages:WaitForChild("Net", 5)
        if not netFolder then warn("❌ Net folder não encontrado") return false end
        
        local useItemRemote = netFolder:WaitForChild("RE/UseItem", 5)
        local teleportRemote = netFolder:WaitForChild("RE/QuantumCloner/OnTeleport", 5)
        if not useItemRemote or not teleportRemote then warn("❌ Remotos não encontrados") return false end

        local toolNames = {"Quantum Cloner", "Brainrot", "brainrot"}
        local tool
        for _, toolName in ipairs(toolNames) do
            tool = backpack:FindFirstChild(toolName) or character:FindFirstChild(toolName)
            if tool then break end
        end
        if not tool then
            for _, item in ipairs(backpack:GetChildren()) do
                if item:IsA("Tool") then tool=item break end
            end
        end

        if tool and tool.Parent==backpack then
            humanoid:EquipTool(tool)
            task.wait(0.5)
        end

        if setfflag then setfflag("WorldStepMax", "-9999999999") end
        task.wait(0.2)
        useItemRemote:FireServer()
        task.wait(1)
        teleportRemote:FireServer()
        task.wait(2)
        if setfflag then setfflag("WorldStepMax", "-1") end
        print("✅ Mobile Desync ativado!")
        return true
    end)
    if not success then
        warn("❌ Erro ao ativar desync: " .. tostring(error))
        return false
    end
    return success
end

local function disableMobileDesync()
    pcall(function()
        if setfflag then setfflag("WorldStepMax", "-1") end
        print("❌ Mobile Desync desativado!")
    end)
end

stateButton.MouseButton1Click:Connect(function()
    desyncActive = not desyncActive
    
    if desyncActive then
        local success = enableMobileDesync()
        if success then
            stateButton.Text = "State: ON"
            stateButton.BackgroundColor3 = Color3.fromRGB(200, 200, 0)
        else
            desyncActive = false
            stateButton.Text = "State: OFF"
            stateButton.BackgroundColor3 = Color3.fromRGB(150, 100, 220)
        end
    else
        disableMobileDesync()
        stateButton.Text = "State: OFF"
        stateButton.BackgroundColor3 = Color3.fromRGB(150, 100, 220)
    end
end)

stateButton.MouseEnter:Connect(function()
    stateButton.BackgroundColor3 = stateButton.BackgroundColor3:Lerp(Color3.fromRGB(255, 255, 255), 0.12)
end)

stateButton.MouseLeave:Connect(function()
    if desyncActive then
        stateButton.BackgroundColor3 = Color3.fromRGB(200, 200, 0)
    else
        stateButton.BackgroundColor3 = Color3.fromRGB(150, 100, 220)
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    desyncActive = false
    stateButton.Text = "State: OFF"
    stateButton.BackgroundColor3 = Color3.fromRGB(150, 100, 220)
end)

local flyActive = false
local flyConn
local flyAtt, flyLV
local flyCharRemovingConn
local destTouchedConn
local destPartRef
local flyRestoreOldGravity, flyRestoreOldJumpPower

local FLY_SUCCESS_SOUND_ID = 'rbxassetid://144686873'
local FLY_SUCCESS_VOLUME = 1

local FLY_GRAV = 20
local FLY_JUMP = 7
local FLY_STOPDIST = 7
local FLY_XZ_SPEED = 22
local FLY_Y_BASE = -1.0
local FLY_Y_MAX = -2.2
local FLY_TIME_STEP = 1.5

local function setFlyButtonActive(state)
    if btnFlyToBase then
        btnFlyToBase.BackgroundColor3 = state and greenOn or redOff
        btnFlyToBase.Text = state and '✈️ FLYING...' or '🚀 FLY TO BASE'
    end
end

local function playFlySuccessSound()
    playSoundOptimized(FLY_SUCCESS_SOUND_ID, FLY_SUCCESS_VOLUME)
end

local function clearFlyConnections()
    if flyConn then
        pcall(function()
            flyConn:Disconnect()
        end)
        flyConn = nil
    end
    if flyCharRemovingConn then
        pcall(function()
            flyCharRemovingConn:Disconnect()
        end)
        flyCharRemovingConn = nil
    end
    if destTouchedConn then
        pcall(function()
            destTouchedConn:Disconnect()
        end)
        destTouchedConn = nil
    end
end

local function destroyFlyBodies()
    if flyLV then
        pcall(function()
            flyLV:Destroy()
        end)
        flyLV = nil
    end
    if flyAtt then
        pcall(function()
            flyAtt:Destroy()
        end)
        flyAtt = nil
    end
    destPartRef = nil
end

local function findMyDeliveryPart()
    local plots = Workspace:FindFirstChild('Plots')
    if plots then
        for _, plot in ipairs(plots:GetChildren()) do
            local sign = plot:FindFirstChild('PlotSign')
            if
                sign
                and sign:FindFirstChild('YourBase')
                and sign.YourBase.Enabled
            then
                local delivery = plot:FindFirstChild('DeliveryHitbox')
                if delivery and delivery:IsA('BasePart') then
                    return delivery
                end
            end
        end
    end
    return nil
end

local function flyGetDescent(dist)
    local maxdist = 200
    dist = math.clamp(dist, 0, maxdist)
    local t = 1 - (dist / maxdist)
    return FLY_Y_BASE + (FLY_Y_MAX - FLY_Y_BASE) * t
end

local function restoreSourceAndPhysics()
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass('Humanoid')
    if hum then
        if gravityLow then
            Workspace.Gravity = REDUCED_GRAV
            setJumpPower(BOOST_JUMP)
            enableSpeedBoostAssembly(true)
            enableInfiniteJump(true)
        else
            Workspace.Gravity = NORMAL_GRAV
            setJumpPower(NORMAL_JUMP)
            enableSpeedBoostAssembly(false)
            enableInfiniteJump(false)
        end
        spoofedGravity = NORMAL_GRAV
    else
        Workspace.Gravity = flyRestoreOldGravity or NORMAL_GRAV
        spoofedGravity = NORMAL_GRAV
        pcall(function()
            if hum and flyRestoreOldJumpPower then
                hum.JumpPower = flyRestoreOldJumpPower
            end
        end)
    end
end

local function cleanupFly()
    clearFlyConnections()
    destroyFlyBodies()
    restoreSourceAndPhysics()
    setFlyButtonActive(false)
end

local function finishFly(success)
    flyActive = false
    cleanupFly()
    if success then
        playFlySuccessSound()
        warn('Fly to Base work! 🚀')
    else
        warn('Fly to Base cancelled. ❌')
    end
end

local function startFlyToBase()
    if flyActive then
        finishFly(false)
        return
    end

    local destPart = findMyDeliveryPart()
    if not destPart then
        warn('Delivery encountered an error❌')
        return
    end

    local char = player.Character
    local hum = char and char:FindFirstChildOfClass('Humanoid')
    local hrp = char and char:FindFirstChild('HumanoidRootPart')
    if not (hum and hrp) then
        return
    end

    flyRestoreOldGravity = Workspace.Gravity
    flyRestoreOldJumpPower = hum.JumpPower

    enableSpeedBoostAssembly(false)
    enableInfiniteJump(false)

    Workspace.Gravity = FLY_GRAV
    spoofedGravity = NORMAL_GRAV
    hum.UseJumpPower = true
    hum.JumpPower = FLY_JUMP

    flyActive = true
    setFlyButtonActive(true)

    flyAtt = Instance.new('Attachment')
    flyAtt.Name = 'FlyToBaseAttachment'
    flyAtt.Parent = hrp

    flyLV = Instance.new('LinearVelocity')
    flyLV.Attachment0 = flyAtt
    flyLV.RelativeTo = Enum.ActuatorRelativeTo.World
    flyLV.MaxForce = math.huge
    flyLV.Parent = hrp

    destPartRef = destPart

    local reached = false
    local lastYUpdate = 0

    do
        local pos = hrp.Position
        local destPos = destPart.Position
        local distXZ = (Vector3.new(destPos.X, pos.Y, destPos.Z) - pos).Magnitude
        local yVel = flyGetDescent(distXZ)
        local dirXZ = Vector3.new(destPos.X - pos.X, 0, destPos.Z - pos.Z)
        if dirXZ.Magnitude > 0 then
            dirXZ = dirXZ.Unit
        else
            dirXZ = Vector3.new()
        end
        flyLV.VectorVelocity =
            Vector3.new(dirXZ.X * FLY_XZ_SPEED, yVel, dirXZ.Z * FLY_XZ_SPEED)
        lastYUpdate = tick()
    end

    destTouchedConn = destPart.Touched:Connect(function(hit)
        if not flyActive then
            return
        end
        local ch = player.Character
        if ch and hit and hit:IsDescendantOf(ch) then
            reached = true
            finishFly(true)
        end
    end)

    if flyConn then
        flyConn:Disconnect()
        flyConn = nil
    end
    flyConn = RunService.Heartbeat:Connect(function()
        if not flyActive then
            cleanupFly()
            return
        end

        if not (hrp and hrp.Parent and hum and hum.Parent) then
            finishFly(false)
            return
        end

        local pos = hrp.Position
        local destPos = destPart.Position
        local distXZ = (Vector3.new(destPos.X, pos.Y, destPos.Z) - pos).Magnitude

        if distXZ < FLY_STOPDIST and not reached then
            reached = true
            finishFly(true)
            return
        end

        if tick() - lastYUpdate >= FLY_TIME_STEP then
            local yVel = flyGetDescent(distXZ)
            local dirXZ = Vector3.new(destPos.X - pos.X, 0, destPos.Z - pos.Z)
            if dirXZ.Magnitude > 0 then
                dirXZ = dirXZ.Unit
            else
                dirXZ = Vector3.new()
            end
            flyLV.VectorVelocity = Vector3.new(
                dirXZ.X * FLY_XZ_SPEED,
                yVel,
                dirXZ.Z * FLY_XZ_SPEED
            )
            lastYUpdate = tick()
        end
    end)

    if flyCharRemovingConn then
        flyCharRemovingConn:Disconnect()
        flyCharRemovingConn = nil
    end
    flyCharRemovingConn = player.CharacterRemoving:Connect(function()
        if flyActive then
            finishFly(false)
        else
            cleanupFly()
        end
    end)
end

_G.Nameliun_StartFlyToBase = startFlyToBase

local flyY = 32 + 42 + 12 + 34 + 12

tpbutton.MouseButton1Click:Connect(function()
    startFlyToBase()
end)

