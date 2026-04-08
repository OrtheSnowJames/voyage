local alert = {}

local current_text = ""
local current_timer = 0
local current_duration = 0
local current_color = {1, 0.3, 0.3, 1}
local title_text = ""
local title_timer = 0
local title_duration = 0
local title_color = {1, 1, 1, 1}
local title_fade_in = 0.25
local title_fade_out = 0.35
local title_scale = 3.0
local title_alpha_multiplier = 1

function alert.show(text, duration, color)
    if not text or text == "" then
        return
    end

    current_text = text
    current_duration = tonumber(duration) or 2
    current_timer = current_duration

    if color and #color >= 4 then
        current_color = {color[1], color[2], color[3], color[4]}
    elseif color and #color >= 3 then
        current_color = {color[1], color[2], color[3], 1}
    else
        current_color = {1, 0.3, 0.3, 1}
    end
end

function alert.title(text, duration, color, fade_in, fade_out)
    if not text or text == "" then
        return
    end

    title_text = text
    title_duration = math.max(0.01, tonumber(duration) or 2.2)
    title_timer = title_duration
    title_fade_in = math.max(0, tonumber(fade_in) or 0.25)
    title_fade_out = math.max(0, tonumber(fade_out) or 0.35)

    if color and #color >= 4 then
        title_color = {color[1], color[2], color[3], color[4]}
    elseif color and #color >= 3 then
        title_color = {color[1], color[2], color[3], 1}
    else
        title_color = {1, 1, 1, 1}
    end
end

function alert.update(dt)
    if current_timer > 0 then
        current_timer = math.max(0, current_timer - dt)
        if current_timer == 0 then
            current_text = ""
            current_duration = 0
        end
    end

    if title_timer > 0 then
        title_timer = math.max(0, title_timer - dt)
        if title_timer == 0 then
            title_text = ""
            title_duration = 0
        end
    end
end

function alert.draw(size)
    if current_timer > 0 and current_text ~= "" then
        love.graphics.setColor(current_color[1], current_color[2], current_color[3], current_color[4])
        local font = love.graphics.getFont()
        local text_width = font:getWidth(current_text)
        love.graphics.print(current_text, (size.CANVAS_WIDTH - text_width) / 2, 10)
        love.graphics.setColor(1, 1, 1, 1)
    end

    if title_timer > 0 and title_text ~= "" then
        local font = love.graphics.getFont()
        local elapsed = title_duration - title_timer
        local alpha = 1
        if title_fade_in > 0 and elapsed < title_fade_in then
            alpha = elapsed / title_fade_in
        end
        if title_fade_out > 0 and title_timer < title_fade_out then
            alpha = math.min(alpha, title_timer / title_fade_out)
        end
        alpha = math.max(0, math.min(1, alpha))

        local title_w = font:getWidth(title_text) * title_scale
        local title_h = font:getHeight() * title_scale
        local tx = (size.CANVAS_WIDTH - title_w) / 2
        local ty = (size.CANVAS_HEIGHT - title_h) / 2
        local base_a = title_color[4] or 1

        love.graphics.setColor(title_color[1], title_color[2], title_color[3], base_a * alpha * title_alpha_multiplier)
        love.graphics.print(title_text, tx, ty, 0, title_scale, title_scale)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function alert.clear()
    current_text = ""
    current_timer = 0
    current_duration = 0
    title_text = ""
    title_timer = 0
    title_duration = 0
    title_alpha_multiplier = 1
end

function alert.is_title_active()
    return title_timer > 0 and title_text ~= ""
end

function alert.set_title_alpha_multiplier(mult)
    title_alpha_multiplier = math.max(0, math.min(1, tonumber(mult) or 1))
end

return alert
