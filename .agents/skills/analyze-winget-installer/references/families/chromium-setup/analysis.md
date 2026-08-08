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

- Bare mini-installer: nested `setup.exe` normally writes the browser ARP entry. `Get-ChromiumSetupInfo` extracts only the source-selected setup resource and prefers explicit uninstall registry paths. When the generic Chromium uninstall-root literal proves runtime composition, it combines structured updater company/product paths with the validated `kInstallModes` table. A one-component updater root may use the primary `base_app_name` when it already begins with that company; otherwise the parser accepts a product-path candidate only when the direct-launch-derived name or `base_app_name` also exists as a separate, null-terminated wide product constant outside its `InstallConstants` field. `ProductCodeSource` identifies the evidence path, and `NestedSetupInfo.InstallModes` retains selectors and suffixes. Repeated literal uninstall paths outrank incidental keys; ambiguous evidence remains unresolved. Never infer ProductCode from outer PE branding or arbitrary version/display strings.
- Google Chrome mini-installer: resolve the command-line-selected ARP key from the already parsed result and manifest switches:

  ```powershell
  $ProductCode = Resolve-ChromiumSetupProductCode -Info $Info -InstallerSwitches $Installer.InstallerSwitches
  ```

  For current Chrome binaries, the parsed selectors `chrome-sxs`, `chrome-beta`, and `chrome-dev` produce the ` SxS`, ` Beta`, and ` Dev` uninstall suffixes; the primary empty selector has no suffix. These names come from the embedded table, not a Chrome-specific ProductCode map. Explicit nested registry evidence remains stronger for forks such as `Zoho.Ulaa` (`Zoho Ulaa`) and `360.360Ent` (`360ent`). Legacy forks such as Vivaldi are resolved only when their nested setup contains a composed uninstall root, a matching `<product>-install-dir` switch, `Software\<Product>`, and the standalone product-path literal; PE branding and archive names are not ProductCode evidence.
- Untagged updater package: model the updater's own ARP entry.
- Tagged Updater/Omaha: model the target application's visible ARP entry, not `appguid`. With `OfflineManifest.gup`, use `OfflineManifest.Version`, inspect `Packages` and `InstallAction`, and use recursively parsed target evidence. Without that manifest, preserve an existing ProductCode and require feed/download or VM evidence.
- `Microsoft.EdgeWebView2Runtime`: the signed UTF-16 tag selects the matching application and the parser hash-verifies its differently named physical TAR payload before analyzing it. The proprietary nested setup does not expose a structurally tied ARP key, so ProductCode remains unresolved; retain accepted manifest or VM evidence rather than converting its app GUID.
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
- `Brave.Brave`, `Brave.Brave.Beta`, `Brave.Brave.Dev`, and `Brave.Brave.Nightly`: current standalone setups are tagged Omaha wrappers with an offline manifest and embedded browser installer. The parser derives the `BraveSoftware Brave-Browser*` keys from the nested company/product constants and install suffixes, not app-GUID mappings.
- Brave online channel installers: small tagged Omaha wrappers without `OfflineManifest.gup`; their ProductCode is intentionally unresolved because updater identity alone does not prove the ARP key.
- `Brave.BraveOrigin.Nightly`: the corresponding offline Origin target can derive the `BraveSoftware Brave-Origin-Nightly` key from its own embedded constants. Do not infer that key from an online Origin app GUID.
- `Microsoft.EdgeWebView2Runtime`: Microsoft Edge tagged Omaha standalone installer with `OfflineManifest.gup`; accepted silent command is `/silent /install`. The parser returns target version/action evidence but not a ProductCode.
- `Perplexity.Comet`: tagged Chromium Updater offline bundle. Its nested `OfflineManifest.gup` selects and hash-verifies `mini_installer.exe`; the nested setup's updater company path, validated `InstallConstants`, and independent product-path literal derive `ProductCode: Perplexity Comet` without mapping the updater app GUID.
- `Vivaldi.Vivaldi` and `Vivaldi.Vivaldi.Snapshot`: branded Chromium mini-installers containing `VIVALDI.PACKED.7Z` and `SETUP.EX_`, using `--vivaldi-silent` and `--vivaldi-install-dir`; the parser derives `ProductCode: Vivaldi` from the nested setup's composed uninstall root and corroborating product switch/registry-path constants, not from a vendor mapping. Do not substitute upstream switches.
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
