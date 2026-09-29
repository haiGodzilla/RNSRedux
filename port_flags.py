import re, pathlib

p = pathlib.Path("prototypes/others.lua")
s = p.read_text()

def fix(m):
    line = m.group(0).replace("\x27hidden\x27, ", "")
    return line + m.group(1) + ".hidden = true\n"

s, n = re.subn(r"^(\w+)\.flags = \{[^\n]*\x27hidden\x27[^\n]*\}\n", fix, s, flags=re.M)
print("flags fixed:", n)
p.write_text(s)
