import pathlib, re

# (regex, replacement, description)
jobs = [
    # get_contents() returns an array of {name, count, quality} since 2.0.
    (r"(\w+)\.get_contents\(\)\[([^\]]+)\]",
     r"\1.get_item_count(\2)",
     "get_contents index -> get_item_count"),

    # blueprint_icons was renamed to preview_icons.
    (r"\.blueprint_icons\b", ".preview_icons", "blueprint_icons -> preview_icons"),

    # mapper_count moved from LuaItemPrototype to LuaItemCommon.
    (r"([\w.]*)\.prototype\.mapper_count\b", r"\1.mapper_count", "prototype.mapper_count -> mapper_count"),

    # A single wire connector now covers red and green, so the double check collapses.
    (r"(\w+(?:\.\w+)*)\.get_circuit_network\(defines\.wire_type\.red, defines\.circuit_connector_id\.constant_combinator\) ~= nil or \1\.get_circuit_network\(defines\.wire_type\.green, defines\.circuit_connector_id\.constant_combinator\) ~= nil",
     r"Util.getCombinatorNetwork(\1) ~= nil",
     "get_circuit_network red/green"),

    (r"(\w+(?:\.\w+)*)\.get_merged_signals\(defines\.circuit_connector_id\.constant_combinator\)",
     r"Util.getCombinatorSignals(\1)",
     "get_merged_signals"),

    (r"(\w+(?:\.\w+)*)\.get_merged_signal\((.*?), defines\.circuit_connector_id\.constant_combinator\)",
     r"Util.getCombinatorSignal(\1, \2)",
     "get_merged_signal"),
    (r"([\w.]*)\.prototype\.mapper_count\b", r"\1.mapper_count", "mapper_count"),
]

skip = {"utils/Util.lua"}
totals = {}
for p in sorted(pathlib.Path(".").rglob("*.lua")):
    if ".git" in p.parts or str(p) in skip:
        continue
    s = p.read_text()
    orig = s
    for pat, repl, desc in jobs:
        s, n = re.subn(pat, repl, s)
        if n:
            totals[desc] = totals.get(desc, 0) + n
    if s != orig:
        p.write_text(s)
        print("patched", p)

print("--- totals ---")
for k, v in totals.items():
    print(" ", v, k)
