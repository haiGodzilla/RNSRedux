// 1. Every tracked .lua file parses as Lua 5.2, the base of Factorio's dialect.
// 2. No global is assigned from inside a function body, which is how an implicit global is born.
const { luaFiles, parse } = require("./lua");

const parseErrors = [];
const leaks = [];

function walk(node, file, fnDepth, write) {
  if (!node || typeof node.type !== "string") return;
  switch (node.type) {
    case "Identifier":
      if (write && !node.isLocal && fnDepth > 0) leaks.push(`${file}:${node.loc.start.line} ${node.name}`);
      return;
    case "AssignmentStatement":
      node.variables.forEach(v => walk(v, file, fnDepth, v.type === "Identifier"));
      node.init.forEach(e => walk(e, file, fnDepth, false));
      return;
    case "FunctionDeclaration":
      if (node.identifier && node.identifier.type === "Identifier" && !node.isLocal) walk(node.identifier, file, fnDepth, true);
      node.body.forEach(s => walk(s, file, fnDepth + 1, false));
      return;
  }
  for (const key of Object.keys(node)) {
    if (key === "loc") continue;
    const v = node[key];
    if (Array.isArray(v)) v.forEach(c => walk(c, file, fnDepth, false));
    else if (v && typeof v === "object" && typeof v.type === "string") walk(v, file, fnDepth, false);
  }
}

const files = luaFiles();
for (const f of files) {
  let ast;
  try { ast = parse(f); } catch (e) { parseErrors.push(`${f}: ${e.message}`); continue; }
  ast.body.forEach(s => walk(s, f, 0, false));
}

console.log(`[globals] ${files.length} files, ${parseErrors.length} parse errors, ${leaks.length} implicit globals`);
parseErrors.forEach(e => console.log("  PARSE  " + e));
leaks.forEach(l => console.log("  LEAK   " + l));
process.exitCode = parseErrors.length + leaks.length > 0 ? 1 : 0;
