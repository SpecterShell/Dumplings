# Font workflow

## When to use

Use this workflow for a supported font artifact. Do not classify an archive as a font installer when it also contains application binaries.

## Detection

Identify the font format from its binary signature and internal tables rather than its filename extension. See [Font internals](../../internals/font/overview.md).

## Static analysis
Read [Font parser internals](../../internals/font/overview.md) before changing detection, extraction, binary decoding, or parser limits.

## Manifest shape

```yaml
Installers:
- Architecture: neutral
  InstallerType: font
  InstallerUrl: https://example.com/Font-1.2.3.ttf
  InstallerSha256: <SHA256>
```

Font manifests belong under the `fonts` root in winget-pkgs. Omit `InstallModes` and `InstallerSwitches`.

## WinGet defaults and overrides

Compare authored fields with WinGet's defaults and keep only family-specific overrides. Follow the [manifest installer-field guidance](../../../../author-winget-manifest/references/manifest/installer-fields.md) for field placement and omission rules.

## Apps & Features

Use structured parser evidence to identify the visible Apps & Features owner. Do not substitute metadata from a hidden or nested payload unless that payload writes the visible uninstall entry.

## Scope and architecture

Use explicit parser evidence for scope and installed payload architecture. Preserve existing manifest intent and use VM validation when either value is conditional or unresolved.

## VM validation

Confirm that the selected artifact is a supported font file and that its internal naming tables describe the intended family. VM validation is normally unnecessary unless installation behavior or font registration must be confirmed.

## Known examples

No accepted font-installer package is cited by the current parser fixture set. Add an example only after its font files and manifest behavior have been verified.
