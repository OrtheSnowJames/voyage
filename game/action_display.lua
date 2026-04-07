local constants = require("game.constants")
local action_display_constants = constants.action_display
local keycap_constants = action_display_constants.keycap
local prompt_constants = action_display_constants.prompt
local mouse_decal_constants = action_display_constants.mouse_decal or {}
local unpack_values = table.unpack or unpack
local action_display = {}

-- giant beheamoth of constants
local KEYCAP_DEFAULT_PADDING = keycap_constants.default_padding
local KEYCAP_CORNER_RADIUS = keycap_constants.corner_radius
local KEYCAP_DEPTH_OFFSET = keycap_constants.depth_offset or 3
local KEYCAP_BORDER_COLOR = keycap_constants.border_color
local KEYCAP_FACE_COLOR = keycap_constants.face_color or {0.95, 0.92, 0.84, 1}
local KEYCAP_SHADOW_COLOR = keycap_constants.shadow_color or {0.32, 0.28, 0.20, 1}
local KEYCAP_TEXT_COLOR = keycap_constants.text_color or {0.14, 0.12, 0.08, 1}
local KEYCAP_HIGHLIGHT_COLOR = keycap_constants.highlight_color or {1, 1, 1, 0.32}
local KEYCAP_FONT_SIZE = keycap_constants.font_size or 30
local PROMPT_MARGIN = prompt_constants.margin
local PROMPT_WIDTH = prompt_constants.width
local PROMPT_HEIGHT = prompt_constants.height
local PROMPT_CORNER_RADIUS = prompt_constants.corner_radius
local PROMPT_BORDER_LINE_WIDTH = prompt_constants.border_line_width
local PROMPT_FONT_PATH = prompt_constants.font_path
local PROMPT_FONT_SIZE = prompt_constants.font_size or 28
local PROMPT_NORMAL_COLOR = prompt_constants.normal_color or {0.25, 0.25, 0.25}
local PROMPT_HOVER_COLOR = prompt_constants.hover_color or {0.22, 0.22, 0.22}
local PROMPT_PRESSED_COLOR = prompt_constants.pressed_color or {0.18, 0.18, 0.18}
local PROMPT_BORDER_COLOR = prompt_constants.border_color or {1, 1, 1, 1}
local PROMPT_FRAME_COLOR = prompt_constants.frame_color or {0.2, 0.2, 0.2, 1}
local PROMPT_INNER_BORDER_COLOR = prompt_constants.inner_border_color or {1, 1, 1, 0.12}
local PROMPT_SHADOW_COLOR = prompt_constants.shadow_color or {0, 0, 0, 0.4}
local PROMPT_TEXT_COLOR = prompt_constants.text_color or {1, 1, 1, 1}
local PROMPT_TEXT_SHADOW_COLOR = prompt_constants.text_shadow_color or {0, 0, 0, 0.5}
local PROMPT_PRESS_OFFSET = prompt_constants.press_offset or 1
local MOUSE_DECAL_BORDER_LINE_WIDTH = mouse_decal_constants.border_line_width or 2
local MOUSE_DECAL_SHADOW_OFFSET_Y = mouse_decal_constants.shadow_offset_y or 3
local MOUSE_DECAL_WHEEL_PADDING_RATIO = mouse_decal_constants.wheel_padding_ratio or 0.06
local MOUSE_DECAL_BODY_COLOR = mouse_decal_constants.body_color or {0.96, 0.97, 0.99, 1}
local MOUSE_DECAL_BUTTON_COLOR = mouse_decal_constants.button_color or {0.90, 0.93, 0.98, 1}
local MOUSE_DECAL_BUTTON_PRESSED_COLOR = mouse_decal_constants.button_pressed_color or {0.78, 0.84, 0.94, 1}
local MOUSE_DECAL_WHEEL_COLOR = mouse_decal_constants.wheel_color or {0.20, 0.28, 0.40, 1}
local MOUSE_DECAL_WHEEL_SLOT_COLOR = mouse_decal_constants.wheel_slot_color or {0.80, 0.86, 0.95, 1}
local MOUSE_DECAL_WHEEL_SLOT_SHADOW_COLOR = mouse_decal_constants.wheel_slot_shadow_color or {0.58, 0.66, 0.80, 0.55}
local MOUSE_DECAL_WHEEL_SLOT_BORDER_COLOR = mouse_decal_constants.wheel_slot_border_color or {0.33, 0.42, 0.56, 1}
local MOUSE_DECAL_SPLIT_COLOR = mouse_decal_constants.split_color or {0.62, 0.70, 0.83, 1}
local MOUSE_DECAL_BORDER_COLOR = mouse_decal_constants.border_color or {0.18, 0.24, 0.34, 1}
local MOUSE_DECAL_HIGHLIGHT_COLOR = mouse_decal_constants.highlight_color or {1, 1, 1, 0.38}
local MOUSE_DECAL_SHADOW_COLOR = mouse_decal_constants.shadow_color or {0, 0, 0, 0.28}
local MOUSE_DECAL_LOOP_COLOR = mouse_decal_constants.loop_color or {0.88, 0.90, 0.97, 0.92}
local MOUSE_DECAL_LOOP_LINE_WIDTH = mouse_decal_constants.loop_line_width or 3
local MOUSE_DECAL_LOOP_RADIUS_SCALE = mouse_decal_constants.loop_radius_scale or 1.12
local MOUSE_DECAL_LOOP_ARROW_SIZE_RATIO = mouse_decal_constants.loop_arrow_size_ratio or 0.2
local MOUSE_DECAL_LOOP_ANGLE_DEGREES = mouse_decal_constants.loop_angle_degrees or 0
local keycap_font = nil
local prompt_font = nil

