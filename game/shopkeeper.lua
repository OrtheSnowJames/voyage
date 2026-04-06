local shopkeeper_factory = {}

local SHEET_PATH = "assets/Pirates Yellow Sprite Sheet.png"
local FRAME_W = 16
local FRAME_H = 16
local SPRITE_SCALE = 2
local BASE_COL_START = 0
local OUTFIT_COL_START = 8 -- third 3-frame outfit block
local ROW_BY_DIR = {
    down = 0,
    up = 1,
    left = 3,
    right = 2
}

local function build_quads(sheet, col_start)
    local quads = {}
    for dir, row in pairs(ROW_BY_DIR) do
        quads[dir] = {
            love.graphics.newQuad((col_start + 0) * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H, sheet:getWidth(), sheet:getHeight()),
            love.graphics.newQuad((col_start + 1) * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H, sheet:getWidth(), sheet:getHeight()),
            love.graphics.newQuad((col_start + 2) * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H, sheet:getWidth(), sheet:getHeight())
        }
    end
    return quads
end

local function facing_direction(from_x, from_y, to_x, to_y)
    local dx = (to_x or from_x) - from_x
    local dy = (to_y or from_y) - from_y
    if math.abs(dx) > math.abs(dy) then
        return dx >= 0 and "right" or "left"
    end
    return dy >= 0 and "down" or "up"
end

function shopkeeper_factory.create(deps)
    local shore_offset_y = deps.main_shopkeeper_shore_offset_y or 0
    local dock_base_y = deps.shore_division - 16
    local sprite_sheet = love.graphics.newImage(SHEET_PATH)
    local shopkeeper = {
        x = 0,
        y = dock_base_y + shore_offset_y,
        dock_x = 0,
        dock_y = dock_base_y,
        size = 15,
        color = {1, 0.8, 0.2, 1},
        interaction_range = 70,
        is_spawned = false,

        sprite_sheet = sprite_sheet,
        base_quads = build_quads(sprite_sheet, BASE_COL_START),
        outfit_quads = build_quads(sprite_sheet, OUTFIT_COL_START),
        frame_width = FRAME_W,
        frame_height = FRAME_H,
        sprite_scale = SPRITE_SCALE,
        frame_time = 0.25,
        current_frame = 1,
        total_frames = 3,
        timer = 0
    }

    function shopkeeper:update(ship_x, _, dt)
        local base_y = deps.shore_division - 16
        self.dock_y = base_y
        self.y = base_y + shore_offset_y

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
                self.dock_x = ship_x + spawn_offset
                self.is_spawned = true
            end
            local side_offset = deps.main_shopkeeper_side_offset_x or 42
            self.x = self.dock_x + side_offset
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
            local actor_x = deps.player_ship.is_on_foot and deps.player_ship.on_foot_x or deps.player_ship.x
            local actor_y = deps.player_ship.is_on_foot and deps.player_ship.on_foot_y or deps.player_ship.y
            local distance = math.sqrt((self.x - actor_x)^2 + (self.y - actor_y)^2)
            local in_range = distance <= self.interaction_range
            local dir = facing_direction(self.x, self.y, actor_x, actor_y)
            local base_quad = (self.base_quads[dir] or self.base_quads.down)[self.current_frame]
            local outfit_quad = (self.outfit_quads[dir] or self.outfit_quads.down)[self.current_frame]

            if in_range then
                love.graphics.setColor(1, 1, 0)
            else
                love.graphics.setColor(1, 1, 1)
            end

            love.graphics.draw(
                self.sprite_sheet,
                base_quad,
                self.x,
                self.y,
                0,
                self.sprite_scale,
                self.sprite_scale,
                self.frame_width / 2,
                self.frame_height / 2
            )
            love.graphics.draw(
                self.sprite_sheet,
                outfit_quad,
                self.x,
                self.y,
                0,
                self.sprite_scale,
                self.sprite_scale,
                self.frame_width / 2,
                self.frame_height / 2
            )

            love.graphics.setColor(1, 1, 1, 1)

            if in_range then
                love.graphics.print('SHOP', self.x - 20, self.y - (self.frame_height * self.sprite_scale))
            end
        end
    end

    function shopkeeper:can_interact()
        if not self.is_spawned then
            return false
        end

        if not deps.player_ship.is_on_foot then
            return false
        end

        local actor_x = deps.player_ship.on_foot_x or deps.player_ship.x
        local actor_y = deps.player_ship.on_foot_y or deps.player_ship.y
        local distance = math.sqrt((self.x - actor_x)^2 + (self.y - actor_y)^2)
        return distance <= self.interaction_range
    end

    return shopkeeper
end

return shopkeeper_factory
