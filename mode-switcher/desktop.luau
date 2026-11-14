local modeName = ""

local function render()
    desktopWidget.render(ui.column({ gap = 10, align = "center", padding = 12 }, {
        ui.label({ text = modeName, fontSize = 18, fontWeight = "bold", align = "center" }),
        ui.row({ gap = 16, justify = "center" }, {
            ui.button({
                glyph = "chevron-left",
                glyphSize = 20,
                variant = "ghost",
                onClick = function()
                    noctalia.state.set("req", "prev\x1f" .. tostring(noctalia.nowMs()))
                end,
            }),
            ui.button({
                glyph = "chevron-right",
                glyphSize = 20,
                variant = "ghost",
                onClick = function()
                    noctalia.state.set("req", "next\x1f" .. tostring(noctalia.nowMs()))
                end,
            }),
        }),
    }))
end

function update()
    render()
end

noctalia.state.watch("current_mode", function(val)
    modeName = val or ""
    render()
end)

modeName = noctalia.state.get("current_mode") or ""
render()   
