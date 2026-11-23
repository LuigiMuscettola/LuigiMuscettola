-- Atlas PvP | Blox Fruits | experimental community script
-- Original implementation. NOT a copy of Hermanos.dev.
-- Designed for executor environments with Luau, CoreGui/gethui, and input injection.
-- Does not bypass server-side damage, cooldowns, PvP restrictions or anti-cheat.

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return warn("[Atlas PvP] Giocatore locale non disponibile") end

local environment = (type(getgenv) == "function" and getgenv()) or _G
if environment.AtlasPvP_Instance and type(environment.AtlasPvP_Instance.Unload) == "function" then
    pcall(function() environment.AtlasPvP_Instance:Unload() end)
end

local Configuration = {
    MaxSearchRange = 550,
    CastRange = 60,
    MeleeRange = 16,
    FollowDistance = 10,
    TargetRefresh = 0.45,
    SkillHold = 0.08,
    SkillCooldown = 5.2, -- Approximation only; actual skills have individual cooldowns
    BetweenSkills = 0.16,
    BetweenWeapons = 0.18,
    UseMelee = true,
    UseFruit = true,
    UseSword = true,
    UseGun = true,
    UseUnknownTools = false,
    UseFSkill = true, -- Flight/mobility moves can interrupt combos
    UseRaceSkills = false,
    AutoFollow = true,
    AutoAttack = true,
    AimAssist = true,
    AutoPvP = false,
}

local state = {
    alive = true,
    active = false,
    targetMode = "NEAREST",
    lockedPlayer = nil,
    currentTarget = nil,
    lastSkill = {},
    lastClick = 0,
    connections = {},
    ui = {},
    aimHook = false,
    inputReady = false,
    message = "Pronto",
}

local vim
pcall(function() vim = game:GetService("VirtualInputManager") end)
local mouse = LocalPlayer:GetMouse()

local function charParts(player)
    local character = player and player.Character
    if not character then return nil end
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then return nil end
    return character, root, humanoid
end

local function distanceFromPlayer(player)
    local _, myRoot = charParts(LocalPlayer)
    local _, theirRoot = charParts(player)
    if not myRoot or not theirRoot then return math.huge end
    return (theirRoot.Position - myRoot.Position).Magnitude
end

local function candidates()
    local list = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and charParts(player) then
            table.insert(list, player)
        end
    end
    table.sort(list, function(a, b)
        return a.Name:lower() < b.Name:lower()
    end)
    return list
end

local function nearestTarget()
    local closest, closestDistance = nil, Configuration.MaxSearchRange
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local dist = distanceFromPlayer(player)
            if dist < closestDistance then
                closest, closestDistance = player, dist
            end
        end
    end
    return closest
end

local function refreshTarget()
    if state.targetMode == "LOCKED" then
        state.currentTarget = state.lockedPlayer
        if not state.currentTarget or distanceFromPlayer(state.currentTarget) == math.huge then
            state.currentTarget = nil
        end
    else
        state.currentTarget = nearestTarget()
    end
    return state.currentTarget
end

local function sendKey(key)
    local code = Enum.KeyCode[key]
    if not code then return false end
    if vim then
        local success = pcall(function()
            vim:SendKeyEvent(true, code, false, game)
            task.wait(Configuration.SkillHold)
            vim:SendKeyEvent(false, code, false, game)
        end)
        if success then return true end
    end
    if type(keypress) == "function" and type(keyrelease) == "function" then
        local success = pcall(function()
            keypress(string.byte(key))
            task.wait(Configuration.SkillHold)
            keyrelease(string.byte(key))
        end)
        if success then return true end
    end
    state.message = "Executor: invio tasti non supportato"
    return false
end

local function clickAttack()
    if type(mouse1click) == "function" then
        local ok = pcall(mouse1click)
        if ok then return true end
    end
    local camera = Workspace.CurrentCamera
    if camera and vim then
        local xy = camera.ViewportSize * 0.5
        local ok = pcall(function()
            vim:SendMouseButtonEvent(xy.X, xy.Y, 0, true, game, 0)
            task.wait(0.025)
            vim:SendMouseButtonEvent(xy.X, xy.Y, 0, false, game, 0)
        end)
        if ok then return true end
    end
    if camera then
        local ok = pcall(function()
            VirtualUser:Button1Down(Vector2.new(0, 0), camera.CFrame)
            task.wait(0.025)
            VirtualUser:Button1Up(Vector2.new(0, 0), camera.CFrame)
        end)
        if ok then return true end
    end
    return false
