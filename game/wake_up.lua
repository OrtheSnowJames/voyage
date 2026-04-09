local wake_up = {}
local constants = require("game.constants")
local extra_math = require("game.extra_math")
local curve = extra_math.curve

local WAKE_UP_TIME = math.max(2.4, tonumber(constants.time.morningtext_fade_duration) or 2)
local time_spent = 0
wake_up.play = false
local reached_end_once = false

local eye_curve = {
    -- open a little, close back in, then open fully
    { t = 0.0, v = 0.0 },
    { t = 0.20, v = 0.22, easing = curve.easing.expo_out },
    { t = 0.40, v = 0.08, easing = curve.easing.expo_in_out },
    { t = 1, v = 1.25, easing = curve.easing.expo_in_out }
}

local initialized = false
local eye_shader

local eye_shader_raw = [[
extern vec2 center_px;
extern vec2 radius_px;
extern float edge_softness;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px)
{
    vec2 rel = (px - center_px) / max(radius_px, vec2(1.0, 1.0));
    float ellipse_dist = dot(rel, rel); // <1 inside ellipse

    // 0 inside (transparent), 1 outside (black), with soft edge
    float alpha = smoothstep(1.0 - edge_softness, 1.0 + edge_softness, ellipse_dist);
    return vec4(0.0, 0.0, 0.0, alpha);
}
]]

function wake_up.load()
    local ok, shader_or_err = pcall(love.graphics.newShader, eye_shader_raw)
    if ok then
        eye_shader = shader_or_err
        eye_shader:send("edge_softness", 0.06)
    else
        eye_shader = nil
        print("wake_up shader failed: " .. tostring(shader_or_err))
    end
    initialized = true
end

function wake_up.start()
    if not initialized then
        wake_up.load()
    end
    time_spent = 0
    wake_up.play = true
    reached_end_once = false
end

function wake_up.stop()
    time_spent = 0
    wake_up.play = false
    reached_end_once = false
end

function wake_up.update(dt)
    if wake_up.play == false then
        return
    end

    time_spent = time_spent + dt

    if time_spent >= WAKE_UP_TIME then
        time_spent = WAKE_UP_TIME
        if reached_end_once then
            wake_up.stop()
            return
        end
        reached_end_once = true
    end
end

function wake_up.draw()
    if not wake_up.play then
        return
    end

    local openness = curve.get(eye_curve, time_spent, WAKE_UP_TIME)
    local screen_width, screen_height = love.graphics.getDimensions()

    if eye_shader then
        local clamped_open = math.max(0.0, math.min(1.0, openness))
        local open_pow = clamped_open * clamped_open
        local max_rx = (screen_width * 0.5) * 1.06
        local max_ry = (screen_height * 0.5) * 1.06
        local rx = math.max(1, max_rx * open_pow)
        local ry = math.max(1, max_ry * open_pow)

        eye_shader:send("center_px", {screen_width * 0.5, screen_height * 0.5})
        eye_shader:send("radius_px", {rx, ry})

        love.graphics.setShader(eye_shader)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, screen_width, screen_height)
        love.graphics.setShader()
    else
        -- Fallback: full black if shader unavailable.
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, screen_width, screen_height)
    end
end

return wake_up
