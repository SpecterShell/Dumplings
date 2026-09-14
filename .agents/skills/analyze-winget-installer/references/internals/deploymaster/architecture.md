# DeployMaster architecture

## Producer pipeline

DeployMaster Builder compiles a `.deploy` project into a native setup stub, one or two architecture-specific runtime cores, declarative metadata, auxiliary resources, application payloads, and generated uninstaller templates. The project file is authoring input and is not required by the installed setup. Runtime behavior must therefore be recovered from the compiled package structures rather than inferred from builder UI labels or the packaged application's PE version.

```text
.deploy project
+-- package identity and destinations
+-- application files and components
+-- registry, file-type, shortcut, and completion operations
+-- prerequisites and update policy
+-- scope, platform, portable, and expiration settings
`-- optional support DLLs
        |
DeployMaster Builder
        |
        `-- setup.exe
            +-- native launcher
            +-- architecture-selected setup runtime core
            +-- compiled metadata and payload catalog
            +-- application payloads
            `-- generated UnDeploy template(s)
```

## Runtime layers

The outer setup stub locates and validates the package, selects a runtime core, evaluates scope and architecture, reads the compiled records, installs files, applies system operations, launches configured prerequisites or completion programs, and registers the generated uninstaller. The uninstaller later replays `Deploy.log`; it does not reconstruct the project from the original setup.

```text
outer setup stub
+-- package locator or classic overlay discovery
+-- runtime-core selection and decompression
+-- command-line and elevation routing
+-- metadata interpreter
+-- payload extraction
+-- registry, shortcut, association, and prerequisite actions
`-- Deploy.log creation and ARP registration

installed state
+-- application files
+-- UnDeploy.exe or UnDeploy64.exe
+-- Deploy.log or an indexed DeployN.log
+-- built-in and explicit registry writes
`-- optional effects from support DLLs and child installers
```

## Physical families

Classic 2.5.x media stores a BZip2 runtime followed by length-prefixed zlib records directly in the PE overlay. Locator-based 6.x and later media stores a fixed locator at absolute file offset `0x80`, raw-LZMA runtime cores and data blocks, parallel payload tables, and a logical file length that may precede an Authenticode certificate table. DeployMaster 3.x through 5.x remains unclassified because no durable fixture establishes either grammar.

The runtime-core architecture and the application architecture are separate. A 32-bit launcher can install an x64 application, while mixed media contains both x86 and x64 runtime and payload routes. The parser reports `InstallerArchitecture`, `ApplicationArchitectureMode`, `ApplicationArchitectures`, and per-file applicability independently.

## Identity domains

| Identity | Source | Purpose |
| --- | --- | --- |
| Runtime identity | outer PE product name, comments, and extracted core | family confirmation and optional feature inspection |
| Package identity | compiled form-feed identity record | display metadata, destinations, release date, URLs, and built-in ProductCode |
| Payload identity | file catalog and selectively inspected binaries | installed architecture and dependency evidence |
| ARP identity | built-in display-name key plus explicit Registry-tab writes | WinGet installed-package matching |
| Deployment identity | `Software\JGsoft\DeployIT` and `Deploy.log` | maintenance and uninstaller state |

The outer PE version is frequently the packaged application's version. It must not select a DeployMaster structural profile or be treated as the builder version.

## Trust boundaries

The installer is untrusted binary input. Every offset, count, size, compressed range, checksum, file index, text encoding, destination, and recursive record is validated before allocation or extraction. A valid locator CRC authenticates only its declared package-control range; catalogued payloads retain separate size and CRC checks, and Authenticode remains an independent envelope.

Support DLLs, prerequisite installers, completion programs, and pre-uninstall programs cross the declarative boundary. Their presence and exact file indexes are reportable, but their side effects require separate static analysis or checkpointed VM validation. The parser never loads a support DLL or executes any extracted file.
