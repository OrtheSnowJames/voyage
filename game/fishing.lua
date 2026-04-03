local fishing = {}
local size = require("game.size")

local fish = {
    "Bluegill", "Crappie", "Yellow Perch", "Redfin Pickerel", "Bullhead Catfish",
    "Largemouth Bass", "Smallmouth Bass", "Channel Catfish", "Common Carp", "Mirror Carp",
    "Northern Pike", "Walleye", "Rainbow Trout", "Brown Trout", "Brook Trout",
    "Flathead Catfish", "Lake Trout", "Grass Carp", "Cutthroat Trout", "Sauger",
    "Muskellunge (Muskie)", "Arctic Char", "Paddlefish", "Tilapia", "Oscar",
    "Peacock Bass", "Piranha", "Arowana", "Snakehead", "Sturgeon"
}

local rare_night_fish = {
    "Twilight Pike", "Glassfin Monarch", "Eclipsed Lanternfish", "Ashscale Marlin", "Starbone Eel",
    "Vermillion Snapjaw", "Crimson Daggerfish", "Phantom Koi", "Abyssal Goldtail", "Frostgill Leviathan",
    "Obsidian Sunfish", "Echofin Halibut", "Wraithfin Thresher", "Moonlace Carp", "Radiant Chimerafish"
}

local special_fish = {
    "Gold Sturgeon"
}

local rods = {
    "Basic Rod", "Good Rod", "Great Rod", "Super Rod", "Ultra Rod", "Master Rod", "Legendary Rod"
}

local corruption_level = 0

local fish_icon = love.graphics.newImage("assets/fish-icon.png")
local fish_icon_width = 64
local fish_icon_height = 64

local BAR_WIDTH = 60
local BAR_HEIGHT = 300
local BAR_LEVELS = 4
local LEVEL_HEIGHT = BAR_HEIGHT / BAR_LEVELS

local GRAVITY = 200
local ROD_SPEED = 300
local CATCH_TIME = 5.0
local CATCH_RANGE = 40
local PROGRESS_START = 0.5
local PERFECT_ALIGNMENT_BONUS = 0.3

local minigame_state = {
    is_active = false,
    fish_position = 0,
    rod_position = 0,
    rod_velocity = 0,
    mouse_angle = 0,
    mouse_radius = 0,
    mouse_x = 0,
    mouse_y = 0,
    last_mouse_x = 0,
    last_mouse_y = 0,
    mouse_movement = 0,
    catch_progress = PROGRESS_START,
    time_on_fish = 0,
    total_time = 0,
    perfect_catch = true,
    touches = 0,
    accuracy_score = 0,
    fish_name = "",
    available_fish = {},
    rod_level = 1,
    depth_level = 1,
    water_color = {0.1, 0.3, 0.6},
    time_in_perfect = 0,
    time_in_catch = 0,
    time_outside_catch = 0
}

local minigame = {}

local function update_catch_text_offsets(catch_texts, spacing)
    for i, catch in ipairs(catch_texts) do
        catch.y_offset = (i - 1) * spacing
    end
end

local function standardize_depth(y)
    local depth_level = math.floor(math.abs(y) / 1000)
    if depth_level < 1 then
        depth_level = 1
    end
    return depth_level
end

local function build_minigame_result(overrides)
    return {
        success = overrides.success,
        fish_name = overrides.fish_name or "None",
        original_fish = "???",
        perfect_catch = overrides.perfect_catch,
        total_time = minigame_state.total_time,
        touches = minigame_state.touches,
        quality_score = overrides.quality_score or 0,
        cancelled = overrides.cancelled,
        combat_interrupt = overrides.combat_interrupt
    }
end

local function end_minigame()
    minigame_state.is_active = false
end

