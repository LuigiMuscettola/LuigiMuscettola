-- Quantum Nova 4.4 | Aero phase and lifecycle improvements
-- Uses standard Roblox APIs only. Includes optional experimental StartQuest/AddPoint requests; no server-side bypass.
-- Game-specific automation is limited to objects and actions exposed to the client.
-- All automation is disabled on launch. No telemetry or external code downloads.
local MathCore = {}
function MathCore.finite(x)
    return type(x)=="number" and x==x and x~=math.huge and x~=-math.huge
end
function MathCore.clamp(x,lo,hi)
    return math.max(lo,math.min(hi,x))
end
function MathCore.alpha(dt,tau)
    if not MathCore.finite(dt) or dt<=0 then return 0 end
    return 1-math.exp(-dt/math.max(tau,0.001))
end
function MathCore.lead(distance,speed,limit)
    if not MathCore.finite(distance) or not MathCore.finite(speed) then return 0 end
    return MathCore.clamp(distance/math.max(speed,1),0,limit)
end
function MathCore.score(distance,radius,hp,vertical,visible,kindWeight)
    if radius<=0 or distance>radius then return math.huge end
    return distance/radius*100 + MathCore.clamp(vertical,0,100)*.2
        + MathCore.clamp(hp,0,1)*12 + (visible and 0 or 18) + kindWeight
end
function MathCore.cooldown(base,failures,maxDelay)
    return math.min(maxDelay,base*2^MathCore.clamp(failures,0,10))
end
function MathCore.healthMode(current,hp,low,high)
    if hp<=low then return true end
    if hp>=high then return false end
    return current
end
function MathCore.stepClock(acc,dt,interval)
    if not MathCore.finite(dt) or dt<0 then return acc,false end
    local total=acc+math.min(dt,1)
    if total<interval then return total,false end
    return total%interval,true
end
function MathCore.segmentClear(distance,range,visible)
    return visible and distance<=range and distance>=0
end

