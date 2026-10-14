# Nexora Care

**Simple. Transparent. In your control.**

Nexora Care is a Windows maintenance utility project built with PowerShell. Its goal is to keep maintenance actions understandable, limited in scope, and reviewable by the user.

> **Development status:** Early development. Review the scripts before running them. This repository is not yet a packaged or production-ready application.

## Current functionality

### Maintenance script

`src/Core/Maintenance.ps1`:

- Checks that the `TEMP` environment variable points to the current user's expected local Temp directory.
- Processes eligible files directly inside that directory that are older than one day.
- Skips directories and reparse-point files.
- Requests the Windows Balanced power plan.
- Writes maintenance messages to a local log.

The script does not recursively clean subdirectories. Files that are locked or inaccessible may be skipped.

### Uninstaller

`src/Uninstall.ps1`:

- Attempts to remove the `NexoraCare-AutomaticMaintenance` scheduled task.
- Attempts to restore the `MenuShowDelay` setting from a local backup when the current value is `0`.
- Does not automatically delete the remaining product folder.

Review the script and ensure the backup is trustworthy before using it. The current uninstaller has not yet been fully hardened for public release.

## Requirements

- Windows
- Windows PowerShell
- Permission to perform the requested operations

Some actions may be unavailable or behave differently depending on the Windows environment and user permissions.

## Safety and transparency

- Review scripts before execution.
- Keep personal logs, backups, machine-specific task exports, and recovery archives out of source control.
- Test changes in a disposable environment before relying on them.
- Do not assume a logged message proves that a native Windows command succeeded; check its exit status.

## Project structure

```text
Nexora-Care/
├── src/
│   ├── Core/
│   │   └── Maintenance.ps1
│   └── Uninstall.ps1
├── tests/
├── docs/
├── .gitignore
├── LICENSE
└── README.md
```

## Development

The project is under active review. Testing, improved error handling, and safer installation and uninstallation workflows are planned before a stable release.

## Contributions

Issues and carefully reviewed contributions are welcome. Please avoid including personal data, machine-specific logs, or sensitive system information in reports.

## License

See [LICENSE](LICENSE).
