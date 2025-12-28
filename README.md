# Scripts

This repository contains a modular PowerShell-based system updater/orchestrator intended to run on Windows systems. The orchestrator `Update-All.ps1` loads small, focused updater scripts from the `modules/` folder to perform package and system maintenance tasks (Chocolatey, Winget, Windows Update, PowerShell modules, Python packages, Docker, etc.).

## Files of interest
- `Update-All.ps1` — main orchestrator. Supports `-WhatIf`, `-SkipModules`, `-RunModules`, and `-LogFile`.
- `modules/` — directory containing per-concern updater scripts. Each module exposes a single `Invoke-Update*` function and returns a structured PSCustomObject.
  - `Update-Chocolatey.ps1`
  - `Update-Winget.ps1`
  - `Update-WindowsUpdate.ps1`
  - `Update-PowerShellModules.ps1`
  - `Update-Python.ps1`
  - `Update-Docker.ps1`
  - `Notify.ps1` — event log + BurntToast helper (`Invoke-Notify`) and `Ensure-ToastAvailable`.
  - `Helpers.ps1` — utility helpers like `Invoke-WithRetry` and `Write-LogJsonLine`.
  - `Update-Modules-Helper.ps1` — elevated helper to update locked PowerShell modules after the main run exits.

## Features
- Modular design: each updater is small and independently callable.
- Structured logging: modules write JSONL lines when `-LogFile` is provided.
- Dry-run support: `-WhatIf` parameter to validate behavior without making changes.
- Safe module updates: failed PowerShell module updates are retried via an elevated helper that runs after the orchestrator exits.
- Notifications: Event Log entries plus optional BurntToast notifications using `Invoke-Notify`.

## Prerequisites
- PowerShell (Windows PowerShell or PowerShell 7)
- Internet access for module/package updates
- Optional: Chocolatey, winget, docker, pip/pipx, rustup, gem, code (VSCode CLI) depending on which modules you run

## Quick usage
Open an elevated PowerShell console and run:

`.\Update-All.ps1`

Dry-run (no changes):

`.\Update-All.ps1 -WhatIf -LogFile C:\Temp\update-log.jsonl`

Run only specific modules:

`.\Update-All.ps1 -RunModules @('Chocolatey','Python')`

Skip modules:

`.\Update-All.ps1 -SkipModules @('Docker')`

Custom log file:

`.\Update-All.ps1 -LogFile C:\Path\to\updates.jsonl`

## Scheduled task
The orchestrator can create a scheduled task; default task name is `Update System (Choco + Winget + Windows Update)`. The task points to `C:\Scripts\Update-All.ps1` (update path if you move the repository).

## Logs
The orchestrator and modules append structured JSON lines (JSONL) to the file configured via `-LogFile`. Each line is a compact JSON object for easy ingestion.

## Troubleshooting
- "Module in use" errors when updating PowerShell modules: the orchestrator collects failed modules and launches `modules/Update-Modules-Helper.ps1` elevated. Inspect the JSONL log for helper results.
- BurntToast notifications not appearing: ensure the `BurntToast` module is installed for the current user. `Invoke-Notify` will attempt to install/update BurntToast automatically.
- No Chocolatey/winget/docker present: corresponding modules skip gracefully if the binary is not installed.

## Development notes
- Module signature convention: `Invoke-Update* -WhatIf -LogFile <path>` and returns a PSCustomObject with `Module`, `Success`, `Message`, `Duration`, and `Errors` fields.
- Helpers: reuse `Invoke-WithRetry` for flaky network operations and `Write-LogJsonLine` to append logs.
- When adding new modules, follow the existing pattern and add the filename to the `Update-All.ps1` `moduleFiles` list.

## Contributing
- Run `.	ools\run-linter.ps1` (if you add it) or use `PSScriptAnalyzer` to keep style consistent.
- Open a PR with focused changes for a single module or the orchestrator.

---

If you want, I can also:
- Add comment-based `Get-Help` blocks for each `Invoke-Update*` function
- Add a small smoke-test script that verifies module signatures with `-WhatIf`
- Add log rotation/retention for the JSONL file
