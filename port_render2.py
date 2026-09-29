import pathlib

def wrap_draw_calls(text):
    out = []
    i = 0
    count = 0
    while True:
        j = text.find("rendering.draw_", i)
        if j == -1:
            out.append(text[i:])
            break
        k = text.find("{", j)
        if k == -1:
            out.append(text[i:])
            break
        depth = 0
        m = k
        while m < len(text):
            c = text[m]
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    break
            m += 1
        out.append(text[i:j])
        out.append("Util.newRender(" + text[j:m+1] + ")")
        i = m + 1
        count += 1
    return "".join(out), count

replacements = [
    ("rendering.destroy(", "Util.destroyRender("),
    ("rendering.get_only_in_alt_mode(", "Util.getRenderAltMode("),
    ("rendering.set_only_in_alt_mode(", "Util.setRenderAltMode("),
]

skip = {"utils/Util.lua", "scripts/objects/Itemstack.lua"}

for p in sorted(pathlib.Path(".").rglob("*.lua")):
    if ".git" in p.parts or str(p) in skip:
        continue
    s = p.read_text()
    orig = s
    s, wrapped = wrap_draw_calls(s)
    hits = 0
    for a, b in replacements:
        n = s.count(a)
        s = s.replace(a, b)
        hits += n
    if s != orig:
        p.write_text(s)
        print(str(p), "wrapped:", wrapped, "calls:", hits)
