-- Chered Hub - Edição Completa (otimizada para mobile)
-- Integração: removido FPS Devourer, adicionado Desync Body (Anti-Hit), Source (Inf Jump / JumpBoost) e FLY TO BASE
-- Discord principal atualizado: https://discord.gg/qvVEZt3q88 
-- Data da modificação: 2025-10-10
-- Otimizações mobile: cache de descendants, pooling de sons, intervalos ajustados, debounce otimizado
-- Новое: Подсветка тела при Desync (зеленый fill, красный outline для оригинала и клона)

----------------------------------------------------------------
-- PERSISTÊNCIA (somente BEST / SECRET / BASE)
----------------------------------------------------------------
local CONFIG_DIR = 'AstroHub'
local CONFIG_FILE = CONFIG_DIR .. '/config.json'
local defaultConfig = { espBest = false, espSecret = false, espBase = false }
local currentConfig = {}
local HttpService = game:GetService('HttpService')
local function safeDecode(str)
    local ok, res = pcall(function()
        return HttpService:JSONDecode(str)
    end)
    return ok and res or nil
end
local function safeEncode(tbl)
    local ok, res = pcall(function()
        return HttpService:JSONEncode(tbl)
    end)
    return ok and res or '{}'
end
local function ensureDir()
    if isfolder and not isfolder(CONFIG_DIR) then
        pcall(function()
            makefolder(CONFIG_DIR)
        end)
    end
end
local function loadConfig()
    for k, v in pairs(defaultConfig) do
        currentConfig[k] = v
    end
    if not (isfile and readfile and isfile(CONFIG_FILE)) then
        return
    end
    local ok, data = pcall(function()
        return readfile(CONFIG_FILE)
    end)
    if ok and data and #data > 0 then
        local decoded = safeDecode(data)
        if decoded then
            for k, v in pairs(defaultConfig) do
                if decoded[k] ~= nil then
                    currentConfig[k] = decoded[k]
                end
            end
        end
    end
end
local saveDebounce = false
local function saveConfig()
    if not writefile then
        return
    end
    if saveDebounce then
        return
    end
    saveDebounce = true
    task.delay(0.35, function()
        saveDebounce = false 
    end)
    ensureDir()
    local json = safeEncode(currentConfig)
    pcall(function()
        writefile(CONFIG_FILE, json)
    end)
end

----------------------------------------------------------------
-- SERVICES
----------------------------------------------------------------
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local UserInputService = game:GetService('UserInputService')
local Workspace = game:GetService('Workspace')
local RunService = game:GetService('RunService')
local StarterGui = game:GetService('StarterGui')
local TweenService = game:GetService('TweenService')
local SoundService = game:GetService('SoundService')
local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')

----------------------------------------------------------------
-- LIMPA GUI ANTIGA
----------------------------------------------------------------
do
    local old = playerGui:FindFirstChild('NameliunHub_FULL')
    if old then
        pcall(function()
            old:Destroy()
        end)
    end
    local old3d = playerGui:FindFirstChild('Nameliun3DFloor')
    if old3d then
        pcall(function()
            old3d:Destroy()
        end)
    end
end

----------------------------------------------------------------
-- UTILITÁRIOS
----------------------------------------------------------------
local function getHumanoid()
    local c = player.Character
    return c and c:FindFirstChildOfClass('Humanoid')
end
local function getHRP()
    local c = player.Character
    return c and c:FindFirstChild('HumanoidRootPart')
end
local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore(
            'SendNotification',
            { Title = title or 'Info', Text = text or '', Duration = dur or 3 }
        )
    end)
end
local function showNotification(title, text, dur)
    notify(title, text, dur)
end

-- safe GetAttribute helper
local function safeGetAttribute(obj, name)
    if not obj then
        return nil
    end
    if obj.GetAttribute then
        local ok, res = pcall(function()
            return obj:GetAttribute(name)
        end)
        if ok then
            return res
        end
    end
    return nil
end

----------------------------------------------------------------
-- ESTADOS ESP
----------------------------------------------------------------
local espConfig = {
    enabledBest = false,
    enabledSecret = false,
    enabledBase = false,
    enabledPlayer = false,
}
local statusLabel
local espBoxes = {}

----------------------------------------------------------------
-- PARSE MONEY
----------------------------------------------------------------
local function parseMoneyPerSec(text)
    if not text then
        return 0
    end
    local mult = 1
    local numberStr = text:match('[%d%.]+')
    if not numberStr then
        return 0
    end
    if text:find('K') then
        mult = 1_000
    elseif text:find('M') then
        mult = 1_000_000
    elseif text:find('B') then
        mult = 1_000_000_000
    elseif text:find('T') then
        mult = 1_000_000_000_000
    elseif text:find('Q') then
        mult = 1_000_000_000_000_000
    end
    local number = tonumber(numberStr)
    return number and number * mult or 0
end

----------------------------------------------------------------
-- VISUAL CONSTANTES
----------------------------------------------------------------
local ESP_FONT_NAME = Enum.Font.GothamSemibold
local ESP_RED_BRIGHT = Color3.fromRGB(255, 0, 60)
local ESP_GREEN = Color3.fromRGB(0, 240, 60)

-- Intervalos otimizados para mobile
local ESP_UPDATE_INTERVAL = 1.5
local BASE_UPDATE_INTERVAL = 1.5
local GLOW_UPDATE_INTERVAL = 0.25

----------------------------------------------------------------
-- CACHE SYSTEM (otimização mobile)
----------------------------------------------------------------
local plotCache = {}
local CACHE_LIFETIME = 3

local function getCachedDescendants(obj)
    if not obj or not obj.Parent then
        return {}
    end
    local now = tick()
    local cached = plotCache[obj]
    if cached and (now - cached.time) < CACHE_LIFETIME then
        return cached.descendants
    end
    local desc = obj:GetDescendants()
    plotCache[obj] = { descendants = desc, time = now }
    return desc
end

-- Limpa cache periodicamente
task.spawn(function()
    while true do
        task.wait(10)
        local now = tick()
        for obj, data in pairs(plotCache) do
            if
                not obj
                or not obj.Parent
                or (now - data.time) > CACHE_LIFETIME
            then
                plotCache[obj] = nil
            end
        end
    end
end)

----------------------------------------------------------------
-- SOUND POOLING (otimização mobile)
----------------------------------------------------------------
local soundPool = {}
local MAX_SOUNDS = 2

local function playSoundOptimized(soundId, volume)
    pcall(function()
        -- Limpa sons inválidos
        for i = #soundPool, 1, -1 do
            if not soundPool[i] or not soundPool[i].Parent then
                table.remove(soundPool, i)
            end
        end

        -- Limita sons simultâneos
        if #soundPool >= MAX_SOUNDS then
            local oldest = table.remove(soundPool, 1)
            if oldest then
                oldest:Destroy()
            end
        end

        local s = Instance.new('Sound')
        s.SoundId = soundId
        s.Volume = volume or 1
        s.Looped = false
        s.Parent = SoundService

        table.insert(soundPool, s)

        s:Play()
        s.Ended:Connect(function()
            task.wait(0.3)
            pcall(function()
                s:Destroy()
            end)
        end)
    end)
end

----------------------------------------------------------------
-- CLEAR FUNÇÕES
----------------------------------------------------------------
local function clearAllBestSecret()
    local plotsFolder = Workspace:FindFirstChild('Plots')
    if not plotsFolder then
        return
    end
    for _, plot in ipairs(plotsFolder:GetChildren()) do
        for _, inst in ipairs(plot:GetDescendants()) do
            if
                inst:IsA('BillboardGui')
                and (inst.Name == 'Best_ESP' or inst.Name == 'Secret_ESP')
            then
                pcall(function()
                    inst:Destroy()
                end)
            end
        end
    end
end

local function clearPlayerESP()
    for plr, objs in pairs(espBoxes) do
        if objs.box then
            pcall(function()
                objs.box:Destroy()
            end)
        end
        if objs.text then
            pcall(function()
                objs.text:Destroy()
            end)
        end
    end
    espBoxes = {}
end

