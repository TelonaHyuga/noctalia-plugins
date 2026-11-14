local modesData = ""
local currentIdx = 1
local selectedMode = 1
local newModeName = ""
local newLaunchCmd = ""
local newKillCmd = ""

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

local function sendReq(action, ...)
    local parts = { action }
    for _, p in ipairs({...}) do
        table.insert(parts, p)
    end
    table.insert(parts, tostring(noctalia.nowMs()))
    noctalia.state.set("req", table.concat(parts, "\x1f"))
end

local function render()
    local modes = parseModes()
    local children = {}
    table.insert(children, ui.label({ text = noctalia.tr("settings.title"), fontSize = 18, fontWeight = "bold" }))

    table.insert(children, ui.row({ gap = 8 }, {
        ui.input({ placeholder = noctalia.tr("settings.new_mode"), value = newModeName, onChange = function(v) newModeName = v end, flexGrow = 1 }),
        ui.button({ text = noctalia.tr("settings.create"), variant = "primary", onClick = function()
            local name = newModeName
            if name == "" then name = noctalia.tr("modes.title") .. (#modes + 1) end
            newModeName = ""
            sendReq("add_mode", name)
        end }),
    }))

    if #modes == 0 then
        table.insert(children, ui.label({ text = noctalia.tr("settings.no_modes") }))
        panel.render(ui.scroll({ flexGrow = 1, gap = 10 }, children)) -- тут
        return
    end

    if selectedMode > #modes then selectedMode = #modes end
    if selectedMode < 1 then selectedMode = 1 end

    local sel = modes[selectedMode]

    table.insert(children, ui.row({ gap = 6, align = "center" }, {
        ui.button({ text = "←", onClick = function()
            selectedMode = math.max(1, selectedMode - 1)
            render()
        end }),
        ui.label({ text = sel.name .. " (" .. selectedMode .. "/" .. #modes .. ")", fontWeight = "bold", flexGrow = 1 }),
        ui.button({ text = "→", onClick = function()
            selectedMode = math.min(#modes, selectedMode + 1)
            render()
        end }),
        ui.button({ text = "✕", variant = "danger", onClick = function()
            sendReq("del_mode", tostring(selectedMode))
        end }),
    }))

    table.insert(children, ui.label({ text = "── " .. noctalia.tr("settings.launch") .. " ──", fontWeight = "bold" }))
    for i, cmd in ipairs(sel.launch) do
        local ci = i
        table.insert(children, ui.row({ gap = 6, align = "center" }, {
            ui.label({ text = cmd, flexGrow = 1 }),
            ui.button({ text = "✕", variant = "ghost", onClick = function()
                sendReq("del_launch", tostring(selectedMode), tostring(ci))
            end }),
        }))
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

    table.insert(children, ui.label({ text = "── " .. noctalia.tr("settings.kill") .. " ──", fontWeight = "bold" }))
    for i, cmd in ipairs(sel.kill) do
        local ci = i
        table.insert(children, ui.row({ gap = 6, align = "center" }, {
            ui.label({ text = cmd, flexGrow = 1 }),
            ui.button({ text = "✕", variant = "ghost", onClick = function()
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
    render()
end

function onClose()
end

noctalia.state.watch("modes_data", function(val)
    modesData = val or ""
    render()
end)   
