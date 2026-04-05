local morningtext = {}
local size = require("game.size")

local morning_texts = {
    {"The water is blue this morning.", "Nice day for fishing."},
    {"Morning light dances across the sea.", "Your luck feels strong today."},
    {"The ocean stretches bright and wide.", "Today feels full of promise."},
    {"Gentle waves carry the ship forward.", "A good day has begun."},
    {"A cool breeze moves across the water.", "The sea is on your side."},
    {"The horizon glows in soft morning light.", "The voyage feels hopeful."},
    {"The sea is calm and clear.", "Take your time and fish well."},
    {"The sky brightens over the horizon.", "The water welcomes your line."},
    {"The morning tide rolls in smoothly.", "A steady hand catches plenty."},
    {"The sun climbs above the sea.", "Another fine day on the water."},
    {"The sea shimmers under early light.", "It feels like a lucky morning."},
    {"Soft winds guide the waves along.", "Your hands feel steady today."},
    {"The water ripples in quiet patterns.", "Patience will reward you."},
    {"A pale sun rises over the horizon.", "The day begins gently."},
    {"The tide drifts in without hurry.", "Take things slow."},
    {"Light glints off the moving water.", "Keep your line true."},
    {"The ocean breathes in calm rhythm.", "You are in step with it."},
    {"A quiet stillness rests on the sea.", "Its a good day to fish."},
    {"The wind carries a hint of salt.", "Stay focused and youll do well."},
    {"Waves lap softly against the hull.", "The morning feels kind."},
    {"The sky opens in soft blue tones.", "Theres no need to rush."},
    {"The water lies smooth and endless.", "Trust your instincts."},
    {"A gentle current pulls beneath you.", "Let it guide your rhythm."},
    {"The horizon stretches far and quiet.", "Today holds simple rewards."},
    {"The sea reflects the waking sky.", "Your luck hasnt left you."},
    {"A calm settles over the waves.", "Work with care."},
    {"The breeze is light but steady.", "Keep your balance."},
    {"The ocean hums in low tones.", "Listen and follow along."},
    {"Morning spreads slowly across the water.", "Everything feels within reach."},
    {"A calm day stretches ahead.", "Make the most of it."}
}

