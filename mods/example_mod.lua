-- Example mod:
-- 1) Writes to files in the project folder.
-- 2) Tweaks the game state on load.
-- 3) Runs a small update hook.

local wrote_once = false

return {
    on_load = function(state, api)
        api.log("example_mod loaded")

        local file = io.open("mods/mod_log.txt", "a")
        if file then
            file:write(os.date("%Y-%m-%d %H:%M:%S"), " example_mod loaded\n")
            file:close()
        end

        -- Small visible effect so you know mods are active.
        state.player.name = (state.player.name or "Ship") .. " [Modded]"

        -- Example behavior override:
        -- every fish is considered available at any depth.
        state.system.game.get_required_depth_for_fish = function(_fish_name)
            print("get_required_depth_for_fish")
            return -1
        end
    end,

    on_update = function(dt, state)
        if wrote_once then
            return
        end

        if state.player and state.player.time_system and state.player.time_system.time > 1 then
            local file = io.open("mods/first_tick.txt", "w")
            if file then
                file:write("Mod update hook executed.\n")
                file:close()
            end
            wrote_once = true
        end
    end
}