end

local function classifyTool(tool)
    local hint = string.lower(tostring(tool.ToolTip or ""))
    if hint:find("melee", 1, true) or hint:find("fighting", 1, true) then return "Melee" end
    if hint:find("blox fruit", 1, true) or hint:find("fruit", 1, true) then return "Fruit" end
    if hint:find("sword", 1, true) then return "Sword" end
    if hint:find("gun", 1, true) then return "Gun" end
    return "Unknown"
end

local function enabledTool(category)
    return (category == "Melee" and Configuration.UseMelee)
        or (category == "Fruit" and Configuration.UseFruit)
        or (category == "Sword" and Configuration.UseSword)
        or (category == "Gun" and Configuration.UseGun)
        or (category == "Unknown" and Configuration.UseUnknownTools)
end

local weaponOrder = {Melee = 1, Fruit = 2, Sword = 3, Gun = 4, Unknown = 5}
local function getWeapons()
    local found, weapons = {}, {}
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    for _, parent in ipairs({char, backpack}) do
        if parent then
            for _, item in ipairs(parent:GetChildren()) do
                if item:IsA("Tool") and not found[item] then
                    found[item] = true
                    local category = classifyTool(item)
                    if enabledTool(category) then
                        table.insert(weapons, {tool = item, category = category})
                    end
                end
            end
        end
    end
    table.sort(weapons, function(a, b)
        if weaponOrder[a.category] ~= weaponOrder[b.category] then
            return weaponOrder[a.category] < weaponOrder[b.category]
        end
        return a.tool.Name < b.tool.Name
    end)
    return weapons
end

local function skillKeys(category)
    if category == "Melee" then return {"Z", "X", "C"} end
    if category == "Sword" or category == "Gun" then return {"Z", "X"} end
    if category == "Fruit" then
        if Configuration.UseFSkill then return {"Z", "X", "C", "V", "F"} end
        return {"Z", "X", "C", "V"}
    end
    return {"Z", "X", "C"}
end

local function installOptionalAimHook()
    if type(hookmetamethod) ~= "function" or type(newcclosure) ~= "function" then return end
    local oldIndex
    local ok = pcall(function()
        oldIndex = hookmetamethod(game, "__index", newcclosure(function(object, property)
            if state.alive and state.active and Configuration.AimAssist
                and object == mouse and (property == "Hit" or property == "Target") then
                local _, root = charParts(state.currentTarget)
                if root then
                    if property == "Hit" then return CFrame.new(root.Position) end
                    return root
                end
            end
            return oldIndex(object, property)
        end))
    end)
    state.aimHook = ok
end

local function applyFollow(target)
    if not Configuration.AutoFollow then return end
    local _, ownRoot, ownHumanoid = charParts(LocalPlayer)
    local _, targetRoot = charParts(target)
    if not ownRoot or not targetRoot then return end
    local gap = (ownRoot.Position - targetRoot.Position).Magnitude
    if gap > Configuration.FollowDistance + 3 then
        local offset = ownRoot.Position - targetRoot.Position
        if offset.Magnitude < 0.1 then offset = Vector3.new(1, 0, 0) end
        local destination = targetRoot.Position + offset.Unit * Configuration.FollowDistance
        ownHumanoid:MoveTo(destination)
    else
        ownHumanoid:MoveTo(ownRoot.Position)
    end
    -- Rotate toward the target for skills that use facing direction.
    if gap < Configuration.CastRange then
        pcall(function()
            ownRoot.CFrame = CFrame.lookAt(ownRoot.Position, Vector3.new(
                targetRoot.Position.X, ownRoot.Position.Y, targetRoot.Position.Z))
        end)
    end
end

