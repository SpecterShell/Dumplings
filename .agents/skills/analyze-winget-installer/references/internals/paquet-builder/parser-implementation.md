# Paquet Builder parser implementation

## Detection

Detection starts with a valid PE and Paquet identity from trusted version-resource fields, then requires one supported structure. Classic needs `DESCRIPTION`, `DVCLAL`, and `PACKAGEINFO`, a valid GPacker envelope, and its declared archive boundary. Cabinet2 needs a valid `ISFX` descriptor and `MSCF` at the exact payload offset. Legacy2 needs one valid payload 7z plus `MZ` in `RCDATA/ENG`. Resource2 needs one valid payload 7z plus a valid outer `GP` runtime. Split3 needs independently valid payload and runtime archives with runtime markers.

Marker strings and file extensions are hints only. A truncated capture or ordinary PE containing `GP`, `GDG`, or `PBCore` text is rejected.

## Parse pipeline

`Get-PaquetBuilderArchiveData` resolves the source path, opens the installer, parses PE layout and resources, identifies the route, decodes bounded configuration, and validates archive candidates. Archive metadata is copied into detached objects before contexts are disposed. `Get-PaquetBuilderInfo` composes common metadata, ARP evidence, system effects, diagnostics, and unresolved fields from that one analysis result.

Nested MSI parsing materializes only the one selected archive entry in an automatically removed temporary directory. It does not extract the full payload. Split3 runtime metadata is read directly from already-open archive entries. For UPX-packed 3.0 and 3.2 launchers, only the bounded mapped image is decoded: the 32-byte UPX header, compressed and expanded Adler-32 values, LZMA properties, saved PE header, section ranges, executable filter, and relocation stream are validated before the reconstructed in-memory PE reaches the normal scanner. The installer overlay is never copied into that image.

## Decoder boundaries

Classic GPacker, Classic GAF zlib members, `@GDG` LZHUF, `AP32` aPLib, outer `GP` LZMA, inner `GP` LZMA, and UPX/LZMA launcher images each have an independent size bound. CRC32 or Adler-32 is checked where the format supplies one. The inner 2.9 frame has no proven checksum field, so successful decoding additionally requires exact output length, bounded input residual, one unambiguous `GINFOS`, unique resource names, and exact resource-table termination.

The aPLib decoder is an independently written Apache-2.0 implementation based on format behavior and disassembly. Restrictively licensed reference source was not copied. The GPacker decoder is similarly isolated in managed source and never requires an external executable.

## Extraction

`Expand-PaquetBuilderInstaller` resolves source and destination paths and supports `Payload`, `Runtime`, or `All`. Omitted `Name` selects all files. `Prompt` asks only after a collision; internal calls use `Rename`. `All` prefixes payload and runtime outputs to prevent cross-container name collisions.

Classic extraction maps ordered GAF members to controller destinations. `{app}` becomes a path below the requested root and other destination classes are preserved below `_destinations`. Cabinet2 extraction uses the exact ISFX cabinet range. Legacy2 and Split3 use validated archive ranges. Resource2 emits the decoded runtime as `ENG.exe` and preserves the original encoded package configuration as `ENG.tail.bin`; `PackageConfiguration` contains its decoded semantic view.

All output paths pass traversal checks. Aggregate expanded bytes, entry counts, recursion, record counts, metadata bytes, PE mapping, and archive sizes are bounded.

## Diagnostics

Parser diagnostics are context-neutral. A concrete workflow resolves their level. Invalid structure and integrity failures are fatal for the selected route. Incomplete call-site scanning, unsupported GINFOS commands, dynamic scope, absent ARP identity, and unresolved destinations remain structured diagnostics so manifest update can preserve existing fields.

`PackageConfigurationError` does not silently discard a structurally proven family. It becomes `PaquetBuilder.Metadata.PackageConfigurationInvalid` with the exact ISFX or GP range. A confirmed route with a malformed payload archive still fails extraction rather than returning partial files as trusted output.

## Performance

The parser does not enumerate the same archive twice in one top-level operation. Large application payloads are catalogued and streamed. The 256 MiB mapped-PE limit excludes giant overlays from native scanning, and configuration buffers are capped at 4 MiB. Typed lists avoid repeated PowerShell array growth. Managed source loading is race-safe across repeated imports and worker runspaces.

## Extending coverage

Add a structural profile only after comparing at least one complete fixture with existing routes. A new command projection must preserve raw arguments and line numbers and must not interpret dynamic expressions as literals. A new native scanner shape needs bounded instruction decoding plus a fixture that proves both positive and negative behavior. Update [Coverage](coverage.md) with the fixture and remaining limitation.
