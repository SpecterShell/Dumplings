# QSetup setup runtime

## Installation phases

```text
start setup
  -> validate package and companion media
  -> resolve scope, registry view, and path aliases
  -> evaluate operating-system and prerequisite policy
  -> collect required user information
  -> copy selected records according to Setup.txt order
  -> apply registry, INI, XML, association, shortcut, and environment operations
  -> run stage-specific Execution Engine commands
  -> write generated uninstaller and built-in ARP entry
  -> perform completion, launch, or restart actions
```

Physical record order provides storage. `Setup.txt` provides destination and execution order. The two orders need not match.

## Scope, elevation, and registry view

Explicit all-users or current-user directives take priority. Requested execution level and a deterministic installation root provide fallback evidence. `requireAdministrator` establishes elevation but cannot identify the final hive of every generic registry operation.

QSetup launchers are commonly I386 even when the project enables 64-bit setup state. The setup state controls built-in registry view; payload architecture is derived separately from selected installed binaries. Do not infer x86 package architecture from the outer launcher.

## Requirements and conditions

`SET_ALLOWED_OS` can prove an x64-only package when payload evidence is unavailable. .NET requirement directives and `SET_MSI_CODES` are prerequisite evidence. They are not automatically promoted to package dependencies because runtime conditions can skip, download, or launch a prerequisite and because an MSI code does not identify the outer package.

Execution Engine conditions are retained with category and runtime-state requirements. The parser does not evaluate the analyst host's registry, processes, services, locale, hardware, or network. User-interaction predicates receive a dedicated diagnostic so unattended behavior is tested rather than assumed.

## Command-line behavior

The QSetup manual documents `/hide`, `/silent`, and `/InstallDir="<path>"`. `/hide` suppresses the interface and maps to WinGet `Silent`; `/silent` retains progress and maps to `SilentWithProgress`. A compiled User Information dialog requiring name, company, or serial data disables both unattended suggestions.

The Composer compiler and a generated setup have different process-result contracts. The parser does not reuse a documented Composer build result as `InstallerSuccessCodes`. A controlled QSetup 12 `/hide` install and generated uninstall returned zero, but package validation should still capture the exact process exit code.

## Nested execution

Process-launch actions can invoke EXE, MSI, batch, shell, DLL, prerequisite, or other nested routes. `ExecutedPayloads` returns command, parameters, show mode, wait state, stage, setup or uninstall phase, and condition evidence. Outer QSetup switches do not automatically apply to a nested installer.

Downloads and external DLL calls remain opaque effects. The parser can report a literal URL command or URL without fetching data or predicting child-process registry changes.

## First-run boundary

QSetup can register associations directly, but the installed application may add more on first run. Compare before-install, after-install, and after-first-run snapshots when complete protocol and extension evidence matters.
