# Inno Setup runtime

This page follows the setup engine from process startup through installation completion. It describes current official behavior. Historical installers can omit newer phases or directives.

## Process startup

`Setup.Start.Start` performs common process initialization, chooses Setup/Uninstaller/RegSvr mode, initializes setup state, creates the main form and wizard, runs the application loop, deinitializes, and exits with `SetupExitCode`.

In normal loader-based setup mode:

```text
SetupLdr
`-- extracts temporary setup engine
    `-- starts it with /SL5=
        +-- setup engine opens original Setup.exe
        +-- reads setup-0 at passed Offset0
        `-- reads payload at passed Offset1
```

Without `/SL5=`, the setup engine looks for `<base>-0.bin` beside itself.

## Command-line processing

SetupLdr handles a small early subset so errors and language selection can occur before the setup engine is restored. The setup engine parses the full command line.

Important public switches include:

| Area | Switches |
| --- | --- |
| UI | `/SILENT`, `/VERYSILENT`, `/SUPPRESSMSGBOXES`, `/NOCANCEL`, `/NOSTYLE` |
| restart | `/NORESTART`, `/RESTARTEXITCODE=` |
| location | `/DIR=`, `/GROUP=`, `/NOICONS` |
| selection | `/LANG=`, `/TYPE=`, `/COMPONENTS=`, `/TASKS=`, `/MERGETASKS=` |
| saved answers | `/LOADINF=`, `/SAVEINF=` |
| scope override | `/CURRENTUSER`, `/ALLUSERS` |
| password | `/PASSWORD=` |
| logging | `/LOG`, `/LOG=` |
| application handling | `/CLOSEAPPLICATIONS`, `/NOCLOSEAPPLICATIONS`, `/FORCECLOSEAPPLICATIONS`, `/RESTARTAPPLICATIONS` and inverse forms |

`/SUPPRESSMSGBOXES` becomes active only with silent or very-silent mode. Silent mode still displays the progress wizard; very-silent mode hides it. Entry flags can distinguish normal and silent execution.

Internal switches such as `/SL5=`, `/SPAWNWND=`, `/FIRSTWND=`, and debugger parameters are removed from the parameter list exposed to Pascal Script.

An INF file is loaded after basic command-line parsing. It can provide wizard selections, while explicit parameters and runtime logic still affect final state.

## Reading setup-0

Initialization opens setup-0, then:

1. compares the full 64-byte `SetupID`;
2. reads and CRC-checks the encryption header;
3. derives/tests the password key when metadata is fully encrypted;
4. opens compressed block 1;
5. reads `TSetupHeader` and each counted entry table in compiler order;
6. activates the language and appearance resources;
7. determines 64-bit install mode;
8. resolves privilege override behavior and elevation;
9. loads compiled Pascal Script;
10. initializes previous data, wizard defaults, and runtime services.

File-location records are read through the file extractor from the second metadata block when payload access is initialized.

## Language selection

SetupLdr and Setup both determine the active language. Inputs include:

- `/LANG=`;
- compiled language-detection method;
- user UI language or locale;
- previous installation language when enabled;
- language-dialog selection.

The active `TSetupLanguageEntry` supplies messages, fonts, directionality, and language-specific license/information text. The selected internal language name is later stored under `Inno Setup: Language` in the uninstall key.

## Architecture admission and 64-bit install mode

`ArchitecturesAllowed` is evaluated against the current machine. A false result rejects setup before installation.

`ArchitecturesInstallIn64BitMode` is evaluated separately. If true, Setup enables 64-bit install mode, which changes:

- default Program Files and Common Files constants;
- default registry view;
- system-directory redirection behavior;
- the 32/64-bit uninstaller-log identity;
- per-entry `install default` bitness.

An expression that asks for 64-bit install mode on a 32-bit system is treated as an internal script error.

## Privilege mode and elevation

`PrivilegesRequired` has four persisted values:

| Value | Runtime intent |
| --- | --- |
| `none` | Do not request administrative privileges. |
| `lowest` | Use the current non-administrative user context. |
| `poweruser` | Historical elevated/power-user behavior. |
| `admin` | Require administrative mode. |

`PrivilegesRequiredOverridesAllowed` can enable command-line and/or dialog overrides.

### Command-line override

When command-line override is enabled:

- `/ALLUSERS` sets effective `PrivilegesRequired` to `admin`;
- `/CURRENTUSER` sets it to `lowest`.

If override support is absent, those switches do not provide a valid scope route.

### Dialog and previous-scope behavior

Dialog override can inspect existing uninstall keys in HKLM and HKCU when `UsePreviousPrivileges=yes`. If only one existing scope is found, Setup prefers it. Otherwise it can ask the user for all-users or current-user installation.

When message boxes are suppressed and no previous choice is available, Setup keeps the compiled privilege setting rather than inventing a dialog choice.

### Respawn

After effective privilege mode is known, Setup decides whether it must respawn elevated. The elevated process receives public arguments and internal spawn-channel parameters. The original process supplies services for actions requested to run as the original user.

This means scope cannot always be inferred from the initial process token or outer PE manifest.

## Constants and initial wizard state

Once scope, architecture mode, language, and source paths are available, Setup can expand constants such as `{app}`, `{win}`, `{sys}`, `{pf}`, `{autopf}`, `{userappdata}`, and `{commonappdata}`.

It then constructs initial wizard values from:

- compiled defaults;
- previous uninstall-key data;
- command-line values;
- loaded INF values;
- Pascal Script callbacks;
- environment and shell-folder state.

`DefaultDirName` is therefore the default expression, not necessarily the directory finally used.

## Pascal Script initialization

If `CompiledCodeText` is present, Setup creates the script runtime, registers built-in functions/classes, loads the bytecode, and invokes setup events. Important early events include:

- `InitializeSetup`, which can abort setup by returning false;
- `CheckPassword`;
- `InitializeWizard`;
- wizard navigation and custom-page events;
- `PrepareToInstall`;
- `CurStepChanged`.

Script code can read parameters, registry, files, environment, wizard state, and architecture. It can write files, registry and INI values, execute programs, load DLLs, and alter selections. Serialized declarative records are not a complete behavioral description when code exists.

## Entry filtering

`ShouldProcessEntry` evaluates entry selectors in this order:

1. component expression against selected components;
2. task expression against selected tasks;
3. language expression against the active language;
4. `Check` Pascal Script expression/function, only if prior selectors passed.

Version bounds are checked by the relevant entry-processing path. A `Check` exception is handled and the entry is skipped rather than crashing the complete setup in the normal filter path.

File records also respect `dontcopy`; run records respect `skipifsilent` and `skipifnotsilent`; icon records include no-icons behavior.

`BeforeInstall` and `AfterInstall` callbacks execute around the associated action. Their side effects are arbitrary Pascal Script behavior.

## Types, components, and tasks

The wizard selects a setup type, which establishes an initial component set. Components can be nested, fixed, exclusive, or inherited. Tasks form a separate optional tree.

Command-line selection behavior differs:

- `/COMPONENTS=` provides the component list;
- `/TASKS=` begins from a deselected task set and selects the named tasks;
- `/MERGETASKS=` modifies the existing/default task selection, including negated tasks.

Record selectors use the final chosen lists, not merely the strings from the command line.

## Installation transaction

`PerformInstall` builds an in-memory uninstall log while applying changes. Current high-level order is:

```text
freeze expanded AppId and Uninstallable result
initialize uninstall log
record install start and compiled code
process components
process tasks
close/restart-manager applications when selected
process [InstallDelete]
record mutex and association-refresh behavior
record [UninstallDelete]
create application and [Dirs] directories
reserve/generate uninstall filenames
copy and extract [Files]
create [Icons]
apply [INI]
apply [Registry]
evaluate NeedRestart
register COM/type-library/GAC files
finalize uninstaller executable and message file
conditionally create ARP key
record [UninstallRun]
save uninstall log
```

`[Run]` entries are handled by the surrounding wizard/install-step flow, including post-install entries and silent filters.

Setup changes the current directory to the Windows system directory before installation so child behavior does not depend on an untrusted launch directory.

## Uninstall logging and rollback

Each reversible action adds an uninstall-log record before or as the action is applied. Records cover files, directories, registry, INI, icons, shared-file counts, services/registration-related effects, environment/association refresh, mutex checks, script code, and explicit uninstall run/delete entries.

If installation fails or is cancelled after changes begin, Setup:

1. sets an error/cancellation exit code;
2. deletes incomplete uninstall files;
3. calls the uninstall-log engine in rollback mode;
4. replays recorded inverse operations;
5. leaves warnings for changes that could not be reversed.

Actions performed by arbitrary Pascal Script or external programs are reversible only when the script explicitly records or reverses them through supported mechanisms.

## Reboot handling

Restart state can come from:

- delayed file replacement/deletion;
- component/task restart flags;
- `AlwaysRestart`;
- `RestartIfNeededByRun`;
- `NeedRestart` Pascal Script event;
- uninstall-log replay.

`/NORESTART` prevents automatic reboot but does not erase the fact that restart is required. `/RESTARTEXITCODE=` can substitute a caller-selected success/restart code.

## Setup exit codes

Current built-in nonzero setup codes are:

| Code | Meaning |
| ---: | --- |
| 1 | Initialization error |
| 2 | Cancelled before installation began |
| 3 | Fatal error while moving to the next wizard step |
| 4 | Fatal installation error |
| 5 | Cancelled during installation or abort selected in an error dialog |
| 6 | Killed by the debugger |
| 7 | `PrepareToInstall` failed without restart needed |
| 8 | `PrepareToInstall` failed and restart is needed |

Successful setup normally returns zero. Pascal Script can supply a custom setup exit code through `GetCustomSetupExitCode`. Restart configuration can also alter the returned code.

## Silent installation is still the same engine

Silent and very-silent modes do not bypass setup records, Pascal Script, prerequisite checks, privilege respawn, or rollback. They change presentation and entry filters. A package can reject silent mode in code, require a dialog not covered by suppression, or launch a child installer whose switches differ.

The default `/SILENT` and `/VERYSILENT` support is therefore format capability, not proof that a particular package completes unattended.

## Source references

- [Setup.Start.pas](https://github.com/jrsoftware/issrc/blob/main/Projects/Src/Setup.Start.pas)
- [Setup.MainFunc.pas](https://github.com/jrsoftware/issrc/blob/main/Projects/Src/Setup.MainFunc.pas)
- [Setup.WizardForm.pas](https://github.com/jrsoftware/issrc/blob/main/Projects/Src/Setup.WizardForm.pas)
- [Setup.Install.pas](https://github.com/jrsoftware/issrc/blob/main/Projects/Src/Setup.Install.pas)
