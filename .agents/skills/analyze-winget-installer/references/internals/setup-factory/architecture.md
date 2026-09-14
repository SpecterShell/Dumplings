# Setup Factory architecture

## Builder, runtime, and media

Setup Factory Builder compiles product identity, destination rules, files, registry operations, shortcuts, uninstall policy, prerequisites, conditions, and runtime actions into distributable setup media. The project source is not required for static analysis because each supported generation includes a compiled project catalog.

```text
builder project
  |
  +-- serialize project metadata and policy
  +-- assign installed-file records
  +-- compress bootstrap and application payloads
  +-- include setup and uninstall runtimes
  `-- emit multi-file media or one PE overlay
       |
       `-- distributed installer
```

Version 3.1 emits a directory of related files. The 16-bit `SETUP.EXE` locates `IRDATA.IRD`, expands `IRDATA.DAT` and `IRSETUP.EXE`, and lets the runtime read the independent payload files named by the installed-file table. Versions 4-10 link a Win32 launcher and append the runtime, compiled project, resources, prerequisites, and payload streams to the PE.

## Physical and logical identity

A physical SF3.1 bootstrap member is identified by its offset and name inside `IRDATA.IRD`. A physical companion stream is identified by a filename in the media directory. The corresponding installed file is identified by the logical name in one `IRDATA.DAT` record. The media filename and installed filename are separate values.

For SF4-10, an outer catalog entry identifies bootstrap bytes such as `irsetup.dat`. Installed application payloads are described by a second generation-specific table inside `irsetup.dat` and physically follow the outer catalog and prerequisites. Outer catalog order cannot be treated as the installed file list.

## Configuration domains

| Domain | Representative evidence | Static confidence |
| --- | --- | --- |
| Format identity | launcher type, exact header, record bounds, embedded runtime | High |
| Product identity | product, version, company, and session variables | High when literal and structurally owned |
| Installed files | logical destination, source member, sizes, CRC, policy | High for supported records |
| Uninstall behavior | built-in uninstall objects and exact uninstall registry writes | High when enabled and literal |
| Scope | registry hive, install path, and compiled action roots | High when one unconditional route exists |
| Silent behavior | generation capability and modern `CProjectData` gate | High for supported routes |
| Custom actions | registry, INI, execution, service, reboot, DLL, and Lua records | High only for literal decoded operands |
| Runtime state | component selection, host values, external calls, and user input | Unresolved without scenario or VM evidence |

## Identity domains

Do not conflate the outer launcher version, embedded runtime version, project format version, application version, and uninstall key.

- SF3.1 `IRDATA.DAT` stores its project format as 3.1.0 and stores a product name, but the verified record does not contain a separate application version or publisher.
- SF4-10 outer PE version resources can be replaced by the project.
- The embedded `irsetup.exe` version is stronger release evidence but remains subordinate to structural routing.
- Product version and publisher come from generation-specific project records or session variables.
- ProductCode is the exact visible uninstall-key identity, not the builder version, setup filename, or embedded runtime name.

## Scope, registry identity, and architecture

Scope is inferred from compiled registry roots and deterministic destination policy only when they agree. A requested execution level can support the conclusion but does not replace registry evidence. HKCU and HKLM uninstall entries remain distinct. A mixed or conditional set of writes produces alternatives or unresolved scope rather than one guessed value.

Setup Factory 3.1 is a 16-bit Windows 3.x product and has no Windows Apps & Features registry contract. Its archived builder media uses a fixed absolute destination. Later setup runtimes are Win32 executables, but payload architecture must come from installed PE files rather than the setup stub.

## Execution boundaries

Static parsing stops at effects whose result depends on code or target state. The parser records the action and unresolved fields when it encounters an external DLL, child executable, runtime registry read, dynamic Lua expression, unresolved condition, or user-selected component.

No parser operation runs a setup runtime, generated uninstaller, extracted payload, prerequisite, Lua script, or child command.

## Trust boundaries

Every offset, size, count, name, path, compressed stream, and checksum comes from an untrusted file. The parser validates the complete route before returning family identity. It bounds allocations and expansion, checks CRC ownership per format, resolves extraction paths below the destination, rejects duplicates or applies the requested collision policy, and restores caller-owned stream positions.

Authenticode can establish integrity for the signed PE range but does not validate appended paths or prove installation behavior. A valid embedded runtime does not make malformed project records acceptable.
