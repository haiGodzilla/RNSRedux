import pathlib
p = pathlib.Path("prototypes/WirelessDevices.lua")
s = p.read_text()
old = "    ammo_category = \"melee\"\n"
new = "    ammo_category = \"melee\",\n    ammo_type = {}\n"
print("found:", s.count(old))
p.write_text(s.replace(old, new))
