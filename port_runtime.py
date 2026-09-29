import pathlib, re

# Every pattern here is documented in the 2.0 changelog or the runtime API.
# global   -> storage          (control.lua:38 crashed on this)
# game.active_mods   -> script.active_mods
# game.item_prototypes  -> prototypes.item
# game.fluid_prototypes -> prototypes.fluid
patterns = [
    (r"(?<![-.\w])global\b", "storage"),
    (r"game\.active_mods", "script.active_mods"),
    (r"game\.item_prototypes", "prototypes.item"),
    (r"game\.fluid_prototypes", "prototypes.fluid"),
]

# The lookbehind keeps settings.global and setting_type = "runtime-global" intact.

total = {}
files = 0
for p in sorted(pathlib.Path(".").rglob("*.lua")):
    if ".git" in p.parts:
        continue
    s = p.read_text()
    orig = s
    for pat, repl in patterns:
        s, n = re.subn(pat, repl, s)
        if n:
            total[repl] = total.get(repl, 0) + n
    if s != orig:
        p.write_text(s)
        files = files + 1

print("files changed:", files)
for _, repl in patterns:
    print("  ->", repl, total.get(repl, 0))

left = 0
show = []
for p in sorted(pathlib.Path(".").rglob("*.lua")):
    if ".git" in p.parts:
        continue
    for i, line in enumerate(p.read_text().splitlines(), 1):
        if "global" in line:
            left = left + 1
            if len(show) < 12:
                show.append(str(p) + ":" + str(i) + ": " + line.strip()[:80])
print("lines still containing global:", left)
for l in show:
    print("  ", l)
