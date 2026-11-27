-- V7.6 Fluid: movimento e mira con interpolazione temporale.

repeat task.wait() until game:IsLoaded()
local P=game:GetService("Players"); local RS=game:GetService("RunService"); local VIM=game:GetService("VirtualInputManager"); local LP=P.LocalPlayer
local PG=LP:WaitForChild("PlayerGui"); local Speed=250; local DodgeSpeed=400; local AttackRange=80; local MaxAttackTime=60; local Active,Closed=false,false; local Target,Started=nil,0; local Attachment,Velocity,FlyRoot
local Rotation,Generation=0,0; local Collision,Skipped={},{}; local Direction,Angle=1,0; local NextChange,NextDodge,DodgeUntil=0,0,0
local LastHealth,LastTarget; local CastTarget,CastToken; local NextMouse,CastUntil=0,0; local MouseSupported=true; local AimRoot,AimPos,AimTime,AimVelocity=nil,nil,0,Vector3.zero
local RNG=Random.new(); local InOrbit=false; local OrbitRadius=15; local Pressed,Cache={},{}; local LastScan,LastProgress,BestDistance=0,0,math.huge
local AngularRate,OrbitBlend,RadiusNow,HeightNow=0,0,15,7; local AimDir,AimFrame,AimCamera; local NextParts=0; local CombatStarted=nil; local ScanInterval=0.4; local NextRace,NextKen=0,0; local KenChar; local KenTried=false; local AutoV4,AutoKen=true,true; local LastCast=setmetatable({},{__mode="k"}); local Categories={
    Melee=1,["Blox Fruit"]=2,Sword=3,Gun=4
}
local Keys={"Z","X","C","V","F"}
for _,n in ipairs({
    "BloxAimTP","AutoBountyV6","AutoBountyV7",
    "AutoBountyV71","AutoBountyV72","AutoBountyV73",
    "PvPDiagnostic","AutoBountyV8","AutoBountyV74","AutoBountyV75","AutoBountyV76","AutoBountyV77","AutoBountyV76Fluid"
}) do
    local old=PG:FindFirstChild(n)
    if old then old:Destroy() end end
RS:UnbindFromRenderStep("AutoBountyAim")
local Gui=Instance.new("ScreenGui",PG); Gui.Name="AutoBountyV76Fluid"; Gui.ResetOnSpawn=false; Gui.DisplayOrder=999; local Main=Instance.new("Frame",Gui)
Main.Size=UDim2.fromOffset(260,208); Main.Position=UDim2.new(0.03,0,0.15,0); Main.BackgroundColor3=Color3.fromRGB(20,22,30); Main.Active=true; Main.Draggable=true
Instance.new("UICorner",Main)
local function label(txt,y,h)
    local l=Instance.new("TextLabel",Main); l.Size=UDim2.new(1,-12,0,h); l.Position=UDim2.fromOffset(6,y); l.BackgroundTransparency=1; l.TextColor3=Color3.new(1,1,1)
    l.Font=Enum.Font.GothamBold; l.TextSize=13; l.TextWrapped=true; l.Text=txt
    return l end
label("AUTO BOUNTY V7.6 FLUID",5,25)
local Button=Instance.new("TextButton",Main); Button.Size=UDim2.new(1,-20,0,42); Button.Position=UDim2.fromOffset(10,35)
Button.BackgroundColor3=Color3.fromRGB(170,40,40); Button.TextColor3=Color3.new(1,1,1); Button.Font=Enum.Font.GothamBold; Button.TextSize=16; Button.Text="AUTO BOUNTY: OFF"
Instance.new("UICorner",Button)
local Info=label("In attesa",82,30); local Scan=label("PvP ON*: 0 | OFF: 0",112,30); local Detail=label("Fruit V: OFF",142,30); local Powers=label("V4 / Istinto: AUTO",174,28)
local function humanoid(p)
    return p and p.Character
        and p.Character:FindFirstChildOfClass("Humanoid") end
local function root(p)
    local h=humanoid(p)
    if not h or h.Health<=0 then return nil end
    return p.Character:FindFirstChild("HumanoidRootPart") end
local function normalize(s)
    return s:lower():gsub("[^%a%d]","") end
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
    if h and h.Health<=0 or p.Character and p.Character:FindFirstChildOfClass("ForceField") then return false end
    local c=Cache[p]; local now=os.clock()
    if c and c.char==p.Character and now-c.at<ScanInterval then return c.allowed end
    local allowed,yes=classify(p); Cache[p]={allowed=allowed,yes=yes,at=now,char=p.Character}
    return allowed end
