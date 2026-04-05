local morningtext = {}
local size = require("game.size")

local wake_texts = {
    {
        "The water is blue this morning.",
        "Nice day for fishing."
    },
    {
        "Morning light dances across the sea.",
        "Your luck feels strong today."
    },
    {
        "The ocean stretches bright and wide.",
        "Today feels full of promise."
    },
    {
        "Gentle waves carry the ship forward.",
        "A good day has begun."
    },
    {
        "A cool breeze moves across the water.",
        "The sea is on your side."
    },
    {
        "The horizon glows in soft morning light.",
        "The voyage feels hopeful."
    },
    {
        "The sea is calm and clear.",
        "Take your time and fish well."
    },
    {
        "The sky brightens over the horizon.",
        "The water welcomes your line."
    },
    {
        "The morning tide rolls in smoothly.",
        "A steady hand catches plenty."
    },
    {
        "The sun climbs above the sea.",
        "Another fine day on the water."
    }
}

local corrupted_texts = {
    [0.1] = {
        "The sea looks darker today.",
        "Your crew seems quieter than usual."
    },

    [0.2] = {
        "The water moves strangely beneath the boat.",
        "Your crew wants to go back home."
    },

    [0.3] = {
        "The ocean feels wrong somehow.",
        "Your crew avoids meeting your eyes."
    },

    [0.4] = {
        "The sea is black.",
        "Your crew whispers among themselves."
    },

    [0.5] = {
        "You know it.",
        "Your crew knows it."
    }
}

local TYPEWRITER_CHARS_PER_SECOND = 26
local START_DELAY = 2.0
local HOLD_TIME = 5.0
local FADE_DURATION = 1.2
local MARGIN = 20
local LINE_SPACING = 8
local TEXT_SCALE = 1.6

local state = {
    active = false,
    timer = 0,
    reveal_chars = 0,
    lines = nil
}

local function round_to_tenth(value)
    return math.floor(value * 10 + 0.5) / 10
end

local function get_corrupted_lines(rainbows)
    local key = round_to_tenth(math.max(0, tonumber(rainbows) or 0))
    while key >= 0.1 do
        if corrupted_texts[key] then
            return corrupted_texts[key]
        end
        key = round_to_tenth(key - 0.1)
    end
    return nil
end

local function get_alpha()
    if not state.active then
        return 0
    end

    if state.timer <= START_DELAY + HOLD_TIME then
        return 1
    end

    local fade_t = (state.timer - (START_DELAY + HOLD_TIME)) / FADE_DURATION
    return math.max(0, 1 - fade_t)
end

local function get_revealed_lines()
    local line1_full = state.lines[1] or ""
    local line2_full = state.lines[2] or ""
    local total_visible_chars = math.floor(state.reveal_chars)

    local line1_visible = math.min(#line1_full, total_visible_chars)
    local line2_visible = math.max(0, total_visible_chars - #line1_full)

    local line1 = string.sub(line1_full, 1, line1_visible)
    local line2 = string.sub(line2_full, 1, line2_visible)
    return line1, line2
end

function morningtext.start(rainbows)
    local corrupted = get_corrupted_lines(rainbows)
    if corrupted then
        state.lines = corrupted
    else
        local line_index = math.random(1, #wake_texts)
        print(string.format("index: %d", line_index))
        state.lines = wake_texts[line_index]
    end

    state.active = true
    state.timer = 0
    state.reveal_chars = 0
end

function morningtext.update(dt)
    if not state.active then
        return
    end

    state.timer = state.timer + dt
    local visible_time = math.max(0, state.timer - START_DELAY)
    state.reveal_chars = visible_time * TYPEWRITER_CHARS_PER_SECOND

    if state.timer >= START_DELAY + HOLD_TIME + FADE_DURATION then
        state.active = false
    end
end

function morningtext.draw()
    if not state.active or not state.lines then
        return
    end

    local alpha = get_alpha()
    if alpha <= 0 then
        return
    end

    local line1, line2 = get_revealed_lines()
    local font = love.graphics.getFont()
    local line1_w = font:getWidth(line1) * TEXT_SCALE
    local line2_w = font:getWidth(line2) * TEXT_SCALE
    local text_h = font:getHeight() * TEXT_SCALE

    -- stacked at the bottom: top line first, bottom line under it
    local block_height = text_h * 2 + LINE_SPACING
    local block_y = size.CANVAS_HEIGHT - MARGIN - block_height
    local line1_y = block_y
    local line2_y = block_y + text_h + LINE_SPACING

    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.print(line1, (size.CANVAS_WIDTH - line1_w) / 2, line1_y, 0, TEXT_SCALE, TEXT_SCALE)
    love.graphics.print(line2, (size.CANVAS_WIDTH - line2_w) / 2, line2_y, 0, TEXT_SCALE, TEXT_SCALE)
    love.graphics.setColor(1, 1, 1, 1)
end

function morningtext.reset()
    state.active = false
    state.timer = 0
    state.reveal_chars = 0
    state.lines = nil
end

return morningtext