local night_texts = {
    {"The tide begins to roar.", "Fish abound like never before."},
    {"Dark water rolls in heavy bands.", "Every cast feels electric."},
    {"Night settles over the sea.", "The deep starts to wake."},
    {"The moon cuts a silver path.", "Your line vanishes into black."},
    {"Cold wind skims the surface.", "Big shapes move below."},
    {"The waves hit harder now.", "The best fish are hunting."},
    {"The sky turns ink-black.", "The ocean grows louder."},
    {"Whitecaps flash in moonlight.", "Prime feeding hours begin."},
    {"The decks creak in the dark.", "Something large is circling."},
    {"The water feels alive tonight.", "You can sense every bite."},
    {"The current pulls with intent.", "The deep is open for business."},
    {"Night fog drifts over the hull.", "Keep your hands steady."},
    {"The horizon disappears.", "Only the line and the pull remain."},
    {"The ocean mutters in the dark.", "Fish rush the upper layers."},
    {"The moon rides high overhead.", "The schools are moving fast."},
    {"A sharp chill hits the deck.", "Predators are on the move."},
    {"Black water slaps the bow.", "Heavy fish are close."},
    {"The sea glows faintly at the edges.", "A rare night bite is on."},
    {"Wind howls across open water.", "Your next cast could be huge."},
    {"The dark tide rises.", "The ocean is feeding."},
    {"Foam trails behind the hull.", "The deep wants to fight."},
    {"The stars sharpen overhead.", "Fish strike without warning."},
    {"The silence breaks in sudden bursts.", "Youre in trophy water."},
    {"Night pushes the shoreline away.", "Only the sea matters now."},
    {"The waves pound in a steady rhythm.", "You match it cast for cast."},
    {"The moonlit chop turns rough.", "Big bites come in chaos."},
    {"A dark swell lifts the ship.", "The next pull could be massive."},
    {"The sea takes on a metallic shine.", "Everything below is moving."},
    {"The wind leans hard on the mast.", "Fish cluster in the turbulence."},
    {"Night deepens by the minute.", "The bite only gets better."},
    {"The tide hammers the keel.", "The deep is wide awake."},
    {"Spray hits cold across the deck.", "Perfect conditions for monsters."},
    {"The ocean breathes in long surges.", "You fish between each pulse."},
    {"The stars blur behind cloud.", "The water below turns wild."},
    {"A low roar rolls across the waves.", "The schools are stacked tonight."},
    {"The moon slips behind cloud.", "The dark water boils with life."},
    {"The sea feels heavier now.", "Something rare is near."},
    {"The surface trembles in moonlight.", "Fish surge from the deep."},
    {"Night current cuts across the bow.", "Your bait will not wait long."},
    {"The wind shifts without warning.", "So do the fish."},
    {"The ocean turns restless.", "This is peak night fishing."},
    {"The deck lights flicker on spray.", "Every shadow could be a strike."},
    {"The dark tide stacks high.", "Bigger fish move shallow."},
    {"Moonlight streaks across the chop.", "The bite window is wide open."},
    {"The hull groans through rough water.", "You keep casting anyway."},
    {"The sea roars and answers back.", "Tonight rewards bold lines."},
    {"Black waves rush under the keel.", "The best catches come now."},
    {"The night current pulls hard.", "The fish pull harder."},
    {"The stars fade behind spray.", "The water below erupts."},
    {"The ocean is loud and hungry.", "Perfect time to fish."},
    {"The waves grow louder in the dark.", "The fish are restless tonight."},
    {"The tide begins to stir.", "Something moves beneath you."},
    {"Moonlight stretches across the sea.", "Your luck feels uncertain."},
    {"The water churns softly.", "Your line won’t stay still."},
    {"A cold wind passes over the deck.", "You feel it watching."},
    {"The sea glows under the moon.", "Fish gather in the deep."},
    {"The night is quiet... too quiet.", "Your catch won’t be ordinary."},
    {"The tide pulls stronger now.", "Hold your line tight."},
    {"Dark waves roll beneath you.", "The sea is alive tonight."},
    {"The stars reflect in the water.", "So do things that aren’t stars."},
    {"A distant splash echoes.", "You weren’t the one who made it."},
    {"The ocean breathes heavier at night.", "It gives, but it takes."},
    {"The water shifts in uneven patterns.", "Something is following your bait."},
    {"The moon hangs low over the horizon.", "Your luck turns strange."},
    {"The sea feels deeper tonight.", "You can’t see the bottom."},
    {"The wind carries a low hum.", "You can’t tell where it’s from."},
    {"The tide roars louder now.", "Fish abound like never before."},
    {"The surface ripples without reason.", "Cast your line anyway."},
    {"The night air feels heavy.", "The catch will be worth it."},
    {"The sea reflects no light.", "Only movement."}
}

local corrupted_texts = {
    [0.1] = {
        "The sea looks darker today.",
        "Your crew seems quieter than usual."
    },
    [0.2] = {
        "The water moves strangely beneath the boat.",
        "Your crew wants to go back home."
    },
    [0.3] = {
        "The ocean feels wrong somehow.",
        "Your crew avoids meeting your eyes."
    },
    [0.4] = {
        "The sea is black.",
        "Your crew whispers among themselves."
    },
    [0.5] = {
        "You know it.",
        "Your crew knows it."
    }
}

local TYPEWRITER_CHARS_PER_SECOND = 26
local START_DELAY = 2.0
local HOLD_TIME = 5.0
local FADE_DURATION = 1.2
local MARGIN = 20
local LINE_SPACING = 8
local TEXT_SCALE = 1.6
local NIGHT_TRIGGER_HOUR = 9.0

