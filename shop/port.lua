local port = {}

local function ray_x_at_y(x0, y0, theta, targetY)
    local dy = math.sin(theta)

    -- avoid divide by zero (horizontal ray)
    if math.abs(dy) < 0.00001 then
        return nil
    end

    local t = (targetY - y0) / dy
    return x0 + math.cos(theta) * t
end

function port.create(deps)
    local constants = deps.constants
    local size = deps.size
    local sand = deps.sand

    local DOCK_INTERACTION_RANGE = constants.shops.dock_interaction_range or 85
    local BOARD_INTERACTION_RANGE = constants.shops.board_interaction_range or 90
    local DOCK_TIP_OFFSET_Y = constants.shops.dock_tip_offset_y or 74
    local DISEMBARK_OFFSET_Y = constants.shops.disembark_offset_y or -18
    local SHORE_DIVISION = constants.world.shore_division or 60
    local SHOP_SPACING = constants.fishing_level
    local INTERACTION_RANGE = 70
    local PORT_DOCK_WIDTH = 30
    local PORT_DOCK_HEIGHT = 30
    local PORT_DOCK_TOP_OVERLAP = 8
    local PORT_SHOPKEEPER_VERTICAL_FACTOR = 0.58
    local animation_frame_time = 0.5
    local sprite_frame_width = 16
    local sprite_frame_height = 16
    local sprite_scale = 2
    local total_frames = 3
    local base_col_start = 0
    local outfit_col_start = 8 -- third 3-frame outfit block
    local row_by_dir = {
        down = 0,
        up = 1,
        left = 3,
        right = 2
    }

    local port_a_shops = {}
    local port_shop_island_cache = {}
    local shopkeeper_sprite = love.graphics.newImage("assets/Pirates Yellow Sprite Sheet.png")
    local last_player_ship = nil

    local function build_quads(col_start)
        local quads = {}
        for dir, row in pairs(row_by_dir) do
            quads[dir] = {
                love.graphics.newQuad((col_start + 0) * sprite_frame_width, row * sprite_frame_height, sprite_frame_width, sprite_frame_height, shopkeeper_sprite:getWidth(), shopkeeper_sprite:getHeight()),
                love.graphics.newQuad((col_start + 1) * sprite_frame_width, row * sprite_frame_height, sprite_frame_width, sprite_frame_height, shopkeeper_sprite:getWidth(), shopkeeper_sprite:getHeight()),
                love.graphics.newQuad((col_start + 2) * sprite_frame_width, row * sprite_frame_height, sprite_frame_width, sprite_frame_height, shopkeeper_sprite:getWidth(), shopkeeper_sprite:getHeight())
            }
        end
        return quads
    end

    local shopkeeper_base_quads = build_quads(base_col_start)
    local shopkeeper_outfit_quads = build_quads(outfit_col_start)

    local function facing_direction(from_x, from_y, to_x, to_y)
        local dx = (to_x or from_x) - from_x
        local dy = (to_y or from_y) - from_y
        if math.abs(dx) > math.abs(dy) then
            return dx >= 0 and "right" or "left"
        end
        return dy >= 0 and "down" or "up"
    end

    local function get_tracked_actor_position()
        if not last_player_ship then
            return nil, nil
        end
        if last_player_ship.is_on_foot then
            return last_player_ship.on_foot_x or last_player_ship.x, last_player_ship.on_foot_y or last_player_ship.y
        end
        return last_player_ship.x, last_player_ship.y
    end

    local api = {}

    local function create_shop_animation(target_y)
        return {
            start_y = target_y,
            target_y = target_y,
            progress = 1,
            duration = 0,
            is_animating = false,
            current_frame = 1,
            frame_timer = 0
        }
    end

    local function ensure_animation(shop_data)
        if shop_data.animation and shop_data.animation.current_frame then
            return
        end
        local target_y = shop_data.y or 0
        if shop_data.animation and shop_data.animation.target_y then
            target_y = shop_data.animation.target_y
        end
        shop_data.animation = create_shop_animation(target_y)
        shop_data.y = target_y
    end

    local function get_cached_port_shop_island(index)
        local cached = port_shop_island_cache[index]
        if cached then
            return cached
        end

        local radius = 44 + ((index % 4) * 3)
        cached = sand.new({
            radius = radius,
            seed = 700 + (index * 97),
            tide_dir_x = 0.1,
            tide_dir_y = 1.0,
            grain_density = 0.0035,
            cutout_density = 0.11
        })
        cached.radius = radius
        port_shop_island_cache[index] = cached
        return cached
    end

    local function get_port_island_center(shop_data)
        return shop_data.x, shop_data.y + 24
    end

    local function get_port_shop_dock_angle(shop_data)
        return tonumber(shop_data and shop_data.dock_angle) or (-math.pi * 0.5)
    end

    local function get_port_shop_dock_geometry(shop_data, index)
        local island = get_cached_port_shop_island(index)
        local island_radius = island.radius or 44
        local cx, cy = get_port_island_center(shop_data)
        local angle = get_port_shop_dock_angle(shop_data)
        local forward_x = math.cos(angle)
        local forward_y = math.sin(angle)
        local side_x = -forward_y
        local side_y = forward_x
        local half_w = PORT_DOCK_WIDTH * 0.5
        local half_h = PORT_DOCK_HEIGHT * 0.5
        local center_distance = island_radius - PORT_DOCK_TOP_OVERLAP + half_h
        local center_x = cx + forward_x * center_distance
        local center_y = cy + forward_y * center_distance
        local inner_x = center_x - forward_x * half_h
        local inner_y = center_y - forward_y * half_h
        local tip_x = center_x + forward_x * half_h
        local tip_y = center_y + forward_y * half_h

        return {
            center_x = center_x,
            center_y = center_y,
            inner_x = inner_x,
            inner_y = inner_y,
            tip_x = tip_x,
            tip_y = tip_y,
            forward_x = forward_x,
            forward_y = forward_y,
            side_x = side_x,
            side_y = side_y,
            half_w = half_w,
            half_h = half_h,
            island_center_x = cx,
            island_center_y = cy,
            island_radius = island_radius
        }
    end

    local function draw_port_shop_dock(geometry)
        local cx = geometry.center_x
        local cy = geometry.center_y
        local fx = geometry.forward_x
        local fy = geometry.forward_y
        local sx = geometry.side_x
        local sy = geometry.side_y
        local hw = geometry.half_w
        local hh = geometry.half_h

        local p1x = cx - (sx * hw) - (fx * hh)
        local p1y = cy - (sy * hw) - (fy * hh)
        local p2x = cx + (sx * hw) - (fx * hh)
        local p2y = cy + (sy * hw) - (fy * hh)
        local p3x = cx + (sx * hw) + (fx * hh)
        local p3y = cy + (sy * hw) + (fy * hh)
        local p4x = cx - (sx * hw) + (fx * hh)
        local p4y = cy - (sy * hw) + (fy * hh)

        love.graphics.setColor(0.45, 0.29, 0.15, 1)
        love.graphics.polygon("fill", p1x, p1y, p2x, p2y, p3x, p3y, p4x, p4y)
        love.graphics.setColor(0.62, 0.41, 0.22, 1)
        love.graphics.polygon("line", p1x, p1y, p2x, p2y, p3x, p3y, p4x, p4y)
        love.graphics.setColor(1, 1, 1, 1)
    end

    local function get_port_shop_dock_position(shop_data, index)
        local geometry = get_port_shop_dock_geometry(shop_data, index)
        return geometry.inner_x, geometry.inner_y
    end

    local function project_point_on_dock_axes(px, py, geometry, origin_x, origin_y)
        local ox = origin_x or geometry.center_x
        local oy = origin_y or geometry.center_y
        local dx = px - ox
        local dy = py - oy
        local forward = (dx * geometry.forward_x) + (dy * geometry.forward_y)
        local side = (dx * geometry.side_x) + (dy * geometry.side_y)
        return forward, side
    end

    local function is_boat_in_port_dock_lane(player_ship, geometry)
        local boat_radius = tonumber(player_ship.radius) or 20
        local lane_half_width = geometry.half_w + (boat_radius * 0.75) + 4
        local lane_min = -boat_radius - 8
        local lane_max = math.max(DOCK_INTERACTION_RANGE, boat_radius + 12)
        local px = player_ship.x or 0
        local py = player_ship.y or 0
        local forward_proj, side_proj = project_point_on_dock_axes(px, py, geometry, geometry.inner_x, geometry.inner_y)
        local approach_dist = -forward_proj

        return math.abs(side_proj) <= lane_half_width
            and approach_dist >= lane_min
            and approach_dist <= lane_max
    end

    local function squared_distance_to_oriented_rect(px, py, geometry)
        local forward_proj, side_proj = project_point_on_dock_axes(px, py, geometry)
        local nearest_forward = math.max(-geometry.half_h, math.min(forward_proj, geometry.half_h))
        local nearest_side = math.max(-geometry.half_w, math.min(side_proj, geometry.half_w))
        local df = forward_proj - nearest_forward
        local ds = side_proj - nearest_side
        return (df * df) + (ds * ds)
    end

    local function is_boat_touching_port_dock(player_ship, geometry)
        local boat_radius = tonumber(player_ship.radius) or 20
        local px = player_ship.x or 0
        local py = player_ship.y or 0
        local touch_padding = 8
        local max_dist = boat_radius + touch_padding
        local dist_sq = squared_distance_to_oriented_rect(px, py, geometry)
        return dist_sq <= (max_dist * max_dist)
    end

    local function get_port_shopkeeper_position(shop_data, index)
        local island = get_cached_port_shop_island(index)
        local cx, cy = get_port_island_center(shop_data)
        return cx, cy + (island.radius * PORT_SHOPKEEPER_VERTICAL_FACTOR)
    end

    local function get_actor_position(player_ship)
        if player_ship and player_ship.is_on_foot then
            return player_ship.on_foot_x or player_ship.x, player_ship.on_foot_y or player_ship.y
        end
        return player_ship.x, player_ship.y
    end

    function api.get_main_dock_position(shopkeeper)
        if not shopkeeper or not shopkeeper.is_spawned then
            return nil, nil
        end

        local dock_x = shopkeeper.dock_x or shopkeeper.x
        local dock_base_y = shopkeeper.dock_y or shopkeeper.y
        return dock_x, dock_base_y + DOCK_TIP_OFFSET_Y
    end

    local function is_boat_near_main_dock(player_ship, shopkeeper)
        local dock_x, dock_y = api.get_main_dock_position(shopkeeper)
        if not dock_x or not dock_y then
            return false
        end

        local near_dock_x = math.abs((player_ship.x or 0) - dock_x) <= DOCK_INTERACTION_RANGE
        local near_shoreline = (player_ship.y or 0) <= (SHORE_DIVISION + 45)
        return near_dock_x and near_shoreline
    end

    local function is_on_foot_near_boat(player_ship)
        local foot_x, foot_y = get_actor_position(player_ship)
        local dx = (foot_x or 0) - (player_ship.x or 0)
        local dy = (foot_y or 0) - (player_ship.y or 0)
        return (dx * dx + dy * dy) <= (BOARD_INTERACTION_RANGE * BOARD_INTERACTION_RANGE)
    end

    function api.try_disembark_main_dock(player_ship, shopkeeper)
        if not player_ship or player_ship.is_on_foot then
            return false
        end
        if not is_boat_near_main_dock(player_ship, shopkeeper) then
            return false
        end

        player_ship.is_on_foot = true
        player_ship.velocity_x = 0
        player_ship.velocity_y = 0
        player_ship.target_rotation = player_ship.rotation
        player_ship.pending_shop_interaction = false

        local dock_x, _ = api.get_main_dock_position(shopkeeper)
        local dock_base_y = (shopkeeper and (shopkeeper.dock_y or shopkeeper.y)) or player_ship.y
        player_ship.on_foot_x = dock_x or player_ship.x
        player_ship.on_foot_y = dock_base_y + DISEMBARK_OFFSET_Y
        player_ship.dock_walk_center_x = dock_x or player_ship.x
        player_ship.dock_walk_center_y = dock_base_y
        player_ship.dock_walk_dock_x = dock_x or player_ship.x
        player_ship.dock_walk_dock_y = dock_base_y + DOCK_TIP_OFFSET_Y
        player_ship.docked_port_shop_index = nil
        player_ship.dock_walk_mode = "shore"
        player_ship.dock_walk_island_radius = nil
        player_ship.dock_walk_dock_half_width = nil
        player_ship.dock_walk_dock_height = nil
        player_ship.dock_walk_max_side = nil
        player_ship.dock_walk_max_up = nil
        player_ship.dock_walk_max_down = nil
        return true
    end

    function api.can_disembark_main_dock(player_ship, shopkeeper)
        if not player_ship or player_ship.is_on_foot then
            return false
        end
        return is_boat_near_main_dock(player_ship, shopkeeper)
    end

    function api.try_board_main_dock(player_ship, _)
        if not player_ship or not player_ship.is_on_foot then
            return false
        end
        if not is_on_foot_near_boat(player_ship) then
            return false
        end

        player_ship.is_on_foot = false
        player_ship.pending_shop_interaction = false
        player_ship.dock_walk_center_x = nil
        player_ship.dock_walk_center_y = nil
        player_ship.dock_walk_dock_x = nil
        player_ship.dock_walk_dock_y = nil
        player_ship.docked_port_shop_index = nil
        player_ship.dock_walk_mode = nil
        player_ship.dock_walk_island_radius = nil
        player_ship.dock_walk_dock_half_width = nil
        player_ship.dock_walk_dock_height = nil
        player_ship.dock_walk_max_side = nil
        player_ship.dock_walk_max_up = nil
        player_ship.dock_walk_max_down = nil
        return true
    end

    function api.can_board_main_dock(player_ship)
        if not player_ship or not player_ship.is_on_foot then
            return false
        end
        return is_on_foot_near_boat(player_ship)
    end

    function api.request_main_shop_interaction(player_ship, shopkeeper)
        if not player_ship or not player_ship.is_on_foot then
            return false
        end
        if not (shopkeeper and shopkeeper.can_interact and shopkeeper:can_interact()) then
            return false
        end

        player_ship.pending_shop_interaction = true
        return true
    end

    function api.can_talk_to_main_shopkeeper(player_ship, shopkeeper)
        if not player_ship or not player_ship.is_on_foot then
            return false
        end
        return shopkeeper and shopkeeper.can_interact and shopkeeper:can_interact()
    end

    local function get_nearest_port_dock_for_boat(player_ship)
        local best_index = nil
        local best_score = nil

        for index, shop_data in ipairs(port_a_shops) do
            if shop_data.is_spawned then
                local dock_x, dock_y = get_port_shop_dock_position(shop_data, index)
                local dock_geometry = get_port_shop_dock_geometry(shop_data, index)

                local qualifies = false
                local score = nil

                if is_boat_touching_port_dock(player_ship, dock_geometry) then
                    local dx = (player_ship.x or 0) - dock_x
                    local dy = (player_ship.y or 0) - dock_y
                    score = (dx * dx) + (dy * dy)
                    qualifies = true
                elseif is_boat_in_port_dock_lane(player_ship, dock_geometry) then
                    local forward_proj, side_proj = project_point_on_dock_axes(
                        player_ship.x or 0,
                        player_ship.y or 0,
                        dock_geometry,
                        dock_geometry.inner_x,
                        dock_geometry.inner_y
                    )
                    local approach_dist = math.max(0, -forward_proj)
                    score = (side_proj * side_proj) + (approach_dist * approach_dist)
                    qualifies = true
                else
                    local dx = (player_ship.x or 0) - dock_x
                    local dy = (player_ship.y or 0) - dock_y
                    local dist_sq = (dx * dx) + (dy * dy)
                    if dist_sq <= (DOCK_INTERACTION_RANGE * DOCK_INTERACTION_RANGE) then
                        score = dist_sq
                        qualifies = true
                    end
                end

                if qualifies and (not best_score or score < best_score) then
                    best_index = index
                    best_score = score
                end
            end
        end

        return best_index
    end

    local function get_active_port_shop_index_for_player(player_ship)
        if not player_ship or not player_ship.is_on_foot then
            return nil
        end

        local docked_index = tonumber(player_ship.docked_port_shop_index)
        if not docked_index then
            return nil
        end
        docked_index = math.max(1, math.floor(docked_index))

        local shop_data = port_a_shops[docked_index]
        if not (shop_data and shop_data.is_spawned) then
            return nil
        end

        local actor_x, actor_y = get_actor_position(player_ship)
        local keeper_x, keeper_y = get_port_shopkeeper_position(shop_data, docked_index)
        local dx = actor_x - keeper_x
        local dy = actor_y - keeper_y
        if (dx * dx + dy * dy) <= (INTERACTION_RANGE * INTERACTION_RANGE) then
            return docked_index
        end

        return nil
    end

    function api.can_disembark_port_shop(player_ship)
        if not player_ship or player_ship.is_on_foot then
            return false
        end
        return get_nearest_port_dock_for_boat(player_ship) ~= nil
    end

    function api.try_disembark_port_shop(player_ship)
        if not player_ship or player_ship.is_on_foot then
            return false
        end

        local dock_index = get_nearest_port_dock_for_boat(player_ship)
        if not dock_index then
            return false
        end

        local shop_data = port_a_shops[dock_index]
        local dock_x, dock_y = get_port_shop_dock_position(shop_data, dock_index)
        local dock_geometry = get_port_shop_dock_geometry(shop_data, dock_index)
        local island_cx, island_cy = get_port_island_center(shop_data)
        local island = get_cached_port_shop_island(dock_index)

        player_ship.is_on_foot = true
        player_ship.velocity_x = 0
        player_ship.velocity_y = 0
        player_ship.target_rotation = player_ship.rotation
        player_ship.pending_shop_interaction = false

        local disembark_dist = (PORT_DOCK_HEIGHT * 0.5) - DISEMBARK_OFFSET_Y
        player_ship.on_foot_x = dock_x + (dock_geometry.forward_x * disembark_dist)
        player_ship.on_foot_y = dock_y + (dock_geometry.forward_y * disembark_dist)
        player_ship.dock_walk_center_x = island_cx
        player_ship.dock_walk_center_y = island_cy
        player_ship.dock_walk_dock_x = dock_x
        player_ship.dock_walk_dock_y = dock_y
        player_ship.docked_port_shop_index = dock_index
        player_ship.dock_walk_mode = "island"
        player_ship.dock_walk_island_radius = (island and island.radius or 44) - 1
        player_ship.dock_walk_dock_half_width = (PORT_DOCK_WIDTH * 0.5) + 2
        player_ship.dock_walk_dock_height = PORT_DOCK_HEIGHT + 2
        player_ship.dock_walk_max_side = (island and island.radius or 44) + 12
        player_ship.dock_walk_max_up = (island and island.radius or 44) + PORT_DOCK_HEIGHT + 12
        player_ship.dock_walk_max_down = (island and island.radius or 44) + 8
        return true
    end

    function api.can_talk_to_port_shopkeeper(player_ship)
        return get_active_port_shop_index_for_player(player_ship) ~= nil
    end

    function api.request_port_shop_interaction(player_ship)
        if not player_ship or not player_ship.is_on_foot then
            return false
        end
        if not api.can_talk_to_port_shopkeeper(player_ship) then
            return false
        end
        player_ship.pending_shop_interaction = true
        return true
    end

    function api.update_spawn_and_animation(player_ship, dt)
        last_player_ship = player_ship
        for _, shop_data in ipairs(port_a_shops) do
            if shop_data.is_spawned then
                ensure_animation(shop_data)
                shop_data.animation.frame_timer = shop_data.animation.frame_timer + dt
                if shop_data.animation.frame_timer >= animation_frame_time then
                    shop_data.animation.frame_timer = shop_data.animation.frame_timer - animation_frame_time
                    shop_data.animation.current_frame = shop_data.animation.current_frame % total_frames + 1
                end
            end
        end

        for _, shop_data in ipairs(port_a_shops) do
            ensure_animation(shop_data)
            local is_shop_visible = math.abs(shop_data.animation.target_y - player_ship.y) <= 500

            if is_shop_visible then
                if not shop_data.is_spawned then
                    local spawn_offset = player_ship.velocity_x > 0 and 200 or -200
                    local spawn_x = ray_x_at_y(
                        player_ship.x + spawn_offset,
                        player_ship.y,
                        player_ship.rotation,
                        shop_data.animation.target_y
                    )
                    if not spawn_x then
                        spawn_x = player_ship.x + spawn_offset
                    end
                    shop_data.x = spawn_x
                    shop_data.is_spawned = true
                    shop_data.animation.is_animating = false
                    shop_data.animation.progress = 1
                    shop_data.y = shop_data.animation.target_y
                    local island_center_y = shop_data.y + 24
                    shop_data.dock_angle = math.atan2(player_ship.y - island_center_y, player_ship.x - shop_data.x)
                    print("Port-a-shop spawned at: X=" .. shop_data.x .. ", Y=" .. shop_data.y)
                end

                if shop_data.y ~= shop_data.animation.target_y then
                    shop_data.y = shop_data.animation.target_y
                end
            else
                if shop_data.is_spawned then
                    print("Port-a-shop despawned at: X=" .. shop_data.x .. ", Y=" .. shop_data.y .. " (Player Y: " .. player_ship.y .. ")")
                end
                shop_data.is_spawned = false
            end
        end
    end

    function api.check_shop_interaction(player_ship, shopkeeper)
        local any_shop_active = false
        local port_shop_active = false
        local main_shop_active = false
        local active_port_index = get_active_port_shop_index_for_player(player_ship)

        for index, shop_data in ipairs(port_a_shops) do
            if shop_data.is_spawned then
                shop_data.is_active = (active_port_index == index)
                any_shop_active = any_shop_active or shop_data.is_active
                port_shop_active = port_shop_active or shop_data.is_active
            else
                shop_data.is_active = false
            end
        end

        if player_ship.is_on_foot and shopkeeper and shopkeeper.can_interact and shopkeeper:can_interact() then
            any_shop_active = true
            main_shop_active = true
        end

        return any_shop_active, port_shop_active, main_shop_active
    end

    function api.add_port_a_shop()
        local shop_number = #port_a_shops + 1
        local target_y = shop_number * SHOP_SPACING
        table.insert(port_a_shops, {
            x = 0,
            y = target_y,
            is_spawned = false,
            is_active = false,
            animation = create_shop_animation(target_y)
        })
        print("New port-a-shop added. Shop #" .. shop_number .. " at Y: " .. target_y)
    end

    function api.get_port_a_shop_count()
        return #port_a_shops
    end

    function api.draw_main_dock(shopkeeper)
        if not shopkeeper or not shopkeeper.is_spawned then
            return
        end

        local dock_x, dock_tip_y = api.get_main_dock_position(shopkeeper)
        if not dock_x or not dock_tip_y then
            return
        end

        local dock_width = 36
        local dock_base_y = shopkeeper.dock_y or shopkeeper.y
        local dock_top_y = dock_base_y - 26
        local dock_height = math.max(18, dock_tip_y - dock_top_y)

        love.graphics.setColor(0.47, 0.31, 0.16, 1)
        love.graphics.rectangle("fill", dock_x - dock_width / 2, dock_top_y, dock_width, dock_height)
        love.graphics.setColor(0.62, 0.43, 0.23, 1)
        love.graphics.rectangle("line", dock_x - dock_width / 2, dock_top_y, dock_width, dock_height)
        love.graphics.setColor(1, 1, 1, 1)
    end

    local function push_boat_out_of_circle(player_ship, cx, cy, extra_radius)
        local boat_radius = tonumber(player_ship.radius) or 20
        local min_dist = math.max(1, (tonumber(extra_radius) or 0) + boat_radius)
        local dx = (player_ship.x or 0) - cx
        local dy = (player_ship.y or 0) - cy
        local dist_sq = (dx * dx) + (dy * dy)
        if dist_sq >= (min_dist * min_dist) then
            return false
        end

        local dist = math.sqrt(dist_sq)
        if dist <= 0.0001 then
            dx = 1
            dy = 0
            dist = 1
        end
        local nx = dx / dist
        local ny = dy / dist

        player_ship.x = cx + (nx * min_dist)
        player_ship.y = cy + (ny * min_dist)
        player_ship.velocity_x = (player_ship.velocity_x or 0) * 0.2
        player_ship.velocity_y = (player_ship.velocity_y or 0) * 0.2
        return true
    end

    local function push_boat_out_of_rect(player_ship, rect_x, rect_y, rect_w, rect_h, extra_padding)
        local boat_radius = tonumber(player_ship.radius) or 20
        local padding = tonumber(extra_padding) or 0
        local px = player_ship.x or 0
        local py = player_ship.y or 0

        local min_x = rect_x - boat_radius - padding
        local max_x = rect_x + rect_w + boat_radius + padding
        local min_y = rect_y - boat_radius - padding
        local max_y = rect_y + rect_h + boat_radius + padding

        if px < min_x or px > max_x or py < min_y or py > max_y then
            return false
        end

        local left_pen = math.abs(px - min_x)
        local right_pen = math.abs(max_x - px)
        local top_pen = math.abs(py - min_y)
        local bottom_pen = math.abs(max_y - py)

        local min_pen = math.min(left_pen, right_pen, top_pen, bottom_pen)
        if min_pen == left_pen then
            player_ship.x = min_x
        elseif min_pen == right_pen then
            player_ship.x = max_x
        elseif min_pen == top_pen then
            player_ship.y = min_y
        else
            player_ship.y = max_y
        end

        player_ship.velocity_x = (player_ship.velocity_x or 0) * 0.2
        player_ship.velocity_y = (player_ship.velocity_y or 0) * 0.2
        return true
    end

    local function push_boat_out_of_oriented_rect(player_ship, geometry, extra_padding)
        local boat_radius = tonumber(player_ship.radius) or 20
        local padding = tonumber(extra_padding) or 0
        local px = player_ship.x or 0
        local py = player_ship.y or 0
        local half_w = geometry.half_w + boat_radius + padding
        local half_h = geometry.half_h + boat_radius + padding
        local forward_proj, side_proj = project_point_on_dock_axes(px, py, geometry)

        if math.abs(forward_proj) > half_h or math.abs(side_proj) > half_w then
            return false
        end

        local forward_pos_pen = half_h - forward_proj
        local forward_neg_pen = half_h + forward_proj
        local side_pos_pen = half_w - side_proj
        local side_neg_pen = half_w + side_proj
        local min_pen = math.min(forward_pos_pen, forward_neg_pen, side_pos_pen, side_neg_pen)

        if min_pen == forward_pos_pen then
            forward_proj = half_h
        elseif min_pen == forward_neg_pen then
            forward_proj = -half_h
        elseif min_pen == side_pos_pen then
            side_proj = half_w
        else
            side_proj = -half_w
        end

        player_ship.x = geometry.center_x + (geometry.forward_x * forward_proj) + (geometry.side_x * side_proj)
        player_ship.y = geometry.center_y + (geometry.forward_y * forward_proj) + (geometry.side_y * side_proj)
        player_ship.velocity_x = (player_ship.velocity_x or 0) * 0.2
        player_ship.velocity_y = (player_ship.velocity_y or 0) * 0.2
        return true
    end

    function api.resolve_boat_collisions(player_ship, shopkeeper)
        if not player_ship or player_ship.is_on_foot then
            return
        end

        for index, shop_data in ipairs(port_a_shops) do
            if shop_data.is_spawned then
                local dock_geometry = get_port_shop_dock_geometry(shop_data, index)

                if not is_boat_in_port_dock_lane(player_ship, dock_geometry) then
                    push_boat_out_of_circle(
                        player_ship,
                        dock_geometry.island_center_x,
                        dock_geometry.island_center_y,
                        dock_geometry.island_radius
                    )
                end
                push_boat_out_of_oriented_rect(player_ship, dock_geometry, 0)
            end
        end

        if shopkeeper and shopkeeper.is_spawned then
            local dock_x, dock_y = api.get_main_dock_position(shopkeeper)
            if dock_x and dock_y then
                local dock_width = 36
                local dock_base_y = shopkeeper.dock_y or shopkeeper.y
                local dock_top_y = dock_base_y - 26
                local dock_height = math.max(18, dock_y - dock_top_y)
                push_boat_out_of_rect(player_ship, dock_x - (dock_width / 2), dock_top_y, dock_width, dock_height, 0)
                push_boat_out_of_circle(player_ship, dock_x, dock_y - 8, 16)
            end
        end
    end

    function api.draw_shops(camera)
        love.graphics.push()

        local view_width = size.CANVAS_WIDTH / camera.scale
        local view_height = love.graphics.getHeight() / camera.scale
        local shore_extension = 1000

        local start_y = math.floor((camera.y - view_height) / SHOP_SPACING) * SHOP_SPACING
        local end_y = math.ceil((camera.y + view_height * 2) / SHOP_SPACING) * SHOP_SPACING

        love.graphics.setColor(0.3, 0.3, 0.5, 0.3)
        love.graphics.setLineWidth(2)
        for y = start_y, end_y, SHOP_SPACING do
            love.graphics.line(
                camera.x - shore_extension, y,
                camera.x + view_width + shore_extension, y
            )
        end

        for index, shop_data in ipairs(port_a_shops) do
            if shop_data.is_spawned then
                ensure_animation(shop_data)

                local island_center_x, island_center_y = get_port_island_center(shop_data)
                local island = get_cached_port_shop_island(index)
                island:draw(island_center_x, island_center_y)
                local dock_geometry = get_port_shop_dock_geometry(shop_data, index)
                draw_port_shop_dock(dock_geometry)

                if shop_data.is_active then
                    love.graphics.setColor(1, 1, 0)
                else
                    love.graphics.setColor(1, 1, 1)
                end
                local keeper_x, keeper_y = get_port_shopkeeper_position(shop_data, index)
                local actor_x, actor_y = get_tracked_actor_position()
                local dir = facing_direction(keeper_x, keeper_y, actor_x, actor_y)
                local frame = shop_data.animation.current_frame
                local base_quad = (shopkeeper_base_quads[dir] or shopkeeper_base_quads.down)[frame]
                local outfit_quad = (shopkeeper_outfit_quads[dir] or shopkeeper_outfit_quads.down)[frame]

                love.graphics.draw(
                    shopkeeper_sprite,
                    base_quad,
                    keeper_x,
                    keeper_y,
                    0,
                    sprite_scale,
                    sprite_scale,
                    sprite_frame_width / 2,
                    sprite_frame_height / 2
                )
                love.graphics.draw(
                    shopkeeper_sprite,
                    outfit_quad,
                    keeper_x,
                    keeper_y,
                    0,
                    sprite_scale,
                    sprite_scale,
                    sprite_frame_width / 2,
                    sprite_frame_height / 2
                )

                love.graphics.setColor(1, 1, 1, 1)

                if shop_data.is_active then
                    love.graphics.print("SHOP", keeper_x - 20, keeper_y - (sprite_frame_height * sprite_scale))
                end
            end
        end

        love.graphics.pop()
    end

    function api.reset()
        port_a_shops = {}
        port_shop_island_cache = {}
    end

    function api.get_port_a_shops_data()
        return port_a_shops
    end

    function api.set_port_a_shops_data(data)
        if data then
            port_a_shops = data
            port_shop_island_cache = {}
        end
    end

    function api.get_last_port_a_shop_y()
        if #port_a_shops == 0 then
            return 0
        end

        local last_shop_y = 0
        for _, shop_data in ipairs(port_a_shops) do
            ensure_animation(shop_data)
            if shop_data.animation and shop_data.animation.target_y then
                last_shop_y = math.max(last_shop_y, shop_data.animation.target_y)
            else
                last_shop_y = math.max(last_shop_y, shop_data.y or 0)
            end
        end

        return last_shop_y
    end

    return api
end

return port
