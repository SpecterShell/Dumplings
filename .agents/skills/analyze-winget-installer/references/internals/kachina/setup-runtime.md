# Kachina setup runtime

## Startup

The runtime reads embedded configuration, parses command-line arguments, chooses an online source when required, resolves the target directory, checks whether the main executable or ARP metadata indicates an existing installation, and classifies target writability as `Private`, `Writable`, or `Unwritable`. `uacStrategy` converts that state into an elevation decision before file, runtime-package, shortcut, uninstaller, and registry operations.

## Command line

| Switch | Runtime behavior | WinGet field |
| --- | --- | --- |
| `-S` | non-interactive silent installation | `InstallerSwitches.Silent` |
| `-I` | unattended installation with progress UI | `InstallerSwitches.SilentWithProgress` |
| `-D <path>` | select target directory | `InstallerSwitches.InstallLocation` |
| `-O` | force online source behavior | diagnostic and runtime evidence |
| `-U` | uninstall route | uninstaller evidence |

The parser returns `interactive`, `silent`, and `silentWithProgress` for structurally supported media. Config-only media can use the same host switches, but target version and payload success still depend on online source availability.

## Source selection and update

The runtime accepts one source URI or an ordered source catalog. A hidden source selector can choose a source ID. Embedded metadata supports offline installation; config-only media fetches release metadata and payload records. The parser returns source records but does not issue network requests.

During update, metadata hash comparisons decide which files can be retained, downloaded, patched, replaced, or deleted. `ignoreFolderPath` preserves configured directories. Metadata `deletes` removes obsolete paths. HDiff patches are recorded as potential routes, but the parser extracts complete embedded payload files only.

## Prerequisites

The `runtimes` array can request .NET or Visual C++ runtime packages. A package can embed matching installers as raw appended TLVs or download them. The runtime executes those prerequisites before finishing application setup. The parser reports configured and embedded packages separately and never copies them automatically into WinGet `Dependencies`.

## Finalization

After payload deployment the runtime creates the installed updater and uninstaller from its own executable prefix, creates shortcuts, and writes ARP state when release metadata is available. Silent mode closes the host after completion. Application launch policy and first-run effects belong to the target application and require runtime evidence.

## Scope and elevation variants

The default Program Files route is machine scope and self-elevates. For `prefer-admin` or `prefer-user`, `-D` can select a private user directory and keep the process unelevated, causing HKCU ARP registration. The same artifact therefore supports complete machine and user variants. A user variant must include both the user scope and its custom install-location choice; merely setting `Scope: user` does not change the runtime target.

## Exit and failure behavior

Malformed index, hash, decompression, source, prerequisite, and filesystem errors can terminate installation before ARP finalization. The parser does not claim nonstandard success codes without source and VM evidence for the exact generation. Config-only source failures and prerequisite installers remain external failure domains.