local function findTarget()
    local r=root(LP); local best,nearest=nil,math.huge; local confirmed=false; local on,off,loaded=0,0,0; local now=os.clock()
    for _,p in ipairs(P:GetPlayers()) do
        if p~=LP then
            local allowed,yes=classify(p); Cache[p]={allowed=allowed,yes=yes,at=now,char=p.Character}
            if allowed then
                on=on+1; local t=root(p)
                if t then loaded=loaded+1 end
                if r and t and (Skipped[p.UserId] or 0)<=now then
                    local d=(t.Position-r.Position).Magnitude
                    if not best or (yes and not confirmed) or (yes==confirmed and d<nearest) then best,nearest,confirmed=p,d,yes end end
            else off=off+1 end end end
    Scan.Text="PvP ON*: "..on.." | OFF: "..off.." | Load: "..loaded
    return best end
local function restore()
    for p,v in pairs(Collision) do
        if p.Parent then p.CanCollide=v end end
    table.clear(Collision); NextParts=0 end
local function stopMovement()
    if Velocity then Velocity:Destroy() Velocity=nil end
    if Attachment then Attachment:Destroy() Attachment=nil end
    if FlyRoot and FlyRoot.Parent then
        FlyRoot.AssemblyLinearVelocity=Vector3.zero end
    FlyRoot=nil
    LastHealth,LastTarget=nil,nil; AngularRate,OrbitBlend=0,0
    restore() end
local function startMovement(r)
    if FlyRoot==r and Velocity and Velocity.Parent and Attachment and Attachment.Parent then return end
    stopMovement()
    FlyRoot=r; Attachment=Instance.new("Attachment",r); Velocity=Instance.new("LinearVelocity",r); Velocity.Attachment0=Attachment; Velocity.RelativeTo=Enum.ActuatorRelativeTo.World
    Velocity.VelocityConstraintMode=Enum.VelocityConstraintMode.Vector; Velocity.ForceLimitsEnabled=false; Velocity.VectorVelocity=Vector3.zero end
local function dodge(now)
    Direction=-Direction; DodgeUntil=now+RNG:NextNumber(0.25,0.45); NextDodge=now+RNG:NextNumber(0.5,1); end
local function clampVector(v,max)
    if v.Magnitude>max then return v.Unit*max end
    return v end
local function updateMovement(dt)
    if not Active or not Target then if Velocity then stopMovement() end; return end
    dt=math.clamp(dt,0,0.1); local r,t=root(LP),root(Target)
    if not r or not t or not pvp(Target) then
        stopMovement() return end
    startMovement(r)
    local now=os.clock(); local h=humanoid(LP); local delta=r.Position-t.Position; local distance=delta.Magnitude
    if LastTarget~=Target then
        LastTarget=Target; Angle=math.atan2(delta.Z,delta.X)
        DodgeUntil,NextDodge=0,0
        NextChange=now+1; LastHealth=h.Health; InOrbit=false; OrbitRadius=RNG:NextNumber(12,18); RadiusNow,HeightNow=OrbitRadius,7; AngularRate,OrbitBlend=0,0 end
    local damaged=LastHealth and h.Health<LastHealth; LastHealth=h.Health
    if now>=NextChange then
        Direction=-Direction; NextChange=now+RNG:NextNumber(0.6,1.6); OrbitRadius=RNG:NextNumber(12,20) end
    local facing=distance>0.01
        and t.CFrame.LookVector:Dot(delta.Unit)>0.65
    if distance<60 and now>=NextDodge
        and (damaged or (facing and distance<35)) then
        dodge(now)
    end
    local evading=now<DodgeUntil; local prediction=clampVector(t.AssemblyLinearVelocity*0.15,25); local destination=t.Position+prediction+Vector3.new(0,4,0); local limit=Speed
    if distance<55 then InOrbit=true elseif distance>75 then InOrbit=false end
    OrbitBlend=OrbitBlend+((InOrbit and 1 or 0)-OrbitBlend)*(1-math.exp(-dt*9))
    AngularRate=AngularRate+(Direction*(evading and 10 or 4.8)-AngularRate)*(1-math.exp(-dt*(evading and 22 or 10)))
    if not InOrbit and OrbitBlend<0.03 then Angle=math.atan2(delta.Z,delta.X) else Angle=Angle+dt*AngularRate end
    RadiusNow=RadiusNow+((evading and 25 or OrbitRadius+math.sin(now*3)*3)-RadiusNow)*(1-math.exp(-dt*12))
    HeightNow=HeightNow+((evading and 18 or 7+math.sin(now*5)*4)-HeightNow)*(1-math.exp(-dt*12))
    local orbit=t.Position+prediction+Vector3.new(math.cos(Angle)*RadiusNow,HeightNow,math.sin(Angle)*RadiusNow)
    destination=destination:Lerp(orbit,OrbitBlend); if evading then limit=DodgeSpeed end
    local desired=clampVector((destination-r.Position)*(evading and 12 or 8)+clampVector(t.AssemblyLinearVelocity,80),limit)
    local current=Velocity.VectorVelocity; local step=(desired-current)*(1-math.exp(-dt*(evading and 24 or 12)))
    Velocity.VectorVelocity=current+clampVector(step,dt*(evading and 4200 or 1900))
