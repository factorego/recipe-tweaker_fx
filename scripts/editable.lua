local context_menu = require("scripts/context-menu") ---@module "recipe-tweaker/scripts/context-menu"
local glib = require("__glib__/glib") ---@module "glib/glib"
local utils = require("scripts/utils") ---@module "recipe-tweaker/scripts/utils"

---@type RecipeTweaker.handlers
local handlers = {}
local editable = {}

-- LABEL

---@param label LuaGuiElement
---@param value AnyBasic
function editable.format_label(label, value)
    glib.set_tag(label, "value", value)
    label.caption = string.format(label.tags.format --[[@as string]] or "", tostring(value))
end

---@param name string
---@param format string
---@param value AnyBasic
---@param visible? boolean
---@param options? {handler: RecipeTweaker.handler, decimal: boolean, negative: boolean}
function editable.label(name, format, value, visible, options)
    options = options or {}
    local caption = value or ""
    if format then
        caption = string.format(format, caption)
    end
    return {
        args = {type = "flow", name = name, visible = visible},
        children = {{
            args = {type = "label", name = "label", caption = caption, style = "clickable_label", tags = {format = format, value = tostring(value)}},
            ref = false,
            _click = handlers.click,
        }, {
            args = {
                type = "textfield", name = "textfield", style = "short_number_textfield", visible = false,
                numeric = true, allow_decimal = options.decimal == nil and true, allow_negative = options.negative,
            },
            ref = false,
            _confirmed = options.handler or handlers.confirm,
        }}
    }
end

---@param event EventData.on_gui_click
function handlers.click(label, refs, event)
    if event.button == defines.mouse_button_type.right then
        context_menu.click_handler(label.parent.parent, refs, event)
        return
    end

    local textfield = label.parent.textfield
    textfield.text = tostring(label.tags.value)
    label.visible = false
    textfield.visible = true
    textfield.focus()
    textfield.select_all()

    local editing = storage.editing[event.player_index]
    if editing and editing.valid then
        handlers.confirm(editing, refs, event)
    end
    storage.editing[event.player_index] = textfield
end

---@param textfield LuaGuiElement
---@param refs table<string, LuaGuiElement>
---@param event GuiEventData
function editable.confirm(textfield, refs, event)
    local label = textfield.parent.label
    editable.format_label(label, textfield.text)
    textfield.visible = false
    label.visible = true
    utils.validate_confirm(refs)
    storage.editing[event.player_index] = nil
end
handlers.confirm = editable.confirm

-- CHECKBOX

function editable.checkbox(name, caption)
    return {
        args = {type = "checkbox", name = name, caption = caption, state = false},
        ref = false,
        _checked_state_changed = handlers.checkbox
    }
end

function handlers.checkbox(_, refs)
    utils.validate_confirm(refs)
end

utils.register_handlers(handlers, "editable")

return editable