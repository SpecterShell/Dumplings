# Actual Installer architecture

## Builder, runtime, and media

Actual Installer Builder authors project state and compiles it into a native setup runtime plus data containers. Distributed setup media does not expose the builder project as a typed object model. The stable static boundary is the embedded INI and the archive catalog around it.

```text
builder project
  |
  +-- compile identity, policy, and operations
  +-- assign numeric logical file indexes
  +-- compress application payloads
  +-- include language and helper resources
  `-- link native setup runtime
       |
       `-- distributed PE with appended containers
```

The setup runtime reads `setup.ini` or `aisetup.ini`, resolves variables, checks requirements, chooses scope and destination, materializes payload files, applies system effects, invokes configured commands, and creates uninstall state. Some values are fixed at build time; others come from launch context, user choices, the registry, INI files, text files, network requests, or external commands.

## Physical and logical identity

A physical container is identified by an absolute offset and validated length. A physical entry is identified inside that container by its archive name. A logical installed file is identified by a numeric `[Files]` key and a destination expression. These identities happen to align differently by route.

```text
Cabinet3/4/5
[Files] row order N -> Nth payload CAB -> first CFFILE entry

Zip6Plus
[Files] numeric key N -> ZIP entry whose leaf name is decimal N
```

The parser never treats a filename in a metadata archive as an installed payload merely because it resembles a product file. Language resources and helper executables belong to the metadata container until a structured record maps them into installed state or a route capability is backed by installed-file equality evidence. The latter currently applies only to Cabinet5 and numbered-ZIP generated uninstallers.

## Configuration domains

The compiled configuration contains several independent evidence domains.

| Domain | Representative fields | Static confidence |
| --- | --- | --- |
| Package identity | `AppName`, `AppVersion`, `CompanyName`, GUID | High when literal |
| Builder identity | `AIVer` or equivalent version field | Compatibility evidence only |
| Scope and elevation | `InstallLevel`, administrator flags, PE manifest | High for fixed policies; conditional for dual scope |
| Paths | installation directory, alternate directory, main executable, uninstaller | High after deterministic variable resolution |
| Payload catalog | numeric file rows and archive entries | High for directly mapped entries |
| Built-in uninstall | enablement, visibility, GUID, display metadata | High for supported GUID generations |
| Custom system effects | registry, extensions, shortcuts, commands | High only for literal decoded records |
| Runtime requirements | operating system, architecture, prerequisites, network, running applications, and installed-version bounds | Decoded where represented by supported setup keys |
| Dynamic values | registry/INI/network lookups, `<V>`, custom variables | Unresolved without runtime evidence |

## Identity domains

Do not conflate the setup runtime version, builder version, application version, Product GUID, and uninstall key.

- The PE file version can describe the setup engine or builder package.
- `AIVer` identifies the builder/compiler generation when present.
- `AppVersion` describes the installed application only when it is literal.
- The Product GUID identifies modern built-in Apps & Features registration and update relationships.
- Legacy media can register an uninstall entry without exposing a GUID in the parsed configuration.
- An explicit custom `[Registry]` record can create another uninstall key unrelated to the built-in Product GUID.

An online setup can therefore have a valid builder version and Product GUID while leaving the final application version unresolved.

## Scope, registry identity, and elevation

Scope policy, registry hive, registry view, and process elevation are separate axes. `InstallLevel` can permit one scope or a user-selectable pair. The selected scope chooses the ordinary built-in uninstall hive. The x64-compliance setting chooses Program Files and registry view. The PE execution level describes launch behavior, not necessarily the final target scope in a split-elevation route.

Actual Installer documentation describes additional registry redirection behavior. In particular, an unelevated write targeting HKLM can be redirected by installer policy, and an elevated process can otherwise represent the elevated account rather than the original interactive user. The runtime provides options for scope-aware or original-user behavior in current generations. The current parser preserves literal roots and resolves `HKDE` from the compiled default scope, but it does not simulate every split-token registry rule. VM evidence remains required where authored records and launch identity interact.

## Execution boundaries

Static parsing stops at external behavior. The following records are evidence that further work is required, not proof of the child effect:

- A command that starts another installer or application.
- A variable populated from the registry, a file, an INI value, a URL, or a downloaded file.
- A helper whose installed bytes differ from the source helper or have not been compared for the selected route.
- An external setup-data archive not embedded in the PE.
- A custom registry expression containing unresolved variables.

No parser operation executes the setup, an extracted payload, a generated uninstaller, or a configured command.

## Trust boundaries

All offsets and sizes originate in an untrusted executable. CAB headers, ZIP central directories, INI lengths, table counts, destination paths, and expanded sizes require independent bounds. Authenticode establishes signer integrity for signed bytes but does not make archive paths safe. A structurally valid archive does not prove that its entries represent installed files. A valid configuration does not prove that all conditional operations run.

## Source references

- [Actual Installer variables](https://www.actualinstaller.com/help/installer-variables.html)
- [Actual Installer files and folders](https://www.actualinstaller.com/help/files-and-folders.html)
- [Actual Installer registry behavior](https://www.actualinstaller.com/help/registry.html)
