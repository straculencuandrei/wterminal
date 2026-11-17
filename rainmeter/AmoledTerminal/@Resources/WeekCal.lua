function Update()
    local now = os.time()
    local t = os.date("*t", now)
    -- Convert Sunday=1..Saturday=7 to Monday=1..Sunday=7
    local wday = (t.wday == 1) and 7 or (t.wday - 1)
    local monday = now - (wday - 1) * 86400

    for i = 1, 7 do
        local dt = os.date("*t", monday + (i - 1) * 86400)
        local dayStr = string.format("%02d", dt.day)
        SKIN:Bang("!SetOption", "MeterDay" .. i, "Text", dayStr)
        if i == wday then
            SKIN:Bang("!SetOption", "MeterDay" .. i, "FontColor", "5,5,7,255")
            SKIN:Bang("!SetOption", "MeterDay" .. i, "FontWeight", "700")
            SKIN:Bang("!SetOption", "MeterDayLbl" .. i, "FontColor", "#TermGreen#")
            local pillX = 15 + (i - 1) * 35
            SKIN:Bang("!SetOption", "MeterTodayPill", "X", tostring(pillX))
        else
            SKIN:Bang("!SetOption", "MeterDay" .. i, "FontColor", "#TextSecondary#")
            SKIN:Bang("!SetOption", "MeterDay" .. i, "FontWeight", "500")
            SKIN:Bang("!SetOption", "MeterDayLbl" .. i, "FontColor", "#TextMuted#")
        end
    end
    return t.day
end
