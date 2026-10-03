local constants = require("game.constants")
local size = require("game.size")

local days = {}

local PIXELS_PER_STEP = constants.days.pixels_per_step
local TELEPORT_PIXELS = constants.days.teleport_pixels

local player_ship = nil
local runtime = {}
local view_index = nil
local title_on_close = false
local alert = require("game.alert")

local function new_entry(number)
    return {
        number = number,
        events = {},
        fish_discovered = 0,
        fish_caught = 0,
        coins_gained = 0,
        coins_lost = 0,
        men_gained = 0,
        men_lost = 0,
        enemies_defeated = 0,
        pixels = 0
    }
end

local function reset_runtime()
    runtime = {}
end

local function seed_discovered(ship)
    local discovered = {}
    for _, name in ipairs(ship.caught_fish or {}) do
        discovered[name] = true
    end
    for _, name in ipairs(ship.inventory or {}) do
        if type(name) == "string" then
            discovered[name] = true
        end
    end
    return discovered
end

local function get_ship_position(ship)
    if ship.is_on_foot then
        return ship.on_foot_x or ship.x, ship.on_foot_y or ship.y
    end
    return ship.x, ship.y
end

local function get_section(y)
    return math.max(0, math.floor((tonumber(y) or 0) / constants.fishing_level))
end

local function ensure()
    local data = player_ship.days
    if type(data) ~= "table" or type(data.log) ~= "table" or #data.log == 0 then
        -- fresh game, or an older save made before days existed
        local x, y = get_ship_position(player_ship)
        local already_sailed = (tonumber(y) or 0) > constants.ship.start_y or (tonumber(x) or 0) ~= constants.ship.start_x
        data = {
            log = {new_entry((tonumber(player_ship.days_passed) or 0) + 1)},
            discovered = seed_discovered(player_ship),
            departed = already_sailed,
            max_section = get_section(y)
        }
        player_ship.days = data
    end
    return data
end