end
local movement=RS.Heartbeat:Connect(function(dt)
    if Active then local ok,err=pcall(updateMovement,dt); if not ok then stopMovement(); Detail.Text="Volo: "..tostring(err):sub(1,45) end end
end)
local noclip=RS.Stepped:Connect(function()
    if not Active or not Velocity or not LP.Character then
        restore() return
    end
    local now=os.clock(); local char=LP.Character
    if now>=NextParts then NextParts=now+0.3
        for _,v in ipairs(char:GetDescendants()) do if v:IsA("BasePart") and Collision[v]==nil then Collision[v]=v.CanCollide end end
    end
    for v,original in pairs(Collision) do
        if not v.Parent then Collision[v]=nil elseif not v:IsDescendantOf(char) then v.CanCollide=original; Collision[v]=nil elseif v.CanCollide then v.CanCollide=false end end
end)
local function aimAt(p,skill,force)
    local t,r,cam=root(p),root(LP),workspace.CurrentCamera
    if not Active or Closed or p~=Target or not t or not r or not cam or not pvp(p) then return false end
    local now=os.clock(); local pos=t.Position; local v=clampVector(t.AssemblyLinearVelocity,220)
    if AimRoot~=t or AimCamera~=cam then AimRoot,AimPos,AimTime,AimVelocity=t,pos,now,v; AimDir,AimFrame,AimCamera=nil,now,cam end
    local dt=now-AimTime
    if dt>=0.012 then local measured=clampVector((pos-AimPos)/dt,220); if dt>0.25 or (pos-AimPos).Magnitude>55 then AimVelocity=v else AimVelocity=AimVelocity:Lerp(v:Lerp(measured,0.35),1-math.exp(-dt*22)) end; AimPos,AimTime=pos,now end
    local point=pos+Vector3.new(0,1,0); local lead=skill and math.clamp((pos-r.Position).Magnitude/750+0.025,0.035,0.15) or 0.02
    point=point+clampVector(AimVelocity*lead,skill and 12 or 3)
    if (point-cam.CFrame.Position).Magnitude<=0.01 then return false end
    local origin=cam.CFrame.Position; local dir=(point-origin).Unit; local frameDt=math.clamp(now-(AimFrame or now),0,0.1); AimFrame=now
    AimDir=(force or not AimDir) and dir or AimDir:Lerp(dir,1-math.exp(-frameDt*(skill and 48 or 23)))
    if AimDir.Magnitude<0.01 then AimDir=dir end; cam.CFrame=CFrame.lookAt(origin,origin+AimDir)
    if skill and MouseSupported and (force or os.clock()>=NextMouse) then
        NextMouse=now+1/45; local xy,onScreen=cam:WorldToScreenPoint(point)
        if onScreen then MouseSupported=pcall(function() VIM:SendMouseMoveEvent(math.floor(xy.X+0.5),math.floor(xy.Y+0.5),game) end) end
    end
    return true
