noctalia.log("MS: 1")

local HOME = "/home/telona"
local DATA_DIR = HOME .. "/.local/state/noctalia/mode-switcher"
local MODES_FILE = DATA_DIR .. "/modes.txt"

noctalia.log("MS: 2")

local modes = { { name = "Режим 1", launch = {}, kill = {} } }
local currentIdx = 1

noctalia.log("MS: 3")

local function saveModes()
    local parts = {}
    for i, m in ipairs(modes) do
        if i > 1 then table.insert(parts, "---") end
        table.insert(parts, "# " .. m.name)
        for _, cmd in ipairs(m.launch) do
            table.insert(parts, "L " .. cmd)
        end
        for _, cmd in ipairs(m.kill) do
            table.insert(parts, "K " .. cmd)
        end
    end
    pcall(function() noctalia.runAsync("mkdir -p " .. DATA_DIR) end)
    pcall(function() noctalia.writeFile(MODES_FILE, table.concat(parts, "\n") .. "\n") end)
end

local function loadModes()
    local ok, content = pcall(function()
        return noctalia.readFile(MODES_FILE)
    end)
    if not ok or not content then return end

    local newModes = {}
    local cur = nil
    for line in content:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line == "" then
        elseif line == "---" then
            cur = nil
        else
            local mname = line:match("^# (.+)$")
            if mname then
                cur = { name = mname, launch = {}, kill = {} }
                table.insert(newModes, cur)
            elseif cur then
                local lcmd = line:match("^L (.+)$")
                if lcmd then table.insert(cur.launch, lcmd) end
                local kcmd = line:match("^K (.+)$")
                if kcmd then table.insert(cur.kill, kcmd) end
            end
        end
    end
    if #newModes > 0 then modes = newModes end
    if currentIdx > #modes then currentIdx = #modes end
    if currentIdx < 1 then currentIdx = 1 end
end

local function publishState()
    local name = modes[currentIdx] and modes[currentIdx].name or ""
    noctalia.state.set("current_mode", name)
    noctalia.state.set("current_idx", currentIdx)

    local lines = {}
    for i, m in ipairs(modes) do
        local parts = { tostring(i), m.name }
        for _, c in ipairs(m.launch) do
            table.insert(parts, "L:" .. c)
        end
        for _, c in ipairs(m.kill) do
            table.insert(parts, "K:" .. c)
        end
        table.insert(lines, table.concat(parts, "\x1f"))
    end
    noctalia.state.set("modes_data", table.concat(lines, "\n"))
end

local function buildLaunchCmd(rawCmd)
    local parts = {}
    for part in rawCmd:gmatch("[^|]+") do
        table.insert(parts, part)
    end
    local baseCmd = parts[1]
    local ws = nil
    local disp = nil
    for i = 2, #parts do
        local w = parts[i]:match("^ws:(%d+)$")
        if w then ws = w end
        local d = parts[i]:match("^disp:([%w%-]+)$")
        if d then disp = d end
    end

    local prefix = "env WAYLAND_DISPLAY=wayland-1 "
    local cmds = {}

    if disp then
        table.insert(cmds, "hyprctl dispatch 'hl.dsp.focus({ monitor = \"" .. disp .. "\" })'")
    end
    if ws then
        table.insert(cmds, "hyprctl dispatch 'hl.dsp.focus({ workspace = \"" .. ws .. "\" })'")
    end
    table.insert(cmds, baseCmd)

    return prefix .. "sh -c '" .. table.concat(cmds, " && ") .. "'"
end

local function doSwitch(newIdx)
    if newIdx < 1 or newIdx > #modes then return end
    if newIdx == currentIdx then return end

    if modes[currentIdx] then
        for _, cmd in ipairs(modes[currentIdx].kill) do
            noctalia.log("MS: kill: " .. cmd)
            pcall(function() noctalia.runAsync(cmd) end)
        end
    end

    currentIdx = newIdx

    if modes[currentIdx] then
        for _, cmd in ipairs(modes[currentIdx].launch) do
            local fullCmd = buildLaunchCmd(cmd)
            noctalia.log("MS: launch: " .. fullCmd)
            pcall(function() noctalia.runAsync(fullCmd) end)
        end
    end

    publishState()
end

noctalia.log("MS: 4")
loadModes()
noctalia.log("MS: 5, count=" .. #modes)
publishState()
noctalia.log("MS: 6, ready, current=" .. (modes[currentIdx] and modes[currentIdx].name or "?"))

local lastReq = ""
noctalia.state.watch("req", function(val)
    if not val or val == lastReq then return end
    lastReq = val
    noctalia.log("MS: req: " .. val)

    local parts = {}
    for part in val:gmatch("[^\x1f]+") do
        table.insert(parts, part)
    end
    if #parts > 1 then table.remove(parts, #parts) end

    local action = parts[1]
    if not action then return end

    if action == "next" then
        doSwitch((currentIdx % #modes) + 1)
    elseif action == "prev" then
        doSwitch((currentIdx - 2 + #modes) % #modes + 1)
    elseif action == "goto" then
        local idx = tonumber(parts[2])
        if idx then doSwitch(idx) end
    elseif action == "add_mode" then
        local name = parts[2] or ("Режим " .. (#modes + 1))
        table.insert(modes, { name = name, launch = {}, kill = {} })
        saveModes()
        publishState()
        noctalia.log("MS: added '" .. name .. "'")
    elseif action == "del_mode" then
        local idx = tonumber(parts[2])
        if idx and idx >= 1 and idx <= #modes then
            table.remove(modes, idx)
            if currentIdx > #modes then currentIdx = #modes end
            if #modes == 0 then
                modes = { { name = "Режим 1", launch = {}, kill = {} } }
                currentIdx = 1
            end
            saveModes()
            publishState()
        end
    elseif action == "add_launch" then
        local mi = tonumber(parts[2])
        local cmd = parts[3]
        if mi and cmd and modes[mi] then
            table.insert(modes[mi].launch, cmd)
            saveModes()
            publishState()
        end
    elseif action == "add_kill" then
        local mi = tonumber(parts[2])
        local cmd = parts[3]
        if mi and cmd and modes[mi] then
            if not cmd:match("^pkill ") then
                cmd = "pkill " .. cmd
            end
            table.insert(modes[mi].kill, cmd)
            saveModes()
            publishState()
        end
    elseif action == "del_launch" then
        local mi = tonumber(parts[2])
        local ci = tonumber(parts[3])
        if mi and ci and modes[mi] then
            table.remove(modes[mi].launch, ci)
            saveModes()
            publishState()
        end
    elseif action == "del_kill" then
        local mi = tonumber(parts[2])
        local ci = tonumber(parts[3])
        if mi and ci and modes[mi] then
            table.remove(modes[mi].kill, ci)
            saveModes()
            publishState()
        end
    elseif action == "set_launch" then
        local mi = tonumber(parts[2])
        local ci = tonumber(parts[3])
        local newCmd = parts[4]
        if mi and ci and newCmd and modes[mi] and modes[mi].launch[ci] then
            modes[mi].launch[ci] = newCmd
            saveModes()
            publishState()
        end
    end
end)
