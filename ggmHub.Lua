-- ==========================================
-- GGM HUB | ANIME ZERO - V38 (Auto Replay/Lobby EXATO)
-- ==========================================

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local VirtualInputManager= game:GetService("VirtualInputManager")
local UserInputService   = game:GetService("UserInputService")
local HttpService        = game:GetService("HttpService")
local LocalPlayer        = Players.LocalPlayer

getgenv().AutoFarm       = false
getgenv().AutoBarrier    = false
getgenv().AutoPatrol     = true
getgenv().AutoSkill1     = false
getgenv().AutoSkill2     = false
getgenv().AutoSkill3     = false
getgenv().AutoUlt        = false
getgenv().AttackDelay    = 0.4

getgenv().WalkSpeed      = 16
getgenv().NoClip         = true

getgenv().EndAction      = "Nada (parar)"
getgenv().WaypointPaused = false

local hipHeightValue = 2
local currentTarget  = nil
local targetType     = nil
local lastAttack     = 0
local lastAimPos     = nil

local waypoints        = {}
local currentWpIndex   = 1
local waypointReached  = false
local pauseStartTime   = 0

local selectedConfig    = nil
local lastConfigName    = ""

local ENEMY_GRACE_TIME = 5
local Y_DEPTH_LIMIT    = 40
local TP_NEAR_DIST     = 12
local WP_REACHED_DIST  = 5
local ATTACK_MAX_DIST  = 30

local lastPosition     = nil
local stuckCounter     = 0
local STUCK_THRESHOLD  = 10

local CONFIG_FILE = "GGM_Hub_WP_v3_" .. game.PlaceId .. ".json"
local INPUT_FLAG  = "GGM_ConfigName"
local WINDOW_NAME = "GGM HUB | Anime Zero"

-- ==========================================
-- PERSISTÊNCIA
-- ==========================================
local function saveAllConfigs(configs)
    if not writefile then return false, "writefile indisponível" end
    local ok, err = pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(configs))
    end)
    if not ok then return false, tostring(err) end
    return true
end

local function loadAllConfigs()
    if not isfile or not isfile(CONFIG_FILE) then return {} end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(CONFIG_FILE))
    end)
    if not ok or type(data) ~= "table" then return {} end
    local clean = {}
    for k, v in pairs(data) do
        if type(k) == "string" and type(v) == "table" then clean[k] = v end
    end
    return clean
end

local function saveCurrentAsConfig(name)
    if not name or name == "" then return false, "nome vazio" end
    local data = {}
    for _, wp in ipairs(waypoints) do
        table.insert(data, {wp.X, wp.Y, wp.Z})
    end
    local configs = loadAllConfigs()
    configs[name] = data
    return saveAllConfigs(configs)
end

local function loadConfigByName(name)
    if type(name) ~= "string" then return false, "nome inválido" end
    local configs = loadAllConfigs()
    local data = configs[name]
    if not data or type(data) ~= "table" then return false, "não encontrada" end
    waypoints = {}
    for _, v in ipairs(data) do
        if type(v) == "table" and v[1] and v[2] and v[3] then
            table.insert(waypoints, Vector3.new(v[1], v[2], v[3]))
        end
    end
    currentWpIndex = 1
    waypointReached = false
    getgenv().WaypointPaused = false
    return true, #waypoints
end

local function deleteConfig(name)
    if type(name) ~= "string" then return false, "nome inválido" end
    local configs = loadAllConfigs()
    if not configs[name] then return false, "não existe" end
    configs[name] = nil
    return saveAllConfigs(configs)
end

-- ==========================================
-- INTERFACE
-- ==========================================
local Window = Rayfield:CreateWindow({
    Name = WINDOW_NAME,
    LoadingTitle = "GGM HUB",
    LoadingSubtitle = "Iniciando...",
    ConfigurationSaving = {Enabled = false},
    Discord = {Enabled = false},
    KeySystem = false,
    Theme = "Amethyst"
})

local TabCombat = Window:CreateTab("⚔️ Combate", 4483362458)
local TabWP     = Window:CreateTab("📍 Waypoints", 4483362458)
local TabMisc   = Window:CreateTab("⚙️ Personagem", 4483345998)

-- ==========================================
-- HELPERS & NOCLIP & WALKSPEED
-- ==========================================
local function getRoot(c) return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum(c)  return c and c:FindFirstChildOfClass("Humanoid") end

RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    
    local active = getgenv().AutoFarm or getgenv().AutoBarrier
    if active then
        local hum = getHum(char)
        if hum then
            hum.WalkSpeed = getgenv().WalkSpeed or 16
        end

        if getgenv().NoClip then
            for _, v in pairs(char:GetDescendants()) do
                if v:IsA("BasePart") and v.CanCollide then
                    v.CanCollide = false
                end
            end
        end
    end
end)

local function findClosestWpIndex()
    local root = getRoot(LocalPlayer.Character)
    if not root or #waypoints == 0 then return 1 end
    local myPos = root.Position
    local bestIdx, bestDist = 1, math.huge
    for i, wp in ipairs(waypoints) do
        local d = (myPos - wp).Magnitude
        if d < bestDist then
            bestIdx, bestDist = i, d
        end
    end
    return bestIdx
end

-- ==========================================
-- SISTEMA DE MOVIMENTAÇÃO (APENAS ANDAR)
-- ==========================================
local function movePlayer(targetPos)
    local char = LocalPlayer.Character
    local root = getRoot(char)
    local hum = getHum(char)
    if not root or not hum then return end

    local flatTarget = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
    
    if lastPosition then
        local moved = (root.Position - lastPosition).Magnitude
        if moved < 0.5 then
            stuckCounter = stuckCounter + 1
        else
            stuckCounter = 0
        end
    end
    lastPosition = root.Position

    if stuckCounter >= STUCK_THRESHOLD then
        stuckCounter = 0
        root.CFrame = root.CFrame * CFrame.new(0, 5, -5)
        return
    end
    
    hum:MoveTo(flatTarget)
end

-- ==========================================
-- CONTADORES E ALVOS
-- ==========================================
local function aliveEnemiesCount()
    local n = 0
    local char = LocalPlayer.Character
    local folder = workspace:FindFirstChild("enemies")
    if folder then
        for _, v in pairs(folder:GetChildren()) do
            local hum = getHum(v)
            if hum and hum.Health > 0 then n = n + 1 end
        end
    end
    if n == 0 then
        local myRoot = getRoot(char)
        for _, v in pairs(workspace:GetChildren()) do
            if v:IsA("Model") and v ~= char and not Players:GetPlayerFromCharacter(v) then
                local hum = getHum(v)
                if hum and hum.Health > 0 then
                    local root = getRoot(v)
                    if root and myRoot and (myRoot.Position - root.Position).Magnitude < 150 then
                        n = n + 1
                    end
                end
            end
        end
    end
    return n
end

local function getBorderAncestor(part)
    local node = part.Parent
    while node and node ~= workspace do
        local n = string.lower(node.Name)
        if string.find(n, "^border%d") then return node.Name end
        node = node.Parent
    end
    return nil
end

local function isTooDeep(partPos, myPos)
    return (myPos.Y - partPos.Y) > Y_DEPTH_LIMIT
end

local function isBreakableRubble(v)
    if not (v:IsA("MeshPart") or v:IsA("Part")) then return false end
    if not v.CanCollide then return false end
    if v.Transparency >= 0.9 then return false end
    local n = string.lower(v.Name)
    if string.find(n, "blocker") or string.find(n, "navigation") then return false end
    if not getBorderAncestor(v) then return false end
    return true
end

local function findRubbleNear(pos, maxDist)
    maxDist = maxDist or 40
    local best, bestD = nil, math.huge
    for _, v in pairs(workspace:GetDescendants()) do
        if isBreakableRubble(v) then
            if not isTooDeep(v.Position, pos) then
                local d = (pos - v.Position).Magnitude
                if d < bestD and d < maxDist then
                    best, bestD = v, d
                end
            end
        end
    end
    return best
end

local function isTyping() return UserInputService:GetFocusedTextBox() ~= nil end

-- ==========================================
-- AUTO REPLAY / LOBBY (CAMINHO EXATO)
-- ==========================================
local function clickDetectedButton(btn)
    for _ = 1, 3 do
        local fired = false
        pcall(function()
            if firesignal then firesignal(btn.Activated); fired = true end
        end)
        if not fired then
            local px = btn.AbsolutePosition.X + btn.AbsoluteSize.X / 2
            local py = btn.AbsolutePosition.Y + btn.AbsoluteSize.Y / 2
            VirtualInputManager:SendMouseButtonEvent(px, py, 0, true, game, 1)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(px, py, 0, false, game, 1)
        end
        task.wait(0.3)
    end
