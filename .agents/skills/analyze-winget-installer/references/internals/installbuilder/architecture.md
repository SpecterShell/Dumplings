# InstallBuilder architecture

## Builder, launcher, and installed application

InstallBuilder is a cross-platform installer builder. A Windows output contains a native launcher and a serialized project, but the files installed by that launcher may be native Windows binaries, Java applications, .NET applications, scripts, or nested installers. The launcher architecture and branding identify the setup runtime, not necessarily the installed application.

```text
builder project
+-- project XML
+-- source directory trees
+-- optional runtime and prerequisite inputs
`-- platform-specific build settings
              |
              v
Windows setup executable
+-- launcher and Tcl runtime
+-- compiled project in Metakit
+-- application payload in Metakit or CookFS
`-- optional signature and project-specific resources
              |
              v
installed state
+-- selected files and generated uninstaller
+-- built-in or custom ARP registration
+-- registry and file associations
+-- shortcuts and persistent system effects
`-- effects of scripts, downloads, and child processes
```

The parser reads the setup executable as data. It does not load the PE, mount TclKit, execute Tcl, invoke the installer, or run extracted children.

## Product lineage and editions

The Windows family has appeared as BitRock InstallBuilder, VMware InstallBuilder, InstallBuilder, and Backstaff InstallBuilder. Professional, Enterprise, Qt, and other builder editions can emit the same physical routes. Branding and edition strings are evidence about the producer, not dispatch keys.

Third-party packages often replace outer PE version resources with application identity. Some builder installers retain a producer version, but that value can differ from the runtime template or project schema. Report each identity separately when available:

| Identity | Typical source | Meaning |
| --- | --- | --- |
| Package identity | `shortName`, `fullName`, `version`, and `vendor` in `project.xml` | Product being installed |
| Project schema | `projectSchemaVersion` | XML vocabulary expected by the builder project |
| Launcher identity | PE version resource and machine type | Compiled setup stub, which projects may customize |
| Structural generation | Metakit-only or CookFS2 records | Parser route selected from bytes |
| Product branding | Builder strings, runtime files, and project content | Secondary producer evidence |

Do not infer an exact builder patch version from the package version, schema value, or one marketing name.

## Physical identity and logical identity

Metakit and CookFS use several independent namespaces. A physical VFS record may be a builder runtime file rather than installed payload. A CookFS path may encode component and folder identifiers that differ from the final installation path. The project maps those records to destinations.

| Layer | Identity example | Use |
| --- | --- | --- |
| Metakit database | `HeaderOffset`, `Distance`, root descriptor | Owns one virtual filesystem |
| Metakit VFS path | `project.xml`, `origindist`, `dist/...` | Selects project and legacy payload records |
| CookFS physical path | component/folder-relative storage path | Locates page-backed bytes |
| Project folder | component name, folder name, destination | Maps physical records to installed paths |
| Installed path | `%ProgramFiles%\Vendor\Product\app.exe` | Architecture, dependency, shortcut, and manifest evidence |

Required-entry ownership prevents a second embedded TclKit or runtime database from being mistaken for the package project.

## Configuration domains

`project.xml` mixes fields with different evaluation times. Treating them as one flat dictionary causes incorrect metadata.

| Domain | Examples | Static treatment |
| --- | --- | --- |
| Identity | `fullName`, `version`, `vendor` | Resolve deterministic substitutions; null unresolved values |
| Project defaults | `createUninstaller`, `createWindowsARPEntry`, `requestedExecutionLevel` | Apply documented defaults when omitted |
| Parameters | `directoryParameter`, `cliOptionName`, configured value/default | Use configured default evidence and retain runtime mutability |
| Components and folders | selection, platform list, destination, rules | Three-valued default-selection projection |
| Actions | registry, execution, services, environment, ACL, associations | Preserve phase, order, conditions, and scalar arguments |
| Runtime state | host files, registry, Windows version, user input, script output | Return unknown unless explicitly supplied by trusted evidence |

## Execution boundaries

InstallBuilder can run programs during initialization, installation, presentation, rollback, and uninstallation. Only successful installation phases can own persistent installed-state evidence. A final-page `runProgram` normally launches the application after setup and cannot by itself replace the outer installer ProductCode. A persistent installation-time child installer may own ARP, dependencies, switches, or additional files and must be analyzed separately.

```text
outer InstallBuilder process
+-- evaluates project parameters and rules
+-- extracts selected payload files
+-- creates uninstaller and optional built-in ARP row
+-- applies persistent actions
+-- may execute nested installer or prerequisite
`-- may launch application on the final page

physical containment does not imply ARP ownership
```

`NestedInstallerCandidates` contains embedded installer-like programs called from installation phases. `ExecutedPayloads` retains all payload-owned executions. Presentation launches remain separate evidence.

## Scope, elevation, registry view, and architecture

These concepts are independent:

| Concept | Main evidence |
| --- | --- |
| Package scope | built-in HKLM ARP route, explicit HKLM/HKCU actions, `requireInstallationByRootUser`, and requested execution level |
| Shortcut scope | `installationScope` |
| Registry view | native launcher bitness or `windows64bitMode` |
| Installed architecture | extracted source-referenced application executables and adjacent dependencies |
| Elevation behavior | PE manifest and `requireInstallationByRootUser` |

An x86 launcher can install x64 files and write the 64-bit registry view when `windows64bitMode` is enabled. Native x64 Windows runtimes appeared in InstallBuilder 19.5, but this historical boundary does not prove the architecture of every later package.

## Trust boundaries

All offsets, counts, paths, sizes, compression records, hashes, XML nodes, actions, and expressions are untrusted installer input. Validate them before allocating memory or writing files. Keep the following data outside automatic evaluation:

- Tcl source, TclPro bytecode, and custom expressions.
- External program, DLL, script, and downloaded-resource behavior.
- Passwords and password-derived payload keys.
- Target-machine registry, filesystem, service, and Windows-version state.
- Project variables whose final value depends on command-line input or UI.

The parser may return exact source and known variable values for an agent to inspect. It must not evaluate that source on the host.

## Source references

- [InstallBuilder project settings](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/project.html)
- [InstallBuilder variables](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/variables.html)
- [InstallBuilder actions](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/action.html)
- [InstallBuilder Windows behavior](https://releases.installbuilder.com/installbuilder/docs/installbuilder-userguide/_windows.html)
- [InstallBuilder changelog](https://installbuilder.com/changelog)
