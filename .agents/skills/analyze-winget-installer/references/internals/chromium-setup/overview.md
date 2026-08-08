# Chromium Setup parser internals

This reference supports parser implementation and review. For installer analysis and manifest authoring, use the [Chromium Setup workflow](../../families/chromium-setup/workflow.md).

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Supported formats and variants

- [Mini-installer](mini-installer.md): embedded setup resources and `InstallConstants` identity.
- [Chromium Updater](chromium-updater.md): packed updater archive, offline bundles, and updater tags.
- [Google Updater](google-updater.md): Google-branded current updater behavior.
- [Omaha](omaha.md): legacy metainstaller resources, certificate tags, and selected EXE payload.

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

- Modules/PackageModule/Libraries/Installers/ChromiumSetup.psm1
- Modules/PackageModule/Libraries/Installers/ChromiumMiniInstaller.psm1
- Modules/PackageModule/Libraries/Installers/ChromiumUpdater.psm1

## Representative fixtures

Use generated malformed fixtures and the behaviorally distinct real installers cited by the focused tests and family workflow.

## Source references

- [Chromium](https://chromium.googlesource.com/chromium/src)
- [Chromium mini-installer selection](https://chromium.googlesource.com/chromium/src/+/main/chrome/installer/mini_installer/mini_installer.cc)
- [Chromium mini-installer resource constants](https://chromium.googlesource.com/chromium/src/+/main/chrome/installer/mini_installer/mini_installer_constants.cc)
- [Chromium install-static uninstall registry construction](https://chromium.googlesource.com/chromium/src/+/main/chrome/install_static/install_util.cc)
- [Chromium InstallConstants layout](https://chromium.googlesource.com/chromium/src/+/main/chrome/install_static/install_constants.h)
- [Chromium Updater tag format](https://chromium.googlesource.com/chromium/src/+/main/chrome/updater/tag.h)
- [Google Omaha](https://github.com/google/omaha)
- [Omaha certificate tag parsing](https://github.com/google/omaha/blob/main/omaha/base/apply_tag.cc)
- [Omaha metainstaller payload build](https://github.com/google/omaha/blob/main/omaha/installers/build_metainstaller.py)
- [Brave Chromium install modes](https://github.com/brave/brave-core/tree/master/chromium_src/chrome/install_static)
- [Microsoft WebView2 Runtime distribution](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution)
