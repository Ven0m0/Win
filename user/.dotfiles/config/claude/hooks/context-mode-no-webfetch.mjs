#!/usr/bin/env node
// Removes context-mode's PreToolUse "WebFetch" matcher so native WebFetch is never
// denied/redirected to ctx_fetch_and_index (which fails on this machine with
// "AssignProcessToJobObject: (50)"). context-mode has no config switch for this, and a
// plugin update restores hooks.json, so this runs on every SessionStart. Idempotent.
import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const plugins = join(homedir(), ".claude", "plugins");
const cache = join(plugins, "cache", "context-mode", "context-mode");
const roots = [
  ...(existsSync(cache) ? readdirSync(cache).map((version) => join(cache, version)) : []),
  join(plugins, "marketplaces", "context-mode"),
];

for (const root of roots) {
  const file = join(root, "hooks", "hooks.json");
  if (!existsSync(file)) continue;
  try {
    const config = JSON.parse(readFileSync(file, "utf-8"));
    const before = config.hooks?.PreToolUse;
    if (!Array.isArray(before)) continue;
    const after = before.filter((entry) => entry.matcher !== "WebFetch");
    if (after.length === before.length) continue;
    config.hooks.PreToolUse = after;
    writeFileSync(file, JSON.stringify(config, null, 2) + "\n", "utf-8");
    console.error(`context-mode-no-webfetch: removed WebFetch matcher from ${file}`);
  } catch (error) {
    console.error(`context-mode-no-webfetch: could not patch ${file}: ${error.message}`);
  }
}