local function useCombos(target)
    local myChar, _, myHumanoid = charParts(LocalPlayer)
    if not myChar or not myHumanoid then return end
    if distanceFromPlayer(target) > Configuration.CastRange then return end
    local equippedSomething = false
    local weapons = getWeapons()
    if #weapons == 0 then
        state.message = "Nessuna arma riconosciuta (ToolTip)"
        return
    end
    for _, entry in ipairs(weapons) do
        if not state.alive or not state.active or state.currentTarget ~= target then return end
        if not charParts(target) then return end
        if distanceFromPlayer(target) > Configuration.CastRange then return end
        local tool = entry.tool
        if tool and tool.Parent and tool:IsA("Tool") then
            local equipped = pcall(function() myHumanoid:EquipTool(tool) end)
            if equipped then
                equippedSomething = true
                task.wait(Configuration.BetweenWeapons)
                if entry.category == "Melee" or entry.category == "Sword" then
                    if Configuration.AutoAttack and distanceFromPlayer(target) < Configuration.MeleeRange then
                        clickAttack()
                    end
                end
                for _, key in ipairs(skillKeys(entry.category)) do
                    if not state.alive or not state.active or state.currentTarget ~= target then return end
                    if distanceFromPlayer(target) > Configuration.CastRange then return end
                    local uniqueKey = tostring(tool) .. ":" .. key
                    if os.clock() - (state.lastSkill[uniqueKey] or -1e10) >= Configuration.SkillCooldown then
                        state.message = tool.Name .. " / " .. key
                        if sendKey(key) then
                            state.lastSkill[uniqueKey] = os.clock()
                        end
                        task.wait(Configuration.BetweenSkills)
                    end
                end
            end
        end
    end
    if Configuration.UseRaceSkills and equippedSomething and state.active then
        sendKey("T")
        task.wait(0.1)
        sendKey("Y")
    end
end

local InstanceId = "AtlasPvP_UI_2026"
local parentGui
pcall(function()
    if type(gethui) == "function" then parentGui = gethui() end
end)
if not parentGui then
    pcall(function() parentGui = game:GetService("CoreGui") end)
end
if not parentGui then parentGui = LocalPlayer:WaitForChild("PlayerGui") end
pcall(function()
    local old = parentGui:FindFirstChild(InstanceId)
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = InstanceId
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1800
gui.Parent = parentGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(292, 345)
panel.Position = UDim2.new(0, 20, 0.5, -173)
panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke", panel)
stroke.Color = Color3.fromRGB(69, 108, 179)
stroke.Thickness = 1

local function makeText(name, content, y, h, fontSize)
    local lbl = Instance.new("TextLabel")
    lbl.Name = name
    lbl.Size = UDim2.new(1, -24, 0, h)
    lbl.Position = UDim2.fromOffset(12, y)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = fontSize or 13
    lbl.TextColor3 = Color3.fromRGB(230, 234, 243)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Text = content
    lbl.Parent = panel
    return lbl
end

local heading = makeText("Heading", "ATLAS PvP  |  Blox Fruits", 10, 27, 17)
heading.Font = Enum.Font.GothamBold
local status = makeText("Status", "Stato: SPENTO", 44, 23, 13)
local targetText = makeText("Target", "Target: nessuno", 66, 22, 12)
local actionText = makeText("Action", "Azione: pronto", 88, 22, 12)

local function makeButton(name, label, x, y, width, height, fn)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.fromOffset(width, height)
    button.Position = UDim2.fromOffset(x, y)
    button.Text = label
    button.TextColor3 = Color3.fromRGB(244, 246, 250)
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 12
    button.BackgroundColor3 = Color3.fromRGB(45, 60, 88)
    button.BorderSizePixel = 0
    button.AutoButtonColor = true
    button.Parent = panel
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 7)
    table.insert(state.connections, button.MouseButton1Click:Connect(fn))
    return button
end

