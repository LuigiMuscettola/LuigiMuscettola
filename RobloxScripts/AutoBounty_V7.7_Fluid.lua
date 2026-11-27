-- V7.7 Fluid: movimento predittivo, schivata progressiva e mira stabilizzata.

repeat task.wait() until game:IsLoaded()
local P=game:GetService("Players"); local RS=game:GetService("RunService"); local VIM=game:GetService("VirtualInputManager"); local LP=P.LocalPlayer
local PG=LP:WaitForChild("PlayerGui"); local Speed=250; local DodgeSpeed=400; local AttackRange=80; local MaxAttackTime=60; local Active,Closed=false,false; local Target,Started=nil,0; local Attachment,Velocity,FlyRoot
local Rotation,Generation=0,0; local Collision,Skipped={},{}; local Direction,Angle=1,0; local NextChange,NextDodge,DodgeUntil=0,0,0
local LastHealth,LastTarget
local EvadeBlend,ThreatTime,DamageUntil=0,0,0
local TargetVelocity=Vector3.zero
local TargetRoot,TargetPosition
local AimAcceleration=Vector3.zero
local LastMousePoint
local InputFailureUntil=0
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
for _,n in ipairs({
    "BloxAimTP","AutoBountyV6","AutoBountyV7",
    "AutoBountyV71","AutoBountyV72","AutoBountyV73",
    "PvPDiagnostic","AutoBountyV8","AutoBountyV74","AutoBountyV75","AutoBountyV76","AutoBountyV77","AutoBountyV76Fluid","AutoBountyV77Fluid"
}) do
    local old=PG:FindFirstChild(n)
    if old then old:Destroy() end end
RS:UnbindFromRenderStep("AutoBountyAim")
local Gui=Instance.new("ScreenGui",PG); Gui.Name="AutoBountyV77Fluid"; Gui.ResetOnSpawn=false; Gui.DisplayOrder=999; local Main=Instance.new("Frame",Gui)
Main.Size=UDim2.fromOffset(260,208); Main.Position=UDim2.new(0.03,0,0.15,0); Main.BackgroundColor3=Color3.fromRGB(20,22,30); Main.Active=true; Main.Draggable=true
Instance.new("UICorner",Main)
local function label(txt,y,h)
    local l=Instance.new("TextLabel",Main); l.Size=UDim2.new(1,-12,0,h); l.Position=UDim2.fromOffset(6,y); l.BackgroundTransparency=1; l.TextColor3=Color3.new(1,1,1)
    l.Font=Enum.Font.GothamBold; l.TextSize=13; l.TextWrapped=true; l.Text=txt
    return l end
label("AUTO BOUNTY V7.7 FLUID",5,25)
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
    LastHealth,LastTarget,TargetRoot,TargetPosition=nil,nil,nil,nil; AngularRate,OrbitBlend,EvadeBlend=0,0,0
    ThreatTime,DamageUntil=0,0; TargetVelocity=Vector3.zero; InOrbit=false
    restore() end
local function startMovement(r)
    if FlyRoot==r and Velocity and Velocity.Parent and Attachment and Attachment.Parent then return end
    stopMovement()
    FlyRoot=r; Attachment=Instance.new("Attachment",r); Velocity=Instance.new("LinearVelocity",r); Velocity.Attachment0=Attachment; Velocity.RelativeTo=Enum.ActuatorRelativeTo.World
    Velocity.VelocityConstraintMode=Enum.VelocityConstraintMode.Vector; Velocity.ForceLimitsEnabled=false; Velocity.VectorVelocity=r.AssemblyLinearVelocity end
local function clampVector(v,max)
    local m=v.Magnitude
    if m>max and m>0 then return v*(max/m) end
    return v
end
local function dodge(now,urgent,delta,forward)
    local radial=flat(delta)
    local tangent=Vector3.new(-radial.Z,0,radial.X)
    local side=tangent.Magnitude>0.01 and tangent.Unit:Dot(flat(forward)) or 0
    Direction=math.abs(side)>0.15 and (side>0 and -1 or 1) or -Direction
    DodgeUntil=now+(urgent and 0.46 or 0.36)
    NextDodge=DodgeUntil+(urgent and 0.42 or 0.62)
    NextChange=NextDodge+0.75
