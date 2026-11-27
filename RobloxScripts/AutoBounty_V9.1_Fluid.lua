local Runtime={stage="Bootstrap",connections={},errors={},closing=false}
function Runtime.notify(title,message)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification",{
            Title=title,Text=message,Duration=6
        })
    end)
end
function Runtime.connect(signal,callback)
    local connection=signal:Connect(function(...)
        if Runtime.closing then return end
        local ok,err=pcall(callback,...)
        if not ok then Runtime.report("Evento",err) end
    end)
    table.insert(Runtime.connections,connection)
    return connection
end
function Runtime.report(area,err)
    local message=tostring(err)
    local now=os.clock()
    local last=Runtime.errors[area] or -math.huge
    if now-last<3 then return end
    Runtime.errors[area]=now
    warn("[V9.1]["..area.."] "..message)
    if Runtime.diagnostic and Runtime.diagnostic.Parent then
        Runtime.diagnostic.Text=area..": "..message:sub(1,110)
    end
end
function Runtime.cleanup()
    if Runtime.closing then return end
    Runtime.closing=true
    if Runtime.stop then pcall(Runtime.stop) end
    if Runtime.release then pcall(Runtime.release) end
    for _,connection in ipairs(Runtime.connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(Runtime.connections)
    pcall(function()
        game:GetService("RunService"):UnbindFromRenderStep("AutoBountyAim")
    end)
    if Runtime.gui then
        pcall(function() Runtime.gui:Destroy() end)
        Runtime.gui=nil
    end
end

local function start(...)
-- V9.1 Fluid: dodge-aware camera lock, independent pointer dispatch and frame timing diagnostics.
local launchMode=...
local SessionTeleport=game:GetService("TeleportService")
local StateKey="AutoBountyFluidV81State"
local StateFile="AutoBountyFluidV81.state"
local function validState(value)
    return value=="on" or value=="off" or value=="closed"
end
local function readStateSaved()
    local ok,value=pcall(function() return SessionTeleport:GetTeleportSetting(StateKey) end)
    if ok and validState(value) then return value end
    if type(readfile)=="function" then
        local fileOk,saved=pcall(readfile,StateFile)
        if fileOk and validState(saved) then return saved end
    end
    return nil
end
local function saveState(value)
    local teleportOk=pcall(function() SessionTeleport:SetTeleportSetting(StateKey,value) end)
    local fileOk=false
    if type(writefile)=="function" then
        fileOk=pcall(writefile,StateFile,value)
    end
    return teleportOk or fileOk
end
local savedState=readStateSaved()
if savedState=="closed" and launchMode~="open" then
    Runtime.notify("Script chiuso", "Usa il caricamento manuale con open per riaprirlo.")
    return
end
if launchMode=="open" then savedState="on"; saveState("on") end

Runtime.stage="Attesa gioco"
local deadline=os.clock()+60
while not game:IsLoaded() and os.clock()<deadline do task.wait(0.1) end
if not game:IsLoaded() then error("Il gioco non si e caricato entro 60 secondi") end
Runtime.stage="Servizi Roblox"
local P=game:GetService("Players")
local RS=game:GetService("RunService")
local VIM
do
    local ok,service=pcall(function() return game:GetService("VirtualInputManager") end)
    if ok then VIM=service end
end
local LP=P.LocalPlayer
deadline=os.clock()+25
while not LP and os.clock()<deadline do task.wait(0.1); LP=P.LocalPlayer end
if not LP then error("LocalPlayer non disponibile") end
Runtime.stage="PlayerGui"
local PG=LP:WaitForChild("PlayerGui",20)
if not PG then error("PlayerGui non disponibile") end
if PG:FindFirstChild("AutoBountyV91Fluid") then
    if launchMode~="open" then return end
    PG.AutoBountyV91Fluid:Destroy()
    task.wait()
end
local Speed=250; local DodgeSpeed=400; local AttackRange=80; local MaxAttackTime=60; local Active,Closed=false,false; local Target,Started=nil,0; local Attachment,Velocity,FlyRoot
local Rotation,Generation=0,0; local Collision,Skipped={},{}; local Direction,Angle=1,0; local NextChange,NextDodge,DodgeUntil=0,0,0
local LastHealth,LastTarget
local EvadeBlend,ThreatTime,DamageUntil=0,0,0
local TargetVelocity=Vector3.zero
local TargetRoot,TargetPosition
local AimAcceleration=Vector3.zero
local LastMousePoint
local InputFailureUntil=0
local DodgeStart,DodgeDuration=0,0
local DodgeStrength=1
local MoveAcceleration=Vector3.zero
local AimPoint,AimAnchor
local AimLead=0
local AimSampleVelocity=Vector3.zero
local LastAimError=0
local AimRetryAt=0
local AimLastUpdate=0
local AimLastSample=0
local AimStableVelocity=Vector3.zero
local AimLastRaw=Vector3.zero
local AimOffset=Vector3.zero
local AimLastOffset=Vector3.zero
local AimMouseFailures=0
local AimMouseRetryAt=0
local RangeNow=14
local DodgeMaxRadius=21
local CastDistance=29
local RangeRefresh=0
local RangeTool
local Soru={enabled=true,next=0,busy=false,cooldown=15.5}
local Motion={
    angularAcceleration=0,radialRate=0,heightRate=0,velocity=Vector3.zero,
    threat=0,side=1,sideRate=0,approachTime=0,
    previousFacing=0,turnRate=0,evadeCount=0,
    lastEnemyVelocity=Vector3.zero,enemyAcceleration=Vector3.zero
}
local AimControl={
    lastPixelAt=0,lastPositionAt=0,prevRaw=Vector3.zero,angularError=0,
    samples={},confidence=0,observed=Vector3.zero,lastObserved=nil,
    lastObservedTime=0,innovation=0,frameInterval=1/60,source="root",
    lastOrigin=nil,lastLocalPosition=nil,originSpeed=0,localSpeed=0,
    direct=false,actualError=0,lastRender=0,renderGap=0,peakGap=0,
    pointer=nil,pointerBusy=false,pointerSerial=0,pointerEpoch=0,mouseErrors=0
}
local Water={
    enabled=true,part=nil,level=nil,nextProbe=0,character=nil,lastHit=0,
    params=nil,land=false,status="Attesa",nextVoxel=0,voxelLevel=nil,voxelPos=nil,
    planes={},planeSet={},nextDiscover=0,discovered=false,source="none",
    lastSafe=nil,lastProbePos=nil,stableLevel=nil,lastLand=0,corrections=0,
    nextStatus=0
}
local Buff={character=nil,nextAura=0,nextKen=0,nextRace=0,auraAttempt=false,kenAttempt=false,nextCheck=0}
local CombatGuard={clearSince=nil,nextScan=0,marker=nil,lastHealth=nil,lastDamage=0}
local TeleportService=game:GetService("TeleportService")
local HttpService=game:GetService("HttpService")
local AutoStart,AutoHop=savedState~="off",true
local EmptyDelay,JoinGrace,HopCooldown=18,25,30
local HopBusy,HopQueued=false,false
local EmptySince,NextHop,HopStarted=nil,0,0
local HopSerial=0
local FailedServers={}
local JoinedAt=os.clock()
local ScriptURL="https://raw.githubusercontent.com/LuigiMuscettola/LuigiMuscettola/main/RobloxScripts/AutoBounty_V9.1_Fluid.lua"
local RangeByCategory={
    melee={12,17,23},
    fightingstyle={12,17,23},
    sword={14,19,26},
    bloxfruit={15,21,30},
    fruit={15,21,30},
    gun={16,22,32}
}

local function alpha(dt,rate)
    return 1-math.exp(-math.clamp(dt,0,0.12)*rate)
end
local function flat(v) return Vector3.new(v.X,0,v.Z) end
local function smoothstep(v)
    v=math.clamp(v,0,1)
    return v*v*(3-2*v)
end
 local CastTarget,CastToken; local NextMouse,CastUntil=0,0; local MouseSupported=true; local AimRoot,AimPos,AimTime,AimVelocity=nil,nil,0,Vector3.zero
local RNG=Random.new(); local InOrbit=false; local OrbitRadius=15; local Pressed,Cache={},{}; local LastScan,LastProgress,BestDistance=0,0,math.huge
local AngularRate,OrbitBlend,RadiusNow,HeightNow=0,0,15,7; local AimDir,AimFrame,AimCamera; local NextParts=0; local CombatStarted=nil; local ScanInterval=0.4; local NextRace,NextKen=0,0; local KenChar; local KenTried=false; local AutoV4,AutoKen=true,true; local LastCast=setmetatable({},{__mode="k"}); local Categories={
    Melee=1,["Blox Fruit"]=2,Sword=3,Gun=4
}
local Keys={"Z","X","C","V","F"}
local Scheduler={
    tools=setmetatable({},{__mode="k"}),
    target=nil,targetHealth=nil,lastHit=0,lastSkill=0,
    lastEquip=0,emptySince=0,nextAction=0,
    successfulInputs=0,failedInputs=0,equips=0,
    lastTargetPosition=nil,nextTelemetry=0,stalled=false
}
local Tuning={
    equipTimeout=0.30,guiTimeout=0.12,skillHold=0.060,
    recovery=0.035,weaponRetry=0.22,unknownRetry=0.38,
    aimHz=144,dodgeThreshold=0.30,threatHorizon=0.36,
    minProgress=0.25,noDamageTimeout=38,
    attackTimeout=95,waterMargin=1.2
}
local function resetScheduler()
    Scheduler.target=nil
    Scheduler.targetHealth=nil
    Scheduler.lastHit=0
    Scheduler.lastSkill=0
    Scheduler.lastEquip=0
    Scheduler.emptySince=0
    Scheduler.nextAction=0
    Scheduler.lastTargetPosition=nil
    Scheduler.stalled=false
end
Runtime.stop=function() Active=false; Closed=true; HopSerial=HopSerial+1 end
Runtime.stage="Pulizia versioni precedenti"
for _,n in ipairs({
    "BloxAimTP","AutoBountyV6","AutoBountyV7",
    "AutoBountyV71","AutoBountyV72","AutoBountyV73",
    "PvPDiagnostic","AutoBountyV8","AutoBountyV74","AutoBountyV75","AutoBountyV76","AutoBountyV77","AutoBountyV76Fluid","AutoBountyV77Fluid","AutoBountyV78Fluid","AutoBountyV79Fluid","AutoBountyV80Fluid","AutoBountyV81Fluid","AutoBountyV82Fluid","AutoBountyV83Fluid","AutoBountyV84Fluid","AutoBountyV85Fluid","AutoBountyV86Fluid","AutoBountyV87Fluid","AutoBountyV88Fluid","AutoBountyV89Fluid","AutoBountyV90Fluid","AutoBountyV91Fluid"
}) do
    local old=PG:FindFirstChild(n)
    if old then pcall(function() old:Destroy() end) end end
pcall(function() RS:UnbindFromRenderStep("AutoBountyAim") end)
Runtime.stage="Creazione interfaccia"
local Gui=Instance.new("ScreenGui",PG); Runtime.gui=Gui; Gui.Name="AutoBountyV91Fluid"; Gui.ResetOnSpawn=false; Gui.DisplayOrder=999; local Main=Instance.new("Frame",Gui)
Main.Size=UDim2.fromOffset(270,452); Main.Position=UDim2.new(0.03,0,0.15,0); Main.BackgroundColor3=Color3.fromRGB(20,22,30); Main.Active=true; Main.Draggable=true
Instance.new("UICorner",Main)
local function label(txt,y,h)
    local l=Instance.new("TextLabel",Main); l.Size=UDim2.new(1,-12,0,h); l.Position=UDim2.fromOffset(6,y); l.BackgroundTransparency=1; l.TextColor3=Color3.new(1,1,1)
    l.Font=Enum.Font.GothamBold; l.TextSize=13; l.TextWrapped=true; l.Text=txt
    return l end
label("AUTO BOUNTY V9.1 FLUID",5,25)
local Button=Instance.new("TextButton",Main); Button.Size=UDim2.new(1,-20,0,42); Button.Position=UDim2.fromOffset(10,35)
Button.BackgroundColor3=Color3.fromRGB(170,40,40); Button.TextColor3=Color3.new(1,1,1); Button.Font=Enum.Font.GothamBold; Button.TextSize=16; Button.Text="AUTO BOUNTY: OFF"
Instance.new("UICorner",Button)
local Info=label("In attesa",82,30); local Scan=label("PvP ON*: 0 | OFF: 0",112,30); local Detail=label("Fruit V: OFF",142,30); local Powers=label("V4 / Istinto: AUTO",174,28)
local HopStatus=label("Server hop: ON",208,24)
local HopToggle=Instance.new("TextButton",Main)
HopToggle.Size=UDim2.new(1,-20,0,26)
HopToggle.Position=UDim2.fromOffset(10,234)
HopToggle.BackgroundColor3=Color3.fromRGB(35,110,78)
HopToggle.TextColor3=Color3.new(1,1,1)
HopToggle.Font=Enum.Font.GothamBold
HopToggle.TextSize=12
HopToggle.Text="AUTO SERVER: ON"
Instance.new("UICorner",HopToggle)
local CloseButton=Instance.new("TextButton",Main)
CloseButton.Size=UDim2.new(1,-20,0,28)
CloseButton.Position=UDim2.fromOffset(10,418)
CloseButton.BackgroundColor3=Color3.fromRGB(145,42,48)
CloseButton.TextColor3=Color3.new(1,1,1)
CloseButton.Font=Enum.Font.GothamBold
CloseButton.TextSize=12
CloseButton.Text="CHIUDI SCRIPT"
Instance.new("UICorner",CloseButton)
local WaterToggle=Instance.new("TextButton",Main)
WaterToggle.Size=UDim2.new(1,-20,0,26)
WaterToggle.Position=UDim2.fromOffset(10,266)
WaterToggle.BackgroundColor3=Color3.fromRGB(35,110,78)
WaterToggle.TextColor3=Color3.new(1,1,1)
WaterToggle.Font=Enum.Font.GothamBold
WaterToggle.TextSize=12
WaterToggle.Text="WATER WALK: ON"
Instance.new("UICorner",WaterToggle)
local SoruToggle=Instance.new("TextButton",Main)
SoruToggle.Size=UDim2.new(1,-20,0,26)
SoruToggle.Position=UDim2.fromOffset(10,298)
SoruToggle.BackgroundColor3=Color3.fromRGB(35,110,78)
SoruToggle.TextColor3=Color3.new(1,1,1)
SoruToggle.Font=Enum.Font.GothamBold
SoruToggle.TextSize=12
SoruToggle.Text="AUTO SORU: ON"
Instance.new("UICorner",SoruToggle)
local Diagnostic=label("Avvio...",330,42)
Diagnostic.TextSize=11
Runtime.diagnostic=Diagnostic
local Telemetry=label("Input: 0 | Cambio arma: 0",374,40)
Telemetry.TextSize=11
Runtime.stage="Controlli"
Runtime.connect(SoruToggle.Activated,function()
    Soru.enabled=not Soru.enabled
    SoruToggle.Text=Soru.enabled and "AUTO SORU: ON" or "AUTO SORU: OFF"
    SoruToggle.BackgroundColor3=Soru.enabled and Color3.fromRGB(35,110,78) or Color3.fromRGB(110,50,50)
end)
local function humanoid(p)
    return p and p.Parent and p.Character
        and p.Character:FindFirstChildOfClass("Humanoid") end
local function root(p)
    local h=humanoid(p)
    if not h or h.Health<=0 or not p.Character then return nil end
    local part=p.Character:FindFirstChild("HumanoidRootPart")
    return part and part:IsA("BasePart") and part:IsDescendantOf(workspace) and part or nil
end
local function normalize(s)
    return s:lower():gsub("[^%a%d]","") end
-- Water support: independent detection of terrain, queryable surfaces and map planes.
local function removeWaterSupport()
    if Water.part then Water.part:Destroy(); Water.part=nil end
    Water.level,Water.character,Water.params=nil,nil,nil
    Water.nextProbe,Water.lastHit,Water.nextVoxel=0,0,0
    Water.voxelLevel,Water.voxelPos=nil,nil
    Water.land=false
    Water.status="Attesa"
    Water.lastSafe,Water.lastProbePos,Water.stableLevel=nil,nil,nil
    Water.source="none"
end
local function isWaterPlane(part)
    if not part or not part:IsA("BasePart") or part==Water.part then return false end
    if part:IsA("Terrain") then return false end
    local name=normalize(part.Name)
    local explicit=name=="water" or name=="sea" or name=="ocean" or name=="waterplane"
        or name=="seawater" or name=="oceansurface" or name=="seasurface"
        or name=="waterlevel" or name=="oceanwater"
    local size=part.Size
    return explicit and size.X>=20 and size.Z>=20 and math.abs(part.CFrame.UpVector.Y)>0.90
end
local function waterHit(hit)
    return hit and (hit.Material==Enum.Material.Water or isWaterPlane(hit.Instance))
end
local function addWaterPlane(part)
    if isWaterPlane(part) and not Water.planeSet[part] then
        Water.planeSet[part]=true
        table.insert(Water.planes,part)
    end
end
local function discoverWaterPlanes()
    local now=os.clock()
    if Water.discovered and now<Water.nextDiscover then return end
    Water.discovered=true
    Water.nextDiscover=now+20
    local kept={}
    for _,part in ipairs(Water.planes) do
        if part.Parent and isWaterPlane(part) then
            table.insert(kept,part)
        else
            Water.planeSet[part]=nil
        end
    end
    Water.planes=kept
    -- Inspect common map containers rather than repeatedly walking all descendants.
    for _,child in ipairs(workspace:GetChildren()) do
        addWaterPlane(child)
        local n=normalize(child.Name)
        if n=="map" or n=="world" or n=="sea" or n=="ocean" or n=="water" or n=="terrain" then
            for _,part in ipairs(child:GetDescendants()) do
                addWaterPlane(part)
            end
        end
    end
end
local waterPlaneAdded=Runtime.connect(workspace.DescendantAdded,function(part)
    if part:IsA("BasePart") then addWaterPlane(part) end
end)
local function planeSurface(position)
    discoverWaterPlanes()
    local best=nil
    for _,part in ipairs(Water.planes) do
        if part.Parent then
            local rel=part.CFrame:PointToObjectSpace(position)
            local size=part.Size
            if math.abs(rel.X)<=size.X/2+0.4 and math.abs(rel.Z)<=size.Z/2+0.4 then
                local surface=part.CFrame:PointToWorldSpace(Vector3.new(rel.X,size.Y/2,rel.Z)).Y
                if math.abs(position.Y-surface)<=38 and (not best or surface>best) then
                    best=surface
                end
            end
        end
    end
    return best
end
local function terrainSurface(position)
    local now=os.clock()
    if now<Water.nextVoxel and Water.voxelPos and (position-Water.voxelPos).Magnitude<5 then
        return Water.voxelLevel
    end
    Water.nextVoxel=now+0.16
    Water.voxelPos=position
    local ok,result=pcall(function()
        local region=Region3.new(position-Vector3.new(1,24,1),position+Vector3.new(1,24,1)):ExpandToGrid(4)
        local materials,occupancy=workspace.Terrain:ReadVoxels(region,4)
        local bottom=region.CFrame.Position.Y-region.Size.Y/2
        local top=nil
        for x=1,#materials do
            for y=1,#materials[x] do
                for z=1,#materials[x][y] do
                    if materials[x][y][z]==Enum.Material.Water and occupancy[x][y][z]>0 then
                        local candidate=bottom+(y-1)*4+4*occupancy[x][y][z]
                        if not top or candidate>top then top=candidate end
                    end
                end
            end
        end
        return top
    end)
    Water.voxelLevel=ok and result or nil
    return Water.voxelLevel
end
local function probeWater(r,h)
    if not Water.params then
        Water.params=RaycastParams.new()
        Water.params.FilterType=Enum.RaycastFilterType.Exclude
        Water.params.IgnoreWater=false
    end
    local exclusions={LP.Character}
    if Water.part then table.insert(exclusions,Water.part) end
    local characters=workspace:FindFirstChild("Characters")
    local enemies=workspace:FindFirstChild("Enemies")
    if characters then table.insert(exclusions,characters) end
    if enemies then table.insert(exclusions,enemies) end
    Water.params.FilterDescendantsInstances=exclusions
    local position=r.Position
    local cast=workspace:Raycast(position+Vector3.new(0,32,0),Vector3.new(0,-88,0),Water.params)
    if waterHit(cast) then return cast.Position.Y,false,"raycast" end
    -- A solid floor underneath the feet takes precedence over an ocean plane.
    local feet=position.Y-math.max(2.5,h.HipHeight+r.Size.Y/2)
    if cast and cast.Instance and cast.Instance:IsA("BasePart") and cast.Instance.CanCollide
        and cast.Position.Y>=feet-1.4 and cast.Position.Y<=position.Y+1 then
        return nil,true,"land"
    end
    local plane=planeSurface(position)
    if plane then
        if cast and cast.Position.Y>plane+0.8 and cast.Position.Y<position.Y+1 then
            return nil,true,"land"
        end
        return plane,false,"map plane"
    end
    local terrain=terrainSurface(position)
    if terrain then return terrain,false,"terrain voxels" end
    return nil,false,"unknown"
end
local function createWaterSupport(r,floor)
    if not Water.part or not Water.part.Parent then
        local part=Instance.new("Part")
        part.Name="AutoBountyWaterSupport"
        part.Anchored=true
        part.CanCollide=true
        part.CanTouch=false
        part.CanQuery=false
        part.Transparency=1
        part.Size=Vector3.new(36,0.8,36)
        part.CFrame=CFrame.new(r.Position.X,floor-0.4,r.Position.Z)
        part.Parent=workspace
        Water.part=part
    end
    Water.part.CFrame=CFrame.new(r.Position.X,floor-0.4,r.Position.Z)
end
local function updateWater()
    if Closed or not Active or not Water.enabled or HopBusy then
        if Water.character or Water.part then removeWaterSupport() end
        return
    end
    local r,h=root(LP),humanoid(LP)
    if not r or not h or h.SeatPart then
        removeWaterSupport()
        return
    end
    if Water.character~=LP.Character then
        removeWaterSupport()
        Water.character=LP.Character
    end
    local now=os.clock()
    local moved=not Water.lastProbePos or (r.Position-Water.lastProbePos).Magnitude>4
    if now>=Water.nextProbe or moved then
        Water.nextProbe=now+0.045
        Water.lastProbePos=r.Position
        local level,land,source=probeWater(r,h)
        Water.land=land
        if level then
            Water.level=level
            Water.lastHit=now
            Water.source=source
            Water.stableLevel=level
        elseif land then
            Water.level=nil
            Water.lastLand=now
        elseif now-Water.lastHit>0.20 then
            Water.level=nil
        end
    end
    if not Water.level or Water.land then
        if Water.part then Water.part:Destroy(); Water.part=nil end
        Water.status=Water.land and "Terra" or "Acqua non rilevata"
        return
    end
    local floor=Water.level+Tuning.waterMargin
    local clearance=math.max(2.5,h.HipHeight+r.Size.Y/2)+0.25
    local safeY=floor+clearance
    local y=r.Position.Y
    Water.status="Superficie rilevata"
    if y>safeY+16 or y<Water.level-28 then
        if Water.part then Water.part:Destroy(); Water.part=nil end
        return
    end
    if Velocity and Velocity.Parent then
        if Water.part then Water.part:Destroy(); Water.part=nil end
        local current=Velocity.VectorVelocity
        if y<safeY+1.2 then
            local minimum=math.clamp((safeY-y)*18,0,95)
            Velocity.VectorVelocity=Vector3.new(current.X,math.max(current.Y,minimum),current.Z)
        end
    else
        createWaterSupport(r,floor)
    end
    if y<safeY-0.22 then
        local lift=safeY-y
        r.CFrame=r.CFrame+Vector3.new(0,lift,0)
        local v=r.AssemblyLinearVelocity
        r.AssemblyLinearVelocity=Vector3.new(v.X,math.max(0,v.Y),v.Z)
        Water.corrections=Water.corrections+1
    end
    Water.lastSafe=r.Position
end
local waterConnection=Runtime.connect(RS.Stepped,function()
    local ok,err=pcall(updateWater)
    if not ok then Runtime.report("Acqua",err); removeWaterSupport() end
end)
Runtime.connect(WaterToggle.Activated,function()
    Water.enabled=not Water.enabled
    if not Water.enabled then removeWaterSupport() end
    WaterToggle.Text=Water.enabled and "WATER WALK: ON" or "WATER WALK: OFF"
    WaterToggle.BackgroundColor3=Water.enabled and Color3.fromRGB(35,110,78) or Color3.fromRGB(110,50,50)
end)
local function rangeProfile(tool)
    local key=tool and normalize(tool.ToolTip or "") or ""
    return RangeByCategory[key] or RangeByCategory.bloxfruit
end
local function classify(p)
    if not p or p==LP or p.Parent~=P then return false,false end
    local yes,no=false,false
    local function scan(o)
        if not o then return end
        local function check(k,v)
            if type(v)~="boolean" then return end
            local n=normalize(k)
            if n=="pvpdisabled" then if v then no=true else yes=true end
            elseif n=="pvpenabled" then if v then yes=true else no=true end
            elseif n=="safezone" or n=="insafezone" then if v then no=true end end end
        for k,v in pairs(o:GetAttributes()) do check(k,v) end
        for _,v in ipairs(o:GetChildren()) do if v:IsA("BoolValue") then check(v.Name,v.Value) end end end
    scan(p); scan(p.Character)
    for _,n in ipairs({"Data","Stats","Status"}) do
        scan(p:FindFirstChild(n)); if p.Character then scan(p.Character:FindFirstChild(n)) end end
    local h=humanoid(p)
    if h and h.Health<=0 or p.Character and p.Character:FindFirstChildOfClass("ForceField") then no=true end
    return not no,yes and not no end
local function pvp(p)
    if not p or p.Parent~=P then return false end
    local h=humanoid(p)
    if not h or h.Health<=0 or p.Character and p.Character:FindFirstChildOfClass("ForceField") then return false end
    local c=Cache[p]; local now=os.clock()
    if c and c.char==p.Character and now-c.at<ScanInterval then return c.allowed end
    local allowed,yes=classify(p); Cache[p]={allowed=allowed,yes=yes,at=now,char=p.Character}
    return allowed end
local function findTarget()
    local r=root(LP)
    local best,bestScore=nil,math.huge
    local on,off,loaded,confirmed,unknown=0,0,0,0,0
    local now=os.clock()
    for _,p in ipairs(P:GetPlayers()) do
        if p~=LP then
            local allowed,yes=classify(p)
            Cache[p]={allowed=allowed,yes=yes,at=now,char=p.Character}
            if allowed then
                on=on+1
                if yes then confirmed=confirmed+1 else unknown=unknown+1 end
                local t=root(p)
                if t then
                    loaded=loaded+1
                    if r and (Skipped[p.UserId] or 0)<=now then
                        local delta=t.Position-r.Position
                        local velocity=t.AssemblyLinearVelocity
                        -- Prefer verified PvP candidates, then nearby and reachable ones.
                        local score=delta.Magnitude+math.abs(delta.Y)*0.20
                        if not yes then score=score+100000 end
                        if velocity.Magnitude>150 then score=score+12 end
                        if p==Target then score=score-6 end
                        if score<bestScore then best,bestScore=p,score end
                    end
                end
            else
                off=off+1
            end
        end
    end
    Scan.Text="PvP ON: "..confirmed.." | ?: "..unknown.." | OFF: "..off.." | Load: "..loaded
    return best,on,loaded
end
local function restore()
    for p,v in pairs(Collision) do
        if p.Parent then p.CanCollide=v end end
    table.clear(Collision); NextParts=0 end
local function stopMovement()
    if Velocity then Velocity:Destroy() Velocity=nil end
    if Attachment then Attachment:Destroy() Attachment=nil end
    if FlyRoot and FlyRoot.Parent then
        local v=FlyRoot.AssemblyLinearVelocity
        FlyRoot.AssemblyLinearVelocity=Vector3.new(math.clamp(v.X,-18,18),math.clamp(v.Y,-20,20),math.clamp(v.Z,-18,18))
    end
    FlyRoot=nil
    LastHealth,LastTarget,TargetRoot,TargetPosition=nil,nil,nil,nil; AngularRate,OrbitBlend,EvadeBlend=0,0,0
    ThreatTime,DamageUntil=0,0; TargetVelocity=Vector3.zero; InOrbit=false
    DodgeStart,DodgeDuration=0,0; MoveAcceleration=Vector3.zero
    Motion.angularAcceleration,Motion.radialRate,Motion.heightRate=0,0,0; Motion.velocity=Vector3.zero
    Motion.threat,Motion.side,Motion.sideRate=0,Direction,0
    Motion.previousFacing,Motion.turnRate=0,0
    Motion.lastEnemyVelocity,Motion.enemyAcceleration=Vector3.zero,Vector3.zero
    RangeNow,DodgeMaxRadius,CastDistance=14,21,29; RangeTool=nil; RangeRefresh=0
    restore() end
local function startMovement(r)
    if FlyRoot==r and Velocity and Velocity.Parent and Attachment and Attachment.Parent then return end
    stopMovement()
    FlyRoot=r; Attachment=Instance.new("Attachment",r); Attachment.Name="AutoBountyAttachment"; Velocity=Instance.new("LinearVelocity",r); Velocity.Name="AutoBountyVelocity"; Velocity.Attachment0=Attachment; Velocity.RelativeTo=Enum.ActuatorRelativeTo.World
    Velocity.VelocityConstraintMode=Enum.VelocityConstraintMode.Vector; Velocity.ForceLimitsEnabled=false; Velocity.VectorVelocity=r.AssemblyLinearVelocity end
local function clampVector(v,max)
    if v.X~=v.X or v.Y~=v.Y or v.Z~=v.Z then return Vector3.zero end
    local m=v.Magnitude
    if m>max and m>0 then return v*(max/m) end
    return v
end
local function smootherstep(x)
    x=math.clamp(x,0,1)
    return x*x*x*(x*(x*6-15)+10)
end
local function dodge(now,urgent,delta,forward)
    -- Preserve orbital direction: avoid a hard reversal at dodge onset.
    DodgeStart=now
    DodgeDuration=urgent and 0.62 or 0.58
    DodgeStrength=urgent and 1 or 0.95
    DodgeUntil=now+DodgeDuration
    NextDodge=DodgeUntil+(urgent and 0.12 or 0.19)
    Motion.evadeCount=Motion.evadeCount+1
    NextChange=NextDodge+0.8
end
-- Exact critically damped spring, independent of the frame rate.
local function springStep(value,velocity,goal,frequency,dt)
    local x=value-goal
    local j=velocity+frequency*x
    local decay=math.exp(-frequency*dt)
    return goal+(x+j*dt)*decay,(velocity-frequency*j*dt)*decay
end
local function updateMovement(dt)
    if Closed or not Active or HopBusy or not Target then
        if Velocity then stopMovement() end
        return
    end
    dt=math.clamp(dt,0,0.08)
    if dt<=0 then return end
    local r,t,h=root(LP),root(Target),humanoid(LP)
    if not r or not t or not h or not pvp(Target) then
        if Velocity then stopMovement() end
        return
    end
    startMovement(r)
    local now=os.clock()
    local delta=r.Position-t.Position
    local distance=delta.Magnitude
    local horizontal=flat(delta)
    local raw=clampVector(t.AssemblyLinearVelocity,260)
    if now>=RangeRefresh then
        RangeRefresh=now+0.045
        RangeTool=LP.Character and LP.Character:FindFirstChildOfClass("Tool")
    end
    local profile=rangeProfile(RangeTool)
    RangeNow=RangeNow+(profile[1]-RangeNow)*alpha(dt,18)
    DodgeMaxRadius=profile[2]
    CastDistance=profile[3]
    if LastTarget~=Target or TargetRoot~=t then
        LastTarget,TargetRoot=Target,t
        Angle=horizontal.Magnitude>0.01 and math.atan2(horizontal.Z,horizontal.X) or 0
        DodgeUntil,NextDodge=0,now+0.15
        DodgeStart,DodgeDuration=0,0; MoveAcceleration=Vector3.zero
        Motion.angularAcceleration,Motion.radialRate,Motion.heightRate=0,0,0; Motion.velocity=Vector3.zero
        Motion.threat,Motion.side,Motion.sideRate=0,Direction,0
        Motion.previousFacing,Motion.turnRate=0,0
        Motion.lastEnemyVelocity,Motion.enemyAcceleration=raw,Vector3.zero
        NextChange=now+1.8
        LastHealth=h.Health
        InOrbit=false
        OrbitRadius=RangeNow
        RadiusNow,HeightNow=RangeNow,3.5
        AngularRate,OrbitBlend,EvadeBlend=0,0,0
        ThreatTime,DamageUntil=0,0
        TargetVelocity=raw
        TargetPosition=t.Position
    end
    if TargetPosition and (t.Position-TargetPosition).Magnitude>math.max(45,dt*300) then
        MoveAcceleration=Vector3.zero
        Motion.angularAcceleration=0
        TargetVelocity=raw
        Angle=horizontal.Magnitude>0.01 and math.atan2(horizontal.Z,horizontal.X) or Angle
        OrbitBlend=0
    else
        local fastChange=TargetVelocity.Magnitude>8 and raw.Magnitude>8 and TargetVelocity.Unit:Dot(raw.Unit)<0.45
        TargetVelocity=TargetVelocity:Lerp(raw,alpha(dt,fastChange and 40 or 20))
    end
    TargetPosition=t.Position
    if LastHealth and h.Health<LastHealth-0.05 then DamageUntil=now+0.5 end
    LastHealth=h.Health
    local damaged=now<DamageUntil
    local relativeVelocity=TargetVelocity-r.AssemblyLinearVelocity
    local facing=distance>0.01 and math.max(0,t.CFrame.LookVector:Dot(delta.Unit)) or 0
    local closing=distance>0.01 and relativeVelocity:Dot(delta.Unit) or 0
    local timeToClosest=math.clamp(delta:Dot(relativeVelocity)/math.max(1,relativeVelocity:Dot(relativeVelocity)),0,Tuning.threatHorizon)
    local closest=(delta-relativeVelocity*timeToClosest).Magnitude
    local proximity=1-smoothstep((distance-12)/37)
    local intercept=(1-smoothstep((closest-7)/24))*smoothstep(closing/35)
    local facingChange=(facing-Motion.previousFacing)/math.max(dt,0.005)
    Motion.previousFacing=facing
    Motion.turnRate=Motion.turnRate+(math.clamp(facingChange,0,10)-Motion.turnRate)*alpha(dt,25)
    local turningThreat=proximity*smoothstep(Motion.turnRate/4)*facing
    local threatScore=math.max(proximity*facing,intercept,turningThreat,damaged and 1 or 0)
    Motion.threat=Motion.threat+(threatScore-Motion.threat)*alpha(dt,threatScore>Motion.threat and 48 or 16)
    ThreatTime=Motion.threat>Tuning.dodgeThreshold and math.min(0.25,ThreatTime+dt) or math.max(0,ThreatTime-dt*2)
    if now>=NextDodge and distance<62 and (damaged or threatScore>0.78 or ThreatTime>=0.025) then
        dodge(now,damaged,delta,t.CFrame.LookVector)
        ThreatTime,DamageUntil=0,0
    end
    local evading=now<DodgeUntil
    if not evading and EvadeBlend<0.02 and now>=NextChange then
        -- Preserve direction and vary radius rather than making periodic hard reversals.
        OrbitRadius=RangeNow+RNG:NextNumber(-0.8,0.8)
        NextChange=now+RNG:NextNumber(3.4,5.2)
    end
    local phase=DodgeDuration>0 and math.clamp((now-DodgeStart)/DodgeDuration,0,1) or 1
    local envelope=0
    if evading then
        if phase<0.20 then envelope=smootherstep(phase/0.20)
        elseif phase<0.48 then envelope=1
        else envelope=1-smootherstep((phase-0.48)/0.52) end
    end
    EvadeBlend=EvadeBlend+(envelope*DodgeStrength-EvadeBlend)*alpha(dt,26)
    local evade=EvadeBlend
    if distance<CastDistance+5 then InOrbit=true elseif distance>CastDistance+14 then InOrbit=false end
    OrbitBlend=OrbitBlend+((InOrbit and 1 or 0)-OrbitBlend)*alpha(dt,8)
    local blend=smoothstep(OrbitBlend)
    local rate=Direction*(2.85+evade*3.0+0.48*Motion.threat)
    AngularRate,Motion.angularAcceleration=springStep(AngularRate,Motion.angularAcceleration,rate,19,dt)
    if not InOrbit and OrbitBlend<0.035 and horizontal.Magnitude>0.01 then
        Angle=math.atan2(horizontal.Z,horizontal.X)
    else
        Angle=(Angle+dt*AngularRate)%(2*math.pi)
    end
    local casting=CastTarget==Target and CastToken==Generation
    local activeMax=casting and math.max(RangeNow+2,DodgeMaxRadius-2) or DodgeMaxRadius
    local baseRadius=math.clamp(RangeNow+(OrbitRadius-RangeNow)*0.3+0.38*math.sin(now*1.8),10,activeMax)
    local wantedRadius=baseRadius+(activeMax-baseRadius)*math.max(evade,Motion.threat*0.22)
    RadiusNow,Motion.radialRate=springStep(RadiusNow,Motion.radialRate,wantedRadius,20,dt)
    RadiusNow=math.clamp(RadiusNow,10,DodgeMaxRadius)
    HeightNow,Motion.heightRate=springStep(HeightNow,Motion.heightRate,3.0+0.45*math.sin(now*1.6)+1.8*evade,16,dt)
    local nearBlend=1-smoothstep((distance-22)/30)
    local leadTime=0.035+0.08*(1-nearBlend)
    local enemyAcceleration=clampVector((raw-Motion.lastEnemyVelocity)/math.max(dt,0.005),320)
    Motion.enemyAcceleration=Motion.enemyAcceleration:Lerp(enemyAcceleration,alpha(dt,14))
    Motion.lastEnemyVelocity=raw
    local prediction=clampVector(TargetVelocity*leadTime+Motion.enemyAcceleration*(0.5*leadTime*leadTime),5+19*(1-nearBlend))
    local center=t.Position+prediction
    local radial=Vector3.new(math.cos(Angle),0,math.sin(Angle))
    local tangent=Vector3.new(-radial.Z,0,radial.X)
    local approachDir=horizontal.Magnitude>0.01 and horizontal.Unit or radial
    local approach=center+approachDir*RangeNow+Vector3.new(0,3.5,0)
    local orbit=center+radial*RadiusNow+Vector3.new(0,HeightNow,0)
    local destination=approach:Lerp(orbit,blend)
    if Water.enabled and Water.level and r.Position.Y>Water.level-12 and r.Position.Y<Water.level+18 then
        local minimum=Water.level+math.max(2.5,h.HipHeight+r.Size.Y/2)+Tuning.waterMargin+0.25
        destination=Vector3.new(destination.X,math.max(destination.Y,minimum),destination.Z)
    end
    -- Limit the relative speed in close orbit, not the target's own movement.
    local relativeCap=(Speed*(1-blend)+(90+evade*78)*blend)
    local targetFeed=clampVector(TargetVelocity,230)
    local correction=(destination-r.Position)*(8+1.2*evade)+tangent*(RadiusNow*AngularRate*blend)
    correction=correction+radial*(Motion.radialRate*blend)+Vector3.new(0,Motion.heightRate*blend,0)
    local relative=clampVector(correction,relativeCap)
    if horizontal.Magnitude>0.01 then
        local outward=horizontal.Unit
        local radialSpeed=relative:Dot(outward)
        local maxOut=math.max(0,(DodgeMaxRadius-horizontal.Magnitude)*5)
        if horizontal.Magnitude>DodgeMaxRadius+1 then
            maxOut=-math.min(100,(horizontal.Magnitude-DodgeMaxRadius)*8)
        end
        if radialSpeed>maxOut then relative=relative-outward*(radialSpeed-maxOut) end
        if horizontal.Magnitude<9 and radialSpeed<0 then
            local v=relative:Dot(outward)
            relative=relative-outward*math.min(0,v)+outward*math.min(45,(9-horizontal.Magnitude)*9)
        end
    end
    local limit=math.min(DodgeSpeed,math.max(Speed,targetFeed.Magnitude+relativeCap))
    local desired=clampVector(targetFeed+relative,limit)
    local current=Velocity.VectorVelocity
    local wantedAcceleration=clampVector((desired-current)*(12+evade*6),1600+evade*2000)
    local jerkLimit=19000+evade*18000
    local oldAcceleration=MoveAcceleration
    MoveAcceleration=MoveAcceleration+clampVector(wantedAcceleration-MoveAcceleration,jerkLimit*dt)
    local nextVelocity=current+(oldAcceleration+MoveAcceleration)*(0.5*dt)
    local difference=desired-current
    -- Stop acceleration from overshooting the desired velocity.
    if difference.Magnitude<0.15 then
        nextVelocity=desired
        MoveAcceleration=Vector3.zero
    elseif (desired-nextVelocity):Dot(difference)<0 then
        nextVelocity=desired
        MoveAcceleration=MoveAcceleration:Lerp(Vector3.zero,alpha(dt,18))
    end
    -- Let excess speed taper rather than clipping it when the dodge ends.
    local cap=math.max(limit,current.Magnitude-1200*dt)
    nextVelocity=clampVector(nextVelocity,cap)
    -- Final vertical guard, after the movement controller has calculated velocity.
    if Water.enabled and Water.level and not Water.land then
        local safeY=Water.level+math.max(2.5,h.HipHeight+r.Size.Y/2)+Tuning.waterMargin+0.25
        if r.Position.Y<safeY+1.0 and r.Position.Y>Water.level-24 then
            nextVelocity=Vector3.new(nextVelocity.X,math.max(nextVelocity.Y,math.clamp((safeY-r.Position.Y)*15,0,85)),nextVelocity.Z)
        end
    end
    Velocity.VectorVelocity=nextVelocity
end
local movement=Runtime.connect(RS.Heartbeat,function(dt)
    if Active then local ok,err=pcall(updateMovement,dt); if not ok then Runtime.report("Movimento",err); stopMovement(); Detail.Text="Volo: "..tostring(err):sub(1,45) end end
end)
local noclip=Runtime.connect(RS.Stepped,function()
    if not Active or not Velocity or not LP.Character then
        if next(Collision) then restore() end; return
    end
    local now=os.clock(); local char=LP.Character
    if now>=NextParts then NextParts=now+0.3
        for _,v in ipairs(char:GetDescendants()) do if v:IsA("BasePart") and Collision[v]==nil then Collision[v]=v.CanCollide end end
    end
    for v,original in pairs(Collision) do
        if not v.Parent then Collision[v]=nil elseif not v:IsDescendantOf(char) then v.CanCollide=original; Collision[v]=nil elseif v.CanCollide then v.CanCollide=false end end
end)
local function resetAim()
    AimRoot,AimPos,AimTime=nil,nil,0
    AimDir,AimFrame,AimCamera=nil,nil,nil
    AimVelocity,AimAcceleration,AimSampleVelocity=Vector3.zero,Vector3.zero,Vector3.zero
    AimStableVelocity,AimLastRaw=Vector3.zero,Vector3.zero
    AimOffset,AimLastOffset=Vector3.zero,Vector3.zero
    AimPoint,AimAnchor,LastMousePoint=nil,nil,nil
    AimLead,NextMouse,LastAimError,AimRetryAt=0,0,0,0
    AimLastUpdate,AimLastSample=0,0
    AimMouseFailures,AimMouseRetryAt=0,0
    AimControl.lastPixelAt,AimControl.lastPositionAt,AimControl.angularError=0,0,0
    AimControl.prevRaw=Vector3.zero
    table.clear(AimControl.samples)
    AimControl.confidence,AimControl.innovation=0,0
    AimControl.observed=Vector3.zero
    AimControl.lastObserved,AimControl.lastObservedTime=nil,0
    AimControl.frameInterval=1/60
    AimControl.lastOrigin,AimControl.lastLocalPosition=nil,nil
    AimControl.originSpeed,AimControl.localSpeed=0,0
    AimControl.direct,AimControl.actualError=false,0
    AimControl.lastRender,AimControl.renderGap,AimControl.peakGap=0,0,0
    AimControl.pointer=nil
    AimControl.pointerEpoch=AimControl.pointerEpoch+1
end
local function rotateTowards(from,to,fraction)
    local dot=math.clamp(from:Dot(to),-1,1)
    if dot>0.99999 then return to end
    local angle=math.acos(dot)
    local axis=from:Cross(to)
    if axis.Magnitude<0.0001 then
        local helper=math.abs(from.Y)<0.95 and Vector3.yAxis or Vector3.xAxis
        axis=from:Cross(helper)
    end
    return CFrame.fromAxisAngle(axis.Unit,angle*math.clamp(fraction,0,1)):VectorToWorldSpace(from).Unit
end
-- Keep input dispatch independent from the camera render callback. Only the latest
-- projected point is retained; no FIFO backlog can build up during fast strafing.
local function queueAimPointer(pixel,force)
    if not VIM or not Active or Closed or HopBusy then return end
    AimControl.pointerSerial=AimControl.pointerSerial+1
    AimControl.pointer={
        pixel=pixel,serial=AimControl.pointerSerial,epoch=AimControl.pointerEpoch,
        generation=Generation,target=Target,force=force,at=os.clock()
    }
end
local function dispatchAimPointer()
    if AimControl.pointerBusy or not VIM or Closed or not Active or HopBusy then return end
    local item=AimControl.pointer
    if not item then return end
    local now=os.clock()
    if not MouseSupported and now<AimMouseRetryAt then return end
    if item.generation~=Generation or item.target~=Target or item.epoch~=AimControl.pointerEpoch or now-item.at>0.10 then
        AimControl.pointer=nil
        return
    end
    local pixel=item.pixel
    if not item.force and LastMousePoint and (pixel-LastMousePoint).Magnitude<0.20 and now-AimControl.lastPixelAt<0.025 then
        AimControl.pointer=nil
        return
    end
    AimControl.pointerBusy=true
    AimControl.pointer=nil
    local ok,err=pcall(function()
        VIM:SendMouseMoveEvent(math.floor(pixel.X+0.5),math.floor(pixel.Y+0.5),game)
    end)
    AimControl.pointerBusy=false
    if item.epoch~=AimControl.pointerEpoch or item.generation~=Generation then return end
    MouseSupported=ok
    if ok then
        LastMousePoint=pixel
        AimControl.lastPixelAt=os.clock()
        AimMouseFailures=0
    else
        AimMouseFailures=AimMouseFailures+1
        AimControl.mouseErrors=AimControl.mouseErrors+1
        AimMouseRetryAt=os.clock()+math.min(2,0.10*2^math.min(AimMouseFailures,4))
        Runtime.report("Puntatore",err)
    end
end
task.spawn(function()
    while not Closed do
        RS.Heartbeat:Wait()
        if Active and Target and not HopBusy then
            local ok,err=pcall(dispatchAimPointer)
            if not ok then
                AimControl.pointerBusy=false
                Runtime.report("Puntatore",err)
            end
        end
    end
end)
local function aimAt(p,skill,force,renderDt)
    local t,r,cam=root(p),root(LP),workspace.CurrentCamera
    if not Active or Closed or HopBusy or p~=Target or not t or not r or not cam or not pvp(p) then return false end
    local now=os.clock()
    local position=t.Position
    local torso=p.Character:FindFirstChild("UpperTorso") or p.Character:FindFirstChild("Torso")
    local bodyOffset=Vector3.new(0,0.8,0)
    if torso and torso:IsA("BasePart") then
        bodyOffset=bodyOffset:Lerp(clampVector(torso.Position-position,3),0.45)
    end
    local raw=clampVector(t.AssemblyLinearVelocity,300)
    if AimRoot~=t or AimCamera~=cam then
        resetAim()
        AimRoot,AimPos,AimTime,AimCamera=t,position,now,cam
        AimVelocity,AimStableVelocity,AimSampleVelocity,AimLastRaw=raw,raw,raw,raw
        AimOffset,AimLastOffset=bodyOffset,bodyOffset
        AimLastUpdate=now
    end
    local dt=math.clamp(now-AimLastUpdate,0,0.08)
    if renderDt and renderDt>0 then dt=math.clamp(renderDt,0,0.08) end
    if AimLastUpdate==0 then dt=renderDt or 1/60 end
    AimLastUpdate=now
    local origin=cam.CFrame.Position
    if dt>0.001 then
        if AimControl.lastOrigin then
            AimControl.originSpeed=(origin-AimControl.lastOrigin).Magnitude/dt
        end
        if AimControl.lastLocalPosition then
            AimControl.localSpeed=(r.Position-AimControl.lastLocalPosition).Magnitude/dt
        end
        AimControl.lastOrigin=origin
        AimControl.lastLocalPosition=r.Position
    end
    local fastMotion=now<DodgeUntil or EvadeBlend>0.025 or AimControl.originSpeed>22 or AimControl.localSpeed>40
    local direct=force or skill or fastMotion
    AimControl.direct=direct
    if renderDt and renderDt>0 and renderDt<0.15 then
        AimControl.frameInterval=AimControl.frameInterval+(renderDt-AimControl.frameInterval)*0.15
        AimControl.renderGap=renderDt
        AimControl.peakGap=math.max(renderDt,AimControl.peakGap*0.985)
        AimControl.lastRender=now
    end
    -- Observe actual position changes, not repeated render frames of the same replicated sample.
    if not AimControl.lastObserved then
        AimControl.lastObserved=position
        AimControl.lastObservedTime=now
    elseif (position-AimControl.lastObserved).Magnitude>0.025 then
        local elapsed=now-AimControl.lastObservedTime
        local displacement=position-AimControl.lastObserved
        if elapsed>0.005 and elapsed<0.18 and displacement.Magnitude<math.max(16,elapsed*380) then
            local observed=clampVector(displacement/elapsed,300)
            local mismatch=(observed-raw).Magnitude
            local quality=1-math.clamp(mismatch/180,0,1)
            AimControl.observed=AimControl.observed:Lerp(observed,0.55)
            AimControl.confidence=AimControl.confidence+(quality-AimControl.confidence)*0.35
            AimControl.innovation=mismatch
        else
            AimControl.confidence=0
            AimControl.observed=raw
        end
        AimControl.lastObserved,AimControl.lastObservedTime=position,now
    elseif now-AimControl.lastObservedTime>0.10 then
        AimControl.confidence=AimControl.confidence*0.8
    end
    -- Avoid advancing the same filter twice when a cast and render coincide.
    local sampleDt=now-AimTime
    if sampleDt>=1/144 then
        local displacement=position-AimPos
        local jump=sampleDt>0.25 or displacement.Magnitude>math.max(26,sampleDt*380)
        if jump then
            AimVelocity,AimStableVelocity,AimSampleVelocity=raw,raw,raw
            AimAcceleration=Vector3.zero
            AimDir,AimPoint=nil,nil
            AimLead=0
        else
            local measured=clampVector(displacement/sampleDt,300)
            local disagreement=(raw-measured).Magnitude
            local trust=math.clamp(0.22-disagreement/600,0.04,0.22)
            if displacement.Magnitude<0.035 and raw.Magnitude>5 then trust=0 end
            local sample=raw:Lerp(measured,trust)
            local oldVelocity=AimSampleVelocity
            local reversal=oldVelocity.Magnitude>8 and sample.Magnitude>8
                and oldVelocity.Unit:Dot(sample.Unit)<0.40
            local braking=sample.Magnitude<oldVelocity.Magnitude*0.45
            if reversal or braking then
                AimSampleVelocity=sample
                AimStableVelocity=sample
                AimAcceleration=Vector3.zero
            else
                AimSampleVelocity=oldVelocity:Lerp(sample,alpha(sampleDt,105))
                AimStableVelocity=AimStableVelocity:Lerp(AimSampleVelocity,alpha(sampleDt,92))
                local acceleration=clampVector((AimSampleVelocity-oldVelocity)/sampleDt,420)
                AimAcceleration=AimAcceleration:Lerp(acceleration,alpha(sampleDt,22))
            end
            AimVelocity=AimStableVelocity
        end
        AimPos,AimTime=position,now
        AimLastRaw=raw
    end
    -- Use the latest replicated position directly; only smooth the animated body offset.
    AimOffset=AimOffset:Lerp(bodyOffset,alpha(dt,direct and 160 or 90))
    local currentVelocity=AimVelocity:Lerp(raw,0.88)
    if AimControl.confidence>0.35 and now-AimControl.lastObservedTime<0.08 then
        currentVelocity=currentVelocity:Lerp(AimControl.observed,AimControl.confidence*0.20)
    end
    if raw.Magnitude<3 and AimVelocity.Magnitude<6 then currentVelocity=Vector3.zero end
    if raw.Magnitude>8 and currentVelocity.Magnitude>8 and raw.Unit:Dot(currentVelocity.Unit)<0.5 then
        currentVelocity=raw
    end
    local distance=(position-r.Position).Magnitude
    local desiredLead=skill and math.clamp(AimControl.frameInterval*0.36+distance/2900,0.005,0.032) or math.clamp(distance/6000,0.002,0.014)
    if AimControl.innovation>80 then desiredLead=desiredLead*0.65 end
    if currentVelocity.Magnitude>8 and raw.Magnitude>8 and raw.Unit:Dot(currentVelocity.Unit)<0.75 then desiredLead=desiredLead*0.5 end
    if currentVelocity.Magnitude<3 then desiredLead=0 end
    -- Local strafe speed changes the viewing angle, not the enemy world position.
    -- Avoid adding extra target lead just because our own camera moves quickly.
    if fastMotion and not skill then desiredLead=math.min(desiredLead,0.008) end
    if direct then AimLead=desiredLead else AimLead=AimLead+(desiredLead-AimLead)*alpha(dt,100) end
    local lead=AimLead
    local acceleration=AimAcceleration
    if currentVelocity.Magnitude<4 then acceleration=Vector3.zero end
    local prediction=clampVector(currentVelocity*lead+acceleration*(0.5*lead*lead),skill and 11 or 4)
    local desiredPoint=position+AimOffset+prediction
    AimPoint=desiredPoint
    origin=cam.CFrame.Position
    local offset=desiredPoint-origin
    if offset.Magnitude<0.01 then return false end
    local desired=offset.Unit
    local previous=cam.CFrame.LookVector
    local angle=math.acos(math.clamp(previous:Dot(desired),-1,1))
    local rate=230+math.min(angle*140,230)
    AimControl.angularError=angle
    -- No angular interpolation during dodge, fast orbit or cast.
    if direct then
        AimDir=desired
    else
        local fraction=alpha(dt,rate)
        if angle<0.055 then fraction=1 end
        AimDir=rotateTowards(previous,desired,fraction)
    end
    local up=math.abs(AimDir.Y)>0.9999 and Vector3.zAxis or Vector3.yAxis
    cam.CFrame=CFrame.lookAt(origin,origin+AimDir,up)
    AimControl.actualError=math.acos(math.clamp(cam.CFrame.LookVector:Dot(desired),-1,1))
    if VIM and (force or direct or now>=NextMouse) then
        local xy,onScreen=cam:WorldToScreenPoint(desiredPoint)
        NextMouse=now+1/Tuning.aimHz
        if onScreen and xy.Z>0 then
            queueAimPointer(Vector2.new(xy.X,xy.Y),force)
        end
    end
    return true
end
RS:BindToRenderStep("AutoBountyAim",Enum.RenderPriority.Last.Value,function(dt)
    if Active and Target and os.clock()>=AimRetryAt then
        local ok,err=pcall(aimAt,Target,(CastTarget==Target and CastToken==Generation) or os.clock()<CastUntil,false,dt)
        if not ok then
            Runtime.report("Mira",err)
            AimRetryAt=os.clock()+0.025
            if os.clock()-LastAimError>2 then
                LastAimError=os.clock()
                Detail.Text="Mira: "..tostring(err):sub(1,45)
            end
        end
    end
end)
local CategoryNames={melee="Melee",fightingstyle="Melee",bloxfruit="Blox Fruit",fruit="Blox Fruit",sword="Sword",gun="Gun"}
local function category(tool) return CategoryNames[normalize(tool.ToolTip or "")] end
local function weapons()
    local result={}
    local function scan(folder)
        if not folder then return end
        for _,v in ipairs(folder:GetChildren()) do
            if v:IsA("Tool") and category(v) then
                table.insert(result,v)
            end end
    end
    scan(LP:FindFirstChild("Backpack")); scan(LP.Character)
    table.sort(result,function(a,b)
        if category(a)==category(b) then return a.Name<b.Name end
        return Categories[category(a)]<Categories[category(b)]
    end)
    return result
end
local function visible(o)
    while o and o~=PG do
        if o:IsA("GuiObject") and not o.Visible then return false end
        if o:IsA("ScreenGui") and not o.Enabled then return false end
        o=o.Parent
    end
    return true
end
local function skillRecord(tool)
    local record=Scheduler.tools[tool]
    if not record then
        record={rows={},gui=nil,retry=0,lastUse=0,checks=0,successes=0,failures=0}
        Scheduler.tools[tool]=record
    end
    return record
end
local function skillGui(tool)
    local record=skillRecord(tool)
    if record.gui and record.gui.Parent and record.gui:IsDescendantOf(PG) then
        return record.gui
    end
    table.clear(record.rows)
    local main=PG:FindFirstChild("Main")
    local skills=main and main:FindFirstChild("Skills",true)
    record.gui=skills and skills:FindFirstChild(tool.Name,true)
    return record.gui
end
local function skillStatus(tool,k)
    if category(tool)=="Blox Fruit" and k=="V" then return "blocked" end
    local record=skillRecord(tool)
    local now=os.clock()
    if (LastCast[tool] and LastCast[tool][k] or 0)>now then return "cooldown" end
    local container=skillGui(tool)
    local row=record.rows[k]
    if not row or not row.Parent or not container or not row:IsDescendantOf(container) then
        row=container and container:FindFirstChild(k,true)
        record.rows[k]=row
    end
    if not row or not visible(row) then return "unknown" end
    local descendants=row:GetDescendants()
    local level=tool:FindFirstChild("Level")
    for _,v in ipairs(descendants) do
        if v:IsA("GuiObject") and visible(v) then
            local name=v.Name:lower()
            if name=="lock" or name=="locked" or name=="lockicon" then
                return "blocked"
            end
        end
        if v:IsA("TextLabel") and visible(v) then
            local txt=v.Text:lower()
            if txt:find("locked",1,true) and not txt:find("unlocked",1,true) then return "blocked" end
            if level and (level:IsA("IntValue") or level:IsA("NumberValue")) then
                local req=tonumber(txt:match("mas%.?%s*(%d+)"))
                if req and level.Value<req then return "blocked" end
            end
        end
    end
    local cd=row:FindFirstChild("Cooldown",true)
    if not cd or not cd:IsA("GuiObject") then return "unknown" end
    if not visible(cd) or cd.AbsoluteSize.X<=1 then return "ready" end
    return "cooldown"
end
local function ready(tool,k)
    return skillStatus(tool,k)=="ready"
end
local function observeTool(tool)
    local record=skillRecord(tool)
    local readyKeys={}
    local known,waiting=0,0
    for _,k in ipairs(Keys) do
        local status=skillStatus(tool,k)
        if status~="unknown" then known=known+1 end
        if status=="ready" then table.insert(readyKeys,k) end
        if status=="cooldown" then waiting=waiting+1 end
    end
    record.checks=record.checks+1
    return readyKeys,known,waiting
end
local function send(k,down)
    if not VIM then
        Runtime.report("Input","VirtualInputManager non disponibile")
        return false
    end
    local key=Enum.KeyCode[k]
    if not key then
        Runtime.report("Input","Tasto non riconosciuto: "..tostring(k))
        return false
    end
    local ok,err=pcall(function()
        VIM:SendKeyEvent(down,key,false,game)
    end)
    if not ok then Runtime.report("Input",err) end
    return ok
end
local function releaseKeys()
    for k in pairs(Pressed) do send(k,false) end
    table.clear(Pressed)
    CastTarget,CastToken,CastUntil=nil,nil,0
    Soru.busy=false
    resetAim()
end
local function cast(tool,k)
    if not Active or Closed or os.clock()<InputFailureUntil or (category(tool)=="Blox Fruit" and k=="V") then return false end
    local current,token=Target,Generation; CastTarget,CastToken=current,token
    local function valid()
        local r,t=root(LP),root(current)
        return Active and not Closed and not HopBusy and token==Generation and current==Target and r and t and tool.Parent==LP.Character and pvp(current) and (r.Position-t.Position).Magnitude<=math.min(AttackRange,rangeProfile(tool)[3]+3)
    end
    -- Aim and key-down are executed in the same callback, with no extra frame wait.
    if not valid() or not aimAt(current,true,true) then CastTarget,CastToken=nil,nil; return false end
    -- Flush a current pointer update before key-down when the dispatcher is idle.
    if not AimControl.pointerBusy then dispatchAimPointer() end
    if not valid() then CastTarget,CastToken=nil,nil; return false end
    if not send(k,true) then
        Scheduler.failedInputs=Scheduler.failedInputs+1
        CastTarget,CastToken,CastUntil=nil,nil,0
        InputFailureUntil=os.clock()+1.5
        Detail.Text="Input non disponibile"
        return false
    end
    local owner={at=os.clock()}
    Pressed[k]=owner
    local untilTime=os.clock()+Tuning.skillHold; CastUntil=untilTime+0.20
    local castOK,castError=pcall(function()
        repeat RS.RenderStepped:Wait(); if not valid() then break end until os.clock()>=untilTime
        if valid() then
            aimAt(current,true,true)
            if not AimControl.pointerBusy then dispatchAimPointer() end
        end
    end)
    if Pressed[k]==owner then send(k,false); Pressed[k]=nil end
    if CastToken==token then CastTarget,CastToken=nil,nil end
    if not castOK then
        Scheduler.failedInputs=Scheduler.failedInputs+1
        Runtime.report("Mossa",castError)
        return false
    end
    if not valid() then if token==Generation then CastUntil=0 end; return false end
    LastCast[tool]=LastCast[tool] or {}
    LastCast[tool][k]=os.clock()+0.55
    CastUntil=os.clock()+0.20
    Scheduler.successfulInputs=Scheduler.successfulInputs+1
    Scheduler.lastSkill=os.clock()
    return true
end
local function readState(obj,names)
    if not obj then return nil end
    for _,n in ipairs(names) do local a=obj:GetAttribute(n); if type(a)=="boolean" or type(a)=="number" then return a end; local x=obj:FindFirstChild(n); if x and (x:IsA("BoolValue") or x:IsA("NumberValue") or x:IsA("IntValue")) then return x.Value end end
end
local function trySoru()
    if not Active or Closed or HopBusy or not Soru.enabled or Soru.busy or CastTarget then return false end
    local now=os.clock()
    if now<Soru.next or now<CastUntil or next(Pressed) then return false end
    local r,t,h=root(LP),root(Target),humanoid(LP)
    if not r or not t or not h or not pvp(Target) or h.SeatPart then return false end
    if h:GetState()==Enum.HumanoidStateType.Swimming then return false end
    if Water.level and r.Position.Y<Water.level+3 then return false end
    local d=(r.Position-t.Position).Magnitude
    if d<math.max(CastDistance+6,36) or d>76 then return false end
    local energy=readState(LP.Character,{"Energy"})
    if energy==nil then energy=readState(LP:FindFirstChild("Data"),{"Energy"}) end
    if type(energy)=="number" and energy<10 then return false end
    local target,token=Target,Generation
    Soru.busy=true
    Soru.next=now+Soru.cooldown
    local ok=aimAt(target,true,true)
    if ok and Active and not Closed and token==Generation and Target==target then
        local sent=send("R",true)
        if sent then
            local owner={at=os.clock()}
            Pressed.R=owner
            task.wait(0.045)
            if Pressed.R==owner then send("R",false); Pressed.R=nil end
            if Active and token==Generation then Detail.Text="Soru | Flash Step" end
        else
            Soru.next=os.clock()+3
        end
    end
    Soru.busy=false
    return ok
end
local function powers()
    local c=LP.Character
    local now=os.clock()
    if not Active or Closed or HopBusy or not c or not root(LP) then return end
    if Buff.character~=c then
        Buff.character=c
        Buff.nextAura,Buff.nextKen,Buff.nextRace=0,0,0
        Buff.auraAttempt,Buff.kenAttempt=false,false
        Buff.nextCheck=0
    end
    if now<Buff.nextCheck or CastTarget or next(Pressed) or Soru.busy then return end
    Buff.nextCheck=now+0.20
    local data=LP:FindFirstChild("Data")
    local function state(names)
        local value=readState(c,names)
        if value==nil then value=readState(LP,names) end
        if value==nil then value=readState(data,names) end
        return value
    end
    local aura=state({"AuraActive","BusoActive","HakiActive","ArmamentActive"})
    local buso=c:FindFirstChild("HasBuso")
    if buso then aura=not buso:IsA("BoolValue") or buso.Value end
    local ken=state({"InstinctActive","KenActive","ObservationActive"})
    local transformed=state({"RaceTransformed","RaceAwakenedActive","V4Active"})
    local energy=state({"RaceEnergy","RaceAwakeningEnergy"})
    local readyV4=state({"RaceEnergyFull","RaceAwakeningReady","V4Ready"})
    local energyObject=c:FindFirstChild("RaceEnergy")
    local maximum=state({"RaceEnergyMax","MaxRaceEnergy"})
    if energyObject then
        maximum=maximum or energyObject:GetAttribute("MaxValue")
    end
    if type(energy)=="number" and type(maximum)=="number" and maximum>0 then
        readyV4=energy>=maximum
    elseif readyV4==nil and type(energy)=="number" and energy>=0 and energy<=1 then
        readyV4=energy>=0.999
    end
    Powers.Text="Haki: "..(aura==true and "ON" or "AUTO").." | Istinto: "..(ken==true and "ON" or "AUTO").." | V4: "..(transformed==true and "ON" or "AUTO")
    local token=Generation
    local function tap(key)
        if not Active or Closed or HopBusy or token~=Generation then return false end
        if not send(key,true) then return false end
        local owner={at=os.clock()}
        Pressed[key]=owner
        task.wait(0.045)
        if Pressed[key]==owner then send(key,false); Pressed[key]=nil end
        return true
    end
    if now>=Buff.nextAura and aura~=true and (aura==false or not Buff.auraAttempt) then
        Buff.nextAura=now+3
        if tap("J") then Buff.auraAttempt=true end
        return
    end
    if AutoKen and now>=Buff.nextKen and ken~=true and (ken==false or not Buff.kenAttempt) then
        Buff.nextKen=now+5
        if tap("E") then Buff.kenAttempt=true end
        return
    end
    if AutoV4 and now>=Buff.nextRace and readyV4==true and transformed~=true then
        Buff.nextRace=now+4
        tap("Y")
    end
end
local function combat()
    if os.clock()<Scheduler.nextAction or os.clock()<InputFailureUntil or next(Pressed) then return end
    local tools=weapons()
    if #tools==0 then
        Detail.Text="Nessuna arma riconosciuta"
        Scheduler.nextAction=os.clock()+0.4
        return
    end
    local current,token=Target,Generation
    local h=humanoid(LP)
    if not h then return end
    local function valid()
        return Active and not Closed and not HopBusy and Generation==token and Target==current
            and root(LP) and root(current) and pvp(current)
    end
    local function distance()
        local own,enemy=root(LP),root(current)
        if not own or not enemy then return math.huge end
        return (own.Position-enemy.Position).Magnitude
    end
    local function equip(tool)
        if tool.Parent==LP.Character then return true end
        if not valid() or tool.Parent~=LP:FindFirstChild("Backpack") then return false end
        h:EquipTool(tool)
        local deadline=os.clock()+Tuning.equipTimeout
        while tool.Parent~=LP.Character and valid() and os.clock()<deadline do
            RS.Heartbeat:Wait()
        end
        if not valid() or tool.Parent~=LP.Character then return false end
        Scheduler.lastEquip=os.clock()
        Scheduler.equips=Scheduler.equips+1
        RangeRefresh=0
        return true
    end
    local ordered={}
    local now=os.clock()
    for index,tool in ipairs(tools) do
        local record=skillRecord(tool)
        if record.retry<=now and distance()<=rangeProfile(tool)[3] then
            local score=0
            if tool.Parent==LP.Character then score=score+35 end
            score=score+math.min(15,now-record.lastUse)
            local offset=(index-Rotation-1)%#tools
            score=score-offset*0.4
            table.insert(ordered,{tool=tool,index=index,score=score})
        end
    end
    table.sort(ordered,function(a,b) return a.score>b.score end)
    for _,entry in ipairs(ordered) do
        if not valid() then return end
        local tool=entry.tool
        local record=skillRecord(tool)
        if equip(tool) then
            local readyDeadline=os.clock()+Tuning.guiTimeout
            local available,known,waiting
            repeat
                available,known,waiting=observeTool(tool)
                if #available>0 or known>=#Keys then break end
                if not valid() or tool.Parent~=LP.Character or os.clock()>=readyDeadline then break end
                RS.Heartbeat:Wait()
            until false
            local used=false
            for _,k in ipairs(available or {}) do
                if not valid() or tool.Parent~=LP.Character or distance()>rangeProfile(tool)[3] then break end
                if ready(tool,k) then
                    Detail.Text=tool.Name.." | "..k.." AIM"
                    if cast(tool,k) then
                        used=true
                        record.successes=record.successes+1
                        record.lastUse=os.clock()
                        Rotation=entry.index
                        local recover=os.clock()+Tuning.recovery
                        repeat RS.Heartbeat:Wait() until not valid() or os.clock()>=recover
                    else
                        record.failures=record.failures+1
                        if os.clock()<InputFailureUntil then break end
                    end
                end
            end
            if used then
                record.retry=os.clock()+0.065
                Scheduler.nextAction=os.clock()+0.012
                Scheduler.emptySince=0
                return
            end
            record.retry=os.clock()+((known or 0)==0 and Tuning.unknownRetry or Tuning.weaponRetry)
        else
            record.retry=os.clock()+Tuning.unknownRetry
        end
    end
    if valid() then
        Scheduler.emptySince=Scheduler.emptySince==0 and os.clock() or Scheduler.emptySince
        Scheduler.nextAction=os.clock()+0.045
        Detail.Text="Attesa skill/input"
    end
end
local function clearTarget(skip)
    if Target and skip then Skipped[Target.UserId]=os.clock()+90 end
    Target=nil; Generation=Generation+1; CombatStarted=nil; BestDistance=math.huge; releaseKeys(); stopMovement(); resetScheduler()
end
Runtime.release=function()
    clearTarget(false)
    removeWaterSupport()
end
local function queueRestart()
    if Closed then return false end
    if HopQueued then return true end
    local queue=queue_on_teleport
    if type(queue)~="function" and type(syn)=="table" then queue=syn.queue_on_teleport end
    if type(queue)~="function" then return false end
    -- The downloaded script checks the saved state before creating any UI.
    -- Do not pass the explicit manual reopening argument to the queued loader.
    local code="repeat task.wait() until game:IsLoaded(); local ok,err=pcall(function() loadstring(game:HttpGet("..string.format("%q",ScriptURL).."))() end); if not ok then warn(err) end"
    local ok,result=pcall(queue,code)
    HopQueued=ok and result~=false
    return HopQueued
end
local function getServerPage(url)
    local ok,body=pcall(function() return game:HttpGet(url) end)
    if not ok or type(body)~="string" then
        local requestFn=http_request or request
        if type(requestFn)~="function" then return nil end
        local success,res=pcall(requestFn,{Url=url,Method="GET"})
        if not success or type(res)~="table" or tonumber(res.StatusCode)~=200 then return nil end
        body=res.Body
    end
    local decoded,result=pcall(function() return HttpService:JSONDecode(body) end)
    if decoded and type(result)=="table" and type(result.data)=="table" then return result end
    return nil
end
local function chooseServer(serial)
    local candidates,seen={},{}
    local cursor=nil
    local order=RNG:NextNumber()<0.5 and "Asc" or "Desc"
    for page=1,3 do
        if Closed or not Active or not AutoHop or serial~=HopSerial then return nil end
        local url="https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder="..order.."&limit=100&excludeFullGames=true"
        if cursor then url=url.."&cursor="..HttpService:UrlEncode(cursor) end
        local result=getServerPage(url)
        if not result then break end
        for _,server in ipairs(result.data) do
            local id,playing,maxPlayers=server.id,tonumber(server.playing),tonumber(server.maxPlayers)
            if type(id)=="string" and id~=game.JobId and not seen[id] and playing and maxPlayers
                and playing>=2 and playing<maxPlayers and (FailedServers[id] or 0)<=os.clock() then
                seen[id]=true
                table.insert(candidates,id)
            end
        end
        cursor=result.nextPageCursor
        if type(cursor)~="string" or cursor=="" then break end
        if page<3 then task.wait(0.5) end
    end
    if #candidates==0 then return nil end
    return candidates[RNG:NextInteger(1,#candidates)]
end
local function hopFailed(message,serial)
    if serial~=HopSerial then return end
    HopBusy=false
    EmptySince=nil
    NextHop=os.clock()+HopCooldown
    if not Closed then HopStatus.Text=message.." | nuovo tentativo" end
end
local function localCombatState()
    -- PvP enabled is not equivalent to being in combat.
    local active,known=false,false
    local function scan(object)
        if not object then return end
        local names={"InCombat","CombatActive","IsInCombat","CombatTag","CombatTagged","CombatTimer","CombatTimeRemaining"}
        for _,name in ipairs(names) do
            local value=object:GetAttribute(name)
            local child=object:FindFirstChild(name)
            if value==nil and child and (child:IsA("BoolValue") or child:IsA("NumberValue") or child:IsA("IntValue")) then
                value=child.Value
            end
            if type(value)=="boolean" then known=true; active=active or value
            elseif type(value)=="number" and (name=="CombatTimer" or name=="CombatTimeRemaining") then
                known=true; active=active or value>0
            end
        end
    end
    scan(LP); scan(LP.Character)
    for _,name in ipairs({"Data","Stats","Status"}) do
        scan(LP:FindFirstChild(name))
        if LP.Character then scan(LP.Character:FindFirstChild(name)) end
    end
    local main=PG:FindFirstChild("Main")
    local marker=CombatGuard.marker
    if not marker or not marker.Parent or not main or not marker:IsDescendantOf(main) then
        marker=main and (main:FindFirstChild("InCombat",true) or main:FindFirstChild("CombatIndicator",true) or main:FindFirstChild("CombatStatus",true))
        CombatGuard.marker=marker
    end
    if marker and marker:IsA("GuiObject") then
        known=true
        if visible(marker) then
            local textObject=(marker:IsA("TextLabel") or marker:IsA("TextButton")) and marker or marker:FindFirstChildWhichIsA("TextLabel",true)
            local txt=textObject and normalize(textObject.Text) or ""
            if txt~="outofcombat" and txt~="notincombat" and txt~="combatinactive" then active=true end
        end
    end
    if active then return true end
    if known then return false end
    return nil
end
local function canHop(now)
    local state=localCombatState()
    if now-CombatGuard.lastDamage<3 then state=true end
    if state~=false then
        CombatGuard.clearSince=nil
        return false,state==true and "Combat attivo: attesa" or "Combat non verificato: attesa"
    end
    CombatGuard.clearSince=CombatGuard.clearSince or now
    if now-CombatGuard.clearSince<3 then return false,"Fine combat: verifica..." end
    return true
end
local function startHop()
    if HopBusy or Closed or not Active or not AutoHop then return end
    local safe,reason=canHop(os.clock())
    if not safe then HopStatus.Text=reason; return end
    HopBusy=true
    HopSerial=HopSerial+1
    local serial=HopSerial
    HopStarted=os.clock()
    NextHop=HopStarted+HopCooldown
    clearTarget(false)
    HopStatus.Text="Ricerca nuovo server..."
    task.spawn(function()
        local ok,err=pcall(function()
            local id=chooseServer(serial)
            if Closed or not Active or not AutoHop or serial~=HopSerial then return end
            if not id then hopFailed("Nessun server trovato",serial); return end
            -- A new target may have appeared while the HTTP request was running.
            local candidate,allowed,loaded=findTarget()
            if candidate or allowed>loaded then
                HopBusy=false
                EmptySince=nil
                HopStatus.Text="Giocatori disponibili"
                return
            end
            local safe,reason=canHop(os.clock())
            if not safe then HopBusy=false; EmptySince=nil; HopStatus.Text=reason; return end
            local queued=queueRestart()
            if not queued then
                hopFailed("Riavvio automatico non disponibile",serial)
                return
            end
            FailedServers[id]=os.clock()+180
            HopStarted=os.clock()
            HopStatus.Text=queued and "Cambio server..." or "Cambio server | riavvio manuale"
            if Closed or not Active or not AutoHop or serial~=HopSerial then return end
            local stillSafe,why=canHop(os.clock())
            if not stillSafe then HopBusy=false; EmptySince=nil; HopStatus.Text=why; return end
            TeleportService:TeleportToPlaceInstance(game.PlaceId,id,LP)
        end)
        if not ok then Runtime.report("Server",err); hopFailed("Errore server",serial) end
    end)
end
local teleportFailure=Runtime.connect(TeleportService.TeleportInitFailed,function(player,result,message)
    if player==LP and HopBusy then
        Runtime.report("Teleport",tostring(result).." "..tostring(message))
        hopFailed("Teleport fallito",HopSerial)
    end
end)
local function monitorHop(candidate,allowed,loaded,now)
    if not AutoHop then EmptySince=nil; return end
    if now-JoinedAt<JoinGrace then
        EmptySince=nil
        HopStatus.Text="Caricamento server..."
        return
    end
    if Target or candidate or allowed>loaded then
        CombatGuard.clearSince=nil
        EmptySince=nil
        HopStatus.Text="Server hop: ON"
        return
    end
    local safe,reason=canHop(now)
    if not safe then EmptySince=nil; HopStatus.Text=reason; return end
    if now<NextHop then
        EmptySince=nil
        HopStatus.Text="Attesa cambio: "..math.ceil(NextHop-now).."s"
        return
    end
    EmptySince=EmptySince or now
    local remaining=math.max(0,EmptyDelay-(now-EmptySince))
    HopStatus.Text="Nessun PvP | cambio tra "..math.ceil(remaining).."s"
    if remaining<=0 then startHop() end
end
local function setActive(value)
    if Closed then return end
    Active=value
    saveState(Active and "on" or "off")
    Generation=Generation+1
    Button.Text=Active and "AUTO BOUNTY: ON" or "AUTO BOUNTY: OFF"
    Button.BackgroundColor3=Active and Color3.fromRGB(30,160,75)
        or Color3.fromRGB(170,40,40)
    if not Active then
        HopSerial=HopSerial+1; HopBusy=false; EmptySince=nil
        clearTarget(false)
        removeWaterSupport(); CombatGuard.clearSince=nil
        Info.Text="Disattivato"
    else
        table.clear(Skipped)
        resetScheduler()
        NextRace,NextKen=0,0
        MouseSupported=VIM~=nil
        InputFailureUntil=0
        Soru.busy=false
        Buff.character=nil
        resetAim()
        Info.Text="Ricerca giocatori..."
    end
    if not VIM then
        Diagnostic.Text="Input executor non disponibile"
    else
        Diagnostic.Text=Active and "Avvio riuscito | ricerca attiva" or "In pausa"
    end
end
Runtime.connect(Button.Activated,function() setActive(not Active) end)
Runtime.connect(CloseButton.Activated,function()
    if Closed then return end
    -- Persist closure before destroying the GUI or cancelling ongoing work.
    local saved=saveState("closed")
    if not saved then
        warn("AutoBounty: stato non salvabile; disabilita anche Auto Execute.")
    end
    Closed=true
    Active=false
    AutoHop=false
    HopSerial=HopSerial+1
    HopBusy=false
    EmptySince=nil
    Gui:Destroy()
end)
Runtime.connect(HopToggle.Activated,function()
    AutoHop=not AutoHop
    EmptySince=nil
    if not AutoHop then HopSerial=HopSerial+1; HopBusy=false end
    HopToggle.Text=AutoHop and "AUTO SERVER: ON" or "AUTO SERVER: OFF"
    HopToggle.BackgroundColor3=AutoHop and Color3.fromRGB(35,110,78) or Color3.fromRGB(110,50,50)
    HopStatus.Text=AutoHop and "Server hop: ON" or "Server hop: OFF"
end)
task.spawn(function()
    while not Closed do
        if Active then
            local ok,err=pcall(function()
                local now=os.clock()
                if HopBusy then
                    if now-HopStarted>40 then
                        HopSerial=HopSerial+1
                        hopFailed("Timeout teleport",HopSerial)
                    end
                    return
                end
                local r=root(LP)
                if not r then
                    EmptySince=nil
                    if Target or Velocity then clearTarget(false) end
                    Info.Text="Respawn..."
                    return
                end
                local h=humanoid(LP)
                if h then
                    if CombatGuard.lastHealth and h.Health<CombatGuard.lastHealth then
                        CombatGuard.lastDamage=now
                        CombatGuard.clearSince=nil
                    end
                    CombatGuard.lastHealth=h.Health
                end
                for id,expiry in pairs(Skipped) do if expiry<=now then Skipped[id]=nil end end
                local candidate,allowed,loaded=findTarget()
                if Target then
                    local t=root(Target)
                    if not t or not pvp(Target) then clearTarget(false)
                    else
                        local d=(r.Position-t.Position).Magnitude
                        if d<BestDistance-5 then BestDistance=d; LastProgress=now end
                        if d<=AttackRange then CombatStarted=CombatStarted or now end
                        local enemyHealth=humanoid(Target)
                        if Scheduler.target~=Target then
                            Scheduler.target=Target
                            Scheduler.targetHealth=enemyHealth and enemyHealth.Health
                            Scheduler.lastHit=now
                        elseif enemyHealth then
                            if Scheduler.targetHealth and enemyHealth.Health<Scheduler.targetHealth-Tuning.minProgress then
                                Scheduler.lastHit=now
                                LastProgress=now
                            end
                            Scheduler.targetHealth=enemyHealth.Health
                        end
                        local noDamage=CombatStarted and now-math.max(CombatStarted,Scheduler.lastHit)>Tuning.noDamageTimeout
                        local overtime=CombatStarted and now-CombatStarted>Tuning.attackTimeout
                        local unreachable=not CombatStarted and now-LastProgress>20
                        if noDamage or overtime or unreachable then
                            if candidate==Target then candidate=nil end; clearTarget(true)
                        end
                    end
                end
                if not Target and candidate and (Skipped[candidate.UserId] or 0)<=now and root(candidate) and pvp(candidate) then
                    Target=candidate; Started=now; LastProgress=now; BestDistance=math.huge
                    resetScheduler()
                    Scheduler.target=candidate
                    Scheduler.targetHealth=humanoid(candidate) and humanoid(candidate).Health
                    Scheduler.lastHit=now
                end
                local t=root(Target)
                Info.Text=t and (Target.Name.." | "..math.floor((r.Position-t.Position).Magnitude).." studs") or "Ricerca giocatori..."
                monitorHop(candidate,allowed,loaded,now)
            end)
            if not ok then Runtime.report("Scansione",err); Detail.Text="Scan: "..tostring(err):sub(1,45) end
        end
        task.wait(ScanInterval)
    end
end)
task.spawn(function()
    while not Closed do
        if Active and not HopBusy then
            local ok,err=pcall(powers)
            if not ok then Runtime.report("Poteri",err); releaseKeys() end
        end
        if Active and not HopBusy and Target then
            local r,t=root(LP),root(Target)
            if r and t and (r.Position-t.Position).Magnitude<=AttackRange and pvp(Target) then
                local token=Generation
                local ok,err=pcall(function()
                    trySoru()
                    if not Active or token~=Generation then return end
                    local own,enemy=root(LP),root(Target)
                    if own and enemy and (own.Position-enemy.Position).Magnitude<=math.min(AttackRange,CastDistance+5) then
                        if Active and token==Generation then combat() end
                    end
                end)
                if not ok then
                    Runtime.report("Combat",err)
                    Soru.busy=false
                    releaseKeys()
                    Detail.Text="Combat: "..tostring(err):sub(1,45)
                end
            end
        end
        task.wait(0.025)
    end
end)
local removing=Runtime.connect(P.PlayerRemoving,function(p)
    Cache[p]=nil; Skipped[p.UserId]=nil; if Target==p then clearTarget(false) end
end)
local respawn=Runtime.connect(LP.CharacterAdded,function() EmptySince=nil; CombatGuard.clearSince=nil; CombatGuard.lastHealth=nil; CombatGuard.lastDamage=0; Buff.character=nil; Soru.busy=false; removeWaterSupport(); clearTarget(false); table.clear(LastCast); table.clear(Scheduler.tools) end)
local teleportStarted=Runtime.connect(LP.OnTeleport,function(state)
    if Closed then return end
    if state==Enum.TeleportState.Started or state==Enum.TeleportState.InProgress then
        saveState(Active and "on" or "off")
        queueRestart()
    end
end)
Runtime.connect(Gui.Destroying,function()
    Closed=true; Active=false
    HopSerial=HopSerial+1; HopBusy=false; teleportFailure:Disconnect(); teleportStarted:Disconnect()
    Generation=Generation+1
    clearTarget(false); removing:Disconnect(); respawn:Disconnect()
    movement:Disconnect(); noclip:Disconnect(); waterConnection:Disconnect(); waterPlaneAdded:Disconnect(); removeWaterSupport()
    RS:UnbindFromRenderStep("AutoBountyAim")
    for _,connection in ipairs(Runtime.connections) do pcall(function() connection:Disconnect() end) end
    table.clear(Runtime.connections)
    Runtime.closing=true
end)

Runtime.stage="Attivazione"
if not Closed then
    setActive(AutoStart)
    queueRestart()
    Runtime.stage="Pronto"
    Runtime.notify("V9.1 Fluid","Script caricato. Controlla il riquadro diagnostica.")
    task.spawn(function()
        while not Closed do
            if Active and WaterToggle.Parent then
                local now=os.clock()
                for key,owner in pairs(Pressed) do
                    if type(owner)=="table" and owner.at and now-owner.at>1.0 then
                        send(key,false)
                        Pressed[key]=nil
                        Runtime.report("Input","Rilascio di sicurezza "..key)
                    end
                end
                Telemetry.Text=string.format("Mira: %s | Frame: %.0f ms | Errore: %.2f°\nInput: %d | Armi: %d | Dodge: %d",AimControl.direct and "LOCK" or "FLUID",AimControl.renderGap*1000,math.deg(AimControl.actualError),Scheduler.successfulInputs,Scheduler.equips,Motion.evadeCount)
                local txt=Water.enabled and ("WATER WALK: "..(Water.status=="Superficie rilevata" and "ACQUA" or "ON")) or "WATER WALK: OFF"
                if Water.status=="Superficie rilevata" and Water.enabled then
                    txt="WATER: "..Water.source:upper()
                end
                if WaterToggle.Text~=txt then WaterToggle.Text=txt end
            end
            task.wait(0.5)
        end
    end)
end

end
local manualMode=...
local ok,err=xpcall(function() start(manualMode) end,function(message)
    return tostring(message)
end)
if not ok then
    Runtime.report(Runtime.stage,err)
    Runtime.cleanup()
    Runtime.notify("Errore V9.1",Runtime.stage..": "..tostring(err):sub(1,120))
end
