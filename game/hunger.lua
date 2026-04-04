local hunger = {}
local alert = require("game.alert")

local function sync_hunger_levels(player_ship, hunger_config)
    local crew_count = math.max(0, math.floor(tonumber(player_ship.men) or 0))
    player_ship.men = crew_count
    player_ship.hunger_levels = player_ship.hunger_levels or {}

    while #player_ship.hunger_levels < crew_count do
        table.insert(player_ship.hunger_levels, hunger_config.start)
    end

    while #player_ship.hunger_levels > crew_count do
        table.remove(player_ship.hunger_levels)
    end

    for i = 1, #player_ship.hunger_levels do
        local current = tonumber(player_ship.hunger_levels[i]) or hunger_config.start
        player_ship.hunger_levels[i] = math.max(0, math.min(hunger_config.max, current))
    end
end

local function set_hunger_alert(hunger_config, text)
    alert.show(text, hunger_config.alert_duration, {1, 0.3, 0.3, 1})
    print(text)
end

local function find_hungriest_index(levels)
    if #levels == 0 then
        return nil
    end

    local hungriest_index = 1
    local lowest_hunger = levels[1]

    for i = 2, #levels do
        if levels[i] < lowest_hunger then
            lowest_hunger = levels[i]
            hungriest_index = i
        end
    end

    return hungriest_index
end

local function consume_best_fish(caught_fish, fishing_module)
    if not caught_fish or #caught_fish == 0 then
        return nil, nil
    end

    local best_index
    local best_name
    local best_value

    for i = 1, #caught_fish do
        local fish_name = caught_fish[i]
        local blocked_for_feeding = (fish_name == "Gold Sturgeon")
            or (fishing_module.is_night_fish and fishing_module.is_night_fish(fish_name))
        if not blocked_for_feeding then
        local fish_value = fishing_module.get_fish_value(fish_name)
            if (not best_value) or fish_value > best_value then
                best_index = i
                best_name = fish_name
                best_value = fish_value
            end
        end
    end

    if not best_index then
        return nil, nil
    end

    table.remove(caught_fish, best_index)
    return best_name, best_value
end

local function count_feedable_fish(caught_fish, fishing_module)
    if not caught_fish then
        return 0
    end

    local count = 0
    for _, fish_name in ipairs(caught_fish) do
        local blocked_for_feeding = (fish_name == "Gold Sturgeon")
            or (fishing_module.is_night_fish and fishing_module.is_night_fish(fish_name))
        if not blocked_for_feeding then
            count = count + 1
        end
    end
    return count
end

local function get_current_catch_value_range(fishing_module, player_ship)
    local available_fish = fishing_module.get_fish_avalible(
        player_ship.x,
        player_ship.y,
        player_ship.time_system.time
    )

    if not available_fish or #available_fish == 0 then
        return nil, nil
    end

    local min_value
    local max_value

    for _, fish_name in ipairs(available_fish) do
        local fish_value = fishing_module.get_fish_value(fish_name)
        if not min_value or fish_value < min_value then
            min_value = fish_value
        end
        if not max_value or fish_value > max_value then
            max_value = fish_value
        end
    end

    return min_value, max_value
end

local function get_feed_percent_for_value(fish_value, min_current_value, max_current_value, hunger_config)
    local below_percent = tonumber(hunger_config.feed_below_current_percent) or 5
    local lowest_percent = tonumber(hunger_config.feed_lowest_current_percent) or 25
    local mid_percent = tonumber(hunger_config.feed_mid_current_percent) or 50
    local highest_percent = tonumber(hunger_config.feed_highest_current_percent) or 90
    local above_percent = tonumber(hunger_config.feed_above_current_percent) or 100

    local safe_value = math.max(1, tonumber(fish_value) or 1)
    if not min_current_value or not max_current_value then
        return mid_percent
    end

    if safe_value < min_current_value then
        return below_percent
    end

    if safe_value > max_current_value then
        return above_percent
    end

    if min_current_value == max_current_value then
        return mid_percent
    end

    if safe_value == min_current_value then
        return lowest_percent
    end

    if safe_value == max_current_value then
        return highest_percent
    end

    return mid_percent
end