local function runFullMathTests()
    local passed=0
    local function check(actual,expected,label)
        if type(expected)=="number" and expected~=math.huge then
            assert(math.abs(actual-expected)<1e-9,label)
        else
            assert(actual==expected,label)
        end
        passed=passed+1
    end
    do -- lead_0_1_0
        local actual = MathCore.lead(0,1,0)
        check(actual,0,"lead_0_1_0")
    end
    do -- lead_0_1_0.05
        local actual = MathCore.lead(0,1,0.05)
        check(actual,0,"lead_0_1_0.05")
    end
    do -- lead_0_1_0.1
        local actual = MathCore.lead(0,1,0.1)
        check(actual,0,"lead_0_1_0.1")
    end
    do -- lead_0_1_0.22
        local actual = MathCore.lead(0,1,0.22)
        check(actual,0,"lead_0_1_0.22")
    end
    do -- lead_0_1_0.5
        local actual = MathCore.lead(0,1,0.5)
        check(actual,0,"lead_0_1_0.5")
    end
    do -- lead_0_8_0
        local actual = MathCore.lead(0,8,0)
        check(actual,0,"lead_0_8_0")
    end
    do -- lead_0_8_0.05
        local actual = MathCore.lead(0,8,0.05)
        check(actual,0,"lead_0_8_0.05")
    end
    do -- lead_0_8_0.1
        local actual = MathCore.lead(0,8,0.1)
        check(actual,0,"lead_0_8_0.1")
    end
    do -- lead_0_8_0.22
        local actual = MathCore.lead(0,8,0.22)
        check(actual,0,"lead_0_8_0.22")
    end
    do -- lead_0_8_0.5
        local actual = MathCore.lead(0,8,0.5)
        check(actual,0,"lead_0_8_0.5")
    end
    do -- lead_0_16_0
        local actual = MathCore.lead(0,16,0)
        check(actual,0,"lead_0_16_0")
    end
    do -- lead_0_16_0.05
        local actual = MathCore.lead(0,16,0.05)
        check(actual,0,"lead_0_16_0.05")
    end
    do -- lead_0_16_0.1
        local actual = MathCore.lead(0,16,0.1)
        check(actual,0,"lead_0_16_0.1")
    end
    do -- lead_0_16_0.22
        local actual = MathCore.lead(0,16,0.22)
        check(actual,0,"lead_0_16_0.22")
    end
    do -- lead_0_16_0.5
        local actual = MathCore.lead(0,16,0.5)
        check(actual,0,"lead_0_16_0.5")
    end
    do -- lead_0_24_0
        local actual = MathCore.lead(0,24,0)
        check(actual,0,"lead_0_24_0")
    end
    do -- lead_0_24_0.05
        local actual = MathCore.lead(0,24,0.05)
        check(actual,0,"lead_0_24_0.05")
    end
    do -- lead_0_24_0.1
        local actual = MathCore.lead(0,24,0.1)
        check(actual,0,"lead_0_24_0.1")
    end
    do -- lead_0_24_0.22
        local actual = MathCore.lead(0,24,0.22)
        check(actual,0,"lead_0_24_0.22")
    end
    do -- lead_0_24_0.5
        local actual = MathCore.lead(0,24,0.5)
        check(actual,0,"lead_0_24_0.5")
    end
    do -- lead_0_60_0
        local actual = MathCore.lead(0,60,0)
        check(actual,0,"lead_0_60_0")
    end
    do -- lead_0_60_0.05
        local actual = MathCore.lead(0,60,0.05)
        check(actual,0,"lead_0_60_0.05")
    end
    do -- lead_0_60_0.1
        local actual = MathCore.lead(0,60,0.1)
        check(actual,0,"lead_0_60_0.1")
    end
    do -- lead_0_60_0.22
        local actual = MathCore.lead(0,60,0.22)
        check(actual,0,"lead_0_60_0.22")
    end
    do -- lead_0_60_0.5
        local actual = MathCore.lead(0,60,0.5)
        check(actual,0,"lead_0_60_0.5")
    end
    do -- lead_0_100_0
        local actual = MathCore.lead(0,100,0)
        check(actual,0,"lead_0_100_0")
    end
    do -- lead_0_100_0.05
        local actual = MathCore.lead(0,100,0.05)
        check(actual,0,"lead_0_100_0.05")
    end
    do -- lead_0_100_0.1
        local actual = MathCore.lead(0,100,0.1)
        check(actual,0,"lead_0_100_0.1")
    end
    do -- lead_0_100_0.22
        local actual = MathCore.lead(0,100,0.22)
        check(actual,0,"lead_0_100_0.22")
    end
    do -- lead_0_100_0.5
        local actual = MathCore.lead(0,100,0.5)
        check(actual,0,"lead_0_100_0.5")
    end
    do -- lead_1_1_0
        local actual = MathCore.lead(1,1,0)
        check(actual,0,"lead_1_1_0")
    end
    do -- lead_1_1_0.05
        local actual = MathCore.lead(1,1,0.05)
        check(actual,0.05,"lead_1_1_0.05")
    end
    do -- lead_1_1_0.1
        local actual = MathCore.lead(1,1,0.1)
        check(actual,0.1,"lead_1_1_0.1")
    end
    do -- lead_1_1_0.22
        local actual = MathCore.lead(1,1,0.22)
        check(actual,0.22,"lead_1_1_0.22")
    end
    do -- lead_1_1_0.5
        local actual = MathCore.lead(1,1,0.5)
        check(actual,0.5,"lead_1_1_0.5")
    end
    do -- lead_1_8_0
        local actual = MathCore.lead(1,8,0)
        check(actual,0,"lead_1_8_0")
    end
    do -- lead_1_8_0.05
        local actual = MathCore.lead(1,8,0.05)
        check(actual,0.05,"lead_1_8_0.05")
    end
    do -- lead_1_8_0.1
        local actual = MathCore.lead(1,8,0.1)
        check(actual,0.1,"lead_1_8_0.1")
    end
    do -- lead_1_8_0.22
        local actual = MathCore.lead(1,8,0.22)
        check(actual,0.125,"lead_1_8_0.22")
    end
    do -- lead_1_8_0.5
        local actual = MathCore.lead(1,8,0.5)
        check(actual,0.125,"lead_1_8_0.5")
    end
    do -- lead_1_16_0
        local actual = MathCore.lead(1,16,0)
        check(actual,0,"lead_1_16_0")
    end
    do -- lead_1_16_0.05
        local actual = MathCore.lead(1,16,0.05)
        check(actual,0.05,"lead_1_16_0.05")
    end
    do -- lead_1_16_0.1
        local actual = MathCore.lead(1,16,0.1)
        check(actual,0.0625,"lead_1_16_0.1")
    end
    do -- lead_1_16_0.22
        local actual = MathCore.lead(1,16,0.22)
        check(actual,0.0625,"lead_1_16_0.22")
    end
    do -- lead_1_16_0.5
        local actual = MathCore.lead(1,16,0.5)
        check(actual,0.0625,"lead_1_16_0.5")
    end
    do -- lead_1_24_0
        local actual = MathCore.lead(1,24,0)
        check(actual,0,"lead_1_24_0")
    end
    do -- lead_1_24_0.05
        local actual = MathCore.lead(1,24,0.05)
        check(actual,0.041666666666666664,"lead_1_24_0.05")
    end
    do -- lead_1_24_0.1
        local actual = MathCore.lead(1,24,0.1)
        check(actual,0.041666666666666664,"lead_1_24_0.1")
    end
    do -- lead_1_24_0.22
        local actual = MathCore.lead(1,24,0.22)
        check(actual,0.041666666666666664,"lead_1_24_0.22")
    end
    do -- lead_1_24_0.5
        local actual = MathCore.lead(1,24,0.5)
        check(actual,0.041666666666666664,"lead_1_24_0.5")
    end
    do -- lead_1_60_0
        local actual = MathCore.lead(1,60,0)
        check(actual,0,"lead_1_60_0")
    end
    do -- lead_1_60_0.05
        local actual = MathCore.lead(1,60,0.05)
        check(actual,0.016666666666666666,"lead_1_60_0.05")
    end
    do -- lead_1_60_0.1
        local actual = MathCore.lead(1,60,0.1)
        check(actual,0.016666666666666666,"lead_1_60_0.1")
    end
    do -- lead_1_60_0.22
        local actual = MathCore.lead(1,60,0.22)
        check(actual,0.016666666666666666,"lead_1_60_0.22")
    end
    do -- lead_1_60_0.5
        local actual = MathCore.lead(1,60,0.5)
        check(actual,0.016666666666666666,"lead_1_60_0.5")
    end
    do -- lead_1_100_0
        local actual = MathCore.lead(1,100,0)
        check(actual,0,"lead_1_100_0")
    end
    do -- lead_1_100_0.05
        local actual = MathCore.lead(1,100,0.05)
        check(actual,0.01,"lead_1_100_0.05")
    end
    do -- lead_1_100_0.1
        local actual = MathCore.lead(1,100,0.1)
        check(actual,0.01,"lead_1_100_0.1")
    end
    do -- lead_1_100_0.22
        local actual = MathCore.lead(1,100,0.22)
        check(actual,0.01,"lead_1_100_0.22")
    end
    do -- lead_1_100_0.5
        local actual = MathCore.lead(1,100,0.5)
        check(actual,0.01,"lead_1_100_0.5")
    end
    do -- lead_3_1_0
        local actual = MathCore.lead(3,1,0)
        check(actual,0,"lead_3_1_0")
    end
    do -- lead_3_1_0.05
        local actual = MathCore.lead(3,1,0.05)
        check(actual,0.05,"lead_3_1_0.05")
    end
    do -- lead_3_1_0.1
        local actual = MathCore.lead(3,1,0.1)
        check(actual,0.1,"lead_3_1_0.1")
    end
    do -- lead_3_1_0.22
        local actual = MathCore.lead(3,1,0.22)
        check(actual,0.22,"lead_3_1_0.22")
    end
    do -- lead_3_1_0.5
        local actual = MathCore.lead(3,1,0.5)
        check(actual,0.5,"lead_3_1_0.5")
    end
    do -- lead_3_8_0
        local actual = MathCore.lead(3,8,0)
        check(actual,0,"lead_3_8_0")
    end
    do -- lead_3_8_0.05
        local actual = MathCore.lead(3,8,0.05)
        check(actual,0.05,"lead_3_8_0.05")
    end
    do -- lead_3_8_0.1
        local actual = MathCore.lead(3,8,0.1)
        check(actual,0.1,"lead_3_8_0.1")
    end
    do -- lead_3_8_0.22
        local actual = MathCore.lead(3,8,0.22)
        check(actual,0.22,"lead_3_8_0.22")
    end
    do -- lead_3_8_0.5
        local actual = MathCore.lead(3,8,0.5)
        check(actual,0.375,"lead_3_8_0.5")
    end
    do -- lead_3_16_0
        local actual = MathCore.lead(3,16,0)
        check(actual,0,"lead_3_16_0")
    end
    do -- lead_3_16_0.05
        local actual = MathCore.lead(3,16,0.05)
        check(actual,0.05,"lead_3_16_0.05")
    end
    do -- lead_3_16_0.1
        local actual = MathCore.lead(3,16,0.1)
        check(actual,0.1,"lead_3_16_0.1")
    end
    do -- lead_3_16_0.22
        local actual = MathCore.lead(3,16,0.22)
        check(actual,0.1875,"lead_3_16_0.22")
    end
    do -- lead_3_16_0.5
        local actual = MathCore.lead(3,16,0.5)
        check(actual,0.1875,"lead_3_16_0.5")
    end
    do -- lead_3_24_0
        local actual = MathCore.lead(3,24,0)
        check(actual,0,"lead_3_24_0")
    end
    do -- lead_3_24_0.05
        local actual = MathCore.lead(3,24,0.05)
        check(actual,0.05,"lead_3_24_0.05")
    end
    do -- lead_3_24_0.1
        local actual = MathCore.lead(3,24,0.1)
        check(actual,0.1,"lead_3_24_0.1")
    end
    do -- lead_3_24_0.22
        local actual = MathCore.lead(3,24,0.22)
        check(actual,0.125,"lead_3_24_0.22")
    end
    do -- lead_3_24_0.5
        local actual = MathCore.lead(3,24,0.5)
        check(actual,0.125,"lead_3_24_0.5")
    end
    do -- lead_3_60_0
        local actual = MathCore.lead(3,60,0)
        check(actual,0,"lead_3_60_0")
    end
    do -- lead_3_60_0.05
        local actual = MathCore.lead(3,60,0.05)
        check(actual,0.05,"lead_3_60_0.05")
    end
    do -- lead_3_60_0.1
        local actual = MathCore.lead(3,60,0.1)
        check(actual,0.05,"lead_3_60_0.1")
    end
    do -- lead_3_60_0.22
        local actual = MathCore.lead(3,60,0.22)
        check(actual,0.05,"lead_3_60_0.22")
    end
    do -- lead_3_60_0.5
        local actual = MathCore.lead(3,60,0.5)
        check(actual,0.05,"lead_3_60_0.5")
    end
    do -- lead_3_100_0
        local actual = MathCore.lead(3,100,0)
        check(actual,0,"lead_3_100_0")
    end
    do -- lead_3_100_0.05
        local actual = MathCore.lead(3,100,0.05)
        check(actual,0.03,"lead_3_100_0.05")
    end
    do -- lead_3_100_0.1
        local actual = MathCore.lead(3,100,0.1)
        check(actual,0.03,"lead_3_100_0.1")
    end
    do -- lead_3_100_0.22
        local actual = MathCore.lead(3,100,0.22)
        check(actual,0.03,"lead_3_100_0.22")
    end
    do -- lead_3_100_0.5
        local actual = MathCore.lead(3,100,0.5)
        check(actual,0.03,"lead_3_100_0.5")
    end
    do -- lead_7_1_0
        local actual = MathCore.lead(7,1,0)
        check(actual,0,"lead_7_1_0")
    end
    do -- lead_7_1_0.05
        local actual = MathCore.lead(7,1,0.05)
        check(actual,0.05,"lead_7_1_0.05")
    end
    do -- lead_7_1_0.1
        local actual = MathCore.lead(7,1,0.1)
        check(actual,0.1,"lead_7_1_0.1")
    end
    do -- lead_7_1_0.22
        local actual = MathCore.lead(7,1,0.22)
        check(actual,0.22,"lead_7_1_0.22")
    end
    do -- lead_7_1_0.5
        local actual = MathCore.lead(7,1,0.5)
        check(actual,0.5,"lead_7_1_0.5")
    end
    do -- lead_7_8_0
        local actual = MathCore.lead(7,8,0)
        check(actual,0,"lead_7_8_0")
    end
    do -- lead_7_8_0.05
        local actual = MathCore.lead(7,8,0.05)
        check(actual,0.05,"lead_7_8_0.05")
    end
    do -- lead_7_8_0.1
        local actual = MathCore.lead(7,8,0.1)
        check(actual,0.1,"lead_7_8_0.1")
    end
    do -- lead_7_8_0.22
        local actual = MathCore.lead(7,8,0.22)
        check(actual,0.22,"lead_7_8_0.22")
    end
    do -- lead_7_8_0.5
        local actual = MathCore.lead(7,8,0.5)
        check(actual,0.5,"lead_7_8_0.5")
    end
    do -- lead_7_16_0
        local actual = MathCore.lead(7,16,0)
        check(actual,0,"lead_7_16_0")
    end
    do -- lead_7_16_0.05
        local actual = MathCore.lead(7,16,0.05)
        check(actual,0.05,"lead_7_16_0.05")
    end
    do -- lead_7_16_0.1
        local actual = MathCore.lead(7,16,0.1)
        check(actual,0.1,"lead_7_16_0.1")
    end
    do -- lead_7_16_0.22
        local actual = MathCore.lead(7,16,0.22)
        check(actual,0.22,"lead_7_16_0.22")
    end
    do -- lead_7_16_0.5
        local actual = MathCore.lead(7,16,0.5)
        check(actual,0.4375,"lead_7_16_0.5")
    end
    do -- lead_7_24_0
        local actual = MathCore.lead(7,24,0)
        check(actual,0,"lead_7_24_0")
    end
    do -- lead_7_24_0.05
        local actual = MathCore.lead(7,24,0.05)
        check(actual,0.05,"lead_7_24_0.05")
    end
    do -- lead_7_24_0.1
        local actual = MathCore.lead(7,24,0.1)
        check(actual,0.1,"lead_7_24_0.1")
    end
    do -- lead_7_24_0.22
        local actual = MathCore.lead(7,24,0.22)
        check(actual,0.22,"lead_7_24_0.22")
    end
    do -- lead_7_24_0.5
        local actual = MathCore.lead(7,24,0.5)
        check(actual,0.2916666666666667,"lead_7_24_0.5")
    end
    do -- lead_7_60_0
        local actual = MathCore.lead(7,60,0)
        check(actual,0,"lead_7_60_0")
    end
    do -- lead_7_60_0.05
        local actual = MathCore.lead(7,60,0.05)
        check(actual,0.05,"lead_7_60_0.05")
    end
    do -- lead_7_60_0.1
        local actual = MathCore.lead(7,60,0.1)
        check(actual,0.1,"lead_7_60_0.1")
    end
    do -- lead_7_60_0.22
        local actual = MathCore.lead(7,60,0.22)
        check(actual,0.11666666666666667,"lead_7_60_0.22")
    end
    do -- lead_7_60_0.5
        local actual = MathCore.lead(7,60,0.5)
        check(actual,0.11666666666666667,"lead_7_60_0.5")
    end
    do -- lead_7_100_0
        local actual = MathCore.lead(7,100,0)
        check(actual,0,"lead_7_100_0")
    end
    do -- lead_7_100_0.05
        local actual = MathCore.lead(7,100,0.05)
        check(actual,0.05,"lead_7_100_0.05")
    end
    do -- lead_7_100_0.1
        local actual = MathCore.lead(7,100,0.1)
        check(actual,0.07,"lead_7_100_0.1")
    end
    do -- lead_7_100_0.22
        local actual = MathCore.lead(7,100,0.22)
        check(actual,0.07,"lead_7_100_0.22")
    end
    do -- lead_7_100_0.5
        local actual = MathCore.lead(7,100,0.5)
        check(actual,0.07,"lead_7_100_0.5")
    end
    do -- lead_16_1_0
        local actual = MathCore.lead(16,1,0)
        check(actual,0,"lead_16_1_0")
    end
    do -- lead_16_1_0.05
        local actual = MathCore.lead(16,1,0.05)
        check(actual,0.05,"lead_16_1_0.05")
    end
    do -- lead_16_1_0.1
        local actual = MathCore.lead(16,1,0.1)
        check(actual,0.1,"lead_16_1_0.1")
    end
    do -- lead_16_1_0.22
        local actual = MathCore.lead(16,1,0.22)
        check(actual,0.22,"lead_16_1_0.22")
    end
    do -- lead_16_1_0.5
        local actual = MathCore.lead(16,1,0.5)
        check(actual,0.5,"lead_16_1_0.5")
    end
    do -- lead_16_8_0
        local actual = MathCore.lead(16,8,0)
        check(actual,0,"lead_16_8_0")
    end
    do -- lead_16_8_0.05
        local actual = MathCore.lead(16,8,0.05)
        check(actual,0.05,"lead_16_8_0.05")
    end
    do -- lead_16_8_0.1
        local actual = MathCore.lead(16,8,0.1)
        check(actual,0.1,"lead_16_8_0.1")
    end
    do -- lead_16_8_0.22
        local actual = MathCore.lead(16,8,0.22)
        check(actual,0.22,"lead_16_8_0.22")
    end
    do -- lead_16_8_0.5
        local actual = MathCore.lead(16,8,0.5)
        check(actual,0.5,"lead_16_8_0.5")
    end
    do -- lead_16_16_0
        local actual = MathCore.lead(16,16,0)
        check(actual,0,"lead_16_16_0")
    end
    do -- lead_16_16_0.05
        local actual = MathCore.lead(16,16,0.05)
        check(actual,0.05,"lead_16_16_0.05")
    end
    do -- lead_16_16_0.1
        local actual = MathCore.lead(16,16,0.1)
        check(actual,0.1,"lead_16_16_0.1")
    end
    do -- lead_16_16_0.22
        local actual = MathCore.lead(16,16,0.22)
        check(actual,0.22,"lead_16_16_0.22")
    end
    do -- lead_16_16_0.5
        local actual = MathCore.lead(16,16,0.5)
        check(actual,0.5,"lead_16_16_0.5")
    end
    do -- lead_16_24_0
        local actual = MathCore.lead(16,24,0)
        check(actual,0,"lead_16_24_0")
    end
    do -- lead_16_24_0.05
        local actual = MathCore.lead(16,24,0.05)
        check(actual,0.05,"lead_16_24_0.05")
    end
    do -- lead_16_24_0.1
        local actual = MathCore.lead(16,24,0.1)
        check(actual,0.1,"lead_16_24_0.1")
    end
    do -- lead_16_24_0.22
        local actual = MathCore.lead(16,24,0.22)
        check(actual,0.22,"lead_16_24_0.22")
    end
    do -- lead_16_24_0.5
        local actual = MathCore.lead(16,24,0.5)
        check(actual,0.5,"lead_16_24_0.5")
    end
    do -- lead_16_60_0
        local actual = MathCore.lead(16,60,0)
        check(actual,0,"lead_16_60_0")
    end
    do -- lead_16_60_0.05
        local actual = MathCore.lead(16,60,0.05)
        check(actual,0.05,"lead_16_60_0.05")
    end
    do -- lead_16_60_0.1
        local actual = MathCore.lead(16,60,0.1)
        check(actual,0.1,"lead_16_60_0.1")
    end
    do -- lead_16_60_0.22
        local actual = MathCore.lead(16,60,0.22)
        check(actual,0.22,"lead_16_60_0.22")
    end
    do -- lead_16_60_0.5
        local actual = MathCore.lead(16,60,0.5)
        check(actual,0.26666666666666666,"lead_16_60_0.5")
    end
    do -- lead_16_100_0
        local actual = MathCore.lead(16,100,0)
        check(actual,0,"lead_16_100_0")
    end
    do -- lead_16_100_0.05
        local actual = MathCore.lead(16,100,0.05)
        check(actual,0.05,"lead_16_100_0.05")
    end
    do -- lead_16_100_0.1
        local actual = MathCore.lead(16,100,0.1)
        check(actual,0.1,"lead_16_100_0.1")
    end
    do -- lead_16_100_0.22
        local actual = MathCore.lead(16,100,0.22)
        check(actual,0.16,"lead_16_100_0.22")
    end
    do -- lead_16_100_0.5
        local actual = MathCore.lead(16,100,0.5)
        check(actual,0.16,"lead_16_100_0.5")
    end
    do -- lead_45_1_0
        local actual = MathCore.lead(45,1,0)
        check(actual,0,"lead_45_1_0")
    end
    do -- lead_45_1_0.05
        local actual = MathCore.lead(45,1,0.05)
        check(actual,0.05,"lead_45_1_0.05")
    end
    do -- lead_45_1_0.1
        local actual = MathCore.lead(45,1,0.1)
        check(actual,0.1,"lead_45_1_0.1")
    end
    do -- lead_45_1_0.22
        local actual = MathCore.lead(45,1,0.22)
        check(actual,0.22,"lead_45_1_0.22")
    end
    do -- lead_45_1_0.5
        local actual = MathCore.lead(45,1,0.5)
        check(actual,0.5,"lead_45_1_0.5")
    end
    do -- lead_45_8_0
        local actual = MathCore.lead(45,8,0)
        check(actual,0,"lead_45_8_0")
    end
    do -- lead_45_8_0.05
        local actual = MathCore.lead(45,8,0.05)
        check(actual,0.05,"lead_45_8_0.05")
    end
    do -- lead_45_8_0.1
        local actual = MathCore.lead(45,8,0.1)
        check(actual,0.1,"lead_45_8_0.1")
    end
    do -- lead_45_8_0.22
        local actual = MathCore.lead(45,8,0.22)
        check(actual,0.22,"lead_45_8_0.22")
    end
    do -- lead_45_8_0.5
        local actual = MathCore.lead(45,8,0.5)
        check(actual,0.5,"lead_45_8_0.5")
    end
    do -- lead_45_16_0
        local actual = MathCore.lead(45,16,0)
        check(actual,0,"lead_45_16_0")
    end
    do -- lead_45_16_0.05
        local actual = MathCore.lead(45,16,0.05)
        check(actual,0.05,"lead_45_16_0.05")
    end
    do -- lead_45_16_0.1
        local actual = MathCore.lead(45,16,0.1)
        check(actual,0.1,"lead_45_16_0.1")
    end
    do -- lead_45_16_0.22
        local actual = MathCore.lead(45,16,0.22)
        check(actual,0.22,"lead_45_16_0.22")
    end
    do -- lead_45_16_0.5
        local actual = MathCore.lead(45,16,0.5)
        check(actual,0.5,"lead_45_16_0.5")
    end
    do -- lead_45_24_0
        local actual = MathCore.lead(45,24,0)
        check(actual,0,"lead_45_24_0")
    end
    do -- lead_45_24_0.05
        local actual = MathCore.lead(45,24,0.05)
        check(actual,0.05,"lead_45_24_0.05")
    end
    do -- lead_45_24_0.1
        local actual = MathCore.lead(45,24,0.1)
        check(actual,0.1,"lead_45_24_0.1")
    end
    do -- lead_45_24_0.22
        local actual = MathCore.lead(45,24,0.22)
        check(actual,0.22,"lead_45_24_0.22")
    end
    do -- lead_45_24_0.5
        local actual = MathCore.lead(45,24,0.5)
        check(actual,0.5,"lead_45_24_0.5")
    end
    do -- lead_45_60_0
        local actual = MathCore.lead(45,60,0)
        check(actual,0,"lead_45_60_0")
    end
    do -- lead_45_60_0.05
        local actual = MathCore.lead(45,60,0.05)
        check(actual,0.05,"lead_45_60_0.05")
    end
    do -- lead_45_60_0.1
        local actual = MathCore.lead(45,60,0.1)
        check(actual,0.1,"lead_45_60_0.1")
    end
    do -- lead_45_60_0.22
        local actual = MathCore.lead(45,60,0.22)
        check(actual,0.22,"lead_45_60_0.22")
    end
    do -- lead_45_60_0.5
        local actual = MathCore.lead(45,60,0.5)
        check(actual,0.5,"lead_45_60_0.5")
    end
    do -- lead_45_100_0
        local actual = MathCore.lead(45,100,0)
        check(actual,0,"lead_45_100_0")
    end
    do -- lead_45_100_0.05
        local actual = MathCore.lead(45,100,0.05)
        check(actual,0.05,"lead_45_100_0.05")
    end
    do -- lead_45_100_0.1
        local actual = MathCore.lead(45,100,0.1)
        check(actual,0.1,"lead_45_100_0.1")
    end
    do -- lead_45_100_0.22
        local actual = MathCore.lead(45,100,0.22)
        check(actual,0.22,"lead_45_100_0.22")
    end
    do -- lead_45_100_0.5
        local actual = MathCore.lead(45,100,0.5)
        check(actual,0.45,"lead_45_100_0.5")
    end
    do -- lead_90_1_0
        local actual = MathCore.lead(90,1,0)
        check(actual,0,"lead_90_1_0")
    end
    do -- lead_90_1_0.05
        local actual = MathCore.lead(90,1,0.05)
        check(actual,0.05,"lead_90_1_0.05")
    end
    do -- lead_90_1_0.1
        local actual = MathCore.lead(90,1,0.1)
        check(actual,0.1,"lead_90_1_0.1")
    end
    do -- lead_90_1_0.22
        local actual = MathCore.lead(90,1,0.22)
        check(actual,0.22,"lead_90_1_0.22")
    end
    do -- lead_90_1_0.5
        local actual = MathCore.lead(90,1,0.5)
        check(actual,0.5,"lead_90_1_0.5")
    end
    do -- lead_90_8_0
        local actual = MathCore.lead(90,8,0)
        check(actual,0,"lead_90_8_0")
    end
    do -- lead_90_8_0.05
        local actual = MathCore.lead(90,8,0.05)
        check(actual,0.05,"lead_90_8_0.05")
    end
    do -- lead_90_8_0.1
        local actual = MathCore.lead(90,8,0.1)
        check(actual,0.1,"lead_90_8_0.1")
    end
    do -- lead_90_8_0.22
        local actual = MathCore.lead(90,8,0.22)
        check(actual,0.22,"lead_90_8_0.22")
    end
    do -- lead_90_8_0.5
        local actual = MathCore.lead(90,8,0.5)
        check(actual,0.5,"lead_90_8_0.5")
    end
    do -- lead_90_16_0
        local actual = MathCore.lead(90,16,0)
        check(actual,0,"lead_90_16_0")
    end
    do -- lead_90_16_0.05
        local actual = MathCore.lead(90,16,0.05)
        check(actual,0.05,"lead_90_16_0.05")
    end
    do -- lead_90_16_0.1
        local actual = MathCore.lead(90,16,0.1)
        check(actual,0.1,"lead_90_16_0.1")
    end
    do -- lead_90_16_0.22
        local actual = MathCore.lead(90,16,0.22)
        check(actual,0.22,"lead_90_16_0.22")
    end
    do -- lead_90_16_0.5
        local actual = MathCore.lead(90,16,0.5)
        check(actual,0.5,"lead_90_16_0.5")
    end
    do -- lead_90_24_0
        local actual = MathCore.lead(90,24,0)
        check(actual,0,"lead_90_24_0")
    end
    do -- lead_90_24_0.05
        local actual = MathCore.lead(90,24,0.05)
        check(actual,0.05,"lead_90_24_0.05")
    end
    do -- lead_90_24_0.1
        local actual = MathCore.lead(90,24,0.1)
        check(actual,0.1,"lead_90_24_0.1")
    end
    do -- lead_90_24_0.22
        local actual = MathCore.lead(90,24,0.22)
        check(actual,0.22,"lead_90_24_0.22")
    end
    do -- lead_90_24_0.5
        local actual = MathCore.lead(90,24,0.5)
        check(actual,0.5,"lead_90_24_0.5")
    end
    do -- lead_90_60_0
        local actual = MathCore.lead(90,60,0)
        check(actual,0,"lead_90_60_0")
    end
    do -- lead_90_60_0.05
        local actual = MathCore.lead(90,60,0.05)
        check(actual,0.05,"lead_90_60_0.05")
    end
    do -- lead_90_60_0.1
        local actual = MathCore.lead(90,60,0.1)
        check(actual,0.1,"lead_90_60_0.1")
    end
    do -- lead_90_60_0.22
        local actual = MathCore.lead(90,60,0.22)
        check(actual,0.22,"lead_90_60_0.22")
    end
    do -- lead_90_60_0.5
        local actual = MathCore.lead(90,60,0.5)
        check(actual,0.5,"lead_90_60_0.5")
    end
    do -- lead_90_100_0
        local actual = MathCore.lead(90,100,0)
        check(actual,0,"lead_90_100_0")
    end
    do -- lead_90_100_0.05
        local actual = MathCore.lead(90,100,0.05)
        check(actual,0.05,"lead_90_100_0.05")
    end
    do -- lead_90_100_0.1
        local actual = MathCore.lead(90,100,0.1)
        check(actual,0.1,"lead_90_100_0.1")
    end
    do -- lead_90_100_0.22
        local actual = MathCore.lead(90,100,0.22)
        check(actual,0.22,"lead_90_100_0.22")
    end
    do -- lead_90_100_0.5
        local actual = MathCore.lead(90,100,0.5)
        check(actual,0.5,"lead_90_100_0.5")
    end
    do -- lead_300_1_0
        local actual = MathCore.lead(300,1,0)
        check(actual,0,"lead_300_1_0")
    end
    do -- lead_300_1_0.05
        local actual = MathCore.lead(300,1,0.05)
        check(actual,0.05,"lead_300_1_0.05")
    end
    do -- lead_300_1_0.1
        local actual = MathCore.lead(300,1,0.1)
        check(actual,0.1,"lead_300_1_0.1")
    end
    do -- lead_300_1_0.22
        local actual = MathCore.lead(300,1,0.22)
        check(actual,0.22,"lead_300_1_0.22")
    end
    do -- lead_300_1_0.5
        local actual = MathCore.lead(300,1,0.5)
        check(actual,0.5,"lead_300_1_0.5")
    end
    do -- lead_300_8_0
        local actual = MathCore.lead(300,8,0)
        check(actual,0,"lead_300_8_0")
    end
    do -- lead_300_8_0.05
        local actual = MathCore.lead(300,8,0.05)
        check(actual,0.05,"lead_300_8_0.05")
    end
    do -- lead_300_8_0.1
        local actual = MathCore.lead(300,8,0.1)
        check(actual,0.1,"lead_300_8_0.1")
    end
    do -- lead_300_8_0.22
        local actual = MathCore.lead(300,8,0.22)
        check(actual,0.22,"lead_300_8_0.22")
    end
    do -- lead_300_8_0.5
        local actual = MathCore.lead(300,8,0.5)
        check(actual,0.5,"lead_300_8_0.5")
    end
    do -- lead_300_16_0
        local actual = MathCore.lead(300,16,0)
        check(actual,0,"lead_300_16_0")
    end
    do -- lead_300_16_0.05
        local actual = MathCore.lead(300,16,0.05)
        check(actual,0.05,"lead_300_16_0.05")
    end
    do -- lead_300_16_0.1
        local actual = MathCore.lead(300,16,0.1)
        check(actual,0.1,"lead_300_16_0.1")
    end
    do -- lead_300_16_0.22
        local actual = MathCore.lead(300,16,0.22)
        check(actual,0.22,"lead_300_16_0.22")
    end
    do -- lead_300_16_0.5
        local actual = MathCore.lead(300,16,0.5)
        check(actual,0.5,"lead_300_16_0.5")
    end
    do -- lead_300_24_0
        local actual = MathCore.lead(300,24,0)
        check(actual,0,"lead_300_24_0")
    end
    do -- lead_300_24_0.05
        local actual = MathCore.lead(300,24,0.05)
        check(actual,0.05,"lead_300_24_0.05")
    end
    do -- lead_300_24_0.1
        local actual = MathCore.lead(300,24,0.1)
        check(actual,0.1,"lead_300_24_0.1")
    end
    do -- lead_300_24_0.22
        local actual = MathCore.lead(300,24,0.22)
        check(actual,0.22,"lead_300_24_0.22")
    end
    do -- lead_300_24_0.5
        local actual = MathCore.lead(300,24,0.5)
        check(actual,0.5,"lead_300_24_0.5")
    end
    do -- lead_300_60_0
        local actual = MathCore.lead(300,60,0)
        check(actual,0,"lead_300_60_0")
    end
    do -- lead_300_60_0.05
        local actual = MathCore.lead(300,60,0.05)
        check(actual,0.05,"lead_300_60_0.05")
    end
    do -- lead_300_60_0.1
        local actual = MathCore.lead(300,60,0.1)
        check(actual,0.1,"lead_300_60_0.1")
    end
    do -- lead_300_60_0.22
        local actual = MathCore.lead(300,60,0.22)
        check(actual,0.22,"lead_300_60_0.22")
    end
    do -- lead_300_60_0.5
        local actual = MathCore.lead(300,60,0.5)
        check(actual,0.5,"lead_300_60_0.5")
    end
    do -- lead_300_100_0
        local actual = MathCore.lead(300,100,0)
        check(actual,0,"lead_300_100_0")
    end
    do -- lead_300_100_0.05
        local actual = MathCore.lead(300,100,0.05)
        check(actual,0.05,"lead_300_100_0.05")
    end
    do -- lead_300_100_0.1
        local actual = MathCore.lead(300,100,0.1)
        check(actual,0.1,"lead_300_100_0.1")
    end
    do -- lead_300_100_0.22
        local actual = MathCore.lead(300,100,0.22)
        check(actual,0.22,"lead_300_100_0.22")
    end
    do -- lead_300_100_0.5
        local actual = MathCore.lead(300,100,0.5)
        check(actual,0.5,"lead_300_100_0.5")
    end
    do -- lead_1200_1_0
        local actual = MathCore.lead(1200,1,0)
        check(actual,0,"lead_1200_1_0")
    end
    do -- lead_1200_1_0.05
        local actual = MathCore.lead(1200,1,0.05)
        check(actual,0.05,"lead_1200_1_0.05")
    end
    do -- lead_1200_1_0.1
        local actual = MathCore.lead(1200,1,0.1)
        check(actual,0.1,"lead_1200_1_0.1")
    end
    do -- lead_1200_1_0.22
        local actual = MathCore.lead(1200,1,0.22)
        check(actual,0.22,"lead_1200_1_0.22")
    end
    do -- lead_1200_1_0.5
        local actual = MathCore.lead(1200,1,0.5)
        check(actual,0.5,"lead_1200_1_0.5")
    end
    do -- lead_1200_8_0
        local actual = MathCore.lead(1200,8,0)
        check(actual,0,"lead_1200_8_0")
    end
    do -- lead_1200_8_0.05
        local actual = MathCore.lead(1200,8,0.05)
        check(actual,0.05,"lead_1200_8_0.05")
    end
    do -- lead_1200_8_0.1
        local actual = MathCore.lead(1200,8,0.1)
        check(actual,0.1,"lead_1200_8_0.1")
    end
    do -- lead_1200_8_0.22
        local actual = MathCore.lead(1200,8,0.22)
        check(actual,0.22,"lead_1200_8_0.22")
    end
    do -- lead_1200_8_0.5
        local actual = MathCore.lead(1200,8,0.5)
        check(actual,0.5,"lead_1200_8_0.5")
    end
    do -- lead_1200_16_0
        local actual = MathCore.lead(1200,16,0)
        check(actual,0,"lead_1200_16_0")
    end
    do -- lead_1200_16_0.05
        local actual = MathCore.lead(1200,16,0.05)
        check(actual,0.05,"lead_1200_16_0.05")
    end
    do -- lead_1200_16_0.1
        local actual = MathCore.lead(1200,16,0.1)
        check(actual,0.1,"lead_1200_16_0.1")
    end
    do -- lead_1200_16_0.22
        local actual = MathCore.lead(1200,16,0.22)
        check(actual,0.22,"lead_1200_16_0.22")
    end
    do -- lead_1200_16_0.5
        local actual = MathCore.lead(1200,16,0.5)
        check(actual,0.5,"lead_1200_16_0.5")
    end
    do -- lead_1200_24_0
        local actual = MathCore.lead(1200,24,0)
        check(actual,0,"lead_1200_24_0")
    end
    do -- lead_1200_24_0.05
        local actual = MathCore.lead(1200,24,0.05)
        check(actual,0.05,"lead_1200_24_0.05")
    end
    do -- lead_1200_24_0.1
        local actual = MathCore.lead(1200,24,0.1)
        check(actual,0.1,"lead_1200_24_0.1")
    end
    do -- lead_1200_24_0.22
        local actual = MathCore.lead(1200,24,0.22)
        check(actual,0.22,"lead_1200_24_0.22")
    end
    do -- lead_1200_24_0.5
        local actual = MathCore.lead(1200,24,0.5)
        check(actual,0.5,"lead_1200_24_0.5")
    end
    do -- lead_1200_60_0
        local actual = MathCore.lead(1200,60,0)
        check(actual,0,"lead_1200_60_0")
    end
    do -- lead_1200_60_0.05
        local actual = MathCore.lead(1200,60,0.05)
        check(actual,0.05,"lead_1200_60_0.05")
    end
    do -- lead_1200_60_0.1
        local actual = MathCore.lead(1200,60,0.1)
        check(actual,0.1,"lead_1200_60_0.1")
    end
    do -- lead_1200_60_0.22
        local actual = MathCore.lead(1200,60,0.22)
        check(actual,0.22,"lead_1200_60_0.22")
    end
    do -- lead_1200_60_0.5
        local actual = MathCore.lead(1200,60,0.5)
        check(actual,0.5,"lead_1200_60_0.5")
    end
    do -- lead_1200_100_0
        local actual = MathCore.lead(1200,100,0)
        check(actual,0,"lead_1200_100_0")
    end
    do -- lead_1200_100_0.05
        local actual = MathCore.lead(1200,100,0.05)
        check(actual,0.05,"lead_1200_100_0.05")
    end
    do -- lead_1200_100_0.1
        local actual = MathCore.lead(1200,100,0.1)
        check(actual,0.1,"lead_1200_100_0.1")
    end
    do -- lead_1200_100_0.22
        local actual = MathCore.lead(1200,100,0.22)
        check(actual,0.22,"lead_1200_100_0.22")
    end
    do -- lead_1200_100_0.5
        local actual = MathCore.lead(1200,100,0.5)
        check(actual,0.5,"lead_1200_100_0.5")
    end
    do -- alpha_0_0.03
        local actual = MathCore.alpha(0,0.03)
        check(actual,0.0,"alpha_0_0.03")
    end
    do -- alpha_0_0.08
        local actual = MathCore.alpha(0,0.08)
        check(actual,0.0,"alpha_0_0.08")
    end
    do -- alpha_0_0.18
        local actual = MathCore.alpha(0,0.18)
        check(actual,0.0,"alpha_0_0.18")
    end
    do -- alpha_0_0.3
        local actual = MathCore.alpha(0,0.3)
        check(actual,0.0,"alpha_0_0.3")
    end
    do -- alpha_0_0.6
        local actual = MathCore.alpha(0,0.6)
        check(actual,0.0,"alpha_0_0.6")
    end
    do -- alpha_0_1
        local actual = MathCore.alpha(0,1)
        check(actual,0.0,"alpha_0_1")
    end
    do -- alpha_0.01_0.03
        local actual = MathCore.alpha(0.01,0.03)
        check(actual,0.28346868942621073,"alpha_0.01_0.03")
    end
    do -- alpha_0.01_0.08
        local actual = MathCore.alpha(0.01,0.08)
        check(actual,0.11750309741540454,"alpha_0.01_0.08")
    end
    do -- alpha_0.01_0.18
        local actual = MathCore.alpha(0.01,0.18)
        check(actual,0.05404053109323459,"alpha_0.01_0.18")
    end
    do -- alpha_0.01_0.3
        local actual = MathCore.alpha(0.01,0.3)
        check(actual,0.0327838995179941,"alpha_0.01_0.3")
    end
    do -- alpha_0.01_0.6
        local actual = MathCore.alpha(0.01,0.6)
        check(actual,0.01652854617838251,"alpha_0.01_0.6")
    end
    do -- alpha_0.01_1
        local actual = MathCore.alpha(0.01,1)
        check(actual,0.009950166250831893,"alpha_0.01_1")
    end
    do -- alpha_0.025_0.03
        local actual = MathCore.alpha(0.025,0.03)
        check(actual,0.5654017914929218,"alpha_0.025_0.03")
    end
    do -- alpha_0.025_0.08
        local actual = MathCore.alpha(0.025,0.08)
        check(actual,0.2683843710533582,"alpha_0.025_0.08")
    end
    do -- alpha_0.025_0.18
        local actual = MathCore.alpha(0.025,0.18)
        check(actual,0.1296752741666095,"alpha_0.025_0.18")
    end
    do -- alpha_0.025_0.3
        local actual = MathCore.alpha(0.025,0.3)
        check(actual,0.07995558537067671,"alpha_0.025_0.3")
    end
    do -- alpha_0.025_0.6
        local actual = MathCore.alpha(0.025,0.6)
        check(actual,0.040810542890861834,"alpha_0.025_0.6")
    end
    do -- alpha_0.025_1
        local actual = MathCore.alpha(0.025,1)
        check(actual,0.024690087971667385,"alpha_0.025_1")
    end
    do -- alpha_0.05_0.03
        local actual = MathCore.alpha(0.05,0.03)
        check(actual,0.8111243971624382,"alpha_0.05_0.03")
    end
    do -- alpha_0.05_0.08
        local actual = MathCore.alpha(0.05,0.08)
        check(actual,0.4647385714810097,"alpha_0.05_0.08")
    end
    do -- alpha_0.05_0.18
        local actual = MathCore.alpha(0.05,0.18)
        check(actual,0.24253487160303355,"alpha_0.05_0.18")
    end
    do -- alpha_0.05_0.3
        local actual = MathCore.alpha(0.05,0.3)
        check(actual,0.15351827510938598,"alpha_0.05_0.3")
    end
    do -- alpha_0.05_0.6
        local actual = MathCore.alpha(0.05,0.6)
        check(actual,0.07995558537067671,"alpha_0.05_0.6")
    end
    do -- alpha_0.05_1
        local actual = MathCore.alpha(0.05,1)
        check(actual,0.048770575499285984,"alpha_0.05_1")
    end
    do -- alpha_0.1_0.03
        local actual = MathCore.alpha(0.1,0.03)
        check(actual,0.9643260066527476,"alpha_0.1_0.03")
    end
    do -- alpha_0.1_0.08
        local actual = MathCore.alpha(0.1,0.08)
        check(actual,0.7134952031398099,"alpha_0.1_0.08")
    end
    do -- alpha_0.1_0.18
        local actual = MathCore.alpha(0.1,0.18)
        check(actual,0.42624657926256726,"alpha_0.1_0.18")
    end
    do -- alpha_0.1_0.3
        local actual = MathCore.alpha(0.1,0.3)
        check(actual,0.28346868942621073,"alpha_0.1_0.3")
    end
    do -- alpha_0.1_0.6
        local actual = MathCore.alpha(0.1,0.6)
        check(actual,0.15351827510938598,"alpha_0.1_0.6")
    end
    do -- alpha_0.1_1
        local actual = MathCore.alpha(0.1,1)
        check(actual,0.09516258196404048,"alpha_0.1_1")
    end
    do -- alpha_0.2_0.03
        local actual = MathCore.alpha(0.2,0.03)
        check(actual,0.9987273661986602,"alpha_0.2_0.03")
    end
    do -- alpha_0.2_0.08
        local actual = MathCore.alpha(0.2,0.08)
        check(actual,0.9179150013761012,"alpha_0.2_0.08")
    end
    do -- alpha_0.2_0.18
        local actual = MathCore.alpha(0.2,0.18)
        check(actual,0.6708070121920944,"alpha_0.2_0.18")
    end
    do -- alpha_0.2_0.3
        local actual = MathCore.alpha(0.2,0.3)
        check(actual,0.486582880967408,"alpha_0.2_0.3")
    end
    do -- alpha_0.2_0.6
        local actual = MathCore.alpha(0.2,0.6)
        check(actual,0.28346868942621073,"alpha_0.2_0.6")
    end
    do -- alpha_0.2_1
        local actual = MathCore.alpha(0.2,1)
        check(actual,0.18126924692201818,"alpha_0.2_1")
    end
    do -- alpha_0.5_0.03
        local actual = MathCore.alpha(0.5,0.03)
        check(actual,0.9999999422225148,"alpha_0.5_0.03")
    end
    do -- alpha_0.5_0.08
        local actual = MathCore.alpha(0.5,0.08)
        check(actual,0.9980695458637723,"alpha_0.5_0.08")
    end
    do -- alpha_0.5_0.18
        local actual = MathCore.alpha(0.5,0.18)
        check(actual,0.9378234759778836,"alpha_0.5_0.18")
    end
    do -- alpha_0.5_0.3
        local actual = MathCore.alpha(0.5,0.3)
        check(actual,0.8111243971624382,"alpha_0.5_0.3")
    end
    do -- alpha_0.5_0.6
        local actual = MathCore.alpha(0.5,0.6)
        check(actual,0.5654017914929218,"alpha_0.5_0.6")
    end
    do -- alpha_0.5_1
        local actual = MathCore.alpha(0.5,1)
        check(actual,0.3934693402873666,"alpha_0.5_1")
    end
    do -- alpha_1_0.03
        local actual = MathCore.alpha(1,0.03)
        check(actual,0.9999999999999967,"alpha_1_0.03")
    end
    do -- alpha_1_0.08
        local actual = MathCore.alpha(1,0.08)
        check(actual,0.999996273346828,"alpha_1_0.08")
    end
    do -- alpha_1_0.18
        local actual = MathCore.alpha(1,0.18)
        check(actual,0.9961340798605272,"alpha_1_0.18")
    end
    do -- alpha_1_0.3
        local actual = MathCore.alpha(1,0.3)
        check(actual,0.9643260066527476,"alpha_1_0.3")
    end
    do -- alpha_1_0.6
        local actual = MathCore.alpha(1,0.6)
        check(actual,0.8111243971624382,"alpha_1_0.6")
    end
    do -- alpha_1_1
        local actual = MathCore.alpha(1,1)
        check(actual,0.6321205588285577,"alpha_1_1")
    end
    do -- alpha_2_0.03
        local actual = MathCore.alpha(2,0.03)
        check(actual,1.0,"alpha_2_0.03")
    end
    do -- alpha_2_0.08
        local actual = MathCore.alpha(2,0.08)
        check(actual,0.9999999999861121,"alpha_2_0.08")
    end
    do -- alpha_2_0.18
        local actual = MathCore.alpha(2,0.18)
        check(actual,0.9999850546614752,"alpha_2_0.18")
    end
    do -- alpha_2_0.3
        local actual = MathCore.alpha(2,0.3)
        check(actual,0.9987273661986602,"alpha_2_0.3")
    end
    do -- alpha_2_0.6
        local actual = MathCore.alpha(2,0.6)
        check(actual,0.9643260066527476,"alpha_2_0.6")
    end
    do -- alpha_2_1
        local actual = MathCore.alpha(2,1)
        check(actual,0.8646647167633873,"alpha_2_1")
    end
    do -- backoff_0.1_0_2
        local actual = MathCore.cooldown(0.1,0,2)
        check(actual,0.1,"backoff_0.1_0_2")
    end
    do -- backoff_0.1_0_10
        local actual = MathCore.cooldown(0.1,0,10)
        check(actual,0.1,"backoff_0.1_0_10")
    end
    do -- backoff_0.1_0_30
        local actual = MathCore.cooldown(0.1,0,30)
        check(actual,0.1,"backoff_0.1_0_30")
    end
    do -- backoff_0.1_1_2
        local actual = MathCore.cooldown(0.1,1,2)
        check(actual,0.2,"backoff_0.1_1_2")
    end
    do -- backoff_0.1_1_10
        local actual = MathCore.cooldown(0.1,1,10)
        check(actual,0.2,"backoff_0.1_1_10")
    end
    do -- backoff_0.1_1_30
        local actual = MathCore.cooldown(0.1,1,30)
        check(actual,0.2,"backoff_0.1_1_30")
    end
    do -- backoff_0.1_2_2
        local actual = MathCore.cooldown(0.1,2,2)
        check(actual,0.4,"backoff_0.1_2_2")
    end
    do -- backoff_0.1_2_10
        local actual = MathCore.cooldown(0.1,2,10)
        check(actual,0.4,"backoff_0.1_2_10")
    end
    do -- backoff_0.1_2_30
        local actual = MathCore.cooldown(0.1,2,30)
        check(actual,0.4,"backoff_0.1_2_30")
    end
    do -- backoff_0.1_3_2
        local actual = MathCore.cooldown(0.1,3,2)
        check(actual,0.8,"backoff_0.1_3_2")
    end
    do -- backoff_0.1_3_10
        local actual = MathCore.cooldown(0.1,3,10)
        check(actual,0.8,"backoff_0.1_3_10")
    end
    do -- backoff_0.1_3_30
        local actual = MathCore.cooldown(0.1,3,30)
        check(actual,0.8,"backoff_0.1_3_30")
    end
    do -- backoff_0.1_4_2
        local actual = MathCore.cooldown(0.1,4,2)
        check(actual,1.6,"backoff_0.1_4_2")
    end
    do -- backoff_0.1_4_10
        local actual = MathCore.cooldown(0.1,4,10)
        check(actual,1.6,"backoff_0.1_4_10")
    end
    do -- backoff_0.1_4_30
        local actual = MathCore.cooldown(0.1,4,30)
        check(actual,1.6,"backoff_0.1_4_30")
    end
    do -- backoff_0.1_5_2
        local actual = MathCore.cooldown(0.1,5,2)
        check(actual,2,"backoff_0.1_5_2")
    end
    do -- backoff_0.1_5_10
        local actual = MathCore.cooldown(0.1,5,10)
        check(actual,3.2,"backoff_0.1_5_10")
    end
    do -- backoff_0.1_5_30
        local actual = MathCore.cooldown(0.1,5,30)
        check(actual,3.2,"backoff_0.1_5_30")
    end
    do -- backoff_0.1_10_2
        local actual = MathCore.cooldown(0.1,10,2)
        check(actual,2,"backoff_0.1_10_2")
    end
    do -- backoff_0.1_10_10
        local actual = MathCore.cooldown(0.1,10,10)
        check(actual,10,"backoff_0.1_10_10")
    end
    do -- backoff_0.1_10_30
        local actual = MathCore.cooldown(0.1,10,30)
        check(actual,30,"backoff_0.1_10_30")
    end
    do -- backoff_0.1_15_2
        local actual = MathCore.cooldown(0.1,15,2)
        check(actual,2,"backoff_0.1_15_2")
    end
    do -- backoff_0.1_15_10
        local actual = MathCore.cooldown(0.1,15,10)
        check(actual,10,"backoff_0.1_15_10")
    end
    do -- backoff_0.1_15_30
        local actual = MathCore.cooldown(0.1,15,30)
        check(actual,30,"backoff_0.1_15_30")
    end
    do -- backoff_0.5_0_2
        local actual = MathCore.cooldown(0.5,0,2)
        check(actual,0.5,"backoff_0.5_0_2")
    end
    do -- backoff_0.5_0_10
        local actual = MathCore.cooldown(0.5,0,10)
        check(actual,0.5,"backoff_0.5_0_10")
    end
    do -- backoff_0.5_0_30
        local actual = MathCore.cooldown(0.5,0,30)
        check(actual,0.5,"backoff_0.5_0_30")
    end
    do -- backoff_0.5_1_2
        local actual = MathCore.cooldown(0.5,1,2)
        check(actual,1.0,"backoff_0.5_1_2")
    end
    do -- backoff_0.5_1_10
        local actual = MathCore.cooldown(0.5,1,10)
        check(actual,1.0,"backoff_0.5_1_10")
    end
    do -- backoff_0.5_1_30
        local actual = MathCore.cooldown(0.5,1,30)
        check(actual,1.0,"backoff_0.5_1_30")
    end
    do -- backoff_0.5_2_2
        local actual = MathCore.cooldown(0.5,2,2)
        check(actual,2,"backoff_0.5_2_2")
    end
    do -- backoff_0.5_2_10
        local actual = MathCore.cooldown(0.5,2,10)
        check(actual,2.0,"backoff_0.5_2_10")
    end
    do -- backoff_0.5_2_30
        local actual = MathCore.cooldown(0.5,2,30)
        check(actual,2.0,"backoff_0.5_2_30")
    end
    do -- backoff_0.5_3_2
        local actual = MathCore.cooldown(0.5,3,2)
        check(actual,2,"backoff_0.5_3_2")
    end
    do -- backoff_0.5_3_10
        local actual = MathCore.cooldown(0.5,3,10)
        check(actual,4.0,"backoff_0.5_3_10")
    end
    do -- backoff_0.5_3_30
        local actual = MathCore.cooldown(0.5,3,30)
        check(actual,4.0,"backoff_0.5_3_30")
    end
    do -- backoff_0.5_4_2
        local actual = MathCore.cooldown(0.5,4,2)
        check(actual,2,"backoff_0.5_4_2")
    end
    do -- backoff_0.5_4_10
        local actual = MathCore.cooldown(0.5,4,10)
        check(actual,8.0,"backoff_0.5_4_10")
    end
    do -- backoff_0.5_4_30
        local actual = MathCore.cooldown(0.5,4,30)
        check(actual,8.0,"backoff_0.5_4_30")
    end
    do -- backoff_0.5_5_2
        local actual = MathCore.cooldown(0.5,5,2)
        check(actual,2,"backoff_0.5_5_2")
    end
    do -- backoff_0.5_5_10
        local actual = MathCore.cooldown(0.5,5,10)
        check(actual,10,"backoff_0.5_5_10")
    end
    do -- backoff_0.5_5_30
        local actual = MathCore.cooldown(0.5,5,30)
        check(actual,16.0,"backoff_0.5_5_30")
    end
    do -- backoff_0.5_10_2
        local actual = MathCore.cooldown(0.5,10,2)
        check(actual,2,"backoff_0.5_10_2")
    end
    do -- backoff_0.5_10_10
        local actual = MathCore.cooldown(0.5,10,10)
        check(actual,10,"backoff_0.5_10_10")
    end
    do -- backoff_0.5_10_30
        local actual = MathCore.cooldown(0.5,10,30)
        check(actual,30,"backoff_0.5_10_30")
    end
    do -- backoff_0.5_15_2
        local actual = MathCore.cooldown(0.5,15,2)
        check(actual,2,"backoff_0.5_15_2")
    end
    do -- backoff_0.5_15_10
        local actual = MathCore.cooldown(0.5,15,10)
        check(actual,10,"backoff_0.5_15_10")
    end
    do -- backoff_0.5_15_30
        local actual = MathCore.cooldown(0.5,15,30)
        check(actual,30,"backoff_0.5_15_30")
    end
    do -- backoff_1_0_2
        local actual = MathCore.cooldown(1,0,2)
        check(actual,1,"backoff_1_0_2")
    end
    do -- backoff_1_0_10
        local actual = MathCore.cooldown(1,0,10)
        check(actual,1,"backoff_1_0_10")
    end
    do -- backoff_1_0_30
        local actual = MathCore.cooldown(1,0,30)
        check(actual,1,"backoff_1_0_30")
    end
    do -- backoff_1_1_2
        local actual = MathCore.cooldown(1,1,2)
        check(actual,2,"backoff_1_1_2")
    end
    do -- backoff_1_1_10
        local actual = MathCore.cooldown(1,1,10)
        check(actual,2,"backoff_1_1_10")
    end
    do -- backoff_1_1_30
        local actual = MathCore.cooldown(1,1,30)
        check(actual,2,"backoff_1_1_30")
    end
    do -- backoff_1_2_2
        local actual = MathCore.cooldown(1,2,2)
        check(actual,2,"backoff_1_2_2")
    end
    do -- backoff_1_2_10
        local actual = MathCore.cooldown(1,2,10)
        check(actual,4,"backoff_1_2_10")
    end
    do -- backoff_1_2_30
        local actual = MathCore.cooldown(1,2,30)
        check(actual,4,"backoff_1_2_30")
    end
    do -- backoff_1_3_2
        local actual = MathCore.cooldown(1,3,2)
        check(actual,2,"backoff_1_3_2")
    end
    do -- backoff_1_3_10
        local actual = MathCore.cooldown(1,3,10)
        check(actual,8,"backoff_1_3_10")
    end
    do -- backoff_1_3_30
        local actual = MathCore.cooldown(1,3,30)
        check(actual,8,"backoff_1_3_30")
    end
    do -- backoff_1_4_2
        local actual = MathCore.cooldown(1,4,2)
        check(actual,2,"backoff_1_4_2")
    end
    do -- backoff_1_4_10
        local actual = MathCore.cooldown(1,4,10)
        check(actual,10,"backoff_1_4_10")
    end
    do -- backoff_1_4_30
        local actual = MathCore.cooldown(1,4,30)
        check(actual,16,"backoff_1_4_30")
    end
    do -- backoff_1_5_2
        local actual = MathCore.cooldown(1,5,2)
        check(actual,2,"backoff_1_5_2")
    end
    do -- backoff_1_5_10
        local actual = MathCore.cooldown(1,5,10)
        check(actual,10,"backoff_1_5_10")
    end
    do -- backoff_1_5_30
        local actual = MathCore.cooldown(1,5,30)
        check(actual,30,"backoff_1_5_30")
    end
    do -- backoff_1_10_2
        local actual = MathCore.cooldown(1,10,2)
        check(actual,2,"backoff_1_10_2")
    end
    do -- backoff_1_10_10
        local actual = MathCore.cooldown(1,10,10)
        check(actual,10,"backoff_1_10_10")
    end
    do -- backoff_1_10_30
        local actual = MathCore.cooldown(1,10,30)
        check(actual,30,"backoff_1_10_30")
    end
    do -- backoff_1_15_2
        local actual = MathCore.cooldown(1,15,2)
        check(actual,2,"backoff_1_15_2")
    end
    do -- backoff_1_15_10
        local actual = MathCore.cooldown(1,15,10)
        check(actual,10,"backoff_1_15_10")
    end
    do -- backoff_1_15_30
        local actual = MathCore.cooldown(1,15,30)
        check(actual,30,"backoff_1_15_30")
    end
    do -- backoff_2_0_2
        local actual = MathCore.cooldown(2,0,2)
        check(actual,2,"backoff_2_0_2")
    end
    do -- backoff_2_0_10
        local actual = MathCore.cooldown(2,0,10)
        check(actual,2,"backoff_2_0_10")
    end
    do -- backoff_2_0_30
        local actual = MathCore.cooldown(2,0,30)
        check(actual,2,"backoff_2_0_30")
    end
    do -- backoff_2_1_2
        local actual = MathCore.cooldown(2,1,2)
        check(actual,2,"backoff_2_1_2")
    end
    do -- backoff_2_1_10
        local actual = MathCore.cooldown(2,1,10)
        check(actual,4,"backoff_2_1_10")
    end
    do -- backoff_2_1_30
        local actual = MathCore.cooldown(2,1,30)
        check(actual,4,"backoff_2_1_30")
    end
    do -- backoff_2_2_2
        local actual = MathCore.cooldown(2,2,2)
        check(actual,2,"backoff_2_2_2")
    end
    do -- backoff_2_2_10
        local actual = MathCore.cooldown(2,2,10)
        check(actual,8,"backoff_2_2_10")
    end
    do -- backoff_2_2_30
        local actual = MathCore.cooldown(2,2,30)
        check(actual,8,"backoff_2_2_30")
    end
    do -- backoff_2_3_2
        local actual = MathCore.cooldown(2,3,2)
        check(actual,2,"backoff_2_3_2")
    end
    do -- backoff_2_3_10
        local actual = MathCore.cooldown(2,3,10)
        check(actual,10,"backoff_2_3_10")
    end
    do -- backoff_2_3_30
        local actual = MathCore.cooldown(2,3,30)
        check(actual,16,"backoff_2_3_30")
    end
    do -- backoff_2_4_2
        local actual = MathCore.cooldown(2,4,2)
        check(actual,2,"backoff_2_4_2")
    end
    do -- backoff_2_4_10
        local actual = MathCore.cooldown(2,4,10)
        check(actual,10,"backoff_2_4_10")
    end
    do -- backoff_2_4_30
        local actual = MathCore.cooldown(2,4,30)
        check(actual,30,"backoff_2_4_30")
    end
    do -- backoff_2_5_2
        local actual = MathCore.cooldown(2,5,2)
        check(actual,2,"backoff_2_5_2")
    end
    do -- backoff_2_5_10
        local actual = MathCore.cooldown(2,5,10)
        check(actual,10,"backoff_2_5_10")
    end
    do -- backoff_2_5_30
        local actual = MathCore.cooldown(2,5,30)
        check(actual,30,"backoff_2_5_30")
    end
    do -- backoff_2_10_2
        local actual = MathCore.cooldown(2,10,2)
        check(actual,2,"backoff_2_10_2")
    end
    do -- backoff_2_10_10
        local actual = MathCore.cooldown(2,10,10)
        check(actual,10,"backoff_2_10_10")
    end
    do -- backoff_2_10_30
        local actual = MathCore.cooldown(2,10,30)
        check(actual,30,"backoff_2_10_30")
    end
    do -- backoff_2_15_2
        local actual = MathCore.cooldown(2,15,2)
        check(actual,2,"backoff_2_15_2")
    end
    do -- backoff_2_15_10
        local actual = MathCore.cooldown(2,15,10)
        check(actual,10,"backoff_2_15_10")
    end
    do -- backoff_2_15_30
        local actual = MathCore.cooldown(2,15,30)
        check(actual,30,"backoff_2_15_30")
    end
    do -- backoff_5_0_2
        local actual = MathCore.cooldown(5,0,2)
        check(actual,2,"backoff_5_0_2")
    end
    do -- backoff_5_0_10
        local actual = MathCore.cooldown(5,0,10)
        check(actual,5,"backoff_5_0_10")
    end
    do -- backoff_5_0_30
        local actual = MathCore.cooldown(5,0,30)
        check(actual,5,"backoff_5_0_30")
    end
    do -- backoff_5_1_2
        local actual = MathCore.cooldown(5,1,2)
        check(actual,2,"backoff_5_1_2")
    end
    do -- backoff_5_1_10
        local actual = MathCore.cooldown(5,1,10)
        check(actual,10,"backoff_5_1_10")
    end
    do -- backoff_5_1_30
        local actual = MathCore.cooldown(5,1,30)
        check(actual,10,"backoff_5_1_30")
    end
    do -- backoff_5_2_2
        local actual = MathCore.cooldown(5,2,2)
        check(actual,2,"backoff_5_2_2")
    end
    do -- backoff_5_2_10
        local actual = MathCore.cooldown(5,2,10)
        check(actual,10,"backoff_5_2_10")
    end
    do -- backoff_5_2_30
        local actual = MathCore.cooldown(5,2,30)
        check(actual,20,"backoff_5_2_30")
    end
    do -- backoff_5_3_2
        local actual = MathCore.cooldown(5,3,2)
        check(actual,2,"backoff_5_3_2")
    end
    do -- backoff_5_3_10
        local actual = MathCore.cooldown(5,3,10)
        check(actual,10,"backoff_5_3_10")
    end
    do -- backoff_5_3_30
        local actual = MathCore.cooldown(5,3,30)
        check(actual,30,"backoff_5_3_30")
    end
    do -- backoff_5_4_2
        local actual = MathCore.cooldown(5,4,2)
        check(actual,2,"backoff_5_4_2")
    end
    do -- backoff_5_4_10
        local actual = MathCore.cooldown(5,4,10)
        check(actual,10,"backoff_5_4_10")
    end
    do -- backoff_5_4_30
        local actual = MathCore.cooldown(5,4,30)
        check(actual,30,"backoff_5_4_30")
    end
    do -- backoff_5_5_2
        local actual = MathCore.cooldown(5,5,2)
        check(actual,2,"backoff_5_5_2")
    end
    do -- backoff_5_5_10
        local actual = MathCore.cooldown(5,5,10)
        check(actual,10,"backoff_5_5_10")
    end
    do -- backoff_5_5_30
        local actual = MathCore.cooldown(5,5,30)
        check(actual,30,"backoff_5_5_30")
    end
    do -- backoff_5_10_2
        local actual = MathCore.cooldown(5,10,2)
        check(actual,2,"backoff_5_10_2")
    end
    do -- backoff_5_10_10
        local actual = MathCore.cooldown(5,10,10)
        check(actual,10,"backoff_5_10_10")
    end
    do -- backoff_5_10_30
        local actual = MathCore.cooldown(5,10,30)
        check(actual,30,"backoff_5_10_30")
    end
    do -- backoff_5_15_2
        local actual = MathCore.cooldown(5,15,2)
        check(actual,2,"backoff_5_15_2")
    end
    do -- backoff_5_15_10
        local actual = MathCore.cooldown(5,15,10)
        check(actual,10,"backoff_5_15_10")
    end
    do -- backoff_5_15_30
        local actual = MathCore.cooldown(5,15,30)
        check(actual,30,"backoff_5_15_30")
    end
    do -- score_0_20_0_0_False
        local actual = MathCore.score(0,20,0,0,false,0)
        check(actual,18.0,"score_0_20_0_0_False")
    end
    do -- score_0_20_0_0_True
        local actual = MathCore.score(0,20,0,0,true,0)
        check(actual,0.0,"score_0_20_0_0_True")
    end
    do -- score_0_20_0_25_False
        local actual = MathCore.score(0,20,0,25,false,0)
        check(actual,23.0,"score_0_20_0_25_False")
    end
    do -- score_0_20_0_25_True
        local actual = MathCore.score(0,20,0,25,true,0)
        check(actual,5.0,"score_0_20_0_25_True")
    end
    do -- score_0_20_0.5_0_False
        local actual = MathCore.score(0,20,0.5,0,false,0)
        check(actual,24.0,"score_0_20_0.5_0_False")
    end
    do -- score_0_20_0.5_0_True
        local actual = MathCore.score(0,20,0.5,0,true,0)
        check(actual,6.0,"score_0_20_0.5_0_True")
    end
    do -- score_0_20_0.5_25_False
        local actual = MathCore.score(0,20,0.5,25,false,0)
        check(actual,29.0,"score_0_20_0.5_25_False")
    end
    do -- score_0_20_0.5_25_True
        local actual = MathCore.score(0,20,0.5,25,true,0)
        check(actual,11.0,"score_0_20_0.5_25_True")
    end
    do -- score_0_20_1_0_False
        local actual = MathCore.score(0,20,1,0,false,0)
        check(actual,30.0,"score_0_20_1_0_False")
    end
    do -- score_0_20_1_0_True
        local actual = MathCore.score(0,20,1,0,true,0)
        check(actual,12.0,"score_0_20_1_0_True")
    end
    do -- score_0_20_1_25_False
        local actual = MathCore.score(0,20,1,25,false,0)
        check(actual,35.0,"score_0_20_1_25_False")
    end
    do -- score_0_20_1_25_True
        local actual = MathCore.score(0,20,1,25,true,0)
        check(actual,17.0,"score_0_20_1_25_True")
    end
    do -- score_0_100_0_0_False
        local actual = MathCore.score(0,100,0,0,false,0)
        check(actual,18.0,"score_0_100_0_0_False")
    end
    do -- score_0_100_0_0_True
        local actual = MathCore.score(0,100,0,0,true,0)
        check(actual,0.0,"score_0_100_0_0_True")
    end
    do -- score_0_100_0_25_False
        local actual = MathCore.score(0,100,0,25,false,0)
        check(actual,23.0,"score_0_100_0_25_False")
    end
    do -- score_0_100_0_25_True
        local actual = MathCore.score(0,100,0,25,true,0)
        check(actual,5.0,"score_0_100_0_25_True")
    end
    do -- score_0_100_0.5_0_False
        local actual = MathCore.score(0,100,0.5,0,false,0)
        check(actual,24.0,"score_0_100_0.5_0_False")
    end
    do -- score_0_100_0.5_0_True
        local actual = MathCore.score(0,100,0.5,0,true,0)
        check(actual,6.0,"score_0_100_0.5_0_True")
    end
    do -- score_0_100_0.5_25_False
        local actual = MathCore.score(0,100,0.5,25,false,0)
        check(actual,29.0,"score_0_100_0.5_25_False")
    end
    do -- score_0_100_0.5_25_True
        local actual = MathCore.score(0,100,0.5,25,true,0)
        check(actual,11.0,"score_0_100_0.5_25_True")
    end
    do -- score_0_100_1_0_False
        local actual = MathCore.score(0,100,1,0,false,0)
        check(actual,30.0,"score_0_100_1_0_False")
    end
    do -- score_0_100_1_0_True
        local actual = MathCore.score(0,100,1,0,true,0)
        check(actual,12.0,"score_0_100_1_0_True")
    end
    do -- score_0_100_1_25_False
        local actual = MathCore.score(0,100,1,25,false,0)
        check(actual,35.0,"score_0_100_1_25_False")
    end
    do -- score_0_100_1_25_True
        local actual = MathCore.score(0,100,1,25,true,0)
        check(actual,17.0,"score_0_100_1_25_True")
    end
    do -- score_0_350_0_0_False
        local actual = MathCore.score(0,350,0,0,false,0)
        check(actual,18.0,"score_0_350_0_0_False")
    end
    do -- score_0_350_0_0_True
        local actual = MathCore.score(0,350,0,0,true,0)
        check(actual,0.0,"score_0_350_0_0_True")
    end
    do -- score_0_350_0_25_False
        local actual = MathCore.score(0,350,0,25,false,0)
        check(actual,23.0,"score_0_350_0_25_False")
    end
    do -- score_0_350_0_25_True
        local actual = MathCore.score(0,350,0,25,true,0)
        check(actual,5.0,"score_0_350_0_25_True")
    end
    do -- score_0_350_0.5_0_False
        local actual = MathCore.score(0,350,0.5,0,false,0)
        check(actual,24.0,"score_0_350_0.5_0_False")
    end
    do -- score_0_350_0.5_0_True
        local actual = MathCore.score(0,350,0.5,0,true,0)
        check(actual,6.0,"score_0_350_0.5_0_True")
    end
    do -- score_0_350_0.5_25_False
        local actual = MathCore.score(0,350,0.5,25,false,0)
        check(actual,29.0,"score_0_350_0.5_25_False")
    end
    do -- score_0_350_0.5_25_True
        local actual = MathCore.score(0,350,0.5,25,true,0)
        check(actual,11.0,"score_0_350_0.5_25_True")
    end
    do -- score_0_350_1_0_False
        local actual = MathCore.score(0,350,1,0,false,0)
        check(actual,30.0,"score_0_350_1_0_False")
    end
    do -- score_0_350_1_0_True
        local actual = MathCore.score(0,350,1,0,true,0)
        check(actual,12.0,"score_0_350_1_0_True")
    end
    do -- score_0_350_1_25_False
        local actual = MathCore.score(0,350,1,25,false,0)
        check(actual,35.0,"score_0_350_1_25_False")
    end
    do -- score_0_350_1_25_True
        local actual = MathCore.score(0,350,1,25,true,0)
        check(actual,17.0,"score_0_350_1_25_True")
    end
    do -- score_5_20_0_0_False
        local actual = MathCore.score(5,20,0,0,false,0)
        check(actual,43.0,"score_5_20_0_0_False")
    end
    do -- score_5_20_0_0_True
        local actual = MathCore.score(5,20,0,0,true,0)
        check(actual,25.0,"score_5_20_0_0_True")
    end
    do -- score_5_20_0_25_False
        local actual = MathCore.score(5,20,0,25,false,0)
        check(actual,48.0,"score_5_20_0_25_False")
    end
    do -- score_5_20_0_25_True
        local actual = MathCore.score(5,20,0,25,true,0)
        check(actual,30.0,"score_5_20_0_25_True")
    end
    do -- score_5_20_0.5_0_False
        local actual = MathCore.score(5,20,0.5,0,false,0)
        check(actual,49.0,"score_5_20_0.5_0_False")
    end
    do -- score_5_20_0.5_0_True
        local actual = MathCore.score(5,20,0.5,0,true,0)
        check(actual,31.0,"score_5_20_0.5_0_True")
    end
    do -- score_5_20_0.5_25_False
        local actual = MathCore.score(5,20,0.5,25,false,0)
        check(actual,54.0,"score_5_20_0.5_25_False")
    end
    do -- score_5_20_0.5_25_True
        local actual = MathCore.score(5,20,0.5,25,true,0)
        check(actual,36.0,"score_5_20_0.5_25_True")
    end
    do -- score_5_20_1_0_False
        local actual = MathCore.score(5,20,1,0,false,0)
        check(actual,55.0,"score_5_20_1_0_False")
    end
    do -- score_5_20_1_0_True
        local actual = MathCore.score(5,20,1,0,true,0)
        check(actual,37.0,"score_5_20_1_0_True")
    end
    do -- score_5_20_1_25_False
        local actual = MathCore.score(5,20,1,25,false,0)
        check(actual,60.0,"score_5_20_1_25_False")
    end
    do -- score_5_20_1_25_True
        local actual = MathCore.score(5,20,1,25,true,0)
        check(actual,42.0,"score_5_20_1_25_True")
    end
    do -- score_5_100_0_0_False
        local actual = MathCore.score(5,100,0,0,false,0)
        check(actual,23.0,"score_5_100_0_0_False")
    end
    do -- score_5_100_0_0_True
        local actual = MathCore.score(5,100,0,0,true,0)
        check(actual,5.0,"score_5_100_0_0_True")
    end
    do -- score_5_100_0_25_False
        local actual = MathCore.score(5,100,0,25,false,0)
        check(actual,28.0,"score_5_100_0_25_False")
    end
    do -- score_5_100_0_25_True
        local actual = MathCore.score(5,100,0,25,true,0)
        check(actual,10.0,"score_5_100_0_25_True")
    end
    do -- score_5_100_0.5_0_False
        local actual = MathCore.score(5,100,0.5,0,false,0)
        check(actual,29.0,"score_5_100_0.5_0_False")
    end
    do -- score_5_100_0.5_0_True
        local actual = MathCore.score(5,100,0.5,0,true,0)
        check(actual,11.0,"score_5_100_0.5_0_True")
    end
    do -- score_5_100_0.5_25_False
        local actual = MathCore.score(5,100,0.5,25,false,0)
        check(actual,34.0,"score_5_100_0.5_25_False")
    end
    do -- score_5_100_0.5_25_True
        local actual = MathCore.score(5,100,0.5,25,true,0)
        check(actual,16.0,"score_5_100_0.5_25_True")
    end
    do -- score_5_100_1_0_False
        local actual = MathCore.score(5,100,1,0,false,0)
        check(actual,35.0,"score_5_100_1_0_False")
    end
    do -- score_5_100_1_0_True
        local actual = MathCore.score(5,100,1,0,true,0)
        check(actual,17.0,"score_5_100_1_0_True")
    end
    do -- score_5_100_1_25_False
        local actual = MathCore.score(5,100,1,25,false,0)
        check(actual,40.0,"score_5_100_1_25_False")
    end
    do -- score_5_100_1_25_True
        local actual = MathCore.score(5,100,1,25,true,0)
        check(actual,22.0,"score_5_100_1_25_True")
    end
    do -- score_5_350_0_0_False
        local actual = MathCore.score(5,350,0,0,false,0)
        check(actual,19.428571428571427,"score_5_350_0_0_False")
    end
    do -- score_5_350_0_0_True
        local actual = MathCore.score(5,350,0,0,true,0)
        check(actual,1.4285714285714286,"score_5_350_0_0_True")
    end
    do -- score_5_350_0_25_False
        local actual = MathCore.score(5,350,0,25,false,0)
        check(actual,24.42857142857143,"score_5_350_0_25_False")
    end
    do -- score_5_350_0_25_True
        local actual = MathCore.score(5,350,0,25,true,0)
        check(actual,6.428571428571429,"score_5_350_0_25_True")
    end
    do -- score_5_350_0.5_0_False
        local actual = MathCore.score(5,350,0.5,0,false,0)
        check(actual,25.42857142857143,"score_5_350_0.5_0_False")
    end
    do -- score_5_350_0.5_0_True
        local actual = MathCore.score(5,350,0.5,0,true,0)
        check(actual,7.428571428571429,"score_5_350_0.5_0_True")
    end
    do -- score_5_350_0.5_25_False
        local actual = MathCore.score(5,350,0.5,25,false,0)
        check(actual,30.42857142857143,"score_5_350_0.5_25_False")
    end
    do -- score_5_350_0.5_25_True
        local actual = MathCore.score(5,350,0.5,25,true,0)
        check(actual,12.428571428571429,"score_5_350_0.5_25_True")
    end
    do -- score_5_350_1_0_False
        local actual = MathCore.score(5,350,1,0,false,0)
        check(actual,31.42857142857143,"score_5_350_1_0_False")
    end
    do -- score_5_350_1_0_True
        local actual = MathCore.score(5,350,1,0,true,0)
        check(actual,13.428571428571429,"score_5_350_1_0_True")
    end
    do -- score_5_350_1_25_False
        local actual = MathCore.score(5,350,1,25,false,0)
        check(actual,36.42857142857143,"score_5_350_1_25_False")
    end
    do -- score_5_350_1_25_True
        local actual = MathCore.score(5,350,1,25,true,0)
        check(actual,18.42857142857143,"score_5_350_1_25_True")
    end
    do -- score_20_20_0_0_False
        local actual = MathCore.score(20,20,0,0,false,0)
        check(actual,118.0,"score_20_20_0_0_False")
    end
    do -- score_20_20_0_0_True
        local actual = MathCore.score(20,20,0,0,true,0)
        check(actual,100.0,"score_20_20_0_0_True")
    end
    do -- score_20_20_0_25_False
        local actual = MathCore.score(20,20,0,25,false,0)
        check(actual,123.0,"score_20_20_0_25_False")
    end
    do -- score_20_20_0_25_True
        local actual = MathCore.score(20,20,0,25,true,0)
        check(actual,105.0,"score_20_20_0_25_True")
    end
    do -- score_20_20_0.5_0_False
        local actual = MathCore.score(20,20,0.5,0,false,0)
        check(actual,124.0,"score_20_20_0.5_0_False")
    end
    do -- score_20_20_0.5_0_True
        local actual = MathCore.score(20,20,0.5,0,true,0)
        check(actual,106.0,"score_20_20_0.5_0_True")
    end
    do -- score_20_20_0.5_25_False
        local actual = MathCore.score(20,20,0.5,25,false,0)
        check(actual,129.0,"score_20_20_0.5_25_False")
    end
    do -- score_20_20_0.5_25_True
        local actual = MathCore.score(20,20,0.5,25,true,0)
        check(actual,111.0,"score_20_20_0.5_25_True")
    end
    do -- score_20_20_1_0_False
        local actual = MathCore.score(20,20,1,0,false,0)
        check(actual,130.0,"score_20_20_1_0_False")
    end
    do -- score_20_20_1_0_True
        local actual = MathCore.score(20,20,1,0,true,0)
        check(actual,112.0,"score_20_20_1_0_True")
    end
    do -- score_20_20_1_25_False
        local actual = MathCore.score(20,20,1,25,false,0)
        check(actual,135.0,"score_20_20_1_25_False")
    end
    do -- score_20_20_1_25_True
        local actual = MathCore.score(20,20,1,25,true,0)
        check(actual,117.0,"score_20_20_1_25_True")
    end
    do -- score_20_100_0_0_False
        local actual = MathCore.score(20,100,0,0,false,0)
        check(actual,38.0,"score_20_100_0_0_False")
    end
    do -- score_20_100_0_0_True
        local actual = MathCore.score(20,100,0,0,true,0)
        check(actual,20.0,"score_20_100_0_0_True")
    end
    do -- score_20_100_0_25_False
        local actual = MathCore.score(20,100,0,25,false,0)
        check(actual,43.0,"score_20_100_0_25_False")
    end
    do -- score_20_100_0_25_True
        local actual = MathCore.score(20,100,0,25,true,0)
        check(actual,25.0,"score_20_100_0_25_True")
    end
    do -- score_20_100_0.5_0_False
        local actual = MathCore.score(20,100,0.5,0,false,0)
        check(actual,44.0,"score_20_100_0.5_0_False")
    end
    do -- score_20_100_0.5_0_True
        local actual = MathCore.score(20,100,0.5,0,true,0)
        check(actual,26.0,"score_20_100_0.5_0_True")
    end
    do -- score_20_100_0.5_25_False
        local actual = MathCore.score(20,100,0.5,25,false,0)
        check(actual,49.0,"score_20_100_0.5_25_False")
    end
    do -- score_20_100_0.5_25_True
        local actual = MathCore.score(20,100,0.5,25,true,0)
        check(actual,31.0,"score_20_100_0.5_25_True")
    end
    do -- score_20_100_1_0_False
        local actual = MathCore.score(20,100,1,0,false,0)
        check(actual,50.0,"score_20_100_1_0_False")
    end
    do -- score_20_100_1_0_True
        local actual = MathCore.score(20,100,1,0,true,0)
        check(actual,32.0,"score_20_100_1_0_True")
    end
    do -- score_20_100_1_25_False
        local actual = MathCore.score(20,100,1,25,false,0)
        check(actual,55.0,"score_20_100_1_25_False")
    end
    do -- score_20_100_1_25_True
        local actual = MathCore.score(20,100,1,25,true,0)
        check(actual,37.0,"score_20_100_1_25_True")
    end
    do -- score_20_350_0_0_False
        local actual = MathCore.score(20,350,0,0,false,0)
        check(actual,23.714285714285715,"score_20_350_0_0_False")
    end
    do -- score_20_350_0_0_True
        local actual = MathCore.score(20,350,0,0,true,0)
        check(actual,5.714285714285714,"score_20_350_0_0_True")
    end
    do -- score_20_350_0_25_False
        local actual = MathCore.score(20,350,0,25,false,0)
        check(actual,28.714285714285715,"score_20_350_0_25_False")
    end
    do -- score_20_350_0_25_True
        local actual = MathCore.score(20,350,0,25,true,0)
        check(actual,10.714285714285715,"score_20_350_0_25_True")
    end
    do -- score_20_350_0.5_0_False
        local actual = MathCore.score(20,350,0.5,0,false,0)
        check(actual,29.714285714285715,"score_20_350_0.5_0_False")
    end
    do -- score_20_350_0.5_0_True
        local actual = MathCore.score(20,350,0.5,0,true,0)
        check(actual,11.714285714285715,"score_20_350_0.5_0_True")
    end
    do -- score_20_350_0.5_25_False
        local actual = MathCore.score(20,350,0.5,25,false,0)
        check(actual,34.714285714285715,"score_20_350_0.5_25_False")
    end
    do -- score_20_350_0.5_25_True
        local actual = MathCore.score(20,350,0.5,25,true,0)
        check(actual,16.714285714285715,"score_20_350_0.5_25_True")
    end
    do -- score_20_350_1_0_False
        local actual = MathCore.score(20,350,1,0,false,0)
        check(actual,35.714285714285715,"score_20_350_1_0_False")
    end
    do -- score_20_350_1_0_True
        local actual = MathCore.score(20,350,1,0,true,0)
        check(actual,17.714285714285715,"score_20_350_1_0_True")
    end
    do -- score_20_350_1_25_False
        local actual = MathCore.score(20,350,1,25,false,0)
        check(actual,40.714285714285715,"score_20_350_1_25_False")
    end
    do -- score_20_350_1_25_True
        local actual = MathCore.score(20,350,1,25,true,0)
        check(actual,22.714285714285715,"score_20_350_1_25_True")
    end
    do -- score_100_20_0_0_False
        local actual = MathCore.score(100,20,0,0,false,0)
        check(actual,math.huge,"score_100_20_0_0_False")
    end
    do -- score_100_20_0_0_True
        local actual = MathCore.score(100,20,0,0,true,0)
        check(actual,math.huge,"score_100_20_0_0_True")
    end
    do -- score_100_20_0_25_False
        local actual = MathCore.score(100,20,0,25,false,0)
        check(actual,math.huge,"score_100_20_0_25_False")
    end
    do -- score_100_20_0_25_True
        local actual = MathCore.score(100,20,0,25,true,0)
        check(actual,math.huge,"score_100_20_0_25_True")
    end
    do -- score_100_20_0.5_0_False
        local actual = MathCore.score(100,20,0.5,0,false,0)
        check(actual,math.huge,"score_100_20_0.5_0_False")
    end
    do -- score_100_20_0.5_0_True
        local actual = MathCore.score(100,20,0.5,0,true,0)
        check(actual,math.huge,"score_100_20_0.5_0_True")
    end
    do -- score_100_20_0.5_25_False
        local actual = MathCore.score(100,20,0.5,25,false,0)
        check(actual,math.huge,"score_100_20_0.5_25_False")
    end
    do -- score_100_20_0.5_25_True
        local actual = MathCore.score(100,20,0.5,25,true,0)
        check(actual,math.huge,"score_100_20_0.5_25_True")
    end
    do -- score_100_20_1_0_False
        local actual = MathCore.score(100,20,1,0,false,0)
        check(actual,math.huge,"score_100_20_1_0_False")
    end
    do -- score_100_20_1_0_True
        local actual = MathCore.score(100,20,1,0,true,0)
        check(actual,math.huge,"score_100_20_1_0_True")
    end
    do -- score_100_20_1_25_False
        local actual = MathCore.score(100,20,1,25,false,0)
        check(actual,math.huge,"score_100_20_1_25_False")
    end
    do -- score_100_20_1_25_True
        local actual = MathCore.score(100,20,1,25,true,0)
        check(actual,math.huge,"score_100_20_1_25_True")
    end
    do -- score_100_100_0_0_False
        local actual = MathCore.score(100,100,0,0,false,0)
        check(actual,118.0,"score_100_100_0_0_False")
    end
    do -- score_100_100_0_0_True
        local actual = MathCore.score(100,100,0,0,true,0)
        check(actual,100.0,"score_100_100_0_0_True")
    end
    do -- score_100_100_0_25_False
        local actual = MathCore.score(100,100,0,25,false,0)
        check(actual,123.0,"score_100_100_0_25_False")
    end
    do -- score_100_100_0_25_True
        local actual = MathCore.score(100,100,0,25,true,0)
        check(actual,105.0,"score_100_100_0_25_True")
    end
    do -- score_100_100_0.5_0_False
        local actual = MathCore.score(100,100,0.5,0,false,0)
        check(actual,124.0,"score_100_100_0.5_0_False")
    end
    do -- score_100_100_0.5_0_True
        local actual = MathCore.score(100,100,0.5,0,true,0)
        check(actual,106.0,"score_100_100_0.5_0_True")
    end
    do -- score_100_100_0.5_25_False
        local actual = MathCore.score(100,100,0.5,25,false,0)
        check(actual,129.0,"score_100_100_0.5_25_False")
    end
    do -- score_100_100_0.5_25_True
        local actual = MathCore.score(100,100,0.5,25,true,0)
        check(actual,111.0,"score_100_100_0.5_25_True")
    end
    do -- score_100_100_1_0_False
        local actual = MathCore.score(100,100,1,0,false,0)
        check(actual,130.0,"score_100_100_1_0_False")
    end
    do -- score_100_100_1_0_True
        local actual = MathCore.score(100,100,1,0,true,0)
        check(actual,112.0,"score_100_100_1_0_True")
    end
    do -- score_100_100_1_25_False
        local actual = MathCore.score(100,100,1,25,false,0)
        check(actual,135.0,"score_100_100_1_25_False")
    end
    do -- score_100_100_1_25_True
        local actual = MathCore.score(100,100,1,25,true,0)
        check(actual,117.0,"score_100_100_1_25_True")
    end
    do -- score_100_350_0_0_False
        local actual = MathCore.score(100,350,0,0,false,0)
        check(actual,46.57142857142857,"score_100_350_0_0_False")
    end
    do -- score_100_350_0_0_True
        local actual = MathCore.score(100,350,0,0,true,0)
        check(actual,28.57142857142857,"score_100_350_0_0_True")
    end
    do -- score_100_350_0_25_False
        local actual = MathCore.score(100,350,0,25,false,0)
        check(actual,51.57142857142857,"score_100_350_0_25_False")
    end
    do -- score_100_350_0_25_True
        local actual = MathCore.score(100,350,0,25,true,0)
        check(actual,33.57142857142857,"score_100_350_0_25_True")
    end
    do -- score_100_350_0.5_0_False
        local actual = MathCore.score(100,350,0.5,0,false,0)
        check(actual,52.57142857142857,"score_100_350_0.5_0_False")
    end
    do -- score_100_350_0.5_0_True
        local actual = MathCore.score(100,350,0.5,0,true,0)
        check(actual,34.57142857142857,"score_100_350_0.5_0_True")
    end
    do -- score_100_350_0.5_25_False
        local actual = MathCore.score(100,350,0.5,25,false,0)
        check(actual,57.57142857142857,"score_100_350_0.5_25_False")
    end
    do -- score_100_350_0.5_25_True
        local actual = MathCore.score(100,350,0.5,25,true,0)
        check(actual,39.57142857142857,"score_100_350_0.5_25_True")
    end
    do -- score_100_350_1_0_False
        local actual = MathCore.score(100,350,1,0,false,0)
        check(actual,58.57142857142857,"score_100_350_1_0_False")
    end
    do -- score_100_350_1_0_True
        local actual = MathCore.score(100,350,1,0,true,0)
        check(actual,40.57142857142857,"score_100_350_1_0_True")
    end
    do -- score_100_350_1_25_False
        local actual = MathCore.score(100,350,1,25,false,0)
        check(actual,63.57142857142857,"score_100_350_1_25_False")
    end
    do -- score_100_350_1_25_True
        local actual = MathCore.score(100,350,1,25,true,0)
        check(actual,45.57142857142857,"score_100_350_1_25_True")
    end
    do -- score_200_20_0_0_False
        local actual = MathCore.score(200,20,0,0,false,0)
        check(actual,math.huge,"score_200_20_0_0_False")
    end
    do -- score_200_20_0_0_True
        local actual = MathCore.score(200,20,0,0,true,0)
        check(actual,math.huge,"score_200_20_0_0_True")
    end
    do -- score_200_20_0_25_False
        local actual = MathCore.score(200,20,0,25,false,0)
        check(actual,math.huge,"score_200_20_0_25_False")
    end
    do -- score_200_20_0_25_True
        local actual = MathCore.score(200,20,0,25,true,0)
        check(actual,math.huge,"score_200_20_0_25_True")
    end
    do -- score_200_20_0.5_0_False
        local actual = MathCore.score(200,20,0.5,0,false,0)
        check(actual,math.huge,"score_200_20_0.5_0_False")
    end
    do -- score_200_20_0.5_0_True
        local actual = MathCore.score(200,20,0.5,0,true,0)
        check(actual,math.huge,"score_200_20_0.5_0_True")
    end
    do -- score_200_20_0.5_25_False
        local actual = MathCore.score(200,20,0.5,25,false,0)
        check(actual,math.huge,"score_200_20_0.5_25_False")
    end
    do -- score_200_20_0.5_25_True
        local actual = MathCore.score(200,20,0.5,25,true,0)
        check(actual,math.huge,"score_200_20_0.5_25_True")
    end
    do -- score_200_20_1_0_False
        local actual = MathCore.score(200,20,1,0,false,0)
        check(actual,math.huge,"score_200_20_1_0_False")
    end
    do -- score_200_20_1_0_True
        local actual = MathCore.score(200,20,1,0,true,0)
        check(actual,math.huge,"score_200_20_1_0_True")
    end
    do -- score_200_20_1_25_False
        local actual = MathCore.score(200,20,1,25,false,0)
        check(actual,math.huge,"score_200_20_1_25_False")
    end
    do -- score_200_20_1_25_True
        local actual = MathCore.score(200,20,1,25,true,0)
        check(actual,math.huge,"score_200_20_1_25_True")
    end
    do -- score_200_100_0_0_False
        local actual = MathCore.score(200,100,0,0,false,0)
        check(actual,math.huge,"score_200_100_0_0_False")
    end
    do -- score_200_100_0_0_True
        local actual = MathCore.score(200,100,0,0,true,0)
        check(actual,math.huge,"score_200_100_0_0_True")
    end
    do -- score_200_100_0_25_False
        local actual = MathCore.score(200,100,0,25,false,0)
        check(actual,math.huge,"score_200_100_0_25_False")
    end
    do -- score_200_100_0_25_True
        local actual = MathCore.score(200,100,0,25,true,0)
        check(actual,math.huge,"score_200_100_0_25_True")
    end
    do -- score_200_100_0.5_0_False
        local actual = MathCore.score(200,100,0.5,0,false,0)
        check(actual,math.huge,"score_200_100_0.5_0_False")
    end
    do -- score_200_100_0.5_0_True
        local actual = MathCore.score(200,100,0.5,0,true,0)
        check(actual,math.huge,"score_200_100_0.5_0_True")
    end
    do -- score_200_100_0.5_25_False
        local actual = MathCore.score(200,100,0.5,25,false,0)
        check(actual,math.huge,"score_200_100_0.5_25_False")
    end
    do -- score_200_100_0.5_25_True
        local actual = MathCore.score(200,100,0.5,25,true,0)
        check(actual,math.huge,"score_200_100_0.5_25_True")
    end
    do -- score_200_100_1_0_False
        local actual = MathCore.score(200,100,1,0,false,0)
        check(actual,math.huge,"score_200_100_1_0_False")
    end
    do -- score_200_100_1_0_True
        local actual = MathCore.score(200,100,1,0,true,0)
        check(actual,math.huge,"score_200_100_1_0_True")
    end
    do -- score_200_100_1_25_False
        local actual = MathCore.score(200,100,1,25,false,0)
        check(actual,math.huge,"score_200_100_1_25_False")
    end
    do -- score_200_100_1_25_True
        local actual = MathCore.score(200,100,1,25,true,0)
        check(actual,math.huge,"score_200_100_1_25_True")
    end
    do -- score_200_350_0_0_False
        local actual = MathCore.score(200,350,0,0,false,0)
        check(actual,75.14285714285714,"score_200_350_0_0_False")
    end
    do -- score_200_350_0_0_True
        local actual = MathCore.score(200,350,0,0,true,0)
        check(actual,57.14285714285714,"score_200_350_0_0_True")
    end
    do -- score_200_350_0_25_False
        local actual = MathCore.score(200,350,0,25,false,0)
        check(actual,80.14285714285714,"score_200_350_0_25_False")
    end
    do -- score_200_350_0_25_True
        local actual = MathCore.score(200,350,0,25,true,0)
        check(actual,62.14285714285714,"score_200_350_0_25_True")
    end
    do -- score_200_350_0.5_0_False
        local actual = MathCore.score(200,350,0.5,0,false,0)
        check(actual,81.14285714285714,"score_200_350_0.5_0_False")
    end
    do -- score_200_350_0.5_0_True
        local actual = MathCore.score(200,350,0.5,0,true,0)
        check(actual,63.14285714285714,"score_200_350_0.5_0_True")
    end
    do -- score_200_350_0.5_25_False
        local actual = MathCore.score(200,350,0.5,25,false,0)
        check(actual,86.14285714285714,"score_200_350_0.5_25_False")
    end
    do -- score_200_350_0.5_25_True
        local actual = MathCore.score(200,350,0.5,25,true,0)
        check(actual,68.14285714285714,"score_200_350_0.5_25_True")
    end
    do -- score_200_350_1_0_False
        local actual = MathCore.score(200,350,1,0,false,0)
        check(actual,87.14285714285714,"score_200_350_1_0_False")
    end
    do -- score_200_350_1_0_True
        local actual = MathCore.score(200,350,1,0,true,0)
        check(actual,69.14285714285714,"score_200_350_1_0_True")
    end
    do -- score_200_350_1_25_False
        local actual = MathCore.score(200,350,1,25,false,0)
        check(actual,92.14285714285714,"score_200_350_1_25_False")
    end
    do -- score_200_350_1_25_True
        local actual = MathCore.score(200,350,1,25,true,0)
        check(actual,74.14285714285714,"score_200_350_1_25_True")
    end
    do -- score_500_20_0_0_False
        local actual = MathCore.score(500,20,0,0,false,0)
        check(actual,math.huge,"score_500_20_0_0_False")
    end
    do -- score_500_20_0_0_True
        local actual = MathCore.score(500,20,0,0,true,0)
        check(actual,math.huge,"score_500_20_0_0_True")
    end
    do -- score_500_20_0_25_False
        local actual = MathCore.score(500,20,0,25,false,0)
        check(actual,math.huge,"score_500_20_0_25_False")
    end
    do -- score_500_20_0_25_True
        local actual = MathCore.score(500,20,0,25,true,0)
        check(actual,math.huge,"score_500_20_0_25_True")
    end
    do -- score_500_20_0.5_0_False
        local actual = MathCore.score(500,20,0.5,0,false,0)
        check(actual,math.huge,"score_500_20_0.5_0_False")
    end
    do -- score_500_20_0.5_0_True
        local actual = MathCore.score(500,20,0.5,0,true,0)
        check(actual,math.huge,"score_500_20_0.5_0_True")
    end
    do -- score_500_20_0.5_25_False
        local actual = MathCore.score(500,20,0.5,25,false,0)
        check(actual,math.huge,"score_500_20_0.5_25_False")
    end
    do -- score_500_20_0.5_25_True
        local actual = MathCore.score(500,20,0.5,25,true,0)
        check(actual,math.huge,"score_500_20_0.5_25_True")
    end
    do -- score_500_20_1_0_False
        local actual = MathCore.score(500,20,1,0,false,0)
        check(actual,math.huge,"score_500_20_1_0_False")
    end
    do -- score_500_20_1_0_True
        local actual = MathCore.score(500,20,1,0,true,0)
        check(actual,math.huge,"score_500_20_1_0_True")
    end
    do -- score_500_20_1_25_False
        local actual = MathCore.score(500,20,1,25,false,0)
        check(actual,math.huge,"score_500_20_1_25_False")
    end
    do -- score_500_20_1_25_True
        local actual = MathCore.score(500,20,1,25,true,0)
        check(actual,math.huge,"score_500_20_1_25_True")
    end
    do -- score_500_100_0_0_False
        local actual = MathCore.score(500,100,0,0,false,0)
        check(actual,math.huge,"score_500_100_0_0_False")
    end
    do -- score_500_100_0_0_True
        local actual = MathCore.score(500,100,0,0,true,0)
        check(actual,math.huge,"score_500_100_0_0_True")
    end
    do -- score_500_100_0_25_False
        local actual = MathCore.score(500,100,0,25,false,0)
        check(actual,math.huge,"score_500_100_0_25_False")
    end
    do -- score_500_100_0_25_True
        local actual = MathCore.score(500,100,0,25,true,0)
        check(actual,math.huge,"score_500_100_0_25_True")
    end
    do -- score_500_100_0.5_0_False
        local actual = MathCore.score(500,100,0.5,0,false,0)
        check(actual,math.huge,"score_500_100_0.5_0_False")
    end
    do -- score_500_100_0.5_0_True
        local actual = MathCore.score(500,100,0.5,0,true,0)
        check(actual,math.huge,"score_500_100_0.5_0_True")
    end
    do -- score_500_100_0.5_25_False
        local actual = MathCore.score(500,100,0.5,25,false,0)
        check(actual,math.huge,"score_500_100_0.5_25_False")
    end
    do -- score_500_100_0.5_25_True
        local actual = MathCore.score(500,100,0.5,25,true,0)
        check(actual,math.huge,"score_500_100_0.5_25_True")
    end
    do -- score_500_100_1_0_False
        local actual = MathCore.score(500,100,1,0,false,0)
        check(actual,math.huge,"score_500_100_1_0_False")
    end
    do -- score_500_100_1_0_True
        local actual = MathCore.score(500,100,1,0,true,0)
        check(actual,math.huge,"score_500_100_1_0_True")
    end
    do -- score_500_100_1_25_False
        local actual = MathCore.score(500,100,1,25,false,0)
        check(actual,math.huge,"score_500_100_1_25_False")
    end
    do -- score_500_100_1_25_True
        local actual = MathCore.score(500,100,1,25,true,0)
        check(actual,math.huge,"score_500_100_1_25_True")
    end
    do -- score_500_350_0_0_False
        local actual = MathCore.score(500,350,0,0,false,0)
        check(actual,math.huge,"score_500_350_0_0_False")
    end
    do -- score_500_350_0_0_True
        local actual = MathCore.score(500,350,0,0,true,0)
        check(actual,math.huge,"score_500_350_0_0_True")
    end
    do -- score_500_350_0_25_False
        local actual = MathCore.score(500,350,0,25,false,0)
        check(actual,math.huge,"score_500_350_0_25_False")
    end
    do -- score_500_350_0_25_True
        local actual = MathCore.score(500,350,0,25,true,0)
        check(actual,math.huge,"score_500_350_0_25_True")
    end
    do -- score_500_350_0.5_0_False
        local actual = MathCore.score(500,350,0.5,0,false,0)
        check(actual,math.huge,"score_500_350_0.5_0_False")
    end
    do -- score_500_350_0.5_0_True
        local actual = MathCore.score(500,350,0.5,0,true,0)
        check(actual,math.huge,"score_500_350_0.5_0_True")
    end
    do -- score_500_350_0.5_25_False
        local actual = MathCore.score(500,350,0.5,25,false,0)
        check(actual,math.huge,"score_500_350_0.5_25_False")
    end
    do -- score_500_350_0.5_25_True
        local actual = MathCore.score(500,350,0.5,25,true,0)
        check(actual,math.huge,"score_500_350_0.5_25_True")
    end
    do -- score_500_350_1_0_False
        local actual = MathCore.score(500,350,1,0,false,0)
        check(actual,math.huge,"score_500_350_1_0_False")
    end
    do -- score_500_350_1_0_True
        local actual = MathCore.score(500,350,1,0,true,0)
        check(actual,math.huge,"score_500_350_1_0_True")
    end
    do -- score_500_350_1_25_False
        local actual = MathCore.score(500,350,1,25,false,0)
        check(actual,math.huge,"score_500_350_1_25_False")
    end
    do -- score_500_350_1_25_True
        local actual = MathCore.score(500,350,1,25,true,0)
        check(actual,math.huge,"score_500_350_1_25_True")
    end
    do -- health_False_0_20_80
        local actual = MathCore.healthMode(false,0,20,80)
        check(actual,true,"health_False_0_20_80")
    end
    do -- health_False_0_20_85
        local actual = MathCore.healthMode(false,0,20,85)
        check(actual,true,"health_False_0_20_85")
    end
    do -- health_False_0_20_95
        local actual = MathCore.healthMode(false,0,20,95)
        check(actual,true,"health_False_0_20_95")
    end
    do -- health_False_0_30_80
        local actual = MathCore.healthMode(false,0,30,80)
        check(actual,true,"health_False_0_30_80")
    end
    do -- health_False_0_30_85
        local actual = MathCore.healthMode(false,0,30,85)
        check(actual,true,"health_False_0_30_85")
    end
    do -- health_False_0_30_95
        local actual = MathCore.healthMode(false,0,30,95)
        check(actual,true,"health_False_0_30_95")
    end
    do -- health_False_10_20_80
        local actual = MathCore.healthMode(false,10,20,80)
        check(actual,true,"health_False_10_20_80")
    end
    do -- health_False_10_20_85
        local actual = MathCore.healthMode(false,10,20,85)
        check(actual,true,"health_False_10_20_85")
    end
    do -- health_False_10_20_95
        local actual = MathCore.healthMode(false,10,20,95)
        check(actual,true,"health_False_10_20_95")
    end
    do -- health_False_10_30_80
        local actual = MathCore.healthMode(false,10,30,80)
        check(actual,true,"health_False_10_30_80")
    end
    do -- health_False_10_30_85
        local actual = MathCore.healthMode(false,10,30,85)
        check(actual,true,"health_False_10_30_85")
    end
    do -- health_False_10_30_95
        local actual = MathCore.healthMode(false,10,30,95)
        check(actual,true,"health_False_10_30_95")
    end
    do -- health_False_29_20_80
        local actual = MathCore.healthMode(false,29,20,80)
        check(actual,false,"health_False_29_20_80")
    end
    do -- health_False_29_20_85
        local actual = MathCore.healthMode(false,29,20,85)
        check(actual,false,"health_False_29_20_85")
    end
    do -- health_False_29_20_95
        local actual = MathCore.healthMode(false,29,20,95)
        check(actual,false,"health_False_29_20_95")
    end
    do -- health_False_29_30_80
        local actual = MathCore.healthMode(false,29,30,80)
        check(actual,true,"health_False_29_30_80")
    end
    do -- health_False_29_30_85
        local actual = MathCore.healthMode(false,29,30,85)
        check(actual,true,"health_False_29_30_85")
    end
    do -- health_False_29_30_95
        local actual = MathCore.healthMode(false,29,30,95)
        check(actual,true,"health_False_29_30_95")
    end
    do -- health_False_30_20_80
        local actual = MathCore.healthMode(false,30,20,80)
        check(actual,false,"health_False_30_20_80")
    end
    do -- health_False_30_20_85
        local actual = MathCore.healthMode(false,30,20,85)
        check(actual,false,"health_False_30_20_85")
    end
    do -- health_False_30_20_95
        local actual = MathCore.healthMode(false,30,20,95)
        check(actual,false,"health_False_30_20_95")
    end
    do -- health_False_30_30_80
        local actual = MathCore.healthMode(false,30,30,80)
        check(actual,true,"health_False_30_30_80")
    end
    do -- health_False_30_30_85
        local actual = MathCore.healthMode(false,30,30,85)
        check(actual,true,"health_False_30_30_85")
    end
    do -- health_False_30_30_95
        local actual = MathCore.healthMode(false,30,30,95)
        check(actual,true,"health_False_30_30_95")
    end
    do -- health_False_31_20_80
        local actual = MathCore.healthMode(false,31,20,80)
        check(actual,false,"health_False_31_20_80")
    end
    do -- health_False_31_20_85
        local actual = MathCore.healthMode(false,31,20,85)
        check(actual,false,"health_False_31_20_85")
    end
    do -- health_False_31_20_95
        local actual = MathCore.healthMode(false,31,20,95)
        check(actual,false,"health_False_31_20_95")
    end
    do -- health_False_31_30_80
        local actual = MathCore.healthMode(false,31,30,80)
        check(actual,false,"health_False_31_30_80")
    end
    do -- health_False_31_30_85
        local actual = MathCore.healthMode(false,31,30,85)
        check(actual,false,"health_False_31_30_85")
    end
    do -- health_False_31_30_95
        local actual = MathCore.healthMode(false,31,30,95)
        check(actual,false,"health_False_31_30_95")
    end
    do -- health_False_50_20_80
        local actual = MathCore.healthMode(false,50,20,80)
        check(actual,false,"health_False_50_20_80")
    end
    do -- health_False_50_20_85
        local actual = MathCore.healthMode(false,50,20,85)
        check(actual,false,"health_False_50_20_85")
    end
    do -- health_False_50_20_95
        local actual = MathCore.healthMode(false,50,20,95)
        check(actual,false,"health_False_50_20_95")
    end
    do -- health_False_50_30_80
        local actual = MathCore.healthMode(false,50,30,80)
        check(actual,false,"health_False_50_30_80")
    end
    do -- health_False_50_30_85
        local actual = MathCore.healthMode(false,50,30,85)
        check(actual,false,"health_False_50_30_85")
    end
    do -- health_False_50_30_95
        local actual = MathCore.healthMode(false,50,30,95)
        check(actual,false,"health_False_50_30_95")
    end
    do -- health_False_75_20_80
        local actual = MathCore.healthMode(false,75,20,80)
        check(actual,false,"health_False_75_20_80")
    end
    do -- health_False_75_20_85
        local actual = MathCore.healthMode(false,75,20,85)
        check(actual,false,"health_False_75_20_85")
    end
    do -- health_False_75_20_95
        local actual = MathCore.healthMode(false,75,20,95)
        check(actual,false,"health_False_75_20_95")
    end
    do -- health_False_75_30_80
        local actual = MathCore.healthMode(false,75,30,80)
        check(actual,false,"health_False_75_30_80")
    end
    do -- health_False_75_30_85
        local actual = MathCore.healthMode(false,75,30,85)
        check(actual,false,"health_False_75_30_85")
    end
    do -- health_False_75_30_95
        local actual = MathCore.healthMode(false,75,30,95)
        check(actual,false,"health_False_75_30_95")
    end
    do -- health_False_84_20_80
        local actual = MathCore.healthMode(false,84,20,80)
        check(actual,false,"health_False_84_20_80")
    end
    do -- health_False_84_20_85
        local actual = MathCore.healthMode(false,84,20,85)
        check(actual,false,"health_False_84_20_85")
    end
    do -- health_False_84_20_95
        local actual = MathCore.healthMode(false,84,20,95)
        check(actual,false,"health_False_84_20_95")
    end
    do -- health_False_84_30_80
        local actual = MathCore.healthMode(false,84,30,80)
        check(actual,false,"health_False_84_30_80")
    end
    do -- health_False_84_30_85
        local actual = MathCore.healthMode(false,84,30,85)
        check(actual,false,"health_False_84_30_85")
    end
    do -- health_False_84_30_95
        local actual = MathCore.healthMode(false,84,30,95)
        check(actual,false,"health_False_84_30_95")
    end
    do -- health_False_85_20_80
        local actual = MathCore.healthMode(false,85,20,80)
        check(actual,false,"health_False_85_20_80")
    end
    do -- health_False_85_20_85
        local actual = MathCore.healthMode(false,85,20,85)
        check(actual,false,"health_False_85_20_85")
    end
    do -- health_False_85_20_95
        local actual = MathCore.healthMode(false,85,20,95)
        check(actual,false,"health_False_85_20_95")
    end
    do -- health_False_85_30_80
        local actual = MathCore.healthMode(false,85,30,80)
        check(actual,false,"health_False_85_30_80")
    end
    do -- health_False_85_30_85
        local actual = MathCore.healthMode(false,85,30,85)
        check(actual,false,"health_False_85_30_85")
    end
    do -- health_False_85_30_95
        local actual = MathCore.healthMode(false,85,30,95)
        check(actual,false,"health_False_85_30_95")
    end
    do -- health_False_86_20_80
        local actual = MathCore.healthMode(false,86,20,80)
        check(actual,false,"health_False_86_20_80")
    end
    do -- health_False_86_20_85
        local actual = MathCore.healthMode(false,86,20,85)
        check(actual,false,"health_False_86_20_85")
    end
    do -- health_False_86_20_95
        local actual = MathCore.healthMode(false,86,20,95)
        check(actual,false,"health_False_86_20_95")
    end
    do -- health_False_86_30_80
        local actual = MathCore.healthMode(false,86,30,80)
        check(actual,false,"health_False_86_30_80")
    end
    do -- health_False_86_30_85
        local actual = MathCore.healthMode(false,86,30,85)
        check(actual,false,"health_False_86_30_85")
    end
    do -- health_False_86_30_95
        local actual = MathCore.healthMode(false,86,30,95)
        check(actual,false,"health_False_86_30_95")
    end
    do -- health_False_100_20_80
        local actual = MathCore.healthMode(false,100,20,80)
        check(actual,false,"health_False_100_20_80")
    end
    do -- health_False_100_20_85
        local actual = MathCore.healthMode(false,100,20,85)
        check(actual,false,"health_False_100_20_85")
    end
    do -- health_False_100_20_95
        local actual = MathCore.healthMode(false,100,20,95)
        check(actual,false,"health_False_100_20_95")
    end
    do -- health_False_100_30_80
        local actual = MathCore.healthMode(false,100,30,80)
        check(actual,false,"health_False_100_30_80")
    end
    do -- health_False_100_30_85
        local actual = MathCore.healthMode(false,100,30,85)
        check(actual,false,"health_False_100_30_85")
    end
    do -- health_False_100_30_95
        local actual = MathCore.healthMode(false,100,30,95)
        check(actual,false,"health_False_100_30_95")
    end
    do -- health_True_0_20_80
        local actual = MathCore.healthMode(true,0,20,80)
        check(actual,true,"health_True_0_20_80")
    end
    do -- health_True_0_20_85
        local actual = MathCore.healthMode(true,0,20,85)
        check(actual,true,"health_True_0_20_85")
    end
    do -- health_True_0_20_95
        local actual = MathCore.healthMode(true,0,20,95)
        check(actual,true,"health_True_0_20_95")
    end
    do -- health_True_0_30_80
        local actual = MathCore.healthMode(true,0,30,80)
        check(actual,true,"health_True_0_30_80")
    end
    do -- health_True_0_30_85
        local actual = MathCore.healthMode(true,0,30,85)
        check(actual,true,"health_True_0_30_85")
    end
    do -- health_True_0_30_95
        local actual = MathCore.healthMode(true,0,30,95)
        check(actual,true,"health_True_0_30_95")
    end
    do -- health_True_10_20_80
        local actual = MathCore.healthMode(true,10,20,80)
        check(actual,true,"health_True_10_20_80")
    end
    do -- health_True_10_20_85
        local actual = MathCore.healthMode(true,10,20,85)
        check(actual,true,"health_True_10_20_85")
    end
    do -- health_True_10_20_95
        local actual = MathCore.healthMode(true,10,20,95)
        check(actual,true,"health_True_10_20_95")
    end
    do -- health_True_10_30_80
        local actual = MathCore.healthMode(true,10,30,80)
        check(actual,true,"health_True_10_30_80")
    end
    do -- health_True_10_30_85
        local actual = MathCore.healthMode(true,10,30,85)
        check(actual,true,"health_True_10_30_85")
    end
    do -- health_True_10_30_95
        local actual = MathCore.healthMode(true,10,30,95)
        check(actual,true,"health_True_10_30_95")
    end
    do -- health_True_29_20_80
        local actual = MathCore.healthMode(true,29,20,80)
        check(actual,true,"health_True_29_20_80")
    end
    do -- health_True_29_20_85
        local actual = MathCore.healthMode(true,29,20,85)
        check(actual,true,"health_True_29_20_85")
    end
    do -- health_True_29_20_95
        local actual = MathCore.healthMode(true,29,20,95)
        check(actual,true,"health_True_29_20_95")
    end
    do -- health_True_29_30_80
        local actual = MathCore.healthMode(true,29,30,80)
        check(actual,true,"health_True_29_30_80")
    end
    do -- health_True_29_30_85
        local actual = MathCore.healthMode(true,29,30,85)
        check(actual,true,"health_True_29_30_85")
    end
    do -- health_True_29_30_95
        local actual = MathCore.healthMode(true,29,30,95)
        check(actual,true,"health_True_29_30_95")
    end
    do -- health_True_30_20_80
        local actual = MathCore.healthMode(true,30,20,80)
        check(actual,true,"health_True_30_20_80")
    end
    do -- health_True_30_20_85
        local actual = MathCore.healthMode(true,30,20,85)
        check(actual,true,"health_True_30_20_85")
    end
    do -- health_True_30_20_95
        local actual = MathCore.healthMode(true,30,20,95)
        check(actual,true,"health_True_30_20_95")
    end
    do -- health_True_30_30_80
        local actual = MathCore.healthMode(true,30,30,80)
        check(actual,true,"health_True_30_30_80")
    end
    do -- health_True_30_30_85
        local actual = MathCore.healthMode(true,30,30,85)
        check(actual,true,"health_True_30_30_85")
    end
    do -- health_True_30_30_95
        local actual = MathCore.healthMode(true,30,30,95)
        check(actual,true,"health_True_30_30_95")
    end
    do -- health_True_31_20_80
        local actual = MathCore.healthMode(true,31,20,80)
        check(actual,true,"health_True_31_20_80")
    end
    do -- health_True_31_20_85
        local actual = MathCore.healthMode(true,31,20,85)
        check(actual,true,"health_True_31_20_85")
    end
    do -- health_True_31_20_95
        local actual = MathCore.healthMode(true,31,20,95)
        check(actual,true,"health_True_31_20_95")
    end
    do -- health_True_31_30_80
        local actual = MathCore.healthMode(true,31,30,80)
        check(actual,true,"health_True_31_30_80")
    end
    do -- health_True_31_30_85
        local actual = MathCore.healthMode(true,31,30,85)
        check(actual,true,"health_True_31_30_85")
    end
    do -- health_True_31_30_95
        local actual = MathCore.healthMode(true,31,30,95)
        check(actual,true,"health_True_31_30_95")
    end
    do -- health_True_50_20_80
        local actual = MathCore.healthMode(true,50,20,80)
        check(actual,true,"health_True_50_20_80")
    end
    do -- health_True_50_20_85
        local actual = MathCore.healthMode(true,50,20,85)
        check(actual,true,"health_True_50_20_85")
    end
    do -- health_True_50_20_95
        local actual = MathCore.healthMode(true,50,20,95)
        check(actual,true,"health_True_50_20_95")
    end
    do -- health_True_50_30_80
        local actual = MathCore.healthMode(true,50,30,80)
        check(actual,true,"health_True_50_30_80")
    end
    do -- health_True_50_30_85
        local actual = MathCore.healthMode(true,50,30,85)
        check(actual,true,"health_True_50_30_85")
    end
    do -- health_True_50_30_95
        local actual = MathCore.healthMode(true,50,30,95)
        check(actual,true,"health_True_50_30_95")
    end
    do -- health_True_75_20_80
        local actual = MathCore.healthMode(true,75,20,80)
        check(actual,true,"health_True_75_20_80")
    end
    do -- health_True_75_20_85
        local actual = MathCore.healthMode(true,75,20,85)
        check(actual,true,"health_True_75_20_85")
    end
    do -- health_True_75_20_95
        local actual = MathCore.healthMode(true,75,20,95)
        check(actual,true,"health_True_75_20_95")
    end
    do -- health_True_75_30_80
        local actual = MathCore.healthMode(true,75,30,80)
        check(actual,true,"health_True_75_30_80")
    end
    do -- health_True_75_30_85
        local actual = MathCore.healthMode(true,75,30,85)
        check(actual,true,"health_True_75_30_85")
    end
    do -- health_True_75_30_95
        local actual = MathCore.healthMode(true,75,30,95)
        check(actual,true,"health_True_75_30_95")
    end
    do -- health_True_84_20_80
        local actual = MathCore.healthMode(true,84,20,80)
        check(actual,false,"health_True_84_20_80")
    end
    do -- health_True_84_20_85
        local actual = MathCore.healthMode(true,84,20,85)
        check(actual,true,"health_True_84_20_85")
    end
    do -- health_True_84_20_95
        local actual = MathCore.healthMode(true,84,20,95)
        check(actual,true,"health_True_84_20_95")
    end
    do -- health_True_84_30_80
        local actual = MathCore.healthMode(true,84,30,80)
        check(actual,false,"health_True_84_30_80")
    end
    do -- health_True_84_30_85
        local actual = MathCore.healthMode(true,84,30,85)
        check(actual,true,"health_True_84_30_85")
    end
    do -- health_True_84_30_95
        local actual = MathCore.healthMode(true,84,30,95)
        check(actual,true,"health_True_84_30_95")
    end
    do -- health_True_85_20_80
        local actual = MathCore.healthMode(true,85,20,80)
        check(actual,false,"health_True_85_20_80")
    end
    do -- health_True_85_20_85
        local actual = MathCore.healthMode(true,85,20,85)
        check(actual,false,"health_True_85_20_85")
    end
    do -- health_True_85_20_95
        local actual = MathCore.healthMode(true,85,20,95)
        check(actual,true,"health_True_85_20_95")
    end
    do -- health_True_85_30_80
        local actual = MathCore.healthMode(true,85,30,80)
        check(actual,false,"health_True_85_30_80")
    end
    do -- health_True_85_30_85
        local actual = MathCore.healthMode(true,85,30,85)
        check(actual,false,"health_True_85_30_85")
    end
    do -- health_True_85_30_95
        local actual = MathCore.healthMode(true,85,30,95)
        check(actual,true,"health_True_85_30_95")
    end
    do -- health_True_86_20_80
        local actual = MathCore.healthMode(true,86,20,80)
        check(actual,false,"health_True_86_20_80")
    end
    do -- health_True_86_20_85
        local actual = MathCore.healthMode(true,86,20,85)
        check(actual,false,"health_True_86_20_85")
    end
    do -- health_True_86_20_95
        local actual = MathCore.healthMode(true,86,20,95)
        check(actual,true,"health_True_86_20_95")
    end
    do -- health_True_86_30_80
        local actual = MathCore.healthMode(true,86,30,80)
        check(actual,false,"health_True_86_30_80")
    end
    do -- health_True_86_30_85
        local actual = MathCore.healthMode(true,86,30,85)
        check(actual,false,"health_True_86_30_85")
    end
    do -- health_True_86_30_95
        local actual = MathCore.healthMode(true,86,30,95)
        check(actual,true,"health_True_86_30_95")
    end
    do -- health_True_100_20_80
        local actual = MathCore.healthMode(true,100,20,80)
        check(actual,false,"health_True_100_20_80")
    end
    do -- health_True_100_20_85
        local actual = MathCore.healthMode(true,100,20,85)
        check(actual,false,"health_True_100_20_85")
    end
    do -- health_True_100_20_95
        local actual = MathCore.healthMode(true,100,20,95)
        check(actual,false,"health_True_100_20_95")
    end
    do -- health_True_100_30_80
        local actual = MathCore.healthMode(true,100,30,80)
        check(actual,false,"health_True_100_30_80")
    end
    do -- health_True_100_30_85
        local actual = MathCore.healthMode(true,100,30,85)
        check(actual,false,"health_True_100_30_85")
    end
    do -- health_True_100_30_95
        local actual = MathCore.healthMode(true,100,30,95)
        check(actual,false,"health_True_100_30_95")
    end
    do -- range_-1_3_False
        local actual = MathCore.segmentClear(-1,3,false)
        check(actual,false,"range_-1_3_False")
    end
    do -- range_-1_3_True
        local actual = MathCore.segmentClear(-1,3,true)
        check(actual,false,"range_-1_3_True")
    end
    do -- range_-1_7_False
        local actual = MathCore.segmentClear(-1,7,false)
        check(actual,false,"range_-1_7_False")
    end
    do -- range_-1_7_True
        local actual = MathCore.segmentClear(-1,7,true)
        check(actual,false,"range_-1_7_True")
    end
    do -- range_-1_15_False
        local actual = MathCore.segmentClear(-1,15,false)
        check(actual,false,"range_-1_15_False")
    end
    do -- range_-1_15_True
        local actual = MathCore.segmentClear(-1,15,true)
        check(actual,false,"range_-1_15_True")
    end
    do -- range_0_3_False
        local actual = MathCore.segmentClear(0,3,false)
        check(actual,false,"range_0_3_False")
    end
    do -- range_0_3_True
        local actual = MathCore.segmentClear(0,3,true)
        check(actual,true,"range_0_3_True")
    end
    do -- range_0_7_False
        local actual = MathCore.segmentClear(0,7,false)
        check(actual,false,"range_0_7_False")
    end
    do -- range_0_7_True
        local actual = MathCore.segmentClear(0,7,true)
        check(actual,true,"range_0_7_True")
    end
    do -- range_0_15_False
        local actual = MathCore.segmentClear(0,15,false)
        check(actual,false,"range_0_15_False")
    end
    do -- range_0_15_True
        local actual = MathCore.segmentClear(0,15,true)
        check(actual,true,"range_0_15_True")
    end
    do -- range_2_3_False
        local actual = MathCore.segmentClear(2,3,false)
        check(actual,false,"range_2_3_False")
    end
    do -- range_2_3_True
        local actual = MathCore.segmentClear(2,3,true)
        check(actual,true,"range_2_3_True")
    end
    do -- range_2_7_False
        local actual = MathCore.segmentClear(2,7,false)
        check(actual,false,"range_2_7_False")
    end
    do -- range_2_7_True
        local actual = MathCore.segmentClear(2,7,true)
        check(actual,true,"range_2_7_True")
    end
    do -- range_2_15_False
        local actual = MathCore.segmentClear(2,15,false)
        check(actual,false,"range_2_15_False")
    end
    do -- range_2_15_True
        local actual = MathCore.segmentClear(2,15,true)
        check(actual,true,"range_2_15_True")
    end
    do -- range_5_3_False
        local actual = MathCore.segmentClear(5,3,false)
        check(actual,false,"range_5_3_False")
    end
    do -- range_5_3_True
        local actual = MathCore.segmentClear(5,3,true)
        check(actual,false,"range_5_3_True")
    end
    do -- range_5_7_False
        local actual = MathCore.segmentClear(5,7,false)
        check(actual,false,"range_5_7_False")
    end
    do -- range_5_7_True
        local actual = MathCore.segmentClear(5,7,true)
        check(actual,true,"range_5_7_True")
    end
    do -- range_5_15_False
        local actual = MathCore.segmentClear(5,15,false)
        check(actual,false,"range_5_15_False")
    end
    do -- range_5_15_True
        local actual = MathCore.segmentClear(5,15,true)
        check(actual,true,"range_5_15_True")
    end
    do -- range_7_3_False
        local actual = MathCore.segmentClear(7,3,false)
        check(actual,false,"range_7_3_False")
    end
    do -- range_7_3_True
        local actual = MathCore.segmentClear(7,3,true)
        check(actual,false,"range_7_3_True")
    end
    do -- range_7_7_False
        local actual = MathCore.segmentClear(7,7,false)
        check(actual,false,"range_7_7_False")
    end
    do -- range_7_7_True
        local actual = MathCore.segmentClear(7,7,true)
        check(actual,true,"range_7_7_True")
    end
    do -- range_7_15_False
        local actual = MathCore.segmentClear(7,15,false)
        check(actual,false,"range_7_15_False")
    end
    do -- range_7_15_True
        local actual = MathCore.segmentClear(7,15,true)
        check(actual,true,"range_7_15_True")
    end
    do -- range_8_3_False
        local actual = MathCore.segmentClear(8,3,false)
        check(actual,false,"range_8_3_False")
    end
    do -- range_8_3_True
        local actual = MathCore.segmentClear(8,3,true)
        check(actual,false,"range_8_3_True")
    end
    do -- range_8_7_False
        local actual = MathCore.segmentClear(8,7,false)
        check(actual,false,"range_8_7_False")
    end
    do -- range_8_7_True
        local actual = MathCore.segmentClear(8,7,true)
        check(actual,false,"range_8_7_True")
    end
    do -- range_8_15_False
        local actual = MathCore.segmentClear(8,15,false)
        check(actual,false,"range_8_15_False")
    end
    do -- range_8_15_True
        local actual = MathCore.segmentClear(8,15,true)
        check(actual,true,"range_8_15_True")
    end
    do -- range_15_3_False
        local actual = MathCore.segmentClear(15,3,false)
        check(actual,false,"range_15_3_False")
    end
    do -- range_15_3_True
        local actual = MathCore.segmentClear(15,3,true)
        check(actual,false,"range_15_3_True")
    end
    do -- range_15_7_False
        local actual = MathCore.segmentClear(15,7,false)
        check(actual,false,"range_15_7_False")
    end
    do -- range_15_7_True
        local actual = MathCore.segmentClear(15,7,true)
        check(actual,false,"range_15_7_True")
    end
    do -- range_15_15_False
        local actual = MathCore.segmentClear(15,15,false)
        check(actual,false,"range_15_15_False")
    end
    do -- range_15_15_True
        local actual = MathCore.segmentClear(15,15,true)
        check(actual,true,"range_15_15_True")
    end
    return passed
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
local deadline=os.clock()+20
while not player and os.clock()<deadline do task.wait(.2);player=Players.LocalPlayer end
assert(player, "Quantum Nova: LocalPlayer unavailable")
local playerGui = player:WaitForChild("PlayerGui",20)
assert(playerGui, "Quantum Nova: PlayerGui unavailable")
local existing = playerGui:FindFirstChild("QuantumNova")
if existing then existing:Destroy() end
local C={
    bg=Color3.fromRGB(13,14,23), panel=Color3.fromRGB(23,25,39),
    item=Color3.fromRGB(33,36,54), accent=Color3.fromRGB(127,92,255),
    accent2=Color3.fromRGB(53,189,235), text=Color3.fromRGB(240,241,252),
    muted=Color3.fromRGB(157,165,192), good=Color3.fromRGB(73,211,152),
    bad=Color3.fromRGB(242,97,122), stroke=Color3.fromRGB(52,55,78)
}
local cfg={farm=false,fruit=false,chest=false,heal=false,path=true,marker=false,
    radius=350,hitRange=7,attackInterval=.23,minHealth=30,recoverHealth=85,
    filter="",weapon="",fruitFilter="",bossOnly=false,ignoreBosses=false,
    timeout=35,stuckTimeout=8,retryDelay=15,scanInterval=.65,
    fruitMarks=false,chestMarks=false,npcMarks=false,markDistance=300,
    markLimit=20,showStats=true,reduceEffects=false,lowShadows=false,
    autoClearLog=false,notifyFruit=false,uiScale=1,logLimit=50}
