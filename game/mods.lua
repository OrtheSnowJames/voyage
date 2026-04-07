local mods = {}

local loaded_mods = {}
local mods_enabled = true
local file_enabled = {}
local PREFS_PATH = "mods/preferences.lua"
local IGNORED_MOD_FILES = {
    ["preferences.lua"] = true
}
local IGNORED_MOD_PREFIXES = {
    "not_mod/"
}

local function sorted_entries(path)
    local entries = love.filesystem.getDirectoryItems(path)
    table.sort(entries)
    return entries
end

local function sorted_lua_files(path)
    local files = {}
    for _, entry in ipairs(sorted_entries(path)) do
        local entry_lower = entry:lower()
        local ignored = IGNORED_MOD_FILES[entry_lower] == true
        if not ignored then
            for _, prefix in ipairs(IGNORED_MOD_PREFIXES) do
                if entry_lower:sub(1, #prefix) == prefix then
                    ignored = true
                    break
                end
            end
        end

        if (not ignored) and entry:sub(-4) == ".lua" then
            table.insert(files, entry)
        end
    end
    return files
end

local function ensure_mods_directory()
    if not love.filesystem.getInfo("mods", "directory") then
        love.filesystem.createDirectory("mods")
    end
end

local function load_game_modules_into_state(state)
    state.system.modules = state.system.modules or {}
    local modules = state.system.modules

    if not love.filesystem.getInfo("game", "directory") then
        return
    end

    for _, filename in ipairs(sorted_lua_files("game")) do
        local basename = filename:sub(1, -5) -- trim .lua
        local module_name = "game." .. basename
        local ok, mod = pcall(require, module_name)
        if ok then
            modules[basename] = mod
        else
            print("[mods] failed to auto-require " .. module_name .. ": " .. tostring(mod))
        end
    end
end

local function make_api()
    return {
        fs = love.filesystem,
        log = function(...)
            print("[mod]", ...)
        end
    }
end

function mods.load_all(state)
    loaded_mods = {}
    load_game_modules_into_state(state)

    if not mods_enabled then
        print("[mods] disabled by launcher choice")
        return
    end

    ensure_mods_directory()

    local api = make_api()
    for _, filename in ipairs(sorted_lua_files("mods")) do
        if file_enabled[filename] == false then
            print("[mods] skipped disabled file: " .. filename)
        else
            local path = "mods/" .. filename
            local chunk, load_err = love.filesystem.load(path)
            if not chunk then
                print("[mods] failed to load " .. path .. ": " .. tostring(load_err))
            else
                local ok, result = pcall(chunk)
                if not ok then
                    print("[mods] runtime error in " .. path .. ": " .. tostring(result))
                else
                    local mod = result
                    if type(mod) == "function" then
                        mod = {on_load = mod}
                    end

                    if type(mod) == "table" then
                        mod.__path = path
                        table.insert(loaded_mods, mod)
                    else
                        print("[mods] " .. path .. " must return a table or function")
                    end
                end
            end
        end
    end

    for _, mod in ipairs(loaded_mods) do
        if type(mod.on_load) == "function" then
            local ok, err = pcall(mod.on_load, state, api)
            if not ok then
                print("[mods] on_load error in " .. mod.__path .. ": " .. tostring(err))
            end
        end
    end
end

function mods.run_hook(hook_name, ...)
    for _, mod in ipairs(loaded_mods) do
        local hook = mod[hook_name]
        if type(hook) == "function" then
            local ok, err = pcall(hook, ...)
            if not ok then
                print("[mods] " .. hook_name .. " error in " .. mod.__path .. ": " .. tostring(err))
            end
        end
    end
end

function mods.has_loaded_mods()
    return #loaded_mods > 0
end

function mods.count()
    return #loaded_mods
end

function mods.set_enabled(enabled)
    mods_enabled = enabled ~= false
end

function mods.is_enabled()
    return mods_enabled
end

function mods.list_mod_files()
    ensure_mods_directory()
    return sorted_lua_files("mods")
end

function mods.is_file_enabled(filename)
    return file_enabled[filename] ~= false
end

function mods.set_file_enabled(filename, enabled)
    file_enabled[filename] = (enabled ~= false)
end

function mods.enable_all_files()
    for _, filename in ipairs(mods.list_mod_files()) do
        file_enabled[filename] = true
    end
end

function mods.disable_all_files()
    for _, filename in ipairs(mods.list_mod_files()) do
        file_enabled[filename] = false
    end
end

function mods.save_preferences()
    ensure_mods_directory()

    local lines = {
        "return {",
        "  mods_enabled = " .. tostring(mods_enabled) .. ",",
        "  file_enabled = {"
    }

    for _, filename in ipairs(mods.list_mod_files()) do
        local enabled = mods.is_file_enabled(filename)
        table.insert(lines, string.format("    [%q] = %s,", filename, tostring(enabled)))
    end

    table.insert(lines, "  }")
    table.insert(lines, "}")

    local ok, err = love.filesystem.write(PREFS_PATH, table.concat(lines, "\n"))
    if not ok then
        print("[mods] failed to save preferences: " .. tostring(err))
        return false
    end
    return true
end

function mods.load_preferences()
    ensure_mods_directory()

    local info = love.filesystem.getInfo(PREFS_PATH, "file")
    if not info then
        return false
    end

    local chunk, load_err = love.filesystem.load(PREFS_PATH)
    if not chunk then
        print("[mods] failed to load preferences: " .. tostring(load_err))
        return false
    end

    local ok, data = pcall(chunk)
    if not ok or type(data) ~= "table" then
        print("[mods] invalid preferences file")
        return false
    end

    if data.mods_enabled ~= nil then
        mods_enabled = data.mods_enabled ~= false
    end

    file_enabled = {}
    if type(data.file_enabled) == "table" then
        for name, enabled in pairs(data.file_enabled) do
            if type(name) == "string" then
                file_enabled[name] = enabled ~= false
            end
        end
    end

    return true
end

return mods
