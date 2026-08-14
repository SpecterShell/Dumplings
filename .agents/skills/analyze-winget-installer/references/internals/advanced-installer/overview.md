# Advanced Installer internals

Advanced Installer is an authoring system that emits several unrelated Windows package forms. A project can produce a direct MSI, an MSI with external cabinets, an EXE bootstrapper around an MSI or MSIX, a web bootstrapper, a prerequisite launcher, or a Suite Installer MSI. The output type determines which runtime owns package selection, command-line handling, and Apps & Features registration.

Use the [Advanced Installer workflow](../../families/advanced-installer/workflow.md) for WinGet authoring. This directory describes the build output and runtime that the parser reconstructs.

## Reading path

1. [Architecture](architecture.md) separates the project, compiler, bootstrapper, nested package, and installed-state layers.
2. [Compiler and output](compiler-and-output.md) follows an `.aip` project into MSI, EXE, web, and external-resource media.
3. [Binary format](binary-format.md) documents the PE, 74-byte footer, payload catalog, transforms, configuration, and nested archives.
4. [Configuration and payload selection](configuration-and-selection.md) describes selector tuples, `GeneralOptions`, online media, and architecture branching.
5. [MSI identity and ARP](msi-identity.md) separates builder identity, package identity, and visible uninstall registration.
6. [Format history](format-history.md) records release boundaries that changed available media capabilities or serialized character mode.
7. [Parser implementation](parser-implementation.md) maps the physical structures to catalog routes and bounded parsing.
8. [Coverage](coverage.md) lists implemented routes, fixtures, and remaining static-analysis limits.

## System model

```text
.aip project
  -> Advanced Installer compiler
      +-- direct MSI/MSP/MSIX output
      +-- EXE bootstrapper
      |   +-- embedded configuration
      |   +-- payload catalog
      |   +-- embedded or external MSI/MSIX/CAB/7z resources
      |   `-- prerequisite and download logic
      `-- Suite Installer MSI
          `-- package graph and suite UI

EXE runtime
  -> parse configuration
  -> choose language and host architecture branch
  -> download or extract the selected package
  -> install prerequisites
  -> invoke MSI/MSIX with composed switches
  `-- forward or translate the child result
```

The outer EXE and nested package have separate versions, identities, architectures, and ARP behavior. A PE `ProductVersion` normally describes the application or vendor-customized bootstrapper. It is not reliable evidence of the Advanced Installer release.

## Identity domains

| Identity | Meaning |
| --- | --- |
| Advanced Installer release | Builder version, reported only when compiled configuration or MSI Summary Information records it explicitly. |
| Commercial edition | Free, Professional, Enterprise, or Architect license used at build time. Generated media does not normally preserve it. |
| Project schema | Version of the `.aip` authoring document. Compiled media usually omits it. |
| Bootstrapper format profile | Footer, catalog, configuration, payload, transform, and bootstrapper-ID ABI selected by the parser catalog. |
| Structure version | Integer in the EXE footer. Observed classic media uses `100`; it is not the product version. |
| Application version | Publisher-controlled package version stored in MSI properties, EXE resources, or configuration. |
| MSI ProductCode and UpgradeCode | Windows Installer product and upgrade identities. |
| Custom ARP key | Optional visible EXE-style uninstall entry written while the native MSI entry is hidden. |

The parser reports a validated builder-version range when no exact builder release survives compilation. It does not derive the builder version from the application version.

## Static-analysis boundary

The footer and catalog prove physical payload ranges and selection classes. The INI can prove literal online URLs and architecture flags. MSI tables prove package identity and authored registry behavior. Runtime prerequisites, target-machine conditions, passwords, downloaded packages, and custom actions may still require VM validation.

## Sources

- [Advanced Installer user guide](https://www.advancedinstaller.com/user-guide/)
- [Advanced Installer release history](https://www.advancedinstaller.com/version-history.html)
- [Advanced Installer EXE setup command line](https://www.advancedinstaller.com/user-guide/exe-setup-file.html)
- [Advanced Installer configuration settings](https://www.advancedinstaller.com/user-guide/configuration-tab.html)
- [Komac Advanced Installer parser](https://github.com/russellbanks/Komac/tree/main/src/analysis/installers/advanced)
- [SabreTools Advanced Installer structures](https://github.com/SabreTools/SabreTools.Serialization/tree/main/SabreTools.Data.Models/AdvancedInstaller)
