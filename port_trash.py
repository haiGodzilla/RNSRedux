import pathlib
p = pathlib.Path("scripts/objects/RNSPlayer.lua")
s = p.read_text()
old = """        local player_trash_contents = player_trash.get_contents()
        for name, count in pairs(player_trash_contents) do"""
new = """        for _, entry in pairs(player_trash.get_contents()) do
            local name = entry.name
            local count = entry.count"""
print("found:", s.count(old))
p.write_text(s.replace(old, new))
