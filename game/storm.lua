local storm = {}

local radius_of_spread = 10
local DOT_SIZE = 50
local WARNING_DURATION = 1.5
local BOLT_DURATION = 0.18
local SPAWN_CHECK_INTERVAL = 6.0
local BOLT_INTERVAL_MIN = 0.35
local BOLT_INTERVAL_MAX = 0.85
local BOLT_BURST_MIN = 2
local BOLT_BURST_MAX = 4
local STRIKE_RADIUS_MIN = 260
local STRIKE_RADIUS_MAX = 560
local MAX_DEPTH_FOR_CHANCE = 12
local LIGHTNING_HEARING_RADIUS = 1200
local INITIAL_LIGHTNING_VOLUME = 0.1 -- 0.5 = 50%
local BASE_RAIN_VOLUME = 0.38
local RAIN_AUDIO_PATH = "assets/rain.mp3"
local LIGHTNING_AUDIO_PATH = "assets/lightning_strike.mp3"

local audio_loaded = false
local rain_source = nil
local lightning_source = nil
local audio_volume_multiplier = 1.0

local function apply_rain_volume()
    if rain_source then
        rain_source:setVolume(BASE_RAIN_VOLUME * audio_volume_multiplier)
    end
end

local function random_in_circle(point, radius)
    local angle = math.random() * math.pi * 2
    local distance = math.sqrt(math.random()) * radius

    return {
        x = point.x + math.cos(angle) * distance,
        y = point.y + math.sin(angle) * distance
    }
end

local function ensure_audio_loaded()
    if audio_loaded then
        return
    end
    audio_loaded = true

    local ok_rain, rain = pcall(love.audio.newSource, RAIN_AUDIO_PATH, "stream")
    if ok_rain and rain then
        rain:setLooping(true)
        rain_source = rain
        apply_rain_volume()
    end

    local ok_lightning, lightning = pcall(love.audio.newSource, LIGHTNING_AUDIO_PATH, "static")
    if ok_lightning and lightning then
        lightning:setVolume(0.25)
        lightning_source = lightning
    end
end

local function play_rain_loop()
    ensure_audio_loaded()
    apply_rain_volume()
    if rain_source and not rain_source:isPlaying() then
        rain_source:play()
    end
end

local function stop_rain_loop()
    if rain_source and rain_source:isPlaying() then
        rain_source:stop()
    end
end

local function play_lightning_sound(strike_x, strike_y, player)
    ensure_audio_loaded()
    if not lightning_source then
        return
    end
    local volume = INITIAL_LIGHTNING_VOLUME
    if player and strike_x and strike_y then
        local dx = (tonumber(strike_x) or 0) - (tonumber(player.x) or 0)
        local dy = (tonumber(strike_y) or 0) - (tonumber(player.y) or 0)
        local dist = math.sqrt((dx * dx) + (dy * dy))
        local t = math.max(0, math.min(1, dist / LIGHTNING_HEARING_RADIUS))
        volume = INITIAL_LIGHTNING_VOLUME * (1 - t)
    end
    volume = volume * audio_volume_multiplier

    local clone = lightning_source:clone()
    clone:setVolume(volume)
    clone:setPitch(0.85 + math.random() * 0.45)
    clone:play()
end

local function random_ring_point(center, min_radius, max_radius)
    local angle = math.random() * math.pi * 2
    local radius = min_radius + math.random() * (max_radius - min_radius)
    return {
        x = center.x + math.cos(angle) * radius,
        y = center.y + math.sin(angle) * radius
    }
end

local function pick_strike_point_around_player(player)
    local center = {x = player.x, y = player.y}
    local roll = math.random()

    -- Heavy bias toward player: some direct hits, many nearby, some far.
    if roll < 0.25 then
        return {
            x = center.x + love.math.random(-10, 10),
            y = center.y + love.math.random(-10, 10)
        }
    end
    if roll < 0.70 then
        return random_ring_point(center, 70, 220)
    end
    return random_ring_point(center, STRIKE_RADIUS_MIN, STRIKE_RADIUS_MAX)
end

local function build_lightning_track(top_point, bottom_point)
    local dy = (bottom_point.y - top_point.y)
    if math.abs(dy) < 1 then
        dy = 1
    end

    -- Stylized bolt shape:
    --   /
    --   —
    --     /
    local seg1_y = top_point.y + dy * 0.36
    local seg2_y = top_point.y + dy * 0.58
    local slash1_x = top_point.x + math.random(28, 68)
    local slash2_x = slash1_x + math.random(34, 86)
    local bottom_x = slash2_x + math.random(22, 58)

    local track = {
        { x = top_point.x,    y = top_point.y },
        random_in_circle({ x = slash1_x, y = seg1_y }, radius_of_spread * 0.7),
        random_in_circle({ x = slash2_x, y = seg2_y }, radius_of_spread * 0.25),
        { x = bottom_point.x, y = bottom_point.y }
    }
    local track_thickness = {
        math.random(10, 50),
        math.random(10, 50),
        math.random(10, 50),
        math.random(10, 50),
    }

    return track, track_thickness
