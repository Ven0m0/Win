# Decision: PSAppDeployToolkit for this repo's deployment

## Question

Should `Ven0m0/Win` adopt [PSAppDeployToolkit](https://psappdeploytoolkit.com) (PSADT) for its bootstrap/deployment layer?

## Findings

- PSADT's own README describes it as "Enterprise App Deployment, Simplified" — a PowerShell framework built to integrate with **Intune, SCCM, Tanium, BigFix**, and similar fleet management tools, targeting >98% deployment success rates across many managed machines.
- Its core value is wrapping a *single app's* installer/uninstaller with: user-facing close-running-apps prompts, deferral/countdown dialogs, reboot handling, MSI/EXE/MSP execution helpers, full-fidelity logging, and (as of v4.1) a SYSTEM-context-safe UI shown via a per-user helper process instead of `ServiceUI`.
- The expected project shape is one folder per packaged application, each with its own `Invoke-AppDeployToolkit.ps1`/`.exe` entry point, `AppProcessesToClose` list, and Install/Uninstall/Repair flow — designed to be invoked repeatedly across a device fleet by a deployment solution, not run once on a single personal machine.
- This repo already has a working deployment pipeline that solves a different problem: `install.conf.yaml` + `Scripts/Setup-Dotfiles.ps1` deploy *dotfiles/configs* via SHA256 hash-based copying (no admin needed), and package installs go through `winget --silent --accept-*` (see `.claude/rules/bootstrap-deployment.md`). There is no per-app "close it before installing," deferral-prompt, or fleet-rollout requirement anywhere in this repo's actual use case — it's a single user setting up their own machine.
- PSADT would add a sizeable new dependency (module + per-app template folders) to solve UX problems (deferral dialogs, SYSTEM-context UI, ADMX-driven policy) that only matter when deploying to users who aren't the person running the install.

## Decision

**Don't adopt.** PSADT solves enterprise fleet-deployment UX (deferral prompts, close-app dialogs, SYSTEM-context installs across many machines) that this repo's single-user winget + dotbot pipeline has no need for; adopting it would add a large dependency for capabilities this repo doesn't use.

## Follow-up

None — no future TODO item needed unless the repo's deployment target changes from "single personal machine" to "many managed machines."
