---
name: windows-re-cli
description: Drive Windows reverse-engineering CLIs from the shell - rizin/rz-bin/rz-diff, frida/frida-trace, Ghidra headless, ilspycmd, capa/floss/diec, cdb, apktool/jadx. Use when asked to triage, disassemble, decompile, diff, trace or debug a PE/DLL/.NET/APK file and no MCP server is connected. Gives the tool order, exact flags, and the traps hit on this machine.
---

# Windows RE from the CLI

Tag legend: [V] = run and checked on this machine (2026-11-10). [U] = from memory or docs, not run here; run `<tool> --help` once before trusting a flag.

## Rules

1. Static first. Triage, then disassemble, then (only if needed) run. Executing an unknown sample on the host is never the default; ask for a VM/Sandbox first.
2. Prefer JSON (`-j`, `*j` commands) and filter with `jq`. Raw text output is large, CRLF-terminated, and may contain ANSI colour.
3. Cap output: pipe to `head`, or use `ctx_execute` and print only the answer. Never dump full `afl`, strings, or disassembly into context.
4. State what you found and what you inferred. A function name from analysis is a guess, not a fact.
5. These tools modify files only with explicit flags (`rizin -w`, `rz-bin -C`). Never pass them on the user's original; work on a copy.

## Which tool, in order

```
Question                          Tool                          Installed
--------------------------------  ----------------------------  ---------
What is this file? (PE triage)    rz-bin, diec, capa            rz-bin yes; diec, capa no
Hashes                            rz-hash                       yes
Disassemble, xrefs, imports       rizin                         yes
Compare two builds                rz-diff                       yes
Pseudo-C decompile                Ghidra headless               no (see below)
.NET to C#                        ilspycmd                      no
Android APK                       apktool (yes), jadx (no)
Runtime hooks / tracing           frida, frida-trace            yes
Crash dump / live debug (CLI)     cdb                           no
Interactive debug                 x64dbg + its MCP plugin       no (see x64dbg section)
Packets                           tshark                        yes
Wasm                              wabt (wasm2wat etc.)          yes, flags not checked
```

## rizin suite [V]

Triage with rz-bin (no analysis, fast):

```
rz-bin -Ij  f.exe          # info: arch, bits, compiler, pdb name, timestamp, mitigations
rz-bin -ij  f.exe          # imports
rz-bin -Ej  f.exe          # exports
rz-bin -lj  f.exe          # linked libs     (text: rz-bin -l)
rz-bin -Sj  f.exe          # sections (look for odd names, W+X perms)
rz-bin -Uj  f.exe          # resources
rz-bin -zj  f.exe          # strings from data sections (valid JSON)
rz-bin -zzq f.exe          # all raw strings, quiet text
rz-bin -P   f.exe          # pdb info
rz-hash -a sha256 f.exe
```

Gotcha: `rz-bin -zzj` emitted JSON that `jq` rejected (parse error). Use `-zj`, or `-zzq` with `rg`.

Disassembly and xrefs (one-shot, no REPL):

```
rizin -q -e scr.color=0 -c 'aaa; aflj' f.exe | jq -r '.[]|"\(.offset) \(.name) \(.size)"' | head -40
rizin -q -e scr.color=0 -c 'aa; s entry0; pd 30' f.exe
rizin -q -e scr.color=0 -c 'aa; s sym.main; pdf' f.exe      # whole function
rizin -q -e scr.color=0 -c 'iij' f.exe | jq -r '.[]|select(.name|test("CreateFile"))'
rizin -q -e scr.color=0 -c 'aaa; axtj @ 0xADDR' f.exe | jq -c '.[]|{from,type,fcn_name}'
```

- `-q` quits after the commands; `-e scr.color=0` disables colour. Use `aa` for speed, `aaa` for xrefs (slower).
- Addresses in JSON are decimal. Convert with `printf '0x%x\n' N`.
- Import xrefs: take the address from `ii`/`iij` (the IAT slot), then `axtj @ <that address>`. `axtj @ sym.imp.KERNEL32.dll_CreateFileW` returned `[]` for me.
- `pdg` (Ghidra decompiler plugin) is present but fails with "No sleigh specification for x86:LE:64:default" here. Do not rely on it; use Ghidra headless or Cutter's GUI decompiler.
- `rizin -d` debugs by executing the file. Avoid on unknown samples.

Compare two builds (`-t` picks what to compare; add `-j` for JSON):

```
rz-diff -t sections  old.dll new.dll
rz-diff -t imports   old.dll new.dll
rz-diff -t functions old.dll new.dll
rz-diff -t strings   old.dll new.dll
rz-diff -t graphs    old.dll new.dll      # needs two functions, dot output
```

Output is CRLF and may carry ANSI. Pipe through `sed 's/\x1b\[[0-9;]*m//g; s/\r//'` if grepping text.

## frida / frida-trace [V flags, 17.24.3]

