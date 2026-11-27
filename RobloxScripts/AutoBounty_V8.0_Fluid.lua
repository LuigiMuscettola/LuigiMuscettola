-- V8.0 Fluid: avvio automatico, monitor disponibilita e cambio server pubblico.

repeat task.wait() until game:IsLoaded()
local P=game:GetService("Players"); local RS=game:GetService("RunService"); local VIM=game:GetService("VirtualInputManager"); local LP=P.LocalPlayer
while not LP do task.wait(); LP=P.LocalPlayer end
local PG=LP:WaitForChild("PlayerGui"); local Speed=250; local DodgeSpeed=400; local AttackRange=80; local MaxAttackTime=60; local Active,Closed=false,false; local Target,Started=nil,0; local Attachment,Velocity,FlyRoot
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
local TeleportService=game:GetService("TeleportService")
local HttpService=game:GetService("HttpService")
local AutoStart,AutoHop=true,true
local EmptyDelay,JoinGrace,HopCooldown=18,25,30
local HopBusy,HopQueued=false,false
local EmptySince,NextHop,HopStarted=nil,0,0
local HopSerial=0
local FailedServers={}
local JoinedAt=os.clock()
local ScriptURL="https://raw.githubusercontent.com/LuigiMuscettola/LuigiMuscettola/main/RobloxScripts/AutoBounty_V8.0_Fluid.lua"
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
for _,n in ipairs({
    "BloxAimTP","AutoBountyV6","AutoBountyV7",
    "AutoBountyV71","AutoBountyV72","AutoBountyV73",
    "PvPDiagnostic","AutoBountyV8","AutoBountyV74","AutoBountyV75","AutoBountyV76","AutoBountyV77","AutoBountyV76Fluid","AutoBountyV77Fluid","AutoBountyV78Fluid","AutoBountyV79Fluid","AutoBountyV80Fluid"
}) do
    local old=PG:FindFirstChild(n)
    if old then old:Destroy() end end
RS:UnbindFromRenderStep("AutoBountyAim")
local Gui=Instance.new("ScreenGui",PG); Gui.Name="AutoBountyV80Fluid"; Gui.ResetOnSpawn=false; Gui.DisplayOrder=999; local Main=Instance.new("Frame",Gui)
Main.Size=UDim2.fromOffset(260,264); Main.Position=UDim2.new(0.03,0,0.15,0); Main.BackgroundColor3=Color3.fromRGB(20,22,30); Main.Active=true; Main.Draggable=true
Instance.new("UICorner",Main)
local function label(txt,y,h)
    local l=Instance.new("TextLabel",Main); l.Size=UDim2.new(1,-12,0,h); l.Position=UDim2.fromOffset(6,y); l.BackgroundTransparency=1; l.TextColor3=Color3.new(1,1,1)
    l.Font=Enum.Font.GothamBold; l.TextSize=13; l.TextWrapped=true; l.Text=txt
    return l end
label("AUTO BOUNTY V8.0 FLUID",5,25)
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
local function humanoid(p)
    return p and p.Character
        and p.Character:FindFirstChildOfClass("Humanoid") end
local function root(p)
    local h=humanoid(p)
    if not h or h.Health<=0 then return nil end
    return p.Character:FindFirstChild("HumanoidRootPart") end
local function normalize(s)
    return s:lower():gsub("[^%a%d]","") end
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
    return best,on,loaded end
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
    DodgeStart,DodgeDuration=0,0; MoveAcceleration=Vector3.zero
    RangeNow,DodgeMaxRadius,CastDistance=14,21,29; RangeTool=nil; RangeRefresh=0
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
local function smootherstep(x)
    x=math.clamp(x,0,1)
    return x*x*x*(x*(x*6-15)+10)
end
local function dodge(now,urgent,delta,forward)
    -- Preserve orbital direction: avoid a hard reversal at dodge onset.
    DodgeStart=now
    DodgeDuration=urgent and 0.64 or 0.56
    DodgeStrength=urgent and 1 or 0.85
    DodgeUntil=now+DodgeDuration
    NextDodge=DodgeUntil+(urgent and 0.27 or 0.46)
    NextChange=NextDodge+0.8
