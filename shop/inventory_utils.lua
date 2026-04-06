local inventory_utils = {}

function inventory_utils.filter_fish(fish_list, search_text)
    if search_text == "" then
        return fish_list
    end

    local filtered = {}
    local search_lower = string.lower(search_text)
    for _, fish in ipairs(fish_list) do
        if string.find(string.lower(fish), search_lower) then
            table.insert(filtered, fish)
        end
    end
    return filtered
end

function inventory_utils.count_fish_in_inventory(fish_name, inventory)
    local count = 0
    for _, fish in ipairs(inventory) do
        if fish == fish_name then
            count = count + 1
        end
    end
    return count
end

return inventory_utils