cfg.predict=true
cfg.predictionLimit=.22
cfg.velocityTau=.18
cfg.maxLead=5
cfg.lineOfSight=true
cfg.equipDelay=.12
cfg.releaseDelay=.06
cfg.targetWeight=true
cfg.standoff=4
cfg.pathInterval=1.0
cfg.moveInterval=.12
cfg.pathShift=8
cfg.engineInterval=.05
cfg.manualTimeout=90
cfg.adaptive=true
cfg.manualOverride=true
cfg.showMetrics=true
cfg.autoQuest=false
cfg.questRequest=false
cfg.raidAssist=false
cfg.bountyAssist=false
cfg.bountyName=""
cfg.autoRace3=false
cfg.autoRace4=false
cfg.eventWatch=false
cfg.eventName=""
cfg.autoStats=false
cfg.statName="Melee"
cfg.statBatch=1
cfg.statReserve=0
cfg.flight=true
cfg.flightSpeed=115
cfg.flightBrake=9
cfg.flightAvoid=true
cfg.flightNoclip=true
local defaults=table.clone(cfg)
local expansion
local state={alive=true,target=nil,targetSince=0,lastAttack=0,lastMove=0,
    lastSearch=0,lastError=0,retreat=false,goal=nil,pathAt=0,pathBusy=false,
    waypoints=nil,waypoint=1,kills=0,attacks=0,errors=0,mode="Pronto",
    excluded={},char=nil,generation=0,paused=false,manualGoal=nil,
    chestCache={},progressTime=0,progressPosition=nil,fps=0,
    log={},started=os.clock(),markers={},fruitSeen={},waymarks={},
    originalEffects={},view="Dashboard",selectedTool=nil}
