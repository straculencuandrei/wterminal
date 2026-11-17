local p = io.popen('starship init cmd')
if p then
    local script = p:read('*a')
    p:close()
    if script and #script > 0 then
        local fn = load(script)
        if fn then fn() end
    end
end