end

local function draw_lightning_track(track, track_thickness)
    local prev_r, prev_g, prev_b, prev_a = love.graphics.getColor()
    love.graphics.setColor(1, 1, 1, 1)

    for i = 1, #track - 1 do
        local p1 = track[i]
        local p2 = track[i + 1]
        local dx = p2.x - p1.x
        local dy = p2.y - p1.y
        local len = math.sqrt((dx * dx) + (dy * dy))
        if len > 0.0001 then
            local nx = -dy / len
            local ny = dx / len
            local h1 = (track_thickness[i] or 10) * 0.5
            local h2 = (track_thickness[i + 1] or 10) * 0.5

            love.graphics.polygon(
                "fill",
                p1.x + nx * h1, p1.y + ny * h1,
                p1.x - nx * h1, p1.y - ny * h1,
                p2.x - nx * h2, p2.y - ny * h2,
                p2.x + nx * h2, p2.y + ny * h2
            )
        end
    end

    -- round the joints/caps so the strip looks continuous
    --[[for i = 1, #track do
        local point = track[i]
        local radius = math.max(1, (track_thickness[i] or 10) * 0.5)
        love.graphics.circle("fill", point.x, point.y, radius)
    end]] -- lowkey not needed, looks better without

    love.graphics.setColor(prev_r, prev_g, prev_b, prev_a)
end

function storm.draw_lightning(top_point, bottom_point)
    local track, track_thickness = build_lightning_track(top_point, bottom_point)
    draw_lightning_track(track, track_thickness)
end

function storm.water_intense(state, yes)
    if not state.system.water then
        state.system.water = { wave_intensity = 1.0 }
    end
    local current = tonumber(state.system.water.wave_intensity) or 0
    state.system.water.wave_intensity = yes and 3 or 1
end

function storm.draw_lightning_dot(dot)
    if dot.stage == 3 then
        love.graphics.setColor(1.000, 0.082, 0.000)
    elseif dot.stage == 2 then
        love.graphics.setColor(1.000, 0.882, 0.000)
    elseif dot.stage == 1 then
        love.graphics.setColor(1.000, 0.976, 0.812)
    end

    love.graphics.ellipse("fill", dot.x, dot.y, DOT_SIZE, DOT_SIZE / 1.25)
    love.graphics.setColor(1, 1, 1, 1)
end

local function ensure_runtime(state)
    if not state.system.storm then
        state.system.storm = {
            active = false,
            check_timer = SPAWN_CHECK_INTERVAL,
            storm_timer = 0,
            next_bolt_timer = 0,
            pending_dots = {},
            active_bolts = {}
        }
    end
    return state.system.storm
end

local function get_time_of_day_hours(player_ship)
    local day_length = tonumber(player_ship.time_system.DAY_LENGTH) or 1
    local current_time = tonumber(player_ship.time_system.time) or 0
    return (current_time / day_length) * 12
end

local function is_night(player_ship)
    local hours = get_time_of_day_hours(player_ship)
    return hours >= 10.5 or hours <= 1.5
end

function storm.get_spawn_chance(player_y, fishing_level)
    local level_size = tonumber(fishing_level) or 1000
    local depth_levels = math.max(0, math.floor(math.abs(tonumber(player_y) or 0) / level_size))
    local t = math.min(1, depth_levels / MAX_DEPTH_FOR_CHANCE)
    return 0.1 + (0.3333333 - 0.1) * t
end

local function start_storm(state, runtime)
    print("storm!")
    runtime.active = true
    runtime.storm_timer = 0
    runtime.next_bolt_timer = 0.2 + math.random() * 0.6
    runtime.pending_dots = {}
    runtime.active_bolts = {}
    storm.water_intense(state, true)
    play_rain_loop()
end

local function stop_storm(state, runtime)
    runtime.active = false
    runtime.storm_timer = 0
    runtime.next_bolt_timer = SPAWN_CHECK_INTERVAL * 0.5
    runtime.pending_dots = {}
    runtime.active_bolts = {}
    storm.water_intense(state, false)
    stop_rain_loop()
end

function storm.debug_start(state)
    local runtime = ensure_runtime(state)
    start_storm(state, runtime)
    runtime.next_bolt_timer = 0.05
    runtime.pending_dots = {}
    runtime.active_bolts = {}
end

function storm.set_audio_volume_multiplier(mult)
    audio_volume_multiplier = math.max(0, math.min(1, tonumber(mult) or 1))
    apply_rain_volume()
