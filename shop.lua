local shop = {}
local suit = require "SUIT"
local fishing = require("game.fishing")
local combat = require("game.combat")
local size = require("game.size")
local scrolling = require("game.scrolling")
local GameType = require("game.gametypes")
local constants = require("game.constants")
local sand = require("sand")

local port = require("shop.port").create({
    constants = constants,
    size = size,
    sand = sand
})

local economy = require("shop.economy").create({
    constants = constants,
    fishing = fishing,
    combat = combat
})

local inventory_utils = require("shop.inventory_utils")

-- player's inventory (should be moved to a proper inventory system later)
local coins = 0
local current_state = ""
local show_no_fish_message = false
local message_timer = 0
local MESSAGE_DURATION = 2

-- inventory ui state
local inventory_state = {
    mode = "",
    search_text = {text = ""},
    selected_fish = nil,
    filtered_fish = {},
    scroll_offset = 0
}

local main_shop_scroll = scrolling.new()
local shop_reopen_requires_exit = false

shop.get_main_dock_position = port.get_main_dock_position
shop.try_disembark_main_dock = port.try_disembark_main_dock
shop.can_disembark_main_dock = port.can_disembark_main_dock
shop.try_board_main_dock = port.try_board_main_dock
shop.can_board_main_dock = port.can_board_main_dock
shop.request_main_shop_interaction = port.request_main_shop_interaction
shop.can_talk_to_main_shopkeeper = port.can_talk_to_main_shopkeeper
shop.can_disembark_port_shop = port.can_disembark_port_shop
shop.try_disembark_port_shop = port.try_disembark_port_shop
shop.can_talk_to_port_shopkeeper = port.can_talk_to_port_shopkeeper
shop.request_port_shop_interaction = port.request_port_shop_interaction
shop.draw_main_dock = port.draw_main_dock
shop.resolve_boat_collisions = port.resolve_boat_collisions
shop.draw_shops = port.draw_shops

function shop.get_coins()
    return coins
end

function shop.try_spend_coins(amount)
    local cost = math.floor(tonumber(amount) or 0)
    if cost <= 0 then
        return true
    end

    if coins < cost then
        return false
    end

    coins = coins - cost
    return true
end

function shop.add_coins(amount)
    local gain = math.floor(tonumber(amount) or 0)
    if gain <= 0 then
        return 0
    end

    coins = coins + gain
    return gain
end

-- public helper so other modules can read crew hire price
function shop.get_crew_hire_cost(current_crew)
    return economy.get_crew_hire_cost(current_crew)
end

function shop.get_current_crew_hire_cost(player_ship)
    local crew_count = player_ship and player_ship.men or 1
    return economy.get_crew_hire_cost(crew_count)
end

