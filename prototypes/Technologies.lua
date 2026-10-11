require("prototypes.normalize")

for _, tech in pairs(Constants.Technologies) do
    local T = {}
    T.type = "technology"
    T.name = tech.name
    T.icon_size = tech.icon_size or 512
    if tech.icon ~= nil then
        T.icon = tech.icon
    else
        --2.0 reads the top-level icon_size only together with `icon`; each layer of
        --`icons` carries its own and defaults to 64, which showed the 512 px images as
        --their top-left corner. A copy, so the shared constants stay untouched.
        T.icons = table.deepcopy(tech.icons)
        for _, layer in pairs(T.icons or {}) do
            layer.icon_size = layer.icon_size or T.icon_size
        end
    end
    T.prerequisites = tech.prerequisites
    T.max_level = tech.max_level
    T.effects = tech.effects
    if tech.unit ~= nil then
        T.unit = table.deepcopy(tech.unit)
    end
    T.upgrade = tech.upgrade
    T.order = "a-z"
    --M5 content (Constants.DeferredToM5): enabled = false keeps it out of research and,
    --with visible_when_disabled left at its default, out of the tech tree.
    if Constants.isDeferredToM5(T.name) then T.enabled = false end
    data:extend{T}
end