end

local function handleEndScreenAction()
    local action = getgenv().EndAction
    if not action or action == "Nada (parar)" then return end

    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end

    local endScreen = pg:FindFirstChild("EndScreen")
    if endScreen and endScreen.Enabled then
        local buttonsHolder = endScreen:FindFirstChild("Holder")
                              and endScreen.Holder:FindFirstChild("ConstraintedHolder")
                              and endScreen.Holder.ConstraintedHolder:FindFirstChild("ButtonsHolder")
        
        if buttonsHolder then
            local targetBtn = nil
            
            if action == "Tentar Novamente" then
                local retryFolder = buttonsHolder:FindFirstChild("RetryButton")
                if retryFolder and retryFolder:FindFirstChild("Button") then
                    targetBtn = retryFolder.Button
                end
            elseif action == "Voltar ao Lobby" then
                local leaveFolder = buttonsHolder:FindFirstChild("LeaveButton")
                if leaveFolder and leaveFolder:FindFirstChild("Button") then
                    targetBtn = leaveFolder.Button
                end
            end

            -- Se achou o botão correto e ele estiver visível na tela, clica nele!
            if targetBtn and targetBtn.Visible then
                clickDetectedButton(targetBtn)
            end
        end
    end
end

task.spawn(function()
    while task.wait(2) do
        handleEndScreenAction()
    end
end)

-- ==========================================
-- WAYPOINTS UI
-- ==========================================
local ConfigDropdown

local function refreshConfigList()
    local configs = loadAllConfigs()
    local names = {}
    for k, _ in pairs(configs) do if type(k) == "string" then table.insert(names, k) end end
    table.sort(names)
    if #names == 0 then names = {"(nenhuma)"} end
    if ConfigDropdown then ConfigDropdown:Refresh(names, true) end
end