----------------------------------------------------------------
-- BEST / SECRET ESP (otimizado)
----------------------------------------------------------------
local function updateBestSecret()
    local plotsFolder = Workspace:FindFirstChild('Plots')
    if not plotsFolder then
        clearAllBestSecret()
        return
    end
    if not (espConfig.enabledBest or espConfig.enabledSecret) then
        clearAllBestSecret()
        return
    end

    local myPlotName
    for _, plot in ipairs(plotsFolder:GetChildren()) do
        local plotSign = plot:FindFirstChild('PlotSign')
        if
            plotSign
            and plotSign:FindFirstChild('YourBase')
            and plotSign.YourBase.Enabled
        then
            myPlotName = plot.Name
            break
        end
    end

    local bestPetInfo
    for _, plot in ipairs(plotsFolder:GetChildren()) do
        if plot.Name ~= myPlotName then
            -- Usa cache otimizado
            local descendants = getCachedDescendants(plot)
            for _, desc in ipairs(descendants) do
                if
                    desc:IsA('TextLabel')
                    and desc.Name == 'Rarity'
                    and desc.Parent
                    and desc.Parent:FindFirstChild('DisplayName')
                then
                    local parentModel = desc.Parent.Parent
                    local rarity = desc.Text
                    local displayName = desc.Parent.DisplayName.Text

                    if rarity == 'Secret' then
                        if espConfig.enabledSecret then
                            if not parentModel:FindFirstChild('Secret_ESP') then
                                local billboard = Instance.new('BillboardGui')
                                billboard.Name = 'Secret_ESP'
                                billboard.Size = UDim2.new(0, 198, 0, 60)
                                billboard.StudsOffset = Vector3.new(0, 3.3, 0)
                                billboard.AlwaysOnTop = true
                                billboard.Parent = parentModel
                                local label = Instance.new('TextLabel')
                                label.Text = displayName
                                label.Size = UDim2.new(1, 0, 1, 0)
                                label.BackgroundTransparency = 1
                                label.TextScaled = true
                                label.Font = ESP_FONT_NAME
                                label.TextColor3 = ESP_RED_BRIGHT
                                label.TextStrokeColor3 = Color3.new(0, 0, 0)
                                label.TextStrokeTransparency = 0.2
                                label.Parent = billboard
                            end
                        else
                            if parentModel:FindFirstChild('Secret_ESP') then
                                parentModel.Secret_ESP:Destroy()
                            end
                        end
                    end

                    if espConfig.enabledBest then
                        local genLabel =
                            desc.Parent:FindFirstChild('Generation')
                        if genLabel and genLabel:IsA('TextLabel') then
                            local mps = parseMoneyPerSec(genLabel.Text)
                            if not bestPetInfo or mps > bestPetInfo.mps then
                                bestPetInfo = {
                                    petName = displayName,
                                    genText = genLabel.Text,
                                    mps = mps,
                                    model = parentModel,
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    if espConfig.enabledBest then
        for _, plot in ipairs(plotsFolder:GetChildren()) do
            for _, inst in ipairs(plot:GetDescendants()) do
                if inst:IsA('BillboardGui') and inst.Name == 'Best_ESP' then
                    pcall(function()
                        inst:Destroy()
                    end)
                end
            end
        end
        if bestPetInfo and bestPetInfo.mps > 0 and bestPetInfo.model then
            local billboard = Instance.new('BillboardGui')
            billboard.Name = 'Best_ESP'
            billboard.Size = UDim2.new(0, 303, 0, 75)
            billboard.StudsOffset = Vector3.new(0, 4.84, 0)
            billboard.AlwaysOnTop = true
            billboard.Parent = bestPetInfo.model
            local nameLabel = Instance.new('TextLabel')
            nameLabel.Size = UDim2.new(1, 0, 0, 35)
            nameLabel.Position = UDim2.new(0, 0, 0, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = bestPetInfo.petName
            nameLabel.TextColor3 = ESP_RED_BRIGHT
            nameLabel.Font = ESP_FONT_NAME
            nameLabel.TextSize = 25
            nameLabel.TextStrokeTransparency = 0.07
            nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
            nameLabel.Parent = billboard
            local moneyLabel = Instance.new('TextLabel')
            moneyLabel.Size = UDim2.new(1, 0, 0, 22)
            moneyLabel.Position = UDim2.new(0, 0, 0, 35)
            moneyLabel.BackgroundTransparency = 1
            moneyLabel.Text = bestPetInfo.genText
            moneyLabel.TextColor3 = ESP_GREEN
            moneyLabel.Font = ESP_FONT_NAME
            moneyLabel.TextSize = 22
            moneyLabel.TextStrokeTransparency = 0.17
            moneyLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
            moneyLabel.Parent = billboard
        end
    end
end

----------------------------------------------------------------
-- PLAYER ESP
----------------------------------------------------------------
local function updatePlayerESP()
    if espConfig.enabledPlayer then
        for _, plr in ipairs(Players:GetPlayers()) do
            if
                plr ~= player
                and plr.Character
                and plr.Character:FindFirstChild('HumanoidRootPart')
            then
                local hrp = plr.Character.HumanoidRootPart
                if not espBoxes[plr] then
                    espBoxes[plr] = {}
                    local box = Instance.new('BoxHandleAdornment')
                    box.Size = Vector3.new(4, 6, 4)
                    box.Adornee = hrp
                    box.AlwaysOnTop = true
                    box.ZIndex = 10
                    box.Transparency = 0.5
                    box.Color3 = Color3.fromRGB(250, 0, 60)
                    box.Parent = hrp
                    espBoxes[plr].box = box

                    local billboard = Instance.new('BillboardGui')
                    billboard.Adornee = hrp
                    billboard.Size = UDim2.new(0, 200, 0, 30)
                    billboard.StudsOffset = Vector3.new(0, 4, 0)
                    billboard.AlwaysOnTop = true
                    local label = Instance.new('TextLabel', billboard)
                    label.Size = UDim2.new(1, 0, 1, 0)
                    label.BackgroundTransparency = 1
                    label.TextColor3 = Color3.fromRGB(220, 0, 60)
                    label.TextStrokeTransparency = 0
                    label.Text = plr.Name
                    label.Font = Enum.Font.GothamBold
                    label.TextSize = 18
                    espBoxes[plr].text = billboard
                    billboard.Parent = hrp
                else
                    if espBoxes[plr].box then
                        espBoxes[plr].box.Adornee = hrp
                    end
                    if espBoxes[plr].text then
                        espBoxes[plr].text.Adornee = hrp
                    end
                end
            else
                if espBoxes[plr] then
                    if espBoxes[plr].box then
                        pcall(function()
                            espBoxes[plr].box:Destroy()
                        end)
                    end
                    if espBoxes[plr].text then
                        pcall(function()
                            espBoxes[plr].text:Destroy()
                        end)
                    end
                    espBoxes[plr] = nil
                end
            end
        end
    else
        clearPlayerESP()
    end
end

Players.PlayerRemoving:Connect(function(plr)
    local objs = espBoxes[plr]
    if objs then
        if objs.box then
            pcall(function()
                objs.box:Destroy()
            end)
        end
        if objs.text then
            pcall(function()
                objs.text:Destroy()
            end)
        end
        espBoxes[plr] = nil
    end
end)

----------------------------------------------------------------
-- LOOP PRINCIPAL DE ESP
----------------------------------------------------------------
task.spawn(function()
    while true do
        task.wait(ESP_UPDATE_INTERVAL)
        if espConfig.enabledBest or espConfig.enabledSecret then
            pcall(updateBestSecret)
        end
        if espConfig.enabledPlayer then
            pcall(updatePlayerESP)
        end
    end
end)

----------------------------------------------------------------
-- CARREGA CONFIG
----------------------------------------------------------------
loadConfig()
espConfig.enabledBest = currentConfig.espBest
espConfig.enabledSecret = currentConfig.espSecret
espConfig.enabledBase = currentConfig.espBase
espConfig.enabledPlayer = false

----------------------------------------------------------------
-- AIMBOT TEIA
----------------------------------------------------------------
local WEBSLINGER_NAME = 'Web Slinger'
local function getClosestPlayerWithLowerTorso()
    local myChar = player.Character
    local myHRP = myChar and myChar:FindFirstChild('HumanoidRootPart')
    if not myHRP then
        return nil
    end
    local closest, closestDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if
            plr ~= player
            and plr.Character
            and plr.Character:FindFirstChild('LowerTorso')
        then
            local lt = plr.Character.LowerTorso
            local dist = (lt.Position - myHRP.Position).Magnitude
            if dist < closestDist then
                closest, closestDist = plr, dist
            end
        end
    end
    return closest
end
local function fireWebSlingerLowerTorso()
    local bp = player:FindFirstChildOfClass('Backpack')
    if bp and bp:FindFirstChild(WEBSLINGER_NAME) then
        player.Character.Humanoid:EquipTool(bp[WEBSLINGER_NAME])
    end
    if not player.Character:FindFirstChild(WEBSLINGER_NAME) then
        return
    end
    local remoteEvent = ReplicatedStorage:FindFirstChild('Packages')
        and ReplicatedStorage.Packages:FindFirstChild('Net')
        and ReplicatedStorage.Packages.Net:FindFirstChild('RE/UseItem')
    if not remoteEvent then
        return
    end
    local alvo = getClosestPlayerWithLowerTorso()
    if
        alvo
        and alvo.Character
        and alvo.Character:FindFirstChild('LowerTorso')
    then
        local lt = alvo.Character.LowerTorso
        remoteEvent:FireServer(lt.Position, lt)
    end
end

----------------------------------------------------------------
-- PAINEL PRINCIPAL (GUI) + TOGGLES + DRAG
----------------------------------------------------------------
local gui = Instance.new('ScreenGui')
gui.Name = 'CheredHub_FULL'
gui.ResetOnSpawn = false
gui.Parent = playerGui

local menu = Instance.new('Frame')
menu.Size = UDim2.new(0, 220, 0, 300)
menu.Position = UDim2.new(0.5, -110, 0.5, -150)
menu.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
menu.BackgroundTransparency = 0.05
menu.BorderSizePixel = 0
menu.Visible = false
menu.Name = 'VIPMenu'
menu.Parent = gui
local menuCorner = Instance.new('UICorner', menu)
menuCorner.CornerRadius = UDim.new(0, 18)
local menuStroke = Instance.new('UIStroke', menu)
menuStroke.Thickness = 2.5
menuStroke.Color = Color3.fromRGB(120, 180, 255)
menuStroke.Transparency = 0.2

-- Gradient de fundo para menu com animação sutil
local menuGradient = Instance.new('UIGradient', menu)
menuGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 15, 35)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(25, 25, 50)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 25))
}
menuGradient.Rotation = 45
task.spawn(function()
    while menu.Parent do
        task.wait(2)
        menuGradient.Rotation = menuGradient.Rotation + 5
    end
end)

