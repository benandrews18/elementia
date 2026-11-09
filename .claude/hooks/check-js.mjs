// PostToolUse hook: after Claude edits a .js/.mjs file, syntax-check it with
// `node --check`. On an error, exit 2 so the message goes back to Claude.
import { execFileSync } from "node:child_process";
let input = "";
for await (const chunk of process.stdin) input += chunk;
const file = JSON.parse(input || "{}").tool_input?.file_path || "";
if (!/\.(m?js)$/.test(file)) process.exit(0);
try {
  execFileSync(process.execPath, ["--check", file], { stdio: ["ignore", "ignore", "pipe"] });
} catch (e) {
  process.stderr.write(`Syntax error in ${file}:\n${String(e.stderr || e.message).trim()}\n`);
  process.exit(2);
}
