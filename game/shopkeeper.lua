local shopkeeper_factory = {}

function shopkeeper_factory.create(deps)
    local shopkeeper = {
        x = 0,
        y = deps.shore_division - 16,
        size = 15,
        color = {1, 0.8, 0.2, 1},
        interaction_range = 70,
        is_spawned = false,

        sprite = love.graphics.newImage('assets/shopkeeper.png'),
        frame_width = 32,
        frame_height = 32,
        frame_time = 0.5,
        current_frame = 1,
        total_frames = 2,
        timer = 0
    }

    function shopkeeper:update(ship_x, _, dt)
        self.y = deps.shore_division - 16

        self.timer = self.timer + dt
        if self.timer >= self.frame_time then
            self.timer = self.timer - self.frame_time
            self.current_frame = self.current_frame % self.total_frames + 1
        end

        local view_top = deps.camera.y
        local view_height = love.graphics.getHeight() / deps.camera.scale
        local is_shore_visible = view_top <= deps.shore_division and view_top + view_height >= deps.shore_division

        if is_shore_visible then
            if not self.is_spawned then
                local spawn_offset = deps.player_ship.velocity_x > 0 and 200 or -200
                self.x = ship_x + spawn_offset
                self.is_spawned = true
            end
        else
            self.is_spawned = false
        end
    end

    function shopkeeper:draw()
        if not self.is_spawned then
            return
        end

        local view_left = deps.camera.x
        local view_width = deps.size.CANVAS_WIDTH / deps.camera.scale

        if self.x >= view_left - 50 and self.x <= view_left + view_width + 50 then
            local quad = love.graphics.newQuad(
                (self.current_frame - 1) * self.frame_width,
                0,
                self.frame_width,
                self.frame_height,
                self.sprite:getWidth(),
                self.sprite:getHeight()
            )

            local distance = math.sqrt((self.x - deps.player_ship.x)^2 + (self.y - deps.player_ship.y)^2)
            local in_range = distance <= self.interaction_range

            if in_range then
                love.graphics.setColor(1, 1, 0)
            else
                love.graphics.setColor(1, 1, 1)
            end

            love.graphics.draw(
                self.sprite,
                quad,
                self.x,
                self.y,
                0,
                1,
                1,
                self.frame_width / 2,
                self.frame_height / 2
            )

            love.graphics.setColor(1, 1, 1, 1)

            if in_range then
                love.graphics.print('SHOP', self.x - 20, self.y - self.frame_height)
            end
        end
    end

    function shopkeeper:can_interact()
        if not self.is_spawned then
            return false
        end

        local distance = math.sqrt((self.x - deps.player_ship.x)^2 + (self.y - deps.player_ship.y)^2)
        return distance <= self.interaction_range
    end

    return shopkeeper
end

return shopkeeper_factory
