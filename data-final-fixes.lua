-- Last data stage. Space Age deletes prototypes that other mod sets keep,
-- and every other mod has had its say by this point.

local substitutes = {
    ["satellite"] = "low-density-structure",
    ["empty-barrel"] = "steel-plate",
}

-- Only buckets that can satisfy a recipe ingredient belong here. Recipe and
-- technology names reuse item names, so counting those gives false negatives.
local item_buckets = {
    "item", "ammo", "capsule", "module", "armor", "tool", "repair-tool",
    "item-with-tags", "item-with-entity-data", "item-with-label",
    "item-with-inventory", "selection-tool", "blueprint", "blueprint-book",
    "deconstruction-item", "upgrade-item", "copy-paste-tool", "gun",
    "rail-planner", "spidertron-remote", "fluid",
}

local known = {}
local known_count = 0
for _, bucket_name in pairs(item_buckets) do
    local bucket = data.raw[bucket_name]
    if type(bucket) == "table" then
        for name in pairs(bucket) do
            if not known[name] then
                known[name] = true
                known_count = known_count + 1
            end
        end
    end
end
log("RNSRedux: item and fluid names available: " .. known_count)

for bucket_name, bucket in pairs(data.raw) do
    if type(bucket) == "table" and bucket["empty-barrel"] ~= nil then
        log("RNSRedux: empty-barrel found in bucket " .. bucket_name)
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

if #missing > 0 then
    log("RNSRedux: ingredients without a substitute (" .. #missing .. "):")
    for _, m in pairs(missing) do
        log("RNSRedux:   " .. m)
    end
end
