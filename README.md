# Windows Boot Performance Diagnostic and Repair Toolkit

PowerShell tooling for Windows startup and boot-performance analysis plus guarded local repair, created by **Dewald Pretorius**.

## Files

- `Windows_Boot_Performance_Diagnostic_Toolkit.ps1` — read-only uptime, boot event and startup inventory reporting.
- `Windows_Boot_Performance_Repair_Toolkit.ps1` — guarded Explorer, icon-cache, startup-entry, scheduled-task and component-integrity repairs.
- `Launch_Boot_Repair.bat` — interactive technician menu.

## Diagnostic default

Running the repair script without a repair switch captures boot events, Explorer state, current-user Run entries, scheduled tasks and icon-cache files without changing the workstation:

```powershell
.\Windows_Boot_Performance_Repair_Toolkit.ps1
```

## Safe repair set

The safe set backs up and rebuilds the current user's icon cache, then restarts Windows Explorer:

```powershell
.\Windows_Boot_Performance_Repair_Toolkit.ps1 -RepairAllSafe -DryRun
```

## Individual repairs

```powershell
.\Windows_Boot_Performance_Repair_Toolkit.ps1 -RestartExplorer
.\Windows_Boot_Performance_Repair_Toolkit.ps1 -ClearIconCache
.\Windows_Boot_Performance_Repair_Toolkit.ps1 `
  -DisableScheduledTask -TaskPath "\Vendor\" -TaskName "Updater"
.\Windows_Boot_Performance_Repair_Toolkit.ps1 `
  -DisableCurrentUserRunEntry -RunValueName "VendorUpdater"
.\Windows_Boot_Performance_Repair_Toolkit.ps1 -RunDism
.\Windows_Boot_Performance_Repair_Toolkit.ps1 -RunSfc
```

## Repair behaviour

- Restarts Windows Explorer.
- Moves icon-cache files into a timestamped backup before Explorer recreates them.
- Disables one explicitly selected non-Microsoft scheduled task after exporting its XML definition.
- Disables one explicitly selected value from the current user's `Run` registry key after exporting the original key and value.
- Runs DISM RestoreHealth or System File Checker when selected.
- Captures before-and-after startup and boot evidence.

The tool refuses to disable scheduled tasks under `\Microsoft\Windows\`.

## Logs, evidence and rollback material

Each run creates a timestamped desktop folder containing:

- `before.json` and `after.json`
- `repair.log`
- Icon-cache backups when rebuilt
- Scheduled-task XML export when a task is disabled
- Current-user Run-key `.reg` export and JSON record when a Run entry is disabled
- DISM or SFC output when selected

Task and registry exports are rollback material, but restoration remains a deliberate manual action.

## Safety

- Diagnosis is the default.
- `-DryRun` previews repair actions.
- Standard actions require typing `YES` unless `-Yes` is supplied.
- Startup-task and Run-entry changes require typing `REPAIR`.
- DISM, SFC and scheduled-task changes normally require elevation.
- The tool does not delete startup applications, uninstall software, alter boot configuration data or disable Microsoft Windows system tasks.
- DISM and SFC can take a long time and should not be interrupted.

## Exit codes

| Code | Meaning |
|---:|---|
| 0 | Completed successfully, including diagnosis or dry-run |
| 2 | Invalid target or safety refusal |
| 4 | Elevation required |
| 10 | User cancelled |
| 20 | Repair action failed |

## Interactive launcher

Double-click:

```text
Launch_Boot_Repair.bat
```

The scripts have been source-reviewed for Windows PowerShell 5.1 but have not been runtime-tested against every startup application, scheduled task or Windows build.
