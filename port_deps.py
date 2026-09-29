import json, pathlib
p = pathlib.Path("info.json")
d = json.loads(p.read_text())
if "? space-age" not in d["dependencies"]:
    d["dependencies"].append("? space-age")
p.write_text(json.dumps(d, indent=4) + "\n")
print(d["dependencies"])
