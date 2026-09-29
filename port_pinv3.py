import pathlib
p = pathlib.Path("scripts/objects/NetworkInventoryInterface.lua")
s = p.read_text()
log = []
a = "--[[local playerInventoryFrame"
b = "local playerInventoryFrame"
log.append(("frame head", s.count(a)))
s = s.replace(a, b, 1)
a = "playerInventoryScrollPane, 8, true)]]"
b = "playerInventoryScrollPane, 8, true)"
log.append(("frame tail", s.count(a)))
s = s.replace(a, b, 1)
p.write_text(s)
print("open comments:", s.count("--[[") + s.count("--[["))
for k, v in log:
    print("  ", k, "=", v)
