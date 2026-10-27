local gui = require("scripts/gui") ---@module "recipe-tweaker/scripts/gui"
local tweak_lib = require("scripts/tweak") ---@module "recipe-tweaker/scripts/tweak"
local utils = require("scripts/utils") ---@module "recipe-tweaker/scripts/utils"
local e = defines.events
local ci = prototypes.custom_input

local function setup_storage()
    ---@type table<uint, table<string, table>>
    storage.tweaks = {}
    ---@type table<uint, table<string, LuaGuiElement>>
    storage.refs = {}
    ---@type table<uint, LuaGuiElement>
    storage.editing = {}
    ---@type table<uint, LuaGuiElement>
    storage.selected_entry = {}
end

local function setup_player(index)
    storage.tweaks[index] = {}
end

local function cache_data()
    ---@type table<string, table>
    storage.loaded_tweaks = utils.decode(settings.startup["rt-recipe-enc"].value --[[@as string]]) or {}
    ---@type table<string, table>
    storage.original_values = prototypes.mod_data["rt-data-smuggle"].data --[[@as table<string, table>]]
end

script.on_init(function()
    setup_storage()
    cache_data()
    for index in pairs(game.players) do
        setup_player(index)
    end
end)

script.on_configuration_changed(function()
    cache_data()
    for index, refs in pairs(storage.refs) do
        storage.refs[index] = {}
        if refs.recipe_tweaker then
            refs.recipe_tweaker.destroy()
        end
    end
end)

script.on_event(e.on_player_created, function(event)
    setup_player(event.player_index)
end)

script.on_event(e.on_player_removed, function(event)
    storage.tweaks[event.player_index] = nil
    storage.refs[event.player_index] = nil
end)

script.on_event(ci.rt_open_gui, function(event)
    local player = game.get_player(event.player_index) --[[@as LuaPlayer]]
    gui.open(player)

    local selected = event.selected_prototype
    if not selected then return end
    if selected.base_type ~= "recipe" then return end
    tweak_lib.open(event.player_index, selected.name)
end)

script.on_event(e.on_lua_shortcut, function(event)
    if event.prototype_name ~= "rt-open-gui" then return end
    local player = game.get_player(event.player_index) --[[@as LuaPlayer]]
    gui.open(player)
end)

---@alias RecipeTweaker.handler fun(element: LuaGuiElement, refs: table<string, LuaGuiElement>, event: GuiEventData)
---@alias RecipeTweaker.handlers table<string, RecipeTweaker.handler>

-- TODO:
-- surface conditions?
-- esc cancels editable label?
-- decimal display?

-- recycling
-- double ingredients

if settings.startup["rr-dev"].value then
    commands.add_command("rr_decode", nil, function(command)
        local s = serpent.block(utils.decode(command.parameter))
        game.print(s)
        log(s)
    end)
end