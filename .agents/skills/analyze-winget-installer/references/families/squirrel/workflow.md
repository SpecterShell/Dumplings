# Squirrel and Velopack workflow

## When to use

Use `InstallerType: exe` with a family comment such as `# Squirrel` or `# Velopack` when WinGet invokes a Squirrel.Windows or Velopack setup EXE.

## Detection

Route here when `Test-SquirrelInstaller` or `Get-SquirrelInfo` succeeds. `Get-SquirrelInfo` reports `Family: Squirrel` only when PE resource `DATA/#131` validates, and reports `Family: Velopack` only when the Velopack offset/length locator, signature, and bounded package payload validate. Embedded `.nupkg` or `.nuspec` metadata without either outer structure is reported as `Squirrel/Velopack` and does not prove the launcher's switches.

Do not route here from `--silent` alone; unrelated installers use the same switch.

## Static analysis

Read [Squirrel And Velopack Installer Type Parser Internals](../../internals/squirrel/overview.md) before changing detection, extraction, binary decoding, or parser limits.

### Parse embedded package and feed evidence

Use `Get-WinGetInstallerAnalysis` for the first pass, or call `Test-SquirrelInstaller` and `Get-SquirrelInfo` from `Modules\PackageModule\Libraries\Installers\Squirrel.psm1`. Parse the installer once and reuse the result for ARP identity. The parser is implemented directly in PackageModule under the project license and does not require the GPL installer parser bridge.

Static parser workflow:

```powershell
. .\Modules\PackageModule\Index.ps1

$Analysis = Get-WinGetInstallerAnalysis -Path $InstallerPath
$ParserResult = $Analysis.ParserResults | Where-Object { $_.Name -eq 'Squirrel/Velopack' -and $_.Success } | Select-Object -First 1
$Info = $ParserResult.Result.Metadata
$Info | Select-Object Family, DetectionRoute, Confidence, PackageId, ProductCode, DisplayName, DisplayVersion, Publisher
$Info.InstallModes
$Info.InstallerSwitches
$Analysis.SuggestedManifestFields
$Analysis.SuggestedManifestVariants
```

If a task uses a Squirrel `RELEASES` feed for update detection, fetch the feed in the task with the package-specific headers, query parameters, cookies, or fallback URL handling that the vendor requires. Use `Invoke-WebRequest | Read-ResponseContent` rather than `Invoke-RestMethod`, because most `RELEASES` feeds are UTF-8 with BOM and `Read-ResponseContent` handles the BOM correctly. Then pass only the already-fetched string to the Squirrel module:

```powershell
$ReleasesContent = Invoke-WebRequest -Uri $ReleasesUri -Headers $Headers | Read-ResponseContent
$LatestRelease = $ReleasesContent | ConvertFrom-SquirrelReleases | Where-Object -FilterScript { -not $_.IsDelta } | Sort-Object -Property { [RawVersion]$_.Version } -Bottom 1
```

`ConvertFrom-SquirrelReleases` does not access the network. It only parses the content string, preserving absolute feed URL base paths and query strings as evidence.

Prefer the parser result over string probing. The `--silent` switch is common to both families and unrelated installers. The authoritative Squirrel route is PE resource type `DATA`, resource ID `131`, containing valid package metadata. The authoritative Velopack route is the source-defined bundle signature with valid preceding payload offset and length. A direct or nested nuspec found through a generic ZIP scan proves package metadata but does not identify the outer launcher; in that case raw `InstallModes` and `InstallerSwitches` are empty, launcher behavior remains in `UnresolvedFields`, and the WinGet suggestion contains no family-specific behavior. If a `RELEASES` feed is the only Squirrel evidence, use it for update discovery and validate the setup EXE in the VM before writing launcher-specific fields.

A .NET single-file bundle that contains `Squirrel.dll` or `NuGet.Squirrel.dll` is not necessarily a Squirrel setup. The application may use Squirrel as a runtime update client while downloading or constructing package state after launch. `Get-SquirrelInfo` accepts this layout only when the bundle or another validated container exposes nupkg, nuspec, or RELEASES metadata. Microsoft Advertising Editor is a current example: its .NET bundle contains Squirrel libraries but no embedded Squirrel package metadata, so the parser rejects it quickly and VM evidence remains necessary for its installed ARP identity.

### Resolve package identity, scope, and ARP

Squirrel-style installers are usually user-scope and write HKCU ARP entries. Use parser-derived `.nuspec` `id`, title, version, and publisher values for ProductCode/display evidence. VM-check ARP and upgrade behavior when the parser cannot prove the embedded package identity.

The individual readers remain available when a task needs one pipeline-friendly atom, but each reparses the installer. Do not call all of them after `Get-SquirrelInfo`:

```powershell
$ProductCode = $InstallerPath | Read-ProductCodeFromSquirrel
$Version = $InstallerPath | Read-ProductVersionFromSquirrel
$Name = $InstallerPath | Read-ProductNameFromSquirrel
$Publisher = $InstallerPath | Read-PublisherFromSquirrel
```

## Manifest shape

Use the Squirrel shape only when `Family` is `Squirrel` and `DetectionRoute` is `SquirrelPeResource`:

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # Squirrel
  Scope: user
  InstallerUrl: https://example.com/ProductSetup-1.2.3.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  InstallerSwitches:
    Silent: --silent
    SilentWithProgress: --silent
  UpgradeBehavior: install
  ProductCode: <ProductCode>
