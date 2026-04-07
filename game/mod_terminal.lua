local mods = require("game.mods")
local scrolling = require("game.scrolling")

local mod_terminal = {}
mod_terminal.__index = mod_terminal

local LAUNCH_TOTAL_DURATION = 2.0
local LAUNCH_TEXT_FADE_DURATION = 0.2
local LAUNCH_BG_FADE_DURATION = 0.2
local scanline_shader = nil

local function get_scanline_shader()
    if scanline_shader then
        return scanline_shader
    end

    local ok, shader_or_err = pcall(love.graphics.newShader, [[
        extern number lineSpacing;
        extern number darkness;
        extern number yOffset;

        vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
            number row = floor((screen_coords.y - yOffset) / max(1.0, lineSpacing));
            number shade = (mod(row, 2.0) == 0.0) ? darkness : 1.0;
            return vec4(color.rgb * shade, color.a);
        }
    ]])

    if ok then
        scanline_shader = shader_or_err
    else
        print("[mod_terminal] scanline shader failed: " .. tostring(shader_or_err))
        scanline_shader = false
    end

    return scanline_shader
end

local function clamp(value, min_value, max_value)
    if value < min_value then
        return min_value
    end
    if value > max_value then
        return max_value
    end
    return value
end

local function autocomplete(input, commands)
    local matches = {}

    for _, cmd in ipairs(commands) do
        if cmd:sub(1, #input) == input then
            table.insert(matches, cmd)
        end
    end

    if #matches == 0 then
        return input
    end

    -- one match → complete fully
    if #matches == 1 then
        return matches[1]
    end

    -- multiple → find common prefix
    local prefix = matches[1]

    for i = 2, #matches do
        local m = matches[i]
        local j = 1

        while j <= #prefix and j <= #m and prefix:sub(j,j) == m:sub(j,j) do
            j = j + 1
        end

        prefix = prefix:sub(1, j - 1)
    end

    return prefix
end

local function autocomplete_ci(input, commands)
    local lowered = {}
    local lookup = {}
    for _, cmd in ipairs(commands) do
        local lc = cmd:lower()
        table.insert(lowered, lc)
        lookup[lc] = cmd
    end

    local completed_lower = autocomplete(input:lower(), lowered)
    if lookup[completed_lower] then
        return lookup[completed_lower]
    end
    return completed_lower
end

local function split_first_token(text)
    local first, rest = text:match("^(%S+)%s*(.*)$")
    return first, rest
end

function mod_terminal.new(opts)
    return setmetatable({
        on_start = opts and opts.on_start or function() end,
        active = true,
        ready = false,
        is_mobile = false,
        input = "",
        log = {},
        cursor_timer = 0,
        screen_font = nil,
        prompt = "> ",
        button_boxes = {},
        scroll = nil,
        scroll_to_bottom_pending = false,
        launching = false,
        launch_timer = 0
    }, mod_terminal)
end

function mod_terminal:is_active()
    return self.active
end

function mod_terminal:push(text)
    table.insert(self.log, tostring(text))
    self.scroll_to_bottom_pending = true
end

function mod_terminal:refresh_listing()
    local files = mods.list_mod_files()
    self:push("")
    self:push("mods found:")
    if #files == 0 then
        self:push("  (none)")
    else
        for _, file in ipairs(files) do
            local status = mods.is_file_enabled(file) and "enabled " or "disabled"
            self:push(string.format("  [%s] %s", status, file))
        end
    end
end

function mod_terminal:print_help()
    self:push("commands:")
    self:push("  help")
    self:push("  list")
    self:push("  enable x.lua")
    self:push("  disable y.lua")
    self:push("  enable all")
    self:push("  disable all")
    self:push("  start")
    self:push("  run")
end

function mod_terminal:finish_and_start()
    self.active = false
    self.launching = false
    self.launch_timer = 0
    self.on_start()
end

function mod_terminal:begin_start()
    if self.launching then
        return
    end
    self.launching = true
    self.launch_timer = 0
    self:push("starting...")
end

function mod_terminal:setup()
    if self.ready then
        return
    end

    self.ready = true
    self.is_mobile = (love.system.getOS() == "iOS" or love.system.getOS() == "Android")
    self.screen_font = love.graphics.newFont(18)
    self.scroll = scrolling.new()
    self.log = {}

    mods.set_enabled(true)
    mods.enable_all_files()
    local files = mods.list_mod_files()
    if #files == 0 then
        self:finish_and_start()
        return
    end

    self:push("Linux 5.4.0-voyage #1 SMP PREEMPT")
    self:push("All rights reserved.")
    self:push("")
    self:push("Voyage Mod Control Terminal")
    self:push(self.prompt .. "help")
    self:print_help()
    self:push("")
    self:push(self.prompt .. "list")
    self:refresh_listing()
    if self.is_mobile then
        self:push("")
        self:push("mobile: tap one button below")
    else
        self:push("")
        self:push("type command and press enter")
    end
end

function mod_terminal:apply_enable_all(enabled)
    if enabled then
        mods.set_enabled(true)
        mods.enable_all_files()
        self:push("enabled all mods")
    else
        mods.set_enabled(false)
        mods.disable_all_files()
        self:push("disabled all mods")
    end
end

function mod_terminal:run_command(raw)
    local command = raw:match("^%s*(.-)%s*$")
    if command == "" then
        return
    end

    self:push(self.prompt .. command)
    local lower = command:lower()
    local action_raw, arg_raw = command:match("^(%S+)%s+(.+)$")
    local action = action_raw and action_raw:lower() or nil
    local arg = arg_raw and arg_raw:match("^%s*(.-)%s*$") or nil

    if lower == "help" then
        self:print_help()
        return
    end

    if lower == "list" then
        self:refresh_listing()
        return
    end

    if lower == "start" or lower == "run" then
        self:begin_start()
        return
    end

    if (action == "enable" or action == "disable") and arg and arg:lower() == "all" then
        self:apply_enable_all(action == "enable")
        return
    end

    if (action == "enable" or action == "disable") and arg and arg:sub(-4):lower() == ".lua" then
        local chosen = nil
        for _, file in ipairs(mods.list_mod_files()) do
            if file:lower() == arg:lower() then
                chosen = file
                break
            end
        end
        if not chosen then
            self:push("mod not found: " .. arg)
            return
        end
        mods.set_enabled(true)
        mods.set_file_enabled(chosen, action == "enable")
        self:push(string.format("%s %s", action == "enable" and "enabled" or "disabled", chosen))
        return
    end

    self:push("unknown command")
end

function mod_terminal:autocomplete_input()
    local text = self.input or ""
    local trimmed = text:match("^%s*(.-)%s*$")
    if trimmed == "" then
        return
    end

    local commands = {"help", "list", "enable", "disable", "start", "run"}

    if not text:find("%s") then
        self.input = autocomplete_ci(text, commands)
        return
    end

    local cmd_raw, rest = split_first_token(trimmed)
    if not cmd_raw then
        return
    end

    local cmd_completed = autocomplete_ci(cmd_raw, commands)
    local has_rest = rest and rest ~= ""
    if (cmd_completed ~= cmd_raw) and (not has_rest) then
        self.input = cmd_completed
        return
    end

    if cmd_completed == "enable" or cmd_completed == "disable" then
        local files = mods.list_mod_files()

        local arg = rest or ""
        if arg == "" then
            self.input = cmd_completed .. " "
            return
        end

        local file_matches = {}
        local arg_lower = arg:lower()
        for _, file in ipairs(files) do
            if file:lower():sub(1, #arg_lower) == arg_lower then
                table.insert(file_matches, file)
            end
        end

        local completed_arg = nil
        if #file_matches > 0 then
            completed_arg = autocomplete_ci(arg, file_matches)
        else
            completed_arg = autocomplete_ci(arg, {"all"})
        end
        self.input = cmd_completed .. " " .. completed_arg
        return
    end

    self.input = cmd_completed .. (has_rest and (" " .. rest) or "")
end

function mod_terminal:update(dt)
    if not self.active then
        return
    end
    self.cursor_timer = self.cursor_timer + dt
    if self.launching then
        self.launch_timer = self.launch_timer + dt
        if self.launch_timer >= LAUNCH_TOTAL_DURATION then
            self:finish_and_start()
        end
    end
end

function mod_terminal:draw(canvas_width, canvas_height)
    if not self.active then
        return
    end

    local pad = 20
    local panel_x = pad
    local panel_y = pad
    local panel_w = canvas_width - pad * 2
    local panel_h = canvas_height - pad * 2

    local text_fade_progress = 0
    local bg_fade_progress = 0
    if self.launching then
        text_fade_progress = clamp(self.launch_timer / LAUNCH_TEXT_FADE_DURATION, 0, 1)
        bg_fade_progress = clamp(
            (self.launch_timer - LAUNCH_TEXT_FADE_DURATION) / LAUNCH_BG_FADE_DURATION,
            0,
            1
        )
    end

    local panel_mul = 1 - bg_fade_progress
    local text_alpha = 1 - text_fade_progress

    love.graphics.clear(0.02 * panel_mul, 0.03 * panel_mul, 0.03 * panel_mul, 1)
    local shader = get_scanline_shader()
    if shader then
        shader:send("lineSpacing", 2.0)
        shader:send("darkness", 0.78)
        shader:send("yOffset", panel_y)
        love.graphics.setShader(shader)
    end
    love.graphics.setColor(0.07 * panel_mul, 0.09 * panel_mul, 0.09 * panel_mul, 1)
    love.graphics.rectangle("fill", panel_x, panel_y, panel_w, panel_h, 8, 8)
    love.graphics.setShader()
    love.graphics.setColor(0.15 * panel_mul, 0.22 * panel_mul, 0.18 * panel_mul, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panel_x, panel_y, panel_w, panel_h, 8, 8)

    if self.screen_font then
        love.graphics.setFont(self.screen_font)
    end

    local line_h = self.screen_font and self.screen_font:getHeight() or 18
    local top_pad = 12
    local side_pad = 12
    local bottom_reserved = self.is_mobile and 88 or (line_h + 30)
    local viewport_x = panel_x + side_pad
    local viewport_y = panel_y + top_pad
    local viewport_w = panel_w - (side_pad * 2)
    local viewport_h = math.max(80, panel_h - top_pad - bottom_reserved)
    local content_h = math.max(viewport_h, (#self.log * line_h) + 20)

    if self.scroll then
        scrolling.update(self.scroll, {
            viewport_x = viewport_x,
            viewport_y = viewport_y,
            viewport_width = viewport_w,
            viewport_height = viewport_h,
            content_height = content_h,
            reserve_scrollbar_space = true
        })
        if self.scroll_to_bottom_pending then
            self.scroll.offset = self.scroll.max_offset or 0
            scrolling.update(self.scroll, {
                viewport_x = viewport_x,
                viewport_y = viewport_y,
                viewport_width = viewport_w,
                viewport_height = viewport_h,
                content_height = content_h,
                reserve_scrollbar_space = true
            })
            self.scroll_to_bottom_pending = false
        end
    end

    local scroll_y = self.scroll and scrolling.get_offset_y(self.scroll, true) or 0
    local text_y = viewport_y + 8 + scroll_y
    local text_x = viewport_x + 8

    if self.scroll then
        scrolling.begin_clip(self.scroll)
    end
    for i = 1, #self.log do
        love.graphics.setColor(0.72, 0.95, 0.72, text_alpha)
        love.graphics.print(self.log[i], text_x, text_y)
        text_y = text_y + line_h
    end
    if self.scroll then
        scrolling.end_clip()
        if not self.launching then
            scrolling.draw(self.scroll)
        end
    end

    self.button_boxes = {}
    if self.is_mobile then
        local button_w = math.min(280, (panel_w - 16 * 2 - 14) * 0.5)
        local button_h = 48
        local gap = 14
        local by = panel_y + panel_h - button_h - 16
        local bx1 = panel_x + 16
        local bx2 = bx1 + button_w + gap

        self.button_boxes.enable_all = {x = bx1, y = by, w = button_w, h = button_h}
        self.button_boxes.disable_all = {x = bx2, y = by, w = button_w, h = button_h}

        local function draw_button(box, label, fill_r, fill_g, fill_b)
            love.graphics.setColor(fill_r * panel_mul, fill_g * panel_mul, fill_b * panel_mul, 1)
            love.graphics.rectangle("fill", box.x, box.y, box.w, box.h, 6, 6)
            love.graphics.setColor(0.8, 0.95, 0.8, text_alpha)
            love.graphics.rectangle("line", box.x, box.y, box.w, box.h, 6, 6)
            love.graphics.printf(label, box.x, box.y + (box.h - line_h) / 2, box.w, "center")
        end

        draw_button(self.button_boxes.enable_all, "Enable All", 0.11, 0.22, 0.13)
        draw_button(self.button_boxes.disable_all, "Disable All", 0.22, 0.11, 0.11)
    else
        local cursor_on = math.floor(self.cursor_timer * 2) % 2 == 0
        local input_text = self.prompt .. self.input .. (cursor_on and "_" or "")
        love.graphics.setColor(0.72, 0.95, 0.72, text_alpha)
        love.graphics.print(input_text, panel_x + 16, panel_y + panel_h - line_h - 20)
    end

    if self.launching and bg_fade_progress > 0 then
        love.graphics.setColor(0, 0, 0, bg_fade_progress)
        love.graphics.rectangle("fill", 0, 0, canvas_width, canvas_height)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function mod_terminal:keypressed(key)
    if not self.active then
        return false
    end
    if self.launching then
        return true
    end
    if self.is_mobile then
        return true
    end

    if key == "return" then
        self:run_command(self.input)
        self.input = ""
        self.scroll_to_bottom_pending = true
        return true
    end
    if key == "tab" then
        self:autocomplete_input()
        self.scroll_to_bottom_pending = true
        return true
    end
    if key == "backspace" then
        local byteoffset = nil
        if utf8 and utf8.offset then
            byteoffset = utf8.offset(self.input, -1)
        end
        if byteoffset then
            self.input = self.input:sub(1, byteoffset - 1)
        else
            self.input = self.input:sub(1, math.max(0, #self.input - 1))
        end
        self.scroll_to_bottom_pending = true
        return true
    end
    return true
end

function mod_terminal:textinput(t)
    if not self.active then
        return false
    end
    if not self.is_mobile and not self.launching then
        self.input = self.input .. t
        self.scroll_to_bottom_pending = true
    end
    return true
end

function mod_terminal:mousepressed(x, y, button)
    if not self.active then
        return false
    end
    if self.launching then
        return true
    end
    if button ~= 1 then
        return true
    end

    local function hit(box)
        return box and x >= box.x and x <= box.x + box.w and y >= box.y and y <= box.y + box.h
    end

    if hit(self.button_boxes.enable_all) then
        self:apply_enable_all(true)
        self:begin_start()
        return true
    end
    if hit(self.button_boxes.disable_all) then
        self:apply_enable_all(false)
        self:begin_start()
        return true
    end
    return true
end

function mod_terminal:mousereleased(_, _, _)
    return self.active
end

function mod_terminal:mousemoved(_, _)
    return self.active
end

function mod_terminal:wheelmoved(_, y)
    if not self.active then
        return false
    end
    if self.scroll and not self.launching then
        local step = 42
        self.scroll.offset = clamp(
            self.scroll.offset - (y * step),
            0,
            self.scroll.max_offset or 0
        )
    end
    return true
end

return mod_terminal
