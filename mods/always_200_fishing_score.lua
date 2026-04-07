local TARGET_SCORE = 200

return {
    on_load = function(state, api)
        local minigame = state and state.fishing and state.fishing.minigame
        if type(minigame) ~= "table" then
            if api and api.log then
                api.log("always_200_fishing_score: minigame not available")
            end
            return
        end

        if minigame.__always_200_score_installed then
            return
        end

        local original_complete = minigame.complete_fishing
        local original_determine = minigame.determine_final_fish
        if type(original_complete) ~= "function" then
            if api and api.log then
                api.log("always_200_fishing_score: complete_fishing missing")
            end
            return
        end
        if type(original_determine) ~= "function" then
            if api and api.log then
                api.log("always_200_fishing_score: determine_final_fish missing")
            end
            return
        end

        minigame.determine_final_fish = function(_, _)
            return original_determine(TARGET_SCORE)
        end

        minigame.complete_fishing = function(...)
            local result = original_complete(...)
            if type(result) == "table" then
                result.quality_score = TARGET_SCORE
            end
            return result
        end

        minigame.__always_200_score_installed = true
        if api and api.log then
            api.log("always_200_fishing_score: forcing score to " .. TARGET_SCORE)
        end
    end
}
