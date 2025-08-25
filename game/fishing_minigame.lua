local fishing_minigame = {}
local size = require("game.size")

-- load fish icon
local fish_icon = love.graphics.newImage("assets/fish-icon.png")
local fish_icon_width = 64
local fish_icon_height = 64

-- fishing bar configuration
local BAR_WIDTH = 60  -- made really thin
local BAR_HEIGHT = 300
local BAR_LEVELS = 4
local LEVEL_HEIGHT = BAR_HEIGHT / BAR_LEVELS

-- fishing mechanics
local GRAVITY = 200  -- pixels per second squared
local ROD_SPEED = 300  -- pixels per second (increased for better control)
local CATCH_TIME = 5.0  -- seconds to catch fish
local CATCH_RANGE = 40  -- pixels from fish to catch (reduced from 60)
local PROGRESS_START = 0.5  -- progress bar starts at 1/2 full
local PERFECT_ALIGNMENT_BONUS = 0.3  -- bonus for being perfectly aligned

-- fishing state
local fishing_state = {
    is_active = false,
    fish_position = 0,
    rod_position = 0,
    rod_velocity = 0,
    mouse_angle = 0,
    mouse_radius = 0,
    mouse_x = 0,
    mouse_y = 0,
    last_mouse_x = 0,
    last_mouse_y = 0,
    mouse_movement = 0,
    catch_progress = PROGRESS_START,
    time_on_fish = 0,
    total_time = 0,
    perfect_catch = true,
    touches = 0,
    accuracy_score = 0,  -- tracks how well aligned you are
    fish_name = "",
    available_fish = {},
    rod_level = 1,
    depth_level = 1
}

-- initialize the fishing mini-game
function fishing_minigame.start_fishing(available_fish, rod_level, depth_level, water_color)
    fishing_state.is_active = true
    fishing_state.fish_position = math.random(50, BAR_HEIGHT - 50)
    fishing_state.rod_position = BAR_HEIGHT / 2  -- start halfway down the bar
    fishing_state.rod_velocity = 0
    fishing_state.mouse_angle = 0
    fishing_state.mouse_radius = 0
    fishing_state.catch_progress = PROGRESS_START
    fishing_state.time_on_fish = 0
    fishing_state.total_time = 0
    fishing_state.perfect_catch = true
    fishing_state.touches = 0
    fishing_state.available_fish = available_fish
    fishing_state.rod_level = rod_level
    fishing_state.depth_level = depth_level
    fishing_state.water_color = water_color or {0.1, 0.3, 0.6}  -- default if not provided
    
    -- don't pick the fish yet - just store available options
    fishing_state.fish_name = "???"  -- will be determined after completion
    
    -- initialize mouse position
    local mouse_x, mouse_y = love.mouse.getPosition()
    fishing_state.mouse_x = mouse_x
    fishing_state.last_mouse_x = mouse_x
    fishing_state.mouse_y = mouse_y
    fishing_state.last_mouse_y = mouse_y
    fishing_state.mouse_movement = 0
    fishing_state.accuracy_score = 0  -- reset accuracy score
    fishing_state.time_in_perfect = 0  -- reset time in perfect zone
    fishing_state.time_in_catch = 0  -- reset time in catch zone
    fishing_state.time_outside_catch = 0  -- reset time outside catch zone
    
    print("Fishing mini-game started! Fish will be determined by performance!")
end

