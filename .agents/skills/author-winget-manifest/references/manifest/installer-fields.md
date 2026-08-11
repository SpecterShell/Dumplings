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

- Specify the installed application architecture, not just the bootstrapper architecture.
- Treat filename labels as discovery hints. Bare `arm` may mean ARM32 or ARM64, and `win32` may label either x86 or x64 software; inspect installer metadata and installed or nested binaries before assigning the architecture. `win64` identifies x64.
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
- Quote `<INSTALLPATH>` inside every explicitly authored install-location switch. The quotes must reach the installer command line, as in `APPDIR="<INSTALLPATH>"` or `--root "<INSTALLPATH>"`; wrapping only the YAML scalar does not protect a path containing spaces. If the installer does not support path-only quoting, test whether it accepts the complete switch inside literal double quotes. Use a single-quoted YAML scalar to preserve them, as in `InstallLocation: '"/DIR=<INSTALLPATH>"'` for `Ekahau.Capture`.
- Add `UnsupportedArguments` when `--location` or `--log` is known unsupported.
- For `nullsoft`, omit `InstallerSwitches.Silent` and `SilentWithProgress` when both are the default `/S`. The same per-key omission rule applies to every known installer type and to a ZIP's effective `NestedInstallerType`.

For package prerequisites, follow [Installer dependencies](dependencies.md). In addition to VC and .NET runtimes, check for hard requirements on Visual Studio Tools for Office Runtime (`Microsoft.VSTOR`) and Microsoft Office or an Office host such as Outlook, Word, Excel, or PowerPoint (`Microsoft.Office`). Do not infer either dependency from optional integration or product-name strings.

## Installer Field Completeness Pass

Do not treat the minimal skeleton as the target output. Before finalizing, inspect every applicable schema field and record evidence or a reason for omission. At minimum, check:

- Container and payload shape: `InstallerType`, `NestedInstallerType`, `NestedInstallerFiles`, `Architecture`, `Scope`, `InstallerLocale`, and `Platform`.
- OS and execution behavior: `MinimumOSVersion`, `InstallModes`, `InstallerSwitches`, `InstallerSuccessCodes`, `ExpectedReturnCodes`, `ElevationRequirement`, `UpgradeBehavior`, `RepairBehavior`, `InstallerAbortsTerminal`, `DownloadCommandProhibited`, and `UnsupportedArguments`.
- Installed identity: `ProductCode`, `PackageFamilyName`, `AppsAndFeaturesEntries`, `InstallationMetadata`, and `ReleaseDate`.
- Integration evidence: `Commands`, `Protocols`, `FileExtensions`, `Dependencies`, `Capabilities`, `RestrictedCapabilities`, `Markets`, and `ArchiveBinariesDependOnPath`.

Use static parser output first, then complete mandatory VM validation against the exact artifact and switch set. Use the compact before/after comparison for facts observable only after installation or first run. Do not read full VM snapshots unless a compact comparison identifies an ambiguity. Do not add a field merely because it exists in the schema: every value must be applicable and evidenced. `Protocols` and `FileExtensions` can be included when observed, but absence from static parsing is not proof that an application never registers them on first run.

### Commands and portable command aliases

`Commands` has an installation meaning only when the base `InstallerType` is `portable`. WinGet permits zero or one value for a direct portable installer; when present, the first value becomes the installed executable name and portable link alias. For example, an artifact named `codex-x86_64-pc-windows-msvc.exe` should use `Commands: [codex]`, based on the documented user-facing command rather than the architecture, target platform, toolchain, or file suffix in the asset name.

For `InstallerType: zip` with `NestedInstallerType: portable`, put `PortableCommandAlias` next to each exposed `RelativeFilePath`. This alias controls the portable link WinGet creates after extraction. `Commands` does not create that alias, but still add the same user-facing commands to `Commands` so they are published in the source index. Do not assign `PortableCommandAlias` to bundled helper executables that are not intended as commands.

For every other base and nested installer-type combination, `Commands` does not alter installer execution, filenames, PATH, or aliases. It is still aggregated into WinGet's searchable Commands index. PowerToys' Command Not Found integration uses the `Microsoft.WinGet.CommandNotFound` provider to obtain Windows Package Manager suggestions, so accurate command metadata lets an unknown command resolve to the correct package.

Follow these rules:

- Always author `Commands` for direct portable and ZIP-plus-portable packages. A direct portable entry must have exactly one command. A ZIP-plus-portable package may expose several commands, subject to the schema limit, with a corresponding `PortableCommandAlias` on each command target.
- Derive the command from the project's documentation, README, usage output, or a verified installed command. Strip architecture, platform, toolchain, version, and packaging decorations from filenames. Do not guess solely from an asset name.
- During mandatory VM validation of a non-portable installer, compare user and machine PATH. When the installer adds its own directory, add its user-facing CLI commands to `Commands` after verifying them in a fresh shell.
- Include CLI commands only. Exclude GUI executable names and internal helpers such as uninstallers, updaters, crash tools, or framework-specific commands such as .NET's `createdump`.

The behavior is grounded in winget-cli's [`PortableFlow.cpp`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCLICore/Workflows/PortableFlow.cpp), [`ManifestValidation.cpp`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCommonCore/Manifest/ManifestValidation.cpp), manifest command aggregation in [`Manifest.cpp`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCommonCore/Manifest/Manifest.cpp), source-index insertion in [`Interface_1_0.cpp`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerRepositoryCore/Microsoft/Schema/1_0/Interface_1_0.cpp), and the official [`Microsoft.WinGet.CommandNotFound`](https://github.com/microsoft/winget-command-not-found) integration.

### ReleaseDate

Use the release date in this evidence order:

1. The matching GitHub release publication date for GitHub-release sources, following the same release selection used by Dumplings GitHub tasks.
2. A version-specific official release-notes or release-history page.
3. The installer's `Last-Modified` HTTP response header when no authoritative release record is available.

Record the source of the date. Do not substitute a page update date, repository commit date, or unrelated asset timestamp.
