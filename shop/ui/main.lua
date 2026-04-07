local main_ui = {}

local function sell_all_fish(runtime_state, player_ship, economy, fishing)
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

        runtime_state.coins = runtime_state.coins + total
        player_ship.caught_fish = {}
        print("Sold fish for " .. total .. " coins!")
        return
    end

    runtime_state.show_no_fish_message = true
    runtime_state.message_timer = runtime_state.message_duration
end

local function render_fish_section(ctx, x, y, section_width)
    local suit = ctx.suit
    local runtime_state = ctx.runtime_state
    local player_ship = ctx.player_ship

    suit.layout:reset(x, y)
    suit.Label("Fish", {align = "center"}, suit.layout:row(section_width, 30))

    local button_text = #player_ship.caught_fish > 0
        and ("Sell All Fish (" .. #player_ship.caught_fish .. ")")
        or "Sell All Fish (none)"

    if suit.Button(button_text, suit.layout:row(section_width, 30)).hit then
        sell_all_fish(runtime_state, player_ship, ctx.economy, ctx.fishing)
    end

    if runtime_state.show_no_fish_message then
        suit.Label("No fish to sell!", {align = "center"}, suit.layout:row(section_width, 20))
    end
end

local function render_crew_section(ctx, x, y, section_width)
    local suit = ctx.suit
    local runtime_state = ctx.runtime_state
    local player_ship = ctx.player_ship
    local economy = ctx.economy

    suit.layout:reset(x, y)
    suit.Label("Crew Members", {align = "center"}, suit.layout:row(section_width, 30))

    local hire_cost = economy.get_crew_hire_cost(player_ship.loyal_men)
    if runtime_state.coins >= hire_cost then
        if suit.Button("Hire 1 Man (" .. hire_cost .. " coins)", suit.layout:row(section_width, 30)).hit then
            runtime_state.coins = runtime_state.coins - hire_cost
            player_ship.men = player_ship.men + 1
            player_ship.loyal_men = player_ship.loyal_men + 1
        end
    else
        suit.Label("Need " .. hire_cost .. " coins", {align = "center"}, suit.layout:row(section_width, 30))
    end

    suit.Label("Current Crew: " .. player_ship.men, {align = "center"}, suit.layout:row(section_width, 30))
    suit.Label("Current Loyal Crew: " .. player_ship.loyal_men, {align = "center"}, suit.layout:row(section_width, 30))
    suit.Label("Current Crew From Enemies: " .. (player_ship.men - player_ship.loyal_men), {align = "center"}, suit.layout:row(section_width, 30))
end

local function render_sword_section(ctx, x, y, section_width)
    local suit = ctx.suit
    local runtime_state = ctx.runtime_state
    local player_ship = ctx.player_ship
    local economy = ctx.economy
    local combat = ctx.combat

    suit.layout:reset(x, y)
    suit.Label("Sword", {align = "center"}, suit.layout:row(section_width, 30))

    local sword_cost = economy.get_sword_upgrade_cost(player_ship.sword)
    local current_level = combat.get_sword_level(player_ship.sword)
    if runtime_state.coins >= sword_cost then
        if suit.Button("Upgrade Sword (" .. sword_cost .. " coins)", suit.layout:row(section_width, 30)).hit then
            runtime_state.coins = runtime_state.coins - sword_cost
            player_ship.sword = combat.get_sword_name(current_level + 1)
            print("Upgraded sword to: " .. player_ship.sword)
        end
    else
        suit.Label("Need " .. sword_cost .. " coins", {align = "center"}, suit.layout:row(section_width, 30))
    end

    suit.Label("Current: " .. player_ship.sword, {align = "center"}, suit.layout:row(section_width, 30))
end

local function render_rod_section(ctx, x, y, section_width)
    local suit = ctx.suit
    local runtime_state = ctx.runtime_state
    local player_ship = ctx.player_ship
    local economy = ctx.economy
    local fishing = ctx.fishing

    suit.layout:reset(x, y)
    suit.Label("Rod", {align = "center"}, suit.layout:row(section_width, 30))

    local rod_cost = economy.get_rod_upgrade_cost(player_ship.rod)
    local current_rod_level = fishing.get_rod_level(player_ship.rod)
    if runtime_state.coins >= rod_cost then
        if suit.Button("Upgrade Rod (" .. rod_cost .. " coins)", suit.layout:row(section_width, 30)).hit then
            runtime_state.coins = runtime_state.coins - rod_cost
            player_ship.rod = fishing.get_rod_name(current_rod_level + 1)
            print("Upgraded rod to: " .. player_ship.rod)
        end
    else
        suit.Label("Need " .. rod_cost .. " coins", {align = "center"}, suit.layout:row(section_width, 30))
    end

    suit.Label("Current: " .. player_ship.rod, {align = "center"}, suit.layout:row(section_width, 30))
end

local function render_port_shop_section(ctx, x, y, section_width)
    local suit = ctx.suit
    local runtime_state = ctx.runtime_state
    local economy = ctx.economy
    local port = ctx.port

    suit.layout:reset(x, y)
    suit.Label("Port-a-Shops", {align = "center"}, suit.layout:row(section_width, 30))

    local next_shop_cost = economy.get_next_shop_cost(port.get_port_a_shop_count())
    if runtime_state.coins >= next_shop_cost then
        if suit.Button("Buy Port-a-Shop (" .. next_shop_cost .. " coins)", suit.layout:row(section_width, 30)).hit then
            runtime_state.coins = runtime_state.coins - next_shop_cost
            port.add_port_a_shop()
        end
    else
        suit.Label("Need " .. next_shop_cost .. " coins", {align = "center"}, suit.layout:row(section_width, 30))
    end

    suit.Label("Owned: " .. port.get_port_a_shop_count(), {align = "center"}, suit.layout:row(section_width, 30))
end

local function render_ship_parts_section(ctx, x, y, section_width)
    local suit = ctx.suit
    local runtime_state = ctx.runtime_state
    local player_ship = ctx.player_ship
    local economy = ctx.economy

    suit.layout:reset(x, y)
    suit.Label("Ship Parts", {align = "center"}, suit.layout:row(section_width, 30))

    local speed_cost = economy.get_speed_upgrade_cost(player_ship.max_speed)
    if runtime_state.coins >= speed_cost then
        if suit.Button("Upgrade Speed (" .. speed_cost .. " coins)", suit.layout:row(section_width, 30)).hit then
            runtime_state.coins = runtime_state.coins - speed_cost
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
end

local function render_cooldown_section(ctx, x, y, section_width)
    local suit = ctx.suit
    local runtime_state = ctx.runtime_state
    local economy = ctx.economy
    local game_config = ctx.game_config

    suit.layout:reset(x, y)
    suit.Label("Fishing Cooldown", {align = "center"}, suit.layout:row(section_width, 30))

    local cooldown_cost = economy.get_cooldown_upgrade_cost(game_config.fishing_cooldown)
    if game_config.fishing_cooldown > 1.0 then
        if runtime_state.coins >= cooldown_cost then
            if suit.Button("Reduce Cooldown (" .. cooldown_cost .. " coins)", suit.layout:row(section_width, 30)).hit then
                runtime_state.coins = runtime_state.coins - cooldown_cost
                game_config.fishing_cooldown = math.max(1.0, game_config.fishing_cooldown - 0.1)
                print("Reduced fishing cooldown to: " .. game_config.fishing_cooldown .. "s")
            end
        else
            suit.Label("Need " .. cooldown_cost .. " coins", {align = "center"}, suit.layout:row(section_width, 30))
        end
    else
        suit.Label("Cooldown fully upgraded", {align = "center"}, suit.layout:row(section_width, 30))
    end

    suit.Label(
        "Current: " .. string.format("%.1f", game_config.fishing_cooldown) .. " seconds",
        {align = "center"},
        suit.layout:row(section_width, 30)
    )
end

local function render_recovery_section(ctx, x, y, section_width)
    local suit = ctx.suit
    local runtime_state = ctx.runtime_state
    local player_ship = ctx.player_ship
    local economy = ctx.economy

    suit.layout:reset(x, y)
    suit.Label("Recovery Bay", {align = "center"}, suit.layout:row(section_width, 30))

    local recovery_bay_max = economy.get_recovery_bay_max()
    local healing_cost = player_ship.fainted_men * 10
    if player_ship.fainted_men > 0 then
        if runtime_state.coins >= healing_cost then
            if suit.Button("Recover Enemy Crew (" .. healing_cost .. " coins)", suit.layout:row(section_width, 30)).hit then
                runtime_state.coins = runtime_state.coins - healing_cost
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
end

local function render_inventory_section(ctx, x, y, section_width)
    local suit = ctx.suit

    suit.layout:reset(x, y)
    suit.Label("Fish Inventory", {align = "center"}, suit.layout:row(section_width, 30))

    if suit.Button("Transfer to Inventory", suit.layout:row(section_width, 30)).hit then
        ctx.open_transfer()
    end

    if suit.Button("View Inventory", suit.layout:row(section_width, 30)).hit then
        ctx.open_inventory()
    end
end

function main_ui.render(ctx)
    local suit = ctx.suit
    local size = ctx.size
    local scrolling = ctx.scrolling
    local runtime_state = ctx.runtime_state

    local window_width = size.CANVAS_WIDTH
    local window_height = size.CANVAS_HEIGHT

    local section_width = 250
    local section_height = 150
    local padding = 30
    local top_margin = 100
    local title_width = 200
    local row2_y = top_margin + section_height + padding
    local row3_y = row2_y + section_height + padding
    local content_height = row3_y + section_height + padding

    scrolling.update(runtime_state.main_shop_scroll, {
        viewport_x = 0,
        viewport_y = 0,
        viewport_width = window_width,
        viewport_height = window_height,
        content_height = content_height,
        reserve_scrollbar_space = true
    })

    local scroll_y = scrolling.get_offset_y(runtime_state.main_shop_scroll, true)
    local function sy(y)
        return y + scroll_y
    end

    local grid_width = section_width * 3 + padding * 2
    local grid_start_x = runtime_state.main_shop_scroll.viewport.x + ((runtime_state.main_shop_scroll.viewport.w - grid_width) / 2)

    suit.layout:reset(runtime_state.main_shop_scroll.viewport.x + ((runtime_state.main_shop_scroll.viewport.w - title_width) / 2), sy(padding))
    suit.Label("SHOP", {align = "center"}, suit.layout:row(title_width, 30))

    suit.layout:reset(runtime_state.main_shop_scroll.viewport.x + ((runtime_state.main_shop_scroll.viewport.w - title_width) / 2), sy(padding + 40))
    suit.Label("Coins: " .. string.format("%.1f", runtime_state.coins), {align = "center"}, suit.layout:row(title_width, 30))

    render_fish_section(ctx, grid_start_x, sy(top_margin), section_width)
    render_crew_section(ctx, grid_start_x + section_width + padding, sy(top_margin), section_width)
    render_sword_section(ctx, grid_start_x + (section_width + padding) * 2, sy(top_margin), section_width)

    render_rod_section(ctx, grid_start_x, sy(row2_y), section_width)
    render_port_shop_section(ctx, grid_start_x + section_width + padding, sy(row2_y), section_width)
    render_ship_parts_section(ctx, grid_start_x + (section_width + padding) * 2, sy(row2_y), section_width)

    render_cooldown_section(ctx, grid_start_x, sy(row3_y), section_width)
    render_recovery_section(ctx, grid_start_x + section_width + padding, sy(row3_y), section_width)
    render_inventory_section(ctx, grid_start_x + (section_width + padding) * 2, sy(row3_y), section_width)
end

return main_ui
