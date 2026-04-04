local alert = {}

local current_text = ""
local current_timer = 0
local current_duration = 0
local current_color = {1, 0.3, 0.3, 1}

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

function alert.update(dt)
    if current_timer <= 0 then
        return
    end

    current_timer = math.max(0, current_timer - dt)
    if current_timer == 0 then
        current_text = ""
        current_duration = 0
    end
end

function alert.draw(size)
    if current_timer <= 0 or current_text == "" then
        return
    end

    love.graphics.setColor(current_color[1], current_color[2], current_color[3], current_color[4])
    local font = love.graphics.getFont()
    local text_width = font:getWidth(current_text)
    love.graphics.print(current_text, (size.CANVAS_WIDTH - text_width) / 2, 10)
    love.graphics.setColor(1, 1, 1, 1)
end

function alert.clear()
    current_text = ""
    current_timer = 0
    current_duration = 0
end

return alert