state.metrics={attempts=0,confirmed=0,unconfirmed=0,blocked=0,paths=0,pathFailures=0,stuck=0,searches=0,manualStops=0}
state.track=nil
state.pendingAttack=nil
state.equipAt=0
state.lastTool=nil
state.pathToken=0
state.manualStarted=0
state.lastManualInput=0
state.lastAttackReason="Pronto"
local conns={}
state.errorByLabel={}
state.lastIssue="Nessun errore registrato"
state.moduleStatus={}
state.engineBusy=false
state.lastScanCount=0
state.lastScanReject={}
state.engineCycles=0
-- One controller for all movement modes. Constraints are local and never anchor the character.
state.flight={root=nil,hum=nil,attachment=nil,velocity=nil,goal=nil,untilTime=0,
    smoothed=Vector3.new(0,0,0),status="Pronto",obstacles=0,detour=nil,detourUntil=0,
    collisionParts={},collisionOwner=nil,nextPartScan=0,collisionCount=0}
do
    local F=state.flight
    local zero=Vector3.new(0,0,0)
    -- Keep original values, including false, and only touch our character.
    function F.restoreCollisions()
        for part,original in pairs(F.collisionParts) do
            pcall(function() part.CanCollide=original end)
        end
        table.clear(F.collisionParts)
        F.collisionOwner=nil;F.nextPartScan=0;F.collisionCount=0
    end
    function F.syncCollisions(now)
        local owner=F.root and F.root.Parent
        if not cfg.flightNoclip or not cfg.flight or not owner or owner~=player.Character then
            if F.collisionOwner then F.restoreCollisions() end
            return
        end
        if F.collisionOwner~=owner then
            F.restoreCollisions()
            F.collisionOwner=owner
        end
        if now>=F.nextPartScan then
            F.nextPartScan=now+.25
            for _,part in ipairs(owner:GetDescendants()) do
                if part:IsA("BasePart") and F.collisionParts[part]==nil then
                    F.collisionParts[part]=part.CanCollide
                end
            end
        end
        local count=0
        for part,original in pairs(F.collisionParts) do
            if not part:IsDescendantOf(owner) then
                pcall(function() part.CanCollide=original end)
                F.collisionParts[part]=nil
            else
                if part.CanCollide then part.CanCollide=false end
                count=count+1
            end
        end
        F.collisionCount=count
    end
    function F.stop(h,r)
        F.restoreCollisions()
        F.goal=nil;F.untilTime=0;F.detour=nil;F.detourUntil=0;F.smoothed=zero
        local had=F.velocity~=nil
        if F.velocity then F.velocity:Destroy();F.velocity=nil end
        if F.attachment then F.attachment:Destroy();F.attachment=nil end
        if had and F.root and F.root.Parent then
            pcall(function() F.root.AssemblyLinearVelocity=zero end)
        end
        F.root=nil;F.hum=nil
        if h and r and h.Parent then h:MoveTo(r.Position) end
        F.status="Fermo"
    end
    function F.command(h,r,goal,now)
        if not r or not h or not goal or r.Anchored or h.SeatPart then
            F.stop(h,r);F.status="Volo indisponibile (ancorato o seduto)";return false
        end
        if F.root~=r or not F.velocity or not F.velocity.Parent then
            F.stop()
            local a=Instance.new("Attachment")
            a.Name="NovaFlightAttachment";a.Parent=r
            F.attachment=a;F.root=r;F.hum=h
            local v=Instance.new("LinearVelocity")
            F.velocity=v
            v.Name="NovaFlightVelocity"
            v.Attachment0=a
            v.RelativeTo=Enum.ActuatorRelativeTo.World
            v.VelocityConstraintMode=Enum.VelocityConstraintMode.Vector
            v.MaxForce=math.max(10000,r.AssemblyMass*(workspace.Gravity+900))
            v.VectorVelocity=zero
            v.Parent=r
            h:MoveTo(r.Position)
        end
        if F.goal and (goal-F.goal).Magnitude>20 then F.detour=nil;F.detourUntil=0 end
        F.goal=goal;F.untilTime=now+.8
        F.syncCollisions(now)
        return true
    end
    function F.hold(h,r,now)
        if cfg.flight then
            if F.command(h,r,r.Position,now) then
                F.detour=nil;F.detourUntil=0;F.smoothed=zero;F.velocity.VectorVelocity=zero;F.status="Hover"
            end
        else
            F.stop(h,r)
        end
    end
    function F.step(dt)
        if not F.velocity then return end
        local r,h=F.root,F.hum
        local now=os.clock()
        if not state.alive or state.paused or not cfg.flight or not F.velocity.Parent or now>F.untilTime
            or not r or not r.Parent or not h or not h.Parent or h.Health<=0
            or r.Anchored or h.SeatPart or r.Parent~=player.Character then
            F.stop();return
        end
        if not F.goal then F.stop();return end
        F.syncCollisions(now)
        local delta=F.goal-r.Position
        local dist=delta.Magnitude
        if dist<.35 then
            F.smoothed=zero;F.velocity.VectorVelocity=zero;F.status="Hover";return
        end
        local destination=F.goal
        local params
        if cfg.flightAvoid and not cfg.flightNoclip then
            params=RaycastParams.new()
            params.FilterType=Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances={r.Parent}
            params.RespectCanCollide=true
            if F.detour and now<F.detourUntil and (F.detour-r.Position).Magnitude>2 then
                destination=F.detour
            else
                F.detour=nil
                local probe=math.min(dist,math.max(10,cfg.flightSpeed*.32))
                local hit=workspace:Raycast(r.Position,delta.Unit*probe,params)
                if hit and (F.goal-hit.Position).Magnitude>3 then
                    F.obstacles=F.obstacles+1
                    -- Normal flight only: try open space above or to either side.
                    local right=delta.Unit:Cross(Vector3.new(0,1,0))
                    if right.Magnitude<.1 then right=Vector3.new(1,0,0) else right=right.Unit end
                    for _,offset in ipairs({Vector3.new(0,15,0),right*15,-right*15,Vector3.new(0,-10,0)}) do
                        if not workspace:Raycast(r.Position,offset,params) then
                            F.detour=r.Position+offset;F.detourUntil=now+1.5;break
                        end
                    end
                    if not F.detour then
                        F.smoothed=zero;F.velocity.VectorVelocity=zero;F.status="Ostacolo: in attesa";return
                    end
                    destination=F.detour
                end
            end
        else
            F.detour=nil;F.detourUntil=0
        end
        local d=destination-r.Position
        local length=d.Magnitude
        local speed=math.min(cfg.flightSpeed,math.max(1,length*cfg.flightBrake),math.sqrt(2*200*length))
        local desired=length>.2 and d.Unit*speed or zero
        F.smoothed=F.smoothed:Lerp(desired,1-math.exp(-math.clamp(dt,0,.1)*12))
        F.velocity.VectorVelocity=F.smoothed
        F.status=F.detour and "Volo: deviazione" or ((cfg.flightNoclip and "Volo Noclip: " or "Volo: ")..math.floor(dist).." studs")
    end