function shop.update(gamestate, player_ship, shopkeeper, game_config)
    local dt = love.timer.getDelta()
    port.update_spawn_and_animation(player_ship, dt)

    local shop_active, port_shop_active, main_shop_active = port.check_shop_interaction(player_ship, shopkeeper)
    if not shop_active then
        shop_reopen_requires_exit = false
    end
    if not (main_shop_active or port_shop_active) then
        player_ship.pending_shop_interaction = false
    end

    if gamestate.get() == GameType.VOYAGE then
        if player_ship.pending_shop_interaction and (main_shop_active or port_shop_active) then
            gamestate.set(GameType.SHOP)
            player_ship.pending_shop_interaction = false
        end
    elseif not shop_active and gamestate.get():find(GameType.SHOP, 1, true) then
        player_ship.pending_shop_interaction = false
        gamestate.set(GameType.VOYAGE)
    end

    if not gamestate.get():find(GameType.SHOP, 1, true) then
        scrolling.stop_drag(main_shop_scroll)
        return
    end

    if message_timer > 0 then
        message_timer = message_timer - dt
        if message_timer <= 0 then
            show_no_fish_message = false
        end
    end

    local window_width = size.CANVAS_WIDTH
    local window_height = size.CANVAS_HEIGHT

    if suit.Button("Leave Shop", {id = "leave_shop"}, window_width - 132, 10, 122, 30).hit then
        gamestate.set(GameType.VOYAGE)
        shop_reopen_requires_exit = true
        player_ship.pending_shop_interaction = false
        scrolling.stop_drag(main_shop_scroll)
        return
    end

    if gamestate.get() ~= GameType.SHOP then
        scrolling.stop_drag(main_shop_scroll)
    end

    if gamestate.get() == GameType.SHOP_TRANSFER then
        suit.layout:reset(window_width / 2 - 300, 50)
        suit.Label("Transfer Fish to Inventory (5 coins each)", {align = "center"}, suit.layout:row(600, 30))
        suit.Label("Current Coins: " .. string.format("%.1f", coins), {align = "center"}, suit.layout:row(600, 30))

        suit.layout:reset(window_width / 2 - 200, 120)
        suit.Label("Search fish:", {align = "left"}, suit.layout:row(400, 30))
        local input_result = suit.Input(inventory_state.search_text, suit.layout:row(400, 30))
        if input_result.submitted or input_result.changed then
            local all_fish = {}
            for _, fish_name in ipairs(player_ship.caught_fish) do
                table.insert(all_fish, fish_name)
            end
            inventory_state.filtered_fish = inventory_utils.filter_fish(all_fish, inventory_state.search_text.text)
        end

        suit.layout:reset(window_width / 2 - 200, 200)
        suit.Label("Select fish to transfer:", {align = "left"}, suit.layout:row(400, 30))

        local unique_fish = {}
        local fish_counts = {}
        for _, fish_name in ipairs(inventory_state.filtered_fish) do
            if not fish_counts[fish_name] then
                fish_counts[fish_name] = 0
                table.insert(unique_fish, fish_name)
            end
            fish_counts[fish_name] = fish_counts[fish_name] + 1
        end

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
            if coins >= 5 then
                local color = economy.get_fish_action_button_color(fish_name)
                local options = color and {color = color} or {}
                if suit.Button(button_text, options, suit.layout:row(400, 30)).hit then
                    coins = coins - 5
                    table.insert(player_ship.inventory, fish_name)
                    for j, caught_fish in ipairs(player_ship.caught_fish) do
                        if caught_fish == fish_name then
                            table.remove(player_ship.caught_fish, j)
                            break
                        end
                    end

                    local all_fish = {}
                    for _, f in ipairs(player_ship.caught_fish) do
                        table.insert(all_fish, f)
                    end
                    inventory_state.filtered_fish = inventory_utils.filter_fish(all_fish, inventory_state.search_text.text)
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

    elseif gamestate.get() == GameType.SHOP_VIEW_INVENTORY then
        suit.layout:reset(window_width / 2 - 300, 50)
        suit.Label("Fish Inventory", {align = "center"}, suit.layout:row(600, 40))

        local inventory_counts = {}
        local unique_inventory = {}
        for _, fish_name in ipairs(player_ship.inventory) do
            if not inventory_counts[fish_name] then
                inventory_counts[fish_name] = 0
                table.insert(unique_inventory, fish_name)
            end
            inventory_counts[fish_name] = inventory_counts[fish_name] + 1
        end

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
                suit.Label(fish_name .. " x" .. fish_count .. " (Value: " .. fish_value .. " each)",
                          {align = "left"}, suit.layout:row(280, 30))

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

    else
        local section_width = 250
        local section_height = 150
        local padding = 30
        local top_margin = 100
        local title_width = 200
        local row2_y = top_margin + section_height + padding
        local row3_y = row2_y + section_height + padding
        local content_height = row3_y + section_height + padding

        scrolling.update(main_shop_scroll, {
            viewport_x = 0,
            viewport_y = 0,
            viewport_width = window_width,
            viewport_height = window_height,
            content_height = content_height,
            reserve_scrollbar_space = true
        })

        local scroll_y = scrolling.get_offset_y(main_shop_scroll, true)
        local function sy(y)
            return y + scroll_y
        end

        local grid_width = section_width * 3 + padding * 2
        local grid_start_x = main_shop_scroll.viewport.x + ((main_shop_scroll.viewport.w - grid_width) / 2)

        suit.layout:reset(main_shop_scroll.viewport.x + ((main_shop_scroll.viewport.w - title_width) / 2), sy(padding))
        suit.Label("SHOP", {align = "center"}, suit.layout:row(title_width, 30))

        suit.layout:reset(main_shop_scroll.viewport.x + ((main_shop_scroll.viewport.w - title_width) / 2), sy(padding + 40))
        suit.Label("Coins: " .. string.format("%.1f", coins), {align = "center"}, suit.layout:row(title_width, 30))

        suit.layout:reset(grid_start_x, sy(top_margin))
        suit.Label("Fish", {align = "center"}, suit.layout:row(section_width, 30))
        local button_text = #player_ship.caught_fish > 0 and "Sell All Fish (" .. #player_ship.caught_fish .. ")" or "Sell All Fish (none)"
        if suit.Button(button_text, suit.layout:row(section_width, 30)).hit then
            if #player_ship.caught_fish > 0 then
                local total = 0
                for _, fish_name in ipairs(player_ship.caught_fish) do
                    if fish_name == "Gold Sturgeon" then
                        total = total + economy.get_gold_sturgeon_sell_price()
                    else
                        local fish_value = fishing.get_fish_value(fish_name)
                        total = total + (fish_value * economy.get_fish_sell_multiplier())
                    end
                end
                coins = coins + total
                player_ship.caught_fish = {}
                print("Sold fish for " .. total .. " coins!")
            else
                show_no_fish_message = true
                message_timer = MESSAGE_DURATION
            end
        end
        if show_no_fish_message then
            suit.Label("No fish to sell!", {align = "center"}, suit.layout:row(section_width, 20))
        end

        suit.layout:reset(grid_start_x + section_width + padding, sy(top_margin))
        suit.Label("Crew Members", {align = "center"}, suit.layout:row(section_width, 30))
        local hire_cost = economy.get_crew_hire_cost(player_ship.loyal_men)
        if coins >= hire_cost then
            if suit.Button("Hire 1 Man (" .. hire_cost .. " coins)", suit.layout:row(section_width, 30)).hit then
                coins = coins - hire_cost
                player_ship.men = player_ship.men + 1
                player_ship.loyal_men = player_ship.loyal_men + 1
            end
        else
            suit.Label("Need " .. hire_cost .. " coins", {align = "center"}, suit.layout:row(section_width, 30))
        end
        suit.Label("Current Crew: " .. player_ship.men, {align = "center"}, suit.layout:row(section_width, 30))
        suit.Label("Current Loyal Crew: " .. player_ship.loyal_men, {align = "center"}, suit.layout:row(section_width, 30))
        suit.Label("Current Crew From Enemies: " .. (player_ship.men - player_ship.loyal_men), {align = "center"}, suit.layout:row(section_width, 30))

        suit.layout:reset(grid_start_x + (section_width + padding) * 2, sy(top_margin))
        suit.Label("Sword", {align = "center"}, suit.layout:row(section_width, 30))
        local sword_cost = economy.get_sword_upgrade_cost(player_ship.sword)
        local current_level = combat.get_sword_level(player_ship.sword)
        if coins >= sword_cost then
            if suit.Button("Upgrade Sword (" .. sword_cost .. " coins)", suit.layout:row(section_width, 30)).hit then
                coins = coins - sword_cost
                player_ship.sword = combat.get_sword_name(current_level + 1)
                print("Upgraded sword to: " .. player_ship.sword)
            end
        else
            suit.Label("Need " .. sword_cost .. " coins", {align = "center"}, suit.layout:row(section_width, 30))
        end
        suit.Label("Current: " .. player_ship.sword, {align = "center"}, suit.layout:row(section_width, 30))

        suit.layout:reset(grid_start_x, sy(row2_y))
        suit.Label("Rod", {align = "center"}, suit.layout:row(section_width, 30))
        local rod_cost = economy.get_rod_upgrade_cost(player_ship.rod)
        local current_rod_level = fishing.get_rod_level(player_ship.rod)
        if coins >= rod_cost then
            if suit.Button("Upgrade Rod (" .. rod_cost .. " coins)", suit.layout:row(section_width, 30)).hit then
                coins = coins - rod_cost
                player_ship.rod = fishing.get_rod_name(current_rod_level + 1)
                print("Upgraded rod to: " .. player_ship.rod)
            end
        else
            suit.Label("Need " .. rod_cost .. " coins", {align = "center"}, suit.layout:row(section_width, 30))
        end
        suit.Label("Current: " .. player_ship.rod, {align = "center"}, suit.layout:row(section_width, 30))

        suit.layout:reset(grid_start_x + section_width + padding, sy(row2_y))
        suit.Label("Port-a-Shops", {align = "center"}, suit.layout:row(section_width, 30))
        local next_shop_cost = economy.get_next_shop_cost(port.get_port_a_shop_count())
        if coins >= next_shop_cost then
            if suit.Button("Buy Port-a-Shop (" .. next_shop_cost .. " coins)", suit.layout:row(section_width, 30)).hit then
                coins = coins - next_shop_cost
                port.add_port_a_shop()
            end
        else
            suit.Label("Need " .. next_shop_cost .. " coins", {align = "center"}, suit.layout:row(section_width, 30))
        end
        suit.Label("Owned: " .. port.get_port_a_shop_count(), {align = "center"}, suit.layout:row(section_width, 30))

        suit.layout:reset(grid_start_x + (section_width + padding) * 2, sy(row2_y))
        suit.Label("Ship Parts", {align = "center"}, suit.layout:row(section_width, 30))
        local speed_cost = economy.get_speed_upgrade_cost(player_ship.max_speed)
        if coins >= speed_cost then
            if suit.Button("Upgrade Speed (" .. speed_cost .. " coins)", suit.layout:row(section_width, 30)).hit then
                coins = coins - speed_cost
                player_ship.max_speed = player_ship.max_speed + 20
                player_ship.acceleration = player_ship.acceleration + economy.get_ship_parts_accel_bonus()
                print("Upgraded speed to: " .. player_ship.max_speed .. " and acceleration to: " .. player_ship.acceleration)
            end
        else
            suit.Label("Need " .. speed_cost .. " coins", {align = "center"}, suit.layout:row(section_width, 30))
        end
        suit.Label(
            "Speed: " .. player_ship.max_speed .. " | Accel: " .. player_ship.acceleration,
            {align = "center"},
            suit.layout:row(section_width, 30)
        )

        suit.layout:reset(grid_start_x, sy(row3_y))
        suit.Label("Fishing Cooldown", {align = "center"}, suit.layout:row(section_width, 30))
        local cooldown_cost = economy.get_cooldown_upgrade_cost(game_config.fishing_cooldown)
        if game_config.fishing_cooldown > 1.0 then
            if coins >= cooldown_cost then
                if suit.Button("Reduce Cooldown (" .. cooldown_cost .. " coins)", suit.layout:row(section_width, 30)).hit then
                    coins = coins - cooldown_cost
                    game_config.fishing_cooldown = math.max(1.0, game_config.fishing_cooldown - 0.1)
                    print("Reduced fishing cooldown to: " .. game_config.fishing_cooldown .. "s")
                end
            else
                suit.Label("Need " .. cooldown_cost .. " coins", {align = "center"}, suit.layout:row(section_width, 30))
            end
        else
            suit.Label("Cooldown fully upgraded", {align = "center"}, suit.layout:row(section_width, 30))
        end
        suit.Label("Current: " .. string.format("%.1f", game_config.fishing_cooldown) .. " seconds", {align = "center"}, suit.layout:row(section_width, 30))

        suit.layout:reset(grid_start_x + section_width + padding, sy(row3_y))
        suit.Label("Recovery Bay", {align = "center"}, suit.layout:row(section_width, 30))
        local recovery_bay_max = economy.get_recovery_bay_max()
        local healing_cost = player_ship.fainted_men * 10
        if player_ship.fainted_men > 0 then
            if coins >= healing_cost then
                if suit.Button("Recover Enemy Crew (" .. healing_cost .. " coins)", suit.layout:row(section_width, 30)).hit then
                    coins = coins - healing_cost
                    player_ship.men = player_ship.men + player_ship.fainted_men
                    print("Recovered " .. player_ship.fainted_men .. " enemy crew member(s)!")
                    player_ship.fainted_men = 0
                end
            else
                suit.Label("Need " .. healing_cost .. " coins", {align = "center"}, suit.layout:row(section_width, 30))
            end
        else
            suit.Label("No fainted enemy crew", {align = "center"}, suit.layout:row(section_width, 30))
        end
        suit.Label(
            string.format("Enemy Fainted: %d/%d", player_ship.fainted_men, recovery_bay_max),
            {align = "center"},
            suit.layout:row(section_width, 30)
        )

        suit.layout:reset(grid_start_x + (section_width + padding) * 2, sy(row3_y))
        suit.Label("Fish Inventory", {align = "center"}, suit.layout:row(section_width, 30))
        if suit.Button("Transfer to Inventory", suit.layout:row(section_width, 30)).hit then
            gamestate.set(GameType.SHOP_TRANSFER)
            inventory_state.search_text.text = ""
            inventory_state.selected_fish = nil
            inventory_state.scroll_offset = 0
            inventory_state.filtered_fish = {}
            for _, fish_name in ipairs(player_ship.caught_fish) do
                table.insert(inventory_state.filtered_fish, fish_name)
            end
        end
        if suit.Button("View Inventory", suit.layout:row(section_width, 30)).hit then
            gamestate.set(GameType.SHOP_VIEW_INVENTORY)
            inventory_state.scroll_offset = 0
        end
    end
