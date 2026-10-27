local editable = require("scripts/editable") ---@module "recipe-tweaker/scripts/editable"
local entries = require("scripts/entries") ---@module "recipe-tweaker/scripts/entries"
local glib = require("__glib__/glib") ---@module "glib/glib"
local utils = require("scripts/utils") ---@module "recipe-tweaker/scripts/utils"

---@type RecipeTweaker.handlers
local handlers = {}
local lib = {}

---@param name string
function lib.button(name)
    return {
        args = {type = "choose-elem-button", name = name, elem_type = "recipe", recipe = name},
        elem_mods = {locked = true},
        _click = handlers.click,
    }
end

function handlers.click(element, refs, event)
    if event.button == defines.mouse_button_type.left then
        refs.confirm.enabled = true
        lib.open(event.player_index, element.name)
    elseif event.button == defines.mouse_button_type.right then
        storage.tweaks[event.player_index][element.name] = nil
        element.destroy()
    end
end

---@return table?, uint?
local function find_entry(arr, type, name)
    for i, entry in pairs(arr) do
        if (entry[1] or entry.type) == type and (entry[2] or entry.name) == name then
            return entry, i
        end
    end
end

---@generic V
---@param change V
---@param current V
---@return V?
local function get_number_value(change, current)
    if change == false then return end
    return change or current
end

local preserve, fresh, reset = "preserve_products_in_machine_output", "result_is_always_fresh", "reset_freshness_on_craft"

---@param index uint
---@param recipe_name string
function lib.open(index, recipe_name)
    local refs = storage.refs[index]
    refs.menu.visible = false
    refs.tweak.visible = true

    refs.tweak_label.caption = string.format("[recipe=%s] %s", recipe_name, recipe_name)
    glib.set_tag(refs.tweak, "current", recipe_name)

    local tweak = storage.tweaks[index][recipe_name] or {}
    local original = storage.original_values[recipe_name] or {}
    local recipe = prototypes.recipe[recipe_name]

    ---@generic T
    ---@param k string
    ---@param recipe_value T
    ---@return T
    local function get_value(k, recipe_value)
        if tweak[k] ~= nil then return tweak[k] end
        return recipe_value
    end

    local me = refs.module_effects
    local ae = recipe.allowed_effects or {}
    local spoilage = refs.spoilage
    editable.format_label(refs.energy.label, get_value("energy", original.energy or recipe.energy))
    editable.format_label(refs.max_productivity, get_value("max_productivity", original.max_productivity or recipe.maximum_productivity))
    me.speed.state = get_value("speed", original.speed or ae.speed)
    me.productivity.state = get_value("productivity", original.productivity or ae.productivity)
    me.consumption.state = get_value("consumption", original.consumption or ae.consumption)
    me.pollution.state = get_value("pollution", original.pollution or ae.pollution)
    me._quality.state = get_value("quality", original.quality or ae.quality)
    spoilage[preserve].state = get_value(preserve, original[preserve] or recipe[preserve])
    spoilage[fresh].state = get_value(fresh, original[fresh] or recipe[fresh])
    spoilage[reset].state = get_value(reset, original[reset] or recipe[reset])

    refs.ingredients.clear()
    local ingredients = table.deepcopy(original.ingredients or recipe.ingredients)
    for _, tweak_ingredient in pairs(tweak.ingredients or {}) do
        local ingredient, i = find_entry(ingredients, tweak_ingredient[1], tweak_ingredient[2])
        ingredient = ingredient or {type = tweak_ingredient[1], name = tweak_ingredient[2]}
        local data = tweak_ingredient[3]
        if not data then
            if i then
                table.remove(ingredients, i)
            end
        else
            ingredient.amount = data.amount or ingredient.amount
            ingredient.temperature = data.temperature or ingredient.temperature
            ingredient.minimum_temperature = data.minimum_temperature or ingredient.minimum_temperature
            ingredient.maximum_temperature = data.maximum_temperature or ingredient.maximum_temperature
            if not i then
                ingredients[#ingredients+1] = ingredient
            end
        end
    end

    for _, ingredient in pairs(ingredients) do
        glib.add(refs.ingredients, entries.entry(ingredient.type, ingredient.name, false, ingredient))
    end

    refs.products.clear()
    local products = utils.normalize_products(original.products or recipe.products)

    for _, tweak_product in pairs(tweak.products or {}) do
        local product, i = find_entry(products, tweak_product[1], tweak_product[2])
        product = product or {}
        if not tweak_product[3] then
            if i then
                table.remove(products, i)
            end
        else
            for j = 3, #tweak_product do
                local data = tweak_product[j]
                local current = product[j] or {}
                product[j] = current
                current.amount = get_number_value(data.amount, current.amount)
                current.amount_min = get_number_value(data.amount_min, current.amount_min)
                current.amount_max = get_number_value(data.amount_max, current.amount_max)
                current.probability = get_number_value(data.probability, current.probability)
                current.extra_count_fraction = get_number_value(data.extra_count_fraction, current.extra_count_fraction)
                current.percent_spoiled = get_number_value(data.percent_spoiled, current.percent_spoiled)
                current.temperature = get_number_value(data.temperature, current.temperature)
                current.minimum_temperature = get_number_value(data.minimum_temperature, current.minimum_temperature)
                current.maximum_temperature = get_number_value(data.maximum_temperature, current.maximum_temperature)
                if not i then
                    products[#products+1] = {tweak_product[1], tweak_product[2], product[j]}
                end
            end
        end
    end

    local denormalized = {}
    for _, product in pairs(products) do
        for i = 3, #product do
            local data = product[i]
            local new = {type = product[1], name = product[2]}
            for k, v in pairs(data) do
                new[k] = v
            end
            denormalized[#denormalized+1] = new
        end
    end

    for _, product in pairs(denormalized) do
        glib.add(refs.products, entries.entry(product.type, product.name, true, product))
    end

    utils.validate_confirm(refs)
end

---@param refs table<string, LuaGuiElement>
function lib.confirm(refs, index)
    local recipe_name = refs.tweak.tags.current --[[@as string]]
    if not refs.tweaks[recipe_name] then
        glib.add(refs.tweaks, lib.button(recipe_name))
    end

    storage.tweaks[index][recipe_name] = utils.diff_tweak(refs)
end

utils.register_handlers(handlers)

return lib