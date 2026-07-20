# Zero Install Installer Type

## When To Use

Use `InstallerType: exe` with `# Zero Install` when WinGet invokes a managed Zero Install bootstrapper bound to an application feed. `DeepL.DeepL` is the principal accepted package example.

Do not classify the generic `0install.exe` or `zero-install.exe` launchers as a package-specific installer unless their embedded bootstrap configuration identifies an application feed.

## Detection

Route here when `Test-ZeroInstallInstaller` or `Get-ZeroInstallInfo` succeeds. The decisive evidence is the embedded CLR manifest resource named `ZeroInstall.BootstrapConfig.ini`; strings such as `Zero Install`, `--silent`, or a .NET PE alone are not sufficient.

```powershell
. .\Modules\PackageModule\Index.ps1

$Analysis = Get-WinGetInstallerAnalysis -Path $InstallerPath
$Info = Get-ZeroInstallInfo -Path $InstallerPath
```

The parser reads the assembly metadata with `PEReader`. It never loads the assembly, invokes the installer, or contacts the feed.

At runtime, the upstream bootstrapper gives an adjacent same-basename `.ini` file precedence over the embedded resource. `Get-ZeroInstallInfo` follows that rule when the sidecar is present, while retaining `EmbeddedBootstrapConfig` as evidence. For a ZIP distribution, analyze the EXE only after extracting it beside its shipped INI; for a direct EXE download, do not invent or retain a local sidecar.

## Binary Structure

The bootstrapper is a managed PE. `IMAGE_COR20_HEADER.ResourcesDirectory` points to one CLR resource blob, while rows in the CLR `ManifestResource` table identify records relative to that blob.

```text
managed PE image
+-- DOS/PE headers and section table
+-- IMAGE_COR20_HEADER
|   `-- ResourcesDirectory RVA/Size
+-- CLR metadata streams
|   +-- #Strings heap
|   `-- ManifestResource table
|       +-- Offset:u32 -> relative resource record offset
|       +-- Attributes
|       +-- Name -> #Strings
|       `-- Implementation = nil for embedded data
`-- CLR managed-resource blob
    +-- ResourceLength:u32 LE
    `-- ResourceData[ResourceLength]
```

The application bootstrapper resources consumed by Dumplings are layered as follows:

```text
ZeroInstall.BootstrapConfig.ini (UTF-8)
+-- [global]
|   `-- self_update_uri, feed_mirror, ...
`-- [bootstrap]
    +-- app_uri, app_name, app_args
    +-- integrate_args, catalog_uri
    +-- key_fingerprint
    `-- customizable_store_path, estimated_required_space

ZeroInstall.content.*
+-- signed feed XML or OpenPGP key
+-- icon/archive content
`-- <digest>_<filename>.exe desktop-integration stub
```

All resource offsets are relative to the CLR resource directory until mapped to absolute PE file offsets. Each selected record must fit inside both that directory and the file. Dumplings limits resource count, individual size, cumulative expansion, XML size, and extraction paths.

## Manifest Shape

Zero Install is a generic EXE type to WinGet, so its modes and switches must be authored explicitly. A GUI application bootstrapper with `integrate_args` supports user and machine integration; duplicate the installer entry by scope.

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # Zero Install
  Scope: user
  InstallModes:
  - interactive
  - silent
  - silentWithProgress
  InstallerSwitches:
    Silent: --verysilent
    SilentWithProgress: --silent
    InstallLocation: --store-path="<INSTALLPATH>"
  UpgradeBehavior: install
  ProductCode: https%3a##example.com#feeds#product.xml
  InstallerUrl: https://example.com/ProductSetup.exe
  InstallerSha256: <SHA256>
- Architecture: x64
  InstallerType: exe # Zero Install
  Scope: machine
  InstallModes:
  - interactive
  - silent
  - silentWithProgress
  InstallerSwitches:
    Silent: --verysilent
    SilentWithProgress: --silent
    InstallLocation: --store-path="<INSTALLPATH>"
    Custom: --machine
  UpgradeBehavior: install
  ProductCode: https%3a##example.com#feeds#product.xml
  InstallerUrl: https://example.com/ProductSetup.exe
  InstallerSha256: <SHA256>
```

Omit `InstallLocation` when `CustomizableStorePath` is false. A CLI application bootstrapper supports `--silent` but not GUI-only `--verysilent`; use the exact `InstallModes` and `InstallerSwitches` returned by the parser. A generic launcher without `app_uri` has no package-specific manifest shape.

## Step-By-Step Static Parsing

