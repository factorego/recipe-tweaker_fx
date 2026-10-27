local utils = require("scripts/utils") ---@module "recipe-tweaker/scripts/utils"

local tweaks = utils.decode(settings.startup["rt-recipe-enc"].value --[[@as string]])
if not tweaks then
    error("Invalid tweak string: Please reset the settings for Recipe Tweaker to clear the setting and try again.")
end

log("Tweaks:")
log(serpent.line(tweaks))

local alias = {
    energy = "energy_required",
    max_productivity = "maximum_productivity",
    speed = "allow_speed",
    productivity = "allow_productivity",
    consumption = "allow_consumption",
    pollution = "allow_pollution",
    quality = "allow_quality",
}

local default_values = {
    energy = 0.5,
    max_productivity = 3,
    speed = true,
    productivity = false,
    consumption = true,
    pollution = true,
    quality = true,
}

---@param name string
---@return data.ItemPrototype?
local function find_item(name)
    for ptype in pairs(defines.prototypes.item) do
        for _, item in pairs(data.raw[ptype] or {}) do
            if item.name == name then
                return item --[[@as data.ItemPrototype]]
            end
        end
    end
end

---@param type string
---@param name string
local function find_prototype(type, name)
    if type ~= "fluid" then
        return find_item(name)
    else
        return data.raw.fluid[name]
    end
end

---@param recipe data.RecipePrototype
---@param name string
---@param type string
local function fix_recipe(recipe, name, type)
    local prototype = find_prototype(type, name)

    if not (recipe.icon or recipe.icons) then
        recipe.icon = prototype.icon
        recipe.icon_size = prototype.icon_size
        recipe.icons = table.deepcopy(prototype.icons)
    end
    if not (recipe.localised_name) then
        local localised_type = type == "fluid" and "fluid-name." or "item-name."
        recipe.localised_name = {"?", {localised_type .. name}, {"entity-name." .. name}, {"equipment-name." .. name}}
    end
end

