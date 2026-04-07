local transfer_ui = {}

local function build_caught_fish_list(player_ship)
    local fish_list = {}
    for _, fish_name in ipairs(player_ship.caught_fish) do
        table.insert(fish_list, fish_name)
    end
    return fish_list
end

local function refresh_filtered_fish(player_ship, inventory_state, inventory_utils)
    local fish_list = build_caught_fish_list(player_ship)
    inventory_state.filtered_fish = inventory_utils.filter_fish(fish_list, inventory_state.search_text.text)
end

local function get_unique_fish_with_counts(filtered_fish)
    local unique_fish = {}
    local fish_counts = {}

    for _, fish_name in ipairs(filtered_fish) do
        if not fish_counts[fish_name] then
            fish_counts[fish_name] = 0
            table.insert(unique_fish, fish_name)
        end
        fish_counts[fish_name] = fish_counts[fish_name] + 1
    end

    return unique_fish, fish_counts
end

function transfer_ui.enter(runtime_state, player_ship)
    local inventory_state = runtime_state.inventory
    inventory_state.search_text.text = ""
    inventory_state.selected_fish = nil
    inventory_state.scroll_offset = 0
    inventory_state.filtered_fish = build_caught_fish_list(player_ship)
end

function transfer_ui.render(ctx)
    local suit = ctx.suit
    local size = ctx.size
    local inventory_utils = ctx.inventory_utils
    local economy = ctx.economy
    local runtime_state = ctx.runtime_state
    local player_ship = ctx.player_ship
    local gamestate = ctx.gamestate
    local GameType = ctx.GameType

    local inventory_state = runtime_state.inventory
    local window_width = size.CANVAS_WIDTH
    local window_height = size.CANVAS_HEIGHT

    suit.layout:reset(window_width / 2 - 300, 50)
    suit.Label("Transfer Fish to Inventory (5 coins each)", {align = "center"}, suit.layout:row(600, 30))
    suit.Label("Current Coins: " .. string.format("%.1f", runtime_state.coins), {align = "center"}, suit.layout:row(600, 30))

    suit.layout:reset(window_width / 2 - 200, 120)
    suit.Label("Search fish:", {align = "left"}, suit.layout:row(400, 30))
    local input_result = suit.Input(inventory_state.search_text, suit.layout:row(400, 30))
    if input_result.submitted or input_result.changed then
        refresh_filtered_fish(player_ship, inventory_state, inventory_utils)
    end

    suit.layout:reset(window_width / 2 - 200, 200)
    suit.Label("Select fish to transfer:", {align = "left"}, suit.layout:row(400, 30))

    local unique_fish, fish_counts = get_unique_fish_with_counts(inventory_state.filtered_fish)
    local items_per_page = 10
    local max_scroll = math.max(0, #unique_fish - items_per_page)
    local list_x = window_width / 2 - 200
    local current_y = 230

    suit.layout:reset(list_x, current_y)
    if inventory_state.scroll_offset > 0 then
        if suit.Button("▲ Scroll Up", suit.layout:row(400, 30)).hit then
            inventory_state.scroll_offset = math.max(0, inventory_state.scroll_offset - 3)
        end
    else
        suit.Label("", {align = "center"}, suit.layout:row(400, 30))
    end

    local start_index = inventory_state.scroll_offset + 1
    local end_index = math.min(start_index + items_per_page - 1, #unique_fish)
    current_y = current_y + 35

    for i = start_index, end_index do
        local fish_name = unique_fish[i]
        local button_text = fish_name .. " (" .. fish_counts[fish_name] .. ")"
        suit.layout:reset(list_x, current_y)

        if runtime_state.coins >= 5 then
            local color = economy.get_fish_action_button_color(fish_name)
            local options = color and {color = color} or {}
            if suit.Button(button_text, options, suit.layout:row(400, 30)).hit then
                runtime_state.coins = runtime_state.coins - 5
                table.insert(player_ship.inventory, fish_name)

                for j, caught_fish in ipairs(player_ship.caught_fish) do
                    if caught_fish == fish_name then
                        table.remove(player_ship.caught_fish, j)
                        break
                    end
                end

                refresh_filtered_fish(player_ship, inventory_state, inventory_utils)
                print("Transferred " .. fish_name .. " to inventory!")
            end
        else
            suit.Label(button_text .. " - Need 5 coins", {align = "left"}, suit.layout:row(400, 30))
        end

        current_y = current_y + 35
    end

    suit.layout:reset(list_x, current_y)
    if inventory_state.scroll_offset < max_scroll then
        if suit.Button("▼ Scroll Down", suit.layout:row(400, 30)).hit then
            inventory_state.scroll_offset = math.min(max_scroll, inventory_state.scroll_offset + 3)
        end
    else
        suit.Label("", {align = "center"}, suit.layout:row(400, 30))
    end

    if #unique_fish > items_per_page then
        suit.layout:reset(list_x, current_y + 35)
        local scroll_info = string.format("Showing %d-%d of %d fish", start_index, end_index, #unique_fish)
        suit.Label(scroll_info, {align = "center"}, suit.layout:row(400, 20))
    end

    suit.layout:reset(window_width - 220, window_height - 60)
    if suit.Button("Back to Shop", suit.layout:row(200, 30)).hit then
        gamestate.set(GameType.SHOP)
        inventory_state.scroll_offset = 0
    end
end

return transfer_ui
