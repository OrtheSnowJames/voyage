local mods = require("game.mods")
local scrolling = require("game.scrolling")

local mod_terminal = {}
mod_terminal.__index = mod_terminal

local command_history = {"help", "list"}
local history_index = 0 -- if 0, not indexed

local LAUNCH_TOTAL_DURATION = 2.0
local LAUNCH_TEXT_FADE_DURATION = 0.2
local LAUNCH_BG_FADE_DURATION = 0.2
local WEB_QUIT_REDIRECT_URL = "http://waffledogz.us"
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
        launch_timer = 0,
        waiting_for_input = false,
        wait_input_prompt = "",
        wait_input_callback = nil,
        skip_next_space_textinput = false
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
    local globally_enabled = mods.is_enabled()
    self:push("")
    self:push(string.format("mods engine: %s", globally_enabled and "enabled" or "disabled"))
    self:push("mods found:")
    if #files == 0 then
        self:push("  (none)")
    else
        for _, file in ipairs(files) do
            local file_enabled = mods.is_file_enabled(file)
            local status
            if not globally_enabled then
                status = file_enabled and "enabled (inactive)" or "disabled"
            else
                status = file_enabled and "enabled" or "disabled"
            end
            self:push(string.format("  [%s] %s", status, file))
        end
    end
end

function mod_terminal:print_help()
    self:push("commands:")
    self:push("  help")
    self:push("  list")
    self:push("  enable [x.lua|all]  (default: all)")
    self:push("  disable [y.lua|all] (default: all)")
    self:push("  start")
    self:push("  run")
    self:push("  lua")
    self:push("  exit")
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
    mods.load_preferences()
    local files = mods.list_mod_files()
    if #files == 0 then
        self:finish_and_start()
        return
    end

    self:push("Linux 5.4.0-voyage #1 SMP PREEMPT")
    self:push("All rights reserved.")
    self:push("")
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
    mods.save_preferences()
end

