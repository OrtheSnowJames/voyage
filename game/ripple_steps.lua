local ripple_steps = {}

function ripple_steps.spawn(system, player_ship, camera, size, x, y)
    if #system.particles >= system.maxParticles then
        return
    end

    local view_left = camera.x
    local view_top = camera.y
    local view_width = size.CANVAS_WIDTH / camera.scale
    local view_height = size.CANVAS_HEIGHT / camera.scale

    local ripple_x = x or (view_left + math.random() * view_width)
    local ripple_y = y or (view_top + view_height + system.spawnMargin)
    local ripple_vy = -love.math.random(20, 40)

    if player_ship and not x and not y then
        local player_speed = math.sqrt(player_ship.velocity_x^2 + player_ship.velocity_y^2)
        local moving_toward_shore = player_ship.velocity_y < -10
        local moving_away_from_shore = player_ship.velocity_y > 10

        if moving_toward_shore then
            ripple_y = view_top - system.spawnMargin
            ripple_vy = -love.math.random(20, 40)
        elseif moving_away_from_shore then
            ripple_y = view_top + view_height + system.spawnMargin
            ripple_vy = -love.math.random(20, 40)
        else
            if math.random() < 0.5 then
                ripple_y = view_top - system.spawnMargin
            else
                ripple_y = view_top + view_height + system.spawnMargin
            end
            ripple_vy = -love.math.random(20, 40)
        end

        if player_speed > 50 then
            local spawn_range = math.min(view_width, 400)
            ripple_x = player_ship.x + (math.random() - 0.5) * spawn_range
        end
    end

    local spacing = 50 + math.random() * 100
    local positions = {
        {x = ripple_x - spacing, y = ripple_y},
        {x = ripple_x, y = ripple_y},
        {x = ripple_x + spacing, y = ripple_y}
    }

    for _, pos in ipairs(positions) do
        if #system.particles < system.maxParticles then
            table.insert(system.particles, {
                x = pos.x,
                y = pos.y,
                vy = ripple_vy + love.math.random(-5, 5),
                size = love.math.random(3, 6),
                alpha = 1,
                maxLife = love.math.random(3, 6),
                life = 0
            })
        end
    end
end

function ripple_steps.update(system, dt, player_ship, camera, size)
    local player_speed = math.sqrt(player_ship.velocity_x^2 + player_ship.velocity_y^2)
    local speed_multiplier = 1 + (player_speed / 100)
    local current_spawn_rate = system.baseSpawnRate / speed_multiplier

    local view_left = camera.x
    local view_top = camera.y
    local view_width = size.CANVAS_WIDTH / camera.scale
    local view_height = size.CANVAS_HEIGHT / camera.scale

    local visible_ripples = 0
    for _, p in ipairs(system.particles) do
        if p.x >= view_left - system.spawnMargin and
           p.x <= view_left + view_width + system.spawnMargin and
           p.y >= view_top - system.spawnMargin and
           p.y <= view_top + view_height + system.spawnMargin then
            visible_ripples = visible_ripples + 1
        end
    end

    system.spawnTimer = system.spawnTimer + dt
    if system.spawnTimer >= current_spawn_rate then
        ripple_steps.spawn(system, player_ship, camera, size)
        system.spawnTimer = 0
    end

    if visible_ripples < system.minVisibleRipples then
        local needed_ripples = system.minVisibleRipples - visible_ripples
        for _ = 1, needed_ripples do
            ripple_steps.spawn(system, player_ship, camera, size)
        end
    end

    for i = #system.particles, 1, -1 do
        local p = system.particles[i]

        p.y = p.y + p.vy * dt
        p.life = p.life + dt
        p.alpha = 1 - (p.life / p.maxLife)

        if p.life >= p.maxLife or
           p.x < view_left - system.spawnMargin or
           p.x > view_left + view_width + system.spawnMargin or
           p.y < view_top - system.spawnMargin * 2 then
            table.remove(system.particles, i)
        end
    end
end

function ripple_steps.draw(system, camera, size)
    local view_left = camera.x
    local view_top = camera.y
    local view_width = size.CANVAS_WIDTH / camera.scale
    local view_height = size.CANVAS_HEIGHT / camera.scale

    love.graphics.setLineWidth(1)
    for _, p in ipairs(system.particles) do
        if p.x >= view_left - system.spawnMargin and
           p.x <= view_left + view_width + system.spawnMargin and
           p.y >= view_top - system.spawnMargin and
           p.y <= view_top + view_height + system.spawnMargin then
            love.graphics.setColor(1, 1, 1, p.alpha * 0.5)

            local s = p.size
            love.graphics.rectangle("fill", p.x - s, p.y - s, s / 2, s / 2)
            love.graphics.rectangle("fill", p.x + s / 2, p.y - s, s / 2, s / 2)
            love.graphics.rectangle("fill", p.x - s * 1.5, p.y, s / 2, s / 2)
            love.graphics.rectangle("fill", p.x + s, p.y, s / 2, s / 2)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return ripple_steps
