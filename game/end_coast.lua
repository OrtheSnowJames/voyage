-- the far coastline at the end of the last fishing zone: a dock and Jonas's house.
-- It spawns the way the shopkeeper does: once the coast is in view it appears near the ship,
-- ahead of its direction of travel, and it despawns when the coast leaves the view.
local end_coast_factory = {}

local HOUSE_PATH = "assets/house.png"
local SPAWN_DISTANCE = 200
local VIEW_MARGIN = 250
-- the opaque part of house.png (the top rows are empty); in image pixels
local HOUSE_SOLID = {x = 0, y = 9, w = 64, h = 55}

function end_coast_factory.create(deps)
    local C = deps.constants.end_coast
    local house_image = love.graphics.newImage(HOUSE_PATH)

    local coast = {
        x = 0,
        dock_x = 0,
        is_spawned = false,
        house_image = house_image
    }

    function coast:get_y()
        return deps.get_y()
    end

    -- the dock reaches from the land (down the screen) out to its tip at the waterline
    function coast:get_dock_geometry()
        local y = self:get_y()
        local base_y = y + C.dock_base_offset_y
        return {
            x = self.dock_x,
            tip_y = y,
            base_y = base_y,
            land_y = y + C.dock_length
        }
    end

    function coast:update(ship_x, dt)
        local coast_y = self:get_y()
        local camera = deps.camera
        local view_top = camera.y
        local view_height = love.graphics.getHeight() / camera.scale
        local is_coast_visible = view_top <= coast_y + VIEW_MARGIN and view_top + view_height >= coast_y - VIEW_MARGIN

        if not is_coast_visible then
            self.is_spawned = false
            return
        end

        if not self.is_spawned then
            local ship = deps.player_ship
            local saved_dock_x = tonumber(ship.dock_walk_dock_x)
            if ship.is_on_foot and ship.dock_walk_mode == "end_coast" and saved_dock_x then
                -- loaded a save while standing on this dock: rebuild the coast around it
                self.dock_x = saved_dock_x
            else
                local spawn_offset = (ship.velocity_x or 0) > 0 and SPAWN_DISTANCE or -SPAWN_DISTANCE
                self.dock_x = ship_x + spawn_offset
            end
            self.is_spawned = true
        end
        self.x = self.dock_x + C.house_side_offset_x
    end

    function coast:can_dock(ship)
        if not self.is_spawned or not ship or ship.is_on_foot then
            return false
        end
        local near_dock_x = math.abs((ship.x or 0) - self.dock_x) <= C.dock_interaction_range
        local near_shoreline = (ship.y or 0) >= self:get_y() - C.dock_boat_range
        return near_dock_x and near_shoreline
    end

    -- steps the captain onto the dock; the on-foot bounds are mirrored from the starting shore
    function coast:try_dock(ship)
        if not self:can_dock(ship) then
            return false
        end

        local dock = self:get_dock_geometry()
        ship.is_on_foot = true
        ship.velocity_x = 0
        ship.velocity_y = 0
        ship.target_rotation = ship.rotation
        ship.pending_shop_interaction = false
        ship.on_foot_x = dock.x
        ship.on_foot_y = dock.base_y + C.disembark_offset_y
        ship.dock_walk_center_x = dock.x
        ship.dock_walk_center_y = dock.base_y
        ship.dock_walk_dock_x = dock.x
        ship.dock_walk_dock_y = dock.tip_y
        ship.docked_port_shop_index = nil
        ship.dock_walk_mode = "end_coast"
        ship.dock_walk_island_radius = nil
        ship.dock_walk_dock_half_width = nil
        ship.dock_walk_dock_height = nil
        ship.dock_walk_max_side = C.walk_max_side
        ship.dock_walk_max_up = C.walk_max_depth -- how far inland the captain can walk
        ship.dock_walk_max_down = nil
        return true
    end

    -- where the house is, as a world rectangle for on-foot collision; nil while the coast is not spawned
    function coast:get_house_rect()
        if not self.is_spawned then
            return nil
        end

        local scale = C.house_scale
        local image_w = house_image:getWidth()
        local image_h = house_image:getHeight()
        local center_y = self:get_y() + C.house_land_offset_y
        local pad = C.house_collision_padding
        return {
            x = self.x - (image_w / 2 - HOUSE_SOLID.x) * scale - pad,
            y = center_y - (image_h / 2 - HOUSE_SOLID.y) * scale - pad,
            w = HOUSE_SOLID.w * scale + pad * 2,
            h = HOUSE_SOLID.h * scale + pad * 2
        }
    end

    function coast:draw_dock()
        if not self.is_spawned then
            return
        end

        local dock = self:get_dock_geometry()
        local width = C.dock_width
        local top = dock.tip_y
        local height = dock.land_y - dock.tip_y

        love.graphics.setColor(0.47, 0.31, 0.16, 1)
        love.graphics.rectangle("fill", dock.x - width / 2, top, width, height)
        love.graphics.setColor(0.62, 0.43, 0.23, 1)
        love.graphics.rectangle("line", dock.x - width / 2, top, width, height)
        love.graphics.setColor(1, 1, 1, 1)
    end

    function coast:draw_house()
        if not self.is_spawned then
            return
        end

        local view_left = deps.camera.x
        local view_width = deps.size.CANVAS_WIDTH / deps.camera.scale
        if self.x < view_left - 150 or self.x > view_left + view_width + 150 then
            return
        end

        local scale = C.house_scale
        local image_w = house_image:getWidth()
        local image_h = house_image:getHeight()
        local center_y = self:get_y() + C.house_land_offset_y
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(house_image, self.x, center_y, 0, scale, scale, image_w / 2, image_h / 2)
    end

    function coast:draw()
        self:draw_dock()
        self:draw_house()
    end

    function coast:reset()
        self.is_spawned = false
        self.dock_x = 0
        self.x = 0
    end

    return coast
end

return end_coast_factory
