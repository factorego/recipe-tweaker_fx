local glib = require("__glib__/glib") ---@module "glib/glib"
local utils = require("scripts/utils") ---@module "recipe-tweaker/scripts/utils"

---@type RecipeTweaker.handlers
local handlers = {}
local lib = {}

---@param event EventData.on_gui_click
function handlers.context_menu(entry, refs, event)
    if event.button ~= defines.mouse_button_type.right then return end
    if not entry.tags.name then return end

    local player = game.get_player(event.player_index) --[[@as LuaPlayer]]

    ---@type GuiElemDef[]
    local list = {}

    ---@param name string
    ---@param visible boolean
    ---@param caption? string
    local function append(name, visible, caption)
        caption = string.format("%s %s", visible and "Hide" or "Show", caption or name)
        list[#list+1] = {
            args = {type = "button", name = name, caption = caption, style = "list_box_item"},
            style_mods = {horizontally_stretchable = true},
            _click = handlers.context_menu_select,
        }
    end

    local name = entry.button.elem_value --[[@as string]]
    local is_product = entry.tags.is_product
    local is_fluid = entry.button.elem_type == "fluid"

    if is_product then
        append("probability", entry.probability.visible)
        append("amount_range", entry.amount_min.visible, "amount range")
        if not is_fluid then
            append("extra_count_fraction", entry.extra_count_fraction.visible, "extra count fraction")
            if prototypes.item[entry.tags.name].get_spoil_ticks("normal") > 0 then
                append("percent_spoiled", entry.percent_spoiled.visible, "percent spoiled")
            end
        end
    end

    if is_fluid then
        local fluid = prototypes.fluid[name]
        if fluid.default_temperature ~= fluid.max_temperature then
            append("temperature", entry.temperature.visible)
            if not is_product then
                append("temperature_range", entry.minimum_temperature.visible, "temperature range")
            end
        end
    end

    if #list == 0 then
        utils.warn(event.player_index, "No options available")
        return
    end

    glib.add(player.gui.screen, {
        args = {type = "empty-widget", name = "rt_overlay"},
        style_mods = {size = player.display_resolution},
        _click = handlers.context_menu_close,
    }, refs)

    glib.add(player.gui.screen, {
        args = {type = "frame", name = "rt_context_menu", direction = "vertical", style = "invisible_frame"},
        elem_mods = {location = event.cursor_display_location},
        children = list
    }, refs)

    player.play_sound{
        path = "utility/entity_settings_copied",
    }

    storage.selected_entry[event.player_index] = entry
end
lib.click_handler = handlers.context_menu

---@param refs table<string, LuaGuiElement>
---@param index uint
function lib.close(refs, index)
    storage.selected_entry[index] = nil

    local menu = refs.rt_context_menu
    if not (menu and menu.valid) then return end

    menu.destroy()
    refs.rt_overlay.destroy()
end

function handlers.context_menu_close(_, refs, event)
    lib.close(refs, event.player_index)
end

---@type table<string, fun(entry: LuaGuiElement, name: string)>
local actions = {}

function actions.default(entry, name)
    local element = entry[name]
    element.visible = not element.visible
end

function actions.amount_range(entry)
    local is_visible = entry.amount_min.visible
    entry.amount.visible = is_visible
    entry.amount_min.visible = not is_visible
    entry.amount_max.visible = not is_visible
end

function actions.temperature(entry)
    local is_visible = entry.temperature.visible
    entry.temperature.visible = not is_visible
    if entry.minimum_temperature then
        entry.minimum_temperature.visible = false
        entry.maximum_temperature.visible = false
    end
end

function actions.temperature_range(entry)
    local is_visible = entry.minimum_temperature.visible
    entry.temperature.visible = false
    entry.minimum_temperature.visible = not is_visible
    entry.maximum_temperature.visible = not is_visible
end

function handlers.context_menu_select(element, refs, event)
    local action = actions[element.name] or actions.default
    local entry = storage.selected_entry[event.player_index]
    action(entry, element.name)
    lib.close(refs, event.player_index)
    utils.validate_confirm(refs)
end

utils.register_handlers(handlers, "context_menu")

return lib