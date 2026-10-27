local glib = require("__glib__/glib") ---@module "glib/glib"
local utils = require("scripts/utils") ---@module "recipe-tweaker/scripts/utils"

---@type RecipeTweaker.handlers
local handlers = {}
local export = {}

---@param refs table<string, LuaGuiElement>
---@param index uint
function export.create(refs, index)
    local tweaks = storage.tweaks[index]
    if table_size(tweaks) == 0 then
        utils.warn(index, "No tweaks to export")
        return
    end
    local s = utils.encode(tweaks)

    local player = game.get_player(index) --[[@as LuaPlayer]]
    local root = glib.add(player.gui.screen, {
        args = {type = "frame", name = "rt_export", direction = "vertical"},
        _closed = handlers.close,
        children = {{
            args = {type = "flow"},
            drag_target = "rt_export",
            children = {{
                args = {type = "label", caption = "Recipe tweak string", style = "frame_title", ignored_by_interaction = true},
            }, {
                args = {type = "empty-widget", style = "draggable_space_header", ignored_by_interaction = true},
                style_mods = {horizontally_stretchable = true, height = 24},
            }, {
                args = {type = "sprite-button", style = "close_button", sprite = "utility/close"},
                _click = handlers.close,
            }}
        }, {
            args = {type = "text-box", name = "textbox", style = "small_notice_textbox", text = s},
            ref = false
        }, {
            args = {type = "flow"},
            children = {{
                args = {type = "button", style = "dialog_button", caption = "Select all"},
                _click = handlers.select_all,
            }, {
                args = {type = "empty-widget"},
                style_mods = {horizontally_stretchable = true},
            }, {
                args = {type = "button", style = "dialog_button", caption = "OK"},
                _click = handlers.close,
            }}
        }}
    }, refs)

    root.force_auto_center()
    root.textbox.focus()
    root.textbox.select_all()
end

function export.close(refs)
    local element = refs.rt_export
    if element and element.valid then
        element.destroy()
    end
end

function handlers.close(_, refs)
    export.close(refs)
end

function handlers.select_all(_, refs)
    refs.rt_export.textbox.focus()
    refs.rt_export.textbox.select_all()
end

utils.register_handlers(handlers, "export")

return export