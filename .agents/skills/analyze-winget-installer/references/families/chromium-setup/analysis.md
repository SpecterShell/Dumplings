# Chromium Setup static analysis

[Back to the Chromium Setup workflow](workflow.md)

## Parse and expand the updater variant

```powershell
$Info = Get-ChromiumSetupInfo -Path $InstallerFile
$Info.Variant
$Info.UpdaterTag
$Info.OfflineManifest
```

Use the aggregate result throughout the analysis. Do not call the scalar `Read-*` or `Test-*` helpers after `Get-ChromiumSetupInfo`; they are alternatives for callers that need only one value. Expand only when nested payload evidence is required:

```powershell
$Files = Expand-ChromiumSetupInstaller -Path $InstallerFile -DestinationPath $DestinationPath -CollisionAction Rename
```

Expansion is source-backed and bounded:

- `BN`/`BD` resources are exported directly.
- `BL` resources are decoded as cabinets.
- `B7` resources are opened with the bundled SharpCompress library; Chromium Updater's nested `updater.7z` is opened recursively so `bin\updater.exe` and any `bin\Offline\{bundle-guid}` payload can be inspected.
- Branded mini-installers may replace `CHROME.PACKED.7Z` with a product name such as Vivaldi's `VIVALDI.PACKED.7Z`. Identify this layout from one non-setup/non-updater `B7` or `BN` archive paired with a `B7`, `BL`, or `BN` setup resource; do not require the `CHROME` prefix.
- Omaha resource `102` is decoded as LZMA, four-stream BCJ2, then TAR according to Omaha's metainstaller build pipeline. Declared compressed and expanded sizes are enforced. Untagged legacy payloads execute the first EXE; tagged offline payloads use the install action selected from `OfflineManifest.gup`.
- For tagged Chromium Updater and Omaha wrappers, `Get-ChromiumSetupInfo` reads `OfflineManifest.gup` or the matching `{app-id}.gup`, selects the signed-tag application, locates its configured executable, verifies the declared size and SHA-256, and recursively analyzes that target. Omaha may suffix the physical TAR name with an app GUID or use a different physical name; a unique size match is accepted only after hash verification. `IsOnlineBootstrapper` is true only after the applicable nested archive was checked and no offline target manifest was found; it is null when that check fails.

No installer, updater, 7-Zip, or NanaZip process is invoked.

## Identify the target and visible ARP owner

The outer updater/metainstaller may not be the final application's ARP writer.

- Bare mini-installer: nested `setup.exe` normally writes the browser ARP entry. `Get-ChromiumSetupInfo` extracts the source-selected setup resource and reads version data plus validated `kInstallModes` selectors and system-level support. It does not scan uninstall paths or combine company, product, channel, suffix, updater, or branding strings into `ProductCode`.
- Every Chromium variant returns `ProductCode` as unresolved. Preserve an accepted existing value during updates. For a new package, obtain the visible uninstall key from the installed-state comparison in the VM. Do not convert `appguid`, `ApplicationId`, PE branding, update-client paths, or install-mode suffixes into a manifest ProductCode.
- Untagged updater package: model the updater's own ARP entry.
- Tagged Updater/Omaha: model the target application's visible ARP entry, not `appguid`. With `OfflineManifest.gup`, use `OfflineManifest.Version`, inspect `Packages` and `InstallAction`, and use recursively parsed target evidence for non-ARP metadata. Preserve an existing ProductCode and require VM evidence for a new one.
- `Microsoft.EdgeWebView2Runtime`: the signed UTF-16 tag selects the matching application and the parser hash-verifies its differently named physical TAR payload before analyzing it. Retain accepted manifest or VM ProductCode evidence rather than converting its app GUID.
- Tagged updater without an offline manifest: the outer PE product version belongs to the updater. Do not use it as the target package version; obtain target-version evidence from the downloaded installer/feed or VM traffic.
- If the target is downloaded at runtime, static analysis cannot prove the final installer version, ARP type, or associations. Capture the updater traffic and validate in the VM.

## Determine scope and target architecture