```
frida-ps -a                                   # running apps; -U/-D/-H for USB/device/remote
frida -f app.exe -l hook.js -q               # spawn, load script, quiet, exit after script
frida -n notepad.exe -e 'console.log(Process.id)' -q   # attach by name, eval inline
frida -p 1234 -l hook.js                      # attach by pid
frida-trace -f app.exe -i 'CreateFile*'      # trace functions by name (glob)
frida-trace -n app.exe -I kernel32.dll -x 'Heap*'   # include module, exclude funcs
frida-trace -p 1234 -a 'app.exe!0x1a2b0'      # trace an address as MODULE!OFFSET
frida-trace -p 1234 -T                        # include imports of the main module
```

- `-q` is required for non-interactive runs, otherwise the REPL blocks the tool call. Always set a tool timeout.
- `-f` spawns and therefore runs the target. Same sandbox rule as above.
- frida-trace writes editable handlers under `__handlers__/` in the cwd. Run it from the scratchpad, not the project.
- Anti-debug or anti-frida targets: say so and stop; do not escalate to bypass tooling unprompted.

## Ghidra headless [U, not installed]

The only free real decompiler. Needs a JDK (Temurin 25 present via mise; check Ghidra's required version in its release notes).

```
analyzeHeadless <projdir> <projname> -import f.exe -overwrite -scriptPath <dir> -postScript Dump.java
analyzeHeadless <projdir> <projname> -process f.exe -noanalysis -postScript Dump.java   # reuse analysis
```

Prefer `pyghidra-mcp` (clearbluejar/pyghidra-mcp) or `GhidraMCP` once installed: they keep the analysis loaded between calls, which headless scripts do not.

## .NET [U, not installed]

```
dotnet tool install -g ilspycmd
ilspycmd -l c  app.dll                 # list classes
ilspycmd -t Namespace.Type app.dll     # decompile one type to stdout
ilspycmd -p -o outdir app.dll          # whole project
```

Check `ilspycmd --help` first: flag names changed across versions. If `ilspycmd` reports "obfuscated", note it; deobfuscation (de4dot) is out of scope until asked.

## Malware triage [U, not installed]

```
diec -j f.exe        # Detect-It-Easy: packer, compiler, entropy. Run first.
capa -j f.exe        # capabilities mapped to ATT&CK. -vv for evidence.
floss f.exe          # decoded/stack strings; run on packed or obfuscated files
```

If `diec` shows a packer, say so before disassembling: imports and strings from a packed file are misleading.

## cdb (WinDbg console) [U, not installed]

Comes with the Windows SDK "Debugging Tools" or the WinDbg package.

```
cdb -z crash.dmp -c '!analyze -v; q'            # dump triage
cdb -c 'g; k; q' app.exe                         # run, then stack, then quit
cdb -z crash.dmp -c '.symfix; .reload; !analyze -v; q'
```

Always end `-c` strings with `q`, or the call never returns.

## x64dbg (interactive user-mode debugger) [U, not installed; README read, not run]

No headless CLI: the GUI must be open. Claude drives it through `duty1g/x64dbg-mcp-server`, a plugin (`.dp64`/`.dp32`) that serves MCP over HTTP from inside x64dbg (72 tools: breakpoints, stepping, registers, memory read/write, disassembly, xrefs, `DetectOEP`, `DumpModule`, `ExecuteDebuggerCommand`).

Setup facts from its README:
- Copy the release `dist/` contents into the x64dbg root, start x64dbg. x64 listens on port 9094, x32 on 9095.
- Default bind is `0.0.0.0` (all interfaces), plain HTTP. Change it to `127.0.0.1` in Plugins > x64dbg-MCP Server > Configure before any use. WSL access is the only reason to leave it open.
- A bearer token is generated on first run; it is a secret. Keep it in an env var, never in a committed `.mcp.json`.
- Client config: `{"mcpServers":{"x64dbg":{"type":"http","url":"http://127.0.0.1:9094/","headers":{"Authorization":"Bearer <token>"}}}}`
- The server can write process memory and run code in the target. Debug only inside a VM for unknown samples.

Typical flow when the MCP is connected: `LoadBinary` -> `SetBreakpoint` -> `run` -> `WaitForPause` -> `GetAllRegisters` / `GetCallStack` / `ReadMemory`. Use `WaitForPause`/`WaitForEvent` instead of polling. For packed files try `DetectOEP`, then `DumpModule` and continue static work in rizin.

When x64dbg is not connected, use `cdb` (console, scriptable) or `frida` for the same questions.

## Android [apktool V present, jadx U]

```
apktool d app.apk -o out        # resources + smali (apktool 3.0.3 installed)
jadx -d out app.apk             # Java source; not installed (scoop install jadx)
```

## Output hygiene

- Text from `rz-bin` and `rz-diff` is CRLF with Unicode rules (`―`); strip before regex work.
- Write large results to the scratchpad, then query with `jq`/`rg`; report counts and the top few lines.
- Report findings as: fact (from tool output, with the command), inference (labelled), not checked.
