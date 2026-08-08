# Burn parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [Burn workflow](../../families/burn/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured Burn variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

Burn stores a fixed bundle header in the PE section named `.wixburn`. The first container is the UX CAB at `StubSize`. Attached payload CABs begin at WiX's calculated engine boundary, after the UX data and any preserved original engine signature. A separately applied current Authenticode signature can follow the attached containers.

```text
PE bundle stub
+-- .wixburn section                bundle registration/header record
+-- UX CAB at StubSize              contains entry "0" (BurnManifest XML)
+-- optional original signature     included in EngineSize
+-- attached container 1            begins at EngineSize
+-- attached container N            follows the previous declared range
`-- optional current signature      PE certificate table after payloads
```

```text
Base       Offset  Size       Field
---------  ------  ---------  ----------------------------------------
[section]  0x00    4          Magic 0x00F14300, uint32 LE
[section]  0x04    4          Format version (supported: 2), uint32 LE
[section]  0x08    16         Bundle GUID, Windows GUID byte order
[section]  0x18    4          StubSize, uint32 LE -> [abs]
[section]  0x1C    4          OriginalChecksum, uint32 LE
[section]  0x20    4          OriginalSignatureOffset, uint32 LE
[section]  0x24    4          OriginalSignatureSize, uint32 LE
[section]  0x28    4          ContainerFormat (1 = CAB), uint32 LE
[section]  0x2C    4          ContainerCount, uint32 LE
[section]  0x30    4*N        Container sizes, uint32 LE
```

Container sizes frame exact sequential ranges. `AttachedIndex` maps physical attached slots to authored container IDs. Manifest XML describes logical payload paths, chain order, package conditions, cache IDs, install arguments, scope variables, and ARP registration; physical adjacency does not by itself identify the visible ARP owner.

`Expand-BurnInstaller` projects the embedded bytes using the WiX 7 extraction model:

```text
<Destination>\
+-- UX\
|   +-- manifest.xml
|   `-- <UX Payload.FilePath>
+-- WixAttachedContainer\
|   `-- <Payload.FilePath>
`-- <CustomContainerId>\
    `-- <Payload.FilePath>
```

Entry `0` becomes `UX\manifest.xml`; opaque `u*` and `a*` source names are replaced with their manifest `FilePath` values. Unmapped CAB records retain their authored CAB paths under the corresponding directory. External payloads and detached containers are reported but never downloaded. WiX 7 provides this behavior through `wix burn extract`; `dark -x` is the older WiX 3 command.

## Detection invariants

Accept the family only when the surrounding headers, ranges, counts, and relationships described above validate. Treat an isolated marker as a routing hint and preserve conditional values as unresolved evidence.

## Metadata projection

Project only structured metadata and explicit registry behavior into the shared parser result. Preserve conditional or unknown values as warnings or unresolved fields.

## Bounds and malformed input

Apply the shared parser bounds to every offset, size, count, decompressed range, destination path, and recursion boundary. Reject malformed input deterministically.

## Performance considerations

Open the installer once, reuse parsed layout evidence, and prefer bounded streams or selected-entry extraction over whole-file materialization.

## Known gaps

Unsupported variants and conditional runtime behavior remain explicit warnings or unresolved evidence; they are not inferred from arbitrary strings.

## Implementation mapping

- Modules/PackageModule/Libraries/Installers/Burn.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

- [WiX Burn common header and engine-boundary reader](https://github.com/wixtoolset/wix/blob/main/src/wix/WixToolset.Core.Burn/Bundles/BurnCommon.cs)
- [WiX Burn UX and attached-container extraction](https://github.com/wixtoolset/wix/blob/main/src/wix/WixToolset.Core.Burn/Bundles/BurnReader.cs)
- [WiX 7 `wix burn extract` command](https://github.com/wixtoolset/wix/blob/main/src/wix/WixToolset.Core.Burn/CommandLine/ExtractSubcommand.cs)