local state = {
    active = false,
    timer = 0,
    reveal_chars = 0,
    lines = nil,
    last_time_hours = nil,
    night_triggered_today = false
}

local function round_to_tenth(value)
    return math.floor(value * 10 + 0.5) / 10
end

local function get_corrupted_lines(rainbows)
    local key = round_to_tenth(math.max(0, tonumber(rainbows) or 0))
    while key >= 0.1 do
        if corrupted_texts[key] then
            return corrupted_texts[key]
        end
        key = round_to_tenth(key - 0.1)
    end
    return nil
end

local function pick_random(lines)
    return lines[math.random(1, #lines)]
end

local function get_alpha()
    if not state.active then
        return 0
    end

    if state.timer <= START_DELAY + HOLD_TIME then
        return 1
    end

    local fade_t = (state.timer - (START_DELAY + HOLD_TIME)) / FADE_DURATION
    return math.max(0, 1 - fade_t)
end

local function get_revealed_lines()
    local line1_full = state.lines[1] or ""
    local line2_full = state.lines[2] or ""
    local total_visible_chars = math.floor(state.reveal_chars)

    local line1_visible = math.min(#line1_full, total_visible_chars)
    local line2_visible = math.max(0, total_visible_chars - #line1_full)

    local line1 = string.sub(line1_full, 1, line1_visible)
    local line2 = string.sub(line2_full, 1, line2_visible)
    return line1, line2
end

local function start_lines(lines)
    state.lines = lines
    state.active = true
    state.timer = 0
    state.reveal_chars = 0
end

function morningtext.start(rainbows)
    local corrupted = get_corrupted_lines(rainbows)
    if corrupted then
        start_lines(corrupted)
    else
        start_lines(pick_random(morning_texts))
    end
end

function morningtext.start_night()
    start_lines(pick_random(night_texts))
end

function morningtext.observe_time(time_hours)
    local hours = tonumber(time_hours)
    if not hours then
        return
    end

    if state.last_time_hours ~= nil and hours < state.last_time_hours then
        state.night_triggered_today = false
    end

    if not state.night_triggered_today and hours >= NIGHT_TRIGGER_HOUR then
        morningtext.start_night()
        state.night_triggered_today = true
    end

    state.last_time_hours = hours
end

function morningtext.update(dt)
    if not state.active then
        return
    end

    state.timer = state.timer + dt
    local visible_time = math.max(0, state.timer - START_DELAY)
    state.reveal_chars = visible_time * TYPEWRITER_CHARS_PER_SECOND

    if state.timer >= START_DELAY + HOLD_TIME + FADE_DURATION then
        state.active = false
    end
end

function morningtext.draw()
    if not state.active or not state.lines then
        return
    end

    local alpha = get_alpha()
    if alpha <= 0 then
        return
    end

    local line1, line2 = get_revealed_lines()
    local font = love.graphics.getFont()
    local line1_w = font:getWidth(line1) * TEXT_SCALE
    local line2_w = font:getWidth(line2) * TEXT_SCALE
    local text_h = font:getHeight() * TEXT_SCALE

    local block_height = text_h * 2 + LINE_SPACING
    local block_y = size.CANVAS_HEIGHT - MARGIN - block_height
    local line1_y = block_y
    local line2_y = block_y + text_h + LINE_SPACING

    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.print(line1, (size.CANVAS_WIDTH - line1_w) / 2, line1_y, 0, TEXT_SCALE, TEXT_SCALE)
    love.graphics.print(line2, (size.CANVAS_WIDTH - line2_w) / 2, line2_y, 0, TEXT_SCALE, TEXT_SCALE)
    love.graphics.setColor(1, 1, 1, 1)
end

function morningtext.reset()
    state.active = false
    state.timer = 0
    state.reveal_chars = 0
    state.lines = nil
    state.last_time_hours = nil
    state.night_triggered_today = false
end

return morningtext
