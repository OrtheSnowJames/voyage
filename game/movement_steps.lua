local movement_steps = {}
local extra_math = require("game.extra_math")
local clamp = extra_math.clamp

local control_corruption = {
    timer = 0,
    turn_jitter = 0,
    drift_x = 0,
    drift_y = 0
}

local function refresh_control_corruption(strength)
    control_corruption.timer = 0.05 + love.math.random() * 0.08
    control_corruption.turn_jitter = (love.math.random() * 2 - 1) * 0.9 * strength
    control_corruption.drift_x = (love.math.random() * 2 - 1) * 28 * strength
    control_corruption.drift_y = (love.math.random() * 2 - 1) * 22 * strength
end

local function clamp_to_rect(px, py, rx, ry, rw, rh)
    return clamp(px, rx, rx + rw), clamp(py, ry, ry + rh)
end

local function clamp_to_circle(px, py, cx, cy, r)
    local dx = px - cx
    local dy = py - cy
    local dist_sq = (dx * dx) + (dy * dy)
    if dist_sq <= (r * r) then
        return px, py
    end
    local dist = math.sqrt(dist_sq)
    if dist <= 0.0001 then
        return cx, cy - r
    end
    local s = r / dist
    return cx + (dx * s), cy + (dy * s)
end

function movement_steps.update_player_ship(self, dt, ctx)
    local mobile_controls = ctx.mobile_controls

    if ctx.gamestate == ctx.GameType.SHIPWRECKED and self.shipwreck_landed then
        self.velocity_x = 0
        self.velocity_y = 0
        self.is_swimming = false
        self.is_on_foot = true
        self.on_foot_x = self.on_foot_x or self.x
        self.on_foot_y = self.on_foot_y or self.y
        ctx.update_ship_animation(dt)
        return
    end

    if self.is_swimming then
        local move_x = 0
        local move_y = 0

        if love.keyboard.isDown("a") or mobile_controls.buttons.left.pressed then
            move_x = move_x - 1
        end
        if love.keyboard.isDown("d") or mobile_controls.buttons.right.pressed then
            move_x = move_x + 1
        end
        if love.keyboard.isDown("w") or mobile_controls.buttons.forward.pressed then
            move_y = move_y - 1
        end
        if love.keyboard.isDown("s") then
            move_y = move_y + 1
        end

        local len = math.sqrt((move_x * move_x) + (move_y * move_y))
        if len > 0 then
            move_x = move_x / len
            move_y = move_y / len
        end

        local swim_speed = ctx.swim_speed or 70
        self.x = (self.x or 0) + (move_x * swim_speed * dt)
        self.y = (self.y or 0) + (move_y * swim_speed * dt)
        local min_swim_y = (ctx.shore_division or 0) + 30
        if self.y < min_swim_y then
            self.y = min_swim_y
        end

        self.on_foot_x = self.x
        self.on_foot_y = self.y
        self.velocity_x = 0
        self.velocity_y = 0
        ctx.update_ship_animation(dt)
        return
    end

    if self.is_on_foot then
        local move_x = 0
        local move_y = 0

        if love.keyboard.isDown("a") or mobile_controls.buttons.left.pressed then
            move_x = move_x - 1
        end
        if love.keyboard.isDown("d") or mobile_controls.buttons.right.pressed then
            move_x = move_x + 1
        end
        if love.keyboard.isDown("w") or mobile_controls.buttons.forward.pressed then
            move_y = move_y - 1
        end
        if love.keyboard.isDown("s") then
            move_y = move_y + 1
        end

        local len = math.sqrt((move_x * move_x) + (move_y * move_y))
        if len > 0 then
            move_x = move_x / len
            move_y = move_y / len
        end

        local walk_speed = ctx.on_foot_speed or 125
        self.on_foot_x = (self.on_foot_x or self.x) + (move_x * walk_speed * dt)
        self.on_foot_y = (self.on_foot_y or self.y) + (move_y * walk_speed * dt)

        local walk_center_x = ctx.walk_center_x or self.x
        local walk_center_y = ctx.walk_center_y or (ctx.shore_division - 30)
        local max_walk_side = ctx.on_foot_max_walk_side or 260
        local max_walk_up = ctx.on_foot_max_walk_up or 240
        local max_walk_down = ctx.on_foot_max_walk_down or 24
        local on_foot_bounds_mode = ctx.on_foot_bounds_mode or "shore"
        local dock_x = ctx.dock_x
        local dock_bottom_y = ctx.dock_bottom_y
        local dock_half_width = ctx.dock_walk_half_width or 20
        local dock_height = ctx.dock_height or 26

        local min_x = walk_center_x - max_walk_side
        local max_x = walk_center_x + max_walk_side
        local min_y = walk_center_y - max_walk_up
        local max_y = walk_center_y + max_walk_down

        if on_foot_bounds_mode == "shore" then
            local shoreline_y = (ctx.shore_division or 0) - 20
            max_y = shoreline_y
            if dock_x and dock_bottom_y and math.abs(self.on_foot_x - dock_x) <= dock_half_width then
                max_y = math.max(shoreline_y, dock_bottom_y)
            end
        end

        self.on_foot_x = math.max(min_x, math.min(max_x, self.on_foot_x))
        self.on_foot_y = math.max(min_y, math.min(max_y, self.on_foot_y))

        -- Port island mode: allow only island circle and dock plank, never free water.
        local island_radius = tonumber(ctx.foot_island_radius)
        if island_radius and island_radius > 0 and dock_x and dock_bottom_y then
            local px = self.on_foot_x
            local py = self.on_foot_y
            local cx = walk_center_x
            local cy = walk_center_y
            local in_circle = ((px - cx) * (px - cx) + (py - cy) * (py - cy)) <= (island_radius * island_radius)

            local dock_rect_x = dock_x - dock_half_width
            local dock_rect_y = dock_bottom_y - dock_height
            local dock_rect_w = dock_half_width * 2
            local dock_rect_h = dock_height
            local in_dock = (px >= dock_rect_x and px <= dock_rect_x + dock_rect_w and py >= dock_rect_y and py <= dock_rect_y + dock_rect_h)

            if not in_circle and not in_dock then
                local cx1, cy1 = clamp_to_circle(px, py, cx, cy, island_radius)
                local cx2, cy2 = clamp_to_rect(px, py, dock_rect_x, dock_rect_y, dock_rect_w, dock_rect_h)

                local d1 = ((px - cx1) * (px - cx1)) + ((py - cy1) * (py - cy1))
                local d2 = ((px - cx2) * (px - cx2)) + ((py - cy2) * (py - cy2))

                if d1 <= d2 then
                    self.on_foot_x = cx1
                    self.on_foot_y = cy1
                else
                    self.on_foot_x = cx2
                    self.on_foot_y = cy2
                end
            end
        end

        self.velocity_x = 0
        self.velocity_y = 0
        ctx.update_ship_animation(dt)
        return
    end

    -- Collision turnaround behavior (triggered by island collision in shop/port.lua):
    -- stop briefly, rotate away from island, then force a short retreat.
    if (tonumber(self.collision_turnaround_timer) or 0) > 0 then
        local timer = tonumber(self.collision_turnaround_timer) or 0
        timer = math.max(0, timer - dt)
        self.collision_turnaround_timer = timer

        local target = tonumber(self.collision_turnaround_target_rotation) or self.rotation
        self.target_rotation = target
        local rotation_diff = self.target_rotation - self.rotation
        self.rotation = self.rotation + rotation_diff * 6 * dt

        if timer > 0.5 then
            self.velocity_x = 0
            self.velocity_y = 0
        elseif timer > 0.22 then
            self.velocity_x = (self.velocity_x or 0) * 0.5
            self.velocity_y = (self.velocity_y or 0) * 0.5
        else
            local away_x = tonumber(self.collision_turnaround_away_x) or math.cos(target)
            local away_y = tonumber(self.collision_turnaround_away_y) or math.sin(target)
            local retreat_speed = math.max(90, (tonumber(self.max_speed) or 180) * 0.45)
            self.velocity_x = away_x * retreat_speed
            self.velocity_y = away_y * retreat_speed
        end

        local new_x = self.x + (self.velocity_x or 0) * dt
        local new_y = self.y + (self.velocity_y or 0) * dt
        local min_shore_distance = 40
        if new_y <= ctx.shore_division + min_shore_distance then
            new_y = ctx.shore_division + min_shore_distance
            self.velocity_y = math.max(0, self.velocity_y or 0)
        end
        self.x = new_x
        self.y = new_y

        if timer <= 0 then
            self.collision_turnaround_target_rotation = nil
            self.collision_turnaround_away_x = nil
            self.collision_turnaround_away_y = nil
        end

        ctx.update_ship_animation(dt)
        return
    end

    local turning = false
    if love.keyboard.isDown("a") or mobile_controls.buttons.left.pressed then
        self.target_rotation = self.target_rotation - self.turn_speed * dt
        turning = true
    end
    if love.keyboard.isDown("d") or mobile_controls.buttons.right.pressed then
        self.target_rotation = self.target_rotation + self.turn_speed * dt
        turning = true
    end

    local rotation_diff = self.target_rotation - self.rotation
    self.rotation = self.rotation + rotation_diff * 5 * dt

    local forward_x = math.cos(self.rotation)
    local forward_y = math.sin(self.rotation)

    local accelerating = false
    if love.keyboard.isDown("w") or mobile_controls.buttons.forward.pressed then
        self.velocity_x = self.velocity_x + forward_x * self.acceleration * dt
        self.velocity_y = self.velocity_y + forward_y * self.acceleration * dt
        accelerating = true
    end
    if love.keyboard.isDown("s") then
        self.velocity_x = self.velocity_x - forward_x * self.acceleration * self.reverse_multiplier * dt
        self.velocity_y = self.velocity_y - forward_y * self.acceleration * self.reverse_multiplier * dt
        accelerating = true
    end

    local current_rainbows = ctx.normalize_rainbows(self.rainbows)
    if current_rainbows >= 0.2 then
        local corruption_strength = math.min(1, 0.45 + ((current_rainbows - 0.2) * 2.0))
        control_corruption.timer = control_corruption.timer - dt
        if control_corruption.timer <= 0 then
            refresh_control_corruption(corruption_strength)
        end

        local smooth_wobble = math.sin(self.time_system.time * 3.1 + self.x * 0.01) * self.turn_speed * 0.2 * corruption_strength
        local wobble = smooth_wobble + control_corruption.turn_jitter
        self.target_rotation = self.target_rotation + wobble * dt

        local drift_x = math.sin(self.time_system.time * 2.2 + self.y * 0.01) * 10 * corruption_strength + control_corruption.drift_x
        local drift_y = math.cos(self.time_system.time * 2.7 + self.x * 0.01) * 8 * corruption_strength + control_corruption.drift_y
        self.velocity_x = self.velocity_x + drift_x * dt
        self.velocity_y = self.velocity_y + drift_y * dt
    else
        control_corruption.timer = 0
        control_corruption.turn_jitter = 0
        control_corruption.drift_x = 0
        control_corruption.drift_y = 0
    end

    local speed_multiplier = turning and self.turn_penalty or 1
    local current_speed = math.sqrt(self.velocity_x * self.velocity_x + self.velocity_y * self.velocity_y)

    if current_speed > self.max_speed * speed_multiplier then
        local scale = (self.max_speed * speed_multiplier) / current_speed
        self.velocity_x = self.velocity_x * scale
        self.velocity_y = self.velocity_y * scale
    end

    if not accelerating then
        self.velocity_x = self.velocity_x * (1 - self.deceleration * dt)
        self.velocity_y = self.velocity_y * (1 - self.deceleration * dt)
    end

    local new_x = self.x + self.velocity_x * dt
    local new_y = self.y + self.velocity_y * dt

    local min_shore_distance = 40
    if new_y <= ctx.shore_division + min_shore_distance then
        new_y = ctx.shore_division + min_shore_distance
        self.velocity_y = math.max(0, self.velocity_y)
        self.velocity_x = self.velocity_x * 0.98
    end

    self.x = new_x
    self.y = new_y

    local dist_since_last_ripple = math.sqrt((self.x - ctx.last_player_ripple_pos.x)^2 + (self.y - ctx.last_player_ripple_pos.y)^2)
    local speed = math.sqrt(self.velocity_x^2 + self.velocity_y^2)

    if speed > 20 and dist_since_last_ripple > ctx.RIPPLE_SPAWN_DIST then
        table.insert(ctx.ship_ripples, 1, {
            x = self.x,
            y = self.y,
            spawn_time = self.time_system.time,
            intensity = math.min(1.0, speed / self.max_speed)
        })
        ctx.last_player_ripple_pos.x = self.x
        ctx.last_player_ripple_pos.y = self.y
        if #ctx.ship_ripples > ctx.MAX_RIPPLES then
            table.remove(ctx.ship_ripples)
        end
    end

    ctx.update_ship_animation(dt)
end

function movement_steps.camera_goto(camera, x, y)
    camera.x = x
    camera.y = y
end

function movement_steps.camera_zoom(camera, factor, target_x, target_y, size)
    local old_scale = camera.scale
    camera.scale = camera.scale * factor

    if target_x and target_y then
        local screen_width = size.CANVAS_WIDTH
        local screen_height = size.CANVAS_HEIGHT

        local center_x = screen_width / 2
        local center_y = screen_height / 2

        local dx = (target_x * old_scale - center_x) / old_scale - (target_x * camera.scale - center_x) / camera.scale
        local dy = (target_y * old_scale - center_y) / old_scale - (target_y * camera.scale - center_y) / camera.scale

        camera.x = camera.x + dx
        camera.y = camera.y + dy
    else
        local mx, my = size.CANVAS_WIDTH / 2, size.CANVAS_HEIGHT / 2
        local dx = mx / old_scale - mx / camera.scale
        local dy = my / old_scale - my / camera.scale

        camera.x = camera.x + dx
        camera.y = camera.y + dy
    end
end

return movement_steps