end
RS:BindToRenderStep("AutoBountyAim",Enum.RenderPriority.Camera.Value+1,function()
    if Active then pcall(aimAt,Target,(CastTarget==Target and CastToken==Generation) or os.clock()<CastUntil,false) end
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
local function ready(tool,k)
    if category(tool)=="Blox Fruit" and k=="V" then return false end
    if (LastCast[tool] and LastCast[tool][k] or 0)>os.clock() then return false end
    local m=PG:FindFirstChild("Main"); local s=m and m:FindFirstChild("Skills",true); local w=s and s:FindFirstChild(tool.Name,true); local row=w and w:FindFirstChild(k,true)
    if not row or not visible(row) then return false end
    local descendants=row:GetDescendants()
    for _,v in ipairs(descendants) do
        if v:IsA("GuiObject") and visible(v)
            and v.Name:lower():find("lock") then return false end
        if v:IsA("TextLabel") and visible(v)
            and v.Text:lower():find("locked") then return false end
    end
    local level=tool:FindFirstChild("Level")
    if level and (level:IsA("IntValue") or level:IsA("NumberValue")) then
        for _,v in ipairs(descendants) do if v:IsA("TextLabel") and visible(v) then
            local req=tonumber(v.Text:lower():match("mas%.?%s*(%d+)")); if req and level.Value<req then return false end
        end end
    end
    local cd=row:FindFirstChild("Cooldown",true)
    return cd and cd:IsA("GuiObject")
        and (not visible(cd) or cd.AbsoluteSize.X<=1)
end
local function send(k,down)
    return pcall(function() VIM:SendKeyEvent(down,Enum.KeyCode[k],false,game) end)
end
local function releaseKeys()
    for k in pairs(Pressed) do send(k,false) end; table.clear(Pressed); CastTarget,CastToken,CastUntil=nil,nil,0; AimRoot,AimPos,AimTime=nil,nil,0; AimDir,AimFrame,AimCamera=nil,nil,nil
end
local function cast(tool,k)
    if not Active or Closed or category(tool)=="Blox Fruit" and k=="V" then return false end
    local current,token=Target,Generation; CastTarget,CastToken=current,token
    local function valid()
        local r,t=root(LP),root(current)
        return Active and not Closed and token==Generation and current==Target and r and t and tool.Parent==LP.Character and pvp(current) and (r.Position-t.Position).Magnitude<=AttackRange
    end
    if not valid() or not aimAt(current,true,true) then CastTarget,CastToken=nil,nil; return false end; RS.Heartbeat:Wait()
    if not valid() or not aimAt(current,true,true) then CastTarget,CastToken=nil,nil; return false end
    if not send(k,true) then CastTarget,CastToken,CastUntil=nil,nil,0; Detail.Text="Input non disponibile"; return false end
    Pressed[k]=true; local untilTime=os.clock()+0.12; CastUntil=untilTime+0.35
    repeat RS.Heartbeat:Wait(); if not valid() then break end until os.clock()>=untilTime
    if valid() then aimAt(current,true,true) end
    if Pressed[k] then send(k,false); Pressed[k]=nil end
    CastTarget,CastToken=nil,nil; if not valid() then CastUntil=0; return false end
    LastCast[tool]=LastCast[tool] or {}; LastCast[tool][k]=os.clock()+0.8; CastUntil=os.clock()+0.35; return true
end
local function readState(obj,names)
    if not obj then return nil end
    for _,n in ipairs(names) do local a=obj:GetAttribute(n); if type(a)=="boolean" or type(a)=="number" then return a end; local x=obj:FindFirstChild(n); if x and (x:IsA("BoolValue") or x:IsA("NumberValue") or x:IsA("IntValue")) then return x.Value end end
end
local function powers()
    local c=LP.Character; local now=os.clock(); if not Active or not c or not root(LP) or not Target or not pvp(Target) then return end
    if KenChar~=c then KenChar=c; KenTried=false; NextKen,NextRace=0,0 end
    local energy=readState(c,{"RaceEnergy"}); local transformed=readState(c,{"RaceTransformed"}); local ken=readState(c,{"InstinctActive","KenActive","ObservationActive"}); if ken==nil then ken=readState(LP,{"InstinctActive","KenActive","ObservationActive"}) end
    local r,t=root(LP),root(Target); if not r or not t or (r.Position-t.Position).Magnitude>AttackRange then return end
    Powers.Text=(transformed==true and "V4: ON" or "V4: AUTO").." | "..(ken==true and "Istinto: ON" or "Istinto: AUTO")
    if AutoV4 and type(energy)=="number" and energy>=0.999 and transformed~=true and now>=NextRace then
        NextRace=now+3; if send("Y",true) then Pressed.Y=true; task.wait(0.1); if Pressed.Y then send("Y",false); Pressed.Y=nil end end; return end
    if AutoKen and (ken==false or ken==nil and not KenTried) and now>=NextKen then
        NextKen=now+5; local rem=game:GetService("ReplicatedStorage"):FindFirstChild("Remotes"); local event=rem and rem:FindFirstChild("CommE")
        if event and event:IsA("RemoteEvent") then local ok=pcall(function() event:FireServer("Ken",true) end); if ok then KenTried=true; return end end
        if ken==false or not KenTried then if send("E",true) then KenTried=true; Pressed.E=true; task.wait(0.1); if Pressed.E then send("E",false); Pressed.E=nil end end end
    end end
local function combat()
    local tools=weapons(); if #tools==0 then Detail.Text="Nessuna arma riconosciuta"; return end
    Rotation=Rotation%#tools+1
    local tool,h=tools[Rotation],humanoid(LP); local current,token=Target,Generation; if not h then return end
    if tool.Parent~=LP.Character then
        h:EquipTool(tool); local deadline=os.clock()+0.45
        repeat task.wait(0.04) until tool.Parent==LP.Character or not Active or token~=Generation or os.clock()>=deadline
        if tool.Parent~=LP.Character or token~=Generation or not Active then return end; task.wait(0.12)
    end
    local used=false
    for _,k in ipairs(Keys) do
        local r,t=root(LP),root(current)
        if not Active or Generation~=token or Target~=current
            or not r or not t or not pvp(current) then break end
        if tool.Parent~=LP.Character then break end
        if (r.Position-t.Position).Magnitude>AttackRange then break end
        if ready(tool,k) then
            Detail.Text=tool.Name.." | "..k.." AIM"
            used=cast(tool,k) or used; task.wait(0.2)
        end end
    if not used and Active and token==Generation then Detail.Text=tool.Name.." | Attesa skill/input" end
end
local function clearTarget(skip)
    if Target and skip then Skipped[Target.UserId]=os.clock()+90 end
    Target=nil; Generation=Generation+1; CombatStarted=nil; BestDistance=math.huge; releaseKeys(); stopMovement()
end
Button.Activated:Connect(function()
    Active=not Active
    Generation=Generation+1
    Button.Text=Active and "AUTO BOUNTY: ON" or "AUTO BOUNTY: OFF"
    Button.BackgroundColor3=Active and Color3.fromRGB(30,160,75)
        or Color3.fromRGB(170,40,40)
    if not Active then
        clearTarget(false)
        Info.Text="Disattivato"
    else
        table.clear(Skipped); NextRace,NextKen=0,0; MouseSupported=true
    end
end)
task.spawn(function()
    while not Closed do
        if Active then
            local ok,err=pcall(function()
                local r=root(LP); if not r then if Target or Velocity then clearTarget(false) end; Info.Text="Respawn..."; return end; local now=os.clock(); local candidate=findTarget()
                if Target then
                    local t=root(Target)
                    if not t or not pvp(Target) then clearTarget(false)
                    else
                        local d=(r.Position-t.Position).Magnitude
                        if d<BestDistance-5 then BestDistance=d; LastProgress=now end
                        if d<=AttackRange then CombatStarted=CombatStarted or now; LastProgress=now; BestDistance=d end
                        if CombatStarted and now-CombatStarted>MaxAttackTime or not CombatStarted and now-LastProgress>20 then
                            if candidate==Target then candidate=nil end; clearTarget(true)
                        end
                    end
                end
                if not Target and candidate and root(candidate) and pvp(candidate) then
                    Target=candidate; Started=now; LastProgress=now; BestDistance=math.huge
                end
                local t=root(Target)
                Info.Text=t and (Target.Name.." | "..math.floor((r.Position-t.Position).Magnitude).." studs") or "Ricerca giocatori..."
            end)
            if not ok then Detail.Text="Scan: "..tostring(err):sub(1,45) end
        end
        task.wait(ScanInterval)
    end
end)
task.spawn(function()
    while not Closed do
        if Active and Target then
            local r,t=root(LP),root(Target)
            if r and t and (r.Position-t.Position).Magnitude<=AttackRange and pvp(Target) then
                local token=Generation; local ok,err=pcall(function() powers(); if Active and token==Generation then combat() end end); if not ok then releaseKeys(); Detail.Text="Combat: "..tostring(err):sub(1,45) end
            end
        end
        task.wait(0.15)
    end
end)
local removing=P.PlayerRemoving:Connect(function(p)
    Cache[p]=nil; Skipped[p.UserId]=nil; if Target==p then clearTarget(false) end
end)
local respawn=LP.CharacterAdded:Connect(function() clearTarget(false); table.clear(LastCast) end)
Gui.Destroying:Connect(function()
    Closed=true; Active=false
    Generation=Generation+1
    clearTarget(false); removing:Disconnect(); respawn:Disconnect()
    movement:Disconnect(); noclip:Disconnect()
    RS:UnbindFromRenderStep("AutoBountyAim")
end)