end
local function releaseAttack()
    local tool=state.lastTool
    if tool and tool.Parent then pcall(function() tool:Deactivate() end) end
    state.lastTool=nil
end
local function connect(signal,cb)
    local c=signal:Connect(cb)
    table.insert(conns,c)
    return c
end
local function make(class,parent,props)
    local o=Instance.new(class)
    for k,v in pairs(props or {}) do o[k]=v end
    o.Parent=parent
    return o
end
local function corner(o,r)
    make("UICorner",o,{CornerRadius=UDim.new(0,r or 9)})
end
local function stroke(o,colour)
    make("UIStroke",o,{Color=colour or C.stroke,Thickness=1,Transparency=.2})
end
local function text(parent,s,props)
    local p={BackgroundTransparency=1,Text=s,TextColor3=C.text,Font=Enum.Font.Gotham,
        TextSize=13,TextXAlignment=Enum.TextXAlignment.Left}
    for k,v in pairs(props or {}) do p[k]=v end
    return make("TextLabel",parent,p)
end
local function button(parent,s,props,fn)
    local p={Text=s,BackgroundColor3=C.item,TextColor3=C.text,Font=Enum.Font.GothamBold,
        TextSize=12,AutoButtonColor=true,BorderSizePixel=0}
    for k,v in pairs(props or {}) do p[k]=v end
    local b=make("TextButton",parent,p)
    corner(b,8)
    if fn then connect(b.Activated,function()
        local ok,err=pcall(fn)
        if not ok then
            state.errors=state.errors+1;state.lastIssue=tostring(err);warn("[Nova]",err)
        end
    end) end
    return b
end
local function log(s)
    table.insert(state.log,1,os.date("%H:%M:%S").."  "..tostring(s))
    while #state.log>cfg.logLimit do table.remove(state.log) end
end
local function notify(s)
    log(s)
    pcall(function()
        StarterGui:SetCore("SendNotification",{Title="Quantum Nova",Text=s,Duration=4})
    end)
end
local gui=make("ScreenGui",playerGui,{Name="QuantumNova",ResetOnSpawn=false,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=25})
local window=make("Frame",gui,{BackgroundColor3=C.bg,Size=UDim2.fromOffset(660,440),
    Position=UDim2.fromScale(.5,.5),AnchorPoint=Vector2.new(.5,.5),BorderSizePixel=0})
corner(window,16);stroke(window)
local scale=make("UIScale",window,{Scale=1})
local header=make("Frame",window,{BackgroundColor3=C.panel,Size=UDim2.new(1,0,0,61),BorderSizePixel=0})
corner(header,15)
local logo=make("Frame",header,{Size=UDim2.fromOffset(38,38),Position=UDim2.fromOffset(14,11),BackgroundColor3=C.accent,BorderSizePixel=0})
corner(logo,12)
make("UIGradient",logo,{Color=ColorSequence.new(C.accent,C.accent2),Rotation=35})
text(logo,"Q",{Size=UDim2.fromScale(1,1),TextSize=25,Font=Enum.Font.GothamBlack,TextXAlignment=Enum.TextXAlignment.Center})
text(header,"QUANTUM NOVA",{Position=UDim2.fromOffset(63,9),Size=UDim2.new(1,-265,0,24),TextSize=19,Font=Enum.Font.GothamBold})
text(header,"V4.4  /  AERO PHASE",{Position=UDim2.fromOffset(64,34),Size=UDim2.new(1,-265,0,17),TextSize=10,TextColor3=C.muted})
local mini=button(gui,"Q  NOVA",{Size=UDim2.fromOffset(90,42),Position=UDim2.fromOffset(10,90),Visible=false,BackgroundColor3=C.accent},function() window.Visible=true;gui:FindFirstChild("Mini").Visible=false end)
mini.Name="Mini"
button(header,"–",{Size=UDim2.fromOffset(34,34),Position=UDim2.new(1,-78,0,13)},function() window.Visible=false;mini.Visible=true end)
button(header,"×",{Size=UDim2.fromOffset(34,34),Position=UDim2.new(1,-39,0,13)},function() gui:Destroy() end)
local sidebar=make("ScrollingFrame",window,{Position=UDim2.fromOffset(10,72),Size=UDim2.new(0,142,1,-112),
    BackgroundColor3=C.panel,BorderSizePixel=0,ScrollBarThickness=2,CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y})
