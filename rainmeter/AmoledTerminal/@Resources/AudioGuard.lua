-- Automatically refreshes AudioFFT once if the Windows default audio playback
-- device changes (e.g. unplugging HDMI monitor or plugging headphones), preventing
-- WASAPI loopback freezes without refreshing on volume changes or initial load.

local lastDevice = nil

function Update()
    local m = SKIN:GetMeasure("MeasureAudioDev")
    if not m then return 0 end
    local cur = m:GetStringValue() or ""
    if cur == "" then return 0 end

    if lastDevice == nil then
        lastDevice = cur
        return 0
    end

    if cur ~= lastDevice then
        lastDevice = cur
        SKIN:Bang("!Refresh")
        return 1
    end

    return 0
end