-- Glow animado melhorado
task.spawn(function()
    while menu.Parent do
        task.wait(GLOW_UPDATE_INTERVAL)
        local t = math.sin(tick() * 2.5)
        menuStroke.Color = Color3.fromRGB(120 + 135 * t, 180 + 75 * t, 255)
        menuStroke.Transparency = 0.2 + 0.1 * math.abs(t)
    end
end)

local title = Instance.new('TextLabel', menu)
title.Size = UDim2.new(1, 0, 0, 32)
title.Text = '💫 ASTRO HUB 💫'
title.TextColor3 = Color3.fromRGB(120, 200, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.BackgroundTransparency = 1
title.TextStrokeTransparency = 0.7
title.TextStrokeColor3 = Color3.new(0, 0, 0)

local tiktokLabel = Instance.new('TextLabel', menu)
tiktokLabel.Size = UDim2.new(1, -20, 0, 18)
tiktokLabel.Position = UDim2.new(0, 10, 0, 32)
tiktokLabel.BackgroundTransparency = 1
tiktokLabel.Text = 'DISCORD: discord.gg/wR3rgRaDjN'
tiktokLabel.TextColor3 = Color3.fromRGB(170, 170, 170)
tiktokLabel.Font = Enum.Font.Gotham
tiktokLabel.TextSize = 13
tiktokLabel.TextXAlignment = Enum.TextXAlignment.Center

statusLabel = Instance.new('TextLabel', menu)
statusLabel.Size = UDim2.new(0.9, 0, 0, 20)
statusLabel.Position = UDim2.new(0.05, 0, 1, -25)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
statusLabel.TextSize = 13
statusLabel.Text = ''
statusLabel.TextTransparency = 1
local function showStatus(msg, color)
    if statusLabel then
        statusLabel.Text = msg
        statusLabel.TextColor3 = color or Color3.fromRGB(120, 200, 255)
        statusLabel.TextTransparency = 0
        -- Animação de fade in
        statusLabel.TextTransparency = 1
        TweenService:Create(statusLabel, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
    end
end

local espBtnY, espBtnH, espBtnW, espBtnGap = 52, 28, 0.48, 0.02

local function makePersistToggle(btn, key, onColor, offColor, label, callback)
    btn.MouseButton1Click:Connect(function()
        currentConfig[key] = not currentConfig[key]
        saveConfig()
        espConfig['enabled' .. key:sub(4):gsub('^%l', string.upper)] =
            currentConfig[key]
        btn.BackgroundColor3 = currentConfig[key] and onColor or offColor
        showStatus(label .. ' ' .. (currentConfig[key] and 'ON' or 'OFF'))
        if callback then
            callback(currentConfig[key])
        end
    end)
end

local function makeRuntimeToggle(
    btn,
    stateKey,
    onColor,
    offColor,
    label,
    callback
)
    btn.MouseButton1Click:Connect(function()
        espConfig[stateKey] = not espConfig[stateKey]
        btn.BackgroundColor3 = espConfig[stateKey] and onColor or offColor
        showStatus(label .. ' ' .. (espConfig[stateKey] and 'ON' or 'OFF'))
        if callback then
            callback(espConfig[stateKey])
        end
    end)
end

local function createButton(parent, size, pos, text, font, color, cornerRadius)
    local btn = Instance.new('TextButton', parent)
    btn.Size = size
    btn.Position = pos
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.Font = font
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.TextSize = 14
    btn.BorderSizePixel = 0
    local corner = Instance.new('UICorner', btn)
    corner.CornerRadius = UDim.new(0, cornerRadius or 12)
    local btnStroke = Instance.new('UIStroke', btn)
    btnStroke.Thickness = 1.5
    btnStroke.Color = Color3.fromRGB(120, 180, 255)
    btnStroke.Transparency = 0.4
    -- Gradient para botões com animação hover-like
    local btnGradient = Instance.new('UIGradient', btn)
    btnGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, color),
        ColorSequenceKeypoint.new(1, color:lerp(Color3.new(0,0,0), 0.4))
    }
    btnGradient.Rotation = 90
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = color:lerp(Color3.new(1,1,1), 0.1)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = color}):Play()
    end)
    return btn
end

local btnEspBest = createButton(menu, UDim2.new(espBtnW, -4, 0, espBtnH), UDim2.new(espBtnGap, 0, 0, espBtnY), '🔥 ESP BEST', Enum.Font.GothamBold, espConfig.enabledBest and Color3.fromRGB(60, 220, 120) or Color3.fromRGB(45, 45, 65), 10)
makePersistToggle(
    btnEspBest,
    'espBest',
    Color3.fromRGB(60, 220, 120),
    Color3.fromRGB(45, 45, 65),
    'ESP BEST',
    function(on)
        espConfig.enabledBest = on
        if on then
            pcall(updateBestSecret)
        else
            clearAllBestSecret()
        end
    end
)

local btnEspSecret = createButton(menu, UDim2.new(espBtnW, -4, 0, espBtnH), UDim2.new(espBtnGap * 2 + espBtnW, 4, 0, espBtnY), '💎 ESP SECRET', Enum.Font.GothamBold, espConfig.enabledSecret and Color3.fromRGB(255, 120, 120) or Color3.fromRGB(45, 45, 65), 10)
makePersistToggle(
    btnEspSecret,
    'espSecret',
    Color3.fromRGB(255, 120, 120),
    Color3.fromRGB(45, 45, 65),
    'ESP SECRET',
    function(on)
        espConfig.enabledSecret = on
        if on then
            pcall(updateBestSecret)
        else
            clearAllBestSecret()
        end
    end
)

