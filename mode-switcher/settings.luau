local modesData = ""
local currentIdx = 1
local selectedMode = 1
local newModeName = ""
local newLaunchCmd = ""
local newKillCmd = ""
local expandedCmd = nil
local editWs = ""
local editDisp = ""

local function parseModes()
    local result = {}
    if not modesData or modesData == "" then return result end
    for line in modesData:gmatch("[^\n]+") do
        local parts = {}
        for part in line:gmatch("[^\x1f]+") do
            table.insert(parts, part)
        end
        if #parts >= 2 then
            local idx = tonumber(parts[1])
            local name = parts[2]
            local launch = {}
            local kill = {}
            for i = 3, #parts do
                if parts[i]:sub(1, 2) == "L:" then
                    table.insert(launch, parts[i]:sub(3))
                elseif parts[i]:sub(1, 2) == "K:" then
                    table.insert(kill, parts[i]:sub(3))
                end
            end
            table.insert(result, { idx = idx, name = name, launch = launch, kill = kill })
        end
    end
    return result
end

local function parseLaunchCmd(rawCmd)
    local parts = {}
    for part in rawCmd:gmatch("[^|]+") do
        table.insert(parts, part)
    end
    local base = parts[1] or rawCmd
    local ws = ""
    local disp = ""
    for i = 2, #parts do
        local w = parts[i]:match("^ws:(%d+)$")
        if w then ws = w end
        local d = parts[i]:match("^disp:([%w%-]+)$")
        if d then disp = d end
    end
    return base, ws, disp
end

local function buildLaunchCmdStr(base, ws, disp)
    local s = base
    if ws ~= "" then s = s .. "|ws:" .. ws end
    if disp ~= "" then s = s .. "|disp:" .. disp end
    return s
end

local function sendReq(action, ...)
    local parts = { action }
    for _, p in ipairs({...}) do
        table.insert(parts, p)
    end
    table.insert(parts, tostring(noctalia.nowMs()))
    noctalia.state.set("req", table.concat(parts, "\x1f"))
end

local function openEdit(ci)
    if expandedCmd == ci then
        expandedCmd = nil
    else
        expandedCmd = ci
        local modes = parseModes()
        if modes[selectedMode] then
            local sel = modes[selectedMode]
            if sel.launch[ci] then
                local _, ws, disp = parseLaunchCmd(sel.launch[ci])
                editWs = ws
                editDisp = disp
            else
                editWs = ""
                editDisp = ""
            end
        end
    end
    render()
end

local function saveEdit()
    local modes = parseModes()
    if modes[selectedMode] and modes[selectedMode].launch[expandedCmd] then
        local base = modes[selectedMode].launch[expandedCmd]
        local b, _, _ = parseLaunchCmd(base)
        local newCmd = buildLaunchCmdStr(b, editWs, editDisp)
        sendReq("set_launch", tostring(selectedMode), tostring(expandedCmd), newCmd)
    end
    expandedCmd = nil
    editWs = ""
    editDisp = ""
end

