local sand = {}

local TAU = math.pi * 2

local function clamp(v, lo, hi)
    if v < lo then
        return lo
    end
    if v > hi then
        return hi
    end
    return v
end

local function normalize2(x, y)
    local len = math.sqrt((x * x) + (y * y))
    if len <= 0.00001 then
        return 0, 1
    end
    return x / len, y / len
end

local function make_rng(seed)
    local s = math.floor((tonumber(seed) or 1) * 1000003) % 2147483647
    if s <= 0 then
        s = 1234567
    end
    return function()
        s = (1103515245 * s + 12345) % 2147483647
        return s / 2147483647
    end
end

local function point_in_polygon(points, x, y)
    local inside = false
    local count = math.floor(#points / 2)
    if count < 3 then
        return false
    end

    local j = count
    for i = 1, count do
        local ix = points[(i * 2) - 1]
        local iy = points[i * 2]
        local jx = points[(j * 2) - 1]
        local jy = points[j * 2]

        local denom = (jy - iy)
        if math.abs(denom) < 0.000001 then
            denom = 0.000001
        end
        local intersects = ((iy > y) ~= (jy > y))
            and (x < (((jx - ix) * (y - iy)) / denom) + ix)

        if intersects then
            inside = not inside
        end
        j = i
    end

    return inside
end

local function inside_cutout(cutouts, x, y)
    for i = 1, #cutouts do
        local c = cutouts[i]
        if point_in_polygon(c.points, x, y) then
            return true
        end
    end
    return false
end

local function pick_grain_color(rng, base)
    local t = rng()
    if t < 0.64 then
        local jitter = (rng() - 0.5) * 0.14
        return {
            clamp(base[1] + jitter, 0, 1),
            clamp(base[2] + jitter, 0, 1),
            clamp(base[3] + jitter, 0, 1)
        }
    elseif t < 0.86 then
        return {
            clamp(base[1] - (0.12 + rng() * 0.08), 0, 1),
            clamp(base[2] - (0.10 + rng() * 0.07), 0, 1),
            clamp(base[3] - (0.08 + rng() * 0.05), 0, 1)
        }
    else
        return {
            clamp(base[1] + (0.10 + rng() * 0.10), 0, 1),
            clamp(base[2] + (0.08 + rng() * 0.10), 0, 1),
            clamp(base[3] + (0.05 + rng() * 0.08), 0, 1)
        }
    end
end

local function build_patch(opts)
    local radius = math.max(4, tonumber(opts.radius) or 90)
    local seed = tonumber(opts.seed) or 1
    local grain_density = tonumber(opts.grain_density) or 0.006
    local cutout_density = tonumber(opts.cutout_density) or 0.17

    local tide_dir_x, tide_dir_y = normalize2(
        opts.tide_dir_x or 0,
        opts.tide_dir_y or 1
    )

    local base_color = opts.base_color or {0.88, 0.75, 0.53}
    local wet_color = opts.wet_color or {0.58, 0.44, 0.28}
    local tide_color = opts.tide_color or {0.20, 0.30, 0.52}
    local edge_color = opts.edge_color or {0.73, 0.58, 0.38}

    local rng = make_rng(seed)
    local cutouts = {}
    local cutout_count = math.max(6, math.floor(radius * (0.10 + cutout_density * 0.65)))

    for i = 1, cutout_count do
        local angle = ((i - 1) / cutout_count) * TAU + ((rng() - 0.5) * 0.55)
        local nx = math.cos(angle)
        local ny = math.sin(angle)

        local tide_exposure = math.max(0, (nx * tide_dir_x) + (ny * tide_dir_y))
        local chance = 0.22 + tide_exposure * 0.64
        if rng() <= chance then
            local half_angle = 0.10 + (rng() * 0.18) + (tide_exposure * 0.08)
            local depth = radius * (0.08 + (rng() * 0.22) + (tide_exposure * 0.12))

            local left_angle = angle - (half_angle * (0.88 + rng() * 0.26))
            local right_angle = angle + (half_angle * (0.88 + rng() * 0.26))
            local tip_angle = angle + ((rng() - 0.5) * half_angle * 0.8)

            local outer_left_r = radius + (0.8 + rng() * 2.4)
            local outer_right_r = radius + (0.8 + rng() * 2.4)
            local shoulder_left_angle = angle - (half_angle * (0.30 + rng() * 0.25))
            local shoulder_right_angle = angle + (half_angle * (0.30 + rng() * 0.25))
            local shoulder_left_r = radius - (depth * (0.27 + rng() * 0.20))
            local shoulder_right_r = radius - (depth * (0.27 + rng() * 0.20))
            local tip_r = math.max(2, radius - depth)

            local points = {
                math.cos(left_angle) * outer_left_r, math.sin(left_angle) * outer_left_r,
                math.cos(shoulder_left_angle) * shoulder_left_r, math.sin(shoulder_left_angle) * shoulder_left_r,
                math.cos(tip_angle) * tip_r, math.sin(tip_angle) * tip_r,
                math.cos(shoulder_right_angle) * shoulder_right_r, math.sin(shoulder_right_angle) * shoulder_right_r,
                math.cos(right_angle) * outer_right_r, math.sin(right_angle) * outer_right_r
            }

            cutouts[#cutouts + 1] = {
                points = points,
                depth = depth,
                rim_left_x = points[1],
                rim_left_y = points[2],
                rim_right_x = points[9],
                rim_right_y = points[10]
            }
        end
    end

    local grains = {}
    local area = math.pi * radius * radius
    local grain_count = clamp(math.floor(area * grain_density), 40, 2200)

    for _ = 1, grain_count do
        local a = rng() * TAU
        local rr = math.sqrt(rng()) * radius * 0.98
        local gx = math.cos(a) * rr
        local gy = math.sin(a) * rr
        if not inside_cutout(cutouts, gx, gy) then
            grains[#grains + 1] = {
                x = gx,
                y = gy,
                size = (rng() < 0.14) and 2 or 1,
                alpha = 0.30 + rng() * 0.50,
                color = pick_grain_color(rng, base_color)
            }
        end
    end

    return {
        radius = radius,
        base_color = base_color,
        wet_color = wet_color,
        tide_color = tide_color,
        edge_color = edge_color,
        cutouts = cutouts,
        grains = grains
    }
end

function sand.new(opts)
    opts = opts or {}
    local patch = build_patch(opts)

    function patch:draw(x, y, draw_opts)
        draw_opts = draw_opts or {}
        local px = tonumber(x) or 0
        local py = tonumber(y) or 0

        local base_color = draw_opts.base_color or self.base_color
        local wet_color = draw_opts.wet_color or self.wet_color
        local tide_color = draw_opts.tide_color or self.tide_color
        local edge_color = draw_opts.edge_color or self.edge_color

        love.graphics.push("all")

        love.graphics.setColor(base_color[1], base_color[2], base_color[3], 1)
        love.graphics.circle("fill", px, py, self.radius)

        for i = 1, 5 do
            local t = i / 5
            local rr = self.radius * (1 - t * 0.22)
            local shade = 1 - (t * 0.09)
            love.graphics.setColor(
                clamp(base_color[1] * shade, 0, 1),
                clamp(base_color[2] * shade, 0, 1),
                clamp(base_color[3] * shade, 0, 1),
                0.18
            )
            love.graphics.circle("fill", px - self.radius * 0.05, py - self.radius * 0.06, rr)
        end

        for i = 1, #self.cutouts do
            local c = self.cutouts[i]
            local points = c.points
            local world_points = {}
            local inset_points = {}
            local inset_t = clamp(0.12 + ((c.depth or 0) / math.max(1, self.radius)) * 0.15, 0.11, 0.30)

            for p = 1, #points, 2 do
                local vx = points[p]
                local vy = points[p + 1]
                world_points[#world_points + 1] = px + vx
                world_points[#world_points + 1] = py + vy

                local ivx = vx * (1 - inset_t)
                local ivy = vy * (1 - inset_t)
                inset_points[#inset_points + 1] = px + ivx
                inset_points[#inset_points + 1] = py + ivy
            end

            love.graphics.setColor(tide_color[1], tide_color[2], tide_color[3], 0.70)
            love.graphics.polygon("fill", world_points)

            love.graphics.setColor(wet_color[1], wet_color[2], wet_color[3], 0.72)
            love.graphics.polygon("fill", inset_points)

            love.graphics.setColor(edge_color[1], edge_color[2], edge_color[3], 0.60)
            love.graphics.setLineWidth(1.5)
            love.graphics.polygon("line", world_points)

            -- shoreline foam-like highlight across the notch mouth.
            love.graphics.setColor(0.70, 0.92, 0.88, 0.72)
            love.graphics.setLineWidth(2)
            love.graphics.line(
                px + c.rim_left_x, py + c.rim_left_y,
                px + c.rim_right_x, py + c.rim_right_y
            )
        end

        for i = 1, #self.grains do
            local g = self.grains[i]
            local gx = px + g.x
            local gy = py + g.y
            love.graphics.setColor(g.color[1], g.color[2], g.color[3], g.alpha)
            if g.size == 1 then
                love.graphics.points(gx, gy)
            else
                love.graphics.rectangle("fill", gx, gy, g.size, g.size)
            end
        end

        love.graphics.setLineWidth(2)
        love.graphics.setColor(edge_color[1], edge_color[2], edge_color[3], 0.55)
        love.graphics.circle("line", px, py, self.radius - 0.5)

        love.graphics.pop()
    end

    return patch
end

function sand.draw(x, y, radius, opts)
    local options = opts or {}
    options.radius = radius or options.radius
    local patch = sand.new(options)
    patch:draw(x, y, options)
    return patch
end

return sand