-- update the fishing mini-game
function fishing_minigame.update(dt)
    if not fishing_state.is_active then
        return nil
    end
    
    -- update total time
    fishing_state.total_time = fishing_state.total_time + dt
    
    -- handle mouse input for rod control
    local mouse_x, mouse_y = love.mouse.getPosition()
    local center_x = size.CANVAS_WIDTH / 2
    local center_y = size.CANVAS_HEIGHT / 2
    
    -- calculate mouse movement
    local mouse_dx = mouse_x - fishing_state.last_mouse_x
    local mouse_dy = mouse_y - fishing_state.last_mouse_y
    local mouse_movement = math.sqrt(mouse_dx * mouse_dx + mouse_dy * mouse_dy)
    
    -- store current mouse position for next frame
    fishing_state.last_mouse_x = mouse_x
    fishing_state.last_mouse_y = mouse_y
    
    -- calculate mouse position relative to center
    local dx = mouse_x - center_x
    local dy = mouse_y - center_y
    fishing_state.mouse_angle = math.atan2(dy, dx)
    fishing_state.mouse_radius = math.sqrt(dx * dx + dy * dy)
    
    -- apply upward force based on mouse movement (spinning = more force)
    local max_movement = 30  -- pixels per frame (reduced for better sensitivity)
    local movement_multiplier = math.min(mouse_movement / max_movement, 4.0)  -- increased max multiplier
    
    -- also consider distance from center for additional control
    local radius_multiplier = math.min(fishing_state.mouse_radius / 100, 1.0)
    
    -- combine movement and radius for total force (more weight on movement)
    local total_multiplier = (movement_multiplier * 0.8) + (radius_multiplier * 0.2)
    
    -- apply force based on depth level (deeper = harder to control)
    local depth_difficulty = 1 + (fishing_state.depth_level - 1) * 0.5
    local upward_force = ROD_SPEED * total_multiplier / depth_difficulty
    
    -- apply gravity
    local rod_bonus = 1 + (fishing_state.rod_level - 1) * 0.1 -- 10% gravity reduction per rod level
    fishing_state.rod_velocity = fishing_state.rod_velocity + (GRAVITY / rod_bonus) * dt
    
    -- apply upward force from mouse movement
    fishing_state.rod_velocity = fishing_state.rod_velocity - upward_force * dt
    
    -- update rod position
    fishing_state.rod_position = fishing_state.rod_position + fishing_state.rod_velocity * dt
    
    -- clamp rod position to bar bounds and track touches
    if fishing_state.rod_position < 0 then
        fishing_state.rod_position = 0
        fishing_state.rod_velocity = 0
        fishing_state.touches = fishing_state.touches + 1
        fishing_state.perfect_catch = false
        print("Rod touched bottom boundary! Touches: " .. fishing_state.touches)
    elseif fishing_state.rod_position > BAR_HEIGHT then
        fishing_state.rod_position = BAR_HEIGHT
        fishing_state.rod_velocity = 0
        fishing_state.touches = fishing_state.touches + 1
        fishing_state.perfect_catch = false
        print("Rod touched top boundary! Touches: " .. fishing_state.touches)
    end
    
    -- check if rod is near fish
    local distance_to_fish = math.abs(fishing_state.rod_position - fishing_state.fish_position)
    local is_near_fish = distance_to_fish <= CATCH_RANGE
    
    if is_near_fish then
        -- calculate accuracy based on zones
        local accuracy_multiplier = 1.0
        
        if distance_to_fish <= 5 then
            -- perfect zone (small circle) - best accuracy
            accuracy_multiplier = 1.0 + PERFECT_ALIGNMENT_BONUS
            fishing_state.time_in_perfect = (fishing_state.time_in_perfect or 0) + dt
        elseif distance_to_fish <= 40 then
            -- catch zone (big circle) - acceptable but not great
            accuracy_multiplier = 1.0
            fishing_state.time_in_catch = (fishing_state.time_in_catch or 0) + dt
        else
            -- outside catch zone - poor accuracy
            accuracy_multiplier = 1.0
            fishing_state.time_outside_catch = (fishing_state.time_outside_catch or 0) + dt
        end
        
        -- increase catch progress with accuracy bonus
        fishing_state.time_on_fish = fishing_state.time_on_fish + dt
        fishing_state.catch_progress = fishing_state.catch_progress + (dt / CATCH_TIME) * 0.5 * accuracy_multiplier
        
        -- check if fish is caught
        if fishing_state.catch_progress >= 1.0 then
            return fishing_minigame.complete_fishing()
        end
    else
        -- decrease catch progress when not near fish (slower decay)
        fishing_state.catch_progress = math.max(0, fishing_state.catch_progress - dt * 0.2)
        
        -- if progress goes to 0, fish escapes
        if fishing_state.catch_progress <= 0 then
            return fishing_minigame.fail_fishing()
        end
    end
    
    return nil
end