end

function shop.draw_ui(gamestate)
    if gamestate.get():find(GameType.SHOP, 1, true) then
        local alpha = gamestate.get() ~= GameType.SHOP and 0.9 or 0.85
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.rectangle("fill", 0, 0, size.CANVAS_WIDTH, size.CANVAS_HEIGHT)
        love.graphics.setColor(1, 1, 1, 1)

        if gamestate.get() == GameType.SHOP then
            scrolling.begin_clip(main_shop_scroll)
            suit.draw()
            scrolling.end_clip()
            scrolling.draw(main_shop_scroll)
        else
            suit.draw()
        end
    end
end

function shop.reset()
    current_state = ""
    show_no_fish_message = false
    message_timer = 0
    coins = 0

    inventory_state.mode = ""
    inventory_state.search_text.text = ""
    inventory_state.selected_fish = nil
    inventory_state.filtered_fish = {}
    scrolling.reset(main_shop_scroll)
    shop_reopen_requires_exit = false

    port.reset()
end

function shop.get_port_a_shops_data()
    return {
        port_a_shops = port.get_port_a_shops_data(),
        coins = coins
    }
end

function shop.set_port_a_shops_data(data)
    if data.port_a_shops then
        port.set_port_a_shops_data(data.port_a_shops)
    end
    if data.coins then
        coins = data.coins
    end
end

function shop.get_last_port_a_shop_y()
    return port.get_last_port_a_shop_y()
end

return shop
