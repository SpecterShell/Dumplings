# InstallAnywhere parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [InstallAnywhere workflow](../../families/installanywhere/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

The parser covers the structured InstallAnywhere variants documented below. Variant-specific evidence must pass the same content-based detection and bounds checks.

## Binary structure

The supported InstallAnywhere layout is a native launcher followed by a self-contained standard ZIP range. Installer logic may be nested in another ZIP entry.

```text
native PE launcher
`-- embedded ZIP range
    +-- local-file records
    +-- central directory
    +-- EOCD                         establishes archive start/end
    +-- InstallerData/Execute.zip   optional nested ZIP
    |   `-- InstallScript.iap_xml
    +-- IAClasses.zip
    `-- InstallerData/.../Resource1.zip and payloads
```

Dumplings derives the embedded ZIP base from the end-of-central-directory and central-directory offset; the first `PK` local header is not trusted as the archive base. Nested ZIP ranges receive independent entry, size, path, and expansion checks. `InstallScript.iap_xml` is structured Java-bean XML containing product identity and actions.

```text
InstallScript.iap_xml
+-- com.zerog.ia.installer.Installer
|   +-- supportsSilentUI / supportsConsoleUI
|   +-- responseFileEnabled
|   +-- installDir -> Windows magic-folder object + relative expression
|   `-- instanceDefinition -> enableInstanceManagement
+-- com.zerog.ia.installer.util.InstallerInfoData
|   +-- productName / productVersion / vendorName
|   +-- productID -> com.zerog.registry.UUID
|   `-- upgradeCode -> com.zerog.registry.UUID
+-- com.zerog.ia.installer.actions.InstallUninstaller
|   `-- shouldUninstall / destinationName / execLevel
`-- com.zerog.ia.installer.actions.SpeedRegistry
    `-- repeated SpeedRegistryData
        +-- keyPath
        +-- dataType
        `-- data
```

The InstallAnywhere runtime creates the built-in Windows uninstall subkey from `productName`, optionally suffixed for instance-managed installations. It writes the project UUID as the ARP value named `ProductID`; that UUID is not the WinGet `ProductCode`. The runtime initially targets HKLM and can fall back to HKCU, so the exact scope remains runtime evidence unless an explicit uninstall write fixes the hive.

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

- Modules/PackageModule/Libraries/Installers/InstallAnywhere.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

Use the source references in the mapped module headers and its focused tests. Add upstream references here when new behavior is grounded.
