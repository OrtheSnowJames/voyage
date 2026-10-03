-- how many times the player has beaten the game.
-- lives in its own signed file (not save.lua) so wiping or resetting a save never touches it,
-- and any edit to the file makes the count fall back to 0.
local times_beaten = {}

local PATH = "times_beaten.dat"
-- keyed hash secret: this is deterrence, not security, since the game ships its own source
local SECRET = "v0yage-0f-the-b34ten-0nes"

local cached = nil

local function to_hex(raw)
    return (raw:gsub(".", function(c)
        return string.format("%02x", c:byte())
    end))
end

local function sign(count)
    local payload = SECRET .. "|" .. tostring(count) .. "|" .. SECRET:reverse()
    return to_hex(love.data.hash("sha256", payload))
end

local function write(count)
    love.filesystem.write(PATH, count .. ":" .. sign(count))
end

-- reads and verifies the file; anything missing, malformed or forged counts as 0
local function read()
    local content = love.filesystem.getInfo(PATH) and love.filesystem.read(PATH) or nil
    if not content then
        return 0
    end

    local count_text, signature = tostring(content):match("^(%d+):(%x+)$")
    local count = tonumber(count_text)
    if not count or count_text ~= tostring(count) or signature ~= sign(count) then
        print("times_beaten file was tampered with - resetting to 0")
        write(0)
        return 0
    end
    return count
end

function times_beaten.get()
    if cached == nil then
        cached = read()
    end
    return cached
end

function times_beaten.increment()
    -- re-read from disk so an edit made while the game is running is caught before it is built on
    cached = read()
    cached = cached + 1
    write(cached)
    return cached
end

-- forget the in-memory copy so the next get() re-verifies the file
function times_beaten.refresh()
    cached = nil
end

return times_beaten