local function get_font(path, size, cached_font)
    if cached_font then
        return cached_font
    end
    if path and love.filesystem.getInfo(path) then
        return love.graphics.newFont(path, size)
    end
    return love.graphics.newFont(size)
end

local function set_color_with_alpha(color, alpha)
    local c1 = color[1] or 1
    local c2 = color[2] or 1
    local c3 = color[3] or 1
    local c4 = (color[4] or 1) * (alpha or 1)
    love.graphics.setColor(c1, c2, c3, c4)
end

local function measure_keycap(key, padding)
    padding = padding or KEYCAP_DEFAULT_PADDING
    keycap_font = get_font(PROMPT_FONT_PATH, KEYCAP_FONT_SIZE, keycap_font)
    local textW = keycap_font:getWidth(key)
    local textH = keycap_font:getHeight()
    local w = textW + padding * 2
    local h = textH + padding * 2
    return w, h, textH
end

function action_display.drawKeycap(key, x, y, padding)
    padding = padding or KEYCAP_DEFAULT_PADDING
    keycap_font = get_font(PROMPT_FONT_PATH, KEYCAP_FONT_SIZE, keycap_font)

    local previous_font = love.graphics.getFont()
    local previous_line_width = love.graphics.getLineWidth()
    love.graphics.setFont(keycap_font)
    local w, h, textH = measure_keycap(key, padding)

    love.graphics.setColor(unpack_values(KEYCAP_SHADOW_COLOR))
    love.graphics.rectangle("fill", x, y + KEYCAP_DEPTH_OFFSET, w, h, KEYCAP_CORNER_RADIUS, KEYCAP_CORNER_RADIUS)

    love.graphics.setColor(unpack_values(KEYCAP_FACE_COLOR))
    love.graphics.rectangle("fill", x, y, w, h, KEYCAP_CORNER_RADIUS, KEYCAP_CORNER_RADIUS)

    love.graphics.setColor(unpack_values(KEYCAP_HIGHLIGHT_COLOR))
    love.graphics.rectangle("fill", x + 2, y + 2, w - 4, math.max(4, h * 0.24), KEYCAP_CORNER_RADIUS, KEYCAP_CORNER_RADIUS)

    love.graphics.setLineWidth(2)
    love.graphics.setColor(unpack_values(KEYCAP_BORDER_COLOR))
    love.graphics.rectangle("line", x, y, w, h, KEYCAP_CORNER_RADIUS, KEYCAP_CORNER_RADIUS)

    love.graphics.setColor(unpack_values(KEYCAP_TEXT_COLOR))
    love.graphics.printf(
        key,
        x,
        y + (h - textH) / 2,
        w,
        "center"
    )

    love.graphics.setLineWidth(previous_line_width)
    love.graphics.setFont(previous_font)
    love.graphics.setColor(1, 1, 1, 1)
    return w, h
