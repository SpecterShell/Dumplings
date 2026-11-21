# Setup Factory parser implementation

## Validation and bounds

Detection requires a valid PE overlay boundary, the generation signature at that exact boundary, a structurally valid generation-specific catalog, bounded entry counts, fixed-width names, valid size fields, and records that remain inside the file. Marker strings elsewhere in the PE are only analyzer hints.

The parser limits the catalog to 100,000 entries, one compressed file to 1 GiB, total extraction to 16 GiB, variable recursion to 32, and every output path to the requested destination. It validates record CRCs, declared decompressed sizes, truncation, duplicate and colliding paths, and decoder-specific termination before writing output.

Metadata analysis catalogs the installer once and decompresses only `irsetup.dat`. It does not expand the complete payload or return temporary paths that disappear after the call. Selective extraction seeks directly to catalog offsets and decodes only matched entries.

End-to-end validation (2026-09-13, evidence under `Sandbox\Evidence\ParserValidation-20260912\SetupFactory` and `...\VM`): a controlled Setup Factory 7.0.6.1 builder project with known product identity, four payload files (including a zero-byte file), and uninstall support was built through the official `/BUILD` CLI, parsed field-for-field with zero diagnostics, re-extracted byte-exact, installed interactively in a sandbox, and its setup log plus `uninstall.xml` confirmed the parser's predicted ARP key (`Parser Probe3.2.1`), display values, publisher, and quoted uninstall command. In a validation VM, OutCALL 2.0 (9.1 runtime) installed silently with `/S` and the resulting visible HKLM `OutCALL2.0` entry matched the static prediction on every field, while a 7.0.1 media set and wizard-generated media both showed that `/S` is effective only when the project enables silent installation. Manifest generation for real Setup Factory packages through `Core\Index.ps1 -Dry` produced schema-valid manifests whose `ProductCode` matched the VM-verified ARP key.

## Detection route

`Test-SetupFactory` accepts SF3.1 only when `SETUP.EXE` is a valid MZ/NE launcher with the expected companion references and its sibling `IRDATA.IRD` has a complete Crusher catalog containing exactly one `IRDATA.DAT` and `IRSETUP.EXE`. A directly supplied `IRDATA.IRD` can also be analyzed. SF4-10 detection requires a valid PE overlay boundary, exact generation signature, complete catalog framing, and a supported profile.

The parser does not scan arbitrary strings to establish family identity. Product names, runtime names, and signature-like bytes are hints until the physical route validates.

## Parse-once behavior

`Get-SetupFactoryInfo` catalogs one media set and decompresses only the metadata required for analysis. SF3.1 decodes `IRDATA.DAT` once and maps its records to sibling files without expanding their contents. SF4-10 decodes `irsetup.dat` once and reuses its object tables for metadata, ARP, action, prerequisite, and installed-file projections.

Selective extraction seeks to one bounded ARQ, outer-catalog, prerequisite, or installed-payload range. Complete extraction streams entries in catalog order. The implementation does not materialize the full installer or full installed payload catalog as one PowerShell `Object[]` byte buffer.

## Decoder boundaries

The SF3.1 C# decoder has separate entry points for ARQ method 2 and companion-file streams. Both restore the source stream position, enforce exact packed ranges and expanded lengths, and reject malformed canonical Huffman tables or invalid back-references. The parser validates packed ARQ CRCs before decoding and expanded companion CRCs after decoding.

SF4-7 PKWARE streams use the bounded `PkwareBlast` decoder. LZMA and LZMA2 use shared managed archive infrastructure. A compression marker or plausible stream prefix cannot override the selected structural profile.

## Extraction safety

Every output name passes `Resolve-SafeExtractionPath`. `CollisionAction` defaults to `Prompt`, but the prompt appears only after a collision. Internal callers use `Rename`. Temporary files are moved into place only after decompression, size, and checksum validation succeeds.

A missing SF3.1 companion makes `CanExpand` false and `CanExpandPartial` true when other records remain present. Selecting the missing entry throws. The parser never substitutes a similarly named file or searches outside the media directory.

## Diagnostics

Raw parser results contain context-neutral structured diagnostics. The workflow assigns levels based on detection, full analysis, manifest authoring, manifest update, or extraction. Missing payloads affect extraction evidence. Dynamic actions affect only fields named in their diagnostic. A structurally proven family with incomplete metadata remains a successful parse; a malformed container or CRC is invalid input.

## Implementation mapping

The public GPL `SetupFactory.psm1` imports three internal modules locally. `SetupFactoryProject.psm1` decodes project, registry, and installed-file records. `SetupFactoryActions.psm1` interprets action tables and owns their record-reader dispatch. `SetupFactoryContainer.psm1` handles outer media, compressed payloads, and the classic 3.1 route. Public API names and JSON results remain owned by the original family module.

- `Modules/InstallerParsers/Libraries/Installers/SetupFactory.psm1`
- `Modules/InstallerParsers/Libraries/Installers/SetupFactoryFormatCatalog.psd1`
- `Modules/InstallerParsers/Assets/Source/SetupFactory/CrusherLh5Decoder.cs`
- `Modules/InstallerParsers/Assets/Source/SetupFactory/PkwareBlast.cs`
- `Modules/PackageModule/Libraries/Installers/SetupFactory.psm1`

The PackageModule file is the GPL process bridge. It does not copy the GPL parser into the Apache-2.0 module.

## Source references

- [Lhasa](https://github.com/fragglet/lhasa)
- [sfextract](https://github.com/CybercentreCanada/sfextract)
- [SFUnpacker](https://github.com/Puyodead1/SFUnpacker)
- [defactory](https://codeberg.org/CYBERDEV/defactory)
- [zlib blast](https://github.com/madler/zlib/tree/develop/contrib/blast)