- Bare mini-installer: default user, `--system-level` machine.
- Untagged Chromium Updater: default user, `--system` machine.
- Untagged Omaha runtime package: user `/install "runtime=true" /enterprise`; machine `/install "runtime=true&needsadmin=true" /enterprise`.
- Tagged updater: `needsadmin=true` means machine, `false` means user, and `prefers` allows elevation or user fallback. For `prefers`, duplicate entries only when a deterministic scope switch for that exact package is proven.
- Plain `--silent` intentionally suppresses Chromium Updater UAC and fails when elevation is required; only `--silent=allow-uac` permits the updater to prompt. When an MSI launches Chromium Updater, the outer Windows Installer may elevate independently. Use the [MSI scope and elevation](../msi-wix/scope-and-elevation.md#chromium-enterprise-msi-wrappers) to distinguish the MSI prompt, immediate custom actions, and deferred nested execution.
- Microsoft documents both per-user and per-machine installation for the latest WebView2 bootstrapper and standalone installer. Elevation selects machine scope; a pre-existing machine Edge Updater may replace a requested user installation with machine scope.
- Determine target architecture from the embedded/downloaded installer and installed binaries, not from an x86 updater stub.

## Compare only the matching variant

- `Google.Chrome.EXE`: upstream-style bare mini-installer; current uncompressed packages contain `BN/CHROME.7Z` and `BN/SETUP.EXE`.
- Chrome consumer download bootstrapper: tagged Chromium Updater with Chrome `appguid` and `needsadmin=prefers`; test the current official `chrome_installer.exe`, not only the untagged updater package.
- `Google.GoogleUpdater` `1.3.35.452` and `1.3.36.372`: untagged Omaha runtime installers containing resource `B/102`; the first TAR executable is `GoogleUpdate.exe`.
- `Google.GoogleUpdater` `126.0.6441.0` and later: untagged Chromium Updater packages containing `updater.packed.7z`.
- `Brave.Brave`, `Brave.Brave.Beta`, `Brave.Brave.Dev`, and `Brave.Brave.Nightly`: current standalone setups are tagged Omaha wrappers with an offline manifest and embedded browser installer. Use the offline manifest for target version and execution evidence, but retain existing or VM-observed ProductCodes.
- Brave online channel installers: small tagged Omaha wrappers without `OfflineManifest.gup`; updater identity does not prove target version or ProductCode.
- `Brave.BraveOrigin.Nightly`: do not infer its ARP key from the Origin app GUID or embedded constants. Use accepted manifest or VM evidence.
- `Microsoft.EdgeWebView2Runtime`: Microsoft Edge tagged Omaha standalone installer with `OfflineManifest.gup`; accepted silent command is `/silent /install`. The parser returns target version and action evidence but leaves ProductCode unresolved.
- `Perplexity.Comet`: tagged Chromium Updater offline bundle. Its nested `OfflineManifest.gup` selects and hash-verifies `mini_installer.exe`; ProductCode still requires accepted manifest or VM evidence.
- `Vivaldi.Vivaldi` and `Vivaldi.Vivaldi.Snapshot`: branded Chromium mini-installers containing `VIVALDI.PACKED.7Z` and `SETUP.EX_`, using `--vivaldi-silent` and `--vivaldi-install-dir`. Do not substitute upstream switches or derive ProductCode from Vivaldi's product-specific constants.
- `360.360SE`: vendor setup using `--silent-install` and `--install-path`.
- `360.360Chrome.X`: vendor setup using `--silent-install` and `--install-path`.
- `360.360Chrome`: vendor Chromium setup; verify current switches and scope.
- `360.360GT`: vendor setup using Chromium-derived silent/install-path switches.
- `360.360Ent`: vendor setup using Chromium-derived silent/install-path switches.
- `Zoho.Ulaa`: Chromium-derived setup; existing manifests use no generic silent switch.
- `NetEase.MailMaster`: Chromium-derived machine setup using `--silent-install` and `--do-not-launch-master`.
- `Maxthon.Maxthon`: vendor setup with package-specific accepted switch spelling; never normalize it from upstream assumptions.
- `Ecosia.EcosiaBrowser`: user-scope Chromium-derived setup with package-specific custom switch evidence.
- `BrowserOS.BrowserOS`: Chromium-derived setup; existing manifests do not prove a universal silent switch.
- `Alex313031.Thorium`: Chromium-derived setup with artifact/CPU variants; inspect the selected asset.
- `Phoenix.TheWorld`: Chromium-derived setup with package-specific `--silent` evidence.

## Validate vendor-specific behavior

The comment `# Chromium Setup` in winget-pkgs is useful search evidence but does not prove which of the three formats a current artifact uses. Re-run `Get-ChromiumSetupInfo` for every new artifact and preserve vendor-specific switch spelling exactly.
