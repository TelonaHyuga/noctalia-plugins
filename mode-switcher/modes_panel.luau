local modesData = ""
local currentIdx = 1

local function parseModes()
    local result = {}
    if not modesData or modesData == "" then return result end
    for line in modesData:gmatch("[^\n]+") do
        local idx, name = line:match("^(%d+)\x1f([^\x1f]+)")
        if idx then
            table.insert(result, { idx = tonumber(idx), name = name })
        end
    end
    return result
end

local function render()
    local modes = parseModes()
    local children = {}
    table.insert(children, ui.label({ text = noctalia.tr("modes.title"), fontSize = 16, fontWeight = "bold" }))

    for _, m in ipairs(modes) do
        local isCurrent = m.idx == currentIdx
        local prefix = ""
        local idx = m.idx
        table.insert(children, ui.button({
            text = prefix .. m.name,
            variant = isCurrent and "primary" or "ghost",
            onClick = function()
                noctalia.state.set("req", "goto\x1f" .. idx .. "\x1f" .. tostring(noctalia.nowMs()))
                panel.close()
            end,
        }))
    end

    panel.render(ui.column({ flexGrow = 1 }, {
        ui.scroll({ flexGrow = 1, gap = 10 }, children),
    }))
end

function onOpen(context)
    modesData = noctalia.state.get("modes_data") or ""
    currentIdx = noctalia.state.get("current_idx") or 1
    render()
end

function onClose()
end

noctalia.state.watch("modes_data", function(val)
    modesData = val or ""
    render()
end)

noctalia.state.watch("current_idx", function(val)
    currentIdx = val or 1
    render()
end)   