local function render()
    local modes = parseModes()
    local children = {}
    table.insert(children, ui.label({ text = noctalia.tr("settings.title"), fontSize = 18, fontWeight = "bold" }))

    table.insert(children, ui.row({ gap = 8 }, {
        ui.input({ placeholder = noctalia.tr("settings.new_mode"), value = newModeName, onChange = function(v) newModeName = v end, flexGrow = 1 }),
        ui.button({ text = noctalia.tr("settings.create"), variant = "primary", onClick = function()
            local name = newModeName
            if name == "" then name = "Mode " .. (#modes + 1) end
            newModeName = ""
            sendReq("add_mode", name)
        end }),
    }))

    if #modes == 0 then
        table.insert(children, ui.label({ text = noctalia.tr("settings.no_modes") }))
        panel.render(ui.column({ flexGrow = 1 }, {
            ui.scroll({ flexGrow = 1, gap = 10 }, children),
        }))
        return
    end

    if selectedMode > #modes then selectedMode = #modes end
    if selectedMode < 1 then selectedMode = 1 end

    local sel = modes[selectedMode]

    table.insert(children, ui.row({ gap = 6, align = "center" }, {
        ui.button({ text = "\xe2\x86\x90", onClick = function()
            selectedMode = math.max(1, selectedMode - 1)
            expandedCmd = nil
            render()
        end }),
        ui.label({ text = sel.name .. " (" .. selectedMode .. "/" .. #modes .. ")", fontWeight = "bold", flexGrow = 1 }),
        ui.button({ text = "\xe2\x86\x92", onClick = function()
            selectedMode = math.min(#modes, selectedMode + 1)
            expandedCmd = nil
            render()
        end }),
        ui.button({ text = "\xe2\x9c\x95", variant = "danger", onClick = function()
            sendReq("del_mode", tostring(selectedMode))
        end }),
    }))

    -- Launch
    table.insert(children, ui.label({ text = "\xe2\x94\x80\xe2\x94\x80 " .. noctalia.tr("settings.launch") .. " \xe2\x94\x80\xe2\x94\x80", fontWeight = "bold" }))
    for i, cmd in ipairs(sel.launch) do
        local ci = i
        local base, ws, disp = parseLaunchCmd(cmd)
        table.insert(children, ui.row({ gap = 6, align = "center" }, {
            ui.label({ text = base, flexGrow = 1 }),
            ui.button({ text = "\xe2\x9a\x99", variant = "ghost", onClick = function()
                openEdit(ci)
            end }),
            ui.button({ text = "\xe2\x9c\x95", variant = "ghost", onClick = function()
                sendReq("del_launch", tostring(selectedMode), tostring(ci))
                if expandedCmd == ci then expandedCmd = nil end
            end }),
        }))

        if expandedCmd == ci then
            table.insert(children, ui.row({ gap = 6, align = "center" }, {
                ui.label({ text = "  WS:", color = "muted" }),
                ui.input({ placeholder = "1, 2, 3...", value = editWs, onChange = function(v) editWs = v end, flexGrow = 1 }),
                ui.label({ text = "Disp:", color = "muted" }),
                ui.input({ placeholder = "DP-2, HDMI-A-1", value = editDisp, onChange = function(v) editDisp = v end, flexGrow = 1 }),
                ui.button({ text = "\xe2\x9c\x93", variant = "primary", onClick = function()
                    saveEdit()
                end }),
            }))
        end
    end
    if #sel.launch == 0 then
        table.insert(children, ui.label({ text = noctalia.tr("settings.empty") }))
    end
    table.insert(children, ui.row({ gap = 8 }, {
        ui.input({ placeholder = noctalia.tr("settings.launch_cmd"), value = newLaunchCmd, onChange = function(v) newLaunchCmd = v end, flexGrow = 1 }),
        ui.button({ text = "+", variant = "primary", onClick = function()
            if newLaunchCmd ~= "" then
                local cmd = newLaunchCmd
                newLaunchCmd = ""
                sendReq("add_launch", tostring(selectedMode), cmd)
            end
        end }),
    }))

    -- Kill
    table.insert(children, ui.label({ text = "\xe2\x94\x80\xe2\x94\x80 " .. noctalia.tr("settings.kill") .. " \xe2\x94\x80\xe2\x94\x80", fontWeight = "bold" }))
    for i, cmd in ipairs(sel.kill) do
        local ci = i
        table.insert(children, ui.row({ gap = 6, align = "center" }, {
            ui.label({ text = cmd, flexGrow = 1 }),
            ui.button({ text = "\xe2\x9c\x95", variant = "ghost", onClick = function()
                sendReq("del_kill", tostring(selectedMode), tostring(ci))
            end }),
        }))
    end
    if #sel.kill == 0 then
        table.insert(children, ui.label({ text = noctalia.tr("settings.empty") }))
    end
    table.insert(children, ui.row({ gap = 8 }, {
        ui.input({ placeholder = noctalia.tr("settings.kill_cmd"), value = newKillCmd, onChange = function(v) newKillCmd = v end, flexGrow = 1 }),
        ui.button({ text = "+", variant = "primary", onClick = function()
            if newKillCmd ~= "" then
                local cmd = newKillCmd
                newKillCmd = ""
                sendReq("add_kill", tostring(selectedMode), cmd)
            end
        end }),
    }))

    panel.render(ui.column({ flexGrow = 1 }, {
        ui.scroll({ flexGrow = 1, gap = 10 }, children),
    }))
end

function onOpen(context)
    modesData = noctalia.state.get("modes_data") or ""
    currentIdx = noctalia.state.get("current_idx") or 1
    selectedMode = currentIdx
    expandedCmd = nil
    editWs = ""
    editDisp = ""
    render()
end

function onClose()
end

noctalia.state.watch("modes_data", function(val)
    modesData = val or ""
    render()
end)   