### Step 1: Parse The Bootstrapper Once

Call `Get-ZeroInstallInfo` once and reuse the object. Do not call individual `Read-*FromZeroInstall` helpers after obtaining the same information. Check `ConfigurationSource`; an adjacent INI changes the effective runtime configuration.

```powershell
$Info = Get-ZeroInstallInfo -Path $InstallerPath
$Info | Select-Object AppUri, AppName, ProductCode, Scope, SupportedScopes,
  InstallModes, InstallerSwitches, WritesAppsAndFeaturesEntry
```

`ProductCode` is the canonical `app_uri` transformed with Zero Install's Windows `PrettyEscape` rules: `/` becomes `#`, `:` becomes `%3a`, and other non-alphanumeric characters use lowercase percent-hex encoding.

### Step 2: Retrieve And Convert The Feed In The Task

The parser does not fetch feeds. Retrieve `AppUri` in the task so package-specific headers, cookies, parameters, proxy, retry, and fallback behavior remain under task control, then pass the raw XML string:

```powershell
$FeedResponse = Invoke-WebRequest -Uri $Info.AppUri
$Info = Get-ZeroInstallInfo -Path $InstallerPath -FeedContent $FeedResponse.Content

$Info.FeedInfo | Select-Object Name, Publisher, Architectures, Protocols, FileExtensions
$Info.FeedInfo.StableImplementations | Select-Object Version, Released, Architecture, ArchiveUrl
```

Do not assume the numerically highest feed record is the implementation that every client receives. The 0install solver also considers architecture, dependencies, stability policy, and rollout percentage. Automation must apply the package's established release-selection policy explicitly.

### Step 3: Resolve Scope And ARP Ownership

When `integrate_args` is present, the bootstrapper calls `0install integrate` and writes a visible uninstall entry under HKCU by default. `--machine` selects HKLM. The uninstall key is the escaped feed URI and therefore supplies `ProductCode` for both scope entries.

When `integrate_args` is absent, the bootstrapper only downloads or runs the target and does not prove an ARP entry. Do not invent `ProductCode`, `Scope`, or `AppsAndFeaturesEntries` in that case.

Zero Install desktop integration writes `DisplayName` and `Publisher` from the feed but does not write `DisplayVersion`. `DeepL.DeepL` is known to update `DisplayVersion` through application behavior; that value is not static bootstrapper evidence.

### Step 4: Inspect Embedded Content When Needed

List embedded resources from `$Info.EmbeddedResources` or export bounded selections:

```powershell
$Files = Expand-ZeroInstallInstaller -Path $InstallerPath -DestinationPath $Destination
$ConfigOnly = Expand-ZeroInstallInstaller -Path $InstallerPath -DestinationPath $OtherDestination -Name 'BootstrapConfig.ini'
```

Embedded `ZeroInstall.content.*` files seed feeds, archives, icons, keys, or desktop-integration stubs. Their physical presence does not prove which target implementation the feed solver will select.

## Apps And Features

For configured integration, the visible entry uses:

- `ProductCode`: escaped canonical feed URI.
- `DisplayName`: feed `<name>`.
- `Publisher`: feed `<publisher>` when present.
- `Scope`: user by default, machine with `--machine`.
- `InstallerType`: generic EXE; no `WindowsInstaller=1` evidence.

Do not duplicate `AppsAndFeaturesEntries.ProductCode` when installer-level `ProductCode` already matches. Add `AppsAndFeaturesEntries` only when the visible ARP name, publisher, or installer type meaningfully differs from authored manifest identity.

## Validation Notes

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md). For Zero Install specifically, validate both configured scopes, confirm that `--silent` and `--verysilent` do not launch the target, capture the final ARP `DisplayVersion`, and determine whether protocols or file extensions appear only after the application first runs.

Also verify that the mutable feed and bootstrapper still correspond. A feed URI or bootstrapper ETag/hash change can be update evidence even when only one of them changes.

## Known Examples

- `DeepL.DeepL`: GUI application bootstrapper, x64 feed, user/machine integration, customizable store path, and `deepl` URL protocol in the feed.

## Implementation Sources

- [0install/0install-win](https://github.com/0install/0install-win): bootstrap configuration, argument handling, and embedded-content behavior.
- [0install/0install-dotnet](https://github.com/0install/0install-dotnet): feed model, URI escaping, desktop integration, and Windows uninstall-entry behavior.
- [Zero Install feed specification](https://docs.0install.net/specifications/feed/)
- [Zero Install on Windows](https://docs.0install.net/details/windows/)