local espBaseY, espBaseH = espBtnY + espBtnH + 10, 34
local btnEspBase = createButton(menu, UDim2.new(0.9, 0, 0, espBaseH), UDim2.new(0.05, 0, 0, espBaseY), '🏠 ESP BASE', Enum.Font.GothamBold, espConfig.enabledBase and Color3.fromRGB(120, 220, 255) or Color3.fromRGB(45, 45, 65), 12)
makePersistToggle(
    btnEspBase,
    'espBase',
    Color3.fromRGB(120, 220, 255),
    Color3.fromRGB(45, 45, 65),
    'ESP BASE',
    function(on)
        espConfig.enabledBase = on
        if on then
            if typeof(startBaseESP) == 'function' then
                pcall(startBaseESP)
            end
        else
            if typeof(stopBaseESP) == 'function' then
                pcall(stopBaseESP)
            end
        end
    end
)

local espPlayerY = espBaseY + espBaseH + 10
local btnEspPlayer = createButton(menu, UDim2.new(0.9, 0, 0, 30), UDim2.new(0.05, 0, 0, espPlayerY), '👥 ESP PLAYER', Enum.Font.GothamBold, espConfig.enabledPlayer and Color3.fromRGB(255, 170, 120) or Color3.fromRGB(45, 45, 65), 12)
makeRuntimeToggle(
    btnEspPlayer,
    'enabledPlayer',
    Color3.fromRGB(255, 170, 120),
    Color3.fromRGB(45, 45, 65),
    'ESP PLAYER',
    function(on)
        if on then
            pcall(updatePlayerESP)
        else
            clearPlayerESP()
        end
    end
)

local aimbotY = espPlayerY + 30 + 14
local btnAimbotMain = createButton(menu, UDim2.new(0.9, 0, 0, 30), UDim2.new(0.05, 0, 0, aimbotY), '🕷️ AIMBOT', Enum.Font.GothamBold, Color3.fromRGB(255, 255, 120), 12)
btnAimbotMain.MouseButton1Click:Connect(function()
    fireWebSlingerLowerTorso()
    showStatus('Aimbot working! 🕷️', Color3.fromRGB(60, 255, 60))
    local oldColor = btnAimbotMain.BackgroundColor3
    local oldText = btnAimbotMain.Text
    btnAimbotMain.BackgroundColor3 = Color3.fromRGB(60, 255, 60)
    btnAimbotMain.Text = '🕷️ activated!'
    task.wait(1)
    btnAimbotMain.Text = oldText
    btnAimbotMain.BackgroundColor3 = oldColor
end)

local btnDiscordMain = createButton(menu, UDim2.new(0.9, 0, 0, 30), UDim2.new(0.05, 0, 0, aimbotY + 30 + 12), '💬 DISCORD', Enum.Font.GothamBold, Color3.fromRGB(120, 180, 255), 12)
btnDiscordMain.MouseButton1Click:Connect(function()
    local link = 'https://discord.gg/wR3rgRaDjN' 
    local copied = false
    if typeof(setclipboard) == 'function' then
        pcall(function()
            setclipboard(link)
            copied = true
        end)
    end
    if copied then
        showStatus('Discord copied! 💬', Color3.fromRGB(120, 255, 140))
        notify('Discord', 'Link copied to clipboard.', 4)
    else
        showStatus('Abra: ' .. link, Color3.fromRGB(255, 255, 120))
        notify('Discord', link, 5)
    end
end)

do
    local bottom = (aimbotY + 30 + 12) + 30 + 18
    menu.Size = UDim2.new(0, 220, 0, bottom + 18)
end

----------------------------------------------------------------
-- PAINEL SECUNDÁRIO: Desync / Inf Jump / Fly to Base
----------------------------------------------------------------
local panel = Instance.new('Frame', gui)
panel.Name = 'ToolsPanel'
panel.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Size = UDim2.new(0, 200, 0, 280)
panel.Position = UDim2.new(0.5, 120, 0.5, -140)
panel.Visible = true
local panelCorner = Instance.new('UICorner', panel)
panelCorner.CornerRadius = UDim.new(0, 16)
local panelStroke = Instance.new('UIStroke', panel)
panelStroke.Thickness = 2.5
panelStroke.Color = Color3.fromRGB(255, 120, 180)
panelStroke.Transparency = 0.2

-- Gradient para panel com animação
local panelGradient = Instance.new('UIGradient', panel)
panelGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 15, 35)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(25, 25, 50)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 25))
}
panelGradient.Rotation = -45
task.spawn(function()
    while panel.Parent do
        task.wait(2.5)
        panelGradient.Rotation = panelGradient.Rotation - 3
    end
end)

local title2 = Instance.new('TextLabel', panel)
title2.Size = UDim2.new(1, 0, 0, 28)
title2.Text = '⚡ MENU ⚡'
title2.TextColor3 = Color3.fromRGB(255, 120, 180)
title2.Font = Enum.Font.GothamBold
title2.TextSize = 18
title2.BackgroundTransparency = 1
title2.TextStrokeTransparency = 0.7
title2.TextStrokeColor3 = Color3.new(0, 0, 0)

----------------------------------------------------------------
-- DESYNC / ANTI-HIT (otimizado) + Подсветка
----------------------------------------------------------------
local antiHitActive = false
local clonerActive = false
local desyncActive = false
local cloneListenerConn
local antiHitRunning = false

local lockdownRunning = false
local lockdownConn = nil

local invHealthConns = {}
local desyncHighlights = {}  -- Для хранения подсветок

local function safeDisconnectConn(conn)
    if conn and typeof(conn) == 'RBXScriptConnection' then
        pcall(function()
            conn:Disconnect()
        end)
    end
end

local function addDesyncHighlight(model)
    if not model or desyncHighlights[model] then return end
    local highlight = Instance.new("Highlight")
    highlight.Name = "DesyncHighlight"
    highlight.FillColor = Color3.fromRGB(0, 255, 100)  -- Зеленый fill
    highlight.OutlineColor = Color3.fromRGB(255, 50, 50)  -- Красный outline
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Parent = model
    desyncHighlights[model] = highlight
end

local function removeDesyncHighlight(model)
    local hl = desyncHighlights[model]
    if hl then
        pcall(function() hl:Destroy() end)
        desyncHighlights[model] = nil
    end
end

local function makeInvulnerable(model)
    if not model or not model.Parent then
        return
    end
    if model.SetAttribute then
        local already = safeGetAttribute(model, 'isInvul')
        if already then
            return
        end
    end
    local hum = model:FindFirstChildOfClass('Humanoid')
    if not hum then
        return
    end

    local maxHealth = 1e9
    pcall(function()
        hum.MaxHealth = maxHealth
        hum.Health = maxHealth
    end)

    if invHealthConns[model] then
        safeDisconnectConn(invHealthConns[model])
        invHealthConns[model] = nil
    end
    invHealthConns[model] = hum.HealthChanged:Connect(function()
        pcall(function()
            if hum.Health < hum.MaxHealth then
                hum.Health = hum.MaxHealth
            end
        end)
    end)

    if not model:FindFirstChildOfClass('ForceField') then
        local ff = Instance.new('ForceField')
        ff.Visible = false
        ff.Parent = model
    end

    -- Добавляем подсветку для Desync
    addDesyncHighlight(model)

    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
    end)

    pcall(function()
        if model.SetAttribute then
            model:SetAttribute('isInvul', true)
        end
    end)
end

