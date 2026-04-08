local top = {}

local height_ratio = 100/600
local start_x = 0
local start_y = 0
local wave_icon = nil
local wave_icon_load_attempted = false
local food_icon = nil
local food_icon_load_attempted = false
local top_font = nil
local top_font_load_attempted = false

local constants = require("game.constants")

local function get_radius(radius_fn, role, default_radius, angle)
    if type(radius_fn) == "function" then
        local value = radius_fn(role, default_radius, angle)
        if type(value) == "number" and value > 0 then
            return value
        end
    elseif type(radius_fn) == "number" and role == "face" then
        return radius_fn
    end
    return default_radius
end

-- Draw an analog clock.
-- cx, cy: center position in screen pixels.
-- time_hours: in-game time in 12-hour units (e.g. 3.5 = 3:30).
-- radius_fn: optional function(role, default_radius, angle) -> number.
-- roles: "face", "hour_hand", "minute_hand", "tick".
-- You may also pass a number to radius_fn to override only the face radius.
function top.draw_clock(cx, cy, time_hours, radius_fn)
    local hours = tonumber(time_hours) or 0
    local hour_value = hours % 12
    local minute_value = (hour_value - math.floor(hour_value)) * 60

    local face_radius = get_radius(radius_fn, "face", 18)
    local hour_len = get_radius(radius_fn, "hour_hand", face_radius * 0.52)
    local minute_len = get_radius(radius_fn, "minute_hand", face_radius * 0.78)
    local tick_len = get_radius(radius_fn, "tick", face_radius * 0.12)

    local hour_angle = -math.pi / 2 + ((hour_value / 12) * math.pi * 2)
    local minute_angle = -math.pi / 2 + ((minute_value / 60) * math.pi * 2)

    love.graphics.setColor(0.98, 0.98, 0.98, 0.95)
    love.graphics.circle("fill", cx, cy, face_radius)
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.circle("line", cx, cy, face_radius)

    love.graphics.setColor(0.65, 0.65, 0.65, 0.9)
    for i = 0, 11 do
        local tick_angle = -math.pi / 2 + (i / 12) * math.pi * 2
        local outer_x = cx + math.cos(tick_angle) * (face_radius - 1)
        local outer_y = cy + math.sin(tick_angle) * (face_radius - 1)
        local inner_x = cx + math.cos(tick_angle) * (face_radius - tick_len)
        local inner_y = cy + math.sin(tick_angle) * (face_radius - tick_len)
        love.graphics.line(inner_x, inner_y, outer_x, outer_y)
    end

    love.graphics.setLineWidth(3)
    love.graphics.line(
        cx,
        cy,
        cx + math.cos(hour_angle) * hour_len,
        cy + math.sin(hour_angle) * hour_len
    )
    love.graphics.setLineWidth(2)
    love.graphics.line(
        cx,
        cy,
        cx + math.cos(minute_angle) * minute_len,
        cy + math.sin(minute_angle) * minute_len
    )
    love.graphics.circle("fill", cx, cy, 2)
    love.graphics.setLineWidth(1)
end

local function format_time_string(time_hours)
    local t = tonumber(time_hours) or 0
    local hours = math.floor(t)
    local minutes = math.floor((t - hours) * 60)
    if hours >= 12 then
        hours = 12
        minutes = 0
    end
    return string.format("%02d:%02d", hours, minutes)
end

local function get_wave_icon()
    if wave_icon_load_attempted then
        return wave_icon
    end
    wave_icon_load_attempted = true
    local ok, img = pcall(love.graphics.newImage, "assets/wave.png")
    if ok and img then
        wave_icon = img
    else
        wave_icon = nil
    end
    return wave_icon
end

local function get_food_icon()
    if food_icon_load_attempted then
        return food_icon
    end
    food_icon_load_attempted = true
    local ok_data, img_data = pcall(love.image.newImageData, "assets/salmon.jpg")
    if not ok_data or not img_data then
        food_icon = nil
        return food_icon
    end

    local w, h = img_data:getDimensions()
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local r, g, b, a = img_data:getPixel(x, y)
            if r > 0.93 and g > 0.93 and b > 0.93 then
                img_data:setPixel(x, y, r, g, b, 0)
            else
                img_data:setPixel(x, y, r, g, b, a)
            end
        end
    end

    local ok_img, img = pcall(love.graphics.newImage, img_data)
    if ok_img and img then
        food_icon = img
    else
        food_icon = nil
    end

    return food_icon
