local context_menu = require("scripts/context-menu") ---@module "recipe-tweaker/scripts/context-menu"
local editable = require("scripts/editable") ---@module "recipe-tweaker/scripts/editable"
local entries = require("scripts/entries") ---@module "recipe-tweaker/scripts/entries"
local export = require("scripts/export") ---@module "recipe-tweaker/scripts/export"
local glib = require("__glib__/glib") ---@module "glib/glib"
local tweak_lib = require("scripts/tweak") ---@module "recipe-tweaker/scripts/tweak"
local utils = require("scripts/utils") ---@module "recipe-tweaker/scripts/utils"

---@type RecipeTweaker.handlers
local handlers = {}
local gui = {}

---@param player LuaPlayer
local function create_gui(player)
    local root, refs = glib.add(player.gui.screen, {
        args = {type = "frame", name = "recipe_tweaker", direction = "vertical"},
        _closed = handlers.close,
        children = {{
            args = {type = "flow", name = "header"},
            ref = false,
            drag_target = "recipe_tweaker",
            children = {{
                args = {type = "label", caption = "Recipe Tweaker", style = "frame_title", ignored_by_interaction = true},
            }, {
                args = {type = "empty-widget", style = "draggable_space_header", ignored_by_interaction = true},
                style_mods = {horizontally_stretchable = true, height = 24},
            }, {
                args = {type = "sprite-button", name = "pin", style = "frame_action_button", sprite = "glib-pin", auto_toggle = true, tooltip = {"glib.keep-open"}},
                _click = handlers.pin,
            }, {
                args = {type = "sprite-button", style = "close_button", sprite = "utility/close"},
                _click = handlers.close_button,
            }},
        }, {
            args = {type = "frame", name = "content", style = "inside_shallow_frame"},
            children = {{
                args = {type = "flow", name = "menu", direction = "vertical"},
                style_mods = {vertical_spacing = 0},
                children = {{
                    args = {type = "frame", style = "filter_frame"},
                    style_mods = {natural_height = 224},
                    children = {{
                        args = {type = "scroll-pane", style = "deep_slots_scroll_pane"},
                        style_mods = {minimal_width = 400, minimal_height = 200},
                        children = {{
                            args = {type = "table", name = "tweaks", column_count = 10, style = "filter_slot_table"},
                        }},
                    -- }, {
                    --     args = {type = "scroll-pane", style = "deep_slots_scroll_pane"},
                    --     style_mods = {minimal_width = 400, minimal_height = 200},
                    --     children = {{
                    --         args = {type = "table", name = "templates", column_count = 10, style = "filter_slot_table"},
                    --     }},
                    }},
                }, {
                    args = {type = "frame", style = "subfooter_frame"},
                    style_mods = {horizontally_stretchable = true, left_padding = 4},
                    children = {{
                        args = {type = "sprite-button", sprite = "utility/export_slot", style = "tool_button", tooltip = "Export to string"},
                        _click = handlers.export,
                    }, {
                        args = {type = "empty-widget"},
                        style_mods = {horizontally_stretchable = true},
                    }, {
                        args = {
                            type = "choose-elem-button", elem_type = "recipe", style = "item_and_count_select_confirm", tooltip = "New tweak",
                            elem_filters = {{filter = "subgroup", subgroup = "parameters", invert = true}, {filter = "hidden", invert = true, mode = "and"}}
                        },
                        _elem_changed = handlers.add_tweak,
                        children = {{
                            args = {type = "flow"},
                            children = {{
                                args = {type = "sprite", sprite = "utility/add"},
                                style_mods = {size = 20, stretch_image_to_widget_size = true},
                            }}
                        }},
                    }},
                }},
            }, {
                args = {type = "flow", name = "tweak", direction = "vertical", visible = false},
                style_mods = {vertical_spacing = 0},
                children = {{
                    args = {type = "scroll-pane", style = "naked_scroll_pane"},
                    style_mods = {width = 424, natural_height = 224, maximal_height = 720, padding = 12},
                    children = {{
                        args = {type = "flow", direction = "vertical"},
                        style_mods = {padding = 0, vertical_spacing = 12},
                        children = {{
                            args = {type = "flow", direction = "vertical"},
                            children = {{
                                args = {type = "label", caption = "Ingredients", style = "heading_2_label"},
                            }, {
                                args = {type = "frame", name = "entries", direction = "vertical", style = "deep_frame_in_shallow_frame"},
                                ref = "ingredients"
                            }, {
                                args = {type = "flow"},
                                children = {
                                    entries.add_button("item"),
                                    entries.add_button("fluid"),
                                }
                            }}
                        }, {
                            args = {type = "flow", direction = "vertical"},
                            children = {{
                                args = {type = "label", caption = "Products", style = "heading_2_label"},
                            }, {
                                args = {type = "frame", name = "entries", direction = "vertical", style = "deep_frame_in_shallow_frame"},
                                ref = "products"
                            }, {
                                args = {type = "flow"},
                                children = {
                                    entries.add_button("item", true),
                                    entries.add_button("fluid", true),
                                }
                            }}
                        }, {
                            args = {type = "flow", name = "module_effects", direction = "vertical"},
                            children = {
                                {args = {type = "label", caption = "Module effects", style = "heading_2_label"}},
                                editable.checkbox("speed", "Allow speed"),
                                editable.checkbox("productivity", "Allow productivity"),
                                editable.checkbox("consumption", "Allow consumption"),
                                editable.checkbox("pollution", "Allow pollution"),
                                editable.checkbox("_quality", "Allow quality"),
                                entries.max_productivity()
                            }
                        }, {
                            args = {type = "flow", name = "spoilage", direction = "vertical", visible = script.feature_flags.spoiling},
                            children = {
                                {args = {type = "label", caption = "Spoilage", style = "heading_2_label"}},
                                editable.checkbox("preserve_products_in_machine_output", "Preserve products in machine output"),
                                editable.checkbox("result_is_always_fresh", "Result is always fresh"),
                                editable.checkbox("reset_freshness_on_craft", "Reset freshness on craft"),
                            }
                        }}
                    }}
                }, {
                    args = {type = "frame", style = "subfooter_frame"},
                    children = {{
                        args = {type = "label", name = "tweak_label", style = "heading_2_label"},
                    }, {
                        args = {type = "empty-widget"},
                        style_mods = {horizontally_stretchable = true},
                    },
                    editable.label("energy", "[img=quantity-time] %ss", ""),
                    {
                        args = {type = "sprite-button", sprite = "utility/close_black", style = "tool_button_red", tooltip = "Cancel tweak"},
                        style_mods = {left_margin = 8},
                        _click = handlers.cancel_tweak,
                    }, {
                        args = {
                            type = "sprite-button", name = "confirm", sprite = "utility/check_mark",
                            style = "item_and_count_select_confirm", tooltip = "Confirm tweak", enabled = false
                        },
                        _click = handlers.confirm_tweak,
                    }}
                }}
            }}
        }}
    })
    storage.refs[player.index] = refs

    -- local add_products = refs.products.parent.children[3]
    -- add_products.children[1].style.width = 131
    -- add_products.children[2].style.width = 130

    local tweaks = storage.tweaks[player.index]
    for name, tweak in pairs(storage.loaded_tweaks) do
        if prototypes.recipe[name] then
            glib.add(refs.tweaks, tweak_lib.button(name))
            tweaks[name] = tweak
        end
    end

    return root
