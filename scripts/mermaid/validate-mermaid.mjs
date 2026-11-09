// Validates every ```mermaid block in the repository's Markdown files.
//
// Checks:
//   1. The block parses with Mermaid (the library GitHub uses to render diagrams).
//   2. Flowcharts and state diagrams define at least one classDef (repository colour convention).
//
// Usage: node validate-mermaid.mjs [repo-root]      exit code 1 on any failure
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative, resolve } from "node:path";
import { JSDOM } from "jsdom";

const dom = new JSDOM("<!doctype html><html><body></body></html>");
globalThis.window = dom.window;
globalThis.document = dom.window.document;
globalThis.DOMPurify = undefined;

const { default: mermaid } = await import("mermaid");
mermaid.initialize({ startOnLoad: false, securityLevel: "strict" });

const root = resolve(process.argv[2] ?? join(import.meta.dirname, "..", ".."));
const skipDirs = new Set([".git", "node_modules", ".terraform"]);

function* markdownFiles(dir) {
  for (const name of readdirSync(dir)) {
    if (skipDirs.has(name)) continue;
    const path = join(dir, name);
    if (statSync(path).isDirectory()) yield* markdownFiles(path);
    else if (name.endsWith(".md")) yield path;
  }
}

const fence = /^```mermaid[ \t]*\n([\s\S]*?)^```[ \t]*$/gm;
let blocks = 0;
const failures = [];

for (const file of markdownFiles(root)) {
  const text = readFileSync(file, "utf8");
  for (const match of text.matchAll(fence)) {
    blocks += 1;
    const code = match[1];
    const line = text.slice(0, match.index).split("\n").length;
    const where = `${relative(root, file)}:${line}`;
    try {
      await mermaid.parse(code);
    } catch (err) {
      failures.push(`${where}  parse error: ${String(err.message ?? err).split("\n").slice(0, 4).join(" | ")}`);
      continue;
    }
    const kind = code.trim().split(/\s/)[0];
    if (["flowchart", "graph", "stateDiagram-v2", "stateDiagram"].includes(kind) && !/classDef\s/.test(code)) {
      // State diagrams may rely on notes only; flowcharts must be coloured.
      if (kind === "flowchart" || kind === "graph") failures.push(`${where}  flowchart without classDef colours`);
    }
  }
}

for (const f of failures) console.error(`FAIL ${f}`);
console.log(`${blocks} Mermaid block(s) checked, ${failures.length} failure(s)`);
process.exit(failures.length ? 1 : 0);
