import pathlib
p = pathlib.Path("utils/Util.lua")
s = p.read_text()
old = "game.print(error)"
new = chr(39).join([]) or ("game.print(error)\n\t\tlog(\"RNSRedux error: \" .. tostring(error))")
print("occurrences:", s.count(old))
p.write_text(s.replace(old, new))
