import re, pathlib

files = ["prototypes/NetworkCable.lua", "prototypes/NetworkCableIOItem.lua", "prototypes/NetworkCableIOExternal.lua", "prototypes/NetworkCableIOFluid.lua"]

P05 = "{flow_direction = \"input-output\", direction = defines.direction.north, position = {0, -0.4}, hide_connection_info = true}"
P1  = "{flow_direction = \"output\", direction = defines.direction.north, position = {0, -0.4}, hide_connection_info = true}"

for f in files:
    p = pathlib.Path(f)
    s = p.read_text()
    s = s.replace("{type = \"output\", position = {0, -1}}", P1)
    s = s.replace("{position = {0, -1}}", P1)
    s = s.replace("{position = {0, -0.5}}", P05)
    s = re.sub(r"[ \t]*hide_connection_info = true,\n", "", s)
    s = s.replace("base_area = 1,", "volume = 100,")
    p.write_text(s)
    print("patched", f)