end

function action_display.drawKeyPrompt(key, prompt, x, y)
    local margin = PROMPT_MARGIN
    local px = x - (PROMPT_WIDTH / 2)
    local py = y - (PROMPT_HEIGHT / 2)
    local previous_line_width = love.graphics.getLineWidth()
    local previous_font = love.graphics.getFont()
    local mx, my = love.mouse.getPosition()
    prompt_font = get_font(PROMPT_FONT_PATH, PROMPT_FONT_SIZE, prompt_font)

    if love.windowToCanvas then
        mx, my = love.windowToCanvas(mx, my)
    end

    local mouse_hovered = (
        mx >= px and mx <= px + PROMPT_WIDTH and
        my >= py and my <= py + PROMPT_HEIGHT
    )
    local mouse_down = mouse_hovered and love.mouse.isDown(1)
    local touch_hovered = false

    if love.touch and love.touch.getTouches and love.touch.getPosition then
        local touches = love.touch.getTouches()
        for i = 1, #touches do
            local id = touches[i]
            local tx, ty = love.touch.getPosition(id)
            if love.windowToCanvas then
                tx, ty = love.windowToCanvas(tx, ty)
            end

            if tx >= px and tx <= px + PROMPT_WIDTH and ty >= py and ty <= py + PROMPT_HEIGHT then
                touch_hovered = true
                break
            end
        end
    end

    local hovered = mouse_hovered or touch_hovered
    local is_down = mouse_down or touch_hovered
    local just_pressed = is_down and not action_display._was_down
    action_display._was_down = is_down

    local fill_color = PROMPT_NORMAL_COLOR
    if is_down then
        fill_color = PROMPT_PRESSED_COLOR
    elseif hovered then
        fill_color = PROMPT_HOVER_COLOR
    end

    local offset = is_down and PROMPT_PRESS_OFFSET or 0

    love.graphics.setColor(unpack_values(PROMPT_SHADOW_COLOR))
    love.graphics.rectangle(
        "fill",
        px + 2,
        py + 6,
        PROMPT_WIDTH,
        PROMPT_HEIGHT,
        PROMPT_CORNER_RADIUS,
        PROMPT_CORNER_RADIUS
    )

    love.graphics.setColor(unpack_values(PROMPT_FRAME_COLOR))
    love.graphics.rectangle(
        "fill",
        px + offset,
        py + offset,
        PROMPT_WIDTH,
        PROMPT_HEIGHT,
        PROMPT_CORNER_RADIUS,
        PROMPT_CORNER_RADIUS
    )

    love.graphics.rectangle(
        "fill",
        px + offset + 4,
        py + offset + 4,
        PROMPT_WIDTH - 8,
        PROMPT_HEIGHT - 8,
        PROMPT_CORNER_RADIUS,
        PROMPT_CORNER_RADIUS
    )
    love.graphics.setColor(unpack_values(fill_color))
    love.graphics.rectangle(
        "fill",
        px + offset + 5,
        py + offset + 5,
        PROMPT_WIDTH - 10,
        PROMPT_HEIGHT - 10,
        PROMPT_CORNER_RADIUS - 2,
        PROMPT_CORNER_RADIUS - 2
    )

    love.graphics.setLineWidth(PROMPT_BORDER_LINE_WIDTH)
    love.graphics.setColor(unpack_values(PROMPT_BORDER_COLOR))
    love.graphics.rectangle(
        "line",
        px + offset,
        py + offset,
        PROMPT_WIDTH,
        PROMPT_HEIGHT,
        PROMPT_CORNER_RADIUS,
        PROMPT_CORNER_RADIUS
    )

    love.graphics.setColor(unpack_values(PROMPT_INNER_BORDER_COLOR))
    love.graphics.rectangle(
        "line",
        px + offset + 5,
        py + offset + 5,
        PROMPT_WIDTH - 10,
        PROMPT_HEIGHT - 10,
        PROMPT_CORNER_RADIUS - 3,
        PROMPT_CORNER_RADIUS - 3
    )

    local _, key_h = measure_keycap(key)
    local key_x = px + margin + offset
    local key_y = py + (PROMPT_HEIGHT - key_h) / 2 + offset
    local kw = action_display.drawKeycap(
        key,
        key_x,
        key_y
    )

    love.graphics.setFont(prompt_font)
    love.graphics.setColor(unpack_values(PROMPT_TEXT_SHADOW_COLOR))
    love.graphics.print(
        prompt,
        key_x + kw + margin + 1,
        py + (PROMPT_HEIGHT - prompt_font:getHeight()) / 2 + 1 + offset
    )
    love.graphics.setColor(unpack_values(PROMPT_TEXT_COLOR))
    love.graphics.print(
        prompt,
        key_x + kw + margin,
        py + (PROMPT_HEIGHT - prompt_font:getHeight()) / 2 + offset
    )

    love.graphics.setLineWidth(previous_line_width)
    love.graphics.setFont(previous_font)
    love.graphics.setColor(1, 1, 1, 1)
    return just_pressed