local function removeInvulnerable(model)
    if not model then
        return
    end
    if invHealthConns[model] then
        safeDisconnectConn(invHealthConns[model])
        invHealthConns[model] = nil
    end
    for _, ff in ipairs(model:GetChildren()) do
        if ff:IsA('ForceField') then
            pcall(function()
                ff:Destroy()
            end)
        end
    end
    local hum = model:FindFirstChildOfClass('Humanoid')
    if hum then
        pcall(function()
            hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
            local safeMax = 100
            hum.MaxHealth = safeMax
            if hum.Health > safeMax then
                hum.Health = safeMax
            end
        end)
    end
    -- Удаляем подсветку
    removeDesyncHighlight(model)
    pcall(function()
        if model.SetAttribute then
            model:SetAttribute('isInvul', false)
        end
    end)
end

local function trySetFlag()
    pcall(function()
        if setfflag then
            setfflag('WorldStepMax', '-99999999999999')
        end
    end)
end
local function resetFlag()
    pcall(function()
        if setfflag then
            setfflag('WorldStepMax', '1')
        end
    end)
end

local function activateDesync()
    if desyncActive then
        return
    end
    desyncActive = true
    trySetFlag()
end
local function deactivateDesync()
    if not desyncActive then
        return
    end
    desyncActive = false
    resetFlag()
end

local function performDesyncLockdown(duration, onComplete)
    if lockdownRunning then
        if onComplete then
            pcall(onComplete)
        end
        return
    end
    lockdownRunning = true

    local char = player.Character
    if not char then
        lockdownRunning = false
        if onComplete then
            pcall(onComplete)
        end
        return
    end
    local hrp = char:FindFirstChild('HumanoidRootPart')
    local hum = char:FindFirstChildOfClass('Humanoid')
    if not hrp or not hum then
        lockdownRunning = false
        if onComplete then
            pcall(onComplete) 
        end
        return
    end

    local savedWalk = hum.WalkSpeed
    local savedJump = hum.JumpPower
    local savedUseJumpPower = hum.UseJumpPower

    hum.WalkSpeed = 0
    hum.JumpPower = 0
    hum.UseJumpPower = true
    hum.PlatformStand = true

    local fixedCFrame = hrp.CFrame

    if lockdownConn then
        lockdownConn:Disconnect()
        lockdownConn = nil
    end

    local lastCFrameTime = 0
    local CFRAME_UPDATE_INTERVAL = 0.15
    lockdownConn = RunService.Heartbeat:Connect(function()
        if
            not hrp
            or not player.Character
            or not player.Character:FindFirstChild('HumanoidRootPart')
        then
            return
        end
        local now = tick()
        pcall(function()
            hrp.Velocity = Vector3.new(0, 0, 0)
            hrp.RotVelocity = Vector3.new(0, 0, 0)
            if (now - lastCFrameTime) >= CFRAME_UPDATE_INTERVAL then
                hrp.CFrame = fixedCFrame
                lastCFrameTime = now
            end
        end)
    end)

    local overlayGui = Instance.new('ScreenGui')
    overlayGui.Name = 'NameliunDesyncOverlay'
    overlayGui.ResetOnSpawn = false
    overlayGui.Parent = playerGui

    local blackFrame = Instance.new('Frame', overlayGui)
    blackFrame.Size = UDim2.new(2, 0, 2, 0)
    blackFrame.Position = UDim2.new(-0.5, 0, -0.5, 0)
    blackFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    blackFrame.BackgroundTransparency = 0
    blackFrame.ZIndex = 9999

    local label = Instance.new('TextLabel', blackFrame)
    label.Size = UDim2.new(1, 0, 0, 120)
    label.Position = UDim2.new(0, 0, 0.45, -60)
    label.BackgroundTransparency = 1
    label.Text = '💫 Astro Hub is desyncing you... 💫'
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 36
    label.ZIndex = 10000

    local barBg = Instance.new('Frame', overlayGui)
    barBg.Size = UDim2.new(0.35, 0, 0, 8)
    barBg.Position = UDim2.new(0.325, 0, 0.55, 0)
    barBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    barBg.BorderSizePixel = 0
    barBg.ZIndex = 10000
    local barCorner = Instance.new('UICorner', barBg)
    barCorner.CornerRadius = UDim.new(0, 4)

    local barFill = Instance.new('Frame', barBg)
    barFill.Size = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    barFill.BorderSizePixel = 0
    barFill.ZIndex = 10001
    local barFillCorner = Instance.new('UICorner', barFill)
    barFillCorner.CornerRadius = UDim.new(0, 4)

    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    local tweenGoal = { Size = UDim2.new(1, 0, 1, 0) }
    local tween = TweenService:Create(barFill, tweenInfo, tweenGoal)
    tween:Play()

    task.delay(duration, function()
        if lockdownConn then
            lockdownConn:Disconnect()
            lockdownConn = nil
        end

        if hum and hum.Parent then
            pcall(function()
                hum.WalkSpeed = savedWalk or 16
                hum.JumpPower = savedJump or 50
                hum.UseJumpPower = savedUseJumpPower or true
                hum.PlatformStand = false
            end)
        end

        pcall(function()
            if overlayGui then
                overlayGui:Destroy()
            end
        end)

        playSoundOptimized('rbxassetid://3997124966', 2)

        notify('Desync', 'Desync Successful! 🛡️', 4)
        showStatus('Desync Successful! 🛡️', Color3.fromRGB(120, 255, 140))

        lockdownRunning = false
        if onComplete then
            pcall(onComplete)
        end
    end)
end

local function activateClonerDesync(callback)
    if clonerActive then
        if callback then
            callback()
        end
        return
    end
    clonerActive = true

    local Backpack = player:FindFirstChildOfClass('Backpack')
    local function equipQuantumCloner()
        if not Backpack then
            return
        end
        local tool = Backpack:FindFirstChild('Quantum Cloner')
        if tool then
            local humanoid = player.Character
                and player.Character:FindFirstChildOfClass('Humanoid')
            if humanoid then
                humanoid:EquipTool(tool)
            end
        end
    end
    equipQuantumCloner()

    local REUseItem =
        ReplicatedStorage.Packages.Net:FindFirstChild('RE/UseItem')
    if REUseItem then
        REUseItem:FireServer()
    end
    local REQuantumClonerOnTeleport =
        ReplicatedStorage.Packages.Net:FindFirstChild(
            'RE/QuantumCloner/OnTeleport'
        )
    if REQuantumClonerOnTeleport then
        REQuantumClonerOnTeleport:FireServer()
    end

    local cloneName = tostring(player.UserId) .. '_Clone'
    cloneListenerConn = Workspace.ChildAdded:Connect(function(obj)
        if obj.Name == cloneName and obj:IsA('Model') then
            pcall(function()
                makeInvulnerable(obj)
            end)
            local origChar = player.Character
            if origChar then
                pcall(function()
                    makeInvulnerable(origChar)
                end)
            end
            if cloneListenerConn then
                cloneListenerConn:Disconnect()
            end
            cloneListenerConn = nil

            performDesyncLockdown(1.6, function()
                if callback then
                    pcall(callback)
                end
            end)
        end
    end)
end

local function deactivateClonerDesync()
    if not clonerActive then
        local existingClone =
            Workspace:FindFirstChild(tostring(player.UserId) .. '_Clone')
        if existingClone then
            pcall(function()
                removeInvulnerable(existingClone)
                existingClone:Destroy()
            end)
        end
        clonerActive = false
        return
    end

    clonerActive = false

    local char = player.Character
    if char then
        removeInvulnerable(char)
    end
    local clone = Workspace:FindFirstChild(tostring(player.UserId) .. '_Clone')
    if clone then
        removeInvulnerable(clone)
        pcall(function()
            clone:Destroy()
        end)
    end

    if cloneListenerConn then
        cloneListenerConn:Disconnect()
        cloneListenerConn = nil
    end
end

local function deactivateAntiHit()
    if antiHitRunning then
        if cloneListenerConn then
            cloneListenerConn:Disconnect()
            cloneListenerConn = nil
        end
        antiHitRunning = false
    end

    deactivateClonerDesync()
    deactivateDesync()
    antiHitActive = false

    if player.Character then
        removeInvulnerable(player.Character)
    end

    local possibleClone =
        Workspace:FindFirstChild(tostring(player.UserId) .. '_Clone')
    if possibleClone then
        pcall(function()
            removeInvulnerable(possibleClone)
            possibleClone:Destroy()
        end)
    end

    -- Очищаем все подсветки
    for model, _ in pairs(desyncHighlights) do
        removeDesyncHighlight(model)
    end

    showNotification('Anti-Hit deactivated. ❌', Color3.fromRGB(255, 120, 120), 2)
    if typeof(updateDesyncButton) == 'function' then
        pcall(updateDesyncButton)
    end