local switch = makeButton("Auto", "AUTO PvP: OFF", 12, 118, 268, 36, function()
    state.active = not state.active
    state.message = state.active and "Avvio ricerca" or "In pausa"
end)
local modeButton = makeButton("Mode", "BERSAGLIO: VICINO", 12, 163, 132, 33, function()
    state.targetMode = (state.targetMode == "NEAREST") and "LOCKED" or "NEAREST"
    if state.targetMode == "LOCKED" and not state.lockedPlayer then
        state.lockedPlayer = nearestTarget()
    end
    refreshTarget()
end)
local nextButton = makeButton("Select", "PROSSIMO PLAYER", 150, 163, 130, 33, function()
    local list = candidates()
    if #list == 0 then
        state.lockedPlayer = nil
        state.message = "Nessun giocatore disponibile"
        return
    end
    local pos = 0
    for i, p in ipairs(list) do if p == state.lockedPlayer then pos = i break end end
    state.lockedPlayer = list[(pos % #list) + 1]
    state.targetMode = "LOCKED"
    refreshTarget()
end)

local meleeButton = makeButton("Melee", "MELEE: ON", 12, 204, 130, 30, function()
    Configuration.UseMelee = not Configuration.UseMelee
end)
local fruitButton = makeButton("Fruit", "FRUIT: ON", 150, 204, 130, 30, function()
    Configuration.UseFruit = not Configuration.UseFruit
end)
local swordButton = makeButton("Sword", "SWORD: ON", 12, 239, 130, 30, function()
    Configuration.UseSword = not Configuration.UseSword
end)
local gunButton = makeButton("Gun", "GUN: ON", 150, 239, 130, 30, function()
    Configuration.UseGun = not Configuration.UseGun
end)
local followButton = makeButton("Follow", "INSEGUI: ON", 12, 275, 130, 29, function()
    Configuration.AutoFollow = not Configuration.AutoFollow
end)
local closeButton = makeButton("Stop", "CHIUDI SCRIPT", 150, 275, 130, 29, function()
    if environment.AtlasPvP_Instance then environment.AtlasPvP_Instance:Unload() end
end)
local foot = makeText("Foot", "Sperimentale | Solo strumenti sbloccati", 316, 18, 10)
foot.TextColor3 = Color3.fromRGB(151, 161, 180)

-- Drag by header, including touch (Delta Android).
do
    local dragging, inputStart, frameStart, currentDragInput = false, nil, nil, nil
    table.insert(state.connections, heading.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            inputStart = input.Position
            frameStart = panel.Position
            local link
            link = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    link:Disconnect()
                end
            end)
        end
    end))
    table.insert(state.connections, heading.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            currentDragInput = input
        end
    end))
    table.insert(state.connections, UserInputService.InputChanged:Connect(function(input)
        if dragging and input == currentDragInput and frameStart and inputStart then
            local delta = input.Position - inputStart
            panel.Position = UDim2.new(frameStart.X.Scale, frameStart.X.Offset + delta.X,
                frameStart.Y.Scale, frameStart.Y.Offset + delta.Y)
        end
    end))
end

local api = {}
function api:Unload()
    if not state.alive then return end
    state.alive = false
    state.active = false
    state.currentTarget = nil
    for _, conn in ipairs(state.connections) do pcall(function() conn:Disconnect() end) end
    pcall(function() gui:Destroy() end)
    if environment.AtlasPvP_Instance == api then environment.AtlasPvP_Instance = nil end
end
api.Config = Configuration
api.State = state
environment.AtlasPvP_Instance = api

installOptionalAimHook()

-- Update chase and active target separately from skill execution.
task.spawn(function()
    while state.alive do
        if state.active then
            local target = refreshTarget()
            if target and charParts(LocalPlayer) and charParts(target) then
                applyFollow(target)
            end
        end
        task.wait(Configuration.TargetRefresh)
    end
end)

task.spawn(function()
    while state.alive do
        if state.active then
            local target = state.currentTarget or refreshTarget()
            if target and charParts(LocalPlayer) and charParts(target) then
                local gap = distanceFromPlayer(target)
                if gap <= Configuration.CastRange then
                    pcall(useCombos, target)
                else
                    state.message = "Inseguimento a " .. math.floor(gap) .. " studs"
                end
            else
                state.message = "Ricerca giocatori..."
            end
        end
        task.wait(0.28)
    end
end)

task.spawn(function()
    while state.alive do
        switch.Text = "AUTO PvP: " .. (state.active and "ON" or "OFF")
        switch.BackgroundColor3 = state.active and Color3.fromRGB(29, 123, 99) or Color3.fromRGB(93, 50, 60)
        modeButton.Text = state.targetMode == "NEAREST" and "BERSAGLIO: VICINO" or "BERSAGLIO: FISSO"
        meleeButton.Text = "MELEE: " .. (Configuration.UseMelee and "ON" or "OFF")
        fruitButton.Text = "FRUIT: " .. (Configuration.UseFruit and "ON" or "OFF")
        swordButton.Text = "SWORD: " .. (Configuration.UseSword and "ON" or "OFF")
        gunButton.Text = "GUN: " .. (Configuration.UseGun and "ON" or "OFF")
        followButton.Text = "INSEGUI: " .. (Configuration.AutoFollow and "ON" or "OFF")
        status.Text = "Stato: " .. (state.active and "ATTIVO" or "SPENTO")
        local target = state.currentTarget
        if target and charParts(target) then
            targetText.Text = "Target: " .. target.Name .. "  (" .. math.floor(distanceFromPlayer(target)) .. " studs)"
        else
            targetText.Text = "Target: nessuno"
        end
        actionText.Text = "Azione: " .. state.message
        task.wait(0.35)
    end
end)

warn("[Atlas PvP] Caricato. GUI pronta. Skill aiming: " .. (state.aimHook and "hook disponibile" or "hook non disponibile"))