local original_data = {}
for name, tweak in pairs(tweaks) do
    local recipe = data.raw.recipe[name]
    if not recipe then
        log("Skipping non-existent recipe: " .. name)
        goto continue
    end
    local original = {}

    local ingredients = table.deepcopy(recipe.ingredients or {})
    if tweak.ingredients then
        original.ingredients = table.deepcopy(ingredients)
        for _, ingredient in pairs(original.ingredients) do
            if ingredient.type == "item" then
                ingredient.amount = math.floor(ingredient.amount)
            end
        end
    end
    recipe.ingredients = ingredients

    local to_remove = {}
    for _, diff in pairs(tweak.ingredients or {}) do
        if not find_prototype(diff[1], diff[2]) then goto continue end
        for i, ingredient in pairs(ingredients) do
            if ingredient.name == diff[2] and ingredient.type == diff[1] then
                if diff[3] then
                    for k, v in pairs(diff[3]) do
                        if v == false then
                            ingredient[k] = nil
                        else
                            ingredient[k] = v
                        end
                    end
                else
                    to_remove[#to_remove+1] = i
                end
                goto continue
            end
        end
        if diff[3] and diff[3].amount then
            local new = table.deepcopy(diff[3])
            new.type = diff[1]
            new.name = diff[2]
            ingredients[#ingredients+1] = new
        end
        ::continue::
    end
    table.sort(to_remove)
    for i = #to_remove, 1, -1 do
        table.remove(ingredients, to_remove[i])
    end
    tweak.ingredients = nil

    local results = table.deepcopy(recipe.results or {})
    if tweak.products then
        original.products = table.deepcopy(results)
        for _, result in pairs(original.products) do
            if result.type == "item" then
                if result.amount then
                    result.amount = math.floor(result.amount)
                else
                    result.amount_min = math.floor(result.amount_min)
                    result.amount_min = math.floor(result.amount_min)
                end
            end
        end
    end
    recipe.results = results

    local only_product = #results == 1 and results[1] or nil
    local main_product = recipe.main_product ~= "" and recipe.main_product or nil
    local main_product_type
    if main_product then
        for _, result in pairs(recipe.results) do
            if result.name == main_product then
                main_product_type = result.type
            end
        end
    end

    to_remove = {}
    for _, diff in pairs(tweak.products or {}) do
        local prototype = find_prototype(diff[1], diff[2])
        if not prototype then goto continue end
        local c = 3
        for i, result in pairs(results) do
            if result.name == diff[2] and result.type == diff[1] then
                local change = diff[c]
                if change then
                    if not (prototype.spoil_ticks and prototype.spoil_ticks > 0)  then
                        change.percent_spoiled = nil
                    end
                    for k, v in pairs(change) do
                        if v == false then
                            result[k] = nil
                        else
                            result[k] = v
                        end
                    end
                    for _, ingredient in pairs(recipe.ingredients) do
                        if ingredient.name == diff[2] and ingredient.type == diff[1] then
                            result.ignored_by_stats = ingredient.amount
                            result.ignored_by_productivity = ingredient.amount
                            goto forelse
                        end
                    end
                    result.ignored_by_stats = nil
                    result.ignored_by_productivity = nil
                    ::forelse::
                else
                    to_remove[#to_remove+1] = i
                end
                c = c + 1
                goto continue
            end
        end
        for i = c, #diff do
            local change = diff[i]
            if change and (change.amount or (change.amount_min and change.amount_max)) then
                local new = table.deepcopy(change)
                new.type = diff[1]
                new.name = diff[2]
                results[#results+1] = new
            end
        end
        ::continue::
    end
    table.sort(to_remove)
    for i = #to_remove, 1, -1 do
        table.remove(results, to_remove[i])
    end

    tweak.products = nil

    if main_product then
        for _, result in pairs(recipe.results) do
            if result.name == main_product then
                goto forelse
            end
        end
        fix_recipe(recipe, main_product, main_product_type)
        ::forelse::
    elseif only_product ~= nil and #recipe.results ~= 1 then
        for _, result in pairs(recipe.results) do
            if result.name == only_product.name and result.type == only_product.type then
                recipe.main_product = only_product.name
                goto forelse
            end
        end
        fix_recipe(recipe, only_product.name, main_product_type)
        ::forelse::
    end

    for k, v in pairs(tweak) do
        local key = alias[k] or k
        original_value, recipe[key] = recipe[key], v
        if original_value == nil then
            original_value = default_values[k]
        end
        original[k] = original_value
    end

    if (not recipe.category) or recipe.category == "crafting" then
        for _, ingredient in pairs(recipe.ingredients or {}) do
            if ingredient.type == "fluid" then
                recipe.category = "crafting-with-fluid"
                goto ifbreak
            end
        end
        for _, result in pairs(recipe.results or {}) do
            if result.type == "fluid" then
                recipe.category = "crafting-with-fluid"
                goto ifbreak

            end
        end
    end
    ::ifbreak::

    if next(original) then
        original_data[name] = original
    end

    ::continue::
end

data:extend{{
    type = "mod-data",
    name = "rt-data-smuggle",
    data = original_data,
}}

-- data.raw.recipe["transport-belt"].category = "crafting-with-fluid"
-- data.raw.recipe["transport-belt"].results[1].probability = 0.5
-- data.raw.recipe["transport-belt"].results[1].amount_min = 1
-- data.raw.recipe["transport-belt"].results[1].amount_max = 2
-- data.raw.recipe["transport-belt"].results[1].amount = nil
-- data.raw.recipe["transport-belt"].results[1].name = "raw-fish"
-- data.raw.recipe["transport-belt"].results[1].percent_spoiled = 0.75

-- data.raw.capsule["raw-fish"].spoil_ticks = 60 * 60 * 60

-- data.raw.fluid.water.default_temperature = -500

-- data.raw.recipe["transport-belt"].ingredients[1] = {type = "fluid", name = "steam", amount = 1, minimum_temperature = 50, maximum_temperature = 100}