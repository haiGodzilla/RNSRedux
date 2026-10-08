// Per stage, follows require("a.b") from the stage's entry files and reports global reads that no
// file of that stage writes and that the engine does not provide. A global defined only in another
// stage is nil at runtime.
const fs = require("fs");
const path = require("path");
const { root, parse, LUA_AND_SHARED } = require("./lua");

const STAGES = {
  settings: { entries: ["settings.lua"], engine: ["data"] },
  //border_image_set & co. are globals that __core__/prototypes/style.lua leaves in the shared data
  //state; pipecoverspictures comes from __base__.
  data: {
    entries: ["data.lua", "data-updates.lua", "data-final-fixes.lua"],
    engine: ["data", "border_image_set", "outer_frame_light", "offset_by_2_default_glow", "default_dirt_color", "pipecoverspictures"],
  },
  control: { entries: ["control.lua"], engine: ["game", "script", "remote", "commands", "rendering", "prototypes", "storage", "rcon"] },
};

const cache = {};
function info(rel) {
  if (cache[rel]) return cache[rel];
  const r = { reads: [], writes: new Set(), requires: [] };
  (function walk(n, w) {
    if (!n || typeof n.type !== "string") return;
    switch (n.type) {
      case "Identifier":
        if (!n.isLocal) { if (w) r.writes.add(n.name); else r.reads.push([n.name, n.loc.start.line]); }
        return;
      case "CallExpression":
        if (n.base.type === "Identifier" && n.base.name === "require" && n.arguments[0] && n.arguments[0].type === "StringLiteral")
          r.requires.push(n.arguments[0].raw.slice(1, -1));
        break;
      case "AssignmentStatement":
        n.variables.forEach(v => walk(v, v.type === "Identifier"));
        n.init.forEach(e => walk(e, false));
        return;
      case "LocalStatement":
        n.init.forEach(e => walk(e, false));
        return;
      case "FunctionDeclaration":
        if (n.identifier) walk(n.identifier, n.identifier.type === "Identifier" && !n.isLocal);
        n.body.forEach(s => walk(s, false));
        return;
      case "MemberExpression":
        walk(n.base, false);
        return;
      case "TableKeyString":
        walk(n.value, false);
        return;
      case "GotoStatement": case "LabelStatement":
        return;
    }
    for (const k of Object.keys(n)) {
      if (k === "loc") continue;
      const v = n[k];
      if (Array.isArray(v)) v.forEach(c => walk(c, false));
      else if (v && typeof v === "object" && v.type) walk(v, false);
    }
  })(parse(rel), false);
  return (cache[rel] = r);
}

let problems = 0;
for (const [stage, { entries, engine }] of Object.entries(STAGES)) {
  const seen = new Set();
  const queue = [...entries];
  while (queue.length) {
    const f = queue.shift();
    if (seen.has(f)) continue;
    if (!fs.existsSync(path.join(root, f))) { console.log(`  [${stage}] REQUIRE NOT FOUND: ${f}`); problems++; continue; }
    seen.add(f);
    info(f).requires.filter(q => !q.startsWith("__")).forEach(q => queue.push(q.replace(/\./g, "/") + ".lua"));
  }
  const writes = new Set();
  seen.forEach(f => info(f).writes.forEach(w => writes.add(w)));
  const known = new Set([...LUA_AND_SHARED, ...engine]);
  const bad = new Map();
  seen.forEach(f => info(f).reads.forEach(([n, l]) => {
    if (writes.has(n) || known.has(n)) return;
    if (!bad.has(n)) bad.set(n, []);
    bad.get(n).push(`${f}:${l}`);
  }));
  console.log(`[stages] ${stage}: ${seen.size} files, ${bad.size} undefined globals`);
  for (const [n, locs] of bad) console.log(`  ${n} <- ${locs.slice(0, 5).join(", ")}`);
  problems += bad.size;
}
process.exitCode = problems > 0 ? 1 : 0;
