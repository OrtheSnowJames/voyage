local movement_steps = {}

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

function movement_steps.update_player_ship(self, dt, ctx)
    local mobile_controls = ctx.mobile_controls

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
