-- Display-adaptive layout & scaling engine for AmoledTerminal Rainmeter suite.
-- Automatically adapts widget scale (#S#) and positions to any monitor resolution,
-- DPI scale, Windows taskbar, or Seelen UI top bar / bottom dock.

local function round(n)
    return math.floor(n + 0.5)
end

local function clamp(val, lo, hi)
    if val < lo then return lo end
    if val > hi then return hi end
    return val
end

local function getVarNum(name, defaultVal)
    local v = tonumber(SKIN:ReplaceVariables("#" .. name .. "#"))
    if v ~= nil then return v end
    return defaultVal
end

local function getMonitorMetrics()
    local wx = getVarNum("WORKAREAX", 0)
    local wy = getVarNum("WORKAREAY", 0)
    local ww = getVarNum("WORKAREAWIDTH", 1920)
    local wh = getVarNum("WORKAREAHEIGHT", 1048)
    local sx = getVarNum("SCREENAREAX", wx)
    local sy = getVarNum("SCREENAREAY", wy)
    local sw = getVarNum("SCREENAREAWIDTH", ww)
    local sh = getVarNum("SCREENAREAHEIGHT", wh)
    if ww <= 0 then ww = 1920 end
    if wh <= 0 then wh = 1048 end
    if sw <= 0 then sw = ww end
    if sh <= 0 then sh = wh end
    return wx, wy, ww, wh, sx, sy, sw, sh
end

local lastSysSig = nil
local function checkDisplayChanged()
    local mW = SKIN:GetMeasure("MeasureMonW")
    local mH = SKIN:GetMeasure("MeasureMonH")
    local mN = SKIN:GetMeasure("MeasureNumMon")
    if not (mW and mH and mN) then return false end
    local sig = string.format("%d,%d,%d", mW:GetValue() or 0, mH:GetValue() or 0, mN:GetValue() or 0)
    if lastSysSig == nil then
        lastSysSig = sig
        return false
    end
    if sig ~= lastSysSig then
        lastSysSig = sig
        return true
    end
    return false
end

local function computeScale(ww, wh, sy, sh, wy)
    -- Base reference: 1920x1048 logical work area = 1.00
    local rw = ww / 1920.0
    local rh = wh / 1048.0
    local raw = math.min(rw, rh)
    local s
    if raw >= 1.0 then
        s = 1.0 + (raw - 1.0) * 0.75
    else
        s = 1.0 - (1.0 - raw) * 0.65
    end
    s = clamp(s, 0.78, 1.50)

    -- Ensure the tallest column (476 * s) + margins + AudioFFT + dock fit comfortably without overlap
    local workBottom = wy + wh
    local screenBottom = sy + sh
    local bottomReserved = math.max(0, screenBottom - workBottom)
    local hasExternalBottomDock = (bottomReserved < 36)
    local dockPerUnit = hasExternalBottomDock and 96 or 18
    local maxVerticalRatio = (wh - 16) / (16 + 554 + 14 + 34 + dockPerUnit)
    if maxVerticalRatio < s then
        s = clamp(maxVerticalRatio, 0.68, 1.50)
    end

    -- Ensure left + right columns leave a clean center corridor (>= 22% of width)
    local maxWidthRatio = (ww * 0.36) / 272.0
    if maxWidthRatio < s then
        s = clamp(maxWidthRatio, 0.68, 1.50)
    end

    return math.floor(s * 100 + 0.5) / 100
end

local function readActiveConfigs()
    local active = {}
    local rmIni = SKIN:ReplaceVariables("#SETTINGSPATH#Rainmeter.ini")
    local f = io.open(rmIni, "rb")
    if not f then return active end
    local content = f:read("*all")
    f:close()
    -- Rainmeter.ini is typically UTF-16 LE; stripping NUL bytes and BOMs handles UTF-16 LE & UTF-8 cleanly
    content = content:gsub("%z", ""):gsub("^\255\254", ""):gsub("^\254\255", ""):gsub("^\239\187\191", "")
    local section = nil
    for line in content:gmatch("[^\r\n]+") do
        local sec = line:match("^%[([^%]]+)%]%s*$")
        if sec then
            section = sec
        elseif section and line:match("^Active=1%s*$") then
            active[section] = true
        end
    end
    return active
end

local function updateVariablesFile(newS, areaKey, pending)
    local varPath = SKIN:ReplaceVariables("#@#Variables.inc")
    local f = io.open(varPath, "r")
    if not f then return false end
    local content = f:read("*all")
    f:close()

    -- Strip UTF-8 BOM if present
    content = content:gsub("^\239\187\191", "")

    local sStr = string.format("%.2f", newS)
    local function setVar(text, key, val)
        local pattern = "(%f[^\n]" .. key .. "=)[^\r\n]*"
        if text:match(pattern) then
            return (text:gsub(pattern, "%1" .. val, 1))
        end
        if not text:match("\n$") then text = text .. "\n" end
        return text .. key .. "=" .. val .. "\n"
    end

    content = setVar(content, "S", sStr)
    content = setVar(content, "LastAreaKey", areaKey)
    content = setVar(content, "PendingLayout", pending)

    local wf = io.open(varPath, "w")
    if not wf then return false end
    wf:write(content)
    wf:close()
    return true
end

local function applyPositions(wx, wy, ww, wh, sx, sy, sw, sh, s, activateAll)
    local marginX = math.max(12, round(24 * s))
    local topY = wy + math.max(12, round(16 * s))
    local gapY = math.max(8, round(12 * s))
    local cardW = round(272 * s)
    local leftX = wx + marginX
    local rightX = wx + ww - cardW - marginX

    local hHero = round(122 * s)
    local hClock = round(112 * s)
    local hWeather = round(96 * s)
    local hCalendar = round(82 * s)
    local hSys = round(122 * s)
    local hGpu = round(110 * s)
    local hPwr = round(110 * s)
    local hAgy = round(122 * s)

    local fftW = 2 * round(12 * s) + 24 * math.max(2, round(8 * s)) + 23 * math.max(1, round(4 * s))
    local fftH = round(34 * s)
    local fftX = wx + math.floor((ww - fftW) / 2)

    local workBottom = wy + wh
    local screenBottom = sy + sh
    local bottomReserved = math.max(0, screenBottom - workBottom)
    local dockClear = (bottomReserved < 36) and math.max(82, round(96 * s)) or math.max(14, round(18 * s))
    local fftY = workBottom - dockClear - fftH

    local active = activateAll and {} or readActiveConfigs()

    local function place(cfg, ini, x, y, forceActivate)
        if activateAll or forceActivate or active[cfg] then
            if activateAll or forceActivate then
                SKIN:Bang("!ActivateConfig", cfg, ini)
            end
            SKIN:Bang("!Move", tostring(x), tostring(y), cfg)
            SKIN:Bang("!ZPos", "0", cfg)
        end
    end

    local useAltClock = (not activateAll) and active["AmoledTerminal\\Clock"] and (not active["AmoledTerminal\\HeroClock"])
    local topLeftH = useAltClock and hClock or hHero

    if useAltClock then
        place("AmoledTerminal\\Clock", "Clock.ini", leftX, topY, false)
    else
        place("AmoledTerminal\\HeroClock", "HeroClock.ini", leftX, topY, activateAll)
    end
    place("AmoledTerminal\\Weather", "Weather.ini", leftX, topY + topLeftH + gapY, false)
    place("AmoledTerminal\\Calendar", "Calendar.ini", leftX, topY + topLeftH + gapY + hWeather + gapY, false)
    place("AmoledTerminal\\Notes", "Notes.ini", leftX, topY + topLeftH + gapY + hWeather + gapY + hCalendar + gapY, false)

    place("AmoledTerminal\\SysPill", "SysPill.ini", rightX, topY, false)
    place("AmoledTerminal\\GpuThermals", "GpuThermals.ini", rightX, topY + hSys + gapY, false)
    place("AmoledTerminal\\PowerAudio", "PowerAudio.ini", rightX, topY + hSys + gapY + hGpu + gapY, false)
    place("AmoledTerminal\\AgyTokens", "AgyTokens.ini", rightX, topY + hSys + gapY + hGpu + gapY + hPwr + gapY, false)
    place("AmoledTerminal\\TerminalDock", "TerminalDock.ini", rightX, topY + hSys + gapY + hGpu + gapY + hPwr + gapY + hAgy + gapY, false)

    place("AmoledTerminal\\AudioFFT", "AudioFFT.ini", fftX, fftY, false)

    if active["AmoledTerminal\\Settings"] then
        local setW = round(280 * s)
        local setH = round(352 * s)
        local setX = wx + math.floor((ww - setW) / 2)
        local setY = wy + math.floor((wh - setH) / 2)
        SKIN:Bang("!Move", tostring(setX), tostring(setY), "AmoledTerminal\\Settings")
    end

    if active["AmoledTerminal\\AgyTokensExpand"] then
        local expW = round(304 * s)
        local expH = round(356 * s)
        local agyY = topY + hSys + gapY + hGpu + gapY + hPwr + gapY
        local expX = math.max(wx + marginX, rightX - expW - gapY)
        local expY = clamp(agyY - math.floor((expH - hAgy) / 2), topY, workBottom - dockClear - expH)
        SKIN:Bang("!Move", tostring(expX), tostring(expY), "AmoledTerminal\\AgyTokensExpand")
        SKIN:Bang("!ZPos", "1", "AmoledTerminal\\AgyTokensExpand")
    end
end

function PositionExpand()
    local wx, wy, ww, wh, sx, sy, sw, sh = getMonitorMetrics()
    if ww <= 0 or wh <= 0 then return end
    local s = tonumber(SKIN:GetVariable("S", "1")) or 1
    local marginX = math.max(12, round(24 * s))
    local topY = wy + math.max(12, round(16 * s))
    local gapY = math.max(8, round(12 * s))
    local cardW = round(272 * s)
    local rightX = wx + ww - cardW - marginX
    local hSys = round(122 * s)
    local hGpu = round(110 * s)
    local hPwr = round(110 * s)
    local hAgy = round(122 * s)
    local expW = round(304 * s)
    local expH = round(356 * s)
    local workBottom = wy + wh
    local screenBottom = sy + sh
    local bottomReserved = math.max(0, screenBottom - workBottom)
    local dockClear = (bottomReserved < 36) and math.max(82, round(96 * s)) or math.max(14, round(18 * s))
    local agyY = topY + hSys + gapY + hGpu + gapY + hPwr + gapY
    local expX = math.max(wx + marginX, rightX - expW - gapY)
    local expY = clamp(agyY - math.floor((expH - hAgy) / 2), topY, workBottom - dockClear - expH)
    SKIN:Bang("!Move", tostring(expX), tostring(expY), "AmoledTerminal\\AgyTokensExpand")
    SKIN:Bang("!ZPos", "1", "AmoledTerminal\\AgyTokensExpand")
end

local tickCount = 0

function Initialize()
    tickCount = 0
    lastSysSig = nil
end

function Update()
    if SKIN:GetVariable("CURRENTCONFIG") ~= "AmoledTerminal\\HeroClock" then
        return 0
    end
    tickCount = tickCount + 1
    if tickCount < 2 then
        return 0
    end

    -- When SysInfo detects a display topology or workarea change at runtime,
    -- refresh HeroClock first so #WORKAREA*# / #SCREENAREA*# reflect Windows' updated rcWork.
    if checkDisplayChanged() then
        SKIN:Bang("!Refresh")
        return 0
    end

    local wx, wy, ww, wh, sx, sy, sw, sh = getMonitorMetrics()
    if ww <= 0 or wh <= 0 then return 0 end

    local areaKey = string.format("%d,%d,%d,%d,%d,%d", wx, wy, ww, wh, sw, sh)
    local curS = tonumber(SKIN:GetVariable("S", "1")) or 1
    local lastArea = SKIN:GetVariable("LastAreaKey", "")
    local pending = SKIN:GetVariable("PendingLayout", "0")
    local newS = computeScale(ww, wh, sy, sh, wy)

    if pending == "1" then
        applyPositions(wx, wy, ww, wh, sx, sy, sw, sh, curS, false)
        updateVariablesFile(curS, areaKey, "0")
        SKIN:Bang("!SetVariable", "PendingLayout", "0")
        SKIN:Bang("!SetVariable", "LastAreaKey", areaKey)
        return 1
    end

    if areaKey ~= lastArea or math.abs(newS - curS) >= 0.02 then
        if math.abs(newS - curS) >= 0.02 then
            updateVariablesFile(newS, areaKey, "1")
            SKIN:Bang("!RefreshGroup", "AmoledTerminal")
        else
            applyPositions(wx, wy, ww, wh, sx, sy, sw, sh, newS, false)
            updateVariablesFile(newS, areaKey, "0")
            SKIN:Bang("!SetVariable", "LastAreaKey", areaKey)
        end
    end
    return 0
end

function ResetLayout()
    local wx, wy, ww, wh, sx, sy, sw, sh = getMonitorMetrics()
    if ww <= 0 or wh <= 0 then return end
    local areaKey = string.format("%d,%d,%d,%d,%d,%d", wx, wy, ww, wh, sw, sh)
    local curS = tonumber(SKIN:GetVariable("S", "1")) or 1
    local newS = computeScale(ww, wh, sy, sh, wy)

    if math.abs(newS - curS) >= 0.02 then
        -- Activate default skins first, then write new scale and refresh so sizes + positions update together
        applyPositions(wx, wy, ww, wh, sx, sy, sw, sh, newS, true)
        updateVariablesFile(newS, areaKey, "1")
        SKIN:Bang("!RefreshGroup", "AmoledTerminal")
    else
        applyPositions(wx, wy, ww, wh, sx, sy, sw, sh, curS, true)
        updateVariablesFile(curS, areaKey, "0")
    end
end
