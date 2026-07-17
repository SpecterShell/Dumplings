# Chromium Setup

## When To Use

Use `InstallerType: exe` for Chromium-family setup executables, but first distinguish three different technologies:

1. **Chromium mini-installer**: the bare installer that embeds `setup.exe` and `chrome.7z` resources.
2. **Chromium/Google Updater**: the current updater metainstaller, either installed as `Google.GoogleUpdater` or tagged to download and install an application.
3. **Google Update/Omaha**: the previous updater/metainstaller design, also used by derivatives such as current Brave standalone setup.

These formats share history and some command-line concepts, but they are not interchangeable and vendor forks frequently customize switches.

## Detection

Run the static parser first:

```powershell
$Info = Get-ChromiumSetupInfo -Path $InstallerFile
$Info.Variant
$Info.UpdaterTag
$Info.ExecutedPayloads
```

Strong resource evidence is:

| Variant | PE resource evidence |
| --- | --- |
| `ChromiumMiniInstaller` | One non-setup `B7` or `BN` `.7z` resource plus a setup resource. Source-defined setup precedence is `B7` (`setup*.7z`), then `BL` (`setup.ex_`), then `BN` (`setup.exe`) |
| `ChromiumUpdater` | `B7` resource named `updater.packed.7z`; its archive contains `updater.7z`, whose launcher is `bin\updater.exe` |
| `Omaha` | `B` resource ID `102` containing LZMA + BCJ2 + TAR payload data, with updater identity/tag evidence |

`Read-ChromiumInstallerTag` searches only the Authenticode certificate table. It supports Omaha's length-framed UTF-8 `Gact2.0Omaha` tag, Chromium Updater's source-defined wide `Gact2.0Omaha...ahamO0.2tcaG` framing, and Microsoft Edge's bounded UTF-16 `MSEDGE_..._EGDESM` tag. The `appguid` is updater protocol identity, **not** an ARP `ProductCode`. It may select a separately proven uninstall key, however: Brave's source defines exact app GUID-to-uninstall-key mappings, while Microsoft documents the WebView2 client GUID and scope registry paths. `Get-ChromiumSetupInfo` returns their separate ARP keys as `ProductCode` without using the GUID itself as the value.

Primary source references:

- [Chromium mini-installer source](https://chromium.googlesource.com/chromium/src/+/main/chrome/installer/mini_installer/)
- [Chromium installer constants](https://source.chromium.org/chromium/chromium/src/+/main:chrome/installer/util/util_constants.cc)
- [Chromium Updater functional specification](https://chromium.googlesource.com/chromium/src/+/57d342625c/docs/updater/functional_spec.md)
- [Chromium Updater source](https://source.chromium.org/chromium/chromium/src/+/main:chrome/updater/)
- [Google Omaha source](https://github.com/google/omaha)

## Manifest Shape

### Bare Chromium Mini-Installer

Upstream Chromium mini-installer defaults to user scope and accepts `--system-level` for machine scope. Silent installation does not necessarily require a separate silent switch; package-specific switches are forwarded to nested `setup.exe`.

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # Chromium Setup
  Scope: user
  InstallerUrl: https://example.com/mini_installer.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - silent
  InstallerSwitches:
    Custom: --do-not-launch-chrome
    Log: --verbose-logging --log-file="<LOGPATH>"
  ProductCode: <VerifiedArpKey>
- Architecture: x64
  InstallerType: exe # Chromium Setup
  Scope: machine
  InstallerUrl: https://example.com/mini_installer.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - silent
  InstallerSwitches:
    Custom: --do-not-launch-chrome --system-level
    Log: --verbose-logging --log-file="<LOGPATH>"
  ProductCode: <VerifiedArpKey>
```

The `Custom` values are Chrome examples, not universal Chromium defaults. Keep scope-specific `Custom` atoms on each installer entry; Dumplings can hoist only identical nested dictionary values.

### Current Google Updater Package

For the updater itself, current accepted `Google.GoogleUpdater` manifests use:

```yaml
Installers:
- Architecture: x86
  InstallerType: exe # Chromium Updater
  Scope: user
  InstallerSwitches:
    Silent: --install --silent
    SilentWithProgress: --install --silent
    Interactive: --install
    Log: --enable-logging
    Upgrade: --update
    Custom: --enterprise
- Architecture: x86
  InstallerType: exe # Chromium Updater
  Scope: machine
  InstallerSwitches:
    Silent: --install --silent
    SilentWithProgress: --install --silent
    Interactive: --install
    Log: --enable-logging
    Upgrade: --update
    Custom: --system --enterprise
```

Do not use this snippet for a tagged Chrome/other-application bootstrapper without verifying how the downloaded target installer receives its switches.

### Legacy Google Update/Omaha Package

The first two `Google.GoogleUpdater` versions in winget-pkgs, `1.3.35.452` and `1.3.36.372`, are untagged Omaha runtime installers rather than Chromium Updater. Their scope-specific commands are:

```yaml
Installers:
- Architecture: x86
  InstallerType: exe # Omaha
  Scope: user
  InstallerSwitches:
    Silent: /silent
    SilentWithProgress: /silent
    Custom: /install "runtime=true" /enterprise
- Architecture: x86
  InstallerType: exe # Omaha
  Scope: machine
  InstallerSwitches:
    Silent: /silent
    SilentWithProgress: /silent
    Custom: /install "runtime=true&needsadmin=true" /enterprise
```

Both installers contain PE resource `B/102`, decode through LZMA + BCJ2 + TAR, and place `GoogleUpdate.exe` first in TAR execution order. Do not replace these Omaha slash switches with Chromium Updater `--system` switches.

### Tagged Online Or Offline Application Bootstrapper

There is no safe universal snippet. A tag does not prove that the wrapper is online-only. For Omaha, first inspect `OfflineManifest.gup`: when present, it identifies the target version, package name, hash, size, action executable, arguments, and elevation requirement. When absent, read the tag, expand the embedded updater, capture its download, and validate the target application's final installer and ARP entry. Omaha/Updater command lines can describe updater installation while the tag selects a different application payload.

## WinGet Defaults And Overrides

WinGet supplies no switches or install modes for generic `InstallerType: exe`. Every Chromium mini-installer, Updater, Omaha, and vendor-fork switch in the selected shape is a complete package-specific override. Remove unsupported fields, keep launch suppression in `Custom`, and never substitute switches from another variant.

## Step-By-Step Analysis

### Step 1: Parse And Expand The Updater Variant

```powershell
$Info = Get-ChromiumSetupInfo -Path $InstallerFile
$Info.Variant
$Info.UpdaterTag
$Info.OfflineManifest
```

Use the aggregate result throughout the analysis. Do not call the scalar `Read-*` or `Test-*` helpers after `Get-ChromiumSetupInfo`; they are alternatives for callers that need only one value. Expand only when nested payload evidence is required:

```powershell
$Files = Expand-ChromiumSetupInstaller -Path $InstallerFile -DestinationPath $DestinationPath
```

Expansion is source-backed and bounded:

- `BN`/`BD` resources are exported directly.
- `BL` resources are decoded as cabinets.
- `B7` resources are opened with the bundled SharpCompress library; Chromium Updater's nested `updater.7z` is opened recursively so `bin\updater.exe` can be selected directly.
- Branded mini-installers may replace `CHROME.PACKED.7Z` with a product name such as Vivaldi's `VIVALDI.PACKED.7Z`. Identify this layout from one non-setup/non-updater `B7` or `BN` archive paired with a `B7`, `BL`, or `BN` setup resource; do not require the `CHROME` prefix.
- Omaha resource `102` is decoded as LZMA, four-stream BCJ2, then TAR according to Omaha's metainstaller build pipeline. Declared compressed and expanded sizes are enforced, and the Omaha stub executes the first EXE in TAR order.
- For tagged Omaha, `Get-ChromiumSetupInfo` reads and parses `OfflineManifest.gup` directly from the decoded TAR under the same bounds. `IsOnlineBootstrapper` is true only after a tagged payload was checked and no offline target manifest was found; it is null when that check fails. A tagged Chromium Updater is online because its selected archive contains the updater rather than the target application.

No installer, updater, 7-Zip, or NanaZip process is invoked.

### Step 2: Identify The Target And Visible ARP Owner

The outer updater/metainstaller may not be the final application's ARP writer.

- Bare mini-installer: nested `setup.exe` normally writes the browser ARP entry; obtain ProductCode/display evidence from explicit setup behavior or VM ARP delta.
- Google Chrome mini-installer: resolve the command-line-selected ARP key from the already parsed result and manifest switches:

  ```powershell
  $ProductCode = Resolve-ChromiumSetupProductCode -Info $Info -InstallerSwitches $Installer.InstallerSwitches
  ```

  `--chrome-sxs`, `--chrome-beta`, and `--chrome-dev` select `Google Chrome SxS`, `Google Chrome Beta`, and `Google Chrome Dev`; an unqualified Google Chrome mini-installer selects `Google Chrome`. Vivaldi's exact PE branding plus `VIVALDI.PACKED.7Z` resolves to its shared `Vivaldi` ARP key. Do not infer ProductCode for other vendor forks without equally explicit evidence.
- Untagged updater package: model the updater's own ARP entry.
- Tagged Updater/Omaha: model the target application's visible ARP entry, not `appguid`. Use a source-defined mapping such as Brave's only when it maps the updater identity to a separate literal uninstall key.
- Tagged Omaha with `OfflineManifest.gup`: use `OfflineManifest.Version` as target-version evidence and inspect `Packages` and `InstallAction` before expanding the selected payload.
- `Microsoft.EdgeWebView2Runtime`: the signed UTF-16 Edge tag selects app GUID `{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}` from a multi-application offline manifest. The parser returns `Microsoft EdgeWebView`, the selected WebView2 action, and the target runtime version. Do not select the first manifest application.
- Tagged updater without an offline manifest: the outer PE product version belongs to the updater. Do not use it as the target package version; obtain target-version evidence from the downloaded installer/feed or VM traffic.
- If the target is downloaded at runtime, static analysis cannot prove the final installer version, ARP type, or associations. Capture the updater traffic and validate in the VM.

### Step 3: Determine Scope And Target Architecture

- Bare mini-installer: default user, `--system-level` machine.
- Untagged Chromium Updater: default user, `--system` machine.
- Untagged Omaha runtime package: user `/install "runtime=true" /enterprise`; machine `/install "runtime=true&needsadmin=true" /enterprise`.
- Tagged updater: `needsadmin=true` means machine, `false` means user, and `prefers` allows elevation or user fallback. For `prefers`, duplicate entries only when a deterministic scope switch for that exact package is proven.
- Microsoft documents both per-user and per-machine installation for the latest WebView2 bootstrapper and standalone installer. Elevation selects machine scope; a pre-existing machine Edge Updater may replace a requested user installation with machine scope.
- Determine target architecture from the embedded/downloaded installer and installed binaries, not from an x86 updater stub.

### Step 4: Compare Only The Matching Variant

- `Google.Chrome.EXE`: upstream-style bare mini-installer; current uncompressed packages contain `BN/CHROME.7Z` and `BN/SETUP.EXE`.
- Chrome consumer download bootstrapper: tagged Chromium Updater with Chrome `appguid` and `needsadmin=prefers`; test the current official `chrome_installer.exe`, not only the untagged updater package.
- `Google.GoogleUpdater` `1.3.35.452` and `1.3.36.372`: untagged Omaha runtime installers containing resource `B/102`; the first TAR executable is `GoogleUpdate.exe`.
- `Google.GoogleUpdater` `126.0.6441.0` and later: untagged Chromium Updater packages containing `updater.packed.7z`.
- `Brave.Brave`, `Brave.Brave.Beta`, `Brave.Brave.Dev`, and `Brave.Brave.Nightly`: current standalone setups are tagged Omaha wrappers with an offline manifest and embedded browser installer. The parser maps their source-defined app GUIDs to `BraveSoftware Brave-Browser*` uninstall keys.
- Brave online channel installers: small tagged Omaha wrappers without `OfflineManifest.gup`; test at least one regular channel and one Origin channel so online/offline handling and both source-defined app-ID namespaces remain covered.
- `Brave.BraveOrigin.Nightly`: uses the source-defined `BraveSoftware Brave-Origin-Nightly` uninstall key. Brave source also defines parallel Origin stable, beta, and dev identities, although they are not separate current WinGet package IDs. Verify current packaging because vendor formats can change.
- `Microsoft.EdgeWebView2Runtime`: Microsoft Edge tagged Omaha standalone installer with `OfflineManifest.gup`; accepted silent command is `/silent /install`, and the parser resolves the documented WebView2 app identity rather than the outer updater version.
- `Vivaldi.Vivaldi` and `Vivaldi.Vivaldi.Snapshot`: branded Chromium mini-installers containing `VIVALDI.PACKED.7Z` and `SETUP.EX_`, using `--vivaldi-silent` and `--vivaldi-install-dir`; do not substitute upstream switches.
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

### Step 5: Validate Vendor-Specific Behavior

The comment `# Chromium Setup` in winget-pkgs is useful search evidence but does not prove which of the three formats a current artifact uses. Re-run `Get-ChromiumSetupInfo` for every new artifact and preserve vendor-specific switch spelling exactly.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) for vendor-specific silent/no-launch switches, user-versus-system installation, updater/bootstrapper payload selection, and visible ARP behavior.

## Implementation Sources

- [Chromium](https://chromium.googlesource.com/chromium/src)
- [Chromium mini-installer selection](https://chromium.googlesource.com/chromium/src/+/main/chrome/installer/mini_installer/mini_installer.cc)
- [Chromium mini-installer resource constants](https://chromium.googlesource.com/chromium/src/+/main/chrome/installer/mini_installer/mini_installer_constants.cc)
- [Chromium Updater tag format](https://chromium.googlesource.com/chromium/src/+/main/chrome/updater/tag.h)
- [Google Omaha](https://github.com/google/omaha)
- [Omaha certificate tag parsing](https://github.com/google/omaha/blob/main/omaha/base/apply_tag.cc)
- [Omaha metainstaller payload build](https://github.com/google/omaha/blob/main/omaha/installers/build_metainstaller.py)
- [Brave Chromium install modes](https://github.com/brave/brave-core/tree/master/chromium_src/chrome/install_static)
- [Microsoft WebView2 Runtime distribution](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution)