local function current()
    local log = ensure().log
    return log[#log]
end

local function add_event(text, highlight, kind)
    local events = current().events
    events[#events + 1] = {text = text, highlight = highlight == true, kind = kind}
end

local function has_event(entry, kind)
    for _, event in ipairs(entry.events) do
        if event.kind == kind then
            return true
        end
    end
    return false
end

function days.attach(ship)
    player_ship = ship
    reset_runtime()
    view_index = nil
end

-- forget everything (new game); the next ensure() starts day 1
function days.reset()
    if player_ship then
        player_ship.days = nil
        player_ship.days_passed = 0
    end
    reset_runtime()
    view_index = nil
    title_on_close = false
end

function days.get_number()
    return current().number
end

function days.record_catch(fish_name)
    local data = ensure()
    local entry = current()
    entry.fish_caught = entry.fish_caught + 1

    if not data.discovered[fish_name] then
        data.discovered[fish_name] = true
        entry.fish_discovered = entry.fish_discovered + 1
    end

    if fish_name == "Gold Sturgeon" then
        add_event("Caught a GOLD STURGEON!!!", true, "gold_sturgeon")
    elseif fish_name == "Sturgeon" then
        add_event("Caught a Sturgeon!", false, "sturgeon")
    end
end

function days.record_enemy_defeated()
    local entry = current()
    entry.enemies_defeated = (entry.enemies_defeated or 0) + 1
end

function days.record_shipwreck()
    add_event("Shipwrecked in a thunderstorm!", true, "shipwreck")
end

local function track_upgrade(slot, name, level)
    local previous = runtime[slot]
    runtime[slot] = level
    if previous and level > previous then
        add_event(name .. " unlocked!", false, "upgrade")
    end
end

-- diff the world against the last frame; cheap, and catches changes made anywhere in the code
function days.sample(state)
    if not player_ship then
        return
    end
    local data = ensure()
    local entry = current()

    local coins = tonumber(state.shop.module.get_coins()) or 0
    if runtime.coins then
        local delta = coins - runtime.coins
        if delta > 0 then
            entry.coins_gained = entry.coins_gained + delta
        elseif delta < 0 then
            entry.coins_lost = entry.coins_lost - delta
        end
    end
    runtime.coins = coins

    local men = tonumber(player_ship.men) or 0
    if runtime.men then
        local delta = men - runtime.men
        if delta > 0 then
            entry.men_gained = entry.men_gained + delta
        elseif delta < 0 then
            entry.men_lost = entry.men_lost - delta
        end
    end
    runtime.men = men

    local x, y = get_ship_position(player_ship)
    local mode = player_ship.is_swimming and "swim" or (player_ship.is_on_foot and "foot" or "boat")
    local moved = false
    if runtime.x and runtime.mode == mode then
        local dist = math.sqrt((x - runtime.x) ^ 2 + (y - runtime.y) ^ 2)
        if dist > 0 and dist < TELEPORT_PIXELS then
            entry.pixels = entry.pixels + dist
            moved = true
        end
    end
    runtime.x, runtime.y, runtime.mode = x, y, mode

    if mode == "boat" then
        if moved and not data.departed then
            data.departed = true
            add_event("Departed from shore for the first time!", false, "departed")
        end
        local section = get_section(y)
        if section > data.max_section then
            data.max_section = section
            add_event("Section " .. section .. " unlocked!", false, "section")
        end
    end

    track_upgrade("rod", player_ship.rod, state.fishing.module.get_rod_level(player_ship.rod))
    track_upgrade("sword", player_ship.sword, state.combat.module.get_sword_level(player_ship.sword))
end

-- close out the current day and start the next one; called as the player falls asleep
function days.next_day(state)
    days.sample(state) -- flush anything that changed since the last frame into the day that earned it
    local data = ensure()
    -- stamp the closing day with how far the corruption has come, so the journal can mourn it
    data.log[#data.log].rainbows_level = math.floor((tonumber(player_ship.rainbows) or 0) * 10 + 0.5)
    player_ship.days_passed = (tonumber(player_ship.days_passed) or 0) + 1
    data.log[#data.log + 1] = new_entry(player_ship.days_passed + 1)
    runtime.x = nil -- sleeping may move the ship to the dock
end

local function format_number(n)
    local text = tostring(math.floor((tonumber(n) or 0) + 0.5))
    local formatted = text
    repeat
        local replaced
        formatted, replaced = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    until replaced == 0
    return formatted
end

local NUMBER_WORDS = {
    [0] = "no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
    "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty"
}

local function number_word(n)
    return NUMBER_WORDS[n] or tostring(n)
end

-- Jonas's only journal lines once the captain has cheated; one per rainbow level
local CHEATED_NOTES = {
    "Why did he do that...",
    "I thought we were friends...",
    "I still can't believe it...",
    "The other guys agree...",
    "Walk the plank!"
}

local function pick(entry, options)
    return options[(entry.number % #options) + 1]
end

-- the narrator's note for the day, written from the day's events and stats
function days.get_commentary(entry)
    local cheated_level = math.min(#CHEATED_NOTES, tonumber(entry.rainbows_level) or 0)
    if cheated_level >= 1 then
        return CHEATED_NOTES[cheated_level]
    end

    local name = constants.ship.start_crew_name
    local lost = entry.men_lost or 0
    local notes = {}

    if has_event(entry, "shipwreck") then
        if lost > 0 then
            notes[#notes + 1] = string.format(
                "We lost %s %s today. I don't know how the captain managed to get us to shore, but somehow we made it.",
                number_word(lost), lost == 1 and "man" or "men")
        else
            notes[#notes + 1] = "The storm took the ship out from under us. I don't know how the captain managed to get us to shore, but somehow we made it."
        end
    elseif lost > 0 then
        notes[#notes + 1] = string.format(
            "We lost %s %s today. The sea doesn't ask, it only takes.",
            number_word(lost), lost == 1 and "man" or "men")
    end

    if has_event(entry, "gold_sturgeon") then
        notes[#notes + 1] = "A Gold Sturgeon. I have never seen anything shine like that. Nobody is allowed to touch it, and nobody wants to."
    elseif has_event(entry, "sturgeon") then
        notes[#notes + 1] = "We landed a Sturgeon today. The men are calling it a good omen."
    end

    if (entry.enemies_defeated or 0) > 0 then
        notes[#notes + 1] = string.format(
            "We fought %s %s and won. The captain says we were lucky; I say we were good.",
            number_word(entry.enemies_defeated), entry.enemies_defeated == 1 and "ship" or "ships")
    end

    if has_event(entry, "departed") then
        notes[#notes + 1] = "First time away from shore. The captain says not to look back, so of course I did."
    end
    if has_event(entry, "section") then
        notes[#notes + 1] = "The water out here is darker, and the fish are bigger. So is everything else."
    end
    if has_event(entry, "upgrade") then
        notes[#notes + 1] = "New gear today. It feels like we might actually survive out here."
    end
    if (entry.men_gained or 0) > 0 and lost == 0 then
        notes[#notes + 1] = "There are more of us than yesterday. The deck feels a little less empty."
    end

    if #notes == 0 then
        notes[1] = pick(entry, {
            "Quiet day. The nets were light but so was my heart.",
            "Nothing worth writing, which out here is the best kind of day.",
            "Calm seas. I mended rope and watched the horizon."
        })
    end

    -- keep the page short: lead with the two weightiest notes
    return table.concat(notes, " ", 1, math.min(2, #notes))
end

function days.get_lines(entry)
    local lines = {}
    for _, event in ipairs(entry.events) do
        lines[#lines + 1] = {text = event.text, highlight = event.highlight}
    end
    lines[#lines + 1] = {text = ""}
    lines[#lines + 1] = {text = days.get_commentary(entry), note = true}
    lines[#lines + 1] = {text = ""}
    local stats = {
        string.format("+%s fish discovered", format_number(entry.fish_discovered)),
        string.format("+%s fish caught", format_number(entry.fish_caught)),
        string.format("+%s coins", format_number(entry.coins_gained)),
        string.format("-%s coins", format_number(entry.coins_lost)),
        string.format("+%s men", format_number(entry.men_gained)),
        string.format("-%s men", format_number(entry.men_lost)),
        string.format("%s enemies defeated", format_number(entry.enemies_defeated or 0)),
        string.format("%s steps walked", format_number(entry.pixels / PIXELS_PER_STEP))
    }
    for _, text in ipairs(stats) do
        lines[#lines + 1] = {text = text}
    end
    return lines
end

function days.is_open()
    return view_index ~= nil
end

function days.open()
    local log = ensure().log
    view_index = #log
end

local function close_view()
    view_index = nil
    if title_on_close then
        title_on_close = false
        alert.title("Day " .. current().number, 3, {1, 1, 1, 1}, 0.5, 0.8)
    end
end

function days.close()
    close_view()
end

-- sunrise: recap the day that just ended; the "Day N" title shows once it's dismissed
function days.show_recap()
    local log = ensure().log
    if #log < 2 then
        alert.title("Day " .. current().number, 3, {1, 1, 1, 1}, 0.5, 0.8)
        return
    end
    view_index = #log - 1
    title_on_close = true
end

-- returns true if the key was consumed
function days.keypressed(key)
    if not view_index then
        return false
    end
    local count = #ensure().log
    if key == "left" then
        view_index = view_index - 1
        if view_index < 1 then
            view_index = count
        end
    elseif key == "right" then
        view_index = view_index + 1
        if view_index > count then
            view_index = 1
        end
    elseif key == "escape" or key == "return" or key == "space" then
        close_view()
    end
    return true
end

function days.draw()
    if not view_index or not player_ship then
        return
    end
    local log = ensure().log
    view_index = math.min(view_index, #log)
    local entry = log[view_index]

    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, size.CANVAS_WIDTH, size.CANVAS_HEIGHT)

    local font = love.graphics.getFont()
    local title_scale = 2
    local line_height = font:getHeight() + 6
    local wrap_width = math.min(520, size.CANVAS_WIDTH - 40)
    local lines = {}
    for _, line in ipairs(days.get_lines(entry)) do
        if line.note then
            local _, wrapped = font:getWrap(line.text, wrap_width)
            for _, text in ipairs(wrapped) do
                lines[#lines + 1] = {text = text, note = true}
            end
        else
            lines[#lines + 1] = line
        end
    end
    local block_height = (font:getHeight() * title_scale) + 16 + line_height + (#lines * line_height) + 16 + font:getHeight()
    local y = math.max(12, (size.CANVAS_HEIGHT - block_height) / 2)

    local function centered(text, scale)
        love.graphics.print(text, (size.CANVAS_WIDTH - font:getWidth(text) * scale) / 2, y, 0, scale, scale)
    end

    love.graphics.setColor(1, 1, 1, 1)
    centered("Day " .. entry.number, title_scale)
    y = y + (font:getHeight() * title_scale) + 4
    love.graphics.setColor(1, 1, 1, 0.55)
    centered(constants.ship.start_crew_name .. "'s Journal", 1)
    y = y + line_height + 12

    for _, line in ipairs(lines) do
        if line.highlight then
            love.graphics.setColor(1, 0.85, 0.2, 1)
        elseif line.note then
            love.graphics.setColor(0.75, 0.82, 0.95, 1)
        else
            love.graphics.setColor(1, 1, 1, 1)
        end
        centered(line.text, 1)
        y = y + line_height
    end

    y = y + 16
    love.graphics.setColor(1, 1, 1, 0.55)
    centered(string.format("< %d / %d >    Esc to close", view_index, #log), 1)
    love.graphics.setColor(1, 1, 1, 1)
end

return days
