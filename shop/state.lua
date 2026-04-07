local state = {}

local function create_inventory_state()
    return {
        mode = "",
        search_text = {text = ""},
        selected_fish = nil,
        filtered_fish = {},
        scroll_offset = 0
    }
end

function state.create(scrolling)
    return {
        coins = 0,
        show_no_fish_message = false,
        message_timer = 0,
        message_duration = 2,
        inventory = create_inventory_state(),
        main_shop_scroll = scrolling.new(),
        shop_reopen_requires_exit = false
    }
end

function state.reset(runtime_state, scrolling)
    runtime_state.coins = 0
    runtime_state.show_no_fish_message = false
    runtime_state.message_timer = 0
    runtime_state.inventory.mode = ""
    runtime_state.inventory.search_text.text = ""
    runtime_state.inventory.selected_fish = nil
    runtime_state.inventory.filtered_fish = {}
    runtime_state.inventory.scroll_offset = 0
    runtime_state.shop_reopen_requires_exit = false
    scrolling.reset(runtime_state.main_shop_scroll)
end

return state