-- complete fishing successfully
function fishing_minigame.complete_fishing()
    -- calculate quality score to determine final fish
    local quality_score = 0
    
    -- perfect catch bonus (no touches) - much smaller boost
    if fishing_state.perfect_catch then
        quality_score = quality_score + 10
        print("Perfect catch bonus: +10 points!")
    end
    
    -- calculate accuracy quality based on time spent in different zones
    local total_time = fishing_state.total_time
    local time_in_perfect = fishing_state.time_in_perfect or 0
    local time_in_catch = fishing_state.time_in_catch or 0
    local time_outside_catch = fishing_state.time_outside_catch or 0
    
    -- calculate percentages
    local perfect_percentage = (time_in_perfect / total_time) * 100
    local catch_percentage = (time_in_catch / total_time) * 100
    local outside_percentage = (time_outside_catch / total_time) * 100
    
    print(string.format("Accuracy breakdown: Perfect: %.1f%% | Catch zone: %.1f%% | Outside: %.1f%%", 
        perfect_percentage, catch_percentage, outside_percentage))
    
    -- determine accuracy quality
    local accuracy_quality = "Bad"
    local accuracy_bonus = 0
    
    if perfect_percentage >= 80 then
        -- Amazing: 80%+ time in perfect zone
        accuracy_quality = "Amazing"
        accuracy_bonus = 50
    elseif perfect_percentage >= 50 then
        -- Great: 50%+ time in perfect zone
        accuracy_quality = "Great"
        accuracy_bonus = 30
    elseif catch_percentage >= 70 then
        -- Good: 70%+ time in catch zone (mostly in big circle)
        accuracy_quality = "Good"
        accuracy_bonus = 10
    else
        -- Bad: mostly outside catch zone
        accuracy_quality = "Bad"
        accuracy_bonus = -20  -- penalty for poor accuracy
    end
    
    quality_score = quality_score + accuracy_bonus
    print("Accuracy quality: " .. accuracy_quality .. " (+" .. accuracy_bonus .. " points)")
    
    -- time bonus (faster = better) - more significant time impact
    local time_bonus = math.max(0, 80 - fishing_state.total_time)  -- increased from 60 to 80 points max
    quality_score = quality_score + time_bonus
    print("Time bonus: +" .. time_bonus .. " points (completed in " .. string.format("%.1f", fishing_state.total_time) .. "s)")
    
    -- touches penalty
    local touch_penalty = fishing_state.touches * 15  -- increased penalty per touch
    quality_score = quality_score - touch_penalty
    if touch_penalty > 0 then
        print("Touch penalty: -" .. touch_penalty .. " points (" .. fishing_state.touches .. " touches)")
    end
    
    -- determine final fish based on quality and available fish
    local final_fish = fishing_minigame.determine_final_fish(quality_score)
    
    local result = {
        success = true,
        fish_name = final_fish,
        original_fish = "???",  -- was never set during mini-game
        perfect_catch = fishing_state.perfect_catch,
        total_time = fishing_state.total_time,
        touches = fishing_state.touches,
        quality_score = quality_score
    }
    
    -- reset state
    fishing_state.is_active = false
    
    print("Fish caught! " .. final_fish .. " in " .. string.format("%.1f", fishing_state.total_time) .. "s")
    if fishing_state.perfect_catch then
        print("Perfect catch!")
    end
    print("Final quality score: " .. quality_score)
    
    return result
end

-- fail fishing
function fishing_minigame.fail_fishing()
    local result = {
        success = false,
        fish_name = "None",
        original_fish = "???",
        perfect_catch = false,
        total_time = fishing_state.total_time,
        touches = fishing_state.touches,
        quality_score = 0
    }
    
    -- reset state
    fishing_state.is_active = false
    
    print("Fish escaped!")
    return result
end

