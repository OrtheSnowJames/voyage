local theme = {}

theme.cornerRadius = 12
theme.font = nil

theme.color = {
    normal = {
        bg = {0.16, 0.20, 0.27, 0.96},
        fg = {0.95, 0.97, 1.00, 1.00},
        border = {0.58, 0.70, 0.86, 1.00},
        shadow = {0.03, 0.05, 0.09, 0.55}
    },
    hovered = {
        bg = {0.20, 0.27, 0.37, 0.98},
        fg = {1.00, 1.00, 1.00, 1.00},
        border = {0.76, 0.86, 0.98, 1.00},
        shadow = {0.04, 0.07, 0.12, 0.62}
    },
    active = {
        bg = {0.12, 0.16, 0.22, 1.00},
        fg = {0.92, 0.96, 1.00, 1.00},
        border = {0.66, 0.78, 0.94, 1.00},
        shadow = {0.02, 0.03, 0.05, 0.68}
    }
}

function theme.getColorForState(opt)
    local state_name = opt.state or "normal"
    return (opt.color and opt.color[state_name]) or theme.color[state_name] or theme.color.normal
end

function theme.getVerticalOffsetForAlign(valign, font, h)
    if valign == "top" then
        return 0
    elseif valign == "bottom" then
        return h - font:getHeight()
    end
    return (h - font:getHeight()) * 0.5
end

local function draw_box_with_depth(x, y, w, h, c, radius, pressed)
    local py = pressed and 1 or 0
    local shadow_offset = pressed and 1 or 3

    love.graphics.setColor(c.shadow)
    love.graphics.rectangle("fill", x, y + shadow_offset, w, h, radius, radius)

    love.graphics.setColor(c.bg)
    love.graphics.rectangle("fill", x, y + py, w, h, radius, radius)

    love.graphics.setColor(1, 1, 1, pressed and 0.05 or 0.10)
    love.graphics.rectangle("line", x + 1, y + py + 1, w - 2, h - 2, math.max(2, radius - 2), math.max(2, radius - 2))

    love.graphics.setColor(c.border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y + py, w, h, radius, radius)
    love.graphics.setLineWidth(1)
end

local function use_font(opt)
    local font = opt.font or theme.font or love.graphics.getFont()
    love.graphics.setFont(font)
    return font
end

function theme.Label(text, opt, x, y, w, h)
    local font = use_font(opt)
    y = y + theme.getVerticalOffsetForAlign(opt.valign, font, h)
    local c = theme.getColorForState(opt)
    love.graphics.setColor(c.fg)
    love.graphics.printf(text, x + 4, y, w - 8, opt.align or "center")
end

function theme.Button(text, opt, x, y, w, h)
    local font = use_font(opt)
    local c = theme.getColorForState(opt)
    local radius = opt.cornerRadius or theme.cornerRadius
    local pressed = opt.state == "active"

    draw_box_with_depth(x, y, w, h, c, radius, pressed)
    love.graphics.setColor(c.fg)
    y = y + theme.getVerticalOffsetForAlign(opt.valign, font, h) + (pressed and 1 or 0)
    love.graphics.printf(text, x + 6, y, w - 12, opt.align or "center")
end

function theme.Checkbox(chk, opt, x, y, w, h)
    local font = use_font(opt)
    local c = theme.getColorForState(opt)
    local box = math.floor(h * 0.72)
    local bx = x + 6
    local by = y + (h - box) * 0.5
    local radius = math.max(4, math.floor(theme.cornerRadius * 0.5))

    draw_box_with_depth(bx, by, box, box, c, radius, opt.state == "active")
    if chk.checked then
        love.graphics.setColor(c.fg)
        love.graphics.setLineWidth(3)
        love.graphics.line(bx + box * 0.22, by + box * 0.55, bx + box * 0.45, by + box * 0.76, bx + box * 0.80, by + box * 0.26)
        love.graphics.setLineWidth(1)
    end

    if chk.text then
        love.graphics.setColor(c.fg)
        local ty = y + theme.getVerticalOffsetForAlign(opt.valign, font, h)
        love.graphics.printf(chk.text, bx + box + 10, ty, w - box - 16, opt.align or "left")
    end
end

function theme.Slider(fraction, opt, x, y, w, h)
    local c = theme.getColorForState(opt)
    local radius = math.max(5, math.floor(theme.cornerRadius * 0.55))
    local track_h = math.max(8, math.floor(h * 0.3))
    local track_y = y + (h - track_h) * 0.5

    love.graphics.setColor(0.07, 0.10, 0.15, 0.9)
    love.graphics.rectangle("fill", x, track_y, w, track_h, radius, radius)
    love.graphics.setColor(c.border)
    love.graphics.rectangle("line", x, track_y, w, track_h, radius, radius)

    local fill_w = math.max(0, math.min(w, w * fraction))
    love.graphics.setColor(c.bg)
    love.graphics.rectangle("fill", x, track_y, fill_w, track_h, radius, radius)

    local knob_x = x + fill_w
    love.graphics.setColor(c.fg)
    love.graphics.circle("fill", knob_x, y + h * 0.5, math.max(7, math.floor(h * 0.26)))
end

function theme.Input(input, opt, x, y, w, h)
    local utf8 = require("utf8")
    local c = theme.getColorForState(opt)
    local radius = opt.cornerRadius or theme.cornerRadius
    local font = use_font(opt)
    local th = font:getHeight()

    draw_box_with_depth(x, y, w, h, c, radius, false)

    local sx, sy, sw, sh = love.graphics.getScissor()
    local text_x = x + 8
    love.graphics.setScissor(text_x - 1, y, w - 14, h)

    local draw_x = text_x - input.text_draw_offset
    love.graphics.setColor(c.fg)
    love.graphics.print(input.text, draw_x, y + (h - th) * 0.5)

    local tw = font:getWidth(input.text)
    local candidate = input.candidate_text and input.candidate_text.text or ""
    love.graphics.setColor(c.fg[1], c.fg[2], c.fg[3], 0.65)
    love.graphics.print(candidate, draw_x + tw, y + (h - th) * 0.5)

    if opt.hasKeyboardFocus and (love.timer.getTime() % 1) > 0.5 then
        local ct = input.candidate_text
        local ws = 0
        if ct and ct.text and ct.start and ct.start > 0 then
            local ok, byte = pcall(utf8.offset, ct.text, ct.start)
            if ok and byte then
                ws = font:getWidth(ct.text:sub(1, byte))
            end
        end
        love.graphics.setColor(c.fg)
        love.graphics.line(draw_x + opt.cursor_pos + ws, y + (h - th) * 0.5, draw_x + opt.cursor_pos + ws, y + (h + th) * 0.5)
    end

    if sx and sy and sw and sh then
        love.graphics.setScissor(sx, sy, sw, sh)
    else
        love.graphics.setScissor()
    end
end

return theme