local function pick_best_roll(rod_rarity, rarity_scale_max, fish_available)
    local num_rolls = math.floor(1 + rod_rarity / 2)
    local best_catch = 1

    for _ = 1, num_rolls do
        local roll = math.random(1, math.max(2, math.floor(#fish_available * 0.4)))
        local bias = math.floor((rod_rarity / rarity_scale_max) * math.random(0, #fish_available * 0.3))
        roll = math.min(roll + bias, #fish_available)
        best_catch = math.max(best_catch, roll)
    end

    return fish_available[best_catch]
end

function fishing.get_rod_level(rod_name)
    for i, v in ipairs(rods) do
        if v == rod_name then
            return i
        end
    end

    local plus = string.match(rod_name or "", "Legendary Rod%+(%d+)")
    if plus then
        return #rods + tonumber(plus)
    end

    return 1
end

function fishing.get_rod_name(level)
    if level <= #rods then
        return rods[level]
    end
    return string.format("Legendary Rod+%d", level - #rods)
end

function fishing.get_rod_rarity(rod)
    return fishing.get_rod_level(rod)
end

function fishing.get_rod_top_rarity()
    return #rods
end

function fishing.get_all_fish()
    local all_fish = {}
    for _, fish_name in ipairs(fish) do
        table.insert(all_fish, fish_name)
    end
    for _, fish_name in ipairs(rare_night_fish) do
        table.insert(all_fish, fish_name)
    end
    for _, fish_name in ipairs(special_fish) do
        table.insert(all_fish, fish_name)
    end
    return all_fish
end

function fishing.is_special_fish(fish_name)
    for _, special in ipairs(special_fish) do
        if fish_name == special then
            return true
        end
    end
    return false
end

function fishing.set_corruption_level(level)
    corruption_level = math.max(0, tonumber(level) or 0)
end

function fishing.get_fish_avalible(x, y, game_time)
    if corruption_level >= 0.3 then
        print("The water remembers..")
        return {"Brown Trout"}
    end

    local depth_level = standardize_depth(y)
    local start_index = depth_level
    local end_index = start_index + 2

    if end_index > #fish then
        end_index = #fish
        start_index = end_index - 2
    end

    local available_fish = {}
    for i = start_index, end_index do
        table.insert(available_fish, fish[i])
    end

    if game_time then
        local time_of_day = (game_time / (12 * 60)) * 12
        if time_of_day >= 8 then
            local night_fish_index = math.min(depth_level, #rare_night_fish)
            table.insert(available_fish, rare_night_fish[night_fish_index])

            if depth_level > 2 and math.random() < 0.5 then
                local second_index = math.min(night_fish_index + 1, #rare_night_fish)
                table.insert(available_fish, rare_night_fish[second_index])
            end
        end

        if time_of_day >= 11.5 and math.random() < 0.01 then
            table.insert(available_fish, "Gold Sturgeon")
        end
    end

    return available_fish
end

function fishing.fish(rod_rarity, top_rarity, fish_available, player_y)
    rod_rarity = math.max(1, tonumber(rod_rarity) or 1)
    local rarity_scale_max = math.max(tonumber(top_rarity) or 1, rod_rarity)

    if player_y then
        local depth_level = standardize_depth(player_y)
        local effective_rod_rarity = rod_rarity - depth_level
        rod_rarity = math.max(1, effective_rod_rarity)
    end

    if not fish_available or #fish_available == 0 then
        return fish[1]
    end

    for _, fish_name in ipairs(fish_available) do
        if fish_name == "Gold Sturgeon" and math.random() < 0.01 then
            return "Gold Sturgeon"
        end
    end

    return pick_best_roll(rod_rarity, rarity_scale_max, fish_available)
end

function fishing.get_fish_value(fish_name)
    if fish_name == "Gold Sturgeon" then
        return 100000
    end

    for i, f in ipairs(fish) do
        if f == fish_name then
            return i
        end
    end

    for i, f in ipairs(rare_night_fish) do
        if f == fish_name then
            return #fish + i
        end
    end

    return 1
end

function fishing.debug_fish_at_depth(y, game_time)
    local available = fishing.get_fish_avalible(0, y, game_time)
    print("at depth " .. y .. " (level " .. standardize_depth(y) .. "), you can catch:")
    for _, fish_name in ipairs(available) do
        local is_night_fish = false
        for _, night_fish in ipairs(rare_night_fish) do
            if fish_name == night_fish then
                is_night_fish = true
                break
            end
        end

        if is_night_fish then
            print("  - " .. fish_name .. " (night fish, only after 8:00)")
        else
            print("  - " .. fish_name)
        end
    end
end

function minigame.start_fishing(available_fish, rod_level, depth_level, water_color)
    minigame_state.is_active = true
    minigame_state.fish_position = math.random(50, BAR_HEIGHT - 50)
    minigame_state.rod_position = BAR_HEIGHT / 2
    minigame_state.rod_velocity = 0
    minigame_state.mouse_angle = 0
    minigame_state.mouse_radius = 0
    minigame_state.catch_progress = PROGRESS_START
    minigame_state.time_on_fish = 0
    minigame_state.total_time = 0
    minigame_state.perfect_catch = true
    minigame_state.touches = 0
    minigame_state.available_fish = available_fish or {}
    minigame_state.rod_level = rod_level or 1
    minigame_state.depth_level = depth_level or 1
    minigame_state.water_color = water_color or {0.1, 0.3, 0.6}
    minigame_state.fish_name = "???"

    local mouse_x, mouse_y = love.mouse.getPosition()
    minigame_state.mouse_x = mouse_x
    minigame_state.last_mouse_x = mouse_x
    minigame_state.mouse_y = mouse_y
    minigame_state.last_mouse_y = mouse_y
    minigame_state.mouse_movement = 0
    minigame_state.accuracy_score = 0
    minigame_state.time_in_perfect = 0
    minigame_state.time_in_catch = 0
    minigame_state.time_outside_catch = 0
end

function minigame.update(dt)
    if not minigame_state.is_active then
        return nil
    end

    minigame_state.total_time = minigame_state.total_time + dt

    local mouse_x, mouse_y = love.mouse.getPosition()
    local center_x = size.CANVAS_WIDTH / 2
    local center_y = size.CANVAS_HEIGHT / 2

    local mouse_dx = mouse_x - minigame_state.last_mouse_x
    local mouse_dy = mouse_y - minigame_state.last_mouse_y
    local mouse_movement = math.sqrt(mouse_dx * mouse_dx + mouse_dy * mouse_dy)

    minigame_state.last_mouse_x = mouse_x
    minigame_state.last_mouse_y = mouse_y

    local dx = mouse_x - center_x
    local dy = mouse_y - center_y
    minigame_state.mouse_angle = math.atan2(dy, dx)
    minigame_state.mouse_radius = math.sqrt(dx * dx + dy * dy)

    local max_movement = 30
    local movement_multiplier = math.min(mouse_movement / max_movement, 4.0)
    local radius_multiplier = math.min(minigame_state.mouse_radius / 100, 1.0)
    local total_multiplier = (movement_multiplier * 0.8) + (radius_multiplier * 0.2)

    local depth_difficulty = 1 + (minigame_state.depth_level - 1) * 0.5
    local rod_control_bonus = math.min(3.0, 1 + (minigame_state.rod_level - 1) * 0.18)
    local upward_force = (ROD_SPEED * total_multiplier * rod_control_bonus) / depth_difficulty

    local rod_bonus = math.min(3.0, 1 + (minigame_state.rod_level - 1) * 0.18)
    minigame_state.rod_velocity = minigame_state.rod_velocity + (GRAVITY / rod_bonus) * dt
    minigame_state.rod_velocity = minigame_state.rod_velocity - upward_force * dt
    minigame_state.rod_position = minigame_state.rod_position + minigame_state.rod_velocity * dt

    if minigame_state.rod_position < 0 then
        minigame_state.rod_position = 0
        minigame_state.rod_velocity = 0
        minigame_state.touches = minigame_state.touches + 1
        minigame_state.perfect_catch = false
    elseif minigame_state.rod_position > BAR_HEIGHT then
        minigame_state.rod_position = BAR_HEIGHT
        minigame_state.rod_velocity = 0
        minigame_state.touches = minigame_state.touches + 1
        minigame_state.perfect_catch = false
    end

    local distance_to_fish = math.abs(minigame_state.rod_position - minigame_state.fish_position)
    local is_near_fish = distance_to_fish <= CATCH_RANGE

    if is_near_fish then
        local accuracy_multiplier = 1.0

        if distance_to_fish <= 5 then
            accuracy_multiplier = 1.0 + PERFECT_ALIGNMENT_BONUS
            minigame_state.time_in_perfect = minigame_state.time_in_perfect + dt
        elseif distance_to_fish <= 40 then
            minigame_state.time_in_catch = minigame_state.time_in_catch + dt
        else
            minigame_state.time_outside_catch = minigame_state.time_outside_catch + dt
        end

        minigame_state.time_on_fish = minigame_state.time_on_fish + dt
        minigame_state.catch_progress = minigame_state.catch_progress + (dt / CATCH_TIME) * 0.5 * accuracy_multiplier

        if minigame_state.catch_progress >= 1.0 then
            return minigame.complete_fishing()
        end
    else
        minigame_state.catch_progress = math.max(0, minigame_state.catch_progress - dt * 0.2)
        if minigame_state.catch_progress <= 0 then
            return minigame.fail_fishing()
        end
    end

    return nil
end

function minigame.determine_final_fish(quality_score)
    local available_fish = minigame_state.available_fish
    if #available_fish == 0 then
        return "Bluegill"
    end

    if quality_score >= 180 then
        return available_fish[#available_fish]
    elseif quality_score >= 140 then
        local current_index = math.random(1, #available_fish)
        return available_fish[math.min(current_index + 1, #available_fish)]
    elseif quality_score >= 100 then
        local upper_half = math.ceil(#available_fish / 2)
        return available_fish[math.random(upper_half, #available_fish)]
    elseif quality_score >= 60 then
        return available_fish[math.ceil(#available_fish / 2)]
    elseif quality_score >= 30 then
        return available_fish[math.random(1, math.max(1, math.floor(#available_fish / 2)))]
    else
        if quality_score < 0 then
            return "Bluegill"
        end
        return available_fish[math.max(1, math.floor(#available_fish / 3))]
    end
end

function minigame.complete_fishing()
    local quality_score = 0

    if minigame_state.perfect_catch then
        quality_score = quality_score + 10
    end

    local total_time = math.max(0.0001, minigame_state.total_time)
    local perfect_percentage = (minigame_state.time_in_perfect / total_time) * 100
    local catch_percentage = (minigame_state.time_in_catch / total_time) * 100

    if perfect_percentage >= 80 then
        quality_score = quality_score + 50
    elseif perfect_percentage >= 50 then
        quality_score = quality_score + 30
    elseif catch_percentage >= 70 then
        quality_score = quality_score + 10
    else
        quality_score = quality_score - 20
    end

    local time_bonus = math.max(0, 80 - minigame_state.total_time)
    quality_score = quality_score + time_bonus
    quality_score = quality_score - (minigame_state.touches * 15)

    local final_fish = minigame.determine_final_fish(quality_score)
    local result = build_minigame_result({
        success = true,
        fish_name = final_fish,
        perfect_catch = minigame_state.perfect_catch,
        quality_score = quality_score
    })

    end_minigame()
    return result
end

function minigame.fail_fishing()
    local result = build_minigame_result({
        success = false,
        fish_name = "None",
        perfect_catch = false,
        quality_score = 0
    })
    end_minigame()
    return result
end

function minigame.cancel_fishing()
    if not minigame_state.is_active then
        return nil
    end

    local result = build_minigame_result({
        success = false,
        fish_name = "None",
        perfect_catch = false,
        quality_score = 0,
        cancelled = true
    })
    end_minigame()
    return result
end

function minigame.combat_interrupt()
    if not minigame_state.is_active then
        return nil
    end

    local result = build_minigame_result({
        success = false,
        fish_name = "None",
        perfect_catch = false,
        quality_score = 0,
        combat_interrupt = true
    })
    end_minigame()
    return result
end

function minigame.is_active()
    return minigame_state.is_active
end

function minigame.get_state()
    return minigame_state
end

function minigame.draw()
    if not minigame_state.is_active then
        return
    end

    local screen_width = size.CANVAS_WIDTH
    local screen_height = size.CANVAS_HEIGHT
    local bar_x = (screen_width - BAR_WIDTH) / 2
    local bar_y = (screen_height - BAR_HEIGHT) / 2

    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", bar_x - 30, bar_y - 20, BAR_WIDTH + 60, BAR_HEIGHT + 40)

    local water_color = minigame_state.water_color or {0.1, 0.3, 0.6}
    for i = 0, BAR_HEIGHT - 1 do
        local progress = i / BAR_HEIGHT
        local darken_factor = 0.7 + (progress * 0.3)
        love.graphics.setColor(water_color[1] * darken_factor, water_color[2] * darken_factor, water_color[3] * darken_factor, 1)
        love.graphics.rectangle("fill", bar_x, bar_y + i, BAR_WIDTH, 1)
    end

    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.setLineWidth(2)
    for i = 1, BAR_LEVELS - 1 do
        local y = bar_y + i * LEVEL_HEIGHT
        love.graphics.line(bar_x, y, bar_x + BAR_WIDTH, y)
    end

    love.graphics.setColor(1, 1, 1, 0.7)
    for i = 1, BAR_LEVELS do
        local y = bar_y + (i - 1) * LEVEL_HEIGHT + LEVEL_HEIGHT / 2
        local level_text = "Level " .. i
        local text_width = love.graphics.getFont():getWidth(level_text)
        love.graphics.print(level_text, bar_x - text_width - 15, y - 10)

        local difficulty_text = string.format("x%.1f", 1 + (i - 1) * 0.5)
        love.graphics.print(difficulty_text, bar_x + BAR_WIDTH + 15, y - 10)
    end

    local fish_x = bar_x + BAR_WIDTH / 2
    local fish_y = bar_y + minigame_state.fish_position

    love.graphics.setColor(1, 0, 0, 0.1)
    love.graphics.circle("fill", fish_x, fish_y, CATCH_RANGE)
    love.graphics.setColor(1, 0, 0, 0.3)
    love.graphics.circle("line", fish_x, fish_y, CATCH_RANGE)

    love.graphics.setColor(0, 1, 0, 0.25)
    love.graphics.circle("fill", fish_x, fish_y, 5)
    love.graphics.setColor(0, 1, 0, 0.6)
    love.graphics.circle("line", fish_x, fish_y, 5)

    local icon_scale = 0.8
    love.graphics.push()
    love.graphics.stencil(function()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(fish_icon, fish_x, fish_y, 0, icon_scale, icon_scale, fish_icon_width / 2, fish_icon_height / 2)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(0, 1, 0, 0.4)
    love.graphics.circle("fill", fish_x, fish_y, 5)
    love.graphics.setStencilTest()
    love.graphics.pop()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(fish_icon, fish_x, fish_y, 0, icon_scale, icon_scale, fish_icon_width / 2, fish_icon_height / 2)

    local rod_x = bar_x + BAR_WIDTH / 2
    local rod_y = bar_y + minigame_state.rod_position

    love.graphics.setColor(0.8, 0.8, 0.8, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.line(bar_x + BAR_WIDTH / 2, bar_y, rod_x, rod_y)

    local distance_to_fish = math.abs(minigame_state.rod_position - minigame_state.fish_position)
    local is_near_fish = distance_to_fish <= CATCH_RANGE

    love.graphics.setColor(is_near_fish and 0 or 1, 1, is_near_fish and 0 or 1, 1)
    love.graphics.circle("fill", rod_x, rod_y, 8)
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.circle("fill", rod_x, rod_y, 5)

    if is_near_fish then
        if distance_to_fish <= 5 then
            love.graphics.setColor(0, 1, 0, 0.6)
        else
            love.graphics.setColor(1, 0, 0, 0.4)
        end
        love.graphics.circle("line", rod_x, rod_y, 8)
    end

    local mouse_x, mouse_y = love.mouse.getPosition()
    local movement_intensity = math.min(math.sqrt((mouse_x - minigame_state.last_mouse_x)^2 + (mouse_y - minigame_state.last_mouse_y)^2) / 50, 1.0)
    if movement_intensity > 0.1 then
        love.graphics.setColor(1, 1, 0, movement_intensity * 0.5)
        love.graphics.circle("line", rod_x, rod_y, 12 + movement_intensity * 8)
    end

    local progress_x = bar_x - 40
    local progress_y = bar_y
    local progress_width = 20
    local progress_height = BAR_HEIGHT

    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", progress_x, progress_y, progress_width, progress_height)

    love.graphics.setColor(0, 1, 0, 1)
    local filled_height = progress_height * minigame_state.catch_progress
    love.graphics.rectangle("fill", progress_x, progress_y + progress_height - filled_height, progress_width, filled_height)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", progress_x, progress_y, progress_width, progress_height)

    local instruction_text = "Move mouse in circles to control rod (faster movement = more force)"
    local text_width = love.graphics.getFont():getWidth(instruction_text)
    love.graphics.print(instruction_text, (screen_width - text_width) / 2, bar_y + BAR_HEIGHT + 30)

    local fish_text = "Fish: " .. minigame_state.fish_name
    love.graphics.print(fish_text, (screen_width - love.graphics.getFont():getWidth(fish_text)) / 2, bar_y - 50)

    local time_text = string.format("Time: %.1fs", minigame_state.total_time)
    love.graphics.print(time_text, (screen_width - love.graphics.getFont():getWidth(time_text)) / 2, bar_y - 30)

    love.graphics.setColor(1, 1, 1, 0.8)
    local fish_list_x = bar_x + BAR_WIDTH + 40
    love.graphics.print("Potential Catches:", fish_list_x, bar_y)
    for i, fish_name in ipairs(minigame_state.available_fish) do
        love.graphics.print("- " .. fish_name, fish_list_x, bar_y + 20 * i)
    end

    local progress_text = string.format("Catch: %.0f%%", minigame_state.catch_progress * 100)
    love.graphics.print(progress_text, (screen_width - love.graphics.getFont():getWidth(progress_text)) / 2, bar_y + BAR_HEIGHT + 10)

    local touches_text = "Touches: " .. minigame_state.touches
    love.graphics.print(touches_text, (screen_width - love.graphics.getFont():getWidth(touches_text)) / 2, bar_y + BAR_HEIGHT + 50)

    local center_x = size.CANVAS_WIDTH / 2
    local center_y = size.CANVAS_HEIGHT / 2
    local dx = mouse_x - center_x
    local dy = mouse_y - center_y
    local mouse_movement = math.sqrt((mouse_x - minigame_state.last_mouse_x)^2 + (mouse_y - minigame_state.last_mouse_y)^2)

    local debug_y = bar_y + BAR_HEIGHT + 90
    local debug_x = (screen_width - 200) / 2

    love.graphics.print("Mouse: (" .. math.floor(dx) .. ", " .. math.floor(dy) .. ")", debug_x, debug_y)
    love.graphics.print("Movement: " .. string.format("%.1f", mouse_movement), debug_x, debug_y + 20)
    love.graphics.print("Force: " .. string.format("%.1f", minigame_state.rod_velocity), debug_x, debug_y + 40)
    love.graphics.print("Catch Range: " .. CATCH_RANGE, debug_x, debug_y + 60)
    love.graphics.print("Perfect: " .. string.format("%.1f", minigame_state.time_in_perfect) .. "s", debug_x, debug_y + 80)
    love.graphics.print("Catch: " .. string.format("%.1f", minigame_state.time_in_catch) .. "s", debug_x, debug_y + 100)

    local escape_text = "Press ESC to cancel fishing"
    love.graphics.print(escape_text, (screen_width - love.graphics.getFont():getWidth(escape_text)) / 2, bar_y + BAR_HEIGHT + 70)
end

function fishing.create_runtime(deps)
    local runtime_state = {
        catch_texts = {},
        fishing_pressed = false,
        fishing_cooldown = 0,
        last_cooldown = deps.game_config.fishing_cooldown,
        player_just_failed_fishing = false
    }

    local runtime = {}

    local function reset_runtime_state()
        for i = #runtime_state.catch_texts, 1, -1 do
            runtime_state.catch_texts[i] = nil
        end
        runtime_state.fishing_pressed = false
        runtime_state.fishing_cooldown = 0
        runtime_state.last_cooldown = deps.game_config.fishing_cooldown
        runtime_state.player_just_failed_fishing = false
    end

    local function get_roll_context()
        local fish_available = fishing.get_fish_avalible(deps.player_ship.x, deps.player_ship.y, deps.player_ship.time_system.time)
        return {
            fish_available = fish_available,
            rod_rarity = fishing.get_rod_rarity(deps.player_ship.rod),
            top_rarity = fishing.get_rod_top_rarity(),
            depth_level = standardize_depth(deps.player_ship.y)
        }
    end

    local function add_catch_text(text)
        table.insert(runtime_state.catch_texts, 1, {
            text = text,
            time = deps.game_config.fishing_cooldown,
            y_offset = 0
        })

        if #runtime_state.catch_texts > deps.get_max_catch_texts() then
            table.remove(runtime_state.catch_texts)
        end

        update_catch_text_offsets(runtime_state.catch_texts, deps.game_config.catch_text_spacing)
    end

    local function crew_auto_fish()
        local ctx = get_roll_context()
        deps.trigger_ship_animation()

        for i = 1, deps.player_ship.men do
            local fish_caught = fishing.fish(ctx.rod_rarity, ctx.top_rarity, ctx.fish_available, deps.player_ship.y)
            if fishing.is_special_fish(fish_caught) then
                deps.trigger_special_fish_event(fish_caught)
            else
                add_catch_text("Crew " .. i .. ": " .. fish_caught)
                table.insert(deps.player_ship.caught_fish, fish_caught)
            end
        end
    end

    function runtime.reset_state()
        reset_runtime_state()
    end

    function runtime.add_catch_text(text)
        add_catch_text(text)
    end

    function runtime.update_catch_texts(dt)
        for i = #runtime_state.catch_texts, 1, -1 do
            local catch = runtime_state.catch_texts[i]
            if not deps.special_fish_event.active then
                catch.time = catch.time - dt
            end
            if catch.time <= 0 then
                table.remove(runtime_state.catch_texts, i)
                update_catch_text_offsets(runtime_state.catch_texts, deps.game_config.catch_text_spacing)
            end
        end
    end

    function runtime.fish(dt)
        local fishing_down = love.keyboard.isDown("f") or deps.mobile_controls.buttons.fish.pressed
        local fishing_released = fishing_down and not runtime_state.fishing_pressed
        runtime_state.fishing_pressed = fishing_down

        local prev_cooldown = runtime_state.fishing_cooldown
        runtime_state.fishing_cooldown = math.max(0, runtime_state.fishing_cooldown - dt)

        local blocked_by_shop_line = deps.is_on_shop_line(deps.player_ship.y)
        if prev_cooldown > 0 and runtime_state.fishing_cooldown <= 0 then
            if blocked_by_shop_line then
                print("Crew cannot fish on shop lines.")
            elseif not runtime_state.player_just_failed_fishing then
                crew_auto_fish()
            else
                runtime_state.player_just_failed_fishing = false
                print("Crew did not fish because player failed.")
            end
        end

        if fishing_released and runtime_state.fishing_cooldown <= 0 and deps.gamestate.get() == deps.GameType.VOYAGE then
            if blocked_by_shop_line then
                print("You can't fish on shop lines.")
                return
            end

            local ctx = get_roll_context()
            deps.fishing_minigame.start_fishing(
                ctx.fish_available,
                ctx.rod_rarity,
                ctx.depth_level,
                deps.get_current_water_color()
            )
            deps.gamestate.set(deps.GameType.FISHING)
        end
    end

    function runtime.get_catch_texts()
        return runtime_state.catch_texts
    end

    function runtime.get_fishing_cooldown()
        return runtime_state.fishing_cooldown
    end

    function runtime.set_fishing_cooldown(value)
        runtime_state.fishing_cooldown = value
    end

    function runtime.get_last_cooldown()
        return runtime_state.last_cooldown
    end

    function runtime.set_last_cooldown(value)
        runtime_state.last_cooldown = value
    end

    function runtime.set_player_just_failed_fishing(value)
        runtime_state.player_just_failed_fishing = value
    end

    return runtime
end

fishing.minigame = minigame

return fishing
