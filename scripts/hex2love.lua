local function print_help()
    print("hex2love — convert hex colors to LÖVE color values")
    print()
    print("Usage:")
    print("  lua hex2love.lua <hex>")
    print()
    print("Examples:")
    print("  lua hex2love.lua #ff0000")
    print("  lua hex2love.lua 1e2a44")
    print("  lua hex2love.lua #1e2a44cc")
    print()
    print("Output:")
    print("  love.graphics.setColor(r, g, b[, a])")
end

local function hex_to_love(hex)
    hex = hex:gsub("#", "")

    if #hex ~= 6 and #hex ~= 8 then
        error("Hex must be RRGGBB or RRGGBBAA")
    end

    local r = tonumber(hex:sub(1,2), 16) / 255
    local g = tonumber(hex:sub(3,4), 16) / 255
    local b = tonumber(hex:sub(5,6), 16) / 255
    local a = (#hex == 8) and tonumber(hex:sub(7,8), 16) / 255 or 1

    return r, g, b, a
end

local arg1 = arg[1]

if not arg1 or arg1 == "-h" or arg1 == "--help" then
    print_help()
    os.exit(0)
end

local ok, r, g, b, a = pcall(hex_to_love, arg1)

if not ok then
    print("Error:", r)
    os.exit(1)
end

if a == 1 then
    print(string.format(
        "love.graphics.setColor(%.3f, %.3f, %.3f)",
        r, g, b
    ))
else
    print(string.format(
        "love.graphics.setColor(%.3f, %.3f, %.3f, %.3f)",
        r, g, b, a
    ))
end