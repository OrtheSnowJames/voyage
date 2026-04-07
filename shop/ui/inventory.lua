local inventory_ui = {}

function inventory_ui.enter(runtime_state)
    runtime_state.inventory.scroll_offset = 0
end

local function build_unique_inventory(player_ship)
    local counts = {}
    local unique = {}

    for _, fish_name in ipairs(player_ship.inventory) do
        if not counts[fish_name] then
            counts[fish_name] = 0
            table.insert(unique, fish_name)
        end
        counts[fish_name] = counts[fish_name] + 1
    end

    return counts, unique
end

function inventory_ui.render(ctx)
    local suit = ctx.suit
    local size = ctx.size
    local fishing = ctx.fishing
    local economy = ctx.economy
    local runtime_state = ctx.runtime_state
    local player_ship = ctx.player_ship
    local gamestate = ctx.gamestate
    local GameType = ctx.GameType

    local inventory_state = runtime_state.inventory
    local window_width = size.CANVAS_WIDTH
    local window_height = size.CANVAS_HEIGHT

    suit.layout:reset(window_width / 2 - 300, 50)
    suit.Label("Fish Inventory", {align = "center"}, suit.layout:row(600, 40))

    local inventory_counts, unique_inventory = build_unique_inventory(player_ship)
    local items_per_page = 12
    local max_scroll = math.max(0, #unique_inventory - items_per_page)

    suit.layout:reset(window_width / 2 - 200, 120)
    if #unique_inventory == 0 then
        suit.Label("Inventory is empty", {align = "center"}, suit.layout:row(400, 30))
    else
        if inventory_state.scroll_offset > 0 then
            if suit.Button("▲ Scroll Up", suit.layout:row(400, 30)).hit then
                inventory_state.scroll_offset = math.max(0, inventory_state.scroll_offset - 3)
            end
        else
            suit.Label("", {align = "center"}, suit.layout:row(400, 30))
        end

        local start_index = inventory_state.scroll_offset + 1
        local end_index = math.min(start_index + items_per_page - 1, #unique_inventory)
        local current_y = 180

        for i = start_index, end_index do
            local fish_name = unique_inventory[i]
            if not fish_name then
                break
            end

            local fish_value = fishing.get_fish_value(fish_name)
            local fish_count = inventory_counts[fish_name] or 0

            suit.layout:reset(window_width / 2 - 200, current_y)
            suit.Label(
                fish_name .. " x" .. fish_count .. " (Value: " .. fish_value .. " each)",
                {align = "left"},
                suit.layout:row(280, 30)
            )

            suit.layout:reset(window_width / 2 + 90, current_y)
            local deposit_color = economy.get_fish_action_button_color(fish_name)
            local deposit_options = deposit_color and {color = deposit_color} or {}
            if suit.Button("Deposit", deposit_options, suit.layout:row(80, 30)).hit then
                for j, inv_fish in ipairs(player_ship.inventory) do
                    if inv_fish == fish_name then
                        table.remove(player_ship.inventory, j)
                        break
                    end
                end
                table.insert(player_ship.caught_fish, fish_name)

                inventory_counts[fish_name] = inventory_counts[fish_name] - 1
                if inventory_counts[fish_name] <= 0 then
                    for k, unique_fish_name in ipairs(unique_inventory) do
                        if unique_fish_name == fish_name then
                            table.remove(unique_inventory, k)
                            break
                        end
                    end
                    local max_scroll_now = math.max(0, #unique_inventory - items_per_page)
                    inventory_state.scroll_offset = math.min(inventory_state.scroll_offset, max_scroll_now)
                end

                print("Deposited " .. fish_name .. " to caught fish!")
                break
            end

            current_y = current_y + 35
        end

        if inventory_state.scroll_offset < max_scroll then
            if suit.Button("▼ Scroll Down", suit.layout:row(400, 30)).hit then
                inventory_state.scroll_offset = math.min(max_scroll, inventory_state.scroll_offset + 3)
            end
        else
            suit.Label("", {align = "center"}, suit.layout:row(400, 30))
        end

        if #unique_inventory > items_per_page then
            local scroll_info = string.format("Showing %d-%d of %d fish", start_index, end_index, #unique_inventory)
            suit.Label(scroll_info, {align = "center"}, suit.layout:row(400, 20))
        end
    end

    suit.layout:reset(window_width - 220, window_height - 60)
    if suit.Button("Back to Shop", suit.layout:row(200, 30)).hit then
        gamestate.set(GameType.SHOP)
        inventory_state.scroll_offset = 0
    end
end

return inventory_ui