TabWP:CreateSection("Gravar Waypoints")
TabWP:CreateButton({
    Name = "📍 Salvar Posição Atual",
    Callback = function()
        local root = getRoot(LocalPlayer.Character)
        if root then
            table.insert(waypoints, root.Position)
            Rayfield:Notify({Title = "Waypoint", Content = "Total: " .. #waypoints, Duration = 2})
        end
    end,
})

TabWP:CreateButton({
    Name = "🗑️ Limpar Waypoints",
    Callback = function()
        waypoints = {}; currentWpIndex = 1; waypointReached = false; getgenv().WaypointPaused = false
        Rayfield:Notify({Title="Waypoints", Content="Sessão limpa!", Duration=2})
    end,
})

TabWP:CreateSection("Salvar / Carregar")
TabWP:CreateInput({
    Name = "Nome da Config (aperte ENTER)", PlaceholderText = "Ex: Fase1", RemoveTextAfterFocusLost = false,
    Flag = INPUT_FLAG, Callback = function(T) lastConfigName = T end,
})

TabWP:CreateButton({
    Name = "💾 Salvar como Config",
    Callback = function()
        if #waypoints == 0 then return end
        local name = lastConfigName
        if name and name ~= "" then
            saveCurrentAsConfig(name)
            refreshConfigList()
            Rayfield:Notify({Title = "Salvo", Content = "'" .. name .. "' (" .. #waypoints .. ")", Duration = 3})
        end
    end,
})

ConfigDropdown = TabWP:CreateDropdown({
    Name = "Configs Salvas", Options = {"(nenhuma)"}, CurrentOption = {"(nenhuma)"}, Flag = "SelectedConfig",
    Callback = function(Opt) selectedConfig = type(Opt)=="table" and Opt[1] or Opt end,
})

TabWP:CreateButton({
    Name = "📂 Carregar Selecionada",
    Callback = function()
        local n = selectedConfig
        if n and n ~= "(nenhuma)" then
            loadConfigByName(n)
            Rayfield:Notify({Title = "Carregada", Content = "'" .. n .. "'", Duration = 3})
        end
    end,
})

-- ==========================================
-- DETECÇÃO E MOVIMENTO PRINCIPAL
-- ==========================================
task.spawn(function()
    while task.wait(0.1) do
        local char = LocalPlayer.Character
        local root = getRoot(char)
        if not root or not (getgenv().AutoFarm or getgenv().AutoBarrier) then
            currentTarget = nil
            continue
        end
        local myPos = root.Position
        local foundEnemy = false

        if getgenv().AutoFarm then
            local enemiesFolder = workspace:FindFirstChild("enemies")
            local bestEnemy, bestDist = nil, math.huge
            local searchIn = enemiesFolder and enemiesFolder:GetChildren() or workspace:GetChildren()
            
            for _, v in pairs(searchIn) do
                if v:IsA("Model") and v ~= char and not Players:GetPlayerFromCharacter(v) then
                    local vRoot, vHum = getRoot(v), getHum(v)
                    if vRoot and vHum and vHum.Health > 0 and not isTooDeep(vRoot.Position, myPos) then
                        local d = (myPos - vRoot.Position).Magnitude
                        if d < bestDist and d < 500 then
                            bestEnemy, bestDist = vRoot, d
                        end
                    end
                end
            end
            
            if bestEnemy then
                currentTarget, targetType = bestEnemy, "Enemy"
                lastAimPos = bestEnemy.Position
                foundEnemy = true
            end
        end

        if not foundEnemy and getgenv().AutoBarrier and #waypoints > 0 then
            if getgenv().WaypointPaused then
                if tick() - pauseStartTime >= 10 then
                    getgenv().WaypointPaused = false
                    currentWpIndex = 1
                    waypointReached = false
                    Rayfield:Notify({Title = "Waypoints", Content = "10 segundos passados! Reiniciando trajeto.", Duration = 3})
                else
                    currentTarget = nil
                    targetType = nil
                end
            else
                local enemiesAlive = aliveEnemiesCount()
                if enemiesAlive == 0 then
                    local wp = waypoints[currentWpIndex]
                    if wp then
                        if not waypointReached and (myPos - wp).Magnitude < WP_REACHED_DIST then
                            waypointReached = true
                        end
                        if waypointReached then
                            local rubble = findRubbleNear(wp, 40)
                            if rubble then
                                currentTarget, targetType = rubble, "Barrier"
                                lastAimPos = rubble.Position
                            else
                                waypointReached = false
                                if currentWpIndex >= #waypoints then
                                    getgenv().WaypointPaused = true
                                    pauseStartTime = tick()
                                    Rayfield:Notify({Title = "Waypoints", Content = "Trajeto finalizado. Reiniciando em 10 segundos.", Duration = 4})
                                else
                                    currentWpIndex = currentWpIndex + 1
                                end
                            end
                        else
                            currentTarget, targetType = wp, "Waypoint"
                        end
                    else
                        currentWpIndex = 1
                    end
                end
            end
        end

        if currentTarget then
            if targetType == "Enemy" and currentTarget.Parent then
                local desired = currentTarget.CFrame * CFrame.new(0, 0, 3)
                if (myPos - desired.Position).Magnitude > 2 then
                    movePlayer(desired.Position)
                end
            elseif targetType == "Waypoint" then
                if (myPos - currentTarget).Magnitude > 2 then
                    movePlayer(currentTarget)
                end
            elseif targetType == "Barrier" and currentTarget.Parent then
                local tPos = currentTarget.Position
                if (myPos - tPos).Magnitude > 5 then
                    local dir = (myPos - tPos).Unit
                    local ideal = tPos + dir * 5
                    movePlayer(ideal)
                end
            end
        end
    end
end)

-- ==========================================
-- ATAQUE M1 & SKILLS
-- ==========================================
local function doAttack(targetPos)
    local cam = workspace.CurrentCamera
    local x, y = cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2
    if targetPos then
        local sp, onScreen = cam:WorldToViewportPoint(targetPos)
        if onScreen then x, y = sp.X, sp.Y end
    end
    VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
    task.wait(0.02)
    VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
end

task.spawn(function()
    while task.wait(0.05) do
        if not (getgenv().AutoFarm or (getgenv().AutoBarrier and currentTarget)) or isTyping() then continue end
        local hum = getHum(LocalPlayer.Character)
        if not hum or hum.Health <= 0 then continue end
        if tick() - lastAttack < (getgenv().AttackDelay or 0.4) then continue end

        local aimPos = (currentTarget and currentTarget.Parent) and currentTarget.Position or lastAimPos
        if aimPos then
            lastAttack = tick()
            doAttack(aimPos)
        end
    end
end)

local function pressKey(k)
    VirtualInputManager:SendKeyEvent(true, k, false, game); task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, k, false, game)
end

task.spawn(function()
    while task.wait(0.6) do
        if getgenv().AutoFarm and targetType == "Enemy" and currentTarget and not isTyping() then
            if getgenv().AutoSkill1 then pressKey(Enum.KeyCode.One) end
            if getgenv().AutoSkill2 then pressKey(Enum.KeyCode.Two) end
            if getgenv().AutoSkill3 then pressKey(Enum.KeyCode.Three) end
            if getgenv().AutoUlt  then pressKey(Enum.KeyCode.G) end
        end
    end
end)

-- ==========================================
-- MENUS RESTANTES
-- ==========================================
TabCombat:CreateSection("Auto Farm")
TabCombat:CreateToggle({Name = "Auto Farm (Andar + Ataque)", CurrentValue = false, Flag = "AutoFarm", Callback = function(V) getgenv().AutoFarm = V end})
TabCombat:CreateToggle({Name = "Auto Quebrar Barreira", CurrentValue = false, Flag = "AutoBarrier", Callback = function(V)
    getgenv().AutoBarrier = V
    if V then 
        currentWpIndex = findClosestWpIndex()
        waypointReached = false 
        getgenv().WaypointPaused = false
    end
end})

TabCombat:CreateSection("Ação de Fim de Partida")
TabCombat:CreateDropdown({
    Name = "Ação ao terminar (Vitória)",
    Options = {"Nada (parar)", "Voltar ao Lobby", "Tentar Novamente"},
    CurrentOption = {"Nada (parar)"},
    Flag = "EndAction",
    Callback = function(Option)
        getgenv().EndAction = type(Option) == "table" and Option[1] or Option
    end,
})

TabCombat:CreateSection("Controle de Waypoints")
TabCombat:CreateButton({
    Name = "🔄 Reiniciar Trajeto Imediatamente",
    Callback = function()
        if #waypoints == 0 then
            Rayfield:Notify({Title="Aviso", Content="Nenhum waypoint carregado.", Duration=2})
            return
        end
        getgenv().WaypointPaused = false
        currentWpIndex = 1
        waypointReached = false
        Rayfield:Notify({Title="Waypoints", Content="Trajeto reiniciado para o WP 1!", Duration=2})
    end,
})

TabCombat:CreateSection("Movimentação (Andar)")
TabCombat:CreateSlider({
    Name = "Velocidade do Andar (WalkSpeed)", Range = {16, 200}, Increment = 1, CurrentValue = 16, Flag = "WalkSpeed",
    Callback = function(V) getgenv().WalkSpeed = V end,
})
TabCombat:CreateToggle({Name = "Atravessar Paredes (NoClip)", CurrentValue = true, Flag = "NoClip", Callback = function(V) getgenv().NoClip = V end})

TabCombat:CreateSection("Ataque e Skills")
TabCombat:CreateSlider({Name="Delay do Ataque (ms)", Range={100, 1000}, Increment=50, CurrentValue=400, Flag="AttackDelay", Callback=function(V) getgenv().AttackDelay = V/1000 end})
TabCombat:CreateToggle({Name="Skill 1 [1]", CurrentValue=false, Flag="S1", Callback=function(V) getgenv().AutoSkill1 = V end})
TabCombat:CreateToggle({Name="Skill 2 [2]", CurrentValue=false, Flag="S2", Callback=function(V) getgenv().AutoSkill2 = V end})
TabCombat:CreateToggle({Name="Skill 3 [3]", CurrentValue=false, Flag="S3", Callback=function(V) getgenv().AutoSkill3 = V end})
TabCombat:CreateToggle({Name="Ultimate [G]", CurrentValue=false, Flag="Ult", Callback=function(V) getgenv().AutoUlt = V end})

TabMisc:CreateSection("Modificadores")
TabMisc:CreateInput({Name="Valor da Altura (HipHeight)", PlaceholderText="Ex: 5", Callback=function(T) hipHeightValue = tonumber(T) or 2 end})
TabMisc:CreateButton({Name="Aplicar Altura", Callback=function()
    local hum = getHum(LocalPlayer.Character)
    if hum then hum.HipHeight = hipHeightValue; Rayfield:Notify({Title="Altura", Content="Alterado para "..hipHeightValue, Duration=2}) end
end})

task.spawn(function() task.wait(1.5); refreshConfigList() end)