import re, pathlib

def load(p): return pathlib.Path(p).read_text()
def save(p, s): pathlib.Path(p).write_text(s)

p = "data.lua"
s = load(p)
s, n = re.subn(r"icon\s*=\s*\{(?:[^{}]|\{[^{}]*\})*\}",
    "icon = Constants.MOD_ID..\"/graphics/playerportIcon.png\", icon_size = 40, small_icon = Constants.MOD_ID..\"/graphics/playerportIcon.png\", small_icon_size = 40", s)
print("data.lua: shortcut icon", n)
save(p, s)

p = "prototypes/Technologies.lua"
s = load(p)
s, n = re.subn(r"^[ \t]*T\.unit\.ingredients = RNS_normalize_ingredients\(T\.unit\.ingredients\)\n", "", s, flags=re.M)
print("Technologies.lua: normalization removed", n)
save(p, s)

p = "prototypes/others.lua"
s = load(p)
s, n = re.subn(r"^[ \t]*combinator1?\.item_slot_count = [^\n]*\n", "", s, flags=re.M)
print("others.lua: item_slot_count removed", n)
save(p, s)

p = "prototypes/WirelessDevices.lua"
s = load(p)
n = s.count("placed_as_equipment_result")
s = s.replace("placed_as_equipment_result", "place_as_equipment_result")
print("WirelessDevices.lua: equipment result", n)
save(p, s)

p = "utils/constants.lua"
s = load(p)
for a, b in [("\"advanced-electronics-2\"", "\"processing-unit\""), ("\"advanced-electronics\"", "\"advanced-circuit\""), ("\"optics\"", "\"lamp\""), ("\"logistic-chest-requester\"", "\"requester-chest\""), ("\"logistic-chest-active-provider\"", "\"active-provider-chest\"")]:
    print("constants.lua:", a, "->", b, s.count(a))
    s = s.replace(a, b)
save(p, s)