end
local function updateMovement(dt)
    if not Active or HopBusy or not Target then
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
        RangeRefresh=now+0.10
        RangeTool=LP.Character and LP.Character:FindFirstChildOfClass("Tool")
    end
    local profile=rangeProfile(RangeTool)
    RangeNow=RangeNow+(profile[1]-RangeNow)*alpha(dt,11)
    DodgeMaxRadius=profile[2]
    CastDistance=profile[3]
    if LastTarget~=Target or TargetRoot~=t then
        LastTarget,TargetRoot=Target,t
        Angle=horizontal.Magnitude>0.01 and math.atan2(horizontal.Z,horizontal.X) or 0
        DodgeUntil,NextDodge=0,now+0.15
        DodgeStart,DodgeDuration=0,0; MoveAcceleration=Vector3.zero
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
    local threat=distance<43 and facing and (closing or distance<23)
    ThreatTime=threat and math.min(0.25,ThreatTime+dt) or math.max(0,ThreatTime-dt*2)
    if now>=NextDodge and distance<60 and (damaged or ThreatTime>=0.075) then
        dodge(now,damaged,delta,t.CFrame.LookVector)
        ThreatTime,DamageUntil=0,0
    end
    local evading=now<DodgeUntil
    if not evading and EvadeBlend<0.02 and now>=NextChange then
        Direction=-Direction
        OrbitRadius=RangeNow+RNG:NextNumber(-1,1)
        NextChange=now+RNG:NextNumber(2.6,4.2)
    end
    local phase=DodgeDuration>0 and math.clamp((now-DodgeStart)/DodgeDuration,0,1) or 1
    local envelope=0
    if evading then
        if phase<0.26 then envelope=smootherstep(phase/0.26)
        elseif phase<0.54 then envelope=1
        else envelope=1-smootherstep((phase-0.54)/0.46) end
    end
    EvadeBlend=EvadeBlend+(envelope*DodgeStrength-EvadeBlend)*alpha(dt,22)
    local evade=EvadeBlend
    if distance<CastDistance+5 then InOrbit=true elseif distance>CastDistance+14 then InOrbit=false end
    OrbitBlend=OrbitBlend+((InOrbit and 1 or 0)-OrbitBlend)*alpha(dt,8)
    local blend=smoothstep(OrbitBlend)
    local rate=Direction*(2.65+evade*2.15)
    AngularRate=AngularRate+(rate-AngularRate)*alpha(dt,evading and 10 or 5)
    if not InOrbit and OrbitBlend<0.035 and horizontal.Magnitude>0.01 then
        Angle=math.atan2(horizontal.Z,horizontal.X)
    else
        Angle=(Angle+dt*AngularRate)%(2*math.pi)
    end
    local casting=CastTarget==Target and CastToken==Generation
    local activeMax=casting and math.max(RangeNow+2,DodgeMaxRadius-2) or DodgeMaxRadius
    local baseRadius=math.clamp(RangeNow+(OrbitRadius-RangeNow)*0.3+0.65*math.sin(now*1.8),10,activeMax)
    local wantedRadius=baseRadius+(activeMax-baseRadius)*evade
    RadiusNow=RadiusNow+(wantedRadius-RadiusNow)*alpha(dt,13)
    HeightNow=HeightNow+(3.0+0.7*math.sin(now*2.0)+2.0*evade-HeightNow)*alpha(dt,13)
    local nearBlend=1-smoothstep((distance-22)/30)
    local leadTime=0.035+0.08*(1-nearBlend)
    local prediction=clampVector(TargetVelocity*leadTime,5+19*(1-nearBlend))
    local center=t.Position+prediction
    local radial=Vector3.new(math.cos(Angle),0,math.sin(Angle))
    local tangent=Vector3.new(-radial.Z,0,radial.X)
    local approachDir=horizontal.Magnitude>0.01 and horizontal.Unit or radial
    local approach=center+approachDir*RangeNow+Vector3.new(0,3.5,0)
    local orbit=center+radial*RadiusNow+Vector3.new(0,HeightNow,0)
    local destination=approach:Lerp(orbit,blend)
    -- Limit the relative speed in close orbit, not the target's own movement.
    local relativeCap=(Speed*(1-blend)+(75+evade*55)*blend)
    local targetFeed=clampVector(TargetVelocity,230)
    local correction=(destination-r.Position)*(8+2*evade)+tangent*(RadiusNow*AngularRate*blend)
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
    local wantedAcceleration=clampVector((desired-current)*(10+evade*6),1500+evade*1850)
    local jerkLimit=24000+evade*18000
    MoveAcceleration=MoveAcceleration+clampVector(wantedAcceleration-MoveAcceleration,jerkLimit*dt)
    local nextVelocity=current+MoveAcceleration*dt
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
    Velocity.VectorVelocity=clampVector(nextVelocity,cap)
