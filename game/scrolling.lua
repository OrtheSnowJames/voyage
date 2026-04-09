local scrolling = {}
local extra_math = require("game.extra_math")
local clamp = extra_math.clamp

local unpack_fn = table.unpack or unpack

local defaults = {
    scrollbar_width = 14,
    scrollbar_margin = 12,
    min_thumb_height = 40,
    track_margin_y = 18,
    corner_radius = 6,
    reserve_scrollbar_space = true,
    track_color = {0.08, 0.08, 0.10, 0.95},
    thumb_color = {0.78, 0.80, 0.86, 0.95},
    thumb_drag_color = {0.95, 0.95, 0.98, 0.95},
    track_border_color = {1, 1, 1, 0.15}
}

local function point_in_rect(x, y, rect)
    return x >= rect.x and y >= rect.y and x <= (rect.x + rect.w) and y <= (rect.y + rect.h)
end

local function get_canvas_mouse_position()
    local mouse_x, mouse_y = love.mouse.getPosition()
    if love.windowToCanvas then
        return love.windowToCanvas(mouse_x, mouse_y)
    end
    return mouse_x, mouse_y
end

function scrolling.new(config)
    local cfg = config or {}
    local state = {
        offset = 0,
        max_offset = 0,
        is_dragging = false,
        drag_grab_offset = 0,
        content_height = 0,
        viewport = {x = 0, y = 0, w = 0, h = 0},
        track = {x = 0, y = 0, w = cfg.scrollbar_width or defaults.scrollbar_width, h = 0},
        thumb = {x = 0, y = 0, w = cfg.scrollbar_width or defaults.scrollbar_width, h = 0},
        needs_scroll = false,
        config = {
            scrollbar_width = cfg.scrollbar_width or defaults.scrollbar_width,
            scrollbar_margin = cfg.scrollbar_margin or defaults.scrollbar_margin,
            min_thumb_height = cfg.min_thumb_height or defaults.min_thumb_height,
            track_margin_y = cfg.track_margin_y or defaults.track_margin_y,
            corner_radius = cfg.corner_radius or defaults.corner_radius,
            reserve_scrollbar_space = cfg.reserve_scrollbar_space
        }
    }

    if state.config.reserve_scrollbar_space == nil then
        state.config.reserve_scrollbar_space = defaults.reserve_scrollbar_space
    end

    state.config.track_color = cfg.track_color or defaults.track_color
    state.config.thumb_color = cfg.thumb_color or defaults.thumb_color
    state.config.thumb_drag_color = cfg.thumb_drag_color or defaults.thumb_drag_color
    state.config.track_border_color = cfg.track_border_color or defaults.track_border_color

    return state
end

function scrolling.reset(state)
    state.offset = 0
    state.max_offset = 0
    state.is_dragging = false
    state.drag_grab_offset = 0
    state.content_height = 0
    state.needs_scroll = false
end

function scrolling.stop_drag(state)
    state.is_dragging = false
end

function scrolling.update_layout(state, opts)
    local viewport_x = opts.viewport_x or 0
    local viewport_y = opts.viewport_y or 0
    local viewport_width = math.max(1, opts.viewport_width or 1)
    local viewport_height = math.max(1, opts.viewport_height or 1)
    local content_height = math.max(1, opts.content_height or viewport_height)

    local reserve_scrollbar_space = opts.reserve_scrollbar_space
    if reserve_scrollbar_space == nil then
        reserve_scrollbar_space = state.config.reserve_scrollbar_space
    end

    local needs_scroll = content_height > viewport_height
    local effective_viewport_width = viewport_width
    if needs_scroll and reserve_scrollbar_space then
        effective_viewport_width = math.max(
            1,
            viewport_width - state.config.scrollbar_width - (state.config.scrollbar_margin * 2)
        )
    end

    local track_height = math.max(1, viewport_height - (state.config.track_margin_y * 2))
    local track_x = viewport_x + viewport_width - state.config.scrollbar_margin - state.config.scrollbar_width
    local track_y = viewport_y + state.config.track_margin_y

    state.viewport.x = viewport_x
    state.viewport.y = viewport_y
    state.viewport.w = effective_viewport_width
    state.viewport.h = viewport_height

    state.track.x = track_x
    state.track.y = track_y
    state.track.w = state.config.scrollbar_width
    state.track.h = track_height

    state.content_height = math.max(content_height, viewport_height)
    state.needs_scroll = needs_scroll

    local max_offset = needs_scroll and math.max(0, state.content_height - viewport_height) or 0
    state.max_offset = max_offset
    state.offset = clamp(state.offset, 0, max_offset)

    local visible_ratio = viewport_height / state.content_height
    local thumb_height = math.max(state.config.min_thumb_height, track_height * visible_ratio)
    thumb_height = math.min(track_height, thumb_height)
    local thumb_travel = math.max(0, track_height - thumb_height)
    local thumb_ratio = max_offset > 0 and (state.offset / max_offset) or 0
    local thumb_y = track_y + (thumb_travel * thumb_ratio)

    state.thumb.x = track_x
    state.thumb.y = thumb_y
    state.thumb.w = state.config.scrollbar_width
    state.thumb.h = thumb_height
