import re, pathlib

p = pathlib.Path("scripts/objects/ItemDrives.lua")
s = p.read_text()

# 2.0: draw_sprite returns a LuaRenderObject; keep only its numeric id in storage,
# because LuaObjects do not survive save/load reliably.
new_regen = """function ID:regenerate_icons()
    for i, ii in pairs(self.icons) do
        if ii ~= nil then
            local obj = rendering.get_object_by_id(ii)
            if obj then obj.destroy() end
            self.icons[i] = nil
        end
    end
    local i = 0
    for n, _ in pairs(self.filters) do
        i = i + 1
        local obj = rendering.draw_sprite{
            sprite = "item/"..n,
            target = self.thisEntity,
            surface = self.thisEntity.surface,
            render_layer = "higher-object-under",
            target_offset = Constants.Settings.RNS_DriveSprite_Offset[i],
            only_in_alt_mode = true
        }
        if obj then table.insert(self.icons, obj.id) end
    end
end"""

new_toggle = """function ID:toggleHoverIcon(hovering)
    for _, i in pairs(self.icons) do
        local obj = rendering.get_object_by_id(i)
        if obj then obj.only_in_alt_mode = not hovering end
    end
end"""

s, n1 = re.subn(r"function ID:regenerate_icons\(\).-\nend", new_regen, s, count=1, flags=re.S)
s, n2 = re.subn(r"function ID:toggleHoverIcon\(hovering\).-\nend", new_toggle, s, count=1, flags=re.S)
print("regenerate_icons:", n1, " toggleHoverIcon:", n2)
p.write_text(s)
