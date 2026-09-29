import re, pathlib

p = pathlib.Path("prototypes/WirelessDevices.lua")
s = p.read_text()
s, n = re.subn(r"ammo_type = \{\s*category = \"melee\"\s*\}", chr(97)+chr(109)+chr(109)+chr(111)+"_category = \"melee\"", s)
print("replaced:", n)
p.write_text(s)