corner(sidebar,10)
make("UIPadding",sidebar,{PaddingTop=UDim.new(0,7),PaddingLeft=UDim.new(0,6),PaddingRight=UDim.new(0,6),PaddingBottom=UDim.new(0,7)})
make("UIListLayout",sidebar,{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder})
local area=make("Frame",window,{Position=UDim2.fromOffset(162,72),Size=UDim2.new(1,-172,1,-112),BackgroundTransparency=1})
local heading=text(area,"Dashboard",{Position=UDim2.fromOffset(0,0),Size=UDim2.new(.54,0,0,32),TextSize=20,Font=Enum.Font.GothamBold})
local search=make("TextBox",area,{Position=UDim2.new(.54,0,0,2),Size=UDim2.new(.46,-3,0,29),
    Text="",PlaceholderText="Cerca impostazioni...",ClearTextOnFocus=false,TextColor3=C.text,PlaceholderColor3=C.muted,
    TextSize=12,Font=Enum.Font.Gotham,BackgroundColor3=C.panel,BorderSizePixel=0})
corner(search);stroke(search)
local body=make("Frame",area,{Position=UDim2.fromOffset(0,40),Size=UDim2.new(1,0,1,-40),BackgroundTransparency=1})
local footer=text(window,"Pronto",{Position=UDim2.new(0,14,1,-32),Size=UDim2.new(1,-28,0,25),TextColor3=C.muted,TextSize=11,TextTruncate=Enum.TextTruncate.AtEnd})
local pages,tabButtons,refreshers,rows={},{},{},{}
local order=0
local function filterRows()
    local query=search.Text:lower()
    local list=rows[state.view] or {}
    for _,entry in ipairs(list) do
        entry.row.Visible=query=="" or entry.label:lower():find(query,1,true)~=nil
    end
end
local function selectTab(name)
    state.view=name
    heading.Text=name
    for n,p in pairs(pages) do
        p.Visible=n==name
        tabButtons[n].BackgroundColor3=n==name and C.accent or C.item
    end
    search.Text=""
    filterRows()
end
local function page(name,index)
    local p=make("ScrollingFrame",body,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,
        ScrollBarThickness=3,ScrollBarImageColor3=C.accent,CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,Visible=false})
    make("UIListLayout",p,{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder})
    pages[name]=p;rows[name]={}
    tabButtons[name]=button(sidebar,name,{Size=UDim2.new(1,-1,0,34),LayoutOrder=index,TextSize=12},function() selectTab(name) end)
    return p
end
connect(search:GetPropertyChangedSignal("Text"),filterRows)
local dash=page("Dashboard",1)
local farmPage=page("Farming",2)
local itemsPage=page("Frutti e oggetti",3)
local marksPage=page("Indicatori",4)
local travel=page("Navigazione",5)
local inv=page("Inventario",6)
local perf=page("Prestazioni",7)
local settings=page("Impostazioni",8)
local diagnostics=page("Diagnostica",9)
local roadmap=page("Compatibilita",12)
local advanced=page("Precisione",10)
local telemetry=page("Telemetria",11)
local function register(parent,row,label)
    for n,p in pairs(pages) do
        if p==parent then table.insert(rows[n],{row=row,label=label});break end
    end
end
local function line(parent,label,height)
    order=order+1
    local row=make("Frame",parent,{BackgroundColor3=C.panel,Size=UDim2.new(1,-6,0,height or 43),BorderSizePixel=0,LayoutOrder=order})
    corner(row,10);stroke(row)
    text(row,label,{Position=UDim2.fromOffset(12,0),Size=UDim2.new(1,-145,1,0),TextTruncate=Enum.TextTruncate.AtEnd})
    register(parent,row,label)
    return row
end
local primaryModes={farm=true,fruit=true,chest=true,autoQuest=true,raidAssist=true,bountyAssist=true}
local function toggle(parent,label,key,changed)
    local row=line(parent,label)
    local b
    local function refresh()
        b.Text=cfg[key] and "ON" or "OFF"
        b.BackgroundColor3=cfg[key] and C.accent or C.item
    end
    b=button(row,"OFF",{Size=UDim2.fromOffset(76,30),Position=UDim2.new(1,-86,.5,-15)},function()
        cfg[key]=not cfg[key]
        if cfg[key] and primaryModes[key] then
            state.paused=false;state.pauseFromManual=false;state.lastSearch=-math.huge
            for other in pairs(primaryModes) do
                if other~=key and cfg[other] then
                    cfg[other]=false
                    if refreshers[other] then refreshers[other]() end
                end
            end
            state.target=nil;state.goal=nil;state.waypoints=nil
            state.pendingAttack=nil;releaseAttack();state.flight.stop()
            state.generation=state.generation+1
        end
        refresh()
        if changed then changed(cfg[key]) end
        log(label..": "..tostring(cfg[key]))
    end)
    refreshers[key]=refresh;refresh()
end
local function field(parent,label,key,numeric,lo,hi)
    local row=line(parent,label)
    local input=make("TextBox",row,{Size=UDim2.fromOffset(124,30),Position=UDim2.new(1,-134,.5,-15),Text=tostring(cfg[key]),
        PlaceholderText=numeric and "Valore" or "Qualsiasi",ClearTextOnFocus=false,BackgroundColor3=C.item,TextColor3=C.text,TextSize=12,Font=Enum.Font.Gotham,BorderSizePixel=0})
    corner(input,7)
    local function refresh() input.Text=tostring(cfg[key]) end
    refreshers[key]=refresh
    connect(input.FocusLost,function()
        if numeric then
            local n=tonumber(input.Text)
            if n and n==n then cfg[key]=math.clamp(n,lo,hi) end
        else cfg[key]=(input.Text:match("^%s*(.-)%s*$") or ""):sub(1,80) end
        refresh()
    end)
end
local function note(parent,s,height)
    order=order+1
    local t=text(parent,s,{Size=UDim2.new(1,-9,0,height or 52),TextWrapped=true,TextColor3=C.muted,TextSize=12,LayoutOrder=order})
    register(parent,t,s)
    return t
end
local function action(parent,label,caption,fn,colour)
    local row=line(parent,label)
    return button(row,caption,{Size=UDim2.fromOffset(124,30),Position=UDim2.new(1,-134,.5,-15),BackgroundColor3=colour or C.item},fn)
end
local function block(parent,label,height)
    order=order+1
    local row=make("Frame",parent,{Size=UDim2.new(1,-6,0,height),BackgroundColor3=C.panel,BorderSizePixel=0,LayoutOrder=order})
    corner(row,10);stroke(row)
    register(parent,row,label)
    return row
end
local function stopAll()
    if expansion and expansion.stop then expansion.stop() end
    releaseAttack();state.pendingAttack=nil;state.track=nil;state.pathToken=state.pathToken+1
    for _,k in ipairs({"farm","fruit","chest","heal","marker","fruitMarks","chestMarks","npcMarks","notifyFruit"}) do
        cfg[k]=false
        if refreshers[k] then refreshers[k]() end
    end
    state.target=nil;state.goal=nil;state.manualGoal=nil;state.waypoints=nil
    state.retreat=false;state.paused=false;state.generation=state.generation+1
    local c=player.Character
    local h=c and c:FindFirstChildOfClass("Humanoid")
    local r=c and c:FindFirstChild("HumanoidRootPart")
    state.flight.stop(h,r)
    log("Arresto generale")
end
local hero=block(dash,"Panoramica",104)
local g=make("Frame",hero,{BackgroundColor3=C.accent,Size=UDim2.new(1,0,0,4),BorderSizePixel=0})
corner(g,3);make("UIGradient",g,{Color=ColorSequence.new(C.accent,C.accent2)})
text(hero,"Controllo sessione",{Position=UDim2.fromOffset(12,12),Size=UDim2.new(1,-24,0,23),Font=Enum.Font.GothamBold,TextSize=18})
local summary=text(hero,"Pronto",{Position=UDim2.fromOffset(12,40),Size=UDim2.new(1,-24,0,53),TextWrapped=true,TextColor3=C.muted,TextSize=12})
action(dash,"Arresta tutte le automazioni","STOP",stopAll,C.bad)
local pauseButton=action(dash,"Pausa / riprendi","PAUSA",function() state.paused=not state.paused;state.pauseFromManual=false;if state.paused then state.flight.stop() end;log(state.paused and "Pausa" or "Ripresa") end)
action(dash,"Azzera contatori","RESET",function() state.kills=0;state.attacks=0;state.errors=0;state.started=os.clock() end)
note(dash,"Le automazioni partono disattivate. Il server mantiene il controllo su danni, ricompense e missioni.")
toggle(farmPage,"Farm NPC visibili","farm")
toggle(farmPage,"Solo boss riconosciuti","bossOnly",function(v) if v then cfg.ignoreBosses=false;if refreshers.ignoreBosses then refreshers.ignoreBosses() end end end)
toggle(farmPage,"Ignora boss","ignoreBosses",function(v) if v then cfg.bossOnly=false;refreshers.bossOnly() end end)
toggle(farmPage,"Ritirata con poca vita","heal")
field(farmPage,"Filtro nome NPC / materiale","filter",false)
field(farmPage,"Arma per attacchi M1","weapon",false)
field(farmPage,"Intervallo attacchi (s)","attackInterval",true,.12,2)
field(farmPage,"Distanza attacco (studs)","hitRange",true,3,15)
field(farmPage,"Ritirata sotto HP %","minHealth",true,5,75)
field(farmPage,"Ripresa sopra HP %","recoverHealth",true,80,100)
note(farmPage,"Il filtro consente di selezionare NPC e boss caricati. Non garantisce ricompense, mastery o progresso missioni.")
toggle(itemsPage,"Cammina verso frutti visibili","fruit")
toggle(itemsPage,"Cammina verso forzieri","chest")
toggle(itemsPage,"Notifica nuovi frutti visibili","notifyFruit")
field(itemsPage,"Filtro nome frutto","fruitFilter",false)
note(itemsPage,"La raccolta effettiva usa le regole del gioco. Non vengono simulati tocchi o invocati eventi remoti.")
toggle(marksPage,"Evidenzia bersaglio attuale","marker")
toggle(marksPage,"Evidenzia frutti visibili","fruitMarks")
toggle(marksPage,"Evidenzia forzieri visibili","chestMarks")
toggle(marksPage,"Evidenzia NPC visibili","npcMarks")
field(marksPage,"Raggio indicatori (studs)","markDistance",true,20,1000)
field(marksPage,"Massimo indicatori","markLimit",true,1,50)
note(marksPage,"Gli indicatori sono locali, limitati agli oggetti caricati e non mostrati attraverso le pareti.")
local xBox,yBox,zBox
local coords=block(travel,"Coordinate destinazione",84)
text(coords,"Destinazione X / Y / Z",{Position=UDim2.fromOffset(12,7),Size=UDim2.new(1,-24,0,24),Font=Enum.Font.GothamBold})
local function coordinateBox(index,label)
    local b=make("TextBox",coords,{Position=UDim2.new((index-1)/3,8,0,38),Size=UDim2.new(1/3,-15,0,32),
        Text="",PlaceholderText=label,ClearTextOnFocus=false,TextColor3=C.text,BackgroundColor3=C.item,BorderSizePixel=0,TextSize=13})
    corner(b);return b
end
xBox=coordinateBox(1,"X");yBox=coordinateBox(2,"Y");zBox=coordinateBox(3,"Z")
local function readCoordinates()
    local x,y,z=tonumber(xBox.Text),tonumber(yBox.Text),tonumber(zBox.Text)
    if not MathCore.finite(x) or not MathCore.finite(y) or not MathCore.finite(z) then return end
    if math.abs(x)>100000 or math.abs(y)>100000 or math.abs(z)>100000 then return end
    return Vector3.new(x,y,z)
end
local function rootPart()
    local c=player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
