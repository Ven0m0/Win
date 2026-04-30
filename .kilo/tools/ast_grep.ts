import { tool } from "@opencode-ai/plugin";

const search = tool({
  description: "AST structural code search across 25+ languages. Use $VAR for single-node meta-vars, $$$ for multi-node.",
  args: {
    rule: tool.schema.string().describe("AST pattern rule (e.g. 'function $F($args) { $body }')"),
    path: tool.schema.string().optional().describe("Directory to search (default: project root)"),
    lang: tool.schema.string().optional().describe("Language (e.g. ts, js, py). Auto-detected if omitted."),
    include: tool.schema.string().optional().describe("File glob filter (e.g. '*.ts')"),
    limit: tool.schema.number().optional().describe("Max matches (default: 50)"),
  },
  async execute(_args) {
    return "ast-grep (sg) is not yet available in this environment. Install @ast-grep/cli and ensure sg is in PATH.";
  },
});

const replace = tool({
  description: "AST structural search-and-replace. Use $VAR for node capture, $$$ for multi-node. Dry-run by default.",
  args: {
    rule: tool.schema.string().describe("Search pattern"),
    replacement: tool.schema.string().describe("Replacement pattern"),
    path: tool.schema.string().optional().describe("Directory to search"),
    lang: tool.schema.string().optional().describe("Language"),
    dryRun: tool.schema.boolean().optional().describe("Preview only (default: true)"),
  },
  async execute(_args) {
    return "ast-grep replace (sgr) is not yet available in this environment. Install @ast-grep/cli and ensure sg is in PATH.";
  },
});

export { search, replace };
