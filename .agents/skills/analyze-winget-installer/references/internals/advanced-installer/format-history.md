# Format history

Advanced Installer release notes describe feature availability, not every serialized field change. The catalog groups releases only when fixture bytes establish a shared footer, catalog, configuration, and transform ABI.

| Release boundary | Producer change relevant to media | Parser consequence |
| --- | --- | --- |
| 1.4 | First documented MSI EXE bootstrapper. | Earliest EXE coverage target; ANSI profile. |
| 1.8 | Downloadable prerequisites. | Main package and prerequisite payloads must remain distinct. |
| 3.6 | Online installation, silent options, and MD5 checks. | Web configuration and digest evidence become relevant. |
| 4.4 | LZMA bootstrapper compression. | Main package may be inside a compressed archive. |
| 6.1 | Unified x86/x64 packages. | `AllPlatforms` and architecture-derived paths appear. |
| 6.4 | Native Unicode EXE bootstrapper. | Catalog v0 retains its 20-byte framing but changes names and configuration to Unicode. |
| 8.6 | Whole-installer AES option. | Catalog v1 adds the transform word; encrypted archives require structured detection and remain non-extractable without a password. |
| 15.9 and 18.x | Later bootstrapper and MSIX-era feature growth. | Same validated physical profile can carry additional selector classes. |
| 19.9 | Web installer support with LZMA resources. | Online and compressed evidence can coexist. |
| 21.6 | Current archived builder baseline in winget-pkgs. | Direct MSI builder metadata remains the exact-version source when present. |
| 23.0 | Suite Installer output uses MSI. | Route Suite Installer media to MSI analysis. |
| 23.6 | Mixed platform choices include ARM64-era output. | Validate fixed or selected nested package architecture. |
| 23.9 | Current catalog coverage endpoint for this implementation. | Unicode profile remains valid on tested current media. |

## Catalog profiles

| Profile | Builder range | Character mode | Footer | Catalog | Configuration |
| --- | --- | --- | --- | --- | --- |
| `classic-ansi-v0` | 1.4 through 6.3.x | ANSI | `footer-v1` | `catalog-v0-ansi` | `ini-ansi-v1` |
| `classic-unicode-v0` | 6.4 through 8.5.x | Unicode | `footer-v1` | `catalog-v0-unicode` | `ini-unicode-v1` or detected INI encoding |
| `classic-unicode-v1` | 8.6 through 23.9 | Unicode | `footer-v1` | `catalog-v1-unicode` | `ini-unicode-v1` or detected INI encoding |
| `classic-compatible-v1` | Unknown future release | Validated catalog mode | `footer-v1` | fully consumed v1 catalog | detected INI route |

An exact builder release outranks the profile range when compiled configuration or nested MSI Summary Information records it. Future fallback is accepted only after all counts, pointers, record boundaries, transforms, and payload ranges validate.

## Sources

- [Advanced Installer version history](https://www.advancedinstaller.com/version-history.html)
- [Advanced Installer 4.4 release notes](https://www.advancedinstaller.com/release-4.4.html)
- [Advanced Installer 6.4 release notes](https://www.advancedinstaller.com/release-6.4.html)
- [Advanced Installer bootstrapper configuration and AES encryption](https://www.advancedinstaller.com/user-guide/configuration-tab.html)
- [Advanced Installer EXE bootstrapper command line and `/aespassword`](https://www.advancedinstaller.com/user-guide/exe-setup-file.html)
