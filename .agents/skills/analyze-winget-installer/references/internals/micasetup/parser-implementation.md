# MicaSetup parser implementation

## Detection

Strict detection requires a valid managed PE, a supported Pack or Option configuration host, and exactly one WPF `ResourceTypeCode.Stream` named `resources/setups/publish.7z`. Product strings, icons, assembly company, a raw 7z signature, or a resource name without a valid `.resources` container are insufficient.

The reader never imports the installer assembly. `MicaSetupReader.cs` uses `PEReader` and `MetadataReader` to locate CLR structures, decode signatures, read method bodies, and map physical resource ranges. `MicaSetup.psm1` applies MicaSetup runtime semantics, archive analysis, ARP projection, diagnostics, and extraction.

## One-pass ownership

`Get-MicaSetupInfo` opens the installer once. The managed reader returns detached metadata and physical resource ranges. The PowerShell layer opens a bounded view of `publish.7z`, enumerates the catalog once, and selectively materializes only the main executable and relevant neighboring DLL or runtime sidecar files for PE analysis.

Caller-owned streams remain open and have their positions restored. Parser-owned file and archive streams are disposed in `finally`. Temporary payload-analysis directories are removed before return, so public results contain detached paths and evidence rather than handles into deleted storage.

## Extraction

`Expand-MicaSetupInstaller` resolves source and destination paths before managed I/O. Omitted `Name` means all installed payload entries and the configured uninstaller. `-RawResources` exports supported WPF stream and byte-array records instead. Public calls default to prompting only when a collision occurs; internal calls use `Rename`.

Extraction rejects absolute archive paths, root escape, traversal, malformed or duplicate destinations, excessive entries, excessive aggregate output, truncated resources, and invalid archive data. A dynamic payload password makes extraction unavailable. A constant password stays in local scope and is cleared with the archive context; it is never returned or logged.

## Diagnostics

Raw parser diagnostics are context-neutral. Structural rejection throws from strict parser entry points. Unsupported CIL expressions, dynamic passwords, custom handlers, ambiguous scope, and payload analysis failures become structured diagnostics and unresolved fields. The calling workflow assigns severity for full analysis, manifest authoring, manifest update, or extraction.

`OptionEvidence` and `UnresolvedExpressions` are the review surface for generated CIL. `SystemEffects` groups typed effects without converting them into manifest fields. `RecommendedPackageDependencies` is advisory payload evidence and is never applied automatically.

## Limits

The managed reader bounds resource rows, method bodies, decoded instructions, string lengths, array lengths, switch tables, metadata ranges, resource counts, and recursion. The archive layer bounds entries, compressed and expanded bytes, selective analysis, and output paths. Checked arithmetic precedes every offset plus length operation.

Malformed IL may yield partial configuration with a diagnostic when structural identity remains valid. An invalid PE, invalid CLR directory, out-of-range managed resource, malformed `.resources` table, missing payload stream, or incompatible configuration host rejects the artifact.

## Implementation map

- `Modules/PackageModule/Assets/Source/MicaSetup/MicaSetupReader.cs`: PE, CLR metadata, CIL, and ResourceManager reader.
- `Modules/PackageModule/Libraries/Installers/MicaSetup.psm1`: format semantics, result composition, payload analysis, and extraction.
- `Modules/PackageModule/Libraries/Infrastructure/InstallerAnalyzer.psm1`: provider-neutral family detection and parser orchestration.
- `Modules/PackageModule/Libraries/WinGet/WinGetAnalysis.psm1`: WinGet suggestion projection.
