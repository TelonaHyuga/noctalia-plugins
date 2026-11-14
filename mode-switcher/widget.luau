local modeName = ""

local function render()
    barWidget.render(ui.row({ gap = 6, align = "center" }, {
        ui.glyph({ name = "glass-full-filled", size = 14 }),
        ui.label({ text = modeName, fontWeight = "bold" }),
    }))
end

function update()
    render()
end

function onClick()
    noctalia.togglePanel("user/mode-switcher:modes")
end

function onRightClick()
    noctalia.togglePanel("user/mode-switcher:settings")
end

function onScroll(axis, steps)
    if axis == "vertical" then
        if steps > 0 then
            noctalia.state.set("req", "next\x1f" .. tostring(noctalia.nowMs()))
        else
            noctalia.state.set("req", "prev\x1f" .. tostring(noctalia.nowMs()))
        end
    end
end

noctalia.state.watch("current_mode", function(val)
    modeName = val or ""
    render()
end)

modeName = noctalia.state.get("current_mode") or ""
render()   