end

function scrolling.update_mouse(state, opts)
    local options = opts or {}
    local mouse_x = options.mouse_x
    local mouse_y = options.mouse_y
    if mouse_x == nil or mouse_y == nil then
        mouse_x, mouse_y = get_canvas_mouse_position()
    end

    local mouse_down = options.mouse_down
    if mouse_down == nil then
        mouse_down = love.mouse.isDown(1)
    end

    if not mouse_down then
        state.is_dragging = false
        return
    end

    if state.max_offset <= 0 then
        state.is_dragging = false
        return
    end

    if not state.is_dragging then
        if point_in_rect(mouse_x, mouse_y, state.thumb) then
            state.is_dragging = true
            state.drag_grab_offset = mouse_y - state.thumb.y
        elseif point_in_rect(mouse_x, mouse_y, state.track) then
            local min_thumb_y = state.track.y
            local max_thumb_y = state.track.y + state.track.h - state.thumb.h
            local target_thumb_y = clamp(mouse_y - (state.thumb.h / 2), min_thumb_y, max_thumb_y)
            local thumb_travel = math.max(1, max_thumb_y - min_thumb_y)
            local target_ratio = (target_thumb_y - min_thumb_y) / thumb_travel
            state.offset = target_ratio * state.max_offset
            state.is_dragging = true
            state.drag_grab_offset = mouse_y - target_thumb_y
        end
    end

    if state.is_dragging then
        local min_thumb_y = state.track.y
        local max_thumb_y = state.track.y + state.track.h - state.thumb.h
        local thumb_travel = math.max(1, max_thumb_y - min_thumb_y)
        local target_thumb_y = clamp(mouse_y - state.drag_grab_offset, min_thumb_y, max_thumb_y)
        local scroll_ratio = (target_thumb_y - min_thumb_y) / thumb_travel
        state.offset = scroll_ratio * state.max_offset
    end
end

function scrolling.update(state, opts)
    scrolling.update_layout(state, opts)
    scrolling.update_mouse(state, opts)
    scrolling.update_layout(state, opts)
end

function scrolling.get_offset_y(state, rounded)
    if rounded then
        return -math.floor(state.offset + 0.5)
    end
    return -state.offset
end

function scrolling.begin_clip(state)
    love.graphics.push("all")
    love.graphics.setScissor(state.viewport.x, state.viewport.y, state.viewport.w, state.viewport.h)
end

function scrolling.end_clip()
    love.graphics.pop()
end

function scrolling.draw(state)
    if state.max_offset <= 0 then
        return
    end

    local cfg = state.config
    love.graphics.setColor(unpack_fn(cfg.track_color))
    love.graphics.rectangle(
        "fill",
        state.track.x,
        state.track.y,
        state.track.w,
        state.track.h,
        cfg.corner_radius,
        cfg.corner_radius
    )

    if state.is_dragging then
        love.graphics.setColor(unpack_fn(cfg.thumb_drag_color))
    else
        love.graphics.setColor(unpack_fn(cfg.thumb_color))
    end
    love.graphics.rectangle(
        "fill",
        state.thumb.x,
        state.thumb.y,
        state.thumb.w,
        state.thumb.h,
        cfg.corner_radius,
        cfg.corner_radius
    )

    love.graphics.setColor(unpack_fn(cfg.track_border_color))
    love.graphics.rectangle(
        "line",
        state.track.x,
        state.track.y,
        state.track.w,
        state.track.h,
        cfg.corner_radius,
        cfg.corner_radius
    )
    love.graphics.setColor(1, 1, 1, 1)
end

return scrolling
