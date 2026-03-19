local visuals = {}

local function lerp(a, b, t)
    return a + (b - a) * t
end

local water_colors = {
    dawn  = {0.15, 0.2, 0.35},
    day   = {0.05, 0.1, 0.3},
    dusk  = {0.12, 0.08, 0.25},
    night = {0.01, 0.02, 0.08}
}

function visuals.get_current_water_color(player_ship)
    local time_of_day = (player_ship.time_system.time / player_ship.time_system.DAY_LENGTH) * 12
    local base_color

    if time_of_day >= 0 and time_of_day < 1 then
        local t = time_of_day
        base_color = {
            lerp(water_colors.dawn[1], water_colors.dawn[1], t),
            lerp(water_colors.dawn[2], water_colors.dawn[2], t),
            lerp(water_colors.dawn[3], water_colors.dawn[3], t)
        }
    elseif time_of_day >= 1 and time_of_day < 6 then
        local t = (time_of_day - 1) / 5
        base_color = {
            lerp(water_colors.dawn[1], water_colors.day[1], t),
            lerp(water_colors.dawn[2], water_colors.day[2], t),
            lerp(water_colors.dawn[3], water_colors.day[3], t)
        }
    elseif time_of_day >= 6 and time_of_day < 11 then
        base_color = water_colors.day
    elseif time_of_day >= 11 and time_of_day < 12 then
        local t = (time_of_day - 11)
        base_color = {
            lerp(water_colors.day[1], water_colors.dusk[1], t),
            lerp(water_colors.day[2], water_colors.dusk[2], t),
            lerp(water_colors.day[3], water_colors.dusk[3], t)
        }
    else
        base_color = water_colors.night
    end

    local rainbows_level = math.max(0, tonumber(player_ship.rainbows) or 0)
    if rainbows_level >= 0.1 then
        local darkness_t = math.min(1, math.max(0, (rainbows_level - 0.1) / 0.3))
        local blend_to_black = math.min(0.985, 0.45 + darkness_t * 0.53)
        local near_black = {0.0, 0.0, 0.01}

        return {
            lerp(base_color[1], near_black[1], blend_to_black),
            lerp(base_color[2], near_black[2], blend_to_black),
            lerp(base_color[3], near_black[3], blend_to_black)
        }
    end

    return base_color
end

function visuals.get_ambient_light(player_ship)
    local time_of_day = (player_ship.time_system.time / player_ship.time_system.DAY_LENGTH) * 12

    if time_of_day >= 0 and time_of_day < 2 then
        return 0.3 + (time_of_day / 2) * 0.4
    elseif time_of_day >= 2 and time_of_day < 10 then
        return 1.0
    elseif time_of_day >= 10 and time_of_day < 12 then
        return 1.0 - ((time_of_day - 10) / 2) * 0.7
    else
        return 0.3
    end
end

function visuals.draw_ship_glow(x, y, radius, color, intensity)
    local glow_radius = radius * 2.5
    local segments = 20

    for i = 1, 3 do
        local current_radius = glow_radius * (1 - i * 0.2)
        local alpha = (intensity * 0.1) / i
        love.graphics.setColor(color[1], color[2], color[3], alpha)
        love.graphics.circle("fill", x, y, current_radius, segments)
    end
end

return visuals
