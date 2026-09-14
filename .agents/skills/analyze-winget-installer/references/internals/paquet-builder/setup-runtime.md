# Paquet Builder setup runtime

## Runtime phases

The exact engine differs by structural route, but verified packages follow the same broad sequence: initialize system and package variables, check privilege and existing-version conditions, collect dialog values, establish `DESTPATH`, extract or copy payload files, apply package operations, prepare uninstaller state, and optionally launch an application.

GINFOS preserves branch and label commands without pretending to execute them. Modern packages expose only bounded literal native call-site evidence. Static output therefore describes possible operations; a conditional package still needs VM evidence for the selected path.

## Scope and elevation

Scope uses explicit evidence in this order: one literal `PBINSTALLSCOPE`, a unique ARP registry hive, `requireAdministrator`, nested MSI scope, or Classic machine-state writes. HKCU ARP proves user scope and HKLM ARP proves machine scope. A `requireAdministrator` manifest proves that the wrapper requires elevation but does not resolve a package that also contains distinct user and machine destination branches.

Classic 2.6 predates modern requested-execution-level manifests. Its verified complete controller writes files under Windows directories and values under HKLM, which proves machine scope. The incomplete Classic capture cannot supply that package catalog and remains unresolved.

## Silent installation

WinGet has no built-in Paquet Builder switches. The published modern package syntax uses `/s`, but the parser suggests it only for Split3 artifacts with literal enabled `SILENT=1` call-site evidence. Historical 2.x GINFOS fixtures do not expose a source-backed command-line switch table, so their static result remains interactive-only and emits a manual-validation diagnostic.

```yaml
InstallerType: exe
InstallModes:
- interactive
- silent
InstallerSwitches:
  Silent: /s
```

Do not infer `/s` from family detection, PE strings, or a newer builder's documentation. Test the exact artifact in a VM when static evidence does not enable the mode.

## Exit codes

Published package exit codes are `0` for success, `1` for decompression failure, `2` for cancellation, and `3` for an unexpected fatal error. None is an additional success code. A nested MSI can return its own process result through wrapper variables or helper calls, and that behavior requires testing when the wrapper's translation is not explicit.

## Nested execution

`EXEC`, `EXECUTE`, and `EXECWAIT` records expose a path, argument string, remaining options, raw argument text, and source line. `CALLDLL` is opaque unless the first argument names the verified `PBExecMSI` helper. In that case, a `%DESTPATH%`-relative MSI path can select the sole matching archive entry for MSI parsing.

An MSI uninstall command such as `msiexec /X{GUID}` is execution evidence for maintenance of an older package, not proof that the current package is an MSI wrapper. Selection depends on an install action naming the archive entry.

## File and uninstaller operations

The GINFOS model exposes `SHORTCUT`, `CREATEFOLDER`, `COPY`, `DELETE`, `DELFOLDER`, `WRITEF`, and `ADDUNCOM` records without executing them. `ADDUNCOM` describes work written into the generated uninstaller. `AUTOSC` and unsupported control-flow mechanics remain raw commands and produce a structured diagnostic.

## VM validation

Use the shared VM workflow without restoring or restarting a VM that another task is using. Validate scope-specific ARP hives, registry view, final destination, generated uninstaller, exact silent switch, wrapper exit code, and nested process behavior. Compare static registry values after variable expansion rather than comparing unresolved script expressions directly.