end

function storm.force_stop(state)
    local runtime = ensure_runtime(state)
    stop_storm(state, runtime)
end

function storm.update(state, dt)
    local runtime = ensure_runtime(state)
    local player = state.system.player
    local camera = state.system.camera
    local fishing_level = state.constants.fishing_level or 1000
    local now = (love.timer and love.timer.getTime and love.timer.getTime()) or 0

    if not runtime.active then
        if not is_night(player) then
            return
        end
        runtime.check_timer = (tonumber(runtime.check_timer) or SPAWN_CHECK_INTERVAL) - dt
        if runtime.check_timer <= 0 then
            runtime.check_timer = SPAWN_CHECK_INTERVAL
            local spawn_chance = storm.get_spawn_chance(player.y, fishing_level)
            if math.random() < spawn_chance then
                start_storm(state, runtime)
            end
        end
        return
    end

    runtime.next_bolt_timer = runtime.next_bolt_timer - dt
    if runtime.next_bolt_timer <= 0 then
        local burst_count = love.math.random(BOLT_BURST_MIN, BOLT_BURST_MAX)
        for _ = 1, burst_count do
            local strike_point = pick_strike_point_around_player(player)
            table.insert(runtime.pending_dots, {
                x = strike_point.x,
                y = strike_point.y,
                started_at = now,
                stage = 1
            })
        end
        runtime.next_bolt_timer = BOLT_INTERVAL_MIN + math.random() * (BOLT_INTERVAL_MAX - BOLT_INTERVAL_MIN)
    end

    for i = #runtime.pending_dots, 1, -1 do
        local dot = runtime.pending_dots[i]
        local progress = (now - dot.started_at) / WARNING_DURATION
        if progress >= 0.66 then
            dot.stage = 3
        elseif progress >= 0.33 then
            dot.stage = 2
        else
            dot.stage = 1
        end

        if progress >= 1.0 then
            local top_point = {
                x = dot.x + love.math.random(-35, 35),
                y = camera.y - 80
            }
            local bottom_point = {
                x = dot.x,
                y = dot.y
            }
            local track, thickness = build_lightning_track(top_point, bottom_point)
            table.insert(runtime.active_bolts, {
                track = track,
                thickness = thickness,
                ends_at = now + BOLT_DURATION
            })

            local player_radius = tonumber(player.radius) or 20
            local strike_dx = (dot.x or 0) - (player.x or 0)
            local strike_dy = (dot.y or 0) - (player.y or 0)
            local strike_dist_sq = (strike_dx * strike_dx) + (strike_dy * strike_dy)
            if strike_dist_sq <= (player_radius * player_radius) then
                runtime.player_touched_by_strike = true
                runtime.player_touched_by_strike_at = now
                local current_state = state.system.gamestate.get()
                if current_state ~= state.system.gametype.SHIPWRECKED then
                    local time_system = (player and player.time_system) or {}
                    time_system.is_fading = false
                    time_system.is_sleeping = false
                    time_system.fade_alpha = 0
                    time_system.fade_timer = 0
                    time_system.fade_direction = "in"

                    player.is_swimming = true
                    player.is_on_foot = true
                    player.shipwreck_landed = false
                    player.shipwreck_sleep_timer = 0
                    player.shipwreck_land_dock_x = nil
                    player.shipwreck_land_dock_y = nil
                    player.boat_hidden_until_morning = true
                    state.shipwreck_reached_land = false
                    state.shipwreck_landfall_pending_recovery = false
                    player.pending_shop_interaction = false
                    player.velocity_x = 0
                    player.velocity_y = 0
                    player.on_foot_x = player.x
                    player.on_foot_y = player.y
                    state.drowning = tonumber(state.constants and state.constants.ship and state.constants.ship.drowning_time) or 6
                    state.shipwreck_game_over = nil

                    state.system.gamestate.set(state.system.gametype.SHIPWRECKED)
                    state.system.alert.title("Swim to land!!!", 5, {1, 1, 1, 0.7}, 1, 1)
                end
            end

            play_lightning_sound(dot.x, dot.y, player)
            table.remove(runtime.pending_dots, i)
        end
    end

    for i = #runtime.active_bolts, 1, -1 do
        if now >= runtime.active_bolts[i].ends_at then
            table.remove(runtime.active_bolts, i)
        end
    end
end

function storm.draw(state)
    local runtime = ensure_runtime(state)
    for i = 1, #runtime.pending_dots do
        storm.draw_lightning_dot(runtime.pending_dots[i])
    end
    for i = 1, #runtime.active_bolts do
        local bolt = runtime.active_bolts[i]
        draw_lightning_track(bolt.track, bolt.thickness)
    end
end

return storm
