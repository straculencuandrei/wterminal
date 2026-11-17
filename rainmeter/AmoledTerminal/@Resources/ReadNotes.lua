function Initialize()
    NotesPath = SKIN:GetVariable("@") .. "notes.txt"
end

function Update()
    local f = io.open(NotesPath, "r")
    if not f then
        return "click to create notes.txt"
    end
    local lines = {}
    for line in f:lines() do
        if #lines < 6 then
            table.insert(lines, line)
        end
    end
    f:close()
    if #lines == 0 then
        return "(empty)"
    end
    return table.concat(lines, "\n")
end
