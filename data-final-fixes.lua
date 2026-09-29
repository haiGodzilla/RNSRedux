-- Final data stage: runs after every mod has defined and removed its prototypes.
-- Space Age removes items that other mod sets keep (for example "satellite"),
-- which only fails later at assignID. Handle that here.

local substitutes = {
    ["satellite"] = "low-density-structure",
}

-- Every prototype name, regardless of bucket. Item prototypes are spread over
-- "item", "item-with-tags", "ammo", "module", "capsule", "armor", "tool",
-- "repair-tool" and more, so looking only at data.raw.item gives false positives.
local known = {}
local count = 0
for _, bucket in pairs(data.raw) do
    if type(bucket) == "table" then
        for name in pairs(bucket) do
            known[name] = true
            count = count + 1
        end
    end
end

local missing = {}
for _, recipe in pairs(data.raw.recipe or {}) do
    if type(recipe) == "table" and recipe.name and recipe.name:find("^RNS_") and recipe.ingredients then
        for _, ingredient in pairs(recipe.ingredients) do
            local name = ingredient.name
            if name and not known[name] then
                local sub = substitutes[name]
                if sub then
                    log("RNSRedux: replacing missing ingredient " .. name .. " with " .. sub .. " in " .. recipe.name)
                    ingredient.name = sub
                else
                    missing[#missing + 1] = recipe.name .. " -> " .. name
                end
            end
        end
    end
end

log("RNSRedux: prototype names collected: " .. count)
if #missing > 0 then
    log("RNSRedux: ingredients still missing (" .. #missing .. "):")
    for _, m in pairs(missing) do
        log("RNSRedux:   " .. m)
    end
end
