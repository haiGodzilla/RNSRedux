import pathlib, re

def find_brace(s, start):
    depth = 0
    for i in range(start, len(s)):
        if s[i] == "{":
            depth += 1
        elif s[i] == "}":
            depth -= 1
            if depth == 0:
                return i
    return -1

# 2.0: assembling machines draw through CraftingMachineGraphicsSet.
# A bare "animation" property is silently discarded, leaving the entity invisible.
files = ["prototypes/NetworkCable.lua", "prototypes/NetworkCableIOItem.lua",
         "prototypes/NetworkCableIOExternal.lua", "prototypes/NetworkCableIOFluid.lua"]

for f in files:
    p = pathlib.Path(f)
    s = p.read_text()
    m = re.search(r"^(\w+)\.animation =", s, re.M)
    if not m:
        print("no animation block:", f)
        continue
    var = m.group(1)
    bstart = s.index("{", m.end())
    bend = find_brace(s, bstart)
    block = s[bstart:bend+1]
    s = s[:m.start()] + var + ".graphics_set = {\n    animation =\n" + block + "\n}" + s[bend+1:]
    s = re.sub(r"\b" + var + r"\.animation\.", var + ".graphics_set.animation.", s)
    p.write_text(s)
    print("patched", f, "->", var + ".graphics_set.animation")