end
local movement=RS.Heartbeat:Connect(function(dt)
    if Active then local ok,err=pcall(updateMovement,dt); if not ok then stopMovement(); Detail.Text="Volo: "..tostring(err):sub(1,45) end end
end)
local noclip=RS.Stepped:Connect(function()
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
    local dt=math.clamp(renderDt or now-AimLastUpdate,0,0.08)
    AimLastUpdate=now
    -- Avoid advancing the same filter twice when a cast and render coincide.
    local sampleDt=now-AimTime
    if sampleDt>=1/60 then
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
            local trust=math.clamp(0.4-disagreement/500,0.07,0.4)
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
                AimSampleVelocity=oldVelocity:Lerp(sample,alpha(sampleDt,42))
                AimStableVelocity=AimStableVelocity:Lerp(AimSampleVelocity,alpha(sampleDt,31))
                local acceleration=clampVector((AimSampleVelocity-oldVelocity)/sampleDt,420)
                AimAcceleration=AimAcceleration:Lerp(acceleration,alpha(sampleDt,16))
            end
            AimVelocity=AimStableVelocity
        end
        AimPos,AimTime=position,now
        AimLastRaw=raw
    end
    -- Use the latest replicated position directly; only smooth the animated body offset.
    AimOffset=AimOffset:Lerp(bodyOffset,alpha(dt,30))
    local currentVelocity=AimVelocity:Lerp(raw,0.42)
    if raw.Magnitude<3 and AimVelocity.Magnitude<6 then currentVelocity=Vector3.zero end
    if raw.Magnitude>8 and currentVelocity.Magnitude>8 and raw.Unit:Dot(currentVelocity.Unit)<0.5 then
        currentVelocity=raw
    end
    local distance=(position-r.Position).Magnitude
    local desiredLead=skill and math.clamp(0.010+distance/1500,0.012,0.075) or math.clamp(distance/3000,0.003,0.024)
    if currentVelocity.Magnitude<3 then desiredLead=0 end
    if force then AimLead=desiredLead else AimLead=AimLead+(desiredLead-AimLead)*alpha(dt,55) end
    local lead=AimLead
    local acceleration=AimAcceleration
    if currentVelocity.Magnitude<4 then acceleration=Vector3.zero end
    local prediction=clampVector(currentVelocity*lead+acceleration*(0.5*lead*lead),skill and 11 or 4)
    local desiredPoint=position+AimOffset+prediction
    AimPoint=desiredPoint
    local origin=cam.CFrame.Position
    local offset=desiredPoint-origin
    if offset.Magnitude<0.01 then return false end
    local desired=offset.Unit
    local previous=AimDir or cam.CFrame.LookVector
    local angle=math.acos(math.clamp(previous:Dot(desired),-1,1))
    local rate=(skill and 95 or 48)+math.min(angle*45,55)
    if force then
        AimDir=desired
    else
        AimDir=rotateTowards(previous,desired,alpha(dt,rate))
    end
    local up=math.abs(AimDir.Y)>0.9999 and Vector3.zAxis or Vector3.yAxis
    cam.CFrame=CFrame.lookAt(origin,origin+AimDir,up)
    if skill and (MouseSupported or now>=AimMouseRetryAt) and (force or now>=NextMouse) then
        local xy,onScreen=cam:WorldToScreenPoint(desiredPoint)
        NextMouse=now+1/90
        if onScreen and xy.Z>0 then
            local pixel=Vector2.new(xy.X,xy.Y)
            if force or not LastMousePoint or (pixel-LastMousePoint).Magnitude>=0.5 then
                local ok=pcall(function()
                    VIM:SendMouseMoveEvent(math.floor(pixel.X+0.5),math.floor(pixel.Y+0.5),game)
                end)
                MouseSupported=ok
                if ok then
                    LastMousePoint=pixel
                    AimMouseFailures=0
                else
                    AimMouseFailures=AimMouseFailures+1
                    AimMouseRetryAt=now+math.min(8,0.5*2^math.min(AimMouseFailures,4))
                end
            end
        end
    end
    return true
end
RS:BindToRenderStep("AutoBountyAim",Enum.RenderPriority.Camera.Value+1,function(dt)
    if Active and Target and os.clock()>=AimRetryAt then
        local ok,err=pcall(aimAt,Target,(CastTarget==Target and CastToken==Generation) or os.clock()<CastUntil,false,dt)
        if not ok then
            AimRetryAt=os.clock()+0.25
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
        return Active and not Closed and token==Generation and current==Target and r and t and tool.Parent==LP.Character and pvp(current) and (r.Position-t.Position).Magnitude<=math.min(AttackRange,rangeProfile(tool)[3]+3)
    end
    if not valid() or not aimAt(current,true,true) then CastTarget,CastToken=nil,nil; return false end; RS.RenderStepped:Wait()
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
        if (r.Position-t.Position).Magnitude>rangeProfile(tool)[3] then break end
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
local function queueRestart()
    if HopQueued then return true end
    local queue=queue_on_teleport
    if type(queue)~="function" and type(syn)=="table" then queue=syn.queue_on_teleport end
    if type(queue)~="function" then return false end
    local code="repeat task.wait() until game:IsLoaded(); local ok,err=pcall(function() loadstring(game:HttpGet("..string.format("%q",ScriptURL).."))() end); if not ok then warn(err) end"
    local ok=pcall(queue,code)
    HopQueued=ok
    return ok
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
local function startHop()
    if HopBusy or Closed or not Active or not AutoHop then return end
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
            local queued=queueRestart()
            FailedServers[id]=os.clock()+180
            HopStarted=os.clock()
            HopStatus.Text=queued and "Cambio server..." or "Cambio server | riavvio manuale"
            TeleportService:TeleportToPlaceInstance(game.PlaceId,id,LP)
        end)
        if not ok then hopFailed("Errore server",serial) end
    end)