local function calculate_feed_amount(fish_value, min_current_value, max_current_value, hunger_config)
    local feed_percent = get_feed_percent_for_value(fish_value, min_current_value, max_current_value, hunger_config)
    local base_feed = (hunger_config.max * feed_percent) / 100
    local adjusted_feed = math.floor(base_feed + 0.5)

    if adjusted_feed < hunger_config.feed_min then
        adjusted_feed = hunger_config.feed_min
    end
    if adjusted_feed > hunger_config.feed_max then
        adjusted_feed = hunger_config.feed_max
    end

    return adjusted_feed
end

local function feed_one_crew_member(state, player_ship, hunger_config)
    local fish_name, fish_value = consume_best_fish(player_ship.caught_fish, state.fishing.module)
    if not fish_name then
        return nil, nil
    end

    local min_current_value, max_current_value = get_current_catch_value_range(state.fishing.module, player_ship)
    local feed_amount = calculate_feed_amount(
        fish_value,
        min_current_value,
        max_current_value,
        hunger_config
    )
    local hungriest_index = find_hungriest_index(player_ship.hunger_levels)

    if hungriest_index then
        player_ship.hunger_levels[hungriest_index] = math.min(
            hunger_config.max,
            player_ship.hunger_levels[hungriest_index] + feed_amount
        )
    end

    return fish_name, feed_amount
end

local function can_decay_hunger(current_state, GameType)
    return current_state == GameType.VOYAGE or
        current_state == GameType.FISHING or
        current_state == GameType.SHOP or
        current_state == GameType.SHOP_TRANSFER or
        current_state == GameType.SHOP_VIEW_INVENTORY
end

local function get_decay_per_second(state, hunger_config)
    local days_to_die = tonumber(hunger_config.days_without_food_to_die)
    if days_to_die and days_to_die > 0 then
        local day_length = tonumber(state.player.time_system.DAY_LENGTH) or tonumber(state.constants.time.day_length) or 1
        if day_length > 0 then
            return hunger_config.max / (day_length * days_to_die)
        end
    end

    return tonumber(hunger_config.decay_per_second) or 0
end

local function get_lowest_hunger(levels)
    if not levels or #levels == 0 then
        return nil
    end

    local lowest = levels[1]
    for i = 2, #levels do
        if levels[i] < lowest then
            lowest = levels[i]
        end
    end

    return lowest
end

local function has_hungry_crew(levels, threshold)
    if not levels then
        return false
    end

    for _, value in ipairs(levels) do
        if value <= threshold then
            return true
        end
    end

    return false
end

function hunger.sync(player_ship, hunger_config)
    sync_hunger_levels(player_ship, hunger_config)
end

function hunger.reset(player_ship, hunger_config)
    local crew_count = math.max(0, math.floor(tonumber(player_ship.men) or 0))
    player_ship.hunger_levels = {}
    for i = 1, crew_count do
        player_ship.hunger_levels[i] = hunger_config.start
    end
end

function hunger.handle_feed_button(state, options)
    local gamestate = state.system.gamestate
    local GameType = state.system.gametype
    if gamestate.get() ~= GameType.VOYAGE then
        return
    end

    options = options or {}
    local suit = state.ui.suit
    local size = state.system.size
    local player_ship = state.player
    local hunger_config = state.constants.hunger

    local button_x = options.x or 10
    local button_y = options.y or (size.CANVAS_HEIGHT - 40)
    local button_width = options.width or 80
    local button_height = options.height or 30
    local button_id = options.id or "feed_crew"

    if not suit.Button("Feed", {id = button_id}, button_x, button_y, button_width, button_height).hit then
        return
    end

    sync_hunger_levels(player_ship, hunger_config)

    if player_ship.men <= 0 or #player_ship.hunger_levels == 0 then
        set_hunger_alert(hunger_config, "No crew left to feed.")
        return
    end

    local fish_name, feed_amount = feed_one_crew_member(state, player_ship, hunger_config)
    if not fish_name then
        set_hunger_alert(hunger_config, "No fish to feed the crew.")
        return
    end

    local message = string.format("Fed crew with %s (+%d hunger)", fish_name, feed_amount)
    set_hunger_alert(hunger_config, message)
    state.fishing.runtime.add_catch_text(message)