end
local function updateMovement(dt)
    if not Active or not Target then
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
    local raw=clampVector(t.AssemblyLinearVelocity,240)
    if LastTarget~=Target or TargetRoot~=t then
        LastTarget,TargetRoot=Target,t
        Angle=horizontal.Magnitude>0.01 and math.atan2(horizontal.Z,horizontal.X) or 0
        DodgeUntil,NextDodge=0,now+0.15
        NextChange=now+1.8
        LastHealth=h.Health
        InOrbit=false
        OrbitRadius=16
        RadiusNow,HeightNow=16,6
        AngularRate,OrbitBlend,EvadeBlend=0,0,0
        ThreatTime,DamageUntil=0,0
        TargetVelocity=raw
        TargetPosition=t.Position
    end
    if TargetPosition and (t.Position-TargetPosition).Magnitude>math.max(45,dt*300) then
        TargetVelocity=raw
        Angle=horizontal.Magnitude>0.01 and math.atan2(horizontal.Z,horizontal.X) or Angle
        OrbitBlend=0
    else
        TargetVelocity=TargetVelocity:Lerp(raw,alpha(dt,16))
    end
    TargetPosition=t.Position
    if LastHealth and h.Health<LastHealth-0.05 then DamageUntil=now+0.5 end
    LastHealth=h.Health
    local damaged=now<DamageUntil
    local facing=distance>0.01 and t.CFrame.LookVector:Dot(delta.Unit)>0.78
    local closing=distance>0.01 and (TargetVelocity-r.AssemblyLinearVelocity):Dot(delta.Unit)>8
    local threat=distance<38 and facing and (closing or distance<21)
    ThreatTime=threat and math.min(0.25,ThreatTime+dt) or math.max(0,ThreatTime-dt*2)
    if now>=NextDodge and distance<60 and (damaged or ThreatTime>=0.09) then
        dodge(now,damaged,delta,t.CFrame.LookVector)
        ThreatTime,DamageUntil=0,0
    end
    local evading=now<DodgeUntil
    if not evading and now>=NextChange then
        Direction=-Direction
        OrbitRadius=RNG:NextNumber(14,20)
        NextChange=now+RNG:NextNumber(1.7,3.0)
    end
    EvadeBlend=EvadeBlend+((evading and 1 or 0)-EvadeBlend)*alpha(dt,evading and 19 or 8)
    local evade=smoothstep(EvadeBlend)
    if distance<47 then InOrbit=true elseif distance>72 then InOrbit=false end
    OrbitBlend=OrbitBlend+((InOrbit and 1 or 0)-OrbitBlend)*alpha(dt,8)
    local blend=smoothstep(OrbitBlend)
    local rate=Direction*(3.1+evade*3.0)
    AngularRate=AngularRate+(rate-AngularRate)*alpha(dt,evading and 13 or 7)
    if not InOrbit and OrbitBlend<0.035 and horizontal.Magnitude>0.01 then
        Angle=math.atan2(horizontal.Z,horizontal.X)
    else
        Angle=(Angle+dt*AngularRate)%(2*math.pi)
    end
    RadiusNow=RadiusNow+(OrbitRadius+2*math.sin(now*2.2)+12*evade-RadiusNow)*alpha(dt,11)
    HeightNow=HeightNow+(6+2*math.sin(now*3.0)+11*evade-HeightNow)*alpha(dt,10)
    local prediction=clampVector(TargetVelocity*math.clamp(distance/1000,0.045,0.16),24)
    local center=t.Position+prediction
    local radial=Vector3.new(math.cos(Angle),0,math.sin(Angle))
    local tangent=Vector3.new(-radial.Z,0,radial.X)
    local approachDir=horizontal.Magnitude>0.01 and horizontal.Unit or radial
    local approach=center+approachDir*15+Vector3.new(0,6,0)
    local orbit=center+radial*RadiusNow+Vector3.new(0,HeightNow,0)
    local destination=approach:Lerp(orbit,blend)
    local limit=Speed+(DodgeSpeed-Speed)*evade
    local feed=clampVector(TargetVelocity,140)+tangent*(RadiusNow*AngularRate*blend)
    local desired=clampVector((destination-r.Position)*(7+3*evade)+feed,limit)
    local current=Velocity.VectorVelocity
    local step=clampVector((desired-current)*alpha(dt,11+evade*8),dt*(1250+evade*2200))
    Velocity.VectorVelocity=clampVector(current+step,limit)
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
local function resetAim()
    AimRoot,AimPos,AimTime=nil,nil,0
    AimDir,AimFrame,AimCamera=nil,nil,nil
    AimVelocity,AimAcceleration=Vector3.zero,Vector3.zero
    LastMousePoint=nil
