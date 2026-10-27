local context_menu = require("scripts/context-menu") ---@module "recipe-tweaker/scripts/context-menu"
local editable = require("scripts/editable") ---@module "recipe-tweaker/scripts/editable"
local glib = require("__glib__/glib") ---@module "glib/glib"
local utils = require("scripts/utils") ---@module "recipe-tweaker/scripts/utils"

---@type RecipeTweaker.handlers
local handlers = {}
local entries = {}

---@param elem_type "item"|"fluid"
---@param is_product? boolean
function entries.add_button(elem_type, is_product)
    local elem_filters = elem_type ~= "fluid" and {
        {filter = "is-parameter", invert = true},
        {filter = "flag", flag = "spawnable", invert = true, mode = "and"},
        {filter = "hidden", invert = true, mode = "and"},
    } or {
        {filter = "subgroup", subgroup = "parameters", invert = true}
    }
    return {
        args = {
            type = "choose-elem-button", elem_type = elem_type == "fluid" and "fluid" or "item",
            style = "button", elem_filters = elem_filters, tags = {is_product = is_product, type = elem_type},
        },
        _elem_changed = handlers.add_entry,
        children = {{
            args = {type = "flow"},
            style_mods = {horizontally_stretchable = true},
            children = {{
                args = {type = "label", caption = "+ Add " .. elem_type, style = "semibold_label"},
                style_mods = {font_color = {}},
            }}
        }}
    }
end

function handlers.add_entry(button, refs)
    if button.elem_value == nil then return end
    local flow = button.parent.parent.entries
    local value = button.elem_value --[[@as string]]
    button.elem_value = nil
    if not button.tags.is_product then
        for _, ingredient in pairs(flow.children) do
            local tags = ingredient.tags
            if tags.type == button.elem_type and tags.name == value then
                utils.warn(button.player_index, "Ingredient already exists")
                return
            end
        end
    end
    glib.add(flow, entries.entry(button.tags.type --[[@as EntryType]], value, button.tags.is_product --[[@as boolean]]))
    utils.validate_confirm(refs)
end

---@param elem_type EntryType
---@param name string
---@param is_product? boolean
---@param entry? Ingredient|Product
---@return GuiElemDef
function entries.entry(elem_type, name, is_product, entry)
    entry = entry or {}

    local is_fluid = elem_type == "fluid"

    ---@type GuiElemDef[]
    local children = {{
        args = {type = "choose-elem-button", name = "button", elem_type = is_fluid and "fluid" or "item", item = name, fluid = name},
        _elem_changed = handlers.elem_changed,
    }}

    local function append(def)
        children[#children+1] = def
    end

    append(editable.label("amount", "× %s", entry.amount or 1, entry.amount_min == nil, {handler = handlers.amount, decimal = is_fluid}))

    if is_product then
        local probability = entry.probability or 1
        table.insert(children, 2, editable.label("probability", "%s%%", probability * 100, probability < 1, {handler = handlers.percentage}))
        append(editable.label("amount_min", "× %d", entry.amount_min or 1, entry.amount_min ~= nil, {handler = handlers.amount_min, decimal = is_fluid}))
        append(editable.label("amount_max", "– %d", entry.amount_max or 2, entry.amount_max ~= nil, {handler = handlers.amount_max, decimal = is_fluid}))
        if elem_type == "item" then
            append(editable.label("extra_count_fraction", "+ %s", entry.extra_count_fraction or 1, entry.extra_count_fraction ~= nil, {handler = handlers.fraction}))
            append(editable.label("percent_spoiled", "(%s%% spoiled)", (entry.percent_spoiled or 0) * 100, entry.percent_spoiled ~= nil, {handler = handlers.percentage}))
        end
    end

    if is_fluid then
        local fluid = prototypes.fluid[name]
        append(editable.label("temperature", "%d°C", entry.temperature or fluid.default_temperature, entry.temperature ~= nil, {handler = handlers.temperature, negative = true}))
        if not is_product then
            local min_temp, max_temp = entry.minimum_temperature, entry.maximum_temperature
            append(editable.label("minimum_temperature", "%d°C", min_temp or fluid.default_temperature, min_temp ~= nil, {handler = handlers.temperature_min, negative = true}))
            append(editable.label("maximum_temperature", "– %d°C", max_temp or fluid.max_temperature, max_temp ~= nil, {handler = handlers.temperature_max, negative = true}))
        end
    end

    return {
        args = {type = "frame", style = "rt_entry_frame", tags = {is_product = is_product, type = elem_type, name = name}},
        _click = context_menu.click_handler,
        children = children,
    }
end

function handlers.elem_changed(button, refs)
    if button.elem_value == nil then
        button.parent.destroy()
    else
        glib.set_tag(button.parent, "name", button.elem_value)
    end
    utils.validate_confirm(refs)
end

---@return GuiElemDef
function entries.max_productivity()
    return {
        args = {type = "flow"},
        children = {
            {args = {type = "label", caption = "Maximum prodictivity:"}},
            editable.label("max_productivity", "%s%%", 300, true, {handler = handlers.max_productivity}),
        }
    }
end

local text_map = {
    [""] = "0",
    ["."] = "0.",
}

---@param text string
local function get_value(text)
    return tonumber(text_map[text] or text) --[[@as number]]
end

---@param handler fun(value: number, textfield: LuaGuiElement): number
local function text_wrapper(handler)
    return function(textfield, refs, event)
        local value = get_value(textfield.text)
        textfield.text = tostring(handler(value, textfield))
        editable.confirm(textfield, refs, event)
    end
end

local function min_handler(n)
    return text_wrapper(function(value)
        return math.min(n, value)
    end)
end

handlers.percentage = min_handler(100)
handlers.fraction = min_handler(1)

---@param handler fun(value: number, textfield: LuaGuiElement)
---@param name string
---@param min boolean
local function range_handler(handler, name, min)
    return function(textfield, refs, event)
        local value = get_value(textfield.text)
        value = handler(value, textfield)
        local other = textfield.parent.parent[name]
        local text = tostring(value)
        if (tonumber(other.label.tags.value) < value) == min then
            other.textfield.text = text
            editable.confirm(other.textfield, refs, event)
        end
        textfield.text = text
        editable.confirm(textfield, refs, event)
    end
end

local function amount_clamp(value, textfield)
    local frame = textfield.parent.parent
    if frame.tags.type ~= "fluid" then
        value = math.min(65535, value)
    end
    if not frame.tags.is_product and value == 0 then
        value = 1
    end
    return value
end

handlers.amount = text_wrapper(amount_clamp)
handlers.amount_min = range_handler(amount_clamp, "amount_max", true)
handlers.amount_max = range_handler(amount_clamp, "amount_min", false)

local function temperature_clamp(value, textfield)
    local fluid = prototypes.fluid[textfield.parent.parent.tags.name --[[@as string]]]
    return math.max(fluid.default_temperature, math.min(fluid.max_temperature, value))
end

handlers.temperature = text_wrapper(temperature_clamp)
handlers.temperature_min = range_handler(temperature_clamp, "maximum_temperature", true)
handlers.temperature_max = range_handler(temperature_clamp, "minimum_temperature", false)

handlers.max_productivity = text_wrapper(function(value, textfield)
    value = math.max(0, value)
    return value
end)

utils.register_handlers(handlers, "entries")

return entries

---@alias EntryType "item"|"fluid"