end

local function get_top_font()
    if top_font_load_attempted then
        return top_font
    end
    top_font_load_attempted = true
    local ok, font = pcall(love.graphics.newFont, "assets/PixelifySans-SemiBold.ttf", 28)
    if ok and font then
        top_font = font
    else
        top_font = nil
    end
    return top_font
end

function top.get_height(canvas_height)
    local h = tonumber(canvas_height) or love.graphics.getHeight()
    return h * height_ratio
end

function top.draw(state)
    local previous_font = love.graphics.getFont()
    local custom_font = get_top_font()
    if custom_font then
        love.graphics.setFont(custom_font)
    end

    local width = love.graphics.getWidth()
    local height = top.get_height(love.graphics.getHeight())

    love.graphics.setColor(0.851, 0.851, 0.851, 0.5)
    love.graphics.rectangle("fill", start_x, start_y, width, height)

    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.line(start_x, height, width, height)

    local dv = width / 3
    for i = 1, width / dv do
        local dw = dv * i
        love.graphics.line(dw, start_y, dw, height)
    end

    local time_hours = 0
    if state and state.system.player and state.system.player.time_system then
        local ts = state.system.player.time_system
        local day_length = tonumber(ts.DAY_LENGTH) or 1
        local current_time = tonumber(ts.time) or 0
        time_hours = (current_time / day_length) * 12
    end

    local section_left = start_x
    local clock_x = section_left + 34
    local clock_y = height / 2
    top.draw_clock(clock_x, clock_y, time_hours, function(role, default_radius)
        if role == "face" then
            return 20
        end
        if role == "tick" then
            return 5
        end
        return default_radius
    end)

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.print(
        format_time_string(time_hours),
        section_left + dv / 2,
        (height - love.graphics.getFont():getHeight()) / 2
    )

    local fishing_level_value = 0
    if state and state.system.player and state.constants and state.constants.fishing_level then
        fishing_level_value = math.floor((state.system.player.y or 0) / state.constants.fishing_level)
    end

    local second_section_left = start_x + dv
    local icon = get_wave_icon()
    local icon_x = second_section_left + 28
    local icon_y = height / 2

    if icon then
        local target_size = 30
        local icon_scale = target_size / icon:getWidth()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            icon,
            icon_x,
            icon_y,
            0,
            icon_scale,
            icon_scale,
            icon:getWidth() / 2,
            icon:getHeight() / 2
        )
    end

    if state.system.spawnenemy.is_dangerous_area(fishing_level_value * 1000 + constants.combat.dangerous_area_buffer + 1) then
        love.graphics.setColor(0.859,  0.016, 0.000)
    else
        love.graphics.setColor(0.0, 0.0, 0.0)
    end
    love.graphics.print(
        string.format("Lv %d", fishing_level_value),
        second_section_left + dv / 2,
        (height - love.graphics.getFont():getHeight()) / 2
    )
    love.graphics.setColor(0, 0, 0, 1)

    local lowest_hunger = 0
    if state and state.system.player and type(state.system.player.hunger_levels) == "table" and #state.system.player.hunger_levels > 0 then
        lowest_hunger = tonumber(state.system.player.hunger_levels[1]) or 0
        for i = 2, #state.system.player.hunger_levels do
            local v = tonumber(state.system.player.hunger_levels[i]) or 0
            if v < lowest_hunger then
                lowest_hunger = v
            end
        end
    end

    local third_section_left = start_x + (dv * 2)
    local food = get_food_icon()
    local food_x = third_section_left + 34
    local food_y = height / 2

    if food then
        local target_size = 75
        local food_scale = target_size / food:getWidth()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            food,
            food_x,
            food_y,
            0,
            food_scale,
            food_scale,
            food:getWidth() / 2,
            food:getHeight() / 2
        )
    end

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.print(
        string.format("%d%%", math.floor(lowest_hunger + 0.5)),
        third_section_left + dv / 2,
        (height - love.graphics.getFont():getHeight()) / 2
    )

    if previous_font then
        love.graphics.setFont(previous_font)
    end
end

return top