end

function action_display.drawMouseDecal(x, y, size, opts)
    size = math.max(8, tonumber(size) or 40)
    opts = opts or {}

    local alpha = opts.alpha or 1
    local left_down = opts.left_down == true
    local right_down = opts.right_down == true
    local show_loop = opts.show_loop == true

    local width = size
    local height = size * 1.52
    local radius = math.max(4, width * 0.44)
    local button_radius = math.max(3, radius * 0.9)
    local button_height = height * 0.40
    local wheel_width = width * 0.14
    local wheel_height = height * 0.16
    local wheel_padding = math.max(1, width * MOUSE_DECAL_WHEEL_PADDING_RATIO)
    local split_width = math.max(1, width * 0.035)
    local px = x - (width / 2)
    local py = y - (height / 2)
    local wheel_x = x - (wheel_width / 2)
    local wheel_y = py + button_height - (wheel_height * 0.35)
    local wheel_slot_x = wheel_x - wheel_padding
    local wheel_slot_y = wheel_y - wheel_padding
    local wheel_slot_w = wheel_width + wheel_padding * 2
    local wheel_slot_h = wheel_height + wheel_padding * 2
    local wheel_slot_radius = math.max(2, wheel_slot_w * 0.35)

    local previous_line_width = love.graphics.getLineWidth()

    love.graphics.stencil(function()
        love.graphics.rectangle("fill", wheel_slot_x, wheel_slot_y, wheel_slot_w, wheel_slot_h, wheel_slot_radius, wheel_slot_radius)
    end, "replace", 1, true)
    love.graphics.setStencilTest("notequal", 1)

    set_color_with_alpha(MOUSE_DECAL_BODY_COLOR, alpha)
    love.graphics.rectangle("fill", px, py, width, height, radius, radius)

    set_color_with_alpha(left_down and MOUSE_DECAL_BUTTON_PRESSED_COLOR or MOUSE_DECAL_BUTTON_COLOR, alpha)
    love.graphics.rectangle("fill", px + 1, py + 1, (width / 2) - 2, button_height, button_radius, button_radius)
    set_color_with_alpha(right_down and MOUSE_DECAL_BUTTON_PRESSED_COLOR or MOUSE_DECAL_BUTTON_COLOR, alpha)
    love.graphics.rectangle("fill", x + 1, py + 1, (width / 2) - 2, button_height, button_radius, button_radius)

    set_color_with_alpha(MOUSE_DECAL_SPLIT_COLOR, alpha)
    love.graphics.rectangle("fill", x - (split_width / 2), py + 3, split_width, button_height - 6, split_width, split_width)

    --set_color_with_alpha(MOUSE_DECAL_HIGHLIGHT_COLOR, alpha) -- too realistic
    --love.graphics.ellipse("fill", x, py + height * 0.20, width * 0.33, math.max(2, height * 0.08))

    love.graphics.setLineWidth(MOUSE_DECAL_BORDER_LINE_WIDTH)
    set_color_with_alpha(MOUSE_DECAL_BORDER_COLOR, alpha)
    love.graphics.rectangle("line", px, py, width, height, radius, radius)
    love.graphics.line(px + 4, py + button_height, px + width - 4, py + button_height)

    love.graphics.setStencilTest()

    set_color_with_alpha(MOUSE_DECAL_WHEEL_COLOR, alpha)
    love.graphics.rectangle(
        "fill",
        wheel_x,
        wheel_y,
        wheel_width,
        wheel_height,
        wheel_width * 0.5,
        wheel_width * 0.5
    )

    love.graphics.setLineWidth(math.max(1, MOUSE_DECAL_BORDER_LINE_WIDTH - 0.5))
    set_color_with_alpha(MOUSE_DECAL_WHEEL_SLOT_BORDER_COLOR, alpha)
    love.graphics.rectangle("line", wheel_slot_x, wheel_slot_y, wheel_slot_w, wheel_slot_h, wheel_slot_radius, wheel_slot_radius)

    love.graphics.stencil(function()
        love.graphics.rectangle("fill", wheel_slot_x, wheel_slot_y, wheel_slot_w, wheel_slot_h, wheel_slot_radius, wheel_slot_radius)
    end, "replace", 0, true)

    if show_loop then
        local phase = opts.loop_phase or math.rad(MOUSE_DECAL_LOOP_ANGLE_DEGREES)
        local loop_radius = math.max(width, height) * MOUSE_DECAL_LOOP_RADIUS_SCALE * 0.5
        local loop_start = phase + math.rad(35)
        local loop_end = phase + math.rad(326)
        local arrow_size = math.max(4, loop_radius * MOUSE_DECAL_LOOP_ARROW_SIZE_RATIO)
        local tip_x = x + math.cos(loop_end) * loop_radius
        local tip_y = y + math.sin(loop_end) * loop_radius
        local dir_x = -math.sin(loop_end)
        local dir_y = math.cos(loop_end)
        local perp_x = -dir_y
        local perp_y = dir_x
        local back_x = tip_x - (dir_x * arrow_size)
        local back_y = tip_y - (dir_y * arrow_size)
        local wing = arrow_size * 0.56

        love.graphics.setLineWidth(MOUSE_DECAL_LOOP_LINE_WIDTH)
        set_color_with_alpha(MOUSE_DECAL_LOOP_COLOR, alpha)
        love.graphics.arc("line", "open", x, y, loop_radius, loop_start, loop_end, 48)

        love.graphics.polygon(
            "fill",
            tip_x,
            tip_y,
            back_x + (perp_x * wing),
            back_y + (perp_y * wing),
            back_x - (perp_x * wing),
            back_y - (perp_y * wing)
        )
    end

    love.graphics.setLineWidth(previous_line_width)
    love.graphics.setColor(1, 1, 1, 1)
end

return action_display
