# Parser implementation

## Catalog and handlers

`AdvancedInstallerFormatCatalog.psd1` contains immutable profile data. Profiles select footer, catalog, configuration, payload, transform, and bootstrapper-ID routes. Handler maps resolve route IDs to focused readers. Version comparisons do not choose field offsets while records are being parsed.

## Analysis context

One top-level parse opens the installer once and builds this context:

```text
resolved path
+-- validated footer
+-- exact-consumption payload catalog
+-- exact-consumption external sibling table
+-- decoded configuration entry
+-- GeneralOptions
+-- format profile and version evidence
+-- media classification
`-- MSI payload selection
```

`Get-AdvancedInstallerInfo` projects this context. `Get-AdvancedInstallerFormatInfo` projects only diagnostic format evidence. Extraction can reuse the returned catalog without reparsing names or selection rules.

`SupportedMediaModes` and `Capabilities` describe what the selected profile range can encode. They do not prove that the current file contains every listed feature. `MediaType`, `MediaInfo`, `MsiPayloadSelection`, and `ArchitectureSelectionEvidence` contain the current-file observations.

## Detection route

The analyzer can use `ADVINSTSFX` as a cheap routing marker, but it accepts Advanced Installer only after `Get-AdvancedInstallerFormatInfo` validates the physical-footer pointer, embedded and external counts, hexadecimal-field syntax, catalog records, payload ranges, exact embedded-catalog consumption, and exact external-table consumption.

## Bounds

- Embedded and external file counts are each no more than 65,536, and their sum is nonzero.
- The footer lies inside the file and its self-pointer equals its physical offset.
- The embedded catalog ends before the optional external table, and both end exactly at their declared boundaries.
- Catalog start is before its declared end and after payload storage.
- Names are bounded before allocation and decoded with strict encodings.
- Every payload range finishes before the catalog.
- External names resolve beneath the setup directory, and absent sibling files remain warnings rather than false-negative format detection.
- Configuration is limited to 4 MiB.
- Nested archive extraction enforces path, entry-count, and expanded-byte limits.
- Unknown transforms remain opaque.

## Performance evidence

The 2,167,225,168-byte BenchMate fixture is the large-media regression. In a clean local PowerShell process, catalog analysis plus selected nested MSI parsing completed in 13.74 seconds with a 221.8 MiB peak working set. This measurement is diagnostic evidence, not a portable CI expectation; the test enforces only the existing 60-second watchdog.

## Fallback

Unknown structure versions can use the compatibility profile only after a complete known footer and catalog route validates. The result sets `IsFallback` and leaves exact builder version unset. An isolated signature never qualifies.

## Module boundary

The byte parser is GPL-2.0 in InstallerParsers. PackageModule exposes an Apache-2.0 bridge and consumes JSON evidence across the child-process boundary. MSI parsing remains in PackageModule and supplies nested identity, ARP, architecture, and exact builder-version evidence.

## Implementation files

- `Modules/InstallerParsers/Libraries/Installers/AdvancedInstallerFormatCatalog.psd1`
- `Modules/InstallerParsers/Libraries/Installers/AdvancedInstaller.psm1`
- `Modules/InstallerParsers/Cli.ps1`
- `Modules/PackageModule/Libraries/Installers/AdvancedInstaller.psm1`
- `Modules/PackageModule/Libraries/Installers/MSI.psm1`
- `Modules/PackageModule/Libraries/Infrastructure/InstallerAnalyzer.psm1`
