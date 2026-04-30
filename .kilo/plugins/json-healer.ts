import type { Plugin } from "@opencode-ai/plugin";
import { IncrementalJsonRepair } from "repair-json-stream/incremental";

const CHUNK = 65536;

function looksLikeJson(s: string): boolean {
  const t = s.trimStart();
  return t.startsWith("{") || t.startsWith("[");
}

function isValidJson(s: string): boolean {
  try {
    JSON.parse(s);
    return true;
  } catch {
    return false;
  }
}

function inlineRepair(text: string): string {
  const r = new IncrementalJsonRepair();
  let out = "";
  for (let i = 0; i < text.length; i += CHUNK) out += r.push(text.slice(i, i + CHUNK));
  out += r.end();
  return out;
}

function repairIfNeeded(s: string): string {
  if (!looksLikeJson(s) || isValidJson(s)) return s;
  try {
    const repaired = inlineRepair(s);
    return isValidJson(repaired) ? repaired : s;
  } catch {
    return s;
  }
}

const JsonHealerPlugin: Plugin = async () => ({
  "tool.execute.before": async (input, output) => {
    if (["bash", "execute_bash", "write", "edit", "apply_patch"].includes(input.tool)) return;
    const args = output.args as Record<string, unknown>;
    for (const key of Object.keys(args)) {
      const val = args[key];
      if (typeof val === "string") {
        args[key] = repairIfNeeded(val);
      }
    }
  },

  "tool.execute.after": async (_input, output) => {
    const o = output as Record<string, unknown>;
    const raw = o["output"];
    if (typeof raw === "string") {
      o["output"] = repairIfNeeded(raw);
    }
  },
});

export default JsonHealerPlugin;