action(travel,"Leggi posizione attuale","LEGGI",function()
    local r=rootPart();if not r then return end
    xBox.Text=string.format("%.1f",r.Position.X);yBox.Text=string.format("%.1f",r.Position.Y);zBox.Text=string.format("%.1f",r.Position.Z)
end)
action(travel,"Vola alla destinazione","VAI",function()
    local goal=readCoordinates();if not goal then notify("Coordinate non valide");return end
    state.target=nil;state.goal=nil;state.waypoints=nil;state.generation=state.generation+1;state.paused=false;state.manualGoal=goal;state.manualStarted=os.clock()
end)
action(travel,"Salva posizione attuale","SALVA",function()
    local r=rootPart();if not r then return end
    if #state.waymarks>=10 then table.remove(state.waymarks,1) end
    table.insert(state.waymarks,r.Position);log("Posizione salvata #"..#state.waymarks)
end)
action(travel,"Torna all'ultima posizione","TORNA",function()
    local goal=state.waymarks[#state.waymarks];if not goal then notify("Nessuna posizione salvata");return end
    state.target=nil;state.goal=nil;state.waypoints=nil;state.generation=state.generation+1;state.paused=false;state.manualGoal=goal;state.manualStarted=os.clock()
end)
action(travel,"Annulla navigazione","ANNULLA",function()
    state.manualGoal=nil;state.goal=nil;state.waypoints=nil;state.generation=state.generation+1
    local c=player.Character;local r=rootPart();local h=c and c:FindFirstChildOfClass("Humanoid");if h and r then state.flight.stop(h,r) end
end)
local confirmRejoin=0
action(travel,"Rientra nel gioco (doppio tocco)","RIENTRA",function()
    if os.clock()-confirmRejoin>5 or confirmRejoin==0 then confirmRejoin=os.clock();notify("Premi nuovamente entro 5 secondi");return end
    confirmRejoin=0;stopAll()
    local ok,err=pcall(function() TeleportService:Teleport(game.PlaceId,player) end)
    if not ok then notify("Rientro non riuscito: "..tostring(err)) end
end)
local inventoryPanel=block(inv,"Elenco strumenti",184)
local inventoryText=text(inventoryPanel,"",{Position=UDim2.fromOffset(12,9),Size=UDim2.new(1,-24,1,-18),TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,TextSize=12})
local function getTools()
    local found={}
    for _,p in ipairs({player.Character or player,player:FindFirstChildOfClass("Backpack") or player}) do
        for _,obj in ipairs(p:GetChildren()) do if obj:IsA("Tool") then table.insert(found,obj) end end
    end
    table.sort(found,function(a,b) return a.Name:lower()<b.Name:lower() end)
    return found
end
local function inventoryRefresh()
    local tools=getTools();local names={}
    for i,t in ipairs(tools) do
        if i>10 then table.insert(names,"... +"..(#tools-10).." strumenti");break end
        table.insert(names,(t.Parent==player.Character and "[E] " or "    ")..t.Name)
    end
    inventoryText.Text=#names>0 and table.concat(names,"\n") or "Nessuno strumento visibile"
end
action(inv,"Aggiorna inventario","AGGIORNA",inventoryRefresh)
action(inv,"Usa primo strumento trovato","EQUIPAGGIA",function()
    local tools=getTools();local c=player.Character;local h=c and c:FindFirstChildOfClass("Humanoid")
    if h and tools[1] then h:EquipTool(tools[1]);cfg.weapon=tools[1].Name;refreshers.weapon();inventoryRefresh() end
end)
action(inv,"Riponi strumenti","RIPONI",function()
    local c=player.Character;local h=c and c:FindFirstChildOfClass("Humanoid");if h then h:UnequipTools() end;inventoryRefresh()
end)
local savedShadows=Lighting.GlobalShadows
local function applyPerformance()
    Lighting.GlobalShadows=cfg.lowShadows and false or savedShadows
    if cfg.lowShadows then Lighting.GlobalShadows=false end
    if not cfg.reduceEffects then
        for obj,value in pairs(state.originalEffects) do if obj.Parent then pcall(function() obj.Enabled=value end) end end
        table.clear(state.originalEffects)
        return
    end
    for _,obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("PostEffect") and state.originalEffects[obj]==nil then
            state.originalEffects[obj]=obj.Enabled;obj.Enabled=false
        end
    end
end
toggle(perf,"Riduci effetti post-processing","reduceEffects",applyPerformance)
toggle(perf,"Disattiva ombre locali","lowShadows",applyPerformance)
toggle(perf,"Mostra statistiche nel footer","showStats")
note(perf,"Le modifiche grafiche sono locali e vengono ripristinate quando chiudi il pannello.")
toggle(settings,"Volo automatico","flight",function(on) if not on then state.flight.stop() end end)
field(settings,"Velocita volo (stud/s)","flightSpeed",true,15,220)
field(settings,"Frenata volo","flightBrake",true,3,15)
toggle(settings,"Noclip durante il volo","flightNoclip",function(on)
    state.flight.detour=nil;state.flight.detourUntil=0
    if not on then state.flight.restoreCollisions() end
end)
toggle(settings,"Evita ostacoli (Noclip OFF)","flightAvoid")
toggle(settings,"Pathfinding (solo camminata)","path")
note(settings,"Noclip agisce solo sulle parti del tuo personaggio durante il volo. STOP e pausa ripristinano le collisioni. Il server puo rifiutare il movimento.",80)
field(settings,"Raggio scansione (studs)","radius",true,20,1200)
field(settings,"Intervallo scansione (s)","scanInterval",true,.25,5)
field(settings,"Timeout bersaglio (s)","timeout",true,10,120)
field(settings,"Timeout movimento bloccato (s)","stuckTimeout",true,3,30)
field(settings,"Attesa nuovo tentativo (s)","retryDelay",true,5,60)
field(settings,"Scala interfaccia","uiScale",true,.65,1.25)
action(settings,"Ripristina impostazioni","DEFAULT",function()
    stopAll();for k,v in pairs(defaults) do cfg[k]=v;if refreshers[k] then refreshers[k]() end end;applyPerformance()
end)
local logPanel=block(diagnostics,"Registro sessione",210)
local logText=text(logPanel,"",{Position=UDim2.fromOffset(10,9),Size=UDim2.new(1,-20,1,-18),TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,TextSize=11})
action(diagnostics,"Cancella registro","PULISCI",function() table.clear(state.log);log("Registro pulito") end)
field(diagnostics,"Massimo righe log","logLimit",true,10,100)
local exportBox=make("TextBox",block(diagnostics,"Configurazione JSON",90),{Position=UDim2.fromOffset(10,8),Size=UDim2.new(1,-20,1,-16),Text="",ClearTextOnFocus=false,MultiLine=true,TextWrapped=true,TextColor3=C.text,BackgroundColor3=C.item,TextSize=11,TextYAlignment=Enum.TextYAlignment.Top})
corner(exportBox)
action(diagnostics,"Mostra configurazione JSON","ESPORTA",function() exportBox.Text=HttpService:JSONEncode(cfg) end)
action(diagnostics,"Importa configurazione JSON","IMPORTA",function()
    local ok,data=pcall(function() return HttpService:JSONDecode(exportBox.Text) end)
    if not ok or type(data)~="table" then notify("JSON non valido");return end
    stopAll()
    local numericRanges={flightSpeed={15,220},flightBrake={3,15},statBatch={1,25},statReserve={0,10000},predictionLimit={0,.5},velocityTau={.03,1},maxLead={0,12},equipDelay={.05,.5},releaseDelay={.03,.2},standoff={2,10},pathInterval={.4,4},moveInterval={.08,.5},pathShift={4,20},engineInterval={.03,.2},manualTimeout={10,180},radius={20,1200},hitRange={3,15},attackInterval={.12,2},minHealth={5,75},recoverHealth={80,100},timeout={10,120},stuckTimeout={3,30},retryDelay={5,60},scanInterval={.25,5},markDistance={20,1000},markLimit={1,50},uiScale={.65,1.25},logLimit={10,100}}
    local noAuto={autoQuest=true,questRequest=true,raidAssist=true,bountyAssist=true,autoRace3=true,autoRace4=true,eventWatch=true,autoStats=true,farm=true,fruit=true,chest=true,heal=true,notifyFruit=true,marker=true,fruitMarks=true,chestMarks=true,npcMarks=true}
    for k,v in pairs(data) do
        if defaults[k]~=nil and type(v)==type(defaults[k]) and not noAuto[k] then
            local range=numericRanges[k]
            if range and v==v then cfg[k]=math.clamp(v,range[1],range[2])
            elseif type(v)=="string" then cfg[k]=v:sub(1,80)
            elseif type(v)=="boolean" then cfg[k]=v end
            if refreshers[k] then refreshers[k]() end
        end
    end
    if cfg.bossOnly and cfg.ignoreBosses then cfg.ignoreBosses=false;refreshers.ignoreBosses() end
    applyPerformance();notify("Configurazione importata; automazioni disattivate")
end)
note(roadmap,"V4 aggiunge assistenti per missioni, raid, Race, PvP, eventi e statistiche. Tutte le automazioni partono OFF.",70)
note(roadmap,"Non implementati: sblocco automatico armi e razze, chip/avvio raid, awakening, Haki/Instinct, server finder, deposito frutti, cambio mare automatico e guida barche.",100)
note(roadmap,"Le richieste StartQuest e AddPoint sono sperimentali: i nomi interni possono cambiare. Nessuna verifica dentro Delta o Blox Fruits.",75)
toggle(advanced,"Predizione movimento NPC","predict")
field(advanced,"Orizzonte massimo (s)","predictionLimit",true,0,.5)
field(advanced,"Filtro velocita (s)","velocityTau",true,.03,1)
field(advanced,"Anticipo massimo (studs)","maxLead",true,0,12)
toggle(advanced,"Verifica ostacoli prima di M1","lineOfSight")
toggle(advanced,"Punteggio bersaglio avanzato","targetWeight")
field(advanced,"Distanza di arresto","standoff",true,2,10)
field(advanced,"Attesa equipaggiamento (s)","equipDelay",true,.05,.5)
field(advanced,"Durata pressione M1 (s)","releaseDelay",true,.03,.2)
field(advanced,"Aggiornamento percorso (s)","pathInterval",true,.4,4)
field(advanced,"Soglia nuovo percorso (studs)","pathShift",true,4,20)
field(advanced,"Aggiornamento movimento (s)","moveInterval",true,.08,.5)
field(advanced,"Intervallo motore (s)","engineInterval",true,.03,.2)
field(advanced,"Timeout navigazione manuale","manualTimeout",true,10,180)
toggle(advanced,"Adatta scansione a FPS bassi","adaptive")
toggle(advanced,"Pausa con input movimento","manualOverride")
note(advanced,"La predizione riguarda la navigazione verso NPC. Il volo modifica solo il movimento locale; hitbox, proiettili e cooldown del server non sono alterati.",70)
local metricsPanel=block(telemetry,"Misure motore",225)
local metricsText=text(metricsPanel,"Pronto",{Position=UDim2.fromOffset(12,10),Size=UDim2.new(1,-24,1,-20),TextYAlignment=Enum.TextYAlignment.Top,TextSize=12,TextWrapped=true})
toggle(telemetry,"Aggiorna telemetria","showMetrics")
action(telemetry,"Azzera misurazioni","RESET",function()
    for k in pairs(state.metrics) do state.metrics[k]=0 end
end)
action(telemetry,"Test matematici rapidi","TEST",function()
    local checks={MathCore.lead(100,20,.2)==.2,MathCore.cooldown(2,3,10)==10,
        MathCore.healthMode(true,50,30,85),not MathCore.healthMode(true,90,30,85),
        MathCore.score(200,100,.5,0,true,0)==math.huge,MathCore.segmentClear(5,7,true)}
    local passed=0
    for _,v in ipairs(checks) do if v then passed=passed+1 end end
    notify(string.format("Test matematici: %d/%d",passed,#checks))
end)
action(telemetry,"Esegui suite completa (834 casi)","TEST FULL",function()
    local ok,result=pcall(runFullMathTests)
    if ok then notify("Test completati: "..result.."/834") else notify("Test fallito: "..tostring(result)) end
end)
note(telemetry,"Il calo di HP osservato dopo un M1 non dimostra che il colpo sia stato causato da questo client.",56)
selectTab("Dashboard")
local dragging,dragStart,origin=false,nil,nil
connect(header.InputBegan,function(i)
    if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=i;dragStart=i.Position;origin=window.Position
    end
end)
connect(UserInputService.InputChanged,function(i)
    if dragging and (i==dragging or (dragging.UserInputType==Enum.UserInputType.MouseButton1 and i.UserInputType==Enum.UserInputType.MouseMovement)) then
        local d=i.Position-dragStart
        window.Position=UDim2.new(origin.X.Scale,origin.X.Offset+d.X,origin.Y.Scale,origin.Y.Offset+d.Y)
    end
end)
connect(UserInputService.InputEnded,function(i) if i==dragging then dragging=false end end)
local function fit()
    local cam=workspace.CurrentCamera;if not cam then return end
    local v=cam.ViewportSize
    scale.Scale=math.clamp(math.min(cfg.uiScale,(v.X-20)/660,(v.Y-25)/440),.2,1.25)
end
fit()
connect(UserInputService.InputBegan,function(i,processed)
    if not processed and i.KeyCode==Enum.KeyCode.RightShift then window.Visible=not window.Visible;mini.Visible=not window.Visible end
end)
local function character()
    local c=player.Character;if not c then return end
    local h=c:FindFirstChildOfClass("Humanoid");local r=c:FindFirstChild("HumanoidRootPart")
    if h and r and h.Health>0 then return c,h,r end
end
local function findRoot(model)
    if model:IsA("BasePart") then return model end
    if model:IsA("Model") then return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart",true) end
    if model:IsA("Tool") then return model:FindFirstChild("Handle") end
end
local function validTarget(t)
    if not t or not t.obj.Parent or not t.part:IsDescendantOf(workspace) then return false end
    return not t.hum or (t.hum.Parent and t.hum.Health>0)
end
local function isExcluded(obj,now)
    local untilTime=state.excluded[obj];if not untilTime then return false end
    if untilTime<=now then state.excluded[obj]=nil;return false end
    return true
end
local function clearLine(root,part,obj)
    local direction=part.Position-root.Position
    if direction.Magnitude<.1 then return true end
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={player.Character}
    params.IgnoreWater=true
    local hit=workspace:Raycast(root.Position,direction,params)
    return not hit or hit.Instance==part or hit.Instance:IsDescendantOf(obj)
end
local function predictedPosition(t,root,now)
    if not cfg.predict or t.kind~="NPC" then return t.part.Position end
    local pos=t.part.Position
    local tr=state.track
    if not tr or tr.obj~=t.obj then
        state.track={obj=t.obj,pos=pos,velocity=Vector3.zero,time=now}
        return pos
    end
    local dt=now-tr.time
    if dt>=.025 then
        local raw=(pos-tr.pos)/dt
        if raw.Magnitude>100 or dt>.6 then
            tr.velocity=Vector3.zero
        else
            tr.velocity=tr.velocity:Lerp(raw,MathCore.alpha(dt,cfg.velocityTau))
        end
        tr.pos=pos;tr.time=now
    end
    local lead=MathCore.lead((pos-root.Position).Magnitude,16,cfg.predictionLimit)
    local offset=tr.velocity*lead
    offset=Vector3.new(offset.X,0,offset.Z)
    if offset.Magnitude>cfg.maxLead and offset.Magnitude>0 then offset=offset.Unit*cfg.maxLead end
    return pos+offset
end
local function chooseTarget(root,now)
    local best,bestDistance=nil,math.huge
    state.lastScanCount=0
    state.lastScanReject={range=0,excluded=0,root=0}
    state.metrics.searches=state.metrics.searches+1
    local function consider(obj,part,kind,hum)
        state.lastScanCount=state.lastScanCount+1
        if not part or not part:IsA("BasePart") then state.lastScanReject.root=state.lastScanReject.root+1;return end
        if isExcluded(obj,now) then state.lastScanReject.excluded=state.lastScanReject.excluded+1;return end
        local dist=(part.Position-root.Position).Magnitude
        if dist>cfg.radius then state.lastScanReject.range=state.lastScanReject.range+1;return end
        local score=dist
        if cfg.targetWeight then
            local hp=hum and hum.Health/math.max(hum.MaxHealth,1) or 0
            score=MathCore.score(dist,cfg.radius,hp,math.abs(part.Position.Y-root.Position.Y),clearLine(root,part,obj),kind=="Fruit" and -10 or 0)
        end
        if score<bestDistance then bestDistance=score;best={obj=obj,part=part,kind=kind,hum=hum} end
    end
    -- Items have priority when enabled. Only loaded world instances are scanned.
    if cfg.fruit or cfg.chest then
        for _,obj in ipairs(workspace:GetChildren()) do
            local n=obj.Name:lower()
            if cfg.fruit and obj:IsA("Tool") and n:find("fruit",1,true) and (cfg.fruitFilter=="" or n:find(cfg.fruitFilter:lower(),1,true)) then consider(obj,findRoot(obj),"Fruit")
            elseif cfg.chest and (obj:IsA("Model") or obj:IsA("BasePart")) and n:find("chest",1,true) then consider(obj,findRoot(obj),"Chest") end
        end
        local map=workspace:FindFirstChild("Map")
        if cfg.chest and map then
            -- Search only containers with explicitly recognizable chest names.
            for _,obj in ipairs(state.chestCache) do
                if obj.Name:lower():find("chest",1,true) and (obj:IsA("Model") or obj:IsA("BasePart")) then consider(obj,findRoot(obj),"Chest") end
            end
        end
    end
    if best then return best end
    if cfg.farm then
        local enemies=workspace:FindFirstChild("Enemies") or workspace:FindFirstChild("NPCs")
        if enemies then
            local filter=cfg.filter:lower()
            for _,obj in ipairs(enemies:GetChildren()) do
                if obj:IsA("Model") and not Players:GetPlayerFromCharacter(obj) and (filter=="" or obj.Name:lower():find(filter,1,true)) then
                    local h=obj:FindFirstChildOfClass("Humanoid")
                    if h and h.Health>0 then
                        local name=obj.Name:lower()
                        local boss=name:find("boss",1,true) or obj:GetAttribute("Boss")==true or obj:GetAttribute("IsBoss")==true
                        if (not cfg.bossOnly or boss) and (not cfg.ignoreBosses or not boss) then
                            consider(obj,findRoot(obj),"NPC",h)
                        end
                    end
                end
            end
        end
    end
    return best
end
local function setTarget(t,now)
    state.track=nil;releaseAttack();state.pendingAttack=nil;state.pathToken=state.pathToken+1
    state.target=t;state.targetSince=now;state.progressPosition=nil;state.progressTime=now;state.goal=nil;state.waypoints=nil;state.pathAt=0;state.generation=state.generation+1
end
local function equip(c,h)
    local query=cfg.weapon:lower();local current=c:FindFirstChildOfClass("Tool")
    local function rank(tool)
        if not tool or not tool:IsA("Tool") then return 0 end
        if query~="" then
            local n=tool.Name:lower()
            return n==query and 100 or (n:find(query,1,true) and 90 or 0)
        end
        local tip=tool.ToolTip:lower()
        if tip=="melee" then return 30 end
        if tip=="sword" then return 25 end
        if tip=="gun" or tip=="blox fruit" or tip=="devil fruit" then return 10 end
        return 0
    end
    local best,score=current,rank(current)
    local backpack=player:FindFirstChildOfClass("Backpack")
    if backpack then
        for _,tool in ipairs(backpack:GetChildren()) do
            local n=rank(tool)
            if n>score then best,score=tool,n end
        end
    end
    if score<=0 then return nil end
    if best.Parent~=c then h:EquipTool(best) end
    return best
end
local function move(h,r,goal,now)
    if not goal then return end
    if cfg.flight then state.goal=goal;state.flight.command(h,r,goal,now);return end
    if state.flight.velocity then state.flight.stop(h,r) end
    if not state.goal or (state.goal-goal).Magnitude>cfg.pathShift then state.goal=goal;state.waypoints=nil;state.pathAt=0;state.generation=state.generation+1 end
    if cfg.path and not state.pathBusy and now-state.pathAt>cfg.pathInterval and (r.Position-goal).Magnitude>12 then
        state.pathAt=now;state.pathBusy=true
        local generation=state.generation;local start=r.Position
        state.metrics.paths=state.metrics.paths+1
        task.spawn(function()
            local ok,points=pcall(function()
                local path=PathfindingService:CreatePath({AgentRadius=2,AgentHeight=5,AgentCanJump=true})
                path:ComputeAsync(start,goal)
                if path.Status==Enum.PathStatus.Success then return path:GetWaypoints() end
            end)
            if state.alive and generation==state.generation and ok and points and #points>1 then state.waypoints=points;state.waypoint=2 end
            if not ok or not points then state.metrics.pathFailures=state.metrics.pathFailures+1 end
            state.pathBusy=false
        end)
    end
    if now-state.lastMove<cfg.moveInterval then return end
    state.lastMove=now
    local dest=goal
    if cfg.path and state.waypoints then
        while state.waypoint<=#state.waypoints and (state.waypoints[state.waypoint].Position-r.Position).Magnitude<4 do state.waypoint=state.waypoint+1 end
        local w=state.waypoints[state.waypoint]
        if w then dest=w.Position;if w.Action==Enum.PathWaypointAction.Jump then h.Jump=true end end
    end
    h:MoveTo(dest)
end
local highlight=make("Highlight",gui,{Enabled=false,FillTransparency=.85,OutlineColor=C.accent,DepthMode=Enum.HighlightDepthMode.Occluded})
local function enabled(t)
    return t and ((t.kind=="NPC" and cfg.farm) or (t.kind=="Fruit" and cfg.fruit) or (t.kind=="Chest" and cfg.chest))
end
local function settleAttack(now)
    local pending=state.pendingAttack
    if not pending then return end
    if now<pending.deadline then return end
    state.pendingAttack=nil
    local hum=pending.hum
    if hum and hum.Parent and hum.Health<pending.before then
        state.metrics.confirmed=state.metrics.confirmed+1
    else
        state.metrics.unconfirmed=state.metrics.unconfirmed+1
        state.lastAttackReason="Attivazione inviata, nessun calo HP osservato"
    end
end
local function attackNPC(c,h,r,t,now)
    if cfg.lineOfSight and not clearLine(r,t.part,t.obj) then
        state.lastAttackReason="Ostacolo"
        state.metrics.blocked=state.metrics.blocked+1
        return false
    end
    if now-state.lastAttack<cfg.attackInterval then return true end
    if state.pendingAttack then state.lastAttackReason="Attendo riscontro HP";return true end
    local before=c:FindFirstChildOfClass("Tool")
    local weapon=equip(c,h)
    if not weapon then state.lastAttackReason="Arma non riconosciuta: imposta il nome esatto in Farming";return false end
    if weapon~=before or weapon~=state.equipped then
        state.equipped=weapon;state.equipAt=now
        state.lastAttackReason="Equipaggiamento"
        return true
    end
    if weapon.Parent~=c or now-state.equipAt<cfg.equipDelay or not weapon.Enabled then
        state.lastAttackReason="Attesa strumento"
        return true
    end
    releaseAttack()
    state.lastAttack=now
    state.metrics.attempts=state.metrics.attempts+1
    local healthBefore=t.hum.Health
    local ok,err=pcall(function() weapon:Activate() end)
    if not ok then state.lastAttackReason=tostring(err);state.lastIssue="M1: "..tostring(err);state.errors=state.errors+1;return false end
    state.attacks=state.attacks+1
    state.lastTool=weapon
    state.lastAttackReason="Attivazione richiesta"
    if not state.pendingAttack then
        state.pendingAttack={hum=t.hum,before=healthBefore,deadline=now+.35}
    end
    task.delay(math.min(cfg.releaseDelay,cfg.attackInterval*.7),function()
        if state.lastTool==weapon and state.lastAttack==now then releaseAttack() end
    end)
    return true
end
local function tick(now)
    settleAttack(now)
    local c,h,r=character()
    if not c then state.flight.stop();releaseAttack();state.pendingAttack=nil;state.mode="Attesa respawn";highlight.Enabled=false;return end
    if c~=state.char then state.char=c;setTarget(nil,now);state.retreat=false;state.lastSearch=0 end
    local hp=100*h.Health/math.max(h.MaxHealth,1)
    if state.paused then releaseAttack();state.flight.stop();if not state.pauseFromManual then state.flight.stop(h,r) end;state.mode=state.pauseFromManual and "Pausa input manuale: premi RIPRENDI" or "Pausa: premi RIPRENDI";highlight.Enabled=false;return end
    if not cfg.heal then state.retreat=false else state.retreat=MathCore.healthMode(state.retreat,hp,cfg.minHealth,cfg.recoverHealth) end
    if state.manualGoal and now-state.manualStarted>cfg.manualTimeout then
        state.manualGoal=nil;setTarget(nil,now);state.flight.stop(h,r);log("Timeout navigazione")
    end
    if state.manualGoal and not state.retreat then
        if (r.Position-state.manualGoal).Magnitude<4 then
            state.manualGoal=nil
            state.flight.stop(h,r)
            setTarget(nil,now)
            log("Destinazione raggiunta")
        else
            state.mode="Navigazione manuale"
            move(h,r,state.manualGoal,now)
        end
        return
    end
    if not (cfg.farm or cfg.fruit or cfg.chest) then
        state.flight.stop();releaseAttack()
        if state.target or state.goal then state.flight.stop(h,r);setTarget(nil,now) end
        state.mode="Idle";highlight.Enabled=false;return
    end
    if state.retreat then
        state.mode="Retreating | "..math.floor(hp).."% HP";highlight.Enabled=false
        local t=state.target
        if validTarget(t) and t.kind=="NPC" then
            local d=r.Position-t.part.Position;d=Vector3.new(d.X,0,d.Z)
            if d.Magnitude<45 then move(h,r,r.Position+(d.Magnitude>0.1 and d.Unit or Vector3.new(1,0,0))*35,now) else state.flight.stop(h,r) end
        else state.flight.stop(h,r) end
        return
    end
    local t=state.target
    if t and validTarget(t) and (t.part.Position-r.Position).Magnitude>cfg.hitRange then
        if not state.progressPosition or (r.Position-state.progressPosition).Magnitude>2 then
            state.progressPosition=r.Position
            state.progressTime=now
        elseif now-state.progressTime>cfg.stuckTimeout then
            state.excluded[t.obj]=now+cfg.retryDelay
            state.metrics.stuck=state.metrics.stuck+1
            log("Percorso bloccato: "..t.obj.Name)
            setTarget(nil,now)
            t=nil
        end
    else
        state.progressPosition=r.Position
        state.progressTime=now
    end
    if t and (not validTarget(t) or not enabled(t) or now-state.targetSince>cfg.timeout or (t.part.Position-r.Position).Magnitude>cfg.radius*1.4) then
        if t.hum and t.hum.Health<=0 then state.kills=state.kills+1; log("NPC terminato: "..t.obj.Name) end
        if validTarget(t) then state.excluded[t.obj]=now+cfg.retryDelay end
        setTarget(nil,now);t=nil
    end
    if not t and now-state.lastSearch>cfg.scanInterval then
        state.lastSearch=now;t=chooseTarget(r,now);setTarget(t,now)
        for obj,expiry in pairs(state.excluded) do if expiry<=now or not obj.Parent then state.excluded[obj]=nil end end
    end
    if not t then
        local rejects=state.lastScanReject
        state.mode=string.format("Nessun target | Candidati %d | Fuori raggio %d | In attesa %d",state.lastScanCount,rejects.range or 0,rejects.excluded or 0)
        highlight.Enabled=false;state.flight.stop(h,r);return
    end
    highlight.Adornee=t.obj;highlight.Enabled=cfg.marker
    local dist=(t.part.Position-r.Position).Magnitude
    state.mode=t.kind.." | "..t.obj.Name.." | "..math.floor(dist).." st"
    if t.kind=="NPC" and dist<=cfg.hitRange then
        state.flight.hold(h,r,now)
        if not attackNPC(c,h,r,t,now) then
            state.mode=state.lastAttackReason
            if cfg.lineOfSight and not clearLine(r,t.part,t.obj) then move(h,r,t.part.Position,now) end
        end
    elseif t.kind~="NPC" and dist<3 then
        -- No simulated touch or prompt bypass. Normal game pickup rules apply.
        move(h,r,t.part.Position,now)
        if now-state.targetSince>5 then state.excluded[t.obj]=now+15;setTarget(nil,now) end
    else
        local goal=predictedPosition(t,r,now)
        if t.kind=="NPC" then
            local delta=goal-r.Position
            local flat=Vector3.new(delta.X,0,delta.Z)
            if flat.Magnitude>cfg.standoff then goal=goal-flat.Unit*math.min(cfg.standoff,cfg.hitRange*.75) end
        end
        move(h,r,goal,now)
    end
end

-- V4 expansion: uses a separate controller, not a second competing movement loop.
-- Community quest command is experimental; no server-side verification available here.
expansion = {}
do
    local E = expansion
    local extra = {"autoQuest","raidAssist","bountyAssist","autoRace3","autoRace4","eventWatch","autoStats"}
    local questRows = {
        {1,1,"Bandit","BanditQuest1",1,"Bandit Quest Giver"},
        {1,10,"Monkey","JungleQuest",1,"Adventurer"},
        {1,15,"Gorilla","JungleQuest",2,"Adventurer"},
        {1,30,"Pirate","BuggyQuest1",1,"Pirate Adventurer"},
        {1,40,"Brute","BuggyQuest1",2,"Pirate Adventurer"},
        {1,60,"Desert Bandit","DesertQuest",1,"Desert Adventurer"},
        {1,75,"Desert Officer","DesertQuest",2,"Desert Adventurer"},
        {1,90,"Snow Bandit","SnowQuest",1,"Villager"},
        {1,100,"Snowman","SnowQuest",2,"Villager"},
        {1,120,"Chief Petty Officer","MarineQuest2",1,"Marine Officer"},
        {1,150,"Sky Bandit","SkyQuest",1,"Sky Adventurer"},
        {1,175,"Dark Master","SkyQuest",2,"Sky Adventurer"},
        {1,190,"Prisoner","PrisonerQuest",1,"Jail Keeper"},
        {1,210,"Dangerous Prisoner","PrisonerQuest",2,"Jail Keeper"},
        {1,250,"Toga Warrior","ColosseumQuest",1,"Colosseum Quest Giver"},
        {1,275,"Gladiator","ColosseumQuest",2,"Colosseum Quest Giver"},
        {1,300,"Military Soldier","MagmaQuest",1,"Magma Quest Giver"},
        {1,325,"Military Spy","MagmaQuest",2,"Magma Quest Giver"},
        {1,375,"Fishman Warrior","FishmanQuest",1,"King Neptune"},
        {1,400,"Fishman Commando","FishmanQuest",2,"King Neptune"},
        {1,450,"God's Guard","SkyExp1Quest",1,"Mole"},
        {1,475,"Shanda","SkyExp1Quest",2,"Mole"},
        {1,525,"Royal Squad","SkyExp2Quest",1,"Sky Quest Giver"},
        {1,550,"Royal Soldier","SkyExp2Quest",2,"Sky Quest Giver"},
        {1,625,"Galley Pirate","FountainQuest",1,"Freezeburg Quest Giver"},
        {1,650,"Galley Captain","FountainQuest",2,"Freezeburg Quest Giver"},
        {2,700,"Raider","Area1Quest",1,"Area 1 Quest Giver"},
        {2,725,"Mercenary","Area1Quest",2,"Area 1 Quest Giver"},
        {2,775,"Swan Pirate","Area2Quest",1,"Area 2 Quest Giver"},
        {2,800,"Factory Staff","Area2Quest",2,"Area 2 Quest Giver"},
        {2,875,"Marine Lieutenant","MarineQuest3",1,"Marine Quest Giver"},
        {2,900,"Marine Captain","MarineQuest3",2,"Marine Quest Giver"},
        {2,950,"Zombie","ZombieQuest",1,"Graveyard Quest Giver"},
        {2,975,"Vampire","ZombieQuest",2,"Graveyard Quest Giver"},
        {2,1000,"Snow Trooper","SnowMountainQuest",1,"Snow Quest Giver"},
        {2,1050,"Winter Warrior","SnowMountainQuest",2,"Snow Quest Giver"},
        {2,1100,"Lab Subordinate","IceSideQuest",1,"Ice Quest Giver"},
        {2,1125,"Horned Warrior","IceSideQuest",2,"Ice Quest Giver"},
        {2,1175,"Magma Ninja","FireSideQuest",1,"Fire Quest Giver"},
        {2,1200,"Lava Pirate","FireSideQuest",2,"Fire Quest Giver"},
        {2,1250,"Ship Deckhand","ShipQuest1",1,"Ship Quest Giver 1"},
        {2,1275,"Ship Engineer","ShipQuest1",2,"Ship Quest Giver 1"},
        {2,1300,"Ship Steward","ShipQuest2",1,"Ship Quest Giver 2"},
        {2,1325,"Ship Officer","ShipQuest2",2,"Ship Quest Giver 2"},
        {2,1350,"Arctic Warrior","FrostQuest",1,"Frost Quest Giver"},
        {2,1375,"Snow Lurker","FrostQuest",2,"Frost Quest Giver"},
        {2,1425,"Sea Soldier","ForgottenQuest",1,"Forgotten Quest Giver"},
        {2,1450,"Water Fighter","ForgottenQuest",2,"Forgotten Quest Giver"},
        {3,1500,"Pirate Millionaire","PiratePortQuest",1,"Pirate Port Quest Giver"},
        {3,1525,"Pistol Billionaire","PiratePortQuest",2,"Pirate Port Quest Giver"},
        {3,1575,"Dragon Crew Warrior","AmazonQuest",1,"Amazon Quest Giver"},
        {3,1600,"Dragon Crew Archer","AmazonQuest",2,"Amazon Quest Giver"},
        {3,1625,"Female Islander","AmazonQuest2",1,"Amazon Quest Giver 2"},
        {3,1650,"Giant Islander","AmazonQuest2",2,"Amazon Quest Giver 2"},
        {3,1700,"Marine Commodore","MarineTreeIsland",1,"Marine Tree Quest Giver"},
        {3,1725,"Marine Rear Admiral","MarineTreeIsland",2,"Marine Tree Quest Giver"},
        {3,1775,"Fishman Raider","DeepForestIsland3",1,"Deep Forest Quest Giver 3"},
        {3,1800,"Fishman Captain","DeepForestIsland3",2,"Deep Forest Quest Giver 3"},
        {3,1825,"Forest Pirate","DeepForestIsland",1,"Deep Forest Quest Giver"},
        {3,1850,"Mythological Pirate","DeepForestIsland",2,"Deep Forest Quest Giver"},
        {3,1900,"Jungle Pirate","DeepForestIsland2",1,"Deep Forest Quest Giver 2"},
        {3,1925,"Musketeer Pirate","DeepForestIsland2",2,"Deep Forest Quest Giver 2"},
        {3,1975,"Reborn Skeleton","HauntedQuest1",1,"Haunted Castle Quest Giver 1"},
        {3,2000,"Living Zombie","HauntedQuest1",2,"Haunted Castle Quest Giver 1"},
        {3,2025,"Demonic Soul","HauntedQuest2",1,"Haunted Castle Quest Giver 2"},
        {3,2050,"Posessed Mummy","HauntedQuest2",2,"Haunted Castle Quest Giver 2"},
        {3,2075,"Peanut Scout","NutsIslandQuest",1,"Peanut Quest Giver"},
        {3,2100,"Peanut President","NutsIslandQuest",2,"Peanut Quest Giver"},
        {3,2125,"Ice Cream Chef","IceCreamIslandQuest",1,"Ice Cream Quest Giver"},
        {3,2150,"Ice Cream Commander","IceCreamIslandQuest",2,"Ice Cream Quest Giver"},
        {3,2200,"Cookie Crafter","CakeQuest1",1,"Cake Quest Giver 1"},
        {3,2225,"Cake Guard","CakeQuest1",2,"Cake Quest Giver 1"},
        {3,2250,"Baking Staff","CakeQuest2",1,"Cake Quest Giver 2"},
        {3,2275,"Head Baker","CakeQuest2",2,"Cake Quest Giver 2"},
        {3,2300,"Cocoa Warrior","ChocQuest1",1,"Chocolate Quest Giver 1"},
        {3,2325,"Chocolate Bar Battler","ChocQuest1",2,"Chocolate Quest Giver 1"},
        {3,2350,"Sweet Thief","ChocQuest2",1,"Chocolate Quest Giver 2"},
        {3,2375,"Candy Rebel","ChocQuest2",2,"Chocolate Quest Giver 2"},
        {3,2400,"Candy Pirate","CandyQuest1",1,"Candy Quest Giver"},
        {3,2425,"Snow Demon","CandyQuest1",2,"Candy Quest Giver"},
        {3,2450,"Isle Outlaw","TikiQuest1",1,"Tiki Quest Giver 1"},
        {3,2475,"Island Boy","TikiQuest1",2,"Tiki Quest Giver 1"},
        {3,2500,"Sun-kissed Warrior","TikiQuest2",1,"Tiki Quest Giver 2"},
        {3,2525,"Isle Champion","TikiQuest2",2,"Tiki Quest Giver 2"},
    }
    local seaIds = {[2753915549]=1,[4442272183]=2,[7449423635]=3}
    local events = {"Mirage Island","Kitsune Island","Prehistoric Island","Leviathan","Sea Beast","Terror Shark","Terrorshark","Factory","Core","Dough King","Cake Prince","rip_indra","Darkbeard","Order","Soul Reaper","Blue Gear","Frozen Dimension","Ship Raid"}
    local routes = {
        {"Race V2","Second Sea; complete the Colosseum quest; speak to Alchemist; find the flowers; pay the in-game cost manually."},
        {"Race V3","Have V2; speak to Arowe and complete the race-specific quest; confirm payment yourself."},
        {"Race V4","Third Sea; V3; defeat rip_indra; obtain Mirror Fractal from Dough King; complete the Sealed King and Mirage/Blue Gear steps; unlock trials with other players."},
        {"Raid awakening","Enter a raid with a valid chip, clear islands with the timer running, then speak to the awakening NPC and confirm the fragment cost."},
        {"Cursed Dual Katana","Obtain Yama and Tushita; meet mastery and level requirements; finish their scroll trials."},
        {"Yama / Tushita","Follow Elite Hunter and the hidden temple quests respectively; required conditions must be recognized by the server."},
        {"Rengoku","Obtain the Hidden Key and locate the corresponding chest in Ice Castle."},
        {"True Triple Katana","Obtain the three legendary swords and their mastery requirements; speak to the appropriate NPC."},
        {"Shark Anchor","Obtain the required sea-event materials and Monster Magnet, then defeat the appropriate Terrorshark."},
        {"Soul Guitar","Complete the Haunted Castle puzzle and acquire the requested materials."},
        {"Godhuman / fighting styles","Meet the prerequisite style mastery, materials and currencies. Confirm any purchase manually."},
        {"Draco / Dragon Dojo","Use the Dragon Dojo progression, belt quests and appropriate NPCs. Verify current conditions in game."},
        {"Ghoul / Cyborg","Use their specific quest items and NPCs. Cyborg requires Order-related progression."},
        {"Sea events","Use a boat and the normal event mechanics. The detector observes loaded objects only."},
    }
    local ui = {}
    local ex = {nextScan=0,nextQuest=0,questBusy=false,questTicket=0,questFailures=0,
        lastMode="",status="Pronto",seen={},eventObjects={},nextStats=0,statBusy=false,
        lastAbility={},abilityTicket=0,activeQuest=nil,questTitle="",raid=false,
        nextObservation=0,level=nil,sea=0,points=nil,charge=nil,raidIsland=nil}
    local function normalized(s)
        return tostring(s or ""):lower():gsub("[^%w]", "")
    end
    local function matches(a,b)
        return normalized(a)==normalized(b)
    end
    local function contains(a,b)
        local key=normalized(b)
        return key~="" and normalized(a):find(key,1,true)~=nil
    end
    local function value(parent,name)
        local obj=parent and parent:FindFirstChild(name)
        if obj and obj:IsA("ValueBase") then
            local ok,v=pcall(function() return obj.Value end)
            if ok then return v end
        end
    end
    local function dataValue(name)
        return value(player:FindFirstChild("Data"),name)
    end
    local function recommend(sea,level)
        local best=nil
        if not level then return nil end
        for _,q in ipairs(questRows) do
            if q[1]==sea and q[2]<=level and (not best or q[2]>best[2]) then best=q end
        end
        return best
    end
    local function visible(obj)
        if not obj or not obj:IsA("GuiObject") or not obj.Visible then return false end
        local p=obj.Parent
        while p and p~=playerGui do
            if p:IsA("GuiObject") and not p.Visible then return false end
            if p:IsA("LayerCollector") and not p.Enabled then return false end
            p=p.Parent
        end
        return true
    end
    local function questPanel()
        local main=playerGui:FindFirstChild("Main")
        local panel=main and main:FindFirstChild("Quest")
        if not visible(panel) then return false,"" end
        local fallback=""
        for _,o in ipairs(panel:GetDescendants()) do
            if (o:IsA("TextLabel") or o:IsA("TextButton")) and visible(o) then
                local txt=o.Text
                if contains(txt,"defeat") or contains(txt,"kill") then return true,txt end
                if normalized(o.Name)=="title" and txt~="" then fallback=txt end
            end
        end
        return true,fallback
    end
    local function raidPanel()
        local main=playerGui:FindFirstChild("Main")
        local timer=main and main:FindFirstChild("Timer")
        return visible(timer)
    end
    local function questFromTitle(sea,title)
        local best=nil
        for _,q in ipairs(questRows) do
            if q[1]==sea and contains(title,q[3]) and (not best or #q[3]>#best[3]) then best=q end
        end
        return best
    end
    local function remote()
        local storage=game:GetService("ReplicatedStorage")
        local folder=storage:FindFirstChild("Remotes")
        local r=folder and folder:FindFirstChild("CommF_")
        if r and r:IsA("RemoteFunction") then return r end
    end
    local function questNPC(q,root)
        local folder=workspace:FindFirstChild("NPCs")
        if not folder then return nil end
        local nearest,dist=nil,math.huge
        for _,obj in ipairs(folder:GetChildren()) do
            local cleanName=obj.Name:gsub("%s*%b[]",""):gsub("%s*%b()","")
            if matches(cleanName,q[6]) or matches(cleanName,q[4]) then
                local part=findRoot(obj)
                if part then
                    local d=(part.Position-root.Position).Magnitude
                    if d<dist then nearest,dist=part,d end
                end
            end
        end
        return nearest,dist
    end
    local function setStatus(s)
        ex.status=s
        state.mode=s
    end
    local function stopMovement(h,r)
        releaseAttack()
        state.pendingAttack=nil
        if state.target or state.goal then setTarget(nil,os.clock()) end
        if h and r then state.flight.stop(h,r) end
    end
    local function stopMode(key)
        cfg[key]=false
        if refreshers[key] then refreshers[key]() end
    end
    local function exclusive(key,on)
        if not on then return end
        for _,k in ipairs({"autoQuest","raidAssist","bountyAssist"}) do
            if k~=key then stopMode(k) end
        end
        setTarget(nil,os.clock())
        state.manualGoal=nil
        ex.lastMode=""
    end
    local function requestQuest(q)
        local r=remote()
        if not r then ex.status="CommF_ non disponibile";return end
        local now=os.clock()
        if ex.questBusy or now<ex.nextQuest then return end
        ex.questBusy=true
        ex.questTicket=ex.questTicket+1
        local ticket=ex.questTicket
        ex.nextQuest=now+4
        task.spawn(function()
            local ok,result=pcall(function() return r:InvokeServer("StartQuest",q[4],q[5]) end)
            ex.questBusy=false
            if ticket~=ex.questTicket or not state.alive then return end
            if not ok then
                ex.questFailures=ex.questFailures+1
                ex.nextQuest=os.clock()+MathCore.cooldown(4,ex.questFailures,60)
                log("Quest: richiesta fallita: "..tostring(result))
            else
                -- Response alone is not a confirmed quest; only the visible panel is used.
                ex.nextQuest=os.clock()+6
                log("Quest: richiesta inviata; attendo conferma GUI")
            end
        end)
    end
    local function scopedFarm(now,filter,raid)
        local old={farm=cfg.farm,fruit=cfg.fruit,chest=cfg.chest,filter=cfg.filter,bossOnly=cfg.bossOnly,ignoreBosses=cfg.ignoreBosses}
        cfg.farm=true;cfg.fruit=false;cfg.chest=false;cfg.filter=filter or "";cfg.bossOnly=false;cfg.ignoreBosses=false
        if state.target and (state.target.kind~="NPC" or (filter and filter~="" and not contains(state.target.obj.Name,filter))) then setTarget(nil,now) end
        local ok,err=pcall(tick,now)
        for k,v in pairs(old) do cfg[k]=v end
        if not ok then error(err) end
        ex.status=(raid and "Raid: " or "Quest: ")..state.mode
        state.mode=ex.status
    end
    local function questTick(now,c,h,r)
        local active,title=questPanel()
        ex.questTitle=title
        local suggested=recommend(ex.sea,ex.level)
        ex.activeQuest=suggested
        if active then
            local q=questFromTitle(ex.sea,title)
            if not q then
                stopMovement(h,r)
                setStatus("Quest attiva non riconosciuta: "..title)
                return
            end
            ex.questFailures=0
            ex.activeQuest=q
            scopedFarm(now,q[3],false)
            return
        end
        if not suggested then
            stopMovement(h,r);setStatus("Nessuna quest compatibile rilevata");return
        end
        if ex.sea==3 and ex.level>=2550 then
            stopMovement(h,r);setStatus("Tabella quest non verificata oltre livello 2549");return
        end
        local part,d=questNPC(suggested,r)
        if not part then
            stopMovement(h,r);setStatus("Raggiungi "..suggested[6].." (NPC non caricato)");return
        end
        if d>12 then
            releaseAttack()
            if state.target then setTarget(nil,now) end
            setStatus("Verso "..suggested[6]);move(h,r,part.Position,now);return
        end
        stopMovement(h,r)
        if cfg.questRequest and not (suggested[1]==3 and suggested[2]>=1775 and suggested[2]<=1925) then
            requestQuest(suggested)
            setStatus("Attendo apertura quest: "..suggested[3])
        else
            setStatus("Apri la quest da "..suggested[6].." manualmente")
        end
    end
    local function raidTick(now,c,h,r)
        if not raidPanel() then
            stopMovement(h,r);setStatus("Raid: avvia o raggiungi un raid dal gioco");return
        end
        local origin=workspace:FindFirstChild("_WorldOrigin")
        local locations=origin and origin:FindFirstChild("Locations")
        local nearest=nil
        if locations then
            for _,obj in ipairs(locations:GetChildren()) do
                if normalized(obj.Name):match("^island[1-5]$") then
                    local part=findRoot(obj)
                    if part then
                        local d=(part.Position-r.Position).Magnitude
                        if not nearest or d<nearest.distance then nearest={part=part,distance=d,name=obj.Name} end
                    end
                end
            end
        end
        if not nearest or nearest.distance>500 then
            stopMovement(h,r);setStatus("Raid: isola non riconosciuta, raggiungila manualmente");return
        end
        ex.raidIsland=nearest.name
        scopedFarm(now,"",true)
    end
    local function safeZone()
        local main=playerGui:FindFirstChild("Main")
        if not main then return nil end
        local found=false
        for _,name in ipairs({"SafeZone","SafeZoneLabel","PvpDisabled","PvPDisabled"}) do
            local obj=main:FindFirstChild(name,true)
            if obj and obj:IsA("GuiObject") then
                found=true
                if visible(obj) then return true end
            end
        end
        if found then return false end
        return nil
    end
    local function selectedOpponent()
        local name=cfg.bountyName
        if name=="" then return nil end
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=player and matches(p.Name,name) then return p end
        end
    end
    local function bountyTick(now,c,h,r)
        settleAttack(now)
        if state.char~=c then state.char=c;setTarget(nil,now) end
        if safeZone()~=false then
            stopMovement(h,r);setStatus("PvP: zona sicura o stato non riconosciuto");return
        end
        local opponent=selectedOpponent()
        local model=opponent and opponent.Character
        local part=model and findRoot(model)
        local hum=model and model:FindFirstChildOfClass("Humanoid")
        if not part or not hum or hum.Health<=0 or (player.Team and opponent.Team==player.Team) then
            stopMovement(h,r);setStatus("PvP: bersaglio selezionato non disponibile");return
        end
        local distance=(part.Position-r.Position).Magnitude
        if distance>cfg.radius or distance>100 then
            stopMovement(h,r);setStatus("PvP: bersaglio fuori raggio");return
        end
        if not state.target or state.target.obj~=model then setTarget({obj=model,part=part,hum=hum,kind="Player"},now) end
        if distance<=cfg.hitRange then
            state.flight.hold(h,r,now)
            attackNPC(c,h,r,state.target,now)
        else
            local d=part.Position-r.Position
            local flat=Vector3.new(d.X,0,d.Z)
            local goal=part.Position
            if flat.Magnitude>cfg.standoff then goal=goal-flat.Unit*cfg.standoff end
            move(h,r,goal,now)
        end
        setStatus("PvP: "..opponent.Name.." | "..math.floor(distance).." st")
    end
    local function observe()
        ex.sea=seaIds[game.PlaceId] or 0
        ex.level=tonumber(dataValue("Level"))
        ex.points=tonumber(dataValue("Points"))
        ex.raid=raidPanel()
        local c=player.Character
        local energy=value(c,"RaceEnergy")
        if type(energy)~="number" then energy=dataValue("RaceEnergy") end
        ex.charge=type(energy)=="number" and energy or nil
    end
    local function scanEvents(r)
        local hits={}
        local visited={}
        local containers={workspace,workspace:FindFirstChild("Map"),workspace:FindFirstChild("Enemies"),workspace:FindFirstChild("SeaBeasts"),workspace:FindFirstChild("_WorldOrigin")}
        local function examine(obj)
            if visited[obj] then return end
            visited[obj]=true
            for _,name in ipairs(events) do
                if matches(obj.Name,name) or contains(obj.Name,name) and #normalized(name)>5 then
                    local part=findRoot(obj)
                    if part then
                        local d=r and (part.Position-r.Position).Magnitude or math.huge
                        local old=hits[name]
                        if not old or d<old.distance then hits[name]={part=part,object=obj,distance=d} end
                    end
                end
            end
        end
        for _,folder in pairs(containers) do
            if folder then
                for _,obj in ipairs(folder:GetChildren()) do
                    examine(obj)
                    if obj:IsA("Folder") and folder~=workspace then
                        for _,child in ipairs(obj:GetChildren()) do examine(child) end
                    end
                end
            end
        end
        for name,hit in pairs(hits) do
            if cfg.eventWatch and ex.seen[name]~=hit.object then notify("Evento visibile: "..name) end
        end
        table.clear(ex.seen)
        for name,hit in pairs(hits) do ex.seen[name]=hit.object end
        ex.eventObjects=hits
    end
    local function abilityTool(c,aliases)
        local backpack=player:FindFirstChildOfClass("Backpack")
        for _,folder in pairs({c,backpack}) do
            if folder then
                for _,tool in ipairs(folder:GetChildren()) do
                    if tool:IsA("Tool") then
                        for _,alias in ipairs(aliases) do
                            if matches(tool.Name,alias) then return tool end
                        end
                    end
                end
            end
        end
    end
    local function tryAbility(c,h,now,key,aliases)
        if now-(ex.lastAbility[key] or -100)<12 then return end
        if ex.abilityBusy or state.lastTool or state.pendingAttack then return end
        local tool=abilityTool(c,aliases)
        if not tool then
            state.moduleStatus[key]="Strumento abilita non trovato: attivazione non disponibile"
            return
        end
        state.moduleStatus[key]="Strumento trovato: "..tool.Name
        ex.lastAbility[key]=now
        ex.abilityBusy=true
        local before=c:FindFirstChildOfClass("Tool")
        local gen=state.generation
        local ticket=ex.abilityTicket
        task.spawn(function()
            local ok,err=pcall(function()
                if tool.Parent~=c then h:EquipTool(tool);task.wait(.2) end
                if not state.alive or ex.abilityTicket~=ticket or state.paused or gen~=state.generation or not cfg[key] then return end
                if tool.Parent==c and tool.Enabled then tool:Activate();task.wait(.08);if tool.Parent==c then tool:Deactivate() end end
            end)
            if before and before.Parent and before.Parent~=c and state.alive and c==player.Character and ex.abilityTicket==ticket then pcall(function() h:EquipTool(before) end) end
            ex.abilityBusy=false
            if not ok then log("Race tool: "..tostring(err)) end
        end)
    end
    local function statsTick(now)
        if not cfg.autoStats or ex.statBusy or now<ex.nextStats then return end
        local points=tonumber(dataValue("Points"))
        local options={melee="Melee",defense="Defense",sword="Sword",gun="Gun",bloxfruit="Demon Fruit",demonfruit="Demon Fruit"}
        local stat=options[normalized(cfg.statName)]
        if not points or not stat then return end
        local amount=math.floor(math.min(cfg.statBatch,points-cfg.statReserve))
        if amount<=0 then return end
        local r=remote()
        if not r then return end
        ex.statBusy=true;ex.nextStats=now+8
        task.spawn(function()
            local ok,err=pcall(function() return r:InvokeServer("AddPoint",stat,amount) end)
            ex.statBusy=false
            if not ok then log("Stats: "..tostring(err));ex.nextStats=os.clock()+30 end
        end)
    end
    function E.stop()
        ex.questTicket=ex.questTicket+1
        ex.abilityTicket=ex.abilityTicket+1
        ex.lastMode=""
        -- Cannot cancel an InvokeServer already sent; preserve the busy lock until response.
        for _,key in ipairs(extra) do stopMode(key) end
        stopMode("questRequest")
        ex.status="Arrestato"
    end
    function E.isActive()
        return cfg.autoQuest or cfg.raidAssist or cfg.bountyAssist or cfg.autoRace3 or cfg.autoRace4 or cfg.autoStats
    end
    function E.tick(now)
        if now>=ex.nextObservation then
            ex.nextObservation=now+.5
            local ok,err=pcall(observe)
            if not ok then state.lastIssue="Dati gioco: "..tostring(err) end
        end
        local c,h,r=character()
        if c and now>=ex.nextScan and (cfg.eventWatch or state.view=="Eventi") then
            ex.nextScan=now+2.5
            local ok,err=pcall(scanEvents,r)
            if not ok then state.lastIssue="Eventi: "..tostring(err) end
        end
        if not c or state.paused or state.manualGoal then return false end
        if (cfg.autoQuest or cfg.raidAssist or cfg.bountyAssist) and cfg.heal and h.Health/math.max(h.MaxHealth,1)*100<=cfg.minHealth then
            stopMovement(h,r);setStatus("Protezione salute: attesa recupero");state.retreat=true;return true
        end
        if (cfg.autoQuest or cfg.raidAssist or cfg.bountyAssist) and state.retreat and cfg.heal then
            if h.Health/math.max(h.MaxHealth,1)*100<cfg.recoverHealth then
                stopMovement(h,r);setStatus("Protezione salute: recupero in corso");return true
            end
            state.retreat=false
        end
        if cfg.autoRace4 and not ex.charge then state.moduleStatus.autoRace4="Energia Race non esposta dal gioco" end
        if cfg.autoRace4 and ex.charge and ex.charge>=100 and not c:FindFirstChild("RaceTransformed") then
            tryAbility(c,h,now,"autoRace4",{"Race Awakening","Race V4","Awakening"})
        end
        if cfg.autoRace3 then tryAbility(c,h,now,"autoRace3",{"Race Ability","Race V3","Last Resort","Water Body","Heavenly Blood","Heightened Senses","Energy Core","Agility"}) end
        statsTick(now)
        if ex.abilityBusy then state.flight.stop(h,r);setStatus("Race: attivazione in corso");return true end
        local mode=cfg.raidAssist and "raid" or cfg.autoQuest and "quest" or cfg.bountyAssist and "bounty" or ""
        if ex.lastMode~=mode then
            setTarget(nil,now);ex.lastMode=mode
            if mode=="" then state.flight.stop(h,r) end
        end
        if mode=="raid" then raidTick(now,c,h,r);return true end
        if mode=="quest" then questTick(now,c,h,r);return true end
        if mode=="bounty" then bountyTick(now,c,h,r);return true end
        return false
    end
    local questPage=page("Missioni",13)
    local raidPage=page("Raid",14)
    local racePage=page("Race / Haki",15)
    local bountyPage=page("PvP",16)
    local eventPage=page("Eventi",17)
    local unlockPage=page("Sblocchi",18)
    local statPage=page("Statistiche",19)
    local function info(parent,title,height)
        return text(block(parent,title,height),"In attesa...",{Position=UDim2.fromOffset(10,8),Size=UDim2.new(1,-20,1,-16),TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,TextSize=12,TextColor3=C.muted})
    end
    ui.quest=info(questPage,"Stato missioni",104)
    toggle(questPage,"Assistente quest","autoQuest",function(on) exclusive("autoQuest",on) end)
    toggle(questPage,"Richiedi StartQuest (sperimentale)","questRequest")
    note(questPage,"Tabella legacy: livelli 1–2549 (ultimo scaglione 2525). L'NPC deve essere caricato e vicino. Non abbandona quest esistenti; nessun cambio mare automatico.",75)
    ui.raid=info(raidPage,"Stato raid",90)
    toggle(raidPage,"Combattimento NPC durante raid","raidAssist",function(on) exclusive("raidAssist",on) end)
    note(raidPage,"Avvia il raid manualmente. Il motore combatte gli NPC caricati quando il timer standard risulta visibile. Non compra chip, non avvia raid e non sblocca awakening.",90)
    ui.race=info(racePage,"Dati Race",105)
    toggle(racePage,"Tentativo V3 tramite Tool","autoRace3")
    toggle(racePage,"Tentativo V4 tramite Tool","autoRace4")
    note(racePage,"Funziona soltanto con strumenti effettivamente presenti e riconosciuti. Haki, Instinct e prove V4 richiedono interazioni di gioco; non sono automatizzati.",85)
    field(bountyPage,"Username esatto del giocatore","bountyName",false)
    toggle(bountyPage,"Combattimento selezionato","bountyAssist",function(on) exclusive("bountyAssist",on) end)
    note(bountyPage,"Solo il giocatore selezionato, entro 100 studs, squadra diversa e fuori da una zona sicura riconoscibile. Nessuna garanzia di bounty o danni.",80)
    toggle(eventPage,"Notifiche eventi caricati","eventWatch")
    ui.event=info(eventPage,"Eventi visibili",220)
    field(eventPage,"Nome evento da raggiungere","eventName",false)
    action(eventPage,"Imposta percorso verso evento","VAI",function()
        for name,hit in pairs(ex.eventObjects) do
            if matches(name,cfg.eventName) and hit.part.Parent then
                state.manualGoal=hit.part.Position;state.manualStarted=os.clock();state.paused=false;return
            end
        end
        notify("Evento non rilevato: inserisci il nome esatto")
    end)
    note(eventPage,"Solo oggetti gia caricati. Il percorso non guida barche e non sposta il personaggio tra isole via teleport.",60)
    for _,route in ipairs(routes) do
        local box=block(unlockPage,route[1],116)
        text(box,route[1],{Position=UDim2.fromOffset(10,6),Size=UDim2.new(1,-20,0,24),TextSize=15,Font=Enum.Font.GothamBold})
        text(box,route[2],{Position=UDim2.fromOffset(10,32),Size=UDim2.new(1,-20,1,-38),TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,TextSize=12,TextColor3=C.muted})
    end
    ui.stats=info(statPage,"Punti disponibili",72)
    field(statPage,"Stat (Melee / Defense / Sword / Gun / Blox Fruit)","statName",false)
    field(statPage,"Punti per richiesta","statBatch",true,1,25)
    field(statPage,"Riserva punti","statReserve",true,0,10000)
    toggle(statPage,"Assegna punti (sperimentale)","autoStats")
    note(statPage,"L'assegnazione punti e permanente salvo reset del gioco. Il modulo e OFF all'avvio e usa solo punti disponibili. Nessuna spesa Robux.",75)
    function E.updateUI()
        local q=ex.activeQuest or recommend(ex.sea,ex.level)
        ui.quest.Text="Mare: "..ex.sea.." | Livello: "..tostring(ex.level or "?").."\nConsigliata: "..(q and q[3] or "non nota").."\nQuest GUI: "..(ex.questTitle~="" and ex.questTitle or "non rilevata")
        ui.raid.Text="Timer raid: "..(ex.raid and "visibile" or "non rilevato").."\nAssistente: "..(cfg.raidAssist and ex.status or "OFF")
        ui.race.Text="Race: "..tostring(dataValue("Race") or "?").."\nEnergia: "..tostring(ex.charge or "non esposta").."\nAttivazione solo via Tool riconosciuto."
        ui.stats.Text="Punti disponibili: "..tostring(ex.points or "non rilevati").."\nStat scelta: "..cfg.statName
        local lines={}
        for name,hit in pairs(ex.eventObjects) do table.insert(lines,name.." | "..(hit.distance<math.huge and tostring(math.floor(hit.distance)).." st" or "?")) end
        table.sort(lines)
        ui.event.Text=#lines>0 and table.concat(lines,"\n") or "Nessun evento rilevato nelle istanze caricate."
    end
    function E.test()
        local cases={{1,1,"Bandit"},{1,15,"Gorilla"},{1,699,"Galley Captain"},{2,700,"Raider"},{2,1425,"Sea Soldier"},{3,1500,"Pirate Millionaire"},{3,2525,"Isle Champion"}}
        local count=0
        for _,test in ipairs(cases) do assert(recommend(test[1],test[2])[3]==test[3]);count=count+1 end
        assert(recommend(0,100)==nil);count=count+1
        assert(questFromTitle(1,"Defeat 8 Gorillas")[3]=="Gorilla");count=count+1
        assert(questFromTitle(2,"Unknown quest")==nil);count=count+1
        assert(matches("Race V4","race-v4"));count=count+1
        for _,q in ipairs(questRows) do
            assert(q[1]>=1 and q[1]<=3 and q[2]>=1 and q[5]>=1 and q[5]<=2 and q[3]~="" and q[4]~="" and q[6]~="")
            count=count+1
        end
        return count
    end
    action(diagnostics,"Test tabella missioni","TEST V4",function()
        local ok,n=pcall(E.test)
        notify(ok and ("Test logici: "..n.." superati") or ("Errore test: "..tostring(n)))
    end)
end


local function refreshChestCache()
    if not (cfg.chest or cfg.chestMarks) then state.chestCache={};return end
    local nextCache={}
    local map=workspace:FindFirstChild("Map")
    if map then
        for _,obj in ipairs(map:GetDescendants()) do
            if obj.Name:lower():find("chest",1,true) and (obj:IsA("Model") or obj:IsA("BasePart")) then
                table.insert(nextCache,obj)
            end
        end
    end
    state.chestCache=nextCache
end
local function clearMarker(obj)
    local record=state.markers[obj]
    if record then record.h:Destroy();state.markers[obj]=nil end
end
local function markerRefresh()
    local _,_,root=character()
    local candidates={}
    local seen={}
    local function consider(obj,colour)
        if not root or not obj.Parent or seen[obj] then return end
        local part=findRoot(obj)
        if not part or not part:IsA("BasePart") then return end
        local d=(part.Position-root.Position).Magnitude
        if d>cfg.markDistance then return end
        seen[obj]=true
        table.insert(candidates,{obj=obj,part=part,d=d,colour=colour})
    end
    if root and (cfg.fruitMarks or cfg.notifyFruit or cfg.chestMarks) then
        for _,obj in ipairs(workspace:GetChildren()) do
            local n=obj.Name:lower()
            if obj:IsA("Tool") and n:find("fruit",1,true) then
                if cfg.fruitMarks then consider(obj,C.good) end
                if cfg.notifyFruit and not state.fruitSeen[obj] then
                    state.fruitSeen[obj]=true;notify("Frutto visibile: "..obj.Name)
                end
            elseif cfg.chestMarks and n:find("chest",1,true) then consider(obj,C.accent2) end
        end
        if cfg.chestMarks then for _,obj in ipairs(state.chestCache) do consider(obj,C.accent2) end end
    end
    for obj in pairs(state.fruitSeen) do if not obj.Parent or not obj:IsDescendantOf(workspace) then state.fruitSeen[obj]=nil end end
    if root and cfg.npcMarks then
        local enemies=workspace:FindFirstChild("Enemies")
        if enemies then
            for _,obj in ipairs(enemies:GetChildren()) do
                if obj:IsA("Model") and not Players:GetPlayerFromCharacter(obj) then
                    local hum=obj:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health>0 then consider(obj,C.bad) end
                end
            end
        end
    end
    table.sort(candidates,function(a,b) return a.d<b.d end)
    local keep={}
    for i,item in ipairs(candidates) do
        if i>math.floor(cfg.markLimit) then break end
        keep[item.obj]=true
        local record=state.markers[item.obj]
        if not record then
            local h=make("Highlight",gui,{Adornee=item.obj,FillTransparency=.92,OutlineColor=item.colour,DepthMode=Enum.HighlightDepthMode.Occluded})
            record={h=h};state.markers[item.obj]=record
        end
        record.h.OutlineColor=item.colour
    end
    local expired={}
    for obj in pairs(state.markers) do if not keep[obj] then table.insert(expired,obj) end end
    for _,obj in ipairs(expired) do clearMarker(obj) end
end
local function safeRun(label,fn)
    local ok,err=pcall(fn)
    state.moduleStatus[label]=ok and "OK (nessuna eccezione)" or tostring(err)
    if not ok then
        state.errors=state.errors+1
        state.lastIssue=label..": "..tostring(err)
        local now=os.clock()
        if not state.errorByLabel[label] or now-state.errorByLabel[label]>5 then
            state.errorByLabel[label]=now;log(state.lastIssue);warn("[QuantumNova]",label,err)
        end
    end
    return ok
end
action(diagnostics,"Verifica compatibilita corrente","VERIFICA",function()
    local c,h,r=character()
    local enemies=workspace:FindFirstChild("Enemies") or workspace:FindFirstChild("NPCs")
    local backpack=player:FindFirstChildOfClass("Backpack")
    local equipped=c and c:FindFirstChildOfClass("Tool")
    local main=playerGui:FindFirstChild("Main")
    local lines={"PlaceId: "..tostring(game.PlaceId),"Personaggio: "..tostring(c~=nil),"NPC caricati: "..tostring(enemies and #enemies:GetChildren() or 0),"Strumenti nello zaino: "..tostring(backpack and #backpack:GetChildren() or 0),"Arma: "..(equipped and equipped.Name or "nessuna"),"Quest GUI: "..tostring(main and main:FindFirstChild("Quest")~=nil or false),"Ultimo errore: "..state.lastIssue}
    for _,lineText in ipairs(lines) do log(lineText);print("[NovaCheck] "..lineText) end
    notify("Controllo completato: leggi Diagnostica")
end)
local runtimePanel=block(diagnostics,"Diagnostica continua",340)
local runtimeText=text(runtimePanel,"In attesa...",{Position=UDim2.fromOffset(10,8),Size=UDim2.new(1,-20,1,-16),TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,TextSize=12})
local runtimeCopy=make("TextBox",block(diagnostics,"Rapporto da copiare",130),{Position=UDim2.fromOffset(8,8),Size=UDim2.new(1,-16,1,-16),Text="",ClearTextOnFocus=false,MultiLine=true,TextWrapped=true,TextEditable=false,TextColor3=C.text,BackgroundColor3=C.item,TextSize=11,TextYAlignment=Enum.TextYAlignment.Top})
local function runtimeReport()
    local c,h,r=character()
    local enemies=workspace:FindFirstChild("Enemies") or workspace:FindFirstChild("NPCs")
    local tools={}
    for _,tool in ipairs(getTools()) do table.insert(tools,tool.Name.." ("..tool.ToolTip..")") end
    local modes={}
    for _,key in ipairs({"farm","fruit","chest","autoQuest","raidAssist","bountyAssist","autoRace3","autoRace4","autoStats","eventWatch"}) do
        if cfg[key] then table.insert(modes,key) end
    end
    local lines={"V4.4 | PlaceId "..tostring(game.PlaceId),
        "Movimento: "..(cfg.flight and "VOLO" or "CAMMINATA").." | "..state.flight.status,
        "Noclip: "..(cfg.flightNoclip and "ON" or "OFF").." | Parti gestite: "..state.flight.collisionCount,
        "Velocita reale: "..(r and math.floor(r.AssemblyLinearVelocity.Magnitude) or 0).." stud/s",
        "Ostacoli volo: "..state.flight.obstacles,
        "Cicli motore: "..state.engineCycles.." | Errori: "..state.errors,
        "Attivi: "..(#modes>0 and table.concat(modes,", ") or "nessuno"),
        "Stato: "..state.mode,
        "Personaggio: "..tostring(c~=nil).." | NPC: "..tostring(enemies and #enemies:GetChildren() or 0),
        "Strumenti: "..(#tools>0 and table.concat(tools,", ") or "nessuno"),
        "M1: "..state.lastAttackReason,
        "Tentativi: "..state.metrics.attempts.." | Calo HP: "..state.metrics.confirmed.." | Nessun calo: "..state.metrics.unconfirmed,
        "Percorsi: "..state.metrics.paths.." | Falliti: "..state.metrics.pathFailures,
        "Ultimo errore: "..state.lastIssue}
    local names={}
    for name in pairs(state.moduleStatus) do table.insert(names,name) end
    table.sort(names)
    for _,name in ipairs(names) do table.insert(lines,name..": "..state.moduleStatus[name]) end
    return table.concat(lines,"\n")
end
action(diagnostics,"Genera rapporto diagnostico","RAPPORTO",function()
    runtimeCopy.Text=runtimeReport()
    print("[NovaReport] "..runtimeCopy.Text)
end)
local clocks={engine=0,ui=0,marks=0,cache=0,inventory=0,perf=0}
local function elapsed(dt,key,interval)
    local nextClock,ready=MathCore.stepClock(clocks[key],dt,interval)
    clocks[key]=nextClock
    return ready
end
local function updateUI()
    fit()
    safeRun("Interfaccia espansione",expansion.updateUI)
    local _,h,r=character()
    local hp=h and math.floor(100*h.Health/math.max(h.MaxHealth,1)) or 0
    local duration=math.floor(os.clock()-state.started)
    summary.Text=string.format("Stato: %s\nVita: %d%%  |  NPC: %d  |  M1 tentati: %d  |  Sessione: %dm %ds",state.mode,hp,state.kills,state.attacks,math.floor(duration/60),duration%60)
    pauseButton.Text=state.paused and "RIPRENDI" or "PAUSA"
    local status=state.mode
    if cfg.showStats then status=string.format("%s  |  FPS %.0f  |  Errori %d",status,state.fps,state.errors) end
    footer.Text=status
    if state.view=="Telemetria" and cfg.showMetrics then
        local m=state.metrics
        metricsText.Text=string.format("M1 richiesti: %d | attivati: %d\nCalo HP osservato: %d | non osservato: %d\nOstacoli: %d | scansioni: %d\nPercorsi: %d | fallimenti: %d\nBlocchi: %d | pause manuali: %d\nUltimo M1: %s",m.attempts,state.attacks,m.confirmed,m.unconfirmed,m.blocked,m.searches,m.paths,m.pathFailures,m.stuck,m.manualStops,state.lastAttackReason)
    end
    if state.view=="Diagnostica" then
        runtimeText.Text=runtimeReport()
        local list={};for i=1,math.min(#state.log,12) do list[i]=state.log[i] end
        logText.Text=table.concat(list,"\n")
    end
end
connect(RunService.Heartbeat,function(dt)
    if not state.alive then return end
    if dt>0 then state.fps=state.fps*.92+(1/dt)*.08 end
    if elapsed(dt,"engine",cfg.engineInterval*(cfg.adaptive and state.fps>0 and state.fps<25 and 1.8 or 1)) and not state.engineBusy then
        state.engineBusy=true
        state.engineCycles=state.engineCycles+1
        local ok=safeRun("Motore",function()
            local now=os.clock()
            settleAttack(now)
            if not expansion.tick(now) then tick(now) end
        end)
        state.engineBusy=false
        if not ok then state.mode="Errore motore: vedi Diagnostica";state.flight.stop();releaseAttack() end
    end
    if elapsed(dt,"ui",.25) then safeRun("Interfaccia",updateUI) end
    if elapsed(dt,"marks",.75) then safeRun("Indicatori",markerRefresh) end
    if elapsed(dt,"cache",3) then safeRun("Cache",refreshChestCache) end
    if elapsed(dt,"inventory",1.2) and state.view=="Inventario" then safeRun("Inventario",inventoryRefresh) end
    if elapsed(dt,"perf",2) and cfg.reduceEffects then safeRun("Grafica",applyPerformance) end
end)
-- Physics-phase update keeps movement and local collisions synchronized.
connect(RunService.PreSimulation,function(dt)
    if not state.alive then return end
    if state.flight.velocity then
        if not safeRun("Volo",function() state.flight.step(dt) end) then state.flight.stop() end
    elseif state.flight.collisionOwner then
        state.flight.restoreCollisions()
    end
end)
connect(player.CharacterRemoving,function()
    state.flight.stop()
    releaseAttack()
    state.pendingAttack=nil
end)
connect(UserInputService.InputBegan,function(i,processed)
    if processed or not cfg.manualOverride then return end
    local key=i.KeyCode
    if key==Enum.KeyCode.W or key==Enum.KeyCode.A or key==Enum.KeyCode.S or key==Enum.KeyCode.D or key==Enum.KeyCode.Space then
        if cfg.farm or cfg.fruit or cfg.chest or state.manualGoal or expansion.isActive() then
            state.paused=true;state.pauseFromManual=true;state.lastManualInput=os.clock();state.metrics.manualStops=state.metrics.manualStops+1
            releaseAttack();state.flight.stop()
        end
    end
end)
connect(gui.Destroying,function()
    state.alive=false;state.generation=state.generation+1
    stopAll();cfg.reduceEffects=false;cfg.lowShadows=false
    pcall(applyPerformance)
    for _,c in ipairs(conns) do c:Disconnect() end
    table.clear(conns)
end)
log("Quantum Nova 4.4 caricato; volo e Noclip ON, automazioni OFF")
print("[QuantumNova] V4.4 loaded. All automation starts OFF.")
