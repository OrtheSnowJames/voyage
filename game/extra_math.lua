local extra_math = {}

function extra_math.lerp(a, b, t)
    return a + (b - a) * t
end

function extra_math.clamp(value, min_value, max_value)
    if value < min_value then
        return min_value
    end
    if value > max_value then
        return max_value
    end
    return value
end

function extra_math.round_to_tenth(value)
    return math.floor(value * 10 + 0.5) / 10
end

function extra_math.normalize_angle(angle)
    while angle > math.pi do
        angle = angle - 2 * math.pi
    end
    while angle < -math.pi do
        angle = angle + 2 * math.pi
    end
    return angle
end

function extra_math.turn_towards(current, target, max_delta)
    local delta = extra_math.normalize_angle(target - current)
    if math.abs(delta) <= max_delta then
        return target
    end
    if delta > 0 then
        return current + max_delta
    end
    return current - max_delta
end

function extra_math.atan2(y, x)
    if x > 0 then return math.atan(y / x)
    elseif x < 0 and y >= 0 then return math.atan(y / x) + math.pi
    elseif x < 0 and y < 0 then return math.atan(y / x) - math.pi
    elseif x == 0 and y > 0 then return math.pi / 2
    elseif x == 0 and y < 0 then return -math.pi / 2
    else return 0 -- Undefined, or x=0 and y=0
    end
end

local curve = {}

-- normalize time → 0..1
function curve.normalize(time, duration)
    if duration <= 0 then return 1 end
    return math.min(time / duration, 1)
end

-- lerp
function curve.lerp(a, b, t)
    return a + (b - a) * t
end

-- easing functions
curve.easing = {}

function curve.easing.linear(t)
    return t
end

function curve.easing.expo_in(t)
    if t == 0 then return 0 end
    return math.pow(2, 10 * (t - 1))
end

function curve.easing.expo_out(t)
    if t == 1 then return 1 end
    return 1 - math.pow(2, -10 * t)
end

function curve.easing.expo_in_out(t)
    if t == 0 or t == 1 then return t end
    if t < 0.5 then
        return math.pow(2, 20 * t - 10) / 2
    else
        return (2 - math.pow(2, -20 * t + 10)) / 2
    end
end

-- sample curve with per-segment easing
function curve.sample(points, t)
    for i = 1, #points - 1 do
        local a = points[i]
        local b = points[i + 1]

        if t >= a.t and t <= b.t then
            local local_t = (t - a.t) / (b.t - a.t)

            local easing = b.easing or curve.easing.linear
            local e = easing(local_t)

            return curve.lerp(a.v, b.v, e)
        end
    end

    return points[#points].v
end

-- helper for time-based usage
function curve.get(points, time, duration)
    local t = curve.normalize(time, duration)
    return curve.sample(points, t)
end

extra_math.curve = curve
return extra_math