end

function handlers.close(_, refs, event)
    if refs.pin.toggled then return end
    refs.recipe_tweaker.visible = false
    context_menu.close(refs, event.player_index)
    export.close(refs)
end

function handlers.close_button(_, refs, event)
    local player = game.get_player(event.player_index) --[[@as LuaPlayer]]
    if player.opened == refs.recipe_tweaker then
        player.opened = nil
    end
    refs.recipe_tweaker.visible = false
end

function handlers.pin(element, refs, event)
    local player = game.get_player(event.player_index) --[[@as LuaPlayer]]
    player.opened = (not element.toggled) and refs.recipe_tweaker or nil
end

function handlers.export(_, refs, event)
    export.create(refs, event.player_index)
end

function handlers.add_tweak(element, refs, event)
    local name = element.elem_value --[[@as string]]
    element.elem_value = nil
    if not name then return end
    if refs.tweaks[name] then
        utils.warn(event.player_index, string.format("Tweak for %s already exists", name))
        return
    end

    refs.confirm.enabled = false
    tweak_lib.open(event.player_index, name)
end

function handlers.cancel_tweak(_, refs)
    refs.menu.visible = true
    refs.tweak.visible = false
end

function handlers.confirm_tweak(_, refs, event)
    tweak_lib.confirm(refs, event.player_index)
    refs.menu.visible = true
    refs.tweak.visible = false
end

---@param player LuaPlayer
function gui.open(player)
    local root = player.gui.screen.recipe_tweaker
    if not root then
        root = create_gui(player)
    else
        root.visible = true
    end
    if not root.header.pin.toggled then
        root.force_auto_center()
        player.opened = root
    end
    root.bring_to_front()
end

utils.register_handlers(handlers)

return gui