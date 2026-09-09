# Actual Installer setup runtime

## Runtime phases

The exact internal call graph varies by generation, but published behavior and compiled metadata establish the following logical phases.

```text
startup
  |
  +-- initialize and validate setup media
  +-- parse command line and setup parameters
  +-- select language
  +-- evaluate operating-system, architecture, disk, network, and prerequisite requirements
  +-- choose install level and obtain elevation when required
  +-- resolve variables and installation directory
  +-- detect existing Product GUID and choose clean/update behavior
  +-- present or skip configured interface pages
  +-- materialize selected file records
  +-- apply registry, association, shortcut, and command records
  +-- create uninstaller and Apps & Features state when enabled
  `-- report success, cancellation, warning, or failure exit code
```

A static table record proves configuration intent, not unconditional reachability. Requirements, custom variables, silent policy, existing-version checks, user choices, update mode, and HALT operations can terminate the runtime before later records execute.

## Installation levels

Current media serializes `InstallLevel` in `[Setup]`.

| Value | Supported scopes | Default scope | Scope command line |
| --- | --- | --- | --- |
| `0` | current user | user | none needed |
| `1` | all users | machine | none needed |
| `2` | user and machine | machine | `/CU` for user; `/RUNAS /ALL` for machine |
| `3` | user and machine | user | `/CU` for user; `/RUNAS /ALL` for machine |

The parser returns no single `Scope` for values 2 and 3. It exposes both `SupportedScopes`, a `DefaultScope`, and the documented scope switches. A scope override is valid only when the compiled policy permits that route. A machine-only 8.0 builder setup remained machine scope when tested with `/CU`.

Historical media without `InstallLevel` uses administrator-related configuration plus the PE requested-execution level. This is weaker than an explicit current-generation policy and should not be generalized to unverified releases.

## Elevation and token behavior

`/RUNAS` launches the setup as administrator. `/ALL` selects all-users installation; it does not independently prove that the current process already has the required token. Current "Modern" interface configurations can defer elevation until the Install action, which permits the runtime to preserve the original interactive user's identity for selected HKCU operations.

The PE requested-execution level is useful evidence, but it is not identical to WinGet scope. A dual-scope setup can begin unelevated, select machine scope, and then elevate. Conversely, a setup compiled to run as administrator can still contain explicit HKCU records whose target identity depends on the launch route.

## Registry redirection behavior

Published runtime behavior adds two important qualifications to literal registry roots.

- HKCU normally refers to the account represented by the active token. If setup is launched elevated, that can be the administrator account. Current Modern-interface split elevation can retain the original user when all-users or ask-user policy is configured and "Run as administrator" is not preselected.
- An unelevated write authored for HKLM can be redirected to HKCU. The `-noChangeRootKey` setup parameter disables this fallback and can expose access-denied failures. `-IgnoreRegistryWriteErrors` suppresses registry-write error messages.

The parser does not emulate token splitting. It preserves explicit roots, resolves `HKDE` from the compiled default scope, and reports recognized setup-parameter policy such as root fallback and ignored write errors. VM validation is required when final hive identity affects ARP or association matching.

## Architecture and registry view

Actual Installer documentation ties the generated setup bitness to the required operating-system architecture. A 64-bit-only project can produce a native 64-bit setup that uses 64-bit Program Files and registry view. Other projects commonly use a 32-bit runtime and 32-bit registry view, including WOW6432Node on 64-bit Windows.

The parser interprets the older Boolean `x64`/`64-bit` keys and the builder's `SystemType` enum. Value `0` is the `32 & 64 bit` option and uses 32-bit filesystem and registry layout, value `1` is `64-bit only`, and value `2` is `32-bit only`. A controlled 9.6 runtime reads `SystemType` as an integer, then uses `dec eax` and `setz` to set its 64-bit-layout flag only when the parsed value equals `1`. This confirms the 32-bit layout for the known values `0` and `2`. Unknown values remain unresolved because a future runtime could add another enum member. Through builder 9.8, even the 64-bit-only route can use an x86 setup stub that disables WOW64 redirection at runtime; version 10.0 and later can emit a native x64 stub. Media without an architecture key falls back to native setup PE bitness. PE machine type, setup runtime bitness, required OS architecture, registry view, and every payload binary's architecture remain separate facts.

## Documented setup switches

Setup switches are case-insensitive. Paths containing spaces require quoting.

| Switch | Runtime behavior | Parser or authoring consequence |
| --- | --- | --- |
| `/S` | Silent installation | Exposed as the silent switch |
| `/N` | Skip system requirement and prerequisite checks | Risky override; not suggested as a normal manifest switch |
| `/D "path"` | Set destination folder | Exposed as install-location switch |
| `/DFC` | Prevent destination changes | Policy switch, not required for ordinary unattended install |
| `/L` | Write errors to `%TEMP%\AISETUPLOG.TXT` | Fixed log destination, not a WinGet log-template switch |
| `/LNG "language"` | Select an included setup language | Artifact-specific; not projected without locale evidence |
| `/X "text"` | Populate `<ExtraVar>` | Custom project input, not a family default |
| `/RUNAS` | Relaunch as administrator | Used with supported machine-scope route |
| `/ALL` | Select all users | Used with `/RUNAS` for supported machine-scope route |
| `/CU` | Select current user | Used only when the compiled install level permits user scope |

The setup filename can also populate `<ExtraVar>` from text after `_` or `-` unless disabled by a setup parameter. This means renaming a setup can change project logic. The parser does not derive metadata from this runtime value.

The generated uninstaller accepts `/S` for silent removal. VM-observed built-in registrations store the generated path without quotes in `UninstallString` and omit `QuietUninstallString`; `UninstallerCommandEvidence` preserves that ARP value and separately provides a quoted silent invocation. Literal custom ARP writes remain authoritative when they explicitly provide either command.

## Success and exit codes

The setup runtime documents the following process exit codes. They are runtime protocol, not all automatic WinGet manifest recommendations.

| Code | Meaning |
| ---: | --- |
| `0` | Installation completed successfully |
| `1` | Setup media is corrupt |
| `2` | Original process closed after starting an elevated child |
| `3` | Custom setup font registration failed |
| `4` | Language file is missing |
| `5` | A prerequisite was not installed |
| `6` | Insufficient disk space |
| `7` | Required network access failed |
| `8` | User cancelled while handling a running application |
| `9` | Installation failed, including access-denied cases |
| `10` | Noncritical warning, such as a shortcut failure |
| `11` | User cancelled before installation |
| `12` | Update-only setup found no installed target |
| `14` | Installed target version is outside the update package range |
| `15` | A custom-variable `HALT()` stopped setup |
| `16` | A command `HALT()` stopped setup |
| `17` | A newer version is already installed |
| `18` | External data file for "Setup EXE + Data" is missing |
| `19` | Pre-install update check found a newer release and halt-on-new-version was enabled |
| `21` | Temporary directory creation failed |
| `22` | Temporary ZIP creation failed |
| `23` | Temporary payload extraction failed |
| `24` | 64-bit Windows is required |
| `25` | 32-bit Windows is required |
| `26` | Windows version is unsupported |
| `27` | Silent installation is prohibited by setup parameters |
| `28` | Installation directory is empty |
| `29` | Required custom components are unselected |
| `99` | Setup initialization failed |
| `100` | Setup file could not be opened due to access denial |

The parser returns the complete documented table as `ExitCodeEvidence` and leaves `InstallerSuccessCodes` empty because code 0 is the ordinary WinGet success default. This evidence is for diagnosis and manifest authoring review; do not copy the complete runtime table into every manifest.

## Update mode

Existing-product detection searches uninstall keys for the configured application GUID in HKCU and HKLM. The project can uninstall, uninstall silently, update in place, allow side-by-side versions, or ask the user. In update mode, the destination cannot be changed. If the GUID is absent because uninstaller or Programs and Features registration is disabled, the update setup falls back to a clean installation path.

An update installer can invoke the installed uninstaller and wait. Static outer-setup switches do not establish the exact child uninstaller command or its behavior.

## Online and external-data media

Variables and commands can fetch network content. Current online builder media can leave `AppVersion=<V>` and obtain the final value at runtime. The parser decodes recognized `DOWNLOAD:`, `GETURL`, and `GETFILE` sources into `MediaInfo` and `ExternalPayloads`, reports the dynamic field, and does not fetch its source.

The "Setup EXE + Data" mode stores application source content beside the setup in a separate 7z/LZMA data file. That path differs from embedded numbered ZIP media. The parser reports the compiled companion `DataFileName`; `Get-ActualInstallerInfo -CompanionFile` validates the filename, declared size, archive type, paths, links, encryption, duplicates, and expansion bounds, then uses its catalog for main-executable architecture and dependency analysis. `Expand-ActualInstallerInstaller` expands the same explicit local file without searching for or downloading media. Exit code 18 is the runtime's missing-data result.

## Silent-install validation boundary

`/S` proves a documented silent route, but project policy can still reject it with code 27, requirements can stop it, a prerequisite can fail, or custom commands can display UI. Package authoring should validate the concrete setup in a checkpointed VM when such records are present.

## Source references

- [Actual Installer command-line parameters and exit codes](https://www.actualinstaller.com/help/command-line.html)
- [Actual Installer registry behavior](https://www.actualinstaller.com/help/registry.html)
- [Actual Installer update installers](https://www.actualinstaller.com/articles/how-to-create-update-installer.html)
