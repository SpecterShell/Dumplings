# Installer fields

## Installer File

Required per installer:

- `Architecture`
- `InstallerType`
- `InstallerUrl`
- `InstallerSha256`

URL rules:

- Use only an official, public URL that WinGet can download without browser state, cookies, account login, form state, or expiring query parameters.
- Do not write signed/session URLs containing dynamic keys, tokens, signatures, expiry timestamps, or changing hash parameters into `InstallerUrl`.
- If an official stable URL redirects to a signed final URL, prefer the stable previous URL as `InstallerUrl`.
- If no stable public URL exists, stop manifest authoring and report that automation must capture update traffic in a VM instead.

Installer type rules:

- Use `msi` for direct MSI installers.
- Use `msix`, `appx`, `msixbundle`, or `appxbundle` for packaged app installers and include `PackageFamilyName`/`SignatureSha256` when applicable.
- Use known EXE installer types (`inno`, `nullsoft`, `burn`, `wix`) when detected.
- Use `exe` only when no more specific supported type applies and silent switches are known.
- Use `zip` with `NestedInstallerType` and `NestedInstallerFiles` for archives.
- Use `portable` only for standalone portable executables or archive-contained portable binaries that match WinGet portable policy.

Architecture rules:

- Specify the architecture of the installed application. A bootstrapper may have a different architecture.
- Treat filename labels as discovery hints. Bare `arm` may mean ARM32 or ARM64, and `win32` may label either x86 or x64 software. Inspect installer metadata and installed or nested binaries before assigning the architecture. `win64` identifies x64.
- Use `neutral` only when the same installer and installed binaries are architecture-neutral.
- Split installers by architecture when URLs or hashes differ.
- Do not add `UnsupportedOSArchitectures` at the moment. Use unsupported-architecture evidence to avoid creating an incorrect installer entry, but omit the manifest field.

Installer locale rules:

