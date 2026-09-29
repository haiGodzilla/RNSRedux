-- Last data stage. Space Age deletes prototypes that other mod sets keep,
-- and by this point every other mod has had its say.

local substitutes = {
    ["satellite"] = "low-density-structure",
    ["empty-barrel"] = "steel-plate",
}

-- Only buckets that can satisfy a recipe reference. Recipe, technology and
-- item-subgroup names reuse item names, so counting those gives false results.
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

local missing = {}

-- Both ingredient and result lists can hold a deleted name. The recycling
-- recipes that the quality mod derives from ours carry a stale copy of our
-- ingredients in their results, so they need the same treatment.
local function scrub(list, recipe_name, label)
    if type(list) ~= "table" then return end
    for _, entry in pairs(list) do
        if type(entry) == "table" then
            local name = entry.name
            if name and not known[name] then
                local sub = substitutes[name]
                if sub then
                    log("RNSRedux: " .. recipe_name .. " " .. label .. ": " .. name .. " -> " .. sub)
                    entry.name = sub
                else
                    missing[#missing + 1] = recipe_name .. " " .. label .. " -> " .. name
                end
            end
        end
    end
end

for _, recipe in pairs(data.raw.recipe or {}) do
    if type(recipe) == "table" and recipe.name and recipe.name:find("^RNS_") then
        scrub(recipe.ingredients, recipe.name, "ingredient")
        scrub(recipe.results, recipe.name, "result")
    end
end

if #missing > 0 then
    log("RNSRedux: references without a substitute (" .. #missing .. "):")
    for _, m in pairs(missing) do
        log("RNSRedux:   " .. m)
    end
end