end

function hunger.handle_feed_all_button(state, options)
    local gamestate = state.system.gamestate
    local GameType = state.system.gametype
    if gamestate.get() ~= GameType.VOYAGE then
        return
    end

    options = options or {}
    local suit = state.ui.suit
    local size = state.system.size
    local player_ship = state.player
    local hunger_config = state.constants.hunger

    local button_x = options.x or 10
    local button_y = options.y or (size.CANVAS_HEIGHT - 70)
    local button_width = options.width or 80
    local button_height = options.height or 30
    local button_id = options.id or "feed_all_crew"

    if not suit.Button("Feed All", {id = button_id}, button_x, button_y, button_width, button_height).hit then
        return
    end

    sync_hunger_levels(player_ship, hunger_config)

    if player_ship.men <= 0 or #player_ship.hunger_levels == 0 then
        set_hunger_alert(hunger_config, "No crew left to feed.")
        return
    end

    local crew_count = math.max(0, math.floor(tonumber(player_ship.men) or 0))
    local feedable_fish_count = count_feedable_fish(player_ship.caught_fish, state.fishing.module)
    if feedable_fish_count < crew_count then
        set_hunger_alert(hunger_config, "Not enough fish to feed everyone.")
        return
    end

    local total_hunger_added = 0
    for _ = 1, crew_count do
        local _, feed_amount = feed_one_crew_member(state, player_ship, hunger_config)
        if feed_amount then
            total_hunger_added = total_hunger_added + feed_amount
        end
    end

    local message = string.format("Fed all crew (%d fish used)", crew_count)
    set_hunger_alert(hunger_config, message)
    state.fishing.runtime.add_catch_text(
        string.format("Crew meal: +%d total hunger", math.floor(total_hunger_added + 0.5))
    )
end

function hunger.update(dt, state)
    local gamestate = state.system.gamestate
    local GameType = state.system.gametype
    local player_ship = state.player
    local hunger_config = state.constants.hunger

    sync_hunger_levels(player_ship, hunger_config)

    if player_ship.men <= 0 then
        return nil
    end

    if not can_decay_hunger(gamestate.get(), GameType) then
        return nil
    end

    local decay_per_second = get_decay_per_second(state, hunger_config)
    for i = 1, #player_ship.hunger_levels do
        player_ship.hunger_levels[i] = math.max(0, player_ship.hunger_levels[i] - decay_per_second * dt)
    end

    local deaths = 0
    for i = #player_ship.hunger_levels, 1, -1 do
        if player_ship.hunger_levels[i] <= 0 then
            table.remove(player_ship.hunger_levels, i)
            deaths = deaths + 1
        end
    end

    if deaths > 0 then
        player_ship.men = math.max(0, player_ship.men - deaths)
        local message = deaths == 1
            and "A crew member starved to death!"
            or string.format("%d crew members starved to death!", deaths)
        set_hunger_alert(hunger_config, message)
        state.fishing.runtime.add_catch_text(message)
    end

    if player_ship.men <= 0 then
        print("Your crew starved to death.")
        state.actions.reset_game()
        gamestate.set(GameType.MENU)
        return GameType.MENU
    end

    return nil
end

function hunger.draw_hud(state)
    local player_ship = state.player
    local hunger_config = state.constants.hunger
    sync_hunger_levels(player_ship, hunger_config)

    local mods_count = 0
    if state.mods then
        mods_count = tonumber(state.mods.count) or 0
    end

    local lowest_hunger = get_lowest_hunger(player_ship.hunger_levels)
    if lowest_hunger then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(string.format("Lowest Hunger: %d%%", math.floor(lowest_hunger + 0.5)), 10, 50)

        local half_hunger_threshold = hunger_config.max * hunger_config.half_threshold
        if has_hungry_crew(player_ship.hunger_levels, half_hunger_threshold) then
            love.graphics.setColor(1, 0.1, 0.1, 1)
            love.graphics.circle("fill", 150, 58, 5)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    if mods_count > 0 then
        love.graphics.print(string.format("Mods: %d", mods_count), 10, 70)
    else
        love.graphics.print("no mods", 10, 70)
    end

end

return hunger
