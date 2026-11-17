#!/usr/bin/env node
// Removes context-mode's PreToolUse WebFetch interception so native WebFetch is never
// denied/redirected to ctx_fetch_and_index (which fails on this machine with
// "AssignProcessToJobObject: (50)"). context-mode has no config switch for this, and a
// plugin update restores its hook files, so this runs on every SessionStart. Idempotent.
//
// Two shapes exist: 1.x hooks/hooks.json has a bare "WebFetch" matcher entry; 2.x
// hooks/claude-code.json has one regex "^(Bash|...|WebFetch|...)$" shared with other tools.
// Only PreToolUse is touched: PostToolUse WebFetch just records the call.
import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";

const configDir = process.env.CLAUDE_CONFIG_DIR?.trim()
  ? resolve(process.env.CLAUDE_CONFIG_DIR.replace(/^~(?=[/\\]|$)/, homedir()))
  : join(homedir(), ".claude");
const plugins = join(configDir, "plugins");
const cache = join(plugins, "cache", "context-mode", "context-mode");
const roots = [
  ...(existsSync(cache) ? readdirSync(cache).map((version) => join(cache, version)) : []),
  join(plugins, "marketplaces", "context-mode"),
];
const hookFiles = ["hooks.json", "claude-code.json"];

// Returns the matcher without WebFetch, or null when nothing is left. A matcher that does
// not mention WebFetch (or is not a plain alternation) is returned unchanged.
function stripWebFetch(matcher) {
  if (typeof matcher !== "string") return matcher;
  const shape = /^(\^?\(?)([^()]*)(\)?\$?)$/.exec(matcher);
  if (!shape) return matcher;
  const parts = shape[2].split("|");
  const kept = parts.filter((part) => part !== "WebFetch");
  if (kept.length === parts.length) return matcher;
  return kept.length ? `${shape[1]}${kept.join("|")}${shape[3]}` : null;
}

function patch(file) {
  if (!existsSync(file)) return;
  try {
    const config = JSON.parse(readFileSync(file, "utf-8"));
    const before = config.hooks?.PreToolUse;
    if (!Array.isArray(before)) return;
    const after = [];
    let changed = false;
    for (const entry of before) {
      const matcher = stripWebFetch(entry.matcher);
      if (matcher === entry.matcher) {
        after.push(entry);
        continue;
      }
      changed = true;
      if (matcher !== null) after.push({ ...entry, matcher });
    }
    if (!changed) return;
    writeFileSync(file, JSON.stringify({ ...config, hooks: { ...config.hooks, PreToolUse: after } }, null, 2) + "\n", "utf-8");
    console.error(`context-mode-no-webfetch: removed WebFetch from PreToolUse in ${file}`);
  } catch (error) {
    console.error(`context-mode-no-webfetch: could not patch ${file}: ${error.message}`);
  }
}

for (const root of roots) for (const name of hookFiles) patch(join(root, "hooks", name));
