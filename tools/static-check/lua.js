// Shared helpers: repo root, the tracked Lua files, and a Lua 5.2 parse with scope info.
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");
const luaparse = require("luaparse");

const root = path.resolve(__dirname, "..", "..");

//Tracked and untracked-but-not-ignored files, minus deleted ones, so uncommitted work is checked too.
function luaFiles() {
  return execSync("git ls-files --cached --others --exclude-standard -- '*.lua'", { cwd: root }).toString()
    .trim().split("\n").filter(f => f && fs.existsSync(path.join(root, f)));
}

function parse(rel) {
  const src = fs.readFileSync(path.join(root, rel), "utf8");
  return luaparse.parse(src, { luaVersion: "5.2", scope: true, locations: true, comments: false });
}

//Globals every stage provides, from Lua itself and from Factorio.
const LUA_AND_SHARED = [
  "_G", "_ENV", "assert", "error", "ipairs", "pairs", "next", "pcall", "xpcall", "print", "rawget", "rawset",
  "rawequal", "rawlen", "select", "setmetatable", "getmetatable", "tonumber", "tostring", "type", "unpack",
  "require", "load", "math", "string", "table", "debug", "bit32",
  "log", "localised_print", "table_size", "serpent", "defines", "settings", "mods", "feature_flags", "helpers",
];

module.exports = { root, luaFiles, parse, LUA_AND_SHARED };
