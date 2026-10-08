// Cross-checks the control-stage Lua against the Factorio 2.0 runtime API, as generated into
// typed-factorio from the official runtime-api.json:
//  A. every `defines.a.b(.c)` path used in the code exists
//  B. every dot-call `x.name(` on a non-mod receiver is a member name somewhere in the API.
//     Engine objects are called with a dot, mod objects with a colon, so a dot-call whose name the
//     API does not know is either a mod function (listed in MOD_FUNCTIONS) or a removed 1.1 API.
const fs = require("fs");
const path = require("path");
const { root, luaFiles } = require("./lua");

const gen = path.join(path.dirname(require.resolve("typed-factorio/package.json")), "runtime", "generated");
const read = f => fs.readFileSync(path.join(gen, f), "utf8");
const apiVersion = require("typed-factorio/package.json").factorioVersion;

//defines paths, relative to the `defines` namespace, rebuilt from the nesting in defines.d.ts
const defs = new Set();
{
  const stack = [];
  const put = name => {
    const i = stack.indexOf("defines");
    if (i >= 0) defs.add([...stack.slice(i + 1), name].filter(Boolean).join("."));
  };
  for (const raw of read("defines.d.ts").split("\n")) {
    const line = raw.replace(/\/\/.*$/, "");
    if (/^\s*(\*|\/\*)/.test(line)) continue;
    const opens = (line.match(/\{/g) || []).length;
    const closes = (line.match(/\}/g) || []).length;
    let m;
    if ((m = line.match(/^\s*(?:export\s+)?(?:declare\s+)?(?:const\s+)?(?:namespace|enum)\s+(\w+)\s*\{/))) {
      put(m[1]);
      if (opens > closes) stack.push(m[1]);
      continue;
    }
    if (closes > opens) { for (let i = 0; i < closes - opens; i++) stack.pop(); continue; }
    if (opens > closes) { for (let i = 0; i < opens - closes; i++) stack.push(""); continue; }
    if ((m = line.match(/^\s*(?:const\s+|readonly\s+)?(\w+)\s*(?::|=|,|$)/)) && !/^\s*(?:export|type)\b/.test(line)) put(m[1]);
  }
}

const members = new Set();
for (const f of fs.readdirSync(gen)) {
  for (const m of read(f).matchAll(/^\s*(?:readonly\s+)?(?:get\s+|set\s+)?(\w+)\??\s*[(:<]/gm)) members.add(m[1]);
}

//Receivers that are mod modules, Lua libraries or engine singletons checked elsewhere.
const SKIP_RECEIVERS = new Set(["Util", "BaseNet", "GuiApi", "GUI", "Event", "UpdateSys", "Migrate", "Constants",
  "ItemStore", "Itemstack", "StressTest", "NC", "ID", "FD", "IIO3", "FIO", "EIO", "NII", "WG", "WT", "TR", "DT",
  "RNSP", "NCbl", "NCug", "table", "string", "math", "serpent", "script", "commands", "remote", "rendering", "game",
  "helpers", "prototypes", "storage", "settings", "data", "defines", "log", "debug", "bit32", "self", "_G"]);
//Mod functions reached through a field (self.network.getOperableObjects(...)).
const MOD_FUNCTIONS = new Set(["filter_by_name", "getOperableObjects"]);

const files = luaFiles().filter(f => !f.startsWith("prototypes/") && !f.startsWith("data") && f !== "settings.lua"
  && !f.startsWith("tools/"));
const badDefs = new Map();
const unknownCalls = new Map();
const add = (m, k, v) => { if (!m.has(k)) m.set(k, []); m.get(k).push(v); };
for (const f of files) {
  fs.readFileSync(path.join(root, f), "utf8").split("\n").forEach((raw, i) => {
    const line = raw.replace(/--.*$/, "");
    for (const m of line.matchAll(/\bdefines\.((?:\w+\.)*\w+)/g)) if (!defs.has(m[1])) add(badDefs, "defines." + m[1], `${f}:${i + 1}`);
    for (const m of line.matchAll(/([\w\]\)]+)\.(\w+)\s*\(/g)) {
      const [, recv, name] = m;
      if (SKIP_RECEIVERS.has(recv) || /^[A-Z]/.test(recv) || MOD_FUNCTIONS.has(name)) continue;
      if (!members.has(name)) add(unknownCalls, name, `${f}:${i + 1}`);
    }
  });
}

console.log(`[api] Factorio ${apiVersion}: ${badDefs.size} unknown defines paths, ${unknownCalls.size} unknown engine calls`);
for (const [k, v] of badDefs) console.log(`  DEFINES ${k} <- ${v.slice(0, 4).join(", ")}${v.length > 4 ? ` (+${v.length - 4})` : ""}`);
for (const [k, v] of unknownCalls) console.log(`  CALL    ${k} <- ${v.slice(0, 4).join(", ")}${v.length > 4 ? ` (+${v.length - 4})` : ""}`);
process.exitCode = badDefs.size + unknownCalls.size > 0 ? 1 : 0;
