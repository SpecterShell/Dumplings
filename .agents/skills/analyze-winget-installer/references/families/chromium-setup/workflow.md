# Chromium Setup workflow

## When to use

Use `InstallerType: exe` for Chromium-family setup executables after distinguishing the mini-installer, Chromium Updater, current Google Updater, legacy Google Update/Omaha, and vendor-specific online or offline bootstrappers. Their command lines and payload records are not interchangeable.

## Detection

Strong evidence includes the mini-installer's `B7`, `BL`, and `BN` setup resources; Chromium Updater's `updater.packed.7z`; Omaha's resource ID 102 LZMA, BCJ2, and TAR payload; and tags bounded to the Authenticode certificate table. An updater `appguid` is protocol identity rather than an ARP `ProductCode`.

## Static analysis

Read [Chromium Setup parser internals](../../internals/chromium-setup/overview.md) before changing detection, extraction, binary decoding, or parser limits.

```powershell
$Info = Get-ChromiumSetupInfo -Path $InstallerFile
$Info.Variant
$Info.UpdaterTag
$Info.ExecutedPayloads
```

1. Select the matching [variant manifest](variants.md).
2. Follow [Chromium analysis](analysis.md) to identify the target application, selected payload, visible ARP owner, scope, architecture, and vendor-specific behavior.
3. Use the parser internals only when implementing or debugging the parser.

WinGet supplies no switches or install modes for generic `InstallerType: exe`. Every switch in the selected shape is a complete package-specific override. Keep launch suppression in `Custom`, include no-reboot behavior in the silent fields where supported, and never substitute switches from another variant.

## Manifest shape

Select the [variant manifest shape](variants.md) that matches `$Info.Variant`. Project only fields supported by parser or VM evidence into the installer entry.

## WinGet defaults and overrides

Compare authored fields with WinGet's defaults and keep only family-specific overrides. Follow the [manifest installer-field guidance](../../../../author-winget-manifest/references/manifest/installer-fields.md) for field placement and omission rules.

## Apps & Features

Use the [target and ARP ownership analysis](analysis.md#identify-the-target-and-visible-arp-owner) to identify the visible Apps & Features entry. Do not substitute metadata from a hidden or nested payload unless that payload writes the visible uninstall entry.

## Scope and architecture

Use the [scope and architecture analysis](analysis.md#determine-scope-and-target-architecture) for the selected variant. Preserve existing manifest intent and use VM validation when either value is conditional or unresolved.

## VM validation

Follow [VM validation](../../workflows/vm-validation.md) when online payload selection, target ARP identity, scope, forwarding, or vendor behavior remains unresolved.

## Known examples

- `Google.Chrome.EXE`: Chromium mini-installer behavior.
- `Brave.Brave`: vendor-specific Chromium install modes.
- `360.360Ent`: ProductCode recovery from source-compatible identity records.
- `Microsoft.EdgeWebView2Runtime`: runtime-specific Chromium Setup identity.
- `Vivaldi.Vivaldi`: vendor resource-layout differences.
