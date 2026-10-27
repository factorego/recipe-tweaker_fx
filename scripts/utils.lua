require("util")

local utils = {}

local encode_string = helpers.encode_string
local decode_string = helpers.decode_string
local table_to_json = helpers.table_to_json
local json_to_table = helpers.json_to_table

---@param t table
function utils.encode(t)
    return encode_string(table_to_json(t))
end

---@param s string
---@return table?
function utils.decode(s)
    if s == "" then return {} end
    local decoded = decode_string(s)
    if not decoded then return end
    return json_to_table(decoded) --[[@as table]]
end

if not script then return utils end

---@param element LuaGuiElement
---@param multiplier? number
local function get_number_value(element, multiplier)
    if not element then return end
    if not element.visible then return end
    return tonumber(element.label.tags.value) * (multiplier or 1)
end

---@generic T
---@param value T
---@param original_value T?
---@return T?
local function diff_value(value, original_value)
    if value == nil then
        if original_value ~= nil then return false end
        return
    end
    if type(value) == "number" then
        if original_value == nil then return value end
        if math.abs(value - original_value) < 2^-56 then return end
    else
        if value == original_value then return end
    end
    return value
end

---@param products Product[]
function utils.normalize_products(products)
    local ret = {}
    for _, product in pairs(table.deepcopy(products)) do
        local type, name = product.type, product.name
        product.type, product.name = nil, nil
        for _, existing in pairs(ret) do
            if existing.name == name and existing.type == type then
                existing[#existing+1] = product
                goto forelse
            end
        end
        ret[#ret+1] = {type, name, product}
        ::forelse::
    end
    return ret
end

---@param refs table<string, LuaGuiElement>
function utils.diff_tweak(refs)
    local recipe_name = refs.tweak.tags.current --[[@as string]]
    local original = storage.original_values[recipe_name] or {}
    local recipe = prototypes.recipe[recipe_name]

    local ingredient_map = {item = {}, fluid = {}}
    local original_ingredients = {item = {}, fluid = {}}
    local frame_ingredients = {item = {}, fluid = {}}
    for _, ingredient in pairs(original.ingredients or {}) do
        ingredient_map[ingredient.type][ingredient.name] = true
        original_ingredients[ingredient.type][ingredient.name] = ingredient
    end
    for _, ingredient in pairs(recipe.ingredients) do
        ingredient_map[ingredient.type][ingredient.name] = true
        original_ingredients[ingredient.type][ingredient.name] = original_ingredients[ingredient.type][ingredient.name] or ingredient
    end
    for _, frame in pairs(refs.ingredients.children) do
        ingredient_map[frame.tags.type][frame.tags.name] = true
        frame_ingredients[frame.tags.type][frame.tags.name] = frame
    end

    local ingredients_diff = {}
    for type, names in pairs(ingredient_map) do
        for name in pairs(names) do
            local diff = {type, name}
            local frame = frame_ingredients[type][name]
            if frame then
                local data = {}
                diff[3] = data
                local ingredient = original_ingredients[type][name] or {}
                data.amount = diff_value(get_number_value(frame.amount), ingredient.amount)
                data.temperature = diff_value(get_number_value(frame.temperature), ingredient.temperature)
                data.minimum_temperature = diff_value(get_number_value(frame.minimum_temperature), ingredient.minimum_temperature)
                data.maximum_temperature = diff_value(get_number_value(frame.maximum_temperature), ingredient.minimum_temperature)
                if diff[3] and table_size(diff[3]) > 0 then
                    ingredients_diff[#ingredients_diff+1] = diff
                end
            else
                ingredients_diff[#ingredients_diff+1] = diff
            end
        end
    end
    if not ingredients_diff[1] then
        ingredients_diff = nil
    end

    local product_map = {item = {}, fluid = {}}
    local original_products = {item = {}, fluid = {}}
    local frame_products = {item = {}, fluid = {}}
    for _, product in pairs(utils.normalize_products(original.products or {})) do
        original_products[product[1]][product[2]] = product
        product_map[product[1]][product[2]] = true
    end
    for _, product in pairs(utils.normalize_products(recipe.products)) do
        -- for i = 3, #product do
        --     if product[i].probability == 1 then
        --         product[i].probability = nil
        --     end
        -- end
        original_products[product[1]][product[2]] = original_products[product[1]][product[2]] or product
        product_map[product[1]][product[2]] = true
    end
    for _, frame in pairs(refs.products.children) do
        product_map[frame.tags.type][frame.tags.name] = true
        local frames = frame_products[frame.tags.type][frame.tags.name] or {}
        frame_products[frame.tags.type][frame.tags.name] = frames
        frames[#frames+1] = frame
    end

    local products_diff = {}
    for type, names in pairs(product_map) do
        for name in pairs(names) do
            ---@type any[]
            local diff = {type, name}
            local frames = frame_products[type][name]
            for i, frame in ipairs(frames or {}) do
                local data = {}
                diff[#diff+1] = data
                local product = (original_products[type][name] or {})[i + 2] or {}
                data.amount = diff_value(get_number_value(frame.amount), product.amount)
                data.amount_min = diff_value(get_number_value(frame.amount_min), product.amount_min)
                data.amount_max = diff_value(get_number_value(frame.amount_max), product.amount_max)
                data.probability = diff_value(get_number_value(frame.probability, 0.01) or 1, product.probability or 1)
                data.extra_count_fraction = diff_value(get_number_value(frame.extra_count_fraction), product.extra_count_fraction)
                data.percent_spoiled = diff_value(get_number_value(frame.percent_spoiled, 0.01), product.percent_spoiled)
                data.temperature = diff_value(get_number_value(frame.temperature), product.temperature)
            end
            if frames then
                for i = 3, #frames + 2 do
                    if diff[i] and table_size(diff[i]) > 0 then
                        products_diff[#products_diff+1] = diff
                        break
                    end
                end
            else
                products_diff[#products_diff+1] = diff
            end
        end
    end
    if not products_diff[1] then
        products_diff = nil
    end

    local me = refs.module_effects
    local ae = recipe.allowed_effects or {}
    local spoilage = refs.spoilage
    local preserve, fresh, reset = "preserve_products_in_machine_output", "result_is_always_fresh", "reset_freshness_on_craft"
    local function proto_field(r, k)
        local ok, v = pcall(function() return r[k] end)
        return ok and v or nil
    end
    return {
        energy = diff_value(tonumber(refs.energy.label.tags.value), original.energy or recipe.energy),
        max_productivity = diff_value(get_number_value(refs.max_productivity, 0.01), original.max_productivity or recipe.maximum_productivity),
        speed = diff_value(me.speed.state, original.speed or ae.speed),
        productivity = diff_value(me.productivity.state, original.productivity or ae.productivity),
        consumption = diff_value(me.consumption.state, original.consumption or ae.consumption),
        pollution = diff_value(me.pollution.state, original.pollution or ae.pollution),
        quality = diff_value(me._quality.state, original.quality or ae.quality),
        [preserve] = diff_value(spoilage[preserve].state, original[preserve] or proto_field(recipe, preserve) or false),
        [fresh] = diff_value(spoilage[fresh].state, original[fresh] or proto_field(recipe, fresh) or false),
        [reset] = diff_value(spoilage[reset].state, original[reset] or proto_field(recipe, reset) or false),
        ingredients = ingredients_diff,
        products = products_diff,
    }
end

local glib = require("__glib__/glib") ---@module "glib/glib"

---@param handlers GuiEventHandler[]
---@param namespace? string
function utils.register_handlers(handlers, namespace)
    glib.register_handlers(handlers, function(event, handler)
        local refs = storage.refs[event.player_index]
        handler(event.element, refs, event)
    end, namespace)
end

---@param refs table<string, LuaGuiElement>
function utils.validate_confirm(refs)
    local diff = utils.diff_tweak(refs)
    refs.confirm.enabled = table_size(diff) > 0
end

---@param index uint
---@param text string
function utils.warn(index, text)
    local player = game.get_player(index) --[[@as LuaPlayer]]
    player.play_sound{path = "utility/cannot_build"}
    player.create_local_flying_text{
        text = text,
        create_at_cursor = true,
    }
end

return utils