```

Squirrel-style installers are usually per-user and write HKCU ARP entries.

Use the Velopack shape only when `Family` is `Velopack` and `DetectionRoute` is `VelopackBundle`:

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # Velopack
  Scope: user
  InstallerUrl: https://example.com/ProductSetup-1.2.3.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  InstallerSwitches:
    Silent: --silent
    SilentWithProgress: --silent
    InstallLocation: --installto "<INSTALLPATH>"
    Log: --log "<LOGPATH>"
  UpgradeBehavior: install
  ProductCode: <ProductCode>
```

Do not copy either shape from a `Squirrel/Velopack` fallback result. Its `PackageId` and nuspec metadata identify the embedded package, but they do not prove an outer ARP `ProductCode`, scope, installation root, or command line; those fields require stronger static evidence or VM validation.

## WinGet defaults and overrides

WinGet supplies no Squirrel or Velopack defaults for generic `InstallerType: exe`. Both confirmed families map `Silent` and `SilentWithProgress` to `--silent`; Velopack also supports `InstallLocation: --installto "<INSTALLPATH>"` and `Log: --log "<LOGPATH>"`. Do not apply the Velopack-only switches to Squirrel.Windows media.

## Apps & Features

Use structured parser evidence to identify the visible Apps & Features owner. Do not substitute metadata from a hidden or nested payload unless that payload writes the visible uninstall entry.

## Scope and architecture

Use explicit parser evidence for scope and installed payload architecture. Preserve existing manifest intent and use VM validation when either value is conditional or unresolved.

## VM validation

Follow [VM validation workflow](../../workflows/vm-validation.md) when the embedded package identity is unresolved or to verify HKCU ARP registration, `--silent`, upgrade behavior, and first-run associations for the current Squirrel/Velopack generation.

### Validate launch after silent installation

Do not stop after the silent installer exits successfully and writes an ARP entry. From a restored VM checkpoint with no prior application state:

1. Capture `BeforeInstall`, run the installer with the verified `--silent` or `-s` switch, record its exit code, and capture `AfterInstall`.
2. Launch the installed application normally through its generated shortcut, `Update.exe --processStart`, or versioned application executable without adding lifecycle switches.
3. Confirm that the application process remains running and its usable main window opens. A transient process, updater-only process, crash dialog, or exit code `0` from setup is insufficient.
4. Capture `AfterFirstRun` and compare it with `AfterInstall` to identify files, registry values, protocols, and extensions created only when the application starts.
5. If normal launch fails, collect the Squirrel/Velopack setup log and application log before changing state. Then test the family-specific first-run route separately to determine whether skipped first-run initialization caused the failure.

This check is required because both families intentionally suppress the post-install application launch in silent mode:

- Squirrel.Windows still invokes each Squirrel-aware executable with `--squirrel-install <version>`, but it does not perform the final launch with `--squirrel-firstrun` when `silentInstall` is true. The missing lifecycle invocation is therefore `--squirrel-firstrun`, not `--squirrel-install`.
- Velopack still invokes its install hook with `--veloapp-install`, but a non-silent setup is what launches the application with the `VELOPACK_FIRSTRUN` environment variable. Do not translate this environment marker into a manifest command-line switch.

Treat lifecycle invocation as diagnostic evidence, not an outer installer switch. Do not add `--squirrel-firstrun`, `--squirrel-install`, `--veloapp-install`, or a Velopack environment marker to `InstallerSwitches`: WinGet passes installer switches to the setup bootstrapper, while these lifecycle values belong to the installed application.

### Discord fresh-install caveat

`Discord.Discord` is a known case where a fresh silent installation can leave Discord unable to complete a later normal launch because the suppressed `--squirrel-firstrun` run did not create all Discord-specific first-run state. Community package validation has reproduced a fatal JavaScript `InconsistentInstallerState` failure and uses the versioned `Discord.exe --squirrel-firstrun` invocation as the recovery/diagnostic route. Test the current Discord build rather than assuming the behavior is fixed or universal.

In the VM, first prove that a normal Discord launch fails after silent setup. Preserve the logs and `AfterInstall` snapshot, invoke the latest installed `app-*\Discord.exe` once with `--squirrel-firstrun`, and then retry a normal launch. Capture the resulting `AfterFirstRun` state. If that sequence fixes launch, report the exact created or modified files from the comparison; do not label them as a version database unless the observed file format or Discord logs prove that identity.

## Known examples

- `Atlassian.Sourcetree`: nested `SourceTree-<version>-full.nupkg` inside the setup EXE; `ProductCode` is `SourceTree`.
- `Dialpad.Dialpad`: nested `dialpad-<version>-full.nupkg` inside the setup EXE; `ProductCode` is `dialpad`.
- `Element.Element`: nested `element-desktop-<version>-full.nupkg` inside the setup EXE; `ProductCode` is `element-desktop`.
- `Sogelink.Appeee`: Velopack bundle locator and direct nuspec-style package payload; `ProductCode` is `Appeee`.
- `SaaSGroup.Tower`: Velopack bundle locator and direct nuspec-style package payload; `ProductCode` is `Tower`.
- `Amazon.Chime`: Squirrel.Windows setup resource ZIP with nested `AmazonChime-<version>-full.nupkg`; `ProductCode` is `AmazonChime`.
- `Toggl.TogglTrack`: Squirrel.Windows setup resource ZIP with nested `TogglTrack-<version>-full.nupkg`; `ProductCode` is `TogglTrack`.
- `SlackTechnologies.Slack`: nested `slack-<version>-full.nupkg` inside the setup EXE; `ProductCode` is `slack`.
- `Figma.Figma`: nested `Figma-<version>-full.nupkg` inside the setup EXE; `ProductCode` is `Figma`.
- `Discord.Discord`: nested `Discord-<version>-full.nupkg` inside the setup EXE; `ProductCode` is `Discord`. Fresh silent installs require the launch validation and `--squirrel-firstrun` diagnostic described above.
