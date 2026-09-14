# InstallBuilder setup runtime

## Runtime phases

InstallBuilder evaluates project rules, unpacks selected folders, applies actions, creates its uninstaller and built-in ARP entry, and may launch presentation actions. Static analysis preserves the phase because the same registry or execution action has different manifest meaning depending on when it runs.

```text
initialization and startup actions
project parameters, modes, pages, and component choices
preInstallationActionList
readyToInstallActionList
repeat for each selected folder:
  unpack folder files
  folder-owned actionList
postInstallationActionList
create built-in uninstaller and optional Windows ARP row
postUninstallerCreationActionList
final-page and presentation actions
```

Failure, cancellation, and rollback lists operate on an unsuccessful transaction. Uninstallation lists remove or alter installed state later. Neither route is merged into the successful default-install projection.

## Lifecycle classes

| Lifecycle | Representative lists | Static use |
| --- | --- | --- |
| `Installation` | pre-install, ready-to-install, folder, post-install, post-uninstaller-creation | Eligible for installed-state projection when conditions and values resolve |
| `Presentation` | final-page, pre-show, post-show, page actions | Application launch and UI evidence only |
| `Initialization` | initialization and startup | Parameter setup or prerequisite probing, not persistent state by default |
| `Rollback` | rollback, aborted, cancel, failure, error | Failure cleanup evidence |
| `Uninstallation` | action lists whose phase names contain uninstall | Removal behavior |
| `Unknown` | unrecognized list owner | Preserved without installed-state claims |

Nested `actionGroup`, `if`, and `while` containers do not create a new lifecycle. Their leaf actions inherit the nearest named action list and all enclosing conditions.

## Installation modes

The project can restrict `allowedInstallationModes`. An omitted or empty allowlist keeps the runtime's normal interactive and unattended support. A project that excludes `unattended` is interactive-only even though the launcher contains generic unattended-mode strings.

| Structural route | Silent switch | Progress switch | Reason |
| --- | --- | --- | --- |
| `LegacyMetakit` 3.x and 4.x | `--mode unattended` | Not claimed | The runtime documents unattended mode but predates `unattendedModeUI` |
| CookFS-era or project with `unattendedModeUI` | `--mode unattended --unattendedmodeui none` | `--mode unattended --unattendedmodeui minimal` | Explicit UI mode overrides a project default such as `minimal` or `minimalWithDialogs` |

`InstallModes` includes `interactive` when any non-unattended mode remains allowed, `silent` when unattended is allowed, and `silentWithProgress` only when the runtime supports `unattendedModeUI`. WinGet has no InstallBuilder defaults, so these source-proven switches must be authored when the modes are used.

## Installation directory and logging

The installation directory is a project parameter, normally `installdir`, with `cliOptionName` set to `prefix`. The manifest switch is derived from the compiled name rather than assumed when the parameter is customized.

```text
normal install-location switch: --prefix "<INSTALLPATH>"
custom parameter route:         --<cliOptionName> "<INSTALLPATH>"
installer log:                  --debugtrace "<LOGPATH>"
```

The command-line value can change subsequent folder destinations, registry values, shortcuts, and child-process arguments. Static metadata reports the compiled default; VM validation must use the actual override when testing those effects.

## Exit behavior

InstallBuilder projects and nested actions can define additional failure paths, so the parser does not return a universal nonzero success-code list. Treat exit code zero as the normal expected result only after the selected package and switches are exercised. A child process or custom script can fail after the outer runtime has already changed state, and a successful outer code does not prove that a nested installer completed.

## Scope and elevation

Package scope comes from the effective registry and installation route, not `installationScope`. The parser combines these signals:

1. A resolved built-in HKLM ARP route establishes machine-oriented installed state.
2. Effective literal HKLM or HKCU uninstall writes establish their corresponding registry scope.
3. `requireInstallationByRootUser` can require an already elevated caller.
4. The PE requested execution level determines whether the launcher asks Windows to elevate itself.
5. A resolved default destination under Program Files supports machine-scope inference when stronger evidence is absent.

`requireAdministrator` maps to WinGet `ElevationRequirement: elevatesSelf`. A project that requires administrator state without a self-elevating PE maps to `elevationRequired`. An `asInvoker` PE is not proof of user scope if project logic later writes HKLM through a helper or child process.

A project can branch on `${installer_is_root_install}` and write HKCU in one branch and HKLM in another. When both routes are structurally present but runtime selection is unresolved, return dual-scope evidence and require VM validation instead of picking one hive.

## Shortcut scope

`installationScope` controls whether Start Menu and desktop shortcuts are created for the current user or all users. It does not select the installation directory, ARP hive, process elevation, or registry view. Keep it under `ShortcutScope`; do not project it as WinGet `Scope` by itself.

