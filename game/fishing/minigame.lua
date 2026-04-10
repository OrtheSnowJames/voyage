local minigame_module = {}
local extra_math = require("game.extra_math")
local top = require("game.top")
local constants = require("game.constants")

function minigame_module.create(deps)
    local fishing = deps.fishing
    local size = deps.size

    local MINIGAME_CONFIG = constants.fish.minigame or {}
    local FISH_ICON_WIDTH = constants.fish.fish_icon_width or 64
    local FISH_ICON_HEIGHT = constants.fish.fish_icon_height or 64

    local fish_icon = love.graphics.newImage("assets/fish-icon.png")
    local fish_icon_width = FISH_ICON_WIDTH
    local fish_icon_height = FISH_ICON_HEIGHT

    local BAR_WIDTH = MINIGAME_CONFIG.bar_width or 60
    local BAR_HEIGHT = MINIGAME_CONFIG.bar_height or 300
    local BAR_LEVELS = MINIGAME_CONFIG.bar_levels or 4
    local LEVEL_HEIGHT = BAR_HEIGHT / BAR_LEVELS

    local GRAVITY = MINIGAME_CONFIG.gravity or 200
    local ROD_SPEED = MINIGAME_CONFIG.rod_speed or 300
    local CATCH_TIME = MINIGAME_CONFIG.catch_time or 5.0
    local CATCH_RANGE = MINIGAME_CONFIG.catch_range or 40
    local PROGRESS_START = MINIGAME_CONFIG.progress_start or 0.5
    local PERFECT_ALIGNMENT_BONUS = MINIGAME_CONFIG.perfect_alignment_bonus or 0.3
    local PERFECT_HOLD_FOREVER_BONUS = MINIGAME_CONFIG.perfect_hold_forever_bonus or 60
    local NIGHT_FISH_CATCH_DENOMINATOR = MINIGAME_CONFIG.night_fish_catch_denominator or 90

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
        time_outside_catch = 0,
        scoring_time = 0,
        entered_catch_circle = false,
        touched_center_after_entry = false,
        time_outside_center_after_entry = 0,
        held_middle_forever = true
    }

    local minigame = {}

    local function pick_for_quality(pool, quality_score)
        if quality_score >= 180 then
            return pool[#pool]
        elseif quality_score >= 130 then
            local current_index = math.random(1, #pool)
            return pool[math.min(current_index + 1, #pool)]
        elseif quality_score >= 100 then
            local upper_half = math.ceil(#pool / 2)
            return pool[math.random(upper_half, #pool)]
        elseif quality_score >= 60 then
            return pool[1] -- worst fish
        elseif quality_score >= 30 then
            -- return pool[math.random(1, math.max(1, math.floor(#pool / 2)))]
            return pool[1]
        else
            return "Bluegill"
            -- return pool[math.max(1, math.floor(#pool / 3))]
        end
    end

    local function maybe_demote_night_fish(candidate, fish_pool, quality_score)
        if fishing.is_night_fish(candidate) and math.random(1, NIGHT_FISH_CATCH_DENOMINATOR) ~= 1 then
            local non_night = {}
            for _, fish_name in ipairs(fish_pool) do
                if not fishing.is_night_fish(fish_name) then
                    table.insert(non_night, fish_name)
                end
            end
            if #non_night > 0 then
                return pick_for_quality(non_night, quality_score)
            end
        end

        return candidate
    end

    local function pick_top_non_night(fish_pool)
        for i = #fish_pool, 1, -1 do
            local fish_name = fish_pool[i]
            if not fishing.is_night_fish(fish_name) then
                return fish_name
            end
        end
        return nil
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

    local function calculate_quality_score()
        local quality_score = 0
        if minigame_state.perfect_catch then
            quality_score = quality_score + 10
        end

        local scoring_time = math.max(0.0001, minigame_state.scoring_time)
        local perfect_percentage = (minigame_state.time_in_perfect / scoring_time) * 100
        local catch_percentage = (minigame_state.time_in_catch / scoring_time) * 100

        if perfect_percentage >= 80 then
            quality_score = quality_score + 50
        elseif perfect_percentage >= 50 then
            quality_score = quality_score + 30
        elseif catch_percentage >= 70 then
            quality_score = quality_score + 10
        else
            quality_score = quality_score - 20
        end

        local time_bonus = math.max(0, 80 - minigame_state.scoring_time)
        quality_score = quality_score + time_bonus
        quality_score = quality_score - (minigame_state.touches * 15)

        if minigame_state.entered_catch_circle
            and minigame_state.touched_center_after_entry
            and minigame_state.held_middle_forever then
            quality_score = quality_score + PERFECT_HOLD_FOREVER_BONUS
            print("held forever!")
        end

        return quality_score
    end

    local function build_failed_minigame_result(flags)
        local extra_flags = flags or {}
        return build_minigame_result({
            success = false,
            fish_name = "None",
            perfect_catch = false,
            quality_score = 0,
            cancelled = extra_flags.cancelled,
            combat_interrupt = extra_flags.combat_interrupt
        })
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
        minigame_state.scoring_time = 0
        minigame_state.entered_catch_circle = false
        minigame_state.touched_center_after_entry = false
        minigame_state.time_outside_center_after_entry = 0
        minigame_state.held_middle_forever = true
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
        minigame_state.mouse_angle = extra_math.atan2(dy, dx)
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
        local is_in_middle = distance_to_fish <= 5

        if is_near_fish and not minigame_state.entered_catch_circle then
            minigame_state.entered_catch_circle = true
        end

        if minigame_state.entered_catch_circle and not minigame_state.touched_center_after_entry and not is_in_middle then
            minigame_state.time_outside_center_after_entry = minigame_state.time_outside_center_after_entry + dt
            if minigame_state.time_outside_center_after_entry > 2.0 then
                minigame_state.held_middle_forever = false
            end
        end

        if minigame_state.entered_catch_circle
            and not minigame_state.touched_center_after_entry
            and is_in_middle then
            minigame_state.touched_center_after_entry = true
        end

        if minigame_state.touched_center_after_entry and not is_in_middle then
            minigame_state.held_middle_forever = false
        end

        if is_near_fish then
            minigame_state.scoring_time = minigame_state.scoring_time + dt
            local accuracy_multiplier = 1.0

            if is_in_middle then
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
            local top_non_night = pick_top_non_night(available_fish)
            if top_non_night then
                return top_non_night
            end
        end

        local candidate = pick_for_quality(available_fish, quality_score)
        return maybe_demote_night_fish(candidate, available_fish, quality_score)
    end

    function minigame.complete_fishing()
        local quality_score = calculate_quality_score()
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
        local result = build_failed_minigame_result()
        end_minigame()
        return result
    end

    function minigame.cancel_fishing()
        if not minigame_state.is_active then
            return nil
        end

        local result = build_failed_minigame_result({cancelled = true})
        end_minigame()
        return result
    end

    function minigame.combat_interrupt()
        if not minigame_state.is_active then
            return nil
        end

        local result = build_failed_minigame_result({combat_interrupt = true})
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
        local panel_width = math.min(screen_width - 80, 560)
        local panel_height = BAR_HEIGHT + 120
        local panel_x = (screen_width - panel_width) / 2
        local panel_y = (screen_height - panel_height) / 2
        local panel_radius = 12

        local top_height = top.get_height(love.graphics.getHeight())
        if panel_y <= top_height then
            panel_y = top_height + constants.fish.minigame.margin_from_top
        end

        local progress_width = 24
        local progress_padding = 20
        local bar_x = panel_x + progress_padding + progress_width + 16
        local bar_y = panel_y + 70

        local info_panel_x = bar_x + BAR_WIDTH + 20
        local info_panel_w = panel_x + panel_width - info_panel_x - 16
        local info_panel_y = bar_y
        local info_panel_h = BAR_HEIGHT

        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.rectangle("fill", 0, 0, screen_width, screen_height)

        love.graphics.setColor(0.06, 0.08, 0.1, 0.92)
        love.graphics.rectangle("fill", panel_x, panel_y, panel_width, panel_height, panel_radius, panel_radius)
        love.graphics.setColor(0.2, 0.28, 0.32, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", panel_x, panel_y, panel_width, panel_height, panel_radius, panel_radius)

        local fish_text = "Fish: " .. minigame_state.fish_name
        local instruction_text = "Circle mouse to steer the hook"
        local header_y = panel_y + 14
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(fish_text, panel_x + 16, header_y)
        love.graphics.setColor(0.78, 0.86, 0.9, 1)
        love.graphics.print(instruction_text, panel_x + 16, header_y + 20)

        local time_text = string.format("Time %.1fs", minigame_state.total_time)
        local touches_text = string.format("Walls %d", minigame_state.touches)
        local right_header_x = panel_x + panel_width - 16
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.print(time_text, right_header_x - love.graphics.getFont():getWidth(time_text), header_y)
        love.graphics.setColor(0.9, 0.9, 0.95, 0.9)
        love.graphics.print(touches_text, right_header_x - love.graphics.getFont():getWidth(touches_text), header_y + 20)

        love.graphics.setColor(0.12, 0.14, 0.17, 0.9)
        love.graphics.rectangle("fill", progress_padding + panel_x, bar_y, progress_width, BAR_HEIGHT, 6, 6)
        local filled_height = BAR_HEIGHT * minigame_state.catch_progress
        local progress_color = {0.08, 0.8, 0.42}
        if minigame_state.catch_progress < 0.3 then
            progress_color = {0.9, 0.35, 0.3}
        elseif minigame_state.catch_progress < 0.6 then
            progress_color = {0.95, 0.75, 0.2}
        end
        love.graphics.setColor(progress_color[1], progress_color[2], progress_color[3], 1)
        love.graphics.rectangle("fill", progress_padding + panel_x, bar_y + BAR_HEIGHT - filled_height, progress_width, filled_height, 6, 6)
        love.graphics.setColor(0.85, 0.9, 0.95, 0.7)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", progress_padding + panel_x, bar_y, progress_width, BAR_HEIGHT, 6, 6)

        local water_color = minigame_state.water_color or {0.1, 0.3, 0.6}
        for i = 0, BAR_HEIGHT - 1 do
            local progress = i / BAR_HEIGHT
            local darken_factor = 0.66 + (progress * 0.34)
            love.graphics.setColor(water_color[1] * darken_factor, water_color[2] * darken_factor, water_color[3] * darken_factor, 1)
            love.graphics.rectangle("fill", bar_x, bar_y + i, BAR_WIDTH, 1)
        end

        love.graphics.setColor(0.9, 0.95, 1, 0.2)
        love.graphics.setLineWidth(1)
        for i = 1, BAR_LEVELS - 1 do
            local y = bar_y + i * LEVEL_HEIGHT
            love.graphics.line(bar_x, y, bar_x + BAR_WIDTH, y)
        end

        love.graphics.setColor(0.85, 0.9, 0.95, 0.7)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", bar_x, bar_y, BAR_WIDTH, BAR_HEIGHT, 8, 8)

        local fish_x = bar_x + BAR_WIDTH / 2
        local fish_y = bar_y + minigame_state.fish_position
        love.graphics.setColor(1, 0.28, 0.28, 0.12)
        love.graphics.circle("fill", fish_x, fish_y, CATCH_RANGE)
        love.graphics.setColor(1, 0.45, 0.45, 0.45)
        love.graphics.circle("line", fish_x, fish_y, CATCH_RANGE)
        love.graphics.setColor(0.3, 1, 0.6, 0.65)
        love.graphics.circle("fill", fish_x, fish_y, 5)

        local icon_scale = 0.8
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(fish_icon, fish_x, fish_y, 0, icon_scale, icon_scale, fish_icon_width / 2, fish_icon_height / 2)

        local rod_x = bar_x + BAR_WIDTH / 2
        local rod_y = bar_y + minigame_state.rod_position
        local distance_to_fish = math.abs(minigame_state.rod_position - minigame_state.fish_position)
        local is_near_fish = distance_to_fish <= CATCH_RANGE
        local is_centered = distance_to_fish <= 5

        love.graphics.setColor(0.85, 0.9, 0.95, 0.75)
        love.graphics.setLineWidth(2)
        love.graphics.line(bar_x + BAR_WIDTH / 2, bar_y, rod_x, rod_y)

        love.graphics.setColor(0.1, 0.9, 0.45, 1)
        love.graphics.circle("fill", rod_x, rod_y, 8)
        love.graphics.setColor(0.95, 0.2, 0.25, 1)
        love.graphics.circle("fill", rod_x, rod_y, 5)

        if is_near_fish then
            if is_centered then
                love.graphics.setColor(0.3, 1, 0.5, 0.8)
            else
                love.graphics.setColor(1, 0.45, 0.3, 0.8)
            end
            love.graphics.circle("line", rod_x, rod_y, 11)
        end

        local progress_text = string.format("Catch %d%%", math.floor(minigame_state.catch_progress * 100 + 0.5))
        local status_text = is_centered and "Centered" or (is_near_fish and "In Range" or "Out Of Range")
        local status_color = is_centered and {0.35, 1, 0.5} or (is_near_fish and {1, 0.8, 0.35} or {1, 0.45, 0.45})
        local hold_ready = minigame_state.entered_catch_circle
            and minigame_state.touched_center_after_entry
            and minigame_state.held_middle_forever
        local hold_text = hold_ready and "Hold Bonus" or "No Hold Bonus"
        local hold_color = hold_ready and {0.35, 1, 0.5} or {1, 0.45, 0.45}

        love.graphics.setColor(0.11, 0.13, 0.16, 0.9)
        love.graphics.rectangle("fill", info_panel_x, info_panel_y, info_panel_w, info_panel_h, 10, 10)
        love.graphics.setColor(0.24, 0.31, 0.36, 1)
        love.graphics.rectangle("line", info_panel_x, info_panel_y, info_panel_w, info_panel_h, 10, 10)

        local info_x = info_panel_x + 12
        local line_y = info_panel_y + 12
        love.graphics.setColor(0.95, 0.97, 1, 1)
        love.graphics.print(progress_text, info_x, line_y)
        line_y = line_y + 22

        love.graphics.setColor(status_color[1], status_color[2], status_color[3], 1)
        love.graphics.print(status_text, info_x, line_y)
        line_y = line_y + 22

        love.graphics.setColor(hold_color[1], hold_color[2], hold_color[3], 1)
        love.graphics.print(hold_text, info_x, line_y)
        line_y = line_y + 30

        love.graphics.setColor(0.85, 0.9, 0.95, 0.95)
        love.graphics.print("Potential Catches", info_x, line_y)
        line_y = line_y + 20

        local max_list_rows = 9
        for i, fish_name in ipairs(minigame_state.available_fish) do
            if i > max_list_rows then
                love.graphics.setColor(0.7, 0.76, 0.82, 1)
                love.graphics.print("...", info_x, line_y)
                break
            end
            love.graphics.setColor(0.9, 0.94, 0.97, 0.95)
            love.graphics.print("- " .. fish_name, info_x, line_y)
            line_y = line_y + 18
        end

        local footer_text = "ESC to cancel"
        love.graphics.setColor(0.8, 0.86, 0.92, 0.9)
        love.graphics.print(footer_text, panel_x + panel_width - 16 - love.graphics.getFont():getWidth(footer_text), panel_y + panel_height - 28)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, 1)
    end

    return minigame
end

return minigame_module