- Add `InstallerLocale` only when two or more installer entries are differentiated by locale, such as separate locale-specific binaries, URLs, or hashes.
- Omit `InstallerLocale` for a single installer, a multilingual installer, or identical installer binaries shared across locales.
- As a final post-processing rule, remove `InstallerLocale` from every installer when every effective installer has the same non-empty value. A common locale does not distinguish payloads and can cause validation to force that locale onto dependencies that do not declare one, as documented in [winget-pkgs#335187](https://github.com/microsoft/winget-pkgs/issues/335187) and [Komac#1718](https://github.com/russellbanks/Komac/issues/1718).
- Do not infer `InstallerLocale` from the manifest's locale files or from an installer UI language selector. It describes which locale-specific installer payload the entry represents.

Switch and behavior rules:

- Prefer WinGet defaults for known installer types.
- Add `InstallerSwitches` only when required for silent install, custom install behavior, or known publisher-specific requirements.
- For `msi`, `wix`, and archive-contained MSI/WiX entries, explicitly check `Get-MsiInstallerInfo.InstallLocationSwitch`. Add a verified non-default override even when the other switches use WinGet defaults. Follow [MSI install-location analysis](../../../analyze-winget-installer/references/families/msi-wix/analysis.md#determine-install-location-switches-and-modes) for unresolved properties and VM checks.
- Quote `<INSTALLPATH>` inside every explicitly authored install-location switch. The quotes must reach the installer command line, as in `APPDIR="<INSTALLPATH>"` or `--root "<INSTALLPATH>"`. Wrapping only the YAML scalar does not protect a path containing spaces. If the installer does not support path-only quoting, test whether it accepts the complete switch inside literal double quotes. Use a single-quoted YAML scalar to preserve them, as in `InstallLocation: '"/DIR=<INSTALLPATH>"'` for `Ekahau.Capture`.
- Add `UnsupportedArguments` when `--location` or `--log` is known unsupported.
- For `nullsoft`, omit `InstallerSwitches.Silent` and `SilentWithProgress` when both are the default `/S`. The same per-key omission rule applies to every known installer type and to a ZIP's effective `NestedInstallerType`.
- For Dell bootstrappers, follow the [Dell command-route workflow](../../../analyze-winget-installer/references/families/dell-update-package/workflow.md) when selecting family defaults or adapting the separate embedded-command alternative after a failed VM test.

For package prerequisites, follow [Installer dependencies](dependencies.md). In addition to VC and .NET runtimes, check for hard requirements on Visual Studio Tools for Office Runtime (`Microsoft.VSTOR`) and Microsoft Office or an Office host such as Outlook, Word, Excel, or PowerPoint (`Microsoft.Office`). Do not infer either dependency from optional integration or product-name strings.

## Installer Field Completeness Pass

Before finalizing, review applicable schema fields and record evidence or a reason for omission.

- Container and payload shape: `InstallerType`, `NestedInstallerType`, `NestedInstallerFiles`, `Architecture`, `Scope`, `InstallerLocale`, and `Platform`.
- OS and execution behavior: `MinimumOSVersion`, `InstallModes`, `InstallerSwitches`, `InstallerSuccessCodes`, `ExpectedReturnCodes`, `ElevationRequirement`, `UpgradeBehavior`, `RepairBehavior`, `InstallerAbortsTerminal`, `DownloadCommandProhibited`, and `UnsupportedArguments`.
- Installed identity: `ProductCode`, `PackageFamilyName`, `AppsAndFeaturesEntries`, `InstallationMetadata`, and `ReleaseDate`.
- Integration evidence: `Commands`, `Protocols`, `FileExtensions`, `Dependencies`, `Capabilities`, `RestrictedCapabilities`, `Markets`, and `ArchiveBinariesDependOnPath`.

Use static parser output first, then complete mandatory VM validation against the exact artifact and switch set. Use the compact before/after comparison for facts observable only after installation or first run. Do not read full VM snapshots unless a compact comparison identifies an ambiguity. Do not add a field merely because it exists in the schema: every value must be applicable and evidenced. `Protocols` and `FileExtensions` can be included when observed, but absence from static parsing is not proof that an application never registers them on first run.

### Commands and portable command aliases

`Commands` has an installation meaning only when the base `InstallerType` is `portable`. WinGet permits zero or one value for a direct portable installer; when present, it defines the command alias. Older clients rename the installed executable for that alias. The current development branch's [v1.30 release notes](https://github.com/microsoft/winget-cli/blob/master/doc/ReleaseNotes.md#portable-installer-alias-handling) describe preserving the original filename and creating a hardlink alias instead, with a file-copy fallback on unsupported volumes. Check the validation client's version before assuming either physical layout. For example, an artifact named `codex-x86_64-pc-windows-msvc.exe` should use `Commands: [codex]`, based on the documented user-facing command, not the architecture, target platform, toolchain, or file suffix in the asset name.

For `InstallerType: zip` with `NestedInstallerType: portable`, put `PortableCommandAlias` next to each exposed `RelativeFilePath`. This alias controls the portable link WinGet creates after extraction. `Commands` does not create that alias, but still add the same user-facing commands to `Commands` so they are published in the source index. Do not assign `PortableCommandAlias` to bundled helper executables that are not intended as commands.

For every other base and nested installer-type combination, `Commands` does not alter installer execution, filenames, PATH, or aliases. It is still aggregated into WinGet's searchable Commands index. PowerToys' Command Not Found integration uses the `Microsoft.WinGet.CommandNotFound` provider to obtain Windows Package Manager suggestions, so accurate command metadata lets an unknown command resolve to the correct package.

- Always author `Commands` for direct portable and ZIP-plus-portable packages. A direct portable entry must have exactly one command. A ZIP-plus-portable package may expose several commands, subject to the schema limit, with a corresponding `PortableCommandAlias` on each command target.
- Derive the command from the project's documentation, README, usage output, or a verified installed command. Strip architecture, platform, toolchain, version, and packaging decorations from filenames. Do not guess solely from an asset name.
- During mandatory VM validation of a non-portable installer, compare user and machine PATH. When the installer adds its own directory, add its user-facing CLI commands to `Commands` after verifying them in a fresh shell.
- Include CLI commands only. Exclude GUI executable names and internal helpers such as uninstallers, updaters, crash tools, or framework-specific commands such as .NET's `createdump`.

Source references are [`PortableFlow.cpp`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCLICore/Workflows/PortableFlow.cpp), [`ManifestValidation.cpp`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCommonCore/Manifest/ManifestValidation.cpp), command aggregation in [`Manifest.cpp`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCommonCore/Manifest/Manifest.cpp), index insertion in [`Interface_1_0.cpp`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerRepositoryCore/Microsoft/Schema/1_0/Interface_1_0.cpp), and [`Microsoft.WinGet.CommandNotFound`](https://github.com/microsoft/winget-command-not-found).

### Archive binaries that depend on the installation path

For `InstallerType: zip` with `NestedInstallerType: portable`, add `ArchiveBinariesDependOnPath: true` when a command executable depends on companion files that remain in the extracted installation directory. Common evidence includes side-by-side DLLs, native runtime files, plugins, or required data and configuration loaded relative to the executable. WinGet then adds the actual portable installation directory to `PATH` instead of relying on command symlinks whose directory may not contain those dependencies.

The presence of README files, licenses, checksums, icons, or other incidental non-executable content does not require this field. Multiple independent EXE files do not prove it either. Instead, add all of them to NestedInstallerFiles. Inspect imports, adjacent runtime files, project documentation, and a WinGet installation in the VM. Set the field whenever the selected portable executable needs the archive's companion files to start or operate correctly. The field applies only to archive-plus-portable installers and defaults to `false` when omitted.

This behavior is defined by the WinGet [manifest schema](https://github.com/microsoft/winget-cli/blob/master/schemas/JSON/manifests/v1.12.0/manifest.installer.1.12.0.json) and the portable installation path in [`PortableInstaller.cpp`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCLICore/PortableInstaller.cpp).

```yaml
InstallerType: zip
NestedInstallerType: portable
ArchiveBinariesDependOnPath: true
Installers:
- Architecture: x64
  NestedInstallerFiles:
  - RelativeFilePath: Product.exe
    PortableCommandAlias: product
  InstallerUrl: https://example.com/Product-1.2.3-x64.zip
  InstallerSha256: <SHA256>
```

### ReleaseDate

Follow [Release date evidence](../package/release-date.md) for source priority and timestamp interpretation.
