local constants = require("game.constants")

local time_utils = {}

local DEFAULT_HOURS_PER_DAY = 12

function time_utils.time_of(clock_text, day_length, hours_per_day)
    local text = tostring(clock_text or "")
    local hour_text, minute_text = text:match("^(%d%d?):(%d%d)$")
    if not hour_text or not minute_text then
        return nil, "expected HH:MM"
    end

    local hour = tonumber(hour_text)
    local minute = tonumber(minute_text)
    local total_hours = tonumber(hours_per_day) or DEFAULT_HOURS_PER_DAY
    local total_day_length = tonumber(day_length) or constants.time.day_length

    if not hour or not minute then
        return nil, "expected numeric HH:MM"
    end
    if minute < 0 or minute > 59 then
        return nil, "minute out of range"
    end
    if hour < 0 or hour > total_hours then
        return nil, "hour out of range"
    end
    if hour == total_hours and minute > 0 then
        return nil, "time past end of day"
    end

    local total_minutes = (hour * 60) + minute
    local minutes_in_day = total_hours * 60
    return (total_minutes / minutes_in_day) * total_day_length
end

return time_utils
