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
    warn("[V11.0]["..area.."] "..message)
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

-- Local adaptive decision engine. No network, credentials or external model.
-- This is a bounded heuristic controller, not a neural network.
local Adaptive={}
function Adaptive.clamp(value,lo,hi)
    if type(value)~="number" or value~=value then return lo end
    return math.max(lo,math.min(hi,value))
end
function Adaptive.mix(old,value,weight)
    return old+(value-old)*Adaptive.clamp(weight,0,1)
end
function Adaptive.new()
    return {
        enabled=true,healthy=true,mode="idle",reason="startup",
        frame=1/60,threat=0,innovation=0,damage=0,
        nextUpdate=0,lastTick=0,updates=0,testsPassed=0,testsTotal=0,
        lastTarget=nil,lastHealth=nil,lastOwnHealth=nil,lastAttempts=0,lastSkills=0,
        lastErrors=0,lastEquips=0,inputRate=0,skillRate=0,errorRate=0,equipRate=0,
        progressRate=0,history={},historyIndex=1,historySize=0,
        targetMemory=setmetatable({},{__mode="k"}),
        output={mode="idle",dodgeScale=1,leadScale=1,recoveryScale=1,holdScale=1,
            orbitScale=1,attack=false,reason="startup"}
    }
end
function Adaptive.decide(input)
    local frame=Adaptive.clamp(input.frame or 1/60,0.004,0.2)
    local threat=Adaptive.clamp(input.threat or 0,0,1)
    local innovation=Adaptive.clamp(input.innovation or 0,0,300)
    local errorRate=Adaptive.clamp(input.errorRate or 0,0,10)
    local equipRate=Adaptive.clamp(input.equipRate or 0,0,20)
    local progress=Adaptive.clamp(input.progress or 0,0,30000)
    local distance=Adaptive.clamp(input.distance or 0,0,10000)
    local mode,reason="engage","normal"
    local attack=true
    -- State precedence is explicit. No adaptive output overrides these guards.
    if not input.active then mode,reason,attack="idle","disabled",false
    elseif input.healing then mode,reason,attack="recover","low HP",false
    elseif input.hopping then mode,reason,attack="hop","server change",false
    elseif not input.target then mode,reason,attack="search","no target",false
    elseif threat>=0.72 then mode,reason="evade","high threat"
    elseif frame>=0.045 or errorRate>=1.5 then mode,reason="stable","frame/input pressure"
    elseif distance>35 then mode,reason="approach","out of range"
    elseif progress<1 and equipRate>4 then mode,reason="weave","weapon churn"
    else mode,reason="engage","normal" end
    local slow=Adaptive.clamp((frame-0.020)/0.040,0,1)
    local uncertain=Adaptive.clamp(innovation/150,0,1)
    local output={
        mode=mode,reason=reason,attack=attack,
        dodgeScale=Adaptive.clamp(1+0.12*threat-0.10*slow,0.90,1.12),
        leadScale=Adaptive.clamp(1-0.35*uncertain,0.65,1),
        recoveryScale=Adaptive.clamp(1+0.45*slow+0.12*errorRate,1,1.65),
        holdScale=Adaptive.clamp(1+0.35*slow+0.10*errorRate,1,1.55),
        orbitScale=Adaptive.clamp(1+0.12*threat-0.12*slow,0.88,1.12)
    }
    if mode=="weave" then output.recoveryScale=math.max(output.recoveryScale,1.12) end
    return output
end
function Adaptive.record(state,sample,now)
    state.history[state.historyIndex]={
        at=now,mode=state.mode,threat=sample.threat,
        frame=sample.frame,progress=state.progressRate,
        inputs=state.inputRate,errors=state.errorRate
    }
    state.historyIndex=state.historyIndex%120+1
    state.historySize=math.min(120,state.historySize+1)
end
function Adaptive.observe(state,sample,now)
    if now<state.nextUpdate then return state.output end
    state.nextUpdate=now+0.15
    local elapsed=state.lastTick>0 and Adaptive.clamp(now-state.lastTick,0.05,2) or 0.15
    state.lastTick=now
    state.frame=Adaptive.mix(state.frame,sample.frame or 1/60,0.22)
    state.threat=Adaptive.mix(state.threat,sample.threat or 0,0.55)
    state.innovation=Adaptive.mix(state.innovation,sample.innovation or 0,0.30)
    local attempts=sample.attempts or 0
    local skills=sample.skills or 0
    local errors=sample.errors or 0
    local equips=sample.equips or 0
    state.inputRate=Adaptive.mix(state.inputRate,math.max(0,attempts-state.lastAttempts)/elapsed,0.25)
    state.skillRate=Adaptive.mix(state.skillRate,math.max(0,skills-state.lastSkills)/elapsed,0.25)
    state.errorRate=Adaptive.mix(state.errorRate,math.max(0,errors-state.lastErrors)/elapsed,0.25)
    state.equipRate=Adaptive.mix(state.equipRate,math.max(0,equips-state.lastEquips)/elapsed,0.25)
    state.lastAttempts,state.lastSkills,state.lastErrors,state.lastEquips=attempts,skills,errors,equips
    if sample.targetId~=state.lastTarget then
        state.lastTarget=sample.targetId
        state.lastHealth=sample.health
        state.progressRate=0
    elseif sample.health and state.lastHealth then
        local observed=math.max(0,state.lastHealth-sample.health)/elapsed
        state.progressRate=Adaptive.mix(state.progressRate,observed,0.25)
        state.lastHealth=sample.health
    end
    if sample.ownHealth and state.lastOwnHealth then
        state.damage=Adaptive.mix(state.damage,math.max(0,state.lastOwnHealth-sample.ownHealth)/elapsed,0.25)
    end
    state.lastOwnHealth=sample.ownHealth
    if sample.targetId then
        local memory=state.targetMemory[sample.targetId] or {risk=0,samples=0,last=now}
        memory.risk=Adaptive.mix(memory.risk,Adaptive.clamp(state.damage/2500,0,1),0.12)
        memory.samples=memory.samples+1
        memory.last=now
        state.targetMemory[sample.targetId]=memory
    end
    local output=Adaptive.decide({
        active=sample.active,healing=sample.healing,hopping=sample.hopping,target=sample.targetId~=nil,
        frame=state.frame,threat=math.max(state.threat,sample.threat or 0),
        innovation=state.innovation,errorRate=state.errorRate,equipRate=state.equipRate,
        progress=state.progressRate,distance=sample.distance
    })
    state.mode,state.reason=output.mode,output.reason
    state.output=output
    state.updates=state.updates+1
    Adaptive.record(state,sample,now)
    return output
end
function Adaptive.factor(state,key)
    if not state.enabled or not state.healthy then return 1 end
    return state.output[key] or 1
end
function Adaptive.targetPenalty(state,player,now)
    if not state.enabled or not state.healthy then return 0 end
    local memory=state.targetMemory[player]
    if not memory or memory.samples<3 then return 0 end
    local age=Adaptive.clamp((now-memory.last)/90,0,1)
    return memory.risk*(1-age)*100
end
function Adaptive.testCase(case)
    local result=Adaptive.decide(case.input)
    if result.mode~=case.expected then return false,"mode" end
    if result.attack~=case.attack then return false,"guard" end
    if result.dodgeScale<0.90 or result.dodgeScale>1.12 then return false,"dodge" end
    if result.leadScale<0.65 or result.leadScale>1 then return false,"lead" end
    if result.recoveryScale<1 or result.recoveryScale>1.65 then return false,"recovery" end
    if result.holdScale<1 or result.holdScale>1.55 then return false,"hold" end
    if result.orbitScale<0.88 or result.orbitScale>1.12 then return false,"orbit" end
    return true