-- draw the fishing mini-game
function fishing_minigame.draw()
    if not fishing_state.is_active then
        return
    end
    
    -- get screen dimensions
    local screen_width = size.CANVAS_WIDTH
    local screen_height = size.CANVAS_HEIGHT
    
    -- calculate bar position (centered)
    local bar_x = (screen_width - BAR_WIDTH) / 2
    local bar_y = (screen_height - BAR_HEIGHT) / 2
    
    -- draw background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", bar_x - 30, bar_y - 20, BAR_WIDTH + 60, BAR_HEIGHT + 40)
    
    -- draw fishing bar with time-of-day gradient
    local water_color = fishing_state.water_color or {0.1, 0.3, 0.6}
    
    -- create gradient from current water color at top to darker version at bottom
    for i = 0, BAR_HEIGHT - 1 do
        local progress = i / BAR_HEIGHT  -- 0 at top, 1 at bottom
        local darken_factor = 0.7 + (progress * 0.3)  -- start at 70% brightness, darken to 40% (not near black)
        
        local r = water_color[1] * darken_factor
        local g = water_color[2] * darken_factor
        local b = water_color[3] * darken_factor
        
        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", bar_x, bar_y + i, BAR_WIDTH, 1)
    end
    
    -- draw level divider lines
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.setLineWidth(2)
    for i = 1, BAR_LEVELS - 1 do
        local y = bar_y + i * LEVEL_HEIGHT
        love.graphics.line(bar_x, y, bar_x + BAR_WIDTH, y)
    end
    
    -- draw level labels
    love.graphics.setColor(1, 1, 1, 0.7)
    for i = 1, BAR_LEVELS do
        local y = bar_y + (i - 1) * LEVEL_HEIGHT + LEVEL_HEIGHT / 2
        local level_text = "Level " .. i
        local text_width = love.graphics.getFont():getWidth(level_text)
        love.graphics.print(level_text, bar_x - text_width - 15, y - 10)
        
        -- draw difficulty indicator (deeper levels are harder)
        local difficulty = 1 + (i - 1) * 0.5
        local difficulty_text = string.format("x%.1f", difficulty)
        local diff_text_width = love.graphics.getFont():getWidth(difficulty_text)
        love.graphics.print(difficulty_text, bar_x + BAR_WIDTH + 15, y - 10)
    end
    
    -- draw fish icon - positioned in middle of bar
    local fish_x = bar_x + BAR_WIDTH / 2
    local fish_y = bar_y + fishing_state.fish_position
    
    -- draw catch range areas - only perfect zone is good (green), rest is penalty (red)
    -- outer zone (catch range) - red (penalty zone)
    love.graphics.setColor(1, 0, 0, 0.1)  -- very light red
    love.graphics.circle("fill", fish_x, fish_y, CATCH_RANGE)
    love.graphics.setColor(1, 0, 0, 0.3)  -- border
    love.graphics.circle("line", fish_x, fish_y, CATCH_RANGE)
    
    -- perfect zone only (5px) - bright green (reward zone)
    love.graphics.setColor(0, 1, 0, 0.25)  -- bright green
    love.graphics.circle("fill", fish_x, fish_y, 5)
    love.graphics.setColor(0, 1, 0, 0.6)  -- border
    love.graphics.circle("line", fish_x, fish_y, 5)
    
    -- draw fish icon with blended perfect zone indicator
    local icon_scale = 0.8  -- scale the icon down slightly
    
    -- save current graphics state
    love.graphics.push()
    
    -- create a stencil that only allows drawing on the fish icon pixels
    love.graphics.stencil(function()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(fish_icon, fish_x, fish_y, 0, icon_scale, icon_scale, 
            fish_icon_width / 2, fish_icon_height / 2)
    end, "replace", 1)
    
    -- enable stencil testing - only draw where fish icon pixels exist
    love.graphics.setStencilTest("greater", 0)
    
    -- use alpha blend mode instead of multiply for better compatibility
    love.graphics.setBlendMode("alpha")
    
    -- draw the perfect zone circle (blended with fish icon)
    love.graphics.setColor(0, 1, 0, 0.4)  -- green with lower transparency for better blending
    local perfect_zone_radius = 5
    love.graphics.circle("fill", fish_x, fish_y, perfect_zone_radius)
    
    -- restore stencil
    love.graphics.setStencilTest()
    
    -- restore graphics state
    love.graphics.pop()
    
    -- draw the fish icon on top
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(fish_icon, fish_x, fish_y, 0, icon_scale, icon_scale, 
        fish_icon_width / 2, fish_icon_height / 2)
    
    -- draw fishing line (from top of bar to fishing rod)
    love.graphics.setColor(0.8, 0.8, 0.8, 0.8)
    love.graphics.setLineWidth(2)
    local rod_x = bar_x + BAR_WIDTH / 2
    local rod_y = bar_y + fishing_state.rod_position
    love.graphics.line(bar_x + BAR_WIDTH / 2, bar_y, rod_x, rod_y)
    
    -- draw fishing rod (red and white circle) - positioned in middle of bar
    local rod_x = bar_x + BAR_WIDTH / 2
    local rod_y = bar_y + fishing_state.rod_position
    
    -- check if rod is near fish for visual feedback
    local distance_to_fish = math.abs(fishing_state.rod_position - fishing_state.fish_position)
    local is_near_fish = distance_to_fish <= CATCH_RANGE
    
    -- draw white circle (smaller for thin bar)
    if is_near_fish then
        love.graphics.setColor(0, 1, 0, 1)  -- green when near fish
    else
        love.graphics.setColor(1, 1, 1, 1)  -- white normally
    end
    love.graphics.circle("fill", rod_x, rod_y, 8)
    
    -- draw red circle (smaller for thin bar)
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.circle("fill", rod_x, rod_y, 5)
    
    -- draw accuracy zone indicator when near fish
    if is_near_fish then
        local distance_to_fish = math.abs(fishing_state.rod_position - fishing_state.fish_position)
        if distance_to_fish <= 5 then
            -- perfect alignment - bright green (reward)
            love.graphics.setColor(0, 1, 0, 0.6)
        else
            -- outside perfect zone - red (penalty)
            love.graphics.setColor(1, 0, 0, 0.4)
        end
        love.graphics.circle("line", rod_x, rod_y, 8)  -- small indicator around rod
    end
    
    -- draw mouse movement indicator (shows control intensity)
    local mouse_x, mouse_y = love.mouse.getPosition()
    local mouse_movement = math.sqrt((mouse_x - fishing_state.last_mouse_x)^2 + (mouse_y - fishing_state.last_mouse_y)^2)
    local movement_intensity = math.min(mouse_movement / 50, 1.0)
    
    if movement_intensity > 0.1 then
        love.graphics.setColor(1, 1, 0, movement_intensity * 0.5)  -- yellow glow based on movement
        love.graphics.circle("line", rod_x, rod_y, 12 + movement_intensity * 8)  -- smaller for thin bar
    end
    
    -- draw catch progress bar (green bar on the side)
    local progress_x = bar_x - 40  -- moved further left since bar is thinner
    local progress_y = bar_y
    local progress_width = 20
    local progress_height = BAR_HEIGHT
    
    -- draw background
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", progress_x, progress_y, progress_width, progress_height)
    
    -- draw progress
    love.graphics.setColor(0, 1, 0, 1)
    local filled_height = progress_height * fishing_state.catch_progress
    love.graphics.rectangle("fill", progress_x, progress_y + progress_height - filled_height, progress_width, filled_height)
    
    -- draw progress border
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", progress_x, progress_y, progress_width, progress_height)
    
    -- draw instructions
    love.graphics.setColor(1, 1, 1, 1)
    local instruction_text = "Move mouse in circles to control rod (faster movement = more force)"
    local text_width = love.graphics.getFont():getWidth(instruction_text)
    love.graphics.print(instruction_text, (screen_width - text_width) / 2, bar_y + BAR_HEIGHT + 30)
    
    -- draw fish name (shows ??? during mini-game)
    local fish_text = "Fish: " .. fishing_state.fish_name
    local fish_text_width = love.graphics.getFont():getWidth(fish_text)
    love.graphics.print(fish_text, (screen_width - fish_text_width) / 2, bar_y - 50)
    
    -- draw time
    local time_text = string.format("Time: %.1fs", fishing_state.total_time)
    local time_text_width = love.graphics.getFont():getWidth(time_text)
    love.graphics.print(time_text, (screen_width - time_text_width) / 2, bar_y - 30)
    
    -- draw catch progress text
    local progress_text = string.format("Catch: %.0f%%", fishing_state.catch_progress * 100)
    local progress_text_width = love.graphics.getFont():getWidth(progress_text)
    love.graphics.print(progress_text, (screen_width - progress_text_width) / 2, bar_y + BAR_HEIGHT + 10)
    
    -- draw touches counter
    local touches_text = "Touches: " .. fishing_state.touches
    local touches_text_width = love.graphics.getFont():getWidth(touches_text)
    love.graphics.print(touches_text, (screen_width - touches_text_width) / 2, bar_y + BAR_HEIGHT + 50)
    
    -- draw mouse movement debug info
    local mouse_x, mouse_y = love.mouse.getPosition()
    local center_x = size.CANVAS_WIDTH / 2
    local center_y = size.CANVAS_HEIGHT / 2
    local dx = mouse_x - center_x
    local dy = mouse_y - center_y
    local mouse_movement = math.sqrt((mouse_x - fishing_state.last_mouse_x)^2 + (mouse_y - fishing_state.last_mouse_y)^2)
    
    -- draw debug info in separate lines to avoid constant movement
    local debug_y = bar_y + BAR_HEIGHT + 90
    local debug_x = (screen_width - 200) / 2  -- center the debug info
    
    love.graphics.print("Mouse: (" .. math.floor(dx) .. ", " .. math.floor(dy) .. ")", debug_x, debug_y)
    love.graphics.print("Movement: " .. string.format("%.1f", mouse_movement), debug_x, debug_y + 20)
    love.graphics.print("Force: " .. string.format("%.1f", fishing_state.rod_velocity), debug_x, debug_y + 40)
    love.graphics.print("Catch Range: " .. CATCH_RANGE, debug_x, debug_y + 60)
    love.graphics.print("Perfect: " .. string.format("%.1f", fishing_state.time_in_perfect or 0) .. "s", debug_x, debug_y + 80)
    love.graphics.print("Catch: " .. string.format("%.1f", fishing_state.time_in_catch or 0) .. "s", debug_x, debug_y + 100)
    
    -- draw escape instruction
    local escape_text = "Press ESC to cancel fishing"
    local escape_text_width = love.graphics.getFont():getWidth(escape_text)
    love.graphics.print(escape_text, (screen_width - escape_text_width) / 2, bar_y + BAR_HEIGHT + 70)
