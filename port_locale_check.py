import pathlib, re

defined = set()
section = None
for p in pathlib.Path("locale").rglob("*.cfg"):
    for line in p.read_text().splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        if s.startswith("[") and s.endswith("]"):
            section = s[1:-1].strip()
            continue
        if "=" in s and section:
            defined.add(section + "." + s.split("=", 1)[0].strip())

used = {}
for p in sorted(pathlib.Path(".").rglob("*.lua")):
    if ".git" in p.parts:
        continue
    s = p.read_text()
    for m in re.finditer(r"\{\s*\"([a-z-]+\.[A-Za-z0-9_]+)\"\s*[,}]", s):
        key = m.group(1)
        used.setdefault(key, set()).add(str(p))

missing = sorted(k for k in used if k not in defined)
print("keys defined:", len(defined), " used:", len(used), " missing:", len(missing))
for k in missing:
    print("  ", k, "  <-", ", ".join(sorted(used[k])[:3]))