end

local function executeAntiHit()
    if antiHitRunning then
        return
    end
    antiHitRunning = true

    if typeof(updateDesyncButton) == 'function' then
        pcall(updateDesyncButton)
    end

    activateDesync()
    task.wait(0.1)
    activateClonerDesync(function()
        deactivateDesync()
        antiHitRunning = false
        antiHitActive = true
        showNotification(
            'Anti-Hit activated! 🛡️',
            Color3.fromRGB(0, 255, 0),
            3
        )
        if typeof(updateDesyncButton) == 'function' then
            pcall(updateDesyncButton)
        end
    end)
end

player.CharacterAdded:Connect(function()
    task.delay(0.3, function()
        local clone =
            Workspace:FindFirstChild(tostring(player.UserId) .. '_Clone')
        if clone then
            pcall(function()
                removeInvulnerable(clone)
                clone:Destroy()
            end)
        end
    end)
end)

player.CharacterRemoving:Connect(function(ch)
    pcall(function()
        removeInvulnerable(ch)
    end)
end)

local btnDesync = createButton(panel, UDim2.new(0.88, 0, 0, 42), UDim2.new(0.06, 0, 0, 32), '🛡️ DESYNC BODY', Enum.Font.GothamBold, Color3.fromRGB(255, 120, 120), 14)

local function updateDesyncButton()
    if antiHitRunning then
        btnDesync.BackgroundColor3 = Color3.fromRGB(255, 220, 60)
        btnDesync.Text = '⏳ DESYNC ACTIVE'
    elseif antiHitActive then
        btnDesync.BackgroundColor3 = Color3.fromRGB(120, 255, 120)
        btnDesync.Text = '✅ DESYNC ON'
    else
        btnDesync.BackgroundColor3 = Color3.fromRGB(255, 120, 120)
        btnDesync.Text = '🛡️ DESYNC BODY'
    end
end

btnDesync.MouseButton1Click:Connect(function()
    if antiHitRunning then
        showStatus('Anti-Hit em execução... ⏳', Color3.fromRGB(255, 220, 60))
        return
    end
    if antiHitActive then
        deactivateAntiHit()
        updateDesyncButton()
        showStatus('DESYNC BODY OFF ❌')
    else
        executeAntiHit()
        updateDesyncButton()
        showStatus('DESYNC BODY ON 🛡️', Color3.fromRGB(120, 255, 120))
    end
end)

----------------------------------------------------------------
-- SOURCE (Inf Jump / Jump Boost / Gravity spoof)
----------------------------------------------------------------
local NORMAL_GRAV = 196.2
local REDUCED_GRAV = 40
local NORMAL_JUMP = 50
local BOOST_JUMP = 35
local BOOST_SPEED = 22

local spoofedGravity = NORMAL_GRAV
pcall(function()
    local mt = getrawmetatable(Workspace)
    if mt then
        setreadonly(mt, false)
        local oldIndex = mt.__index
        mt.__index = function(self, k)
            if k == 'Gravity' then
                return spoofedGravity
            end
            return oldIndex(self, k)
        end
        setreadonly(mt, true)
    end
end)

local gravityLow = false
local sourceActive = false

local function setJumpPower(jump)
    local h = player.Character
        and player.Character:FindFirstChildOfClass('Humanoid')
    if h then
        h.JumpPower = jump
        h.UseJumpPower = true
    end
end

local speedBoostConn
local function enableSpeedBoostAssembly(state)
    if speedBoostConn then
        speedBoostConn:Disconnect()
        speedBoostConn = nil
    end
    if state then
        speedBoostConn = RunService.Heartbeat:Connect(function()
            local char = player.Character
            if char then
                local root = char:FindFirstChild('HumanoidRootPart')
                local h = char:FindFirstChildOfClass('Humanoid')
                if root and h and h.MoveDirection.Magnitude > 0 then
                    root.Velocity = Vector3.new(
                        h.MoveDirection.X * BOOST_SPEED,
                        root.Velocity.Y,
                        h.MoveDirection.Z * BOOST_SPEED
                    )
                end
            end
        end)
    end
end

local infiniteJumpConn
local function enableInfiniteJump(state)
    if infiniteJumpConn then
        infiniteJumpConn:Disconnect()
        infiniteJumpConn = nil
    end
    if state then
        infiniteJumpConn = UserInputSpace.JumpRequest:Connect(function()
            local h = player.Character
                and player.Character:FindFirstChildOfClass('Humanoid')
            if
                h
                and gravityLow
                and h:GetState() ~= Enum.HumanoidStateType.Seated
            then
                local root = player.Character:FindFirstChild('HumanoidRootPart')
                if root then
                    root.Velocity = Vector3.new(
                        root.Velocity.X,
                        h.JumpPower,
                        root.Velocity.Z
                    )
                end
            end
        end)
    end
end

local function antiRagdoll()
    local char = player.Character
    if char then
        for _, v in pairs(char:GetDescendants()) do
            if v:IsA('BodyVelocity') or v:IsA('BodyAngularVelocity') then
                v:Destroy()
            end
        end
    end
end

local function toggleForceField()
    local char = player.Character
    if char then
        if gravityLow then
            if not char:FindFirstChildOfClass('ForceField') then
                local ff = Instance.new('ForceField', char)
                ff.Visible = false
            end
        else
            for _, ff in ipairs(char:GetChildren()) do
                if ff:IsA('ForceField') then
                    ff:Destroy()
                end
            end
        end
    end
end

local btnInfJump = createButton(panel, UDim2.new(0.88, 0, 0, 34), UDim2.new(0.06, 0, 0, 32 + 42 + 12), '🦘 INF JUMP', Enum.Font.GothamBold, Color3.fromRGB(120, 255, 120), 14)

local greenOn = Color3.fromRGB(120, 255, 120)
local redOff = Color3.fromRGB(255, 120, 120)
local function updateInfJumpButton()
    btnInfJump.BackgroundColor3 = sourceActive and greenOn or redOff
    btnInfJump.Text = sourceActive and '✅ INF JUMP ON' or '🦘 INF JUMP'
end

local function switchGravityJump()
    gravityLow = not gravityLow
    sourceActive = gravityLow
    Workspace.Gravity = gravityLow and REDUCED_GRAV or NORMAL_GRAV
    setJumpPower(gravityLow and BOOST_JUMP or NORMAL_JUMP)
    enableSpeedBoostAssembly(gravityLow)
    enableInfiniteJump(gravityLow)
    antiRagdoll()
    toggleForceField()
    spoofedGravity = NORMAL_GRAV
    updateInfJumpButton()
    showStatus(
        'Inf Jump ' .. (sourceActive and 'ON 🦘' or 'OFF'),
        sourceActive and greenOn or redOff
    )
end

btnInfJump.MouseButton1Click:Connect(function()
    switchGravityJump()
end)

----------------------------------------------------------------
-- FLY TO BASE
----------------------------------------------------------------
local btnFlyToBase
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
        showStatus('Fly to Base work! 🚀', greenOn)
    else
        showStatus('Fly to Base cancelled. ❌', Color3.fromRGB(255, 220, 120))
    end
end

local function startFlyToBase()
    if flyActive then
        finishFly(false)
        return
    end

    local destPart = findMyDeliveryPart()
    if not destPart then
        showStatus('Delivery encountered an error❌')
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

updateDesyncButton()
updateInfJumpButton()

local flyY = 32 + 42 + 12 + 34 + 12
btnFlyToBase = createButton(panel, UDim2.new(0.88, 0, 0, 34), UDim2.new(0.06, 0, 0, flyY), '🚀 FLY TO BASE', Enum.Font.GothamBold, redOff, 14)
btnFlyToBase.MouseButton1Click:Connect(function()
    startFlyToBase()
end)

