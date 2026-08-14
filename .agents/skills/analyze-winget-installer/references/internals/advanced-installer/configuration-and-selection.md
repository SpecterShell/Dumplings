# Configuration and payload selection

## Configuration encoding

Selector `(0, 3)` identifies the bootstrapper INI. Unicode generations normally store UTF-16LE, sometimes with a BOM. Historical media can use ANSI. Encoding is established from BOM and NUL distribution before key parsing.

The INI is literal configuration, not an executable project model. Values can still contain runtime properties and paths whose final value depends on the target system.

## GeneralOptions

Observed keys include `DownloadFolder`, `ExtractionFolder`, `MainAppURL`, `AllPlatforms`, `ProductCode`, `UpgradeCode`, `DefaultProdCode`, `PackageCode`, `MsiCertData`, `ProductVersion`, and updater settings. Product and package codes can aid correlation, but the selected MSI remains authoritative for Windows Installer identity.

An exact builder version is accepted only from explicit keys such as `AdvancedInstallerVersion`, `BuilderVersion`, or `AIVersion`. `ProductVersion` is the packaged application version. Project schema is reported only from an explicit `ProjectSchemaVersion` or `AipSchemaVersion` value.

## Main package precedence

```text
if MainAppURL is present
  select downloaded main package
else if selector (1, 0) exists
  select direct embedded MSI
else if selector (3, 7) exists
  select compressed archive and derive its MSI path
else
  leave main package unresolved
```

This ordering matters. An embedded MSI-like file does not replace `MainAppURL` evidence.

The same selector tuples can come from the external-resource role table. In that case, the selection is reported as `ExternalMsi` or `ExternalArchive`, and extraction reads the declared sibling instead of seeking the range inside the launcher.

## Classic platform selection

When `AllPlatforms=true`, the classic bootstrapper derives a `.x64` sibling name for the WOW64 branch. For example, `Product.msi` becomes `Product.x64.msi`, and `Product.7z` implies `Product.x64.msi` after extraction. The base path is selected otherwise.

Fixed-path media does not branch. Validate the selected MSI architecture directly. Current ARM64 packages may use a fixed ARM64 MSI, while an x86 stub under ARM64 can still take the classic `.x64` branch.

## Online URL transformation

For classic all-platform web media, the same suffix rule applies before the query or fragment. `https://example/Product.msi?token=x` becomes `https://example/Product.x64.msi?token=x` for the WOW64 branch. The parser preserves the original URI components.

## MSI/MSIX operating-system selection

A mixed platform bootstrapper carries the legacy MSI through the ordinary `(1, 0)` route and the modern package through selector `(1, 18)`. `GeneralOptions.AppxVersion` records the minimum Windows version for the modern branch, while `GeneralOptions.AppxPkId` records the compiled MSIX/AppX package full name. The latter can expose package architecture and the package-family-name components without opening the package.

```text
if current Windows version is at least AppxVersion
  install selector (1, 18) MSIX/AppX payload
else
  install the selected MSI payload
```

The outer EXE therefore has two possible installed-state owners. Analyze both nested packages and preserve existing manifest matching fields unless target-OS behavior is represented deliberately; using only the legacy MSI ProductCode would be incorrect on systems that take the MSIX/AppX branch.

## Ambiguity policy

If the configuration proves several architecture paths, callers must provide the manifest architecture. If no selector route proves a path, a wildcard can narrow candidates but cannot establish runtime selection. Multiple matching MSI files remain an error.

## Prerequisites

The outer catalog proves which prerequisite files are embedded. Selector group `4` stores an uncompressed prerequisite and group `9` stores an LZMA-compressed prerequisite. The catalog does not contain the command lines or detection conditions.

The selected MSI stores those semantics in `AI_PreRequisite` and `AI_AppSearchEx`. `AI_PreRequisite` records the display name, local path or URL, expected size, MD5 value, full/basic/silent command lines, force-install and compression flags, target name, execution order, feature, and missing condition. `AI_AppSearchEx` records the properties and searches referenced by that condition. Analyze these tables through the same selected MSI used for product identity; a different MSI from the payload set may describe different prerequisites.

`MissingCondition` uses Windows Installer conditional-expression syntax. Parse it as an expression rather than searching its text: quoted strings and property-name prefixes otherwise produce false search associations. The parser reports `MissingConditionAnalysis`, exact referenced `Searches`, and a three-valued `MissingConditionState`. Callers can provide virtual MSI properties to evaluate a target scenario; unspecified properties remain `Unknown`, and the analysis host is never queried.

Location value `0` is an embedded file, `1` is a download URL, and `2` opens a site. Controlled Advanced Installer 8.6 builds establish option flag `m` as force-install and `z` as LZMA compression. The parser leaves prerequisite elevation unresolved because the table describes child invocation rather than the child executable's manifest and runtime behavior.
