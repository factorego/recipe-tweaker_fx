data:extend{{
    type = "custom-input",
    name = "rt_open_gui",
    key_sequence = "CONTROL + BACKSLASH",
    include_selected_prototype = true,
}, {
    type = "shortcut",
    name = "rt-open-gui",
    associated_control_input = "rt_open_gui",
    action = "lua",
    icon = "__recipe-tweaker__/graphics/shortcut-x56.png",
    icon_size = 56,
    small_icon = "__recipe-tweaker__/graphics/shortcut-x24.png",
    small_icon_size = 24,
}}

local styles = data.raw["gui-style"].default

styles.rt_entry_frame = {
    type = "frame_style",
    parent = "subheader_frame",
    height = 40,
    padding = 0,
    horizontally_stretchable = "on",
    horizontal_flow_style = {
        type = "horizontal_flow_style",
        height = 40,
        vertical_align = "center"
    }
}