----------------------------------------------------------------
-- ESP BASE (otimizado com cache)
----------------------------------------------------------------
do
    local Workspace_local = game:GetService('Workspace')

    local function clearBaseESP_repl()
        local plotsFolder = Workspace_local:FindFirstChild('Plots')
        if plotsFolder then
            for _, plot in pairs(plotsFolder:GetChildren()) do
                local descendants = getCachedDescendants(plot)
                for _, model in pairs(descendants) do
                    if typeof(model) == 'Instance' then
                        if model:FindFirstChild('Base_ESP') then
                            pcall(function()
                                model.Base_ESP:Destroy()
                            end)
                        end
                    end
                end
            end
        end
    end

    local function updateESPBase()
        local plotsFolder = Workspace_local:FindFirstChild('Plots')
        if not plotsFolder then
            return
        end

        local myPlotName
        for _, plot in pairs(plotsFolder:GetChildren()) do
            local plotSign = plot:FindFirstChild('PlotSign')
            if
                plotSign
                and plotSign:FindFirstChild('YourBase')
                and plotSign.YourBase.Enabled
            then
                myPlotName = plot.Name
                break
            end
        end

        if not espConfig.enabledBase or not myPlotName then
            clearBaseESP_repl()
            return
        end

        for _, plot in pairs(plotsFolder:GetChildren()) do
            if plot.Name ~= myPlotName then
                local purchases = plot:FindFirstChild('Purchases')
                local pb = purchases and purchases:FindFirstChild('PlotBlock')
                local main = pb and pb:FindFirstChild('Main')
                local gui = main and main:FindFirstChild('BillboardGui')
                local timeLb = gui and gui:FindFirstChild('RemainingTime')
                if timeLb and main then
                    local parentModel = main
                    local existingBillboard =
                        parentModel:FindFirstChild('Base_ESP')
                    if not existingBillboard then
                        local billboard = Instance.new('BillboardGui')
                        billboard.Name = 'Base_ESP'
                        billboard.Size = UDim2.new(0, 140, 0, 36)
                        billboard.StudsOffset = Vector3.new(0, 5, 0)
                        billboard.AlwaysOnTop = true
                        billboard.Parent = parentModel

                        local label = Instance.new('TextLabel')
                        label.Text = timeLb.Text
                        label.Size = UDim2.new(1, 0, 1, 0)
                        label.BackgroundTransparency = 1
                        label.TextScaled = true
                        label.TextColor3 = Color3.fromRGB(220, 0, 60)
                        label.Font = Enum.Font.Arcade
                        label.TextStrokeTransparency = 0.5
                        label.TextStrokeColor3 = Color3.new(0, 0, 0)
                        label.Parent = billboard

                        pcall(function()
                            if billboard.SetAttribute then
                                billboard:SetAttribute('lastTime', label.Text)
                            end
                        end)
                    else
                        local label =
                            existingBillboard:FindFirstChildOfClass('TextLabel')
                        if label then
                            local last =
                                safeGetAttribute(existingBillboard, 'lastTime')
                            local newText = timeLb.Text
                            if last ~= newText then
                                label.Text = newText
                                pcall(function()
                                    if existingBillboard.SetAttribute then
                                        existingBillboard:SetAttribute(
                                            'lastTime',
                                            newText
                                        )
                                    end
                                end)
                            end
                        end
                    end
                elseif main and main:FindFirstChild('Base_ESP') then
                    pcall(function()
                        main.Base_ESP:Destroy()
                    end)
                end
            end
        end
    end

    function startBaseESP()
        espConfig.enabledBase = true
        pcall(updateESPBase)
    end

    function stopBaseESP()
        espConfig.enabledBase = false
        pcall(clearBaseESP_repl)
    end

    task.spawn(function()
        while true do
            task.wait(BASE_UPDATE_INTERVAL)
            pcall(updateESPBase)
        end
    end)
end

----------------------------------------------------------------
-- STEAL FLOOR
----------------------------------------------------------------
local ProximityPromptService = game:GetService('ProximityPromptService')

-- Estado principal
local sfActive = false
local sfFloatSpeed = 24
local sfAttachment, sfAlignPosition, sfAlignOrientation, sfLinearVelocity

-- Conexões
local sfHeartbeatConn, sfPromptConn, sfDiedConn, sfCharAddedConn

-- Backup de aparência das peças
local sfOriginalProps = {} -- [BasePart] = {Transparency=, Material=}

local function sfSafeDisconnect(conn)
    if conn and typeof(conn) == 'RBXScriptConnection' then
        pcall(function()
            conn:Disconnect()
        end)
    end
end

-- Transparência com backup/restauração
local function sfSetPlotsTransparency(active)
    local plots = Workspace:FindFirstChild('Plots')
    if not plots then
        return
    end

    if active then
        sfOriginalProps = {}
        for _, plot in ipairs(plots:GetChildren()) do
            local containers = {
                plot:FindFirstChild('Decorations'),
                plot:FindFirstChild('AnimalPodiums'),
            }
            for _, container in ipairs(containers) do
                if container then
                    for _, obj in ipairs(container:GetDescendants()) do
                        if obj:IsA('BasePart') then
                            sfOriginalProps[obj] = {
                                Transparency = obj.Transparency,
                                Material = obj.Material,
                            }
                            obj.Transparency = 0.7
                        end
                    end
                end
            end
        end
    else
        for part, props in pairs(sfOriginalProps) do
            if part and part.Parent then
                part.Transparency = props.Transparency
                part.Material = props.Material
            end
        end
        sfOriginalProps = {}
    end
end

-- Criação/remoção de corpos de física
local function sfDestroyBodies()
    if sfLinearVelocity then
        pcall(function()
            sfLinearVelocity:Destroy()
        end)
    end
    if sfAlignPosition then
        pcall(function()
            sfAlignPosition:Destroy()
        end)
    end
    if sfAlignOrientation then
        pcall(function()
            sfAlignOrientation:Destroy()
        end)
    end
    if sfAttachment then
        pcall(function()
            sfAttachment:Destroy()
        end)
    end
    sfLinearVelocity, sfAlignPosition, sfAlignOrientation, sfAttachment =
        nil, nil, nil, nil
end

local function sfCreateBodies(rootPart)
    sfDestroyBodies()
    if not rootPart then
        return
    end

    sfAttachment = Instance.new('Attachment')
    sfAttachment.Name = 'StealFloor_Attachment'
    sfAttachment.Parent = rootPart

    sfAlignPosition = Instance.new('AlignPosition')
    sfAlignPosition.Name = 'StealFloor_AlignPosition'
    sfAlignPosition.Attachment0 = sfAttachment
    sfAlignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
    sfAlignPosition.Position = rootPart.Position
    sfAlignPosition.MaxForce = 500000
    sfAlignPosition.Responsiveness = 200
    sfAlignPosition.ApplyAtCenterOfMass = true
    sfAlignPosition.ForceLimitMode = Enum.ForceLimitMode.PerAxis
    sfAlignPosition.MaxAxesForce = Vector3.new(math.huge, 0, math.huge)
    sfAlignPosition.Parent = rootPart

    sfAlignOrientation = Instance.new('AlignOrientation')
    sfAlignOrientation.Name = 'StealFloor_AlignOrientation'
    sfAlignOrientation.Attachment0 = sfAttachment
    sfAlignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
    sfAlignOrientation.CFrame = rootPart.CFrame
    sfAlignOrientation.MaxTorque = 500000
    sfAlignOrientation.Responsiveness = 200
    sfAlignOrientation.Parent = rootPart

    sfLinearVelocity = Instance.new('LinearVelocity')
    sfLinearVelocity.Name = 'StealFloor_LinearVelocity'
    sfLinearVelocity.Attachment0 = sfAttachment
    sfLinearVelocity.MaxForce = 500000
    sfLinearVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
    sfLinearVelocity.MaxAxesForce = Vector3.new(0, math.huge, 0)
    sfLinearVelocity.VectorVelocity = Vector3.new(0, 0, 0)
    sfLinearVelocity.Parent = rootPart