local function get_lua_env(term)
    if term.lua_repl_env then
        return term.lua_repl_env
    end

    term.lua_repl_env = setmetatable({
        print = function(...)
            local parts = {}
            local n = select("#", ...)
            for i = 1, n do
                parts[#parts + 1] = tostring(select(i, ...))
            end
            term:push(table.concat(parts, "\t"))
        end
    }, {__index = _G})
    return term.lua_repl_env
end

local function try_run_lua(code, term)
    local env = get_lua_env(term)

    local function make_chunk(src)
        if _VERSION == "Lua 5.1" and setfenv then
            local chunk, err = loadstring(src, "terminal")
            if not chunk then
                return nil, err
            end
            setfenv(chunk, env)
            return chunk, nil
        end
        return load(src, "terminal", "t", env)
    end

    local eval_chunk = make_chunk("return " .. code)
    if eval_chunk then
        local ok, result = pcall(eval_chunk)
        if not ok then
            term:push(result)
            return nil, result
        elseif result ~= nil then
            term:push(tostring(result))
        end
        return true
    end

    local chunk, err = make_chunk(code)
    if not chunk then
        if err and err:match("<eof>") then
            return false, err
        end
        term:push(err or "lua compile error")
        return nil, err
    end

    local ok, result = pcall(chunk)
    if not ok then
        term:push(result)
        return nil, result
    elseif result ~= nil then
        term:push(tostring(result))
    end
    return true
end

local function count_keyword(line, keyword)
    local count = 0
    local pattern = "%f[%a]" .. keyword .. "%f[^%a]"
    for _ in line:gmatch(pattern) do
        count = count + 1
    end
    return count
end

local function next_lua_indent(current_indent, line)
    local open_count =
        count_keyword(line, "function") +
        count_keyword(line, "then") +
        count_keyword(line, "do") +
        count_keyword(line, "repeat")
    local close_count =
        count_keyword(line, "end") +
        count_keyword(line, "until")

    -- elseif/else should align with matching if, then reopen their own body.
    local starts_with_else = line:match("^%s*else%f[^%a]")
    local starts_with_elseif = line:match("^%s*elseif%f[^%a]")
    if starts_with_else or starts_with_elseif then
        close_count = close_count + 1
        open_count = open_count + 1
    end

    local next_indent = current_indent + (open_count - close_count)
    if next_indent < 0 then
        next_indent = 0
    end
    return next_indent
end

local function lua_repl_wait(term, prompt, indent_spaces)
    term:wait_for_input(prompt or "", function(value, t)
        local raw_line = tostring(value or "")
        local trimmed = raw_line:match("^%s*(.-)%s*$") or ""
        if trimmed == "exit" then
            t.lua_repl_buffer = {}
            t.lua_repl_indent = 0
            t.lua_repl_env = nil
            t:push("leaving lua mode")
            return
        end

        t.lua_repl_buffer = t.lua_repl_buffer or {}
        table.insert(t.lua_repl_buffer, raw_line)

        local code = table.concat(t.lua_repl_buffer, "\n")
        local ok = try_run_lua(code, t)
        if ok == true then
            t.lua_repl_buffer = {}
            t.lua_repl_indent = 0
            lua_repl_wait(t, "lua> ", "")
            return
        elseif ok == false then
            t.lua_repl_indent = next_lua_indent(tonumber(t.lua_repl_indent) or 0, raw_line)
            local spaces = string.rep("  ", t.lua_repl_indent)
            lua_repl_wait(t, "... ", spaces)
            return
        end

        -- Hard compile/runtime error; reset buffer and continue fresh.
        t.lua_repl_buffer = {}
        t.lua_repl_indent = 0
        lua_repl_wait(t, "lua> ", "")
    end, indent_spaces or "")
end

function mod_terminal:run_command(raw)
    table.insert(command_history, raw)
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

    if lower == "lua --version" then
        self:push(_VERSION)
        return
    end

    if lower == "lua --paste" then
        local clipboard = ""
        if love.system and love.system.getClipboardText then
            clipboard = tostring(love.system.getClipboardText() or "")
        end
        local script = clipboard:match("^%s*(.-)%s*$") or ""
        if script == "" then
            self:push("clipboard is empty")
            return
        end
        local ok, err = try_run_lua(clipboard, self)
        if ok == false then
            self:push("clipboard script is incomplete")
        elseif ok == nil and err then
            -- try_run_lua already pushed exact error; keep command response concise.
        end
        return
    end

    if lower == "lua --help" then
        self:push(_VERSION)
        self:push("lua --paste: Run script in clipboard")
        self:push("lua --version: Print version of lua running")
        self:push("lua --help: Print help dialog")
        self:push("lua: Run interactive repl")
    end

    if lower == "exit" then
        if love.system.getOS() == "Web" then
            love.system.openURL(WEB_QUIT_REDIRECT_URL)
            return
        end
        love.event.quit()
        return
    end

    if lower == "enable" or lower == "disable" then
        self:apply_enable_all(lower == "enable")
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
        mods.save_preferences()
        self:push(string.format("%s %s", action == "enable" and "enabled" or "disabled", chosen))
        return
    end

    if lower == "lua" then
        self:push("Lua " .. _VERSION .. ". Type 'exit' to leave.")
        self.lua_repl_buffer = {}
        self.lua_repl_indent = 0
        self.lua_repl_env = nil
        lua_repl_wait(self, "lua> ", "")
        return
    end

    self:push("unknown command")
end

function mod_terminal:wait_for_input(prompt, on_submit, initial_value)
    self.waiting_for_input = true
    self.wait_input_prompt = tostring(prompt or "")
    self.wait_input_callback = on_submit
    self.input = tostring(initial_value or "")
    self.scroll_to_bottom_pending = true
end

function mod_terminal:autocomplete_input()
    local text = self.input or ""
    local trimmed = text:match("^%s*(.-)%s*$")
    if trimmed == "" then
        return
    end

    local commands = {"help", "list", "enable", "disable", "start", "run", "exit"}

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
        local active_prompt = self.waiting_for_input and (self.wait_input_prompt or "") or self.prompt
        local input_text = active_prompt .. self.input .. (cursor_on and "_" or "")
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
        if self.waiting_for_input then
            local submitted = self.input or ""
            table.insert(command_history, submitted)
            history_index = 0
            local prefix = self.wait_input_prompt or ""
            self:push(prefix .. submitted)
            self.waiting_for_input = false
            local callback = self.wait_input_callback
            self.wait_input_callback = nil
            self.wait_input_prompt = ""
            if callback then
                callback(submitted, self)
            end
        else
            self:run_command(self.input)
        end
        self.input = ""
        self.scroll_to_bottom_pending = true
        return true
    end
    if key == "tab" then
        if self.waiting_for_input then
            return true
        end
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
    if key == "space" then
        self.input = (self.input or "") .. " "
        self.skip_next_space_textinput = true
        self.scroll_to_bottom_pending = true
        return true
    end
    if key == "up" then
        history_index = history_index + 1
        local total = #command_history
        if total <= 0 then
            history_index = 0
            return true
        end
        if history_index > total then
            history_index = total
        end
        local idx = total - history_index + 1
        if idx < 1 then
            idx = 1
        end
        if idx > total then
            idx = total
        end
        self.input = tostring(command_history[idx] or "")
        self.scroll_to_bottom_pending = true
        return true
    end
    if key == "down" then
        local total = #command_history
        if total <= 0 then
            history_index = 0
            self.input = ""
            return true
        end
        history_index = history_index - 1
        if history_index <= 0 then
            history_index = 0
            self.input = ""
            self.scroll_to_bottom_pending = true
            return true
        end
        local idx = total - history_index + 1
        if idx < 1 then
            idx = 1
        end
        if idx > total then
            idx = total
        end
        self.input = tostring(command_history[idx] or "")
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
        if t == " " and self.skip_next_space_textinput then
            self.skip_next_space_textinput = false
            return true
        end
        self.skip_next_space_textinput = false
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