end

-- determine final fish based on quality score
function fishing_minigame.determine_final_fish(quality_score)
    local available_fish = fishing_state.available_fish
    if #available_fish == 0 then
        return "Bluegill"
    end
    
    -- quality thresholds for fish upgrades/downgrades (made more challenging)
    if quality_score >= 180 then
        -- Legendary quality: upgrade to best available fish (requires near-perfect performance)
        local best_fish = available_fish[#available_fish]
        print("Legendary quality! You get the best fish: " .. best_fish)
        return best_fish
    elseif quality_score >= 140 then
        -- Excellent quality: high chance of upgrade
        local current_index = math.random(1, #available_fish)
        local target_index = math.min(current_index + 1, #available_fish)
        local target_fish = available_fish[target_index]
        print("Excellent quality! You get: " .. target_fish)
        return target_fish
    elseif quality_score >= 100 then
        -- Good quality: keep in upper tier
        local upper_half = math.ceil(#available_fish / 2)
        local fish_index = math.random(upper_half, #available_fish)
        local fish = available_fish[fish_index]
        print("Good quality! You get: " .. fish)
        return fish
    elseif quality_score >= 60 then
        -- Fair quality: middle tier fish
        local fish_index = math.ceil(#available_fish / 2)
        local fish = available_fish[fish_index]
        print("Fair quality! You get: " .. fish)
        return fish
    elseif quality_score >= 30 then
        -- Poor quality: lower tier fish
        local lower_half = math.floor(#available_fish / 2)
        local fish_index = math.random(1, lower_half)
        local fish = available_fish[fish_index]
        print("Poor quality! You get: " .. fish)
        return fish
    else
        -- Very poor quality: common fish or significant downgrade
        if quality_score < 0 then
            print("Very poor quality! You get a common fish")
            return "Bluegill"
        else
            local fish_index = math.max(1, math.floor(#available_fish / 3))
            local fish = available_fish[fish_index]
            print("Very poor quality! You get: " .. fish)
            return fish
        end
    end
end

-- cancel fishing
function fishing_minigame.cancel_fishing()
    if fishing_state.is_active then
        fishing_state.is_active = false
        print("Fishing cancelled")
        return {
            success = false,
            fish_name = "None",
            original_fish = "???",
            perfect_catch = false,
            total_time = fishing_state.total_time,
            touches = fishing_state.touches,
            quality_score = 0,
            cancelled = true
        }
    end
    return nil
end

-- stop fishing due to combat (fish escapes)
function fishing_minigame.combat_interrupt()
    if fishing_state.is_active then
        fishing_state.is_active = false
        print("Fishing interrupted by combat - fish escaped!")
        return {
            success = false,
            fish_name = "None",
            original_fish = "???",
            perfect_catch = false,
            total_time = fishing_state.total_time,
            touches = fishing_state.touches,
            quality_score = 0,
            combat_interrupt = true
        }
    end
    return nil
end

-- check if fishing is active
function fishing_minigame.is_active()
    return fishing_state.is_active
end

-- get current fishing state for debugging
function fishing_minigame.get_state()
    return fishing_state
end

return fishing_minigame