end

-- Teleportar até o chão
local function sfDisable() end -- forward decl

local function sfTeleportToGround()
    local char = player.Character
    local rp = char and char:FindFirstChild('HumanoidRootPart')
    local hum = char and char:FindFirstChildOfClass('Humanoid')
    if not (rp and hum and hum.Health > 0) then
        return
    end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { char }

    local rayResult =
        Workspace:Raycast(rp.Position, Vector3.new(0, -1500, 0), rayParams)
    if rayResult then
        rp.CFrame = CFrame.new(
            rp.Position.X,
            rayResult.Position.Y + hum.HipHeight,
            rp.Position.Z
        )
        if sfActive then
            sfDisable() -- restaura e limpa
        end
    end
end

-- Habilitar/Desabilitar
local function sfEnable()
    if sfActive then
        return
    end
    local hum = getHumanoid()
    local root = getHRP()
    if not (hum and hum.Health > 0 and root) then
        return
    end

    sfActive = true
    sfCreateBodies(root)
    sfSetPlotsTransparency(true)

    -- Sobe continuamente
    sfSafeDisconnect(sfHeartbeatConn)
    sfHeartbeatConn = RunService.Heartbeat:Connect(function()
        if not sfActive or not sfLinearVelocity then
            return
        end
        local h = getHumanoid()
        if not (h and h.Health > 0) then
            sfDisable()
            return
        end
        sfLinearVelocity.VectorVelocity = Vector3.new(0, sfFloatSpeed, 0)
    end)

    -- Teleportar ao detectar "steal"
    sfSafeDisconnect(sfPromptConn)
    sfPromptConn = ProximityPromptService.PromptTriggered:Connect(
        function(prompt, who)
            if who == player then
                local act = (prompt.ActionText or ''):lower()
                if string.find(act, 'steal') then
                    sfTeleportToGround()
                end
            end
        end
    )

    -- Morreu: desliga e restaura
    sfSafeDisconnect(sfDiedConn)
    if hum then
        sfDiedConn = hum.Died:Connect(function()
            sfDisable()
        end)
    end
end

function sfDisable()
    if not sfActive then
        -- garantir limpeza mesmo inativo
        sfSetPlotsTransparency(false)
        sfDestroyBodies()
        sfSafeDisconnect(sfHeartbeatConn)
        sfSafeDisconnect(sfPromptConn)
        sfSafeDisconnect(sfDiedConn)
        sfHeartbeatConn, sfPromptConn, sfDiedConn = nil, nil, nil
        return
    end
    sfActive = false
    sfSetPlotsTransparency(false)
    sfDestroyBodies()
    sfSafeDisconnect(sfHeartbeatConn)
    sfSafeDisconnect(sfPromptConn)
    sfSafeDisconnect(sfDiedConn)
    sfHeartbeatConn, sfPromptConn, sfDiedConn = nil, nil, nil
end

-- Respawn: sempre restaurar
sfSafeDisconnect(sfCharAddedConn)
sfCharAddedConn = player.CharacterAdded:Connect(function(ch)
    -- dá um tempo para os objetos spawnarem
    task.wait(0.1)
    sfDisable()
end)

-- Botão STEAL FLOOR
local btnStealFloor = createButton(panel, UDim2.new(0.88, 0, 0, 34), UDim2.new(0.06, 0, 0, flyY + 34 + 12), '🏗️ STEAL FLOOR', Enum.Font.GothamBold, Color3.fromRGB(255, 120, 120), 14)
btnStealFloor.MouseButton1Click:Connect(function()
    if not sfActive then
        sfEnable()
        btnStealFloor.BackgroundColor3 = Color3.fromRGB(120, 255, 120)
        btnStealFloor.Text = '✅ STEAL FLOOR ON'
        showStatus('Steal Floor ON 🏗️', Color3.fromRGB(120, 255, 120))
    else
        sfDisable()
        btnStealFloor.BackgroundColor3 = Color3.fromRGB(255, 120, 120)
        btnStealFloor.Text = '🏗️ STEAL FLOOR'
        showStatus('Steal Floor OFF')
    end
end)

-- Ajusta altura do painel para incluir o novo botão
do
    local bottom = btnStealFloor.Position.Y.Offset
        + btnStealFloor.Size.Y.Offset
        + 18
    panel.Size = UDim2.new(0, 200, 0, bottom)
end

----------------------------------------------------------------
-- REMOÇÃO DE ACESSÓRIOS
----------------------------------------------------------------
local function removeAccessoriesFromCharacter(character)
    if not character then
        return
    end
    for _, item in ipairs(character:GetChildren()) do
        if item:IsA('Accessory') then
            pcall(function()
                item:Destroy()
            end)
        end
    end
end

local playersWithAccessoryListener = {}
local function ensureAccessoryListenerForPlayer(p)
    if not p or p == player or playersWithAccessoryListener[p] then
        return
    end
    playersWithAccessoryListener[p] = true
    p.CharacterAdded:Connect(function(ch)
        task.wait(0.2)
        removeAccessoriesFromCharacter(ch)
    end)
end

local function stripOtherPlayersAccessories_once()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            if p.Character then
                removeAccessoriesFromCharacter(p.Character)
            end
            ensureAccessoryListenerForPlayer(p)
        end
    end
end
stripOtherPlayersAccessories_once()

Players.PlayerAdded:Connect(function(p)
    if p ~= player then
        ensureAccessoryListenerForPlayer(p)
        if p.Character then
            task.wait(0.2)
            removeAccessoriesFromCharacter(p.Character)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(30)
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                pcall(function()
                    removeAccessoriesFromCharacter(p.Character)
                end)
            end
        end
    end
end)

----------------------------------------------------------------
-- BOTÃO OPEN + DRAG
----------------------------------------------------------------
local openBtn = Instance.new('ImageButton')
openBtn.Size = UDim2.new(0, 60, 0, 60)
openBtn.Position = UDim2.new(0, 20, 0.5, -30)
openBtn.Image = 'rbxassetid://129657171957977' 
openBtn.BackgroundTransparency = 1
openBtn.Name = 'OpenButton'
openBtn.Parent = gui
local openCorner = Instance.new('UICorner', openBtn)
openCorner.CornerRadius = UDim.new(1, 0)
local glowBtn = Instance.new('UIStroke', openBtn)
glowBtn.Thickness = 2.5
glowBtn.Transparency = 0.15

-- Glow animado улучшенный для кнопки
task.spawn(function()
    while openBtn.Parent do
        task.wait(GLOW_UPDATE_INTERVAL)
        local t = math.sin(tick() * 3)
        glowBtn.Color = Color3.fromRGB(120 + 135 * t, 255, 180 + 75 * t)
        glowBtn.Transparency = 0.15 + 0.15 * math.abs(t)
    end
end)

openBtn.MouseButton1Click:Connect(function()
    menu.Visible = not menu.Visible
end)
panel.Visible = true

local function makeDraggable(obj)
    local dragging = false
    local dragStart, startPos
    obj.InputBegan:Connect(function(inp)
        if
            inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch
        then
            dragging = true
            dragStart = inp.Position
            startPos = obj.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    obj.InputChanged:Connect(function(inp)
        if
            inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch
        then
            if dragging then
                local delta = inp.Position - dragStart
                obj.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            end
        end
    end)
end

makeDraggable(menu)
makeDraggable(panel)
makeDraggable(openBtn)

notify('Astro Hub', 'Script activated! ✨', 5)

----------------------------------------------------------------
-- FINAL: Script otimizado para mobile
----------------------------------------------------------------
-- Otimizações aplicadas:
-- 1. Cache de GetDescendants (reduz varredura de árvore)
-- 2. Sound pooling (limita sons simultâneos)
-- 3. Intervalos aumentados (1.5s ESP, 0.25s glow)
-- 4. Debounce otimizado em CFrame updates
-- 5. Limpeza periódica de cache
-- Новое: Красивый дизайн с градиентами, анимациями, эмодзи; Подсветка Desync (зеленый+красный для оригинала/клона)
-- Todas as funcionalidades mantidas intactas!
