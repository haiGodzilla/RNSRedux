-- Factorio 2.0 requires ingredient and product entries to be dictionaries.
-- Converts the 1.1 shorthand {"name", amount} into {type="item", name=..., amount=...}.
function RNS_normalize_ingredients(list)
    if list == nil then return nil end
    local out = {}
    for k, v in pairs(list) do
        if type(v) == "table" and v[1] ~= nil then
            out[k] = {type = "item", name = v[1], amount = v[2]}
        else
            out[k] = v
        end
    end
    return out
end
