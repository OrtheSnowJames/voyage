local mobile_controls_steps = {}

local function update_button_positions(state, size)
    local button_size = state.button_size
    local spacing = state.button_spacing
    local screen_width = size.CANVAS_WIDTH
    local screen_height = size.CANVAS_HEIGHT

    state.buttons.left.x = button_size / 2 + spacing
    state.buttons.left.y = screen_height - button_size / 2 - spacing

    state.buttons.right.x = button_size * 1.5 + spacing * 2
    state.buttons.right.y = screen_height - button_size / 2 - spacing

    state.buttons.forward.x = (state.buttons.left.x + state.buttons.right.x) / 2
    state.buttons.forward.y = screen_height - button_size * 1.5 - spacing * 2

    state.buttons.fish.x = screen_width - button_size / 2 - spacing
    state.buttons.fish.y = screen_height - button_size / 2 - spacing
end

local function is_point_in_button(state, x, y, button)
    local dx = x - button.x
    local dy = y - button.y
    local radius = state.button_size / 2
    return (dx * dx + dy * dy) <= radius * radius
end

local function is_button_hidden(state, button_name)
    return button_name == "fish" and state.hide_fish_button
end

function mobile_controls_steps.handle_press(state, x, y)
    for button_name, button in pairs(state.buttons) do
        if not is_button_hidden(state, button_name) and is_point_in_button(state, x, y, button) then
            button.pressed = true
            return button_name
        end
    end
    return nil
end

function mobile_controls_steps.handle_release(state, x, y)
    for button_name, button in pairs(state.buttons) do
        if is_button_hidden(state, button_name) then
            button.pressed = false
        elseif is_point_in_button(state, x, y, button) then
            button.pressed = false
            return button_name
        end
    end
    return nil
end

function mobile_controls_steps.draw(state, size)
    update_button_positions(state, size)
    if state.hide_fish_button and state.buttons.fish then
        state.buttons.fish.pressed = false
    end

    for button_name, button in pairs(state.buttons) do
        if not is_button_hidden(state, button_name) then
            local alpha = button.pressed and 1.0 or state.button_alpha
            local color_multiplier = button.pressed and 0.7 or 1.0

            love.graphics.setColor(0.2 * color_multiplier, 0.6 * color_multiplier, 1.0 * color_multiplier, alpha)
            love.graphics.circle("fill", button.x, button.y, state.button_size / 2, 20)

            love.graphics.setColor(0.1 * color_multiplier, 0.4 * color_multiplier, 0.8 * color_multiplier, alpha)
            love.graphics.setLineWidth(3)
            love.graphics.circle("line", button.x, button.y, state.button_size / 2, 20)

            love.graphics.setColor(1, 1, 1, alpha)
            local text = button.key:upper()
            local font = love.graphics.getFont()
            local text_width = font:getWidth(text)
            local text_height = font:getHeight()
            love.graphics.print(text, button.x - text_width / 2, button.y - text_height / 2)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return mobile_controls_steps
