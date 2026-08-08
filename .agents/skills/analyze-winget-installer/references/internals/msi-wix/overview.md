# MSI and WiX parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [MSI and WiX workflow](../../families/msi-wix/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

- [CFB and database layout](cfb-database.md): document classes, sectors, streams, and tables.
- [Builder detection](builder-detection.md): WiX, Advanced Installer, InstallShield, and unknown builders.
- [ARP and scope](arp-scope.md): visible entries, custom ARP, Windows Installer identity, and user context.

Each variant must pass the same content-based detection and bounds checks.

## Binary structure

The parser consumes the format structures described below. Offsets use the bases stated in each diagram.

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

- Modules/PackageModule/Libraries/Installers/MSI.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

- [WiX Toolset](https://github.com/wixtoolset/wix)
- [Microsoft: Word Count Summary property](https://learn.microsoft.com/en-us/windows/win32/msi/word-count-summary)
- [Microsoft: MsiRunningElevated property](https://learn.microsoft.com/en-us/windows/win32/msi/msirunningelevated-)
- [Microsoft: Using Windows Installer with UAC](https://learn.microsoft.com/en-us/windows/win32/msi/using-windows-installer-with-uac)
- [Chromium enterprise standalone MSI source](https://chromium.googlesource.com/chromium/src/+/main/chrome/updater/win/signing/enterprise_standalone_installer.wxs.xml)
- [Chromium Updater functional specification](https://chromium.googlesource.com/chromium/src/+/main/docs/updater/functional_spec.md)
- [Chromium Updater user manual](https://chromium.googlesource.com/chromium/src/+/main/docs/updater/user_manual.md)
- [Revenera: ISSetAllUsers custom action](https://docs.revenera.com/installshield27helplib/helplibrary/IHelpISSetAllUsers.htm)