end
local function aimAt(p,skill,force,renderDt)
    local t,r,cam=root(p),root(LP),workspace.CurrentCamera
    if not Active or Closed or p~=Target or not t or not r or not cam or not pvp(p) then return false end
    local now=os.clock()
    local pos=t.Position
    local raw=clampVector(t.AssemblyLinearVelocity,250)
    if AimRoot~=t or AimCamera~=cam then
        resetAim()
        AimRoot,AimPos,AimTime,AimVelocity=t,pos,now,raw
        AimCamera=cam
    end
    local sampleDt=now-AimTime
    if sampleDt>=1/60 then
        local displacement=pos-AimPos
        if sampleDt>0.25 or displacement.Magnitude>math.max(45,sampleDt*320) then
            AimVelocity,AimAcceleration=raw,Vector3.zero
            AimDir=nil
        else
            local measured=clampVector(displacement/sampleDt,250)
            local previous=AimVelocity
            AimVelocity=previous:Lerp(raw:Lerp(measured,0.28),alpha(sampleDt,19))
            AimAcceleration=AimAcceleration:Lerp(clampVector((AimVelocity-previous)/sampleDt,260),alpha(sampleDt,8))
        end
        AimPos,AimTime=pos,now
    end
    local distance=(pos-r.Position).Magnitude
    local lead=skill and math.clamp(distance/900+0.025,0.03,0.13) or math.clamp(distance/1800,0.008,0.045)
    local point=pos+Vector3.new(0,1,0)+clampVector(AimVelocity*lead+AimAcceleration*(0.5*lead*lead),skill and 16 or 5)
    local origin=cam.CFrame.Position
    local offset=point-origin
    if offset.Magnitude<0.01 then return false end
    local desired=offset.Unit
    local dt=renderDt or (AimFrame and now-AimFrame or 1/60)
    if renderDt then AimFrame=now end
    local previous=AimDir or cam.CFrame.LookVector
    local factor=alpha(dt,skill and 38 or 20)
    if force then factor=math.max(factor,0.92)
    elseif previous:Dot(desired)<0.5 then factor=math.max(factor,alpha(dt,30)) end
    local nextDir=previous:Lerp(desired,factor)
    AimDir=nextDir.Magnitude>0.01 and nextDir.Unit or desired
    cam.CFrame=CFrame.lookAt(origin,origin+AimDir)
    if skill and MouseSupported and (force or now>=NextMouse) then
        local xy,onScreen=cam:WorldToScreenPoint(point)
        if onScreen and xy.Z>0 then
            local pixel=Vector2.new(xy.X,xy.Y)
            if force or not LastMousePoint or (pixel-LastMousePoint).Magnitude>=1.5 then
                NextMouse=now+1/50
                LastMousePoint=pixel
                MouseSupported=pcall(function()
                    VIM:SendMouseMoveEvent(math.floor(pixel.X+0.5),math.floor(pixel.Y+0.5),game)
                end)
            end
        end
    end
    return true
end
RS:BindToRenderStep("AutoBountyAim",Enum.RenderPriority.Camera.Value+1,function(dt)
    if Active and Target then
        pcall(aimAt,Target,(CastTarget==Target and CastToken==Generation) or os.clock()<CastUntil,false,dt)
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
    for k in pairs(Pressed) do send(k,false) end; table.clear(Pressed); CastTarget,CastToken,CastUntil=nil,nil,0; resetAim()
end
local function cast(tool,k)
    if not Active or Closed or os.clock()<InputFailureUntil or (category(tool)=="Blox Fruit" and k=="V") then return false end
    local current,token=Target,Generation; CastTarget,CastToken=current,token
    local function valid()
        local r,t=root(LP),root(current)
        return Active and not Closed and token==Generation and current==Target and r and t and tool.Parent==LP.Character and pvp(current) and (r.Position-t.Position).Magnitude<=AttackRange
    end
    if not valid() or not aimAt(current,true,true) then CastTarget,CastToken=nil,nil; return false end; RS.Heartbeat:Wait()
    if not valid() or not aimAt(current,true,true) then CastTarget,CastToken=nil,nil; return false end
    if not send(k,true) then CastTarget,CastToken,CastUntil=nil,nil,0; InputFailureUntil=os.clock()+1.5; Detail.Text="Input non disponibile"; return false end
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
        if token~=Generation or not Active or Target~=current then return end
    end
    local used=false
    for _,k in ipairs(Keys) do
        local r,t=root(LP),root(current)
        if not Active or Closed or Generation~=token or Target~=current
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
        table.clear(Skipped); NextRace,NextKen=0,0; MouseSupported=true; InputFailureUntil=0; resetAim()
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
                if not Target and candidate and (Skipped[candidate.UserId] or 0)<=now and root(candidate) and pvp(candidate) then
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