## Registry view and 64-bit mode

The Windows launcher and project can select different views:

| Evidence | Registry and path consequence |
| --- | --- |
| Native x64 or ARM64 launcher | Native 64-bit registry view and Program Files projection |
| x86 launcher with `windows64bitMode=1` | 64-bit registry and Program Files behavior despite the x86 process image |
| x86 launcher without 64-bit mode | 32-bit registry view and `%ProgramFiles(x86)%` defaults |

Native Windows x64 runtimes appeared in InstallBuilder 19.5. That release boundary helps select expectations but cannot replace the actual PE machine and project flag.

## Installed application architecture

Launcher architecture does not establish installed application architecture. InstallBuilder can carry Java bytecode, AnyCPU .NET assemblies, mixed x86/x64 native files, scripts, or architecture-specific components. `PrimaryExecutableCandidates` identifies embedded executables referenced by shortcuts and execution actions. `-AnalyzePrimaryExecutables` extracts a bounded subset plus adjacent DLL and .NET sidecars and passes them to shared PE architecture and dependency analysis.

The default analysis remains metadata-only to avoid decompressing large payload pages. Author `Architecture` from the analyzed application payload or trusted vendor artifact selection, not from the setup stub alone.

## Component and platform selection

The default payload is the intersection of physically packaged files and project selection:

```text
packaged file
AND component selected by default
AND folder selected by default
AND platform list accepts Windows runtime
AND inherited condition rules resolve true
= default installed payload
```

False conditions move files to `ExcludedPayloadFiles`; unknown conditions move them to `ConditionalPayloadFiles`. Command-line component selection, UI choices, filesystem tests, and target-state probes can make the VM result differ from the static default. Use the same mode and parameters during validation.

## Registry and system actions

Installation actions are applied in order after condition evaluation and variable expansion. `setEnvironmentVariable` affects only the installer process. Persistent environment variables, PATH changes, services, scheduled tasks, fonts, shared-DLL references, ACLs, registry rows, and associations are separate runtime actions whose scopes and removal behavior come from their compiled properties.

The parser does not execute service commands, task commands, scripts, DLL calls, or child processes. Password-bearing service and scheduled-task properties are redacted. An unresolved rule prevents that action from becoming authoritative installed-state evidence.

## Nested execution

InstallBuilder can package and execute prerequisite installers or application setup programs. The parser distinguishes three important cases:

| Purpose | Typical phase | Interpretation |
| --- | --- | --- |
| Installer action | pre-install, ready-to-install, folder, or post-install | Candidate nested installer that may own ARP or dependencies |
| Application launch | final page or presentation phase | First-run evidence, not outer installer identity |
| External helper or script | any phase | Opaque side effects unless independently analyzed |

Outer switches do not automatically pass through to a nested setup. If a nested candidate creates the visible ARP row, analyze that payload separately and validate the composed behavior in the VM.

## Java and .NET detection

`autodetectJava` can restrict accepted Java versions, vendor, architecture, and JRE versus JDK. `autodetectDotNetFramework` can restrict .NET Framework versions. These actions can set project variables, show dialogs, download or execute prerequisites, or abort. The parser returns their structured constraints as `RuntimeRequirements` but does not convert them directly to WinGet package dependencies.

## Upgrade installations

`installationType` and project logic can implement upgrade-only or maintenance behavior. An upgrade can find and reuse an existing installation directory or ARP key, migrate values, remove an older uninstaller, or suppress creation of a second entry. Static parsing must not invent a new ProductCode when no fresh key is proven. VM validation should compare both clean installation and upgrade from the accepted prior version when the project contains upgrade logic.

## Dynamic Tcl and external state

InstallBuilder can evaluate Tcl expressions, scripts, registry and filesystem probes, downloaded data, and external command results. Dumplings exposes exact source and known variable evidence in `DynamicProjectLogic`, but never evaluates it on the host. Review deterministic expressions manually. Validate host-dependent behavior in an isolated VM with the target state configured explicitly.

## VM evidence from current media

The current InstallBuilder 26.8.0 x64 builder installer was validated as a machine-scope package. Its visible 64-bit ARP tuple, generated uninstall command, installation directory, silent install behavior, exit code zero, silent uninstall behavior, and removal of both ARP and the installation directory matched the static projection. This validates that fixture and route; it does not eliminate the need to test custom third-party project logic.

## Source references

- [InstallBuilder running the installer](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/_running_the_installer.html)
- [InstallBuilder unattended UI](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/_user_interface.html)
- [InstallBuilder Windows behavior](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/_windows.html)
- [InstallBuilder actions](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/action.html)