end
local teleportFailure=TeleportService.TeleportInitFailed:Connect(function(player)
    if player==LP and HopBusy then hopFailed("Teleport fallito",HopSerial) end
end)
local function monitorHop(candidate,allowed,loaded,now)
    if not AutoHop then EmptySince=nil; return end
    if now-JoinedAt<JoinGrace then
        EmptySince=nil
        HopStatus.Text="Caricamento server..."
        return
    end
    if Target or candidate or allowed>loaded then
        EmptySince=nil
        HopStatus.Text="Server hop: ON"
        return
    end
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
    Active=value
    Generation=Generation+1
    Button.Text=Active and "AUTO BOUNTY: ON" or "AUTO BOUNTY: OFF"
    Button.BackgroundColor3=Active and Color3.fromRGB(30,160,75)
        or Color3.fromRGB(170,40,40)
    if not Active then
        HopSerial=HopSerial+1; HopBusy=false; EmptySince=nil
        clearTarget(false)
        Info.Text="Disattivato"
    else
        table.clear(Skipped); NextRace,NextKen=0,0; MouseSupported=true; InputFailureUntil=0; resetAim()
    end
end
Button.Activated:Connect(function() setActive(not Active) end)
HopToggle.Activated:Connect(function()
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
                local candidate,allowed,loaded=findTarget()
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
                monitorHop(candidate,allowed,loaded,now)
            end)
            if not ok then Detail.Text="Scan: "..tostring(err):sub(1,45) end
        end
        task.wait(ScanInterval)
    end
end)
task.spawn(function()
    while not Closed do
        if Active and not HopBusy and Target then
            local r,t=root(LP),root(Target)
            if r and t and (r.Position-t.Position).Magnitude<=math.min(AttackRange,CastDistance+5) and pvp(Target) then
                local token=Generation; local ok,err=pcall(function() powers(); if Active and token==Generation then combat() end end); if not ok then releaseKeys(); Detail.Text="Combat: "..tostring(err):sub(1,45) end
            end
        end
        task.wait(0.15)
    end
end)
local removing=P.PlayerRemoving:Connect(function(p)
    Cache[p]=nil; Skipped[p.UserId]=nil; if Target==p then clearTarget(false) end
end)
local respawn=LP.CharacterAdded:Connect(function() EmptySince=nil; clearTarget(false); table.clear(LastCast) end)
Gui.Destroying:Connect(function()
    Closed=true; Active=false
    HopSerial=HopSerial+1; HopBusy=false; teleportFailure:Disconnect()
    Generation=Generation+1
    clearTarget(false); removing:Disconnect(); respawn:Disconnect()
    movement:Disconnect(); noclip:Disconnect()
    RS:UnbindFromRenderStep("AutoBountyAim")
end)

if AutoStart and not Closed then setActive(true) end
