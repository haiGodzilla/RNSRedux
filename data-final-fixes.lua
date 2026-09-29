-- Final data stage: runs after every other mod has had its say.
-- Some ingredients do not exist in every mod set (space-age removes "satellite").
-- Replace them explicitly instead of letting assignID fail, and report the rest.

local substitutes = {
    ["satellite"] = "low-density-structure",
}

local problems = {}
for _, recipe in pairs(data.raw.recipe or {}) do
    if type(recipe) == "table" and recipe.name and recipe.name:find("^RNS_") and recipe.ingredients then
        for _, ingredient in pairs(recipe.ingredients) do
            local name = ingredient.name
            if name and not (data.raw.item[name] or data.raw.fluid[name]) then
                local sub = substitutes[name]
                if sub then
                    log("RNSRedux: replacing missing ingredient " .. name .. " with " .. sub .. " in " .. recipe.name)
                    ingredient.name = sub
                else
                    problems[#problems + 1] = recipe.name .. " -> " .. name
                end
            end
        end
    end
end

if #problems > 0 then
    log("RNSRedux: ingredients without a substitute:")
    for _, p in pairs(problems) do
        log("RNSRedux:   " .. p)
    end
end