end
-- Regression cases are explicit, generated from combinations of operational state,
-- frame time, threat, distance and input pressure. They are not executed per frame.
function Adaptive.runTests()
    local passed,total,first=0,0,nil
    local function check(case)
        total=total+1
        local ok,reason=Adaptive.testCase(case)
        if ok then passed=passed+1 elseif not first then first=case.name..":"..reason end
    end
    check({
        name="state-001",
        input={active=false,healing=false,hopping=false,target=false,
            frame=0.012,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-002",
        input={active=false,healing=false,hopping=false,target=false,
            frame=0.012,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-003",
        input={active=false,healing=false,hopping=false,target=false,
            frame=0.012,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-004",
        input={active=false,healing=false,hopping=false,target=false,
            frame=0.012,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-005",
        input={active=false,healing=false,hopping=false,target=false,
            frame=0.012,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-006",
        input={active=false,healing=false,hopping=false,target=false,
            frame=0.012,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-007",
        input={active=false,healing=false,hopping=false,target=false,
            frame=0.012,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-008",
        input={active=false,healing=false,hopping=false,target=false,
            frame=0.012,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-009",
        input={active=false,healing=false,hopping=false,target=false,
            frame=0.05,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-010",
        input={active=false,healing=false,hopping=false,target=false,
            frame=0.05,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-011",
        input={active=false,healing=false,hopping=false,target=false,
            frame=0.05,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-012",
        input={active=false,healing=false,hopping=false,target=false,
            frame=0.05,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-013",
        input={active=false,healing=false,hopping=false,target=false,
            frame=0.05,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-014",
        input={active=false,healing=false,hopping=false,target=false,
            frame=0.05,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-015",
        input={active=false,healing=false,hopping=false,target=false,
            frame=0.05,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-016",
        input={active=false,healing=false,hopping=false,target=false,
            frame=0.05,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-017",
        input={active=false,healing=false,hopping=false,target=true,
            frame=0.012,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-018",
        input={active=false,healing=false,hopping=false,target=true,
            frame=0.012,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-019",
        input={active=false,healing=false,hopping=false,target=true,
            frame=0.012,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-020",
        input={active=false,healing=false,hopping=false,target=true,
            frame=0.012,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-021",
        input={active=false,healing=false,hopping=false,target=true,
            frame=0.012,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-022",
        input={active=false,healing=false,hopping=false,target=true,
            frame=0.012,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-023",
        input={active=false,healing=false,hopping=false,target=true,
            frame=0.012,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-024",
        input={active=false,healing=false,hopping=false,target=true,
            frame=0.012,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-025",
        input={active=false,healing=false,hopping=false,target=true,
            frame=0.05,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-026",
        input={active=false,healing=false,hopping=false,target=true,
            frame=0.05,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-027",
        input={active=false,healing=false,hopping=false,target=true,
            frame=0.05,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-028",
        input={active=false,healing=false,hopping=false,target=true,
            frame=0.05,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-029",
        input={active=false,healing=false,hopping=false,target=true,
            frame=0.05,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-030",
        input={active=false,healing=false,hopping=false,target=true,
            frame=0.05,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-031",
        input={active=false,healing=false,hopping=false,target=true,
            frame=0.05,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-032",
        input={active=false,healing=false,hopping=false,target=true,
            frame=0.05,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-033",
        input={active=false,healing=false,hopping=true,target=false,
            frame=0.012,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-034",
        input={active=false,healing=false,hopping=true,target=false,
            frame=0.012,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-035",
        input={active=false,healing=false,hopping=true,target=false,
            frame=0.012,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-036",
        input={active=false,healing=false,hopping=true,target=false,
            frame=0.012,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-037",
        input={active=false,healing=false,hopping=true,target=false,
            frame=0.012,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-038",
        input={active=false,healing=false,hopping=true,target=false,
            frame=0.012,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-039",
        input={active=false,healing=false,hopping=true,target=false,
            frame=0.012,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-040",
        input={active=false,healing=false,hopping=true,target=false,
            frame=0.012,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-041",
        input={active=false,healing=false,hopping=true,target=false,
            frame=0.05,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-042",
        input={active=false,healing=false,hopping=true,target=false,
            frame=0.05,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-043",
        input={active=false,healing=false,hopping=true,target=false,
            frame=0.05,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-044",
        input={active=false,healing=false,hopping=true,target=false,
            frame=0.05,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-045",
        input={active=false,healing=false,hopping=true,target=false,
            frame=0.05,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-046",
        input={active=false,healing=false,hopping=true,target=false,
            frame=0.05,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-047",
        input={active=false,healing=false,hopping=true,target=false,
            frame=0.05,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-048",
        input={active=false,healing=false,hopping=true,target=false,
            frame=0.05,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-049",
        input={active=false,healing=false,hopping=true,target=true,
            frame=0.012,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-050",
        input={active=false,healing=false,hopping=true,target=true,
            frame=0.012,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-051",
        input={active=false,healing=false,hopping=true,target=true,
            frame=0.012,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-052",
        input={active=false,healing=false,hopping=true,target=true,
            frame=0.012,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-053",
        input={active=false,healing=false,hopping=true,target=true,
            frame=0.012,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-054",
        input={active=false,healing=false,hopping=true,target=true,
            frame=0.012,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-055",
        input={active=false,healing=false,hopping=true,target=true,
            frame=0.012,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-056",
        input={active=false,healing=false,hopping=true,target=true,
            frame=0.012,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-057",
        input={active=false,healing=false,hopping=true,target=true,
            frame=0.05,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-058",
        input={active=false,healing=false,hopping=true,target=true,
            frame=0.05,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-059",
        input={active=false,healing=false,hopping=true,target=true,
            frame=0.05,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-060",
        input={active=false,healing=false,hopping=true,target=true,
            frame=0.05,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-061",
        input={active=false,healing=false,hopping=true,target=true,
            frame=0.05,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-062",
        input={active=false,healing=false,hopping=true,target=true,
            frame=0.05,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-063",
        input={active=false,healing=false,hopping=true,target=true,
            frame=0.05,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-064",
        input={active=false,healing=false,hopping=true,target=true,
            frame=0.05,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-065",
        input={active=false,healing=true,hopping=false,target=false,
            frame=0.012,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-066",
        input={active=false,healing=true,hopping=false,target=false,
            frame=0.012,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-067",
        input={active=false,healing=true,hopping=false,target=false,
            frame=0.012,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-068",
        input={active=false,healing=true,hopping=false,target=false,
            frame=0.012,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-069",
        input={active=false,healing=true,hopping=false,target=false,
            frame=0.012,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-070",
        input={active=false,healing=true,hopping=false,target=false,
            frame=0.012,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-071",
        input={active=false,healing=true,hopping=false,target=false,
            frame=0.012,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-072",
        input={active=false,healing=true,hopping=false,target=false,
            frame=0.012,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-073",
        input={active=false,healing=true,hopping=false,target=false,
            frame=0.05,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-074",
        input={active=false,healing=true,hopping=false,target=false,
            frame=0.05,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-075",
        input={active=false,healing=true,hopping=false,target=false,
            frame=0.05,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-076",
        input={active=false,healing=true,hopping=false,target=false,
            frame=0.05,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-077",
        input={active=false,healing=true,hopping=false,target=false,
            frame=0.05,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-078",
        input={active=false,healing=true,hopping=false,target=false,
            frame=0.05,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-079",
        input={active=false,healing=true,hopping=false,target=false,
            frame=0.05,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-080",
        input={active=false,healing=true,hopping=false,target=false,
            frame=0.05,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-081",
        input={active=false,healing=true,hopping=false,target=true,
            frame=0.012,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-082",
        input={active=false,healing=true,hopping=false,target=true,
            frame=0.012,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-083",
        input={active=false,healing=true,hopping=false,target=true,
            frame=0.012,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-084",
        input={active=false,healing=true,hopping=false,target=true,
            frame=0.012,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-085",
        input={active=false,healing=true,hopping=false,target=true,
            frame=0.012,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-086",
        input={active=false,healing=true,hopping=false,target=true,
            frame=0.012,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-087",
        input={active=false,healing=true,hopping=false,target=true,
            frame=0.012,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-088",
        input={active=false,healing=true,hopping=false,target=true,
            frame=0.012,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-089",
        input={active=false,healing=true,hopping=false,target=true,
            frame=0.05,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-090",
        input={active=false,healing=true,hopping=false,target=true,
            frame=0.05,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-091",
        input={active=false,healing=true,hopping=false,target=true,
            frame=0.05,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-092",
        input={active=false,healing=true,hopping=false,target=true,
            frame=0.05,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-093",
        input={active=false,healing=true,hopping=false,target=true,
            frame=0.05,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-094",
        input={active=false,healing=true,hopping=false,target=true,
            frame=0.05,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-095",
        input={active=false,healing=true,hopping=false,target=true,
            frame=0.05,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-096",
        input={active=false,healing=true,hopping=false,target=true,
            frame=0.05,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-097",
        input={active=false,healing=true,hopping=true,target=false,
            frame=0.012,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-098",
        input={active=false,healing=true,hopping=true,target=false,
            frame=0.012,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-099",
        input={active=false,healing=true,hopping=true,target=false,
            frame=0.012,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-100",
        input={active=false,healing=true,hopping=true,target=false,
            frame=0.012,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-101",
        input={active=false,healing=true,hopping=true,target=false,
            frame=0.012,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-102",
        input={active=false,healing=true,hopping=true,target=false,
            frame=0.012,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-103",
        input={active=false,healing=true,hopping=true,target=false,
            frame=0.012,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-104",
        input={active=false,healing=true,hopping=true,target=false,
            frame=0.012,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-105",
        input={active=false,healing=true,hopping=true,target=false,
            frame=0.05,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-106",
        input={active=false,healing=true,hopping=true,target=false,
            frame=0.05,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-107",
        input={active=false,healing=true,hopping=true,target=false,
            frame=0.05,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-108",
        input={active=false,healing=true,hopping=true,target=false,
            frame=0.05,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-109",
        input={active=false,healing=true,hopping=true,target=false,
            frame=0.05,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-110",
        input={active=false,healing=true,hopping=true,target=false,
            frame=0.05,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-111",
        input={active=false,healing=true,hopping=true,target=false,
            frame=0.05,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-112",
        input={active=false,healing=true,hopping=true,target=false,
            frame=0.05,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-113",
        input={active=false,healing=true,hopping=true,target=true,
            frame=0.012,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-114",
        input={active=false,healing=true,hopping=true,target=true,
            frame=0.012,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-115",
        input={active=false,healing=true,hopping=true,target=true,
            frame=0.012,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-116",
        input={active=false,healing=true,hopping=true,target=true,
            frame=0.012,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-117",
        input={active=false,healing=true,hopping=true,target=true,
            frame=0.012,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-118",
        input={active=false,healing=true,hopping=true,target=true,
            frame=0.012,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-119",
        input={active=false,healing=true,hopping=true,target=true,
            frame=0.012,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-120",
        input={active=false,healing=true,hopping=true,target=true,
            frame=0.012,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-121",
        input={active=false,healing=true,hopping=true,target=true,
            frame=0.05,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-122",
        input={active=false,healing=true,hopping=true,target=true,
            frame=0.05,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-123",
        input={active=false,healing=true,hopping=true,target=true,
            frame=0.05,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-124",
        input={active=false,healing=true,hopping=true,target=true,
            frame=0.05,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-125",
        input={active=false,healing=true,hopping=true,target=true,
            frame=0.05,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-126",
        input={active=false,healing=true,hopping=true,target=true,
            frame=0.05,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-127",
        input={active=false,healing=true,hopping=true,target=true,
            frame=0.05,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="idle",attack=false
    })
    check({
        name="state-128",
        input={active=false,healing=true,hopping=true,target=true,
            frame=0.05,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="idle",attack=false
    })
    check({
        name="state-129",
        input={active=true,healing=false,hopping=false,target=false,
            frame=0.012,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="search",attack=false
    })
    check({
        name="state-130",
        input={active=true,healing=false,hopping=false,target=false,
            frame=0.012,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="search",attack=false
    })
    check({
        name="state-131",
        input={active=true,healing=false,hopping=false,target=false,
            frame=0.012,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="search",attack=false
    })
    check({
        name="state-132",
        input={active=true,healing=false,hopping=false,target=false,
            frame=0.012,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="search",attack=false
    })
    check({
        name="state-133",
        input={active=true,healing=false,hopping=false,target=false,
            frame=0.012,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="search",attack=false
    })
    check({
        name="state-134",
        input={active=true,healing=false,hopping=false,target=false,
            frame=0.012,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="search",attack=false
    })
    check({
        name="state-135",
        input={active=true,healing=false,hopping=false,target=false,
            frame=0.012,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="search",attack=false
    })
    check({
        name="state-136",
        input={active=true,healing=false,hopping=false,target=false,
            frame=0.012,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="search",attack=false
    })
    check({
        name="state-137",
        input={active=true,healing=false,hopping=false,target=false,
            frame=0.05,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="search",attack=false
    })
    check({
        name="state-138",
        input={active=true,healing=false,hopping=false,target=false,
            frame=0.05,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="search",attack=false
    })
    check({
        name="state-139",
        input={active=true,healing=false,hopping=false,target=false,
            frame=0.05,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="search",attack=false
    })
    check({
        name="state-140",
        input={active=true,healing=false,hopping=false,target=false,
            frame=0.05,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="search",attack=false
    })
    check({
        name="state-141",
        input={active=true,healing=false,hopping=false,target=false,
            frame=0.05,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="search",attack=false
    })
    check({
        name="state-142",
        input={active=true,healing=false,hopping=false,target=false,
            frame=0.05,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="search",attack=false
    })
    check({
        name="state-143",
        input={active=true,healing=false,hopping=false,target=false,
            frame=0.05,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="search",attack=false
    })
    check({
        name="state-144",
        input={active=true,healing=false,hopping=false,target=false,
            frame=0.05,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="search",attack=false
    })
    check({
        name="state-145",
        input={active=true,healing=false,hopping=false,target=true,
            frame=0.012,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="weave",attack=true
    })
    check({
        name="state-146",
        input={active=true,healing=false,hopping=false,target=true,
            frame=0.012,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="stable",attack=true
    })
    check({
        name="state-147",
        input={active=true,healing=false,hopping=false,target=true,
            frame=0.012,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="approach",attack=true
    })
    check({
        name="state-148",
        input={active=true,healing=false,hopping=false,target=true,
            frame=0.012,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="stable",attack=true
    })
    check({
        name="state-149",
        input={active=true,healing=false,hopping=false,target=true,
            frame=0.012,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="evade",attack=true
    })
    check({
        name="state-150",
        input={active=true,healing=false,hopping=false,target=true,
            frame=0.012,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="evade",attack=true
    })
    check({
        name="state-151",
        input={active=true,healing=false,hopping=false,target=true,
            frame=0.012,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="evade",attack=true
    })
    check({
        name="state-152",
        input={active=true,healing=false,hopping=false,target=true,
            frame=0.012,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="evade",attack=true
    })
    check({
        name="state-153",
        input={active=true,healing=false,hopping=false,target=true,
            frame=0.05,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="stable",attack=true
    })
    check({
        name="state-154",
        input={active=true,healing=false,hopping=false,target=true,
            frame=0.05,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="stable",attack=true
    })
    check({
        name="state-155",
        input={active=true,healing=false,hopping=false,target=true,
            frame=0.05,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="stable",attack=true
    })
    check({
        name="state-156",
        input={active=true,healing=false,hopping=false,target=true,
            frame=0.05,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="stable",attack=true
    })
    check({
        name="state-157",
        input={active=true,healing=false,hopping=false,target=true,
            frame=0.05,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="evade",attack=true
    })
    check({
        name="state-158",
        input={active=true,healing=false,hopping=false,target=true,
            frame=0.05,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="evade",attack=true
    })
    check({
        name="state-159",
        input={active=true,healing=false,hopping=false,target=true,
            frame=0.05,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="evade",attack=true
    })
    check({
        name="state-160",
        input={active=true,healing=false,hopping=false,target=true,
            frame=0.05,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="evade",attack=true
    })
    check({
        name="state-161",
        input={active=true,healing=false,hopping=true,target=false,
            frame=0.012,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="hop",attack=false
    })
    check({
        name="state-162",
        input={active=true,healing=false,hopping=true,target=false,
            frame=0.012,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="hop",attack=false
    })
    check({
        name="state-163",
        input={active=true,healing=false,hopping=true,target=false,
            frame=0.012,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="hop",attack=false
    })
    check({
        name="state-164",
        input={active=true,healing=false,hopping=true,target=false,
            frame=0.012,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="hop",attack=false
    })
    check({
        name="state-165",
        input={active=true,healing=false,hopping=true,target=false,
            frame=0.012,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="hop",attack=false
    })
    check({
        name="state-166",
        input={active=true,healing=false,hopping=true,target=false,
            frame=0.012,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="hop",attack=false
    })
    check({
        name="state-167",
        input={active=true,healing=false,hopping=true,target=false,
            frame=0.012,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="hop",attack=false
    })
    check({
        name="state-168",
        input={active=true,healing=false,hopping=true,target=false,
            frame=0.012,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="hop",attack=false
    })
    check({
        name="state-169",
        input={active=true,healing=false,hopping=true,target=false,
            frame=0.05,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="hop",attack=false
    })
    check({
        name="state-170",
        input={active=true,healing=false,hopping=true,target=false,
            frame=0.05,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="hop",attack=false
    })
    check({
        name="state-171",
        input={active=true,healing=false,hopping=true,target=false,
            frame=0.05,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="hop",attack=false
    })
    check({
        name="state-172",
        input={active=true,healing=false,hopping=true,target=false,
            frame=0.05,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="hop",attack=false
    })
    check({
        name="state-173",
        input={active=true,healing=false,hopping=true,target=false,
            frame=0.05,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="hop",attack=false
    })
    check({
        name="state-174",
        input={active=true,healing=false,hopping=true,target=false,
            frame=0.05,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="hop",attack=false
    })
    check({
        name="state-175",
        input={active=true,healing=false,hopping=true,target=false,
            frame=0.05,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="hop",attack=false
    })
    check({
        name="state-176",
        input={active=true,healing=false,hopping=true,target=false,
            frame=0.05,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="hop",attack=false
    })
    check({
        name="state-177",
        input={active=true,healing=false,hopping=true,target=true,
            frame=0.012,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="hop",attack=false
    })
    check({
        name="state-178",
        input={active=true,healing=false,hopping=true,target=true,
            frame=0.012,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="hop",attack=false
    })
    check({
        name="state-179",
        input={active=true,healing=false,hopping=true,target=true,
            frame=0.012,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="hop",attack=false
    })
    check({
        name="state-180",
        input={active=true,healing=false,hopping=true,target=true,
            frame=0.012,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="hop",attack=false
    })
    check({
        name="state-181",
        input={active=true,healing=false,hopping=true,target=true,
            frame=0.012,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="hop",attack=false
    })
    check({
        name="state-182",
        input={active=true,healing=false,hopping=true,target=true,
            frame=0.012,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="hop",attack=false
    })
    check({
        name="state-183",
        input={active=true,healing=false,hopping=true,target=true,
            frame=0.012,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="hop",attack=false
    })
    check({
        name="state-184",
        input={active=true,healing=false,hopping=true,target=true,
            frame=0.012,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="hop",attack=false
    })
    check({
        name="state-185",
        input={active=true,healing=false,hopping=true,target=true,
            frame=0.05,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="hop",attack=false
    })
    check({
        name="state-186",
        input={active=true,healing=false,hopping=true,target=true,
            frame=0.05,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="hop",attack=false
    })
    check({
        name="state-187",
        input={active=true,healing=false,hopping=true,target=true,
            frame=0.05,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="hop",attack=false
    })
    check({
        name="state-188",
        input={active=true,healing=false,hopping=true,target=true,
            frame=0.05,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="hop",attack=false
    })
    check({
        name="state-189",
        input={active=true,healing=false,hopping=true,target=true,
            frame=0.05,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="hop",attack=false
    })
    check({
        name="state-190",
        input={active=true,healing=false,hopping=true,target=true,
            frame=0.05,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="hop",attack=false
    })
    check({
        name="state-191",
        input={active=true,healing=false,hopping=true,target=true,
            frame=0.05,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="hop",attack=false
    })
    check({
        name="state-192",
        input={active=true,healing=false,hopping=true,target=true,
            frame=0.05,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="hop",attack=false
    })
    check({
        name="state-193",
        input={active=true,healing=true,hopping=false,target=false,
            frame=0.012,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-194",
        input={active=true,healing=true,hopping=false,target=false,
            frame=0.012,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-195",
        input={active=true,healing=true,hopping=false,target=false,
            frame=0.012,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-196",
        input={active=true,healing=true,hopping=false,target=false,
            frame=0.012,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-197",
        input={active=true,healing=true,hopping=false,target=false,
            frame=0.012,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-198",
        input={active=true,healing=true,hopping=false,target=false,
            frame=0.012,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-199",
        input={active=true,healing=true,hopping=false,target=false,
            frame=0.012,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-200",
        input={active=true,healing=true,hopping=false,target=false,
            frame=0.012,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-201",
        input={active=true,healing=true,hopping=false,target=false,
            frame=0.05,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-202",
        input={active=true,healing=true,hopping=false,target=false,
            frame=0.05,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-203",
        input={active=true,healing=true,hopping=false,target=false,
            frame=0.05,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-204",
        input={active=true,healing=true,hopping=false,target=false,
            frame=0.05,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-205",
        input={active=true,healing=true,hopping=false,target=false,
            frame=0.05,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-206",
        input={active=true,healing=true,hopping=false,target=false,
            frame=0.05,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-207",
        input={active=true,healing=true,hopping=false,target=false,
            frame=0.05,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-208",
        input={active=true,healing=true,hopping=false,target=false,
            frame=0.05,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-209",
        input={active=true,healing=true,hopping=false,target=true,
            frame=0.012,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-210",
        input={active=true,healing=true,hopping=false,target=true,
            frame=0.012,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-211",
        input={active=true,healing=true,hopping=false,target=true,
            frame=0.012,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-212",
        input={active=true,healing=true,hopping=false,target=true,
            frame=0.012,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-213",
        input={active=true,healing=true,hopping=false,target=true,
            frame=0.012,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-214",
        input={active=true,healing=true,hopping=false,target=true,
            frame=0.012,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-215",
        input={active=true,healing=true,hopping=false,target=true,
            frame=0.012,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-216",
        input={active=true,healing=true,hopping=false,target=true,
            frame=0.012,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-217",
        input={active=true,healing=true,hopping=false,target=true,
            frame=0.05,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-218",
        input={active=true,healing=true,hopping=false,target=true,
            frame=0.05,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-219",
        input={active=true,healing=true,hopping=false,target=true,
            frame=0.05,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-220",
        input={active=true,healing=true,hopping=false,target=true,
            frame=0.05,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-221",
        input={active=true,healing=true,hopping=false,target=true,
            frame=0.05,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-222",
        input={active=true,healing=true,hopping=false,target=true,
            frame=0.05,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-223",
        input={active=true,healing=true,hopping=false,target=true,
            frame=0.05,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-224",
        input={active=true,healing=true,hopping=false,target=true,
            frame=0.05,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-225",
        input={active=true,healing=true,hopping=true,target=false,
            frame=0.012,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-226",
        input={active=true,healing=true,hopping=true,target=false,
            frame=0.012,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-227",
        input={active=true,healing=true,hopping=true,target=false,
            frame=0.012,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-228",
        input={active=true,healing=true,hopping=true,target=false,
            frame=0.012,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-229",
        input={active=true,healing=true,hopping=true,target=false,
            frame=0.012,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-230",
        input={active=true,healing=true,hopping=true,target=false,
            frame=0.012,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-231",
        input={active=true,healing=true,hopping=true,target=false,
            frame=0.012,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-232",
        input={active=true,healing=true,hopping=true,target=false,
            frame=0.012,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-233",
        input={active=true,healing=true,hopping=true,target=false,
            frame=0.05,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-234",
        input={active=true,healing=true,hopping=true,target=false,
            frame=0.05,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-235",
        input={active=true,healing=true,hopping=true,target=false,
            frame=0.05,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-236",
        input={active=true,healing=true,hopping=true,target=false,
            frame=0.05,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-237",
        input={active=true,healing=true,hopping=true,target=false,
            frame=0.05,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-238",
        input={active=true,healing=true,hopping=true,target=false,
            frame=0.05,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-239",
        input={active=true,healing=true,hopping=true,target=false,
            frame=0.05,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-240",
        input={active=true,healing=true,hopping=true,target=false,
            frame=0.05,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-241",
        input={active=true,healing=true,hopping=true,target=true,
            frame=0.012,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-242",
        input={active=true,healing=true,hopping=true,target=true,
            frame=0.012,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-243",
        input={active=true,healing=true,hopping=true,target=true,
            frame=0.012,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-244",
        input={active=true,healing=true,hopping=true,target=true,
            frame=0.012,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-245",
        input={active=true,healing=true,hopping=true,target=true,
            frame=0.012,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-246",
        input={active=true,healing=true,hopping=true,target=true,
            frame=0.012,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-247",
        input={active=true,healing=true,hopping=true,target=true,
            frame=0.012,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-248",
        input={active=true,healing=true,hopping=true,target=true,
            frame=0.012,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-249",
        input={active=true,healing=true,hopping=true,target=true,
            frame=0.05,threat=0.15,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-250",
        input={active=true,healing=true,hopping=true,target=true,
            frame=0.05,threat=0.15,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-251",
        input={active=true,healing=true,hopping=true,target=true,
            frame=0.05,threat=0.15,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-252",
        input={active=true,healing=true,hopping=true,target=true,
            frame=0.05,threat=0.15,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-253",
        input={active=true,healing=true,hopping=true,target=true,
            frame=0.05,threat=0.85,distance=15,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-254",
        input={active=true,healing=true,hopping=true,target=true,
            frame=0.05,threat=0.85,distance=15,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="state-255",
        input={active=true,healing=true,hopping=true,target=true,
            frame=0.05,threat=0.85,distance=70,errorRate=0,
            equipRate=6,progress=0,innovation=20},
        expected="recover",attack=false
    })
    check({
        name="state-256",
        input={active=true,healing=true,hopping=true,target=true,
            frame=0.05,threat=0.85,distance=70,errorRate=2,
            equipRate=1,progress=100,innovation=180},
        expected="recover",attack=false
    })
    check({
        name="normal",
        input={active=true,healing=false,hopping=false,target=true,
            frame=0.016,threat=0.2,distance=20,errorRate=0,
            equipRate=1,progress=20,innovation=0},
        expected="engage",attack=true
    })
    check({
        name="threat-edge",
        input={active=true,healing=false,hopping=false,target=true,
            frame=0.016,threat=0.72,distance=20,errorRate=0,
            equipRate=1,progress=20,innovation=0},
        expected="evade",attack=true
    })
    check({
        name="frame-edge",
        input={active=true,healing=false,hopping=false,target=true,
            frame=0.045,threat=0.2,distance=20,errorRate=0,
            equipRate=1,progress=20,innovation=0},
        expected="stable",attack=true
    })
    check({
        name="distance-edge",
        input={active=true,healing=false,hopping=false,target=true,
            frame=0.016,threat=0.2,distance=35,errorRate=0,
            equipRate=1,progress=20,innovation=0},
        expected="engage",attack=true
    })
    check({
        name="distance-over",
        input={active=true,healing=false,hopping=false,target=true,
            frame=0.016,threat=0.2,distance=35.1,errorRate=0,
            equipRate=1,progress=20,innovation=0},
        expected="approach",attack=true
    })
    check({
        name="error-edge",
        input={active=true,healing=false,hopping=false,target=true,
            frame=0.016,threat=0.2,distance=20,errorRate=1.5,
            equipRate=1,progress=20,innovation=0},
        expected="stable",attack=true
    })
    check({
        name="weave-edge",
        input={active=true,healing=false,hopping=false,target=true,
            frame=0.016,threat=0.2,distance=20,errorRate=0,
            equipRate=4,progress=0,innovation=0},
        expected="engage",attack=true
    })
    check({
        name="weave-over",
        input={active=true,healing=false,hopping=false,target=true,
            frame=0.016,threat=0.2,distance=20,errorRate=0,
            equipRate=4.1,progress=0,innovation=0},
        expected="weave",attack=true
    })
    return passed,total,first
end

local function start(...)
-- Keep helper functions in a private table to reduce local-register pressure.
local Helpers={}
local AI=Adaptive.new()
-- V11.0 Fluid: controlled pre-hop ascent, with combat checks and cancellation.
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
if PG:FindFirstChild("AutoBountyV110Fluid") then
    if launchMode~="open" then return end
    PG.AutoBountyV110Fluid:Destroy()
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
    phase="IDLE",phaseSince=0,healBlend=0,healVelocity=Vector3.zero,
    lastRadius=15,turnGoal=0,turnVelocity=0,angleInitialized=false,
    lastEnemyVelocity=Vector3.zero,enemyAcceleration=Vector3.zero,
    ownAcceleration=Vector3.zero,lastOwnVelocity=nil,forecastRisk=0,forecastTime=0,
    forecastDistance=0,forecastAt=0,forecastSide=1,forecastKind="none",
    sideScore=0,lastSideChange=0,dualFrames=0
}
local AimControl={
    lastPixelAt=0,lastPositionAt=0,prevRaw=Vector3.zero,angularError=0,
    samples={},confidence=0,observed=Vector3.zero,lastObserved=nil,
    lastObservedTime=0,innovation=0,frameInterval=1/60,source="root",
    lastOrigin=nil,lastLocalPosition=nil,originSpeed=0,localSpeed=0,
    direct=false,actualError=0,lastRender=0,renderGap=0,peakGap=0,
    pointer=nil,pointerBusy=false,pointerSerial=0,pointerEpoch=0,mouseErrors=0,
    lastOriginAt=0,fastUntil=0,dispatchMs=0,lateFrames=0,
    forecastRoot=nil,forecastPosition=nil,forecastVelocity=nil,forecastAt=0,
    forecastError=0,forecastConfidence=0,forecastTurnUntil=0,forecastLead=0,
    fastRoot=nil,fastPosition=nil,fastAt=0,fastVelocity=Vector3.zero,
    fastConfidence=0,fastSampleInterval=1/60,fastTarget=false,
    angularSpeed=0,lockUntil=0,worldPointAt=0,worldGeneration=nil,
    pointerAge=0,reprojected=0,simultaneousFrames=0
}
local Water={
    enabled=true,part=nil,level=nil,nextProbe=0,character=nil,lastHit=0,
    params=nil,land=false,status="Attesa",nextVoxel=0,voxelLevel=nil,voxelPos=nil,
    planes={},planeSet={},nextDiscover=0,discovered=false,source="none",
    lastSafe=nil,lastProbePos=nil,stableLevel=nil,lastLand=0,corrections=0,
    nextStatus=0,safeY=nil,clearance=nil,preempt=false,nextAhead=0,aheadLevel=nil,aheadSource=nil,
    discovering=false,probeBusy=false,probeEpoch=0,lastProbeCost=0
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
local HopFlight={active=false,goal=nil,character=nil,serial=0,health=nil,height=120,speed=65}
local FailedServers={}
local JoinedAt=os.clock()
local ScriptURL="https://raw.githubusercontent.com/LuigiMuscettola/LuigiMuscettola/main/RobloxScripts/AutoBounty_V11.0_Fluid.lua"
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
    lastTargetPosition=nil,nextTelemetry=0,stalled=false,
    comboCursor=0,comboCount=0,lastActionAt=0,
    lastWeapon=nil,weaponSince=0
}
local Tuning={
    equipTimeout=0.25,guiTimeout=0.09,skillHold=0.045,
    recovery=0.020,weaponRetry=0.16,unknownRetry=0.28,
    minWeaponDwell=0.12,skillCacheTTL=0.20,
    aimHz=144,dodgeThreshold=0.24,threatHorizon=0.070,
    minProgress=0.25,noDamageTimeout=90,
    attackTimeout=95,waterMargin=3.0,waterAvoidMargin=10.0,
    waterRouteHorizon=0.28,waterRouteMax=110
}
local Options={
    profile="Rapid",heal=true,healLow=4000,healHigh=11000,healing=false,
    smartTarget=true,healAltitude=2000,healGoal=nil,healCharacter=nil,
    compact=false,healResumeAt=0,
    autoM1=true,m1Interval=0,m1Mode="Auto",adaptive=true,
    healStarted=0,healTarget=nil,healCount=0,skipUnknown=false,
    allowed={Melee=true,["Blox Fruit"]=true,Sword=true,Gun=true},
    skills={Melee={Z=true,X=true,C=true,V=true,F=true},
        ["Blox Fruit"]={Z=true,X=true,C=true,V=false,F=true},
        Sword={Z=true,X=true,C=true,V=true,F=true},
        Gun={Z=true,X=true,C=true,V=true,F=true}},
    profileData={
        Rapid={hold=0.045,recovery=0.020,speed=250,dodge=400,orbit=2.75,jerk=1.0,blend=10},
        Balanced={hold=0.070,recovery=0.045,speed=210,dodge=330,orbit=2.45,jerk=0.82,blend=8},
        Precision={hold=0.085,recovery=0.060,speed=180,dodge=290,orbit=2.05,jerk=0.68,blend=7}
    },
    stats={started=os.clock(),skipped=0,targets=0,damageObserved=0},
    file="AutoBountyFluidOptionsV93.json",
    widgets={}
}
function Options.load()
    if type(readfile)~="function" then return end
    local ok,data=pcall(function()
        return HttpService:JSONDecode(readfile(Options.file))
    end)
    if not ok or type(data)~="table" then return end
    if Options.profileData[data.profile] then Options.profile=data.profile end
    -- Mandatory recovery and smart selection are always enabled.
    if type(data.compact)=="boolean" then Options.compact=data.compact end
    if type(data.autoM1)=="boolean" then Options.autoM1=data.autoM1 end
    if type(data.adaptive)=="boolean" then Options.adaptive=data.adaptive end
    if data.m1Mode=="Auto" or data.m1Mode=="Tool" or data.m1Mode=="Mouse" then Options.m1Mode=data.m1Mode end
    if type(data.skipUnknown)=="boolean" then Options.skipUnknown=data.skipUnknown end
    if type(data.allowed)=="table" then
        for name in pairs(Options.allowed) do
            if type(data.allowed[name])=="boolean" then Options.allowed[name]=data.allowed[name] end
        end
    end
    if type(data.skills)=="table" then
        for name,keys in pairs(Options.skills) do
            if type(data.skills[name])=="table" then
                for key in pairs(keys) do
                    if type(data.skills[name][key])=="boolean" then keys[key]=data.skills[name][key] end
                end
            end
        end
    end
    Options.skills["Blox Fruit"].V=false
end
function Options.save()
    if type(writefile)~="function" then return end
    pcall(function()
        writefile(Options.file,HttpService:JSONEncode({
            profile=Options.profile,heal=Options.heal,skipUnknown=Options.skipUnknown,compact=Options.compact,autoM1=Options.autoM1,m1Mode=Options.m1Mode,adaptive=Options.adaptive,
            allowed=Options.allowed,skills=Options.skills
        }))
    end)
end
function Options.apply()
    local p=Options.profileData[Options.profile]
    Tuning.skillHold,Tuning.recovery=p.hold,p.recovery
    Speed,DodgeSpeed=p.speed,p.dodge
    Tuning.orbitRate,Tuning.jerkScale,Tuning.orbitBlendRate=p.orbit,p.jerk,p.blend
end
function Options.phase(value)
    if Motion.phase~=value then Motion.phase=value; Motion.phaseSince=os.clock() end
end
Options.load()
Options.apply()
AI.enabled=Options.adaptive
function Helpers.resetScheduler()
    Scheduler.target=nil
    Scheduler.targetHealth=nil
    Scheduler.lastHit=0
    Scheduler.lastSkill=0
    Scheduler.lastEquip=0
    Scheduler.emptySince=0
    Scheduler.nextAction=0
    Scheduler.lastTargetPosition=nil
    Scheduler.stalled=false
    Scheduler.comboCursor=0
    Scheduler.lastActionAt=0
    Scheduler.lastWeapon=nil
    Scheduler.weaponSince=0
end
Runtime.stop=function() Active=false; Closed=true; HopSerial=HopSerial+1 end
Runtime.stage="Pulizia versioni precedenti"
for _,n in ipairs({
    "BloxAimTP","AutoBountyV6","AutoBountyV7",
    "AutoBountyV71","AutoBountyV72","AutoBountyV73",
    "PvPDiagnostic","AutoBountyV8","AutoBountyV74","AutoBountyV75","AutoBountyV76","AutoBountyV77","AutoBountyV76Fluid","AutoBountyV77Fluid","AutoBountyV78Fluid","AutoBountyV79Fluid","AutoBountyV80Fluid","AutoBountyV81Fluid","AutoBountyV82Fluid","AutoBountyV83Fluid","AutoBountyV84Fluid","AutoBountyV85Fluid","AutoBountyV86Fluid","AutoBountyV87Fluid","AutoBountyV88Fluid","AutoBountyV89Fluid","AutoBountyV90Fluid","AutoBountyV91Fluid","AutoBountyV92Fluid","AutoBountyV93Fluid","AutoBountyV94Fluid","AutoBountyV95Fluid","AutoBountyV96Fluid","AutoBountyV97Fluid","AutoBountyV98Fluid","AutoBountyV99Fluid","AutoBountyV100Fluid","AutoBountyV101Fluid","AutoBountyV102Fluid","AutoBountyV103Fluid","AutoBountyV104Fluid","AutoBountyV105Fluid","AutoBountyV106Fluid","AutoBountyV107Fluid","AutoBountyV108Fluid","AutoBountyV109Fluid","AutoBountyV110Fluid"
}) do
    local old=PG:FindFirstChild(n)
    if old then pcall(function() old:Destroy() end) end end
pcall(function() RS:UnbindFromRenderStep("AutoBountyAim") end)
Runtime.stage="Creazione interfaccia"
local Gui=Instance.new("ScreenGui",PG); Runtime.gui=Gui; Gui.Name="AutoBountyV110Fluid"; Gui.ResetOnSpawn=false; Gui.DisplayOrder=999; local Main=Instance.new("Frame",Gui)
Main.Size=UDim2.fromOffset(270,484); Main.Position=UDim2.new(0.03,0,0.15,0); Main.BackgroundColor3=Color3.fromRGB(20,22,30); Main.Active=true; Main.Draggable=true
Instance.new("UICorner",Main)
local function label(txt,y,h)
    local l=Instance.new("TextLabel",Main); l.Size=UDim2.new(1,-12,0,h); l.Position=UDim2.fromOffset(6,y); l.BackgroundTransparency=1; l.TextColor3=Color3.new(1,1,1)
    l.Font=Enum.Font.GothamBold; l.TextSize=13; l.TextWrapped=true; l.Text=txt
    return l end
label("AUTO BOUNTY V11.0 FLUID",5,25)
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
CloseButton.Position=UDim2.fromOffset(10,450)
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
do
    local panel=Instance.new("Frame",Gui)
    panel.Name="CombatSettings"
    panel.Size=UDim2.fromOffset(282,518)
    panel.AnchorPoint=Vector2.new(0.5,0.5)
    panel.Position=UDim2.fromScale(0.5,0.5)
    panel.BackgroundColor3=Color3.fromRGB(25,29,39)
    panel.Visible=false
    panel.ZIndex=5
    Instance.new("UICorner",panel)
    local function control(parent,title,x,y,w,h,callback)
        local b=Instance.new("TextButton",parent)
        b.Size=UDim2.fromOffset(w,h)
        b.Position=UDim2.fromOffset(x,y)
        b.BackgroundColor3=Color3.fromRGB(46,56,77)
        b.TextColor3=Color3.new(1,1,1)
        b.Font=Enum.Font.GothamBold
        b.TextSize=12
        b.Text=title
        b.ZIndex=parent==panel and 6 or 2
        Instance.new("UICorner",b)
        Runtime.connect(b.Activated,function() callback(b) end)
        return b
    end
    control(Main,"IMPOSTAZIONI",10,418,120,26,function() panel.Visible=not panel.Visible end)
    control(Main,"SALTA TARGET",140,418,120,26,function()
        Options.skipRequested=true
    end)
    control(panel,"CHIUDI",174,8,98,26,function() panel.Visible=false end)
    Options.widgets.profile=control(panel,"Profilo: "..Options.profile,10,8,154,26,function(b)
        local list={"Rapid","Balanced","Precision"}
        local i=table.find(list,Options.profile) or 1
        Options.profile=list[i%#list+1]
        Options.apply()
        Options.save()
        b.Text="Profilo: "..Options.profile
    end)
    control(panel,"SMART ON | HP 4000 / 11000",10,44,262,26,function() end).AutoButtonColor=false
    control(panel,"Solo PvP confermato: "..(Options.skipUnknown and "ON" or "OFF"),10,76,262,26,function(b)
        Options.skipUnknown=not Options.skipUnknown
        table.clear(Cache)
        b.Text="Solo PvP confermato: "..(Options.skipUnknown and "ON" or "OFF")
        Options.save()
    end)
    local names={"Melee","Blox Fruit","Sword","Gun"}
    for i,name in ipairs(names) do
        local y=112+(i-1)*51
        control(panel,name..": "..(Options.allowed[name] and "ON" or "OFF"),10,y,104,45,function(b)
            Options.allowed[name]=not Options.allowed[name]
            b.Text=name..": "..(Options.allowed[name] and "ON" or "OFF")
            Options.save()
        end)
        for j,key in ipairs(Keys) do
            local function keyText()
                return key..(Options.skills[name][key] and "+" or "-")
            end
            control(panel,keyText(),118+(j-1)*31,y,29,45,function(b)
                if name=="Blox Fruit" and key=="V" then return end
                Options.skills[name][key]=not Options.skills[name][key]
                b.Text=keyText()
                Options.save()
            end)
        end
    end
    Options.widgets.stats=control(panel,"Sessione",10,320,262,26,function() end)
    Options.widgets.stats.AutoButtonColor=false
    local uiScale=Instance.new("UIScale",Main)
    local settingsScale=Instance.new("UIScale",panel)
    local function fit()
        local cam=workspace.CurrentCamera
        local size=cam and cam.ViewportSize or Vector2.new(800,600)
        local base=math.clamp((size.Y-32)/484,0.48,1)
        uiScale.Scale=base*(Options.compact and 0.80 or 1)
        settingsScale.Scale=math.clamp(math.min((size.Y-20)/518,(size.X-20)/282),0.50,1)
        Main.Position=UDim2.fromOffset(10,math.max(8,(size.Y-484*uiScale.Scale)/2))
    end
    control(panel,"Interfaccia compatta: "..(Options.compact and "ON" or "OFF"),10,354,262,26,function(b)
        Options.compact=not Options.compact
        b.Text="Interfaccia compatta: "..(Options.compact and "ON" or "OFF")
        fit()
        Options.save()
    end)
    Options.widgets.m1=control(panel,"AUTO M1: "..(Options.autoM1 and "ON" or "OFF"),10,386,262,26,function(b)
        Options.autoM1=not Options.autoM1
        b.Text="AUTO M1: "..(Options.autoM1 and "ON" or "OFF")
        Options.save()
    end)
    Options.widgets.m1Mode=control(panel,"M1 INPUT: "..Options.m1Mode,10,418,262,26,function(b)
        local modes={"Auto","Tool","Mouse"}
        local i=table.find(modes,Options.m1Mode) or 1
        Options.m1Mode=modes[i%#modes+1]
        b.Text="M1 INPUT: "..Options.m1Mode
        Options.save()
    end)
    Options.widgets.ai=control(panel,"ADAPTIVE: "..(AI.enabled and "ON" or "OFF"),10,450,262,26,function(b)
        AI.enabled=not AI.enabled
        Options.adaptive=AI.enabled
        b.Text="ADAPTIVE: "..(AI.enabled and "ON" or "OFF")
        Options.save()
    end)
    Options.widgets.aiTests=control(panel,"SELF TEST",10,482,262,26,function(b)
        local passed,total,first=Adaptive.runTests()
        AI.testsPassed,AI.testsTotal=passed,total
        AI.healthy=passed==total
        b.Text=string.format("TEST %d/%d %s",passed,total,first or "OK")
    end)
    fit()
    if workspace.CurrentCamera then
        Runtime.connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),fit)
    end
end
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
function Helpers.removeWaterSupport()
    if Water.part then Water.part:Destroy(); Water.part=nil end
    Water.level,Water.character,Water.params=nil,nil,nil
    Water.nextProbe,Water.lastHit,Water.nextVoxel=0,0,0
    Water.voxelLevel,Water.voxelPos=nil,nil
    Water.land=false
    Water.status="Attesa"
    Water.lastSafe,Water.lastProbePos,Water.stableLevel=nil,nil,nil
    Water.source="none"
    Water.probeEpoch=Water.probeEpoch+1
    Water.safeY,Water.clearance=nil,nil
    Water.preempt=false
    Water.nextAhead=0
    Water.aheadLevel,Water.aheadSource=nil,nil
end
function Helpers.isWaterPlane(part)
    if not part or not part:IsA("BasePart") or part==Water.part then return false end
    if part:IsA("Terrain") then return false end
    local name=normalize(part.Name)
    local explicit=name=="water" or name=="sea" or name=="ocean" or name=="waterplane"
        or name=="seawater" or name=="oceansurface" or name=="seasurface"
        or name=="waterlevel" or name=="oceanwater"
    local size=part.Size
    return explicit and size.X>=20 and size.Z>=20 and math.abs(part.CFrame.UpVector.Y)>0.90
end
function Helpers.waterHit(hit)
    return hit and (hit.Material==Enum.Material.Water or Helpers.isWaterPlane(hit.Instance))
end
function Helpers.addWaterPlane(part)
    if Helpers.isWaterPlane(part) and not Water.planeSet[part] then
        Water.planeSet[part]=true
        table.insert(Water.planes,part)
    end
end
function Helpers.discoverWaterPlanes()
    local now=os.clock()
    if Water.discovering or (Water.discovered and now<Water.nextDiscover) then return end
    Water.discovering=true
    Water.discovered=true
    Water.nextDiscover=now+20
    -- Discovery yields in batches and never runs inside the physics callback.
    task.spawn(function()
        local ok,err=pcall(function()
            local kept={}
            for _,part in ipairs(Water.planes) do
                if part.Parent and Helpers.isWaterPlane(part) then
                    table.insert(kept,part)
                else
                    Water.planeSet[part]=nil
                end
            end
            Water.planes=kept
            local checked=0
            for _,child in ipairs(workspace:GetChildren()) do
                if Closed then break end
                Helpers.addWaterPlane(child)
                local n=normalize(child.Name)
                if n=="map" or n=="world" or n=="sea" or n=="ocean" or n=="water" then
                    for _,part in ipairs(child:GetDescendants()) do
                        if Closed then break end
                        Helpers.addWaterPlane(part)
                        checked=checked+1
                        if checked%160==0 then task.wait() end
                    end
                end
            end
        end)
        Water.discovering=false
        if not ok then Runtime.report("Ricerca acqua",err) end
    end)
end
local waterPlaneAdded=Runtime.connect(workspace.DescendantAdded,function(part)
    if part:IsA("BasePart") then Helpers.addWaterPlane(part) end
end)
function Helpers.planeSurface(position)
    Helpers.discoverWaterPlanes()
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
function Helpers.terrainSurface(position)
    local now=os.clock()
    if now<Water.nextVoxel and Water.voxelPos and (position-Water.voxelPos).Magnitude<5 then
        return Water.voxelLevel
    end
    Water.nextVoxel=now+0.16
    Water.voxelPos=position
    local started=os.clock()
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
    Water.lastProbeCost=(os.clock()-started)*1000
    Water.voxelLevel=ok and result or nil
    return Water.voxelLevel
end
function Helpers.probeWater(r,h,position)
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
    position=position or r.Position
    local cast=workspace:Raycast(position+Vector3.new(0,32,0),Vector3.new(0,-88,0),Water.params)
    if Helpers.waterHit(cast) then return cast.Position.Y,false,"raycast" end
    -- A solid floor underneath the feet takes precedence over an ocean plane.
    local feet=position.Y-math.max(2.5,h.HipHeight+r.Size.Y/2)
    if cast and cast.Instance and cast.Instance:IsA("BasePart") and cast.Instance.CanCollide
        and cast.Position.Y>=feet-1.4 and cast.Position.Y<=position.Y+1 then
        return nil,true,"land"
    end
    local plane=Helpers.planeSurface(position)
    if plane then
        if cast and cast.Position.Y>plane+0.8 and cast.Position.Y<position.Y+1 then
            return nil,true,"land"
        end
        return plane,false,"map plane"
    end
    local terrain=Helpers.terrainSurface(position)
    if terrain then return terrain,false,"terrain voxels" end
    return nil,false,"unknown"
end
function Helpers.createWaterSupport(r,floor)
    if not Water.part or not Water.part.Parent then
        local part=Instance.new("Part")
        part.Name="AutoBountyWaterSupport"
        part.Anchored=true
        part.CanCollide=true
        part.CanTouch=false
        part.CanQuery=false
        part.Transparency=1
        part.Size=Vector3.new(18,0.8,18)
        part.CFrame=CFrame.new(r.Position.X,floor-0.4,r.Position.Z)
        part.Parent=workspace
        Water.part=part
    end
    Water.part.CFrame=CFrame.new(r.Position.X,floor-0.4,r.Position.Z)
end
function Helpers.updateWater()
    -- Water walk remains available when automatic PvP is paused.
    if Closed or not Water.enabled or HopBusy then
        if Water.character or Water.part then Helpers.removeWaterSupport() end
        return
    end
    local r,h=root(LP),humanoid(LP)
    if not r or not h or h.SeatPart then
        Helpers.removeWaterSupport()
        return
    end
    if Water.character~=LP.Character then
        Helpers.removeWaterSupport()
        Water.character=LP.Character
    end
    local now=os.clock()
    local v=r.AssemblyLinearVelocity
    local planar=Vector3.new(v.X,0,v.Z)
    -- Anticipate the commanded flight path as well as actual assembly motion.
    local route=planar
    if Active and Velocity and Velocity.Parent then
        local command=Velocity.VectorVelocity
        local commanded=Vector3.new(command.X,0,command.Z)
        if commanded.Magnitude>2 then route=commanded end
    end
    if Active and Target and not Options.healing and route.Magnitude<=2 then
        local targetRoot=root(Target)
        if targetRoot then
            local direction=Vector3.new(targetRoot.Position.X-r.Position.X,0,targetRoot.Position.Z-r.Position.Z)
            if direction.Magnitude>8 then route=direction.Unit*math.min(Speed,direction.Magnitude/0.28) end
        end
    end
    local moved=not Water.lastProbePos or (r.Position-Water.lastProbePos).Magnitude>4
    if now>=Water.nextProbe or (moved and now>=Water.nextProbe-0.010) then
        Water.nextProbe=now+0.025
        Water.lastProbePos=r.Position
        local level,land,source=Helpers.probeWater(r,h)
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
    -- Sample near and far points on the upcoming flight path, including acceleration from rest.
    if now>=Water.nextAhead then
        Water.nextAhead=now+0.035
        Water.aheadLevel,Water.aheadSource=nil,nil
        if route.Magnitude>2 then
            local reach=math.clamp(route.Magnitude*(Active and Tuning.waterRouteHorizon or 0.12),2,Active and Tuning.waterRouteMax or 18)
            local samples=Active and 3 or 1
            for i=1,samples do
                local look=r.Position+route.Unit*(reach*i/samples)
                local level,land,source=Helpers.probeWater(r,h,look)
                if level and not land and (not Water.aheadLevel or level>Water.aheadLevel) then
                    Water.aheadLevel,Water.aheadSource=level,source
                end
            end
        end
    end
    local level=not Water.land and Water.level or nil
    Water.preempt=false
    if Water.aheadLevel and route.Magnitude>2 and (not level or (Active and Water.aheadLevel>level)) then
        level=Water.aheadLevel
        Water.preempt=true
        Water.source=Water.aheadSource
    end
    if not level then
        if Water.part then Water.part:Destroy(); Water.part=nil end
        Water.safeY=nil
        Water.status=Water.land and "Terra" or "Acqua non rilevata"
        return
    end
    -- Derive the root-to-foot distance from the actual rig, including scaled avatars.
    local clearance=math.max(2.5,h.HipHeight+r.Size.Y/2)
    for _,name in ipairs({"LeftFoot","RightFoot","Left Leg","Right Leg"}) do
        local foot=LP.Character:FindFirstChild(name)
        if foot and foot:IsA("BasePart") then
            local extent=math.abs(foot.CFrame.RightVector.Y)*foot.Size.X/2
                +math.abs(foot.CFrame.UpVector.Y)*foot.Size.Y/2
                +math.abs(foot.CFrame.LookVector.Y)*foot.Size.Z/2
            clearance=math.max(clearance,r.Position.Y-foot.Position.Y+extent)
        end
    end
    clearance=math.clamp(clearance+0.35,2.5,10)
    Water.clearance=clearance
    -- Preserve ordinary Water Walk when auto-combat is paused.
    local floor=level+(Active and Tuning.waterAvoidMargin or Tuning.waterMargin)
    local safeY=floor+clearance
    Water.safeY=safeY
    local y=r.Position.Y
    Water.status="Superficie rilevata"
    if y>safeY+16 or (not Active and y<level-32) then
        if Water.part then Water.part:Destroy(); Water.part=nil end
        return
    end
    if Velocity and Velocity.Parent then
        if Water.part then Water.part:Destroy(); Water.part=nil end
        local current=Velocity.VectorVelocity
        if y<safeY+(Active and 2.0 or 1.2) then
            local minimum=math.clamp((safeY-y)*18,0,95)
            Velocity.VectorVelocity=Vector3.new(current.X,math.max(current.Y,minimum),current.Z)
        end
    else
        Helpers.createWaterSupport(r,floor)
    end
    -- Anticipate a falling frame instead of waiting for the next water contact.
    local falling=v.Y<0 and y+v.Y*0.035<safeY
    if y<safeY-0.10 or falling then
        local lift=math.max(0,safeY-y)
        r.CFrame=r.CFrame+Vector3.new(0,lift,0)
        local current=r.AssemblyLinearVelocity
        r.AssemblyLinearVelocity=Vector3.new(current.X,math.max(0,current.Y),current.Z)
        Water.corrections=Water.corrections+1
    end
    Water.lastSafe=r.Position
end
local waterConnection=Runtime.connect(RS.Stepped,function()
    local ok,err=pcall(Helpers.updateWater)
    if not ok then Runtime.report("Acqua",err); Helpers.removeWaterSupport() end
end)
Runtime.connect(WaterToggle.Activated,function()
    Water.enabled=not Water.enabled
    if not Water.enabled then Helpers.removeWaterSupport() end
    WaterToggle.Text=Water.enabled and "WATER WALK: ON" or "WATER WALK: OFF"
    WaterToggle.BackgroundColor3=Water.enabled and Color3.fromRGB(35,110,78) or Color3.fromRGB(110,50,50)
end)
function Helpers.rangeProfile(tool)
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
    return not no and (yes or not Options.skipUnknown),yes and not no end
local function pvp(p)
    if not p or p.Parent~=P then return false end
    local h=humanoid(p)
    if not h or h.Health<=0 or p.Character and p.Character:FindFirstChildOfClass("ForceField") then return false end
    local c=Cache[p]; local now=os.clock()
    if c and c.char==p.Character and now-c.at<ScanInterval then return c.allowed end
    local allowed,yes=classify(p); Cache[p]={allowed=allowed,yes=yes,at=now,char=p.Character}
    return allowed end
function Helpers.numericStat(p,names)
    if not p then return nil end
    local containers={p}
    for _,n in ipairs({"Data","Stats","leaderstats","Status"}) do
        local c=p:FindFirstChild(n)
        if c then table.insert(containers,c) end
    end
    for _,c in ipairs(containers) do
        for _,name in ipairs(names) do
            local value=c:GetAttribute(name)
            if type(value)=="number" and value>=0 and value<1e10 then return value end
            local item=c:FindFirstChild(name)
            if item and (item:IsA("IntValue") or item:IsA("NumberValue")) and item.Value>=0 then return item.Value end
        end
    end
    return nil
end
function Helpers.smartScore(p,ownLevel,ownBounty,ownMax,r,t,yes)
    local h=humanoid(p)
    if not h or h.MaxHealth<=0 then return math.huge end
    local level=Helpers.numericStat(p,{"Level","Lvl","level"})
    local bounty=Helpers.numericStat(p,{"Bounty/Honor","Bounty","Honor","bounty","honor"})
    local gap=ownLevel and level and math.abs(level-ownLevel)/math.max(1,ownLevel) or nil
    local hpRatio=math.clamp(h.Health/math.max(1,h.MaxHealth),0,1)
    local relativeMax=h.MaxHealth/math.max(1,ownMax)
    local delta=t.Position-r.Position
    local score=math.min(delta.Magnitude,3500)*0.035+math.min(math.abs(delta.Y),1000)*0.04
    score=score+(gap and gap*900 or 180)
    if gap and gap>0.22 then score=score+250 end
    score=score+hpRatio*100+math.clamp(relativeMax,0,3)*55
    if ownBounty and ownBounty>0 and bounty then
        score=score+math.clamp(bounty/ownBounty,0,6)*65
    else score=score+65 end
    if not yes then score=score+100000 end
    if t.AssemblyLinearVelocity.Magnitude>150 then score=score+15 end
    if p==Target then score=score-8 end
    return score+Adaptive.targetPenalty(AI,p,os.clock())
end
function Helpers.findTarget()
    local r=root(LP)
    local ownLevel=Helpers.numericStat(LP,{"Level","Lvl","level"})
    local ownBounty=Helpers.numericStat(LP,{"Bounty/Honor","Bounty","Honor","bounty","honor"})
    local ownHumanoid=humanoid(LP)
    local ownMax=ownHumanoid and ownHumanoid.MaxHealth or 11000
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
                        local score=Helpers.smartScore(p,ownLevel,ownBounty,ownMax,r,t,yes)
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
function Helpers.stopMovement()
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
    Motion.ownAcceleration,Motion.lastOwnVelocity=Vector3.zero,nil
    Motion.forecastRisk,Motion.forecastTime,Motion.forecastDistance,Motion.forecastAt=0,0,0,0
    Motion.forecastKind="none"
    Motion.sideScore,Motion.lastSideChange=0,0
    RangeNow,DodgeMaxRadius,CastDistance=14,21,29; RangeTool=nil; RangeRefresh=0
    restore() end
function Helpers.startMovement(r)
    if FlyRoot==r and Velocity and Velocity.Parent and Attachment and Attachment.Parent then return end
    Helpers.stopMovement()
    FlyRoot=r; Attachment=Instance.new("Attachment",r); Attachment.Name="AutoBountyAttachment"; Velocity=Instance.new("LinearVelocity",r); Velocity.Name="AutoBountyVelocity"; Velocity.Attachment0=Attachment; Velocity.RelativeTo=Enum.ActuatorRelativeTo.World
    Velocity.VelocityConstraintMode=Enum.VelocityConstraintMode.Vector; Velocity.ForceLimitsEnabled=false; Velocity.VectorVelocity=r.AssemblyLinearVelocity end
function Helpers.clampVector(v,max)
    if v.X~=v.X or v.Y~=v.Y or v.Z~=v.Z then return Vector3.zero end
    local m=v.Magnitude
    if m>max and m>0 then return v*(max/m) end
    return v
end
function Helpers.smootherstep(x)
    x=math.clamp(x,0,1)
    return x*x*x*(x*(x*6-15)+10)
end
function Helpers.evasionSide(delta,forward,relative,previous)
    local radial=flat(delta)
    local facing=flat(forward)
    if radial.Magnitude<0.01 or facing.Magnitude<0.01 then return previous,0 end
    radial=radial.Unit
    facing=facing.Unit
    local tangent=Vector3.new(-radial.Z,0,radial.X)
    local function score(side)
        local future=flat(delta)+tangent*(side*9)-flat(relative)*0.07
        local along=future:Dot(facing)
        local lateral=(future-facing*along).Magnitude
        local risk=along>0 and math.max(0,10-lateral) or 0
        return lateral-risk-(side==previous and 0 or 2.5)
    end
    local currentScore=score(previous)
    local otherScore=score(-previous)
    if otherScore>currentScore+4 then return -previous,otherScore-currentScore end
    return previous,0
end
local function dodge(now,urgent,delta,forward)
    -- Prefer lateral escape from the projected facing line, with hysteresis.
    if now-Motion.lastSideChange>=0.55 then
        local own=FlyRoot and FlyRoot.AssemblyLinearVelocity or Vector3.zero
        local side,advantage=Helpers.evasionSide(delta,forward,TargetVelocity-own,Direction)
        Motion.sideScore=advantage
        if side~=Direction then
            Direction=side
            Motion.lastSideChange=now
        end
        Motion.forecastSide=Direction
    end
    DodgeStart=now
    DodgeDuration=urgent and 0.57 or 0.54
    DodgeStrength=1
    DodgeUntil=now+DodgeDuration
    NextDodge=DodgeUntil+(urgent and 0.09 or 0.14)
    Motion.evadeCount=Motion.evadeCount+1
    NextChange=NextDodge+0.8
end
-- Exact critically damped spring, independent of the frame rate.
-- Evaluate several possible future relative positions. The result is a
-- movement-risk estimate, not a prediction of undisclosed server hitboxes.
function Helpers.forecastThreat(delta,relative,acceleration,look,horizon)
    local nearest=delta.Magnitude
    local eta=0
    local risk=0
    local kind="none"
    local forward=look.Magnitude>0.01 and look.Unit or Vector3.zero
    local closing=delta.Magnitude>0.01 and relative:Dot(delta.Unit) or 0
    for i=1,7 do
        local t=horizon*i/7
        local projected=delta-relative*t-Helpers.clampVector(acceleration*(0.5*t*t),22)
        local distance=projected.Magnitude
        if distance<nearest then nearest,eta=distance,t end
        local confidence=1-0.48*(t/horizon)
        local approach=math.clamp((closing+acceleration:Dot(delta.Magnitude>0.01 and delta.Unit or Vector3.zero)*t)/40,0,1)
        local proximity=1-smoothstep((distance-7)/25)
        local collisionRisk=proximity*approach*confidence
        if collisionRisk>risk then risk,kind=collisionRisk,"intercept" end
        if forward.Magnitude>0.01 and distance>0.01 then
            local along=projected:Dot(forward)
            local side=(projected-forward*along).Magnitude
            if along>0 and along<65 then
                local cone=1-smoothstep((side-3)/(7+along*0.12))
                local rangeWeight=1-smoothstep((along-15)/55)
                local lineRisk=cone*rangeWeight*confidence*0.76
                if lineRisk>risk then risk,kind=lineRisk,"facing" end
            end
        end
    end
    return math.clamp(risk,0,1),eta,nearest,kind
end
function Helpers.forecastAim(rootPart,position,raw,now)
    if AimControl.forecastRoot~=rootPart then
        AimControl.forecastRoot=rootPart
        AimControl.forecastPosition=position
        AimControl.forecastVelocity=raw
        AimControl.forecastAt=now
        AimControl.forecastError=0
        AimControl.forecastConfidence=0.5
        AimControl.forecastTurnUntil=0
        return
    end
    local elapsed=now-AimControl.forecastAt
    if elapsed<0.012 then return end
    local previous=AimControl.forecastVelocity or raw
    local displacement=position-AimControl.forecastPosition
    local reset=elapsed>0.20 or displacement.Magnitude>math.max(24,elapsed*750)
    if reset then
        AimControl.forecastError=0
        AimControl.forecastConfidence=0.25
        AimControl.forecastTurnUntil=now+0.045
    else
        local predicted=AimControl.forecastPosition+previous*elapsed
        local error=(position-predicted).Magnitude
        AimControl.forecastError=AimControl.forecastError+(error-AimControl.forecastError)*0.35
        local turn=previous.Magnitude>8 and raw.Magnitude>8 and previous.Unit:Dot(raw.Unit)<0.65
        local brake=previous.Magnitude>12 and raw.Magnitude<previous.Magnitude*0.45
        if turn or brake then AimControl.forecastTurnUntil=now+0.07 end
        local quality=1-math.clamp(error/math.max(2,elapsed*120),0,1)
        AimControl.forecastConfidence=AimControl.forecastConfidence+(quality-AimControl.forecastConfidence)*0.25
    end
    AimControl.forecastPosition=position
    AimControl.forecastVelocity=raw
    AimControl.forecastAt=now
end
function Helpers.springStep(value,velocity,goal,frequency,dt)
    local x=value-goal
    local j=velocity+frequency*x
    local decay=math.exp(-frequency*dt)
    return goal+(x+j*dt)*decay,(velocity-frequency*j*dt)*decay
end
function Helpers.updateMovement(dt)
    if HopFlight.active and Active and not Closed and HopBusy and AutoHop and HopFlight.serial==HopSerial then
        local r=root(LP)
        if r and LP.Character==HopFlight.character then
            Helpers.startMovement(r)
            local errorY=HopFlight.goal-r.Position.Y
            local speed=math.clamp(errorY*3,-18,HopFlight.speed)
            Velocity.VectorVelocity=Velocity.VectorVelocity:Lerp(Vector3.new(0,speed,0),alpha(dt,9))
            Options.phase("SALITA SERVER")
            return
        end
    end
    if Closed or not Active or HopBusy or (not Target and not Options.healing) then
        if Velocity then Helpers.stopMovement() end
        return
    end
    dt=math.clamp(dt,0,0.08)
    if dt<=0 then return end
    local r,t,h=root(LP),root(Target),humanoid(LP)
    if Options.healing and r and h then
        Options.phase("RECUPERO IN QUOTA")
        if Options.healCharacter~=LP.Character then return end
        Helpers.startMovement(r)
        local goal=Options.healGoal or r.Position.Y
        if Water.safeY then goal=math.max(goal,Water.safeY+12) end
        local errorY=goal-r.Position.Y
        local desired=Vector3.new(0,math.clamp(errorY*3,-25,180),0)
        Velocity.VectorVelocity=Velocity.VectorVelocity:Lerp(desired,alpha(dt,13))
        return
    end
    if not r or not t or not h or not pvp(Target) then
        if Velocity then Helpers.stopMovement() end
        return
    end
    Helpers.startMovement(r)
    local now=os.clock()
    Motion.healBlend=Motion.healBlend*(1-alpha(dt,8))
    local delta=r.Position-t.Position
    local distance=delta.Magnitude
    local horizontal=flat(delta)
    local raw=Helpers.clampVector(t.AssemblyLinearVelocity,450)
    if now>=RangeRefresh then
        RangeRefresh=now+0.045
        RangeTool=LP.Character and LP.Character:FindFirstChildOfClass("Tool")
    end
    local profile=Helpers.rangeProfile(RangeTool)
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
        Motion.ownAcceleration,Motion.lastOwnVelocity=Vector3.zero,r.AssemblyLinearVelocity
        Motion.forecastRisk,Motion.forecastTime,Motion.forecastDistance,Motion.forecastAt=0,0,0,0
        Motion.forecastKind="none"
        Motion.sideScore,Motion.lastSideChange=0,now
        NextChange=now+1.8
        LastHealth=h.Health
        InOrbit=false
        OrbitRadius=RangeNow
        RadiusNow,HeightNow=RangeNow,3.5
        AngularRate,OrbitBlend,EvadeBlend=0,0,0
        Motion.angleInitialized=true
        Motion.turnGoal,Motion.turnVelocity=0,0
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
        TargetVelocity=TargetVelocity:Lerp(raw,alpha(dt,fastChange and 55 or (raw.Magnitude>110 and 35 or 20)))
    end
    TargetPosition=t.Position
    if LastHealth and h.Health<LastHealth-0.05 then DamageUntil=now+0.5 end
    LastHealth=h.Health
    local damaged=now<DamageUntil
    local ownVelocity=r.AssemblyLinearVelocity
    local ownAcceleration=Helpers.clampVector((ownVelocity-(Motion.lastOwnVelocity or ownVelocity))/math.max(dt,0.005),300)
    Motion.ownAcceleration=Motion.ownAcceleration:Lerp(ownAcceleration,alpha(dt,12))
    Motion.lastOwnVelocity=ownVelocity
    local enemyAcceleration=Helpers.clampVector((raw-Motion.lastEnemyVelocity)/math.max(dt,0.005),320)
    Motion.enemyAcceleration=Motion.enemyAcceleration:Lerp(enemyAcceleration,alpha(dt,18))
    Motion.lastEnemyVelocity=raw
    local relativeVelocity=TargetVelocity-ownVelocity
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
    if now>=Motion.forecastAt then
        Motion.forecastAt=now+0.010
        Motion.forecastRisk,Motion.forecastTime,Motion.forecastDistance,Motion.forecastKind=Helpers.forecastThreat(
            delta,relativeVelocity,Motion.enemyAcceleration-Motion.ownAcceleration,t.CFrame.LookVector,Tuning.threatHorizon)
    end
    local threatScore=math.max(proximity*facing,intercept,turningThreat,Motion.forecastRisk,damaged and 1 or 0)
    if facing>0.82 and closest<15 and closing>8 then threatScore=math.max(threatScore,0.83) end
    Motion.threat=Motion.threat+(threatScore-Motion.threat)*alpha(dt,threatScore>Motion.threat and 60 or 18)
    ThreatTime=Motion.threat>Tuning.dodgeThreshold and math.min(0.25,ThreatTime+dt) or math.max(0,ThreatTime-dt*2)
    local imminent=Motion.forecastRisk>=0.52 and Motion.forecastTime>0 and Motion.forecastTime<=Tuning.threatHorizon and Motion.forecastDistance<14
    if now>=NextDodge and distance<72 and (damaged or imminent or threatScore>0.70 or ThreatTime>=0.016) then
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
        if phase<0.16 then envelope=Helpers.smootherstep(phase/0.16)
        elseif phase<0.48 then envelope=1
        else envelope=1-Helpers.smootherstep((phase-0.48)/0.52) end
    end
    EvadeBlend=EvadeBlend+(envelope*DodgeStrength-EvadeBlend)*alpha(dt,32)
    local evade=EvadeBlend
    if distance<CastDistance+5 then InOrbit=true elseif distance>CastDistance+14 then InOrbit=false end
    OrbitBlend=OrbitBlend+((InOrbit and 1 or 0)-OrbitBlend)*alpha(dt,Tuning.orbitBlendRate or 8)
    local blend=smoothstep(OrbitBlend)
    local rate=Direction*((Tuning.orbitRate or 2.75)+evade*3.65+0.55*Motion.threat)*Adaptive.factor(AI,"orbitScale")
    AngularRate,Motion.angularAcceleration=Helpers.springStep(AngularRate,Motion.angularAcceleration,rate,22,dt)
    if not InOrbit and OrbitBlend<0.035 and horizontal.Magnitude>0.01 then
        Angle=math.atan2(horizontal.Z,horizontal.X)
    else
        Angle=(Angle+dt*AngularRate)%(2*math.pi)
    end
    local casting=CastTarget==Target and CastToken==Generation
    if casting and evading then Motion.dualFrames=Motion.dualFrames+1 end
    Options.phase(casting and evading and "ATTACCO + DODGE" or casting and "ATTACCO" or evading and "SCHIVATA" or InOrbit and "ORBITA" or "INSEGUIMENTO")
    -- Casting does not narrow the evasive envelope while danger is present.
    local activeMax=(casting and not evading) and math.max(RangeNow+2,DodgeMaxRadius-2) or DodgeMaxRadius
    -- Keep melee contact possible when not evading; do not sacrifice emergency dodge range.
    if Options.autoM1 and not evading and not casting and RangeTool then
        local kind=normalize(RangeTool.ToolTip or "")
        if kind=="melee" or kind=="fightingstyle" or kind=="sword" then
            activeMax=math.min(activeMax,math.max(12,RangeNow+1))
        end
    end
    local baseRadius=math.clamp(RangeNow+(OrbitRadius-RangeNow)*0.3+0.38*math.sin(now*1.8),10,activeMax)
    local wantedRadius=baseRadius+(activeMax-baseRadius)*math.max(evade,Motion.threat*0.22)
    if casting and evading then
        wantedRadius=math.min(wantedRadius,math.max(10,CastDistance-5))
    end
    RadiusNow,Motion.radialRate=Helpers.springStep(RadiusNow,Motion.radialRate,wantedRadius,20,dt)
    RadiusNow=math.clamp(RadiusNow,10,DodgeMaxRadius)
    HeightNow,Motion.heightRate=Helpers.springStep(HeightNow,Motion.heightRate,3.0+0.45*math.sin(now*1.6)+1.8*evade,16,dt)
    local nearBlend=1-smoothstep((distance-22)/30)
    local leadTime=0.035+0.08*(1-nearBlend)
    local prediction=Helpers.clampVector(TargetVelocity*leadTime+Motion.enemyAcceleration*(0.5*leadTime*leadTime),5+19*(1-nearBlend))
    local center=t.Position+prediction
    local radial=Vector3.new(math.cos(Angle),0,math.sin(Angle))
    local tangent=Vector3.new(-radial.Z,0,radial.X)
    local approachDir=horizontal.Magnitude>0.01 and horizontal.Unit or radial
    local approach=center+approachDir*RangeNow+Vector3.new(0,3.5,0)
    local orbit=center+radial*RadiusNow+Vector3.new(0,HeightNow,0)
    local destination=approach:Lerp(orbit,blend)
    if Water.enabled and Water.safeY then
        -- Apply the detected water floor to approach, orbit and dodge destinations.
        local minimum=Water.safeY
        destination=Vector3.new(destination.X,math.max(destination.Y,minimum),destination.Z)
    end
    -- Limit the relative speed in close orbit, not the target's own movement.
    local relativeCap=(Speed*(1-blend)+(90+evade*90)*blend)
    local targetFeed=Helpers.clampVector(TargetVelocity,230)
    local correction=(destination-r.Position)*(8+1.2*evade)+tangent*(RadiusNow*AngularRate*blend)
    -- Keep the extra evasive component tangential, not a lunge away from cast range.
    if evading and distance<CastDistance+4 then
        correction=correction+tangent*(Direction*evade*12*blend)
    end
    correction=correction+radial*(Motion.radialRate*blend)+Vector3.new(0,Motion.heightRate*blend,0)
    local relative=Helpers.clampVector(correction,relativeCap)
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
    -- Reduce overshoot as the orbit changes from attack to evasion.
    local desired=Helpers.clampVector(targetFeed+relative,limit)
    local current=Velocity.VectorVelocity
    local wantedAcceleration=Helpers.clampVector((desired-current)*(12+evade*8),1600+evade*2400*Adaptive.factor(AI,"dodgeScale"))
    local jerkLimit=(19000+evade*22000)*(Tuning.jerkScale or 1)
    local oldAcceleration=MoveAcceleration
    MoveAcceleration=MoveAcceleration+Helpers.clampVector(wantedAcceleration-MoveAcceleration,jerkLimit*dt)
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
    nextVelocity=Helpers.clampVector(nextVelocity,cap)
    -- Final vertical guard, after the movement controller has calculated velocity.
    if Water.enabled and Water.safeY then
        local safeY=Water.safeY
        -- Limit downward velocity before the next physics step can cross the water floor.
        local gap=r.Position.Y-safeY
        local horizon=math.clamp(dt*2,0.035,0.16)
        local lower=gap>0 and -gap/horizon or math.clamp(-gap*15,0,95)
        if gap<2 then lower=math.max(0,lower) end
        nextVelocity=Vector3.new(nextVelocity.X,math.max(nextVelocity.Y,lower),nextVelocity.Z)
    end
    Velocity.VectorVelocity=nextVelocity
end
local movement=Runtime.connect(RS.Heartbeat,function(dt)
    if Active then local ok,err=pcall(Helpers.updateMovement,dt); if not ok then Runtime.report("Movimento",err); Helpers.stopMovement(); Detail.Text="Volo: "..tostring(err):sub(1,45) end end
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
function Helpers.resetAim()
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
    AimControl.lastOriginAt,AimControl.fastUntil=0,0
    AimControl.originSpeed,AimControl.localSpeed=0,0
    AimControl.direct,AimControl.actualError=false,0
    AimControl.lastRender,AimControl.renderGap,AimControl.peakGap=0,0,0
    AimControl.pointer=nil
    AimControl.pointerEpoch=AimControl.pointerEpoch+1
    AimControl.forecastRoot,AimControl.forecastPosition,AimControl.forecastVelocity=nil,nil,nil
    AimControl.forecastAt,AimControl.forecastError,AimControl.forecastConfidence=0,0,0
    AimControl.forecastTurnUntil,AimControl.forecastLead=0,0
    AimControl.fastRoot,AimControl.fastPosition=nil,nil
    AimControl.fastAt,AimControl.fastConfidence=0,0
    AimControl.fastVelocity=Vector3.zero
    AimControl.fastSampleInterval,AimControl.fastTarget=1/60,false
    AimControl.angularSpeed,AimControl.lockUntil,AimControl.worldPointAt=0,0,0
    AimControl.worldGeneration=nil
    AimControl.pointerAge=0
end
function Helpers.rotateTowards(from,to,fraction)
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
function Helpers.queueAimPointer(pixel,force)
    if not VIM or not Active or Closed or HopBusy then return end
    AimControl.pointerSerial=AimControl.pointerSerial+1
    AimControl.pointer={
        pixel=pixel,serial=AimControl.pointerSerial,epoch=AimControl.pointerEpoch,
        generation=Generation,target=Target,force=force,at=os.clock(),world=AimPoint
    }
end
function Helpers.dispatchAimPointer()
    if AimControl.pointerBusy or not VIM or Closed or not Active or HopBusy then return end
    local item=AimControl.pointer
    if not item then return end
    local now=os.clock()
    if not MouseSupported and now<AimMouseRetryAt then return end
    if item.generation~=Generation or item.target~=Target or item.epoch~=AimControl.pointerEpoch or now-item.at>0.045 then
        AimControl.pointer=nil
        return
    end
    local pixel=item.pixel
    local cam=workspace.CurrentCamera
    -- Reproject the same world target against the current camera, which may have moved during a dodge.
    if item.world and cam then
        local projected,shown=cam:WorldToScreenPoint(item.world)
        if not shown or projected.Z<=0 then AimControl.pointer=nil; return end
        pixel=Vector2.new(projected.X,projected.Y)
        AimControl.reprojected=AimControl.reprojected+1
    end
    AimControl.pointerAge=now-item.at
    if not item.force and LastMousePoint and (pixel-LastMousePoint).Magnitude<0.20 and now-AimControl.lastPixelAt<0.025 then
        AimControl.pointer=nil
        return
    end
    AimControl.pointerBusy=true
    AimControl.pointer=nil
    local started=os.clock()
    local ok,err=pcall(function()
        VIM:SendMouseMoveEvent(math.floor(pixel.X+0.5),math.floor(pixel.Y+0.5),game)
    end)
    AimControl.dispatchMs=(os.clock()-started)*1000
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
            local ok,err=pcall(Helpers.dispatchAimPointer)
            if not ok then
                AimControl.pointerBusy=false
                Runtime.report("Puntatore",err)
            end
        end
    end
end)
-- Observe distinct replicated positions, rather than treating every render as a new sample.
function Helpers.trackFastTarget(part,position,raw,now)
    if AimControl.fastRoot~=part then
        AimControl.fastRoot=part
        AimControl.fastPosition=position
        AimControl.fastAt=now
        AimControl.fastVelocity=raw
        AimControl.fastConfidence=0
        AimControl.fastSampleInterval=1/60
        return raw
    end
    local elapsed=now-AimControl.fastAt
    local displacement=position-AimControl.fastPosition
    if elapsed>0.22 then
        AimControl.fastPosition=position
        AimControl.fastAt=now
        AimControl.fastVelocity=raw
        AimControl.fastConfidence=0
    elseif elapsed>=0.005 and displacement.Magnitude>0.035 then
        local speed=displacement.Magnitude/elapsed
        if displacement.Magnitude>math.max(32,elapsed*850) then
            AimControl.fastVelocity=raw
            AimControl.fastConfidence=0
            AimControl.forecastTurnUntil=now+0.045
        else
            local measured=Helpers.clampVector(displacement/elapsed,650)
            local disagreement=(raw-measured).Magnitude
            local rawSpeed=raw.Magnitude
            local agrees=rawSpeed>5 and measured.Magnitude>5 and raw.Unit:Dot(measured.Unit)>0.65
            if agrees or rawSpeed<5 then
                local quality=rawSpeed<5 and 0.45 or 1-math.clamp(disagreement/500,0,1)
                AimControl.fastVelocity=measured
                AimControl.fastConfidence=AimControl.fastConfidence+(quality-AimControl.fastConfidence)*0.5
            else
                AimControl.fastVelocity=raw
                AimControl.fastConfidence=0
                AimControl.forecastTurnUntil=now+0.045
            end
            AimControl.fastSampleInterval=AimControl.fastSampleInterval+(elapsed-AimControl.fastSampleInterval)*0.25
        end
        AimControl.fastPosition=position
        AimControl.fastAt=now
    end
    local age=now-AimControl.fastAt
    local observed=AimControl.fastVelocity
    local weight=math.clamp(AimControl.fastConfidence*(1-age/0.08),0,0.65)
    if raw.Magnitude>8 and observed.Magnitude>8 and raw.Unit:Dot(observed.Unit)<0.65 then weight=0 end
    if raw.Magnitude<5 and age>0.025 then weight=0 end
    return raw:Lerp(observed,weight)
end
function Helpers.aimAt(p,skill,force,renderDt)
    local t,r,cam=root(p),root(LP),workspace.CurrentCamera
    if not Active or Closed or HopBusy or Options.healing or p~=Target or not t or not r or not cam or not pvp(p) then return false end
    local now=os.clock()
    local position=t.Position
    local torso=p.Character:FindFirstChild("UpperTorso") or p.Character:FindFirstChild("Torso")
    local bodyOffset=Vector3.new(0,0.8,0)
    if torso and torso:IsA("BasePart") then
        bodyOffset=bodyOffset:Lerp(Helpers.clampVector(torso.Position-position,3),0.45)
    end
    local raw=Helpers.clampVector(t.AssemblyLinearVelocity,650)
    if AimRoot~=t or AimCamera~=cam then
        Helpers.resetAim()
        AimRoot,AimPos,AimTime,AimCamera=t,position,now,cam
        AimVelocity,AimStableVelocity,AimSampleVelocity,AimLastRaw=raw,raw,raw,raw
        AimOffset,AimLastOffset=bodyOffset,bodyOffset
        AimLastUpdate=now
    end
    Helpers.forecastAim(t,position,raw,now)
    local tracked=Helpers.trackFastTarget(t,position,raw,now)
    AimControl.fastTarget=math.max(raw.Magnitude,tracked.Magnitude)>110
    -- Cast and render may run in the same frame. Do not advance filters twice.
    local dt=math.clamp(now-AimLastUpdate,0,0.08)
    if AimLastUpdate==0 then dt=math.clamp(renderDt or 1/60,0,0.08) end
    AimLastUpdate=now
    local origin=cam.CFrame.Position
    local originDt=now-AimControl.lastOriginAt
    if originDt>=0.004 then
        if AimControl.lastOrigin then
            AimControl.originSpeed=(origin-AimControl.lastOrigin).Magnitude/originDt
        end
        if AimControl.lastLocalPosition then
            AimControl.localSpeed=(r.Position-AimControl.lastLocalPosition).Magnitude/originDt
        end
        AimControl.lastOrigin=origin
        AimControl.lastLocalPosition=r.Position
        AimControl.lastOriginAt=now
    end
    if now<DodgeUntil or EvadeBlend>0.025 or AimControl.originSpeed>22 or AimControl.localSpeed>40 then
        AimControl.fastUntil=now+0.10
    end
    local fastMotion=now<AimControl.fastUntil
    local equipped=LP.Character and LP.Character:FindFirstChildOfClass("Tool")
    local gun=equipped and normalize(equipped.ToolTip or "")=="gun"
    -- Relative angular motion, rather than target world speed alone, determines
    -- when the camera must use a direct lock. Own dodge velocity contributes
    -- to angular motion but is never added to the enemy position.
    local sight=position-origin
    local relative=tracked-r.AssemblyLinearVelocity
    if sight.Magnitude>0.01 then
        local axis=sight.Unit
        local transverse=relative-axis*relative:Dot(axis)
        AimControl.angularSpeed=transverse.Magnitude/math.max(3,sight.Magnitude)
    else AimControl.angularSpeed=0 end
    if AimControl.angularSpeed>2.0 or now<DodgeUntil then AimControl.lockUntil=now+0.10 end
    local direct=force or skill or fastMotion or gun or AimControl.fastTarget or now<AimControl.lockUntil
    AimControl.direct=direct
    if now<DodgeUntil and skill then AimControl.simultaneousFrames=AimControl.simultaneousFrames+1 end
    if renderDt and renderDt>0 and renderDt<0.15 then
        AimControl.frameInterval=AimControl.frameInterval+(renderDt-AimControl.frameInterval)*0.15
        AimControl.renderGap=renderDt
        AimControl.peakGap=math.max(renderDt,AimControl.peakGap*0.985)
        AimControl.lastRender=now
        if renderDt>0.040 then AimControl.lateFrames=AimControl.lateFrames+1 end
    end
    -- Observe actual position changes, not repeated render frames of the same replicated sample.
    if not AimControl.lastObserved then
        AimControl.lastObserved=position
        AimControl.lastObservedTime=now
    elseif (position-AimControl.lastObserved).Magnitude>0.025 then
        local elapsed=now-AimControl.lastObservedTime
        local displacement=position-AimControl.lastObserved
        if elapsed>0.005 and elapsed<0.18 and displacement.Magnitude<math.max(16,elapsed*750) then
            local observed=Helpers.clampVector(displacement/elapsed,650)
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
        local jump=sampleDt>0.25 or displacement.Magnitude>math.max(26,sampleDt*750)
        if jump then
            AimVelocity,AimStableVelocity,AimSampleVelocity=raw,raw,raw
            AimAcceleration=Vector3.zero
            AimDir,AimPoint=nil,nil
            AimLead=0
        else
            local measured=Helpers.clampVector(displacement/sampleDt,650)
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
                local acceleration=Helpers.clampVector((AimSampleVelocity-oldVelocity)/sampleDt,420)
                AimAcceleration=AimAcceleration:Lerp(acceleration,alpha(sampleDt,22))
            end
            AimVelocity=AimStableVelocity
        end
        AimPos,AimTime=position,now
        AimLastRaw=raw
    end
    -- Use the latest replicated position directly; only smooth the animated body offset.
    if gun then
        -- Aim at the current torso center for shots, without animation-filter lag.
        AimOffset=torso and torso:IsA("BasePart") and Helpers.clampVector(torso.Position-position,3) or bodyOffset
    else
        AimOffset=AimOffset:Lerp(bodyOffset,alpha(dt,direct and 160 or 90))
    end
    local currentVelocity=AimVelocity:Lerp(raw,0.92)
    if AimControl.confidence>0.35 and now-AimControl.lastObservedTime<0.08 then
        currentVelocity=currentVelocity:Lerp(AimControl.observed,AimControl.confidence*0.20)
    end
    if raw.Magnitude<3 and AimVelocity.Magnitude<6 then currentVelocity=Vector3.zero end
    if raw.Magnitude>8 and currentVelocity.Magnitude>8 and raw.Unit:Dot(currentVelocity.Unit)<0.5 then
        currentVelocity=raw
    end
    if AimControl.fastTarget then currentVelocity=tracked end
    local distance=(position-r.Position).Magnitude
    local desiredLead=skill and math.clamp(AimControl.frameInterval*0.36+distance/2900,0.005,0.032) or math.clamp(distance/6000,0.002,0.014)
    if gun then
        -- Small replication-aware lead; projectile speed is not assumed known.
        local age=math.clamp(now-AimControl.lastObservedTime,0,0.025)
        desiredLead=math.clamp(AimControl.frameInterval*0.50+age*0.35+distance/4000,0.005,0.035)
    end
    if AimControl.fastTarget then
        local age=math.clamp(now-AimControl.fastAt,0,0.045)
        local sampleInterval=math.clamp(AimControl.fastSampleInterval,0.005,0.06)
        desiredLead=math.clamp(AimControl.frameInterval*0.45+sampleInterval*0.35+age*0.5+distance/4500,0.008,0.060)
    end
    if AimControl.innovation>80 then desiredLead=desiredLead*(AimControl.fastTarget and 0.85 or 0.65) end
    if currentVelocity.Magnitude>8 and raw.Magnitude>8 and raw.Unit:Dot(currentVelocity.Unit)<0.75 then desiredLead=desiredLead*0.5 end
    if raw.Magnitude<2 and currentVelocity.Magnitude<5 then desiredLead=0 end
    if AimControl.innovation>120 and not AimControl.fastTarget then desiredLead=math.min(desiredLead,0.006) end
    -- Local strafe speed changes the viewing angle, not the enemy world position.
    -- Avoid adding extra target lead just because our own camera moves quickly.
    if fastMotion and not skill and not gun and not AimControl.fastTarget then
        -- Keep moderate target lead during our own dodge; only reduce it if the estimate is unstable.
        local cap=AimControl.forecastConfidence>0.60 and 0.014 or 0.008
        desiredLead=math.min(desiredLead,cap)
    end
    -- Recalibrate lead from recent prediction errors, not a fixed ping guess.
    local confidence=math.clamp(AimControl.forecastConfidence,0,1)
    desiredLead=desiredLead*(0.65+0.35*confidence)
    if now<AimControl.forecastTurnUntil then desiredLead=math.min(desiredLead,0.007) end
    if AimControl.forecastError>4 then desiredLead=desiredLead*0.55 end
    desiredLead=desiredLead*Adaptive.factor(AI,"leadScale")
    if direct then AimLead=desiredLead else AimLead=AimLead+(desiredLead-AimLead)*alpha(dt,100) end
    local lead=AimLead
    AimControl.forecastLead=lead
    local acceleration=AimAcceleration
    if now<AimControl.forecastTurnUntil then acceleration=Vector3.zero end
    if currentVelocity.Magnitude<4 then acceleration=Vector3.zero end
    local maxLeadDistance=AimControl.fastTarget and math.clamp(currentVelocity.Magnitude*0.045,8,26) or ((skill or gun) and 11 or 4)
    local prediction=Helpers.clampVector(currentVelocity*lead+acceleration*(0.5*lead*lead),maxLeadDistance)
    local desiredPoint=position+AimOffset+prediction
    AimPoint=desiredPoint
    AimControl.worldPointAt=now
    AimControl.worldGeneration=Generation
    origin=cam.CFrame.Position
    local offset=desiredPoint-origin
    if offset.Magnitude<0.01 then return false end
    local desired=offset.Unit
    local previous=cam.CFrame.LookVector
    local angle=math.acos(math.clamp(previous:Dot(desired),-1,1))
    local rate=320+math.min(angle*180,320)
    AimControl.angularError=angle
    -- No angular interpolation during dodge, fast orbit or cast.
    if direct or now<AimControl.forecastTurnUntil then
        AimDir=desired
    else
        local fraction=alpha(dt,rate)
        if angle<0.065 then fraction=1 end
        AimDir=Helpers.rotateTowards(previous,desired,fraction)
    end
    local up=math.abs(AimDir.Y)>0.9999 and Vector3.zAxis or Vector3.yAxis
    cam.CFrame=CFrame.lookAt(origin,origin+AimDir,up)
    AimControl.actualError=math.acos(math.clamp(cam.CFrame.LookVector:Dot(desired),-1,1))
    if VIM and (force or direct or now>=NextMouse) then
        local xy,onScreen=cam:WorldToScreenPoint(desiredPoint)
        NextMouse=now+1/Tuning.aimHz
        if onScreen and xy.Z>0 then
            Helpers.queueAimPointer(Vector2.new(xy.X,xy.Y),force or AimControl.fastTarget or now<DodgeUntil)
        end
    end
    return true
end
RS:BindToRenderStep("AutoBountyAim",Enum.RenderPriority.Last.Value,function(dt)
    if Active and Target and os.clock()>=AimRetryAt then
        local ok,err=pcall(Helpers.aimAt,Target,(CastTarget==Target and CastToken==Generation) or os.clock()<CastUntil,false,dt)
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
            if v:IsA("Tool") and category(v) and Options.allowed[category(v)] then
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
function Helpers.skillRecord(tool)
    local record=Scheduler.tools[tool]
    if not record then
        record={rows={},gui=nil,retry=0,lastUse=0,checks=0,successes=0,failures=0,lastReady=0,lastObserved=0,
            rowInfo={},nextGuiScan=0,failedEquip=0}
        Scheduler.tools[tool]=record
    end
    return record
end
function Helpers.skillGui(tool)
    local record=Helpers.skillRecord(tool)
    if record.gui and record.gui.Parent and record.gui:IsDescendantOf(PG) then
        return record.gui
    end
    if os.clock()<record.nextGuiScan then return nil end
    record.nextGuiScan=os.clock()+0.04
    table.clear(record.rows)
    table.clear(record.rowInfo)
    local main=PG:FindFirstChild("Main")
    local skills=main and main:FindFirstChild("Skills",true)
    record.gui=skills and skills:FindFirstChild(tool.Name,true)
    return record.gui
end
function Helpers.skillStatus(tool,k)
    local kind=category(tool)
    if not kind or not Options.allowed[kind] or not Options.skills[kind][k] then return "blocked" end
    if kind=="Blox Fruit" and k=="V" then return "blocked" end
    local record=Helpers.skillRecord(tool)
    local now=os.clock()
    if (LastCast[tool] and LastCast[tool][k] or 0)>now then return "cooldown" end
    local container=Helpers.skillGui(tool)
    local row=record.rows[k]
    if not row or not row.Parent or not container or not row:IsDescendantOf(container) then
        row=container and container:FindFirstChild(k,true)
        record.rows[k]=row
        record.rowInfo[k]=nil
    end
    if not row or not visible(row) then return "unknown" end
    local info=record.rowInfo[k]
    if not info or info.row~=row or now-info.at>Tuning.skillCacheTTL then
        info={row=row,at=now,descendants=row:GetDescendants(),cd=row:FindFirstChild("Cooldown",true)}
        record.rowInfo[k]=info
    end
    local descendants=info.descendants
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
    local cd=info.cd
    if not cd or not cd.Parent or not cd:IsA("GuiObject") then return "unknown" end
    if not visible(cd) or cd.AbsoluteSize.X<=1 then return "ready" end
    return "cooldown"
end
local function ready(tool,k)
    return Helpers.skillStatus(tool,k)=="ready"
end
function Helpers.observeTool(tool)
    local record=Helpers.skillRecord(tool)
    local readyKeys={}
    local known,waiting=0,0
    for _,k in ipairs(Keys) do
        local status=Helpers.skillStatus(tool,k)
        if status~="unknown" then known=known+1 end
        if status=="ready" then table.insert(readyKeys,k) end
        if status=="cooldown" then waiting=waiting+1 end
    end
    record.checks=record.checks+1
    record.lastReady=#readyKeys
    record.lastObserved=os.clock()
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
local M1={nextAt=0,blockUntil=0,attempts=0,errors=0,equipping=false,busy=false,
    activeTool=nil,activeGeneration=nil,pulses=0,reason="attesa",startedAt=0,
    backend=nil,mousePoint=nil,mouseFailures=0,toolFailures=0,lastBackend="Tool",
    probeTarget=nil,probeTool=nil,probeStart=0,probeAttempts=0,probeHealth=nil,preferMouseUntil=0}
function Helpers.releaseM1()
    local tool,backend,point=M1.activeTool,M1.backend,M1.mousePoint
    if not tool then return end
    M1.activeTool,M1.activeGeneration,M1.backend,M1.mousePoint=nil,nil,nil,nil
    local ok,err=pcall(function()
        if backend=="Mouse" and VIM and point then
            VIM:SendMouseButtonEvent(point.X,point.Y,0,false,game,0)
        else tool:Deactivate() end
    end)
    if not ok then M1.errors=M1.errors+1; Runtime.report("M1 release",err) end
end
function Helpers.releaseKeys()
    Helpers.releaseM1()
    M1.blockUntil=os.clock()+0.08
    M1.nextAt=M1.blockUntil
    M1.equipping=false
    for k in pairs(Pressed) do send(k,false) end
    table.clear(Pressed)
    CastTarget,CastToken,CastUntil=nil,nil,0
    Soru.busy=false
    Helpers.resetAim()
end
local function cast(tool,k)
    M1.blockUntil=math.max(M1.blockUntil,os.clock()+0.012)
    Helpers.releaseM1()
    if not Active or Closed or Options.healing or os.clock()<InputFailureUntil or (category(tool)=="Blox Fruit" and k=="V") then return false end
    local current,token=Target,Generation; CastTarget,CastToken=current,token
    local function valid()
        local r,t=root(LP),root(current)
        return Active and not Closed and not HopBusy and not Options.healing and token==Generation and current==Target and r and t and tool.Parent==LP.Character and pvp(current) and (r.Position-t.Position).Magnitude<=math.min(AttackRange,Helpers.rangeProfile(tool)[3]+3)
    end
    -- Aim and key-down are executed in the same callback, with no extra frame wait.
    if not valid() or not Helpers.aimAt(current,true,true) then CastTarget,CastToken=nil,nil; return false end
    -- Flush a current pointer update before key-down when the dispatcher is idle.
    if not AimControl.pointerBusy then Helpers.dispatchAimPointer() end
    if not valid() then CastTarget,CastToken=nil,nil; return false end
    -- Refresh if an executor input call yielded while the player was evading.
    if AimControl.worldGeneration~=token or os.clock()-AimControl.worldPointAt>0.020 then
        if not Helpers.aimAt(current,true,true) then CastTarget,CastToken=nil,nil; return false end
        if not AimControl.pointerBusy then Helpers.dispatchAimPointer() end
    end
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
    local untilTime=os.clock()+math.max(Tuning.skillHold*Adaptive.factor(AI,"holdScale"),math.min(0.070,AimControl.frameInterval*1.5)); CastUntil=untilTime+0.12
    local castOK,castError=pcall(function()
        repeat
            RS.RenderStepped:Wait()
            if not valid() then break end
            if os.clock()<DodgeUntil and os.clock()-AimControl.worldPointAt>0.015 then
                Helpers.aimAt(current,true,true)
            end
        until os.clock()>=untilTime
        if valid() then
            Helpers.aimAt(current,true,true)
            if not AimControl.pointerBusy then Helpers.dispatchAimPointer() end
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
    LastCast[tool][k]=os.clock()+0.40
    CastUntil=os.clock()+0.12
    Scheduler.successfulInputs=Scheduler.successfulInputs+1
    Scheduler.lastSkill=os.clock()
    Scheduler.lastActionAt=Scheduler.lastSkill
    M1.blockUntil=os.clock()
    Scheduler.comboCount=Scheduler.comboCount+1
    return true
end
local function readState(obj,names)
    if not obj then return nil end
    for _,n in ipairs(names) do local a=obj:GetAttribute(n); if type(a)=="boolean" or type(a)=="number" then return a end; local x=obj:FindFirstChild(n); if x and (x:IsA("BoolValue") or x:IsA("NumberValue") or x:IsA("IntValue")) then return x.Value end end
end
function Helpers.trySoru()
    if not Active or Closed or HopBusy or Options.healing or not Soru.enabled or Soru.busy or CastTarget then return false end
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
    Helpers.releaseM1()
    Soru.next=now+Soru.cooldown
    local ok=Helpers.aimAt(target,true,true)
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
        Helpers.releaseM1()
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
    local selfHumanoid=humanoid(LP)
    if not selfHumanoid or selfHumanoid.Health<math.min(Options.healLow,selfHumanoid.MaxHealth*0.80) then return end
    if Options.healing or os.clock()<Scheduler.nextAction or os.clock()<InputFailureUntil or next(Pressed) then return end
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
        M1.equipping=true
        Helpers.releaseM1()
        local equipOK,equipErr=pcall(function() h:EquipTool(tool) end)
        if not equipOK then
            M1.equipping=false
            Runtime.report("Equip",equipErr)
            return false
        end
        local deadline=os.clock()+Tuning.equipTimeout
        while tool.Parent~=LP.Character and valid() and os.clock()<deadline do
            RS.Heartbeat:Wait()
        end
        M1.equipping=false
        M1.blockUntil=os.clock()+0.008
        if not valid() or tool.Parent~=LP.Character then return false end
        Scheduler.lastWeapon=tool
        Scheduler.weaponSince=os.clock()
        Scheduler.lastEquip=os.clock()
        Scheduler.equips=Scheduler.equips+1
        RangeRefresh=0
        return true
    end
    local ordered={}
    local now=os.clock()
    local initialDistance=distance()
    local equipped=LP.Character and LP.Character:FindFirstChildOfClass("Tool")
    if equipped and Scheduler.lastWeapon~=equipped then
        Scheduler.lastWeapon=equipped
        Scheduler.weaponSince=now
    end
    for index,tool in ipairs(tools) do
        local record=Helpers.skillRecord(tool)
        if record.retry<=now and initialDistance<=Helpers.rangeProfile(tool)[3] then
            local score=0
            if tool.Parent==LP.Character then
                score=score+18
                if now-Scheduler.weaponSince<Tuning.minWeaponDwell then score=score+12 end
            end
            if now-record.lastObserved<0.40 then score=score+record.lastReady*5 end
            score=score+math.min(22,now-record.lastUse)-math.min(10,record.failedEquip*2)
            local offset=(index-Rotation-1)%#tools
            score=score-offset*0.4
            table.insert(ordered,{tool=tool,index=index,score=score})
        end
    end
    table.sort(ordered,function(a,b) return a.score>b.score end)
    for _,entry in ipairs(ordered) do
        if not valid() then return end
        local tool=entry.tool
        local record=Helpers.skillRecord(tool)
        if equip(tool) then
            local readyDeadline=os.clock()+Tuning.guiTimeout
            local available,known,waiting
            repeat
                available,known,waiting=Helpers.observeTool(tool)
                if #available>0 or known>=#Keys then break end
                if not valid() or tool.Parent~=LP.Character or os.clock()>=readyDeadline then break end
                RS.Heartbeat:Wait()
            until false
            local used=false
            record.failedEquip=0
            for _,k in ipairs(available or {}) do
                if not valid() or tool.Parent~=LP.Character or distance()>Helpers.rangeProfile(tool)[3] then break end
                if ready(tool,k) then
                    Detail.Text=tool.Name.." | "..k.." AIM"
                    if cast(tool,k) then
                        used=true
                        record.successes=record.successes+1
                        record.lastUse=os.clock()
                        Rotation=entry.index
                        local recover=os.clock()+Tuning.recovery*Adaptive.factor(AI,"recoveryScale")
                        while valid() and os.clock()<recover do RS.Heartbeat:Wait() end
                    else
                        record.failures=record.failures+1
                        if os.clock()<InputFailureUntil then break end
                    end
                end
            end
            if used then
                record.retry=os.clock()+0.030
                Scheduler.nextAction=os.clock()+0.006
                Scheduler.emptySince=0
                return
            end
            record.retry=os.clock()+((known or 0)==0 and Tuning.unknownRetry or Tuning.weaponRetry)
        else
            record.failedEquip=record.failedEquip+1
            record.retry=os.clock()+Tuning.unknownRetry
        end
    end
    if valid() then
        Scheduler.emptySince=Scheduler.emptySince==0 and os.clock() or Scheduler.emptySince
        Scheduler.nextAction=os.clock()+0.030
        Detail.Text="Attesa skill/input"
    end
end
-- Basic attacks use a separate low-priority, non-blocking loop.
-- Do not hold mouse buttons or simulate a click on the script interface.
function Helpers.tryM1()
    -- An activation lasts at least one Heartbeat unless a higher-priority skill preempts it.
    if M1.activeTool then
        Helpers.releaseM1()
        M1.pulses=M1.pulses+1
        return
    end
    local now=os.clock()
    if not Options.autoM1 or not Active or Closed or HopBusy or Options.healing or not Target then M1.reason="attesa"; return end
    if M1.equipping or M1.busy or Soru.busy or CastTarget or next(Pressed) or now<M1.blockUntil or now<InputFailureUntil then M1.reason="skill"; return end
    if now<M1.nextAt then return end
    local own,enemy=root(LP),root(Target)
    local health=humanoid(LP)
    if not health or health.Health<math.min(Options.healLow,health.MaxHealth*0.80) then return end
    if not own or not enemy or not pvp(Target) then return end
    local char=LP.Character
    local tool=char and char:FindFirstChildOfClass("Tool")
    if not tool then M1.reason="nessuna arma"; return end
    if not tool.Enabled then M1.reason="cooldown"; return end
    local kind=category(tool)
    if not kind or not Options.allowed[kind] then M1.reason="arma esclusa"; return end
    local maxRange=kind=="Gun" and 32 or kind=="Blox Fruit" and 21 or kind=="Sword" and 20 or 18
    if (own.Position-enemy.Position).Magnitude>maxRange then M1.reason="distanza"; return end
    local enemyHumanoid=humanoid(Target)
    if M1.probeTarget~=Target or M1.probeTool~=tool then
        M1.probeTarget,M1.probeTool=Target,tool
        M1.probeHealth=enemyHumanoid and enemyHumanoid.Health
        M1.probeStart,M1.probeAttempts=now,0
        M1.preferMouseUntil=0
    elseif enemyHumanoid and M1.probeHealth and enemyHumanoid.Health<M1.probeHealth-0.25 then
        M1.probeHealth=enemyHumanoid.Health
        M1.probeStart,M1.probeAttempts=now,0
    elseif now-M1.probeStart>1.8 and M1.probeAttempts>=12 and now-Scheduler.lastSkill>1.0 then
        M1.preferMouseUntil=now+2.5
        M1.probeStart,M1.probeAttempts=now,0
    end
    M1.busy=true
    local token,current=Generation,Target
    local ok,err=pcall(function()
        if kind=="Gun" then
            if not Helpers.aimAt(current,true,true) then M1.reason="mira"; return end
            if not AimControl.pointerBusy then Helpers.dispatchAimPointer() end
        end
        if not Active or Closed or HopBusy or Options.healing or token~=Generation or current~=Target or tool.Parent~=LP.Character or CastTarget or next(Pressed) then return end
        local backend=Options.m1Mode=="Mouse" and "Mouse" or "Tool"
        if Options.m1Mode=="Auto" and (now<M1.preferMouseUntil or kind=="Gun") then backend="Mouse" end
        local point=nil
        if backend=="Mouse" and VIM and AimPoint and workspace.CurrentCamera then
            local xy,shown=workspace.CurrentCamera:WorldToScreenPoint(AimPoint)
            if shown and xy.Z>0 then
                local x,y=math.floor(xy.X+0.5),math.floor(xy.Y+0.5)
                local ok,objects=pcall(function() return PG:GetGuiObjectsAtPosition(x,y) end)
                local blocked=not ok
                if ok then
                    for _,obj in ipairs(objects) do
                        if obj:IsDescendantOf(Gui) or obj:IsA("GuiButton") then blocked=true; break end
                    end
                end
                if not blocked then point=Vector2.new(x,y) end
            end
        end
        if backend=="Mouse" and not point then backend="Tool" end
        M1.activeTool,M1.activeGeneration=tool,token
        M1.backend,M1.mousePoint=backend,point
        M1.startedAt=os.clock()
        if backend=="Mouse" then
            VIM:SendMouseButtonEvent(point.X,point.Y,0,true,game,0)
        else
            tool:Activate()
        end
        M1.lastBackend=backend
        M1.attempts=M1.attempts+1
        M1.probeAttempts=M1.probeAttempts+1
        M1.reason=backend
    end)
    M1.busy=false
    if not ok then
        local backend=M1.backend
        Helpers.releaseM1()
        if backend=="Mouse" then M1.mouseFailures=M1.mouseFailures+1; M1.preferMouseUntil=0
        else M1.toolFailures=M1.toolFailures+1; M1.preferMouseUntil=os.clock()+2.5 end
        M1.errors=M1.errors+1
        M1.nextAt=os.clock()+0.10
        M1.reason="errore"
        Runtime.report("M1",err)
    end
end
Runtime.connect(RS.Heartbeat,function()
    if M1.activeTool or (Options.autoM1 and Active and not Closed) then Helpers.tryM1() end
end)
function Helpers.clearTarget(skip)
    HopFlight.active=false
    HopFlight.goal,HopFlight.character,HopFlight.health=nil,nil,nil
    if Target and skip then Skipped[Target.UserId]=os.clock()+90; Options.stats.skipped=Options.stats.skipped+1 end
    Target=nil; Generation=Generation+1; CombatStarted=nil; BestDistance=math.huge; Helpers.releaseKeys(); Helpers.stopMovement(); Helpers.resetScheduler()
    Options.healing=false; Options.healTarget=nil
    Options.healGoal,Options.healCharacter=nil,nil
    Options.phase("IDLE")
end
Runtime.release=function()
    Helpers.clearTarget(false)
    Helpers.removeWaterSupport()
end
function Helpers.queueRestart()
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
function Helpers.getServerPage(url)
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
function Helpers.chooseServer(serial)
    local candidates,seen={},{}
    local cursor=nil
    local order=RNG:NextNumber()<0.5 and "Asc" or "Desc"
    for page=1,3 do
        if Closed or not Active or not AutoHop or serial~=HopSerial then return nil end
        local url="https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder="..order.."&limit=100&excludeFullGames=true"
        if cursor then url=url.."&cursor="..HttpService:UrlEncode(cursor) end
        local result=Helpers.getServerPage(url)
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
function Helpers.hopFailed(message,serial)
    if serial~=HopSerial then return end
    HopFlight.active=false
    HopFlight.goal,HopFlight.character,HopFlight.health=nil,nil,nil
    Helpers.stopMovement()
    Options.phase("IDLE")
    HopBusy=false
    EmptySince=nil
    NextHop=os.clock()+HopCooldown
    if not Closed then HopStatus.Text=message.." | nuovo tentativo" end
end
function Helpers.localCombatState()
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
function Helpers.canHop(now)
    local state=Helpers.localCombatState()
    if now-CombatGuard.lastDamage<3 then state=true end
    if state~=false then
        CombatGuard.clearSince=nil
        return false,state==true and "Combat attivo: attesa" or "Combat non verificato: attesa"
    end
    CombatGuard.clearSince=CombatGuard.clearSince or now
    if now-CombatGuard.clearSince<3 then return false,"Fine combat: verifica..." end
    return true
end
function Helpers.cancelHop(reason,serial)
    if serial~=HopSerial then return end
    HopFlight.active=false
    HopFlight.goal,HopFlight.character,HopFlight.health=nil,nil,nil
    Helpers.stopMovement()
    Options.phase("IDLE")
    HopBusy=false
    EmptySince=nil
    if not Closed then HopStatus.Text=reason end
end
function Helpers.hopStillValid(serial)
    if Closed or not Active or not AutoHop or serial~=HopSerial or not HopBusy then return false,"Cambio annullato" end
    local h=humanoid(LP)
    if not root(LP) or LP.Character~=HopFlight.character or not h then return false,"Personaggio cambiato" end
    if HopFlight.health and h.Health<HopFlight.health then
        CombatGuard.lastDamage=os.clock()
        CombatGuard.clearSince=nil
        return false,"Danno ricevuto: cambio annullato"
    end
    HopFlight.health=h.Health
    local safe,reason=Helpers.canHop(os.clock())
    if not safe then return false,reason end
    local candidate,allowed,loaded=Helpers.findTarget()
    if candidate or allowed>loaded then return false,"Giocatori disponibili" end
    return true
end
function Helpers.startHop()
    if HopBusy or Closed or not Active or not AutoHop or Options.healing then return end
    local safe,reason=Helpers.canHop(os.clock())
    if not safe then HopStatus.Text=reason; return end
    HopBusy=true
    HopSerial=HopSerial+1
    local serial=HopSerial
    HopStarted=os.clock()
    NextHop=HopStarted+HopCooldown
    Helpers.clearTarget(false)
    local r,h=root(LP),humanoid(LP)
    if not r or not h then Helpers.cancelHop("Personaggio non disponibile",serial); return end
    HopFlight.active=true
    HopFlight.character=LP.Character
    HopFlight.health=h.Health
    HopFlight.serial=serial
    HopFlight.goal=r.Position.Y+HopFlight.height
    HopStatus.Text="Salita prima del cambio server..."
    task.spawn(function()
        local ok,err=pcall(function()
            local deadline=os.clock()+7
            local reached=false
            while os.clock()<deadline do
                local valid,why=Helpers.hopStillValid(serial)
                if not valid then Helpers.cancelHop(why,serial); return end
                local current=root(LP)
                local remaining=HopFlight.goal-current.Position.Y
                HopStatus.Text="Salita: "..math.max(0,math.ceil(remaining)).." studs"
                if remaining<=3 then reached=true; break end
                task.wait(0.20)
            end
            if not reached then Helpers.hopFailed("Salita non riuscita",serial); return end
            HopStatus.Text="In quota | ricerca server..."
            local id=Helpers.chooseServer(serial)
            if Closed or not Active or not AutoHop or serial~=HopSerial then return end
            if not id then Helpers.hopFailed("Nessun server trovato",serial); return end
            -- A new target may have appeared while the HTTP request was running.
            local candidate,allowed,loaded=Helpers.findTarget()
            if candidate or allowed>loaded then
                Helpers.cancelHop("Giocatori disponibili",serial)
                return
            end
            local safe,reason=Helpers.canHop(os.clock())
            if not safe then Helpers.cancelHop(reason,serial); return end
            local queued=Helpers.queueRestart()
            if not queued then
                Helpers.hopFailed("Riavvio automatico non disponibile",serial)
                return
            end
            FailedServers[id]=os.clock()+180
            HopStarted=os.clock()
            HopStatus.Text=queued and "Cambio server..." or "Cambio server | riavvio manuale"
            if Closed or not Active or not AutoHop or serial~=HopSerial then return end
            local stillSafe,why=Helpers.hopStillValid(serial)
            if not stillSafe then Helpers.cancelHop(why,serial); return end
            TeleportService:TeleportToPlaceInstance(game.PlaceId,id,LP)
        end)
        if not ok then Runtime.report("Server",err); Helpers.hopFailed("Errore server",serial) end
    end)
end
local teleportFailure=Runtime.connect(TeleportService.TeleportInitFailed,function(player,result,message)
    if player==LP and HopBusy then
        Runtime.report("Teleport",tostring(result).." "..tostring(message))
        Helpers.hopFailed("Teleport fallito",HopSerial)
    end
end)
function Helpers.monitorHop(candidate,allowed,loaded,now)
    if not AutoHop then EmptySince=nil; return end
    if now-JoinedAt<JoinGrace then
        EmptySince=nil
        HopStatus.Text="Caricamento server..."
        return
    end
    if Options.healing or Target or candidate or allowed>loaded then
        CombatGuard.clearSince=nil
        EmptySince=nil
        HopStatus.Text="Server hop: ON"
        return
    end
    local safe,reason=Helpers.canHop(now)
    if not safe then EmptySince=nil; HopStatus.Text=reason; return end
    if now<NextHop then
        EmptySince=nil
        HopStatus.Text="Attesa cambio: "..math.ceil(NextHop-now).."s"
        return
    end
    EmptySince=EmptySince or now
    local remaining=math.max(0,EmptyDelay-(now-EmptySince))
    HopStatus.Text="Nessun PvP | cambio tra "..math.ceil(remaining).."s"
    if remaining<=0 then Helpers.startHop() end
end
function Helpers.checkRecovery()
    if Closed or not Active then return false end
    local h,r=humanoid(LP),root(LP)
    if not h or not r or h.MaxHealth<=0 then return Options.healing end
    local low=math.min(Options.healLow,h.MaxHealth*0.80)
    local high=math.min(Options.healHigh,h.MaxHealth)
    if Options.healing then
        if h.Health>=high then
            Options.healing=false
            Options.healTarget=nil
            Options.healGoal,Options.healCharacter=nil,nil
            CombatStarted=nil
            LastProgress=os.clock()
            Scheduler.lastHit=LastProgress
            EmptySince=nil
            Options.phase("INSEGUIMENTO")
            Info.Text="HP recuperati | ricerca target"
            return false
        end
        Info.Text=string.format("HP %d/%d | Quota +%d",math.floor(h.Health),math.floor(high),math.floor(math.max(0,Options.healAltitude-((Options.healGoal or r.Position.Y)-r.Position.Y))))
        return true
    end
    if h.Health<low then
        if HopBusy then
            HopSerial=HopSerial+1
            Helpers.cancelHop("HP bassi: recupero",HopSerial)
        end
        Options.healing=true
        Options.healTarget=Target
        Options.healCharacter=LP.Character
        Options.healGoal=r.Position.Y+Options.healAltitude
        Options.healStarted=os.clock()
        Options.healCount=Options.healCount+1
        Generation=Generation+1
        Target=nil
        CombatStarted=nil
        EmptySince=nil
        Helpers.releaseKeys()
        Helpers.resetScheduler()
        Options.phase("RECUPERO IN QUOTA")
        Info.Text="HP bassi: salita immediata"
        return true
    end
    return false
end
Runtime.connect(RS.Heartbeat,function()
    if Active and not Closed then Helpers.checkRecovery() end
end)
function Helpers.setActive(value)
    if Closed then return end
    Active=value
    saveState(Active and "on" or "off")
    Generation=Generation+1
    Button.Text=Active and "AUTO BOUNTY: ON" or "AUTO BOUNTY: OFF"
    Button.BackgroundColor3=Active and Color3.fromRGB(30,160,75)
        or Color3.fromRGB(170,40,40)
    if not Active then
        HopSerial=HopSerial+1; HopBusy=false; EmptySince=nil
        Helpers.clearTarget(false)
        CombatGuard.clearSince=nil
        -- Keep the independent Water Walk toggle active while PvP is paused.
        Info.Text="Disattivato"
    else
        table.clear(Skipped)
        Helpers.resetScheduler()
        NextRace,NextKen=0,0
        MouseSupported=VIM~=nil
        InputFailureUntil=0
        Soru.busy=false
        Buff.character=nil
        Helpers.resetAim()
        Info.Text="Ricerca giocatori..."
    end
    if not VIM then
        Diagnostic.Text="Input executor non disponibile"
    else
        Diagnostic.Text=Active and "Avvio riuscito | ricerca attiva" or "In pausa"
    end
end
Runtime.connect(Button.Activated,function() Helpers.setActive(not Active) end)
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
    if not AutoHop then
        HopSerial=HopSerial+1
        if HopFlight.active then Helpers.cancelHop("Server hop: OFF",HopSerial) end
        HopBusy=false
    end
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
                    if HopFlight.active then
                        local valid,why=Helpers.hopStillValid(HopSerial)
                        if not valid then Helpers.cancelHop(why,HopSerial); return end
                    end
                    if now-HopStarted>40 then
                        HopSerial=HopSerial+1
                        Helpers.hopFailed("Timeout teleport",HopSerial)
                    end
                    return
                end
                local r=root(LP)
                if not r then
                    EmptySince=nil
                    if Target or Velocity then Helpers.clearTarget(false) end
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
                if Options.skipRequested then
                    Options.skipRequested=false
                    if Target then Helpers.clearTarget(true) end
                end
                if Helpers.checkRecovery() then return end
                local candidate,allowed,loaded=Helpers.findTarget()
                if Target then
                    local t=root(Target)
                    if not t or not pvp(Target) then Helpers.clearTarget(false)
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
                                Options.stats.damageObserved=Options.stats.damageObserved+Scheduler.targetHealth-enemyHealth.Health
                                Scheduler.lastHit=now
                                LastProgress=now
                            end
                            Scheduler.targetHealth=enemyHealth.Health
                        end
                        -- Count from acquisition, including approach. Only observed health
                        -- loss resets inactivity; key presses and movement do not.
                        local noDamage=now-math.max(Started,Scheduler.lastHit)>=Tuning.noDamageTimeout
                        local overtime=CombatStarted and now-CombatStarted>Tuning.attackTimeout
                        if noDamage or overtime then
                            local reason=noDamage and "90s senza danno osservato" or "Limite combattimento"
                            Helpers.clearTarget(true)
                            Detail.Text="Cambio target: "..reason
                            -- Re-rank immediately after excluding the previous opponent.
                            candidate,allowed,loaded=Helpers.findTarget()
                        end
                    end
                end
                if not Target and candidate and (Skipped[candidate.UserId] or 0)<=now and root(candidate) and pvp(candidate) then
                    Target=candidate; Started=now; LastProgress=now; BestDistance=math.huge
                    Options.stats.targets=Options.stats.targets+1
                    Helpers.resetScheduler()
                    Scheduler.target=candidate
                    Scheduler.targetHealth=humanoid(candidate) and humanoid(candidate).Health
                    Scheduler.lastHit=now
                end
                local t=root(Target)
                Info.Text=t and (Target.Name.." | "..math.floor((r.Position-t.Position).Magnitude).." studs | "..math.max(0,math.ceil(Tuning.noDamageTimeout-(now-math.max(Started,Scheduler.lastHit)))).."s") or "Ricerca giocatori..."
                Helpers.monitorHop(candidate,allowed,loaded,now)
            end)
            if not ok then Runtime.report("Scansione",err); Detail.Text="Scan: "..tostring(err):sub(1,45) end
        end
        task.wait(ScanInterval)
    end
end)
task.spawn(function()
    while not Closed do
        if Active and not HopBusy and not Options.healing then
            local ok,err=pcall(powers)
            if not ok then Runtime.report("Poteri",err); Helpers.releaseKeys() end
        end
        if Active and not HopBusy and not Options.healing and Target then
            local r,t=root(LP),root(Target)
            if r and t and (r.Position-t.Position).Magnitude<=AttackRange and pvp(Target) then
                local token=Generation
                local ok,err=pcall(function()
                    Helpers.trySoru()
                    if not Active or token~=Generation then return end
                    local own,enemy=root(LP),root(Target)
                    if own and enemy and (own.Position-enemy.Position).Magnitude<=math.min(AttackRange,CastDistance+5) then
                        if Active and token==Generation then combat() end
                    end
                end)
                if not ok then
                    Runtime.report("Combat",err)
                    Soru.busy=false
                    M1.equipping=false
                    Helpers.releaseKeys()
                    Detail.Text="Combat: "..tostring(err):sub(1,45)
                end
            end
        end
        RS.Heartbeat:Wait()
    end
end)
local removing=Runtime.connect(P.PlayerRemoving,function(p)
    Cache[p]=nil; Skipped[p.UserId]=nil; if Target==p then Helpers.clearTarget(false) end
end)
local respawn=Runtime.connect(LP.CharacterAdded,function() if HopBusy then HopSerial=HopSerial+1; Helpers.cancelHop("Respawn: cambio annullato",HopSerial) end; EmptySince=nil; CombatGuard.clearSince=nil; CombatGuard.lastHealth=nil; CombatGuard.lastDamage=0; Buff.character=nil; Soru.busy=false; Helpers.removeWaterSupport(); Helpers.clearTarget(false); table.clear(LastCast); table.clear(Scheduler.tools) end)
local teleportStarted=Runtime.connect(LP.OnTeleport,function(state)
    if Closed then return end
    if state==Enum.TeleportState.Started or state==Enum.TeleportState.InProgress then
        saveState(Active and "on" or "off")
        Helpers.queueRestart()
    end
end)
Runtime.connect(Gui.Destroying,function()
    Closed=true; Active=false
    HopSerial=HopSerial+1; HopBusy=false; teleportFailure:Disconnect(); teleportStarted:Disconnect()
    Generation=Generation+1
    Helpers.clearTarget(false); removing:Disconnect(); respawn:Disconnect()
    movement:Disconnect(); noclip:Disconnect(); waterConnection:Disconnect(); waterPlaneAdded:Disconnect(); Helpers.removeWaterSupport()
    RS:UnbindFromRenderStep("AutoBountyAim")
    for _,connection in ipairs(Runtime.connections) do pcall(function() connection:Disconnect() end) end
    table.clear(Runtime.connections)
    Runtime.closing=true
end)

Runtime.stage="Self test"
do
    local ok,passed,total,first=pcall(Adaptive.runTests)
    if ok then
        AI.testsPassed,AI.testsTotal=passed,total
        AI.healthy=passed==total
        if first then Runtime.report("Adaptive test",first) end
    else
        AI.healthy=false
        Runtime.report("Adaptive test",passed)
    end
    if Options.widgets.aiTests then
        Options.widgets.aiTests.Text=string.format("TEST %d/%d %s",AI.testsPassed,AI.testsTotal,AI.healthy and "OK" or "FAIL")
    end
end
Runtime.connect(RS.Heartbeat,function()
    local now=os.clock()
    if not AI.enabled or not AI.healthy or now<AI.nextUpdate then return end
    local h,t=humanoid(LP),humanoid(Target)
    local r,tr=root(LP),root(Target)
    Adaptive.observe(AI,{
        active=Active and not Closed,healing=Options.healing,hopping=HopBusy,targetId=Target,
        frame=AimControl.frameInterval,threat=Motion.threat,innovation=AimControl.innovation,
        attempts=M1.attempts,skills=Scheduler.successfulInputs,errors=M1.errors+Scheduler.failedInputs,
        equips=Scheduler.equips,health=t and t.Health,ownHealth=h and h.Health,
        distance=r and tr and (r.Position-tr.Position).Magnitude or 0
    },now)
end)
Runtime.stage="Attivazione"
if not Closed then
    Helpers.setActive(AutoStart)
    Helpers.queueRestart()
    Runtime.stage="Pronto"
    Runtime.notify("V11.0 Fluid","Script caricato. Controlla il riquadro diagnostica.")
    task.spawn(function()
        while not Closed do
            if not Closed and WaterToggle.Parent then
                local now=os.clock()
                for key,owner in pairs(Pressed) do
                    if type(owner)=="table" and owner.at and now-owner.at>1.0 then
                        send(key,false)
                        Pressed[key]=nil
                        Runtime.report("Input","Rilascio di sicurezza "..key)
                    end
                end
                Telemetry.Text=string.format("%s | AI:%s | %.0f ms\nM1:%d | Skill:%d | Dual:%d | Lead:%.0fms",Motion.phase,AI.enabled and AI.healthy and AI.mode or "OFF",AimControl.renderGap*1000,M1.attempts,Scheduler.successfulInputs,Motion.dualFrames,AimControl.forecastLead*1000)
                local txt=Water.enabled and ("WATER WALK: "..(Water.status=="Superficie rilevata" and "ACQUA" or "ON")) or "WATER WALK: OFF"
                if Water.status=="Superficie rilevata" and Water.enabled then
                    txt=(Active and "WATER +10: " or "WATER: ")..Water.source:upper()..(Water.preempt and " | AHEAD" or "")
                end
                if WaterToggle.Text~=txt then WaterToggle.Text=txt end
                if Options.widgets.stats then
                    Options.widgets.stats.Text=string.format("Target: %d | Skip: %d | HP: %d",Options.stats.targets,Options.stats.skipped,Options.healCount)
                end
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
    Runtime.notify("Errore V11.0",Runtime.stage..": "..tostring(err):sub(1,120))
end
