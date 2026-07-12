# Squirrel And Velopack Installer Type

## When To Use

Use `InstallerType: exe` with a family comment such as `# Squirrel` or `# Velopack` when WinGet invokes a Squirrel.Windows or Velopack setup EXE.

## Detection

Route here when `Test-SquirrelInstaller` or `Get-SquirrelInfo` succeeds, when the EXE contains Squirrel DATA resource ID `131`, or when static payload inspection finds embedded `.nupkg`, `.nuspec`, or `RELEASES` metadata consistent with Squirrel/Velopack.

Do not route here from `--silent` alone; unrelated installers use the same switch.

## Manifest Shape

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

Velopack uses a Squirrel-derived layout and may store the nupkg in the overlay. For Velopack, add `InstallLocation: --installto "<INSTALLPATH>"` and `Log: --log "<LOGPATH>"`.

## WinGet Defaults And Overrides

WinGet supplies no Squirrel/Velopack defaults for generic `InstallerType: exe`. Treat `--silent`, Velopack location/log arguments, `InstallModes`, and upgrade behavior as complete family-specific evidence. Remove fields that the detected Squirrel or Velopack generation does not support.

## Step-By-Step Analysis

### Step 1: Parse Embedded Package And Feed Evidence

Use `Get-WinGetInstallerAnalysis` for the first pass, or call `Test-SquirrelInstaller` and `Get-SquirrelInfo` from `Modules\PackageModule\Libraries\Squirrel.psm1`. Parse the installer once and reuse the result for ARP identity. The parser is implemented directly in PackageModule under the project license and does not require the GPL installer parser bridge.

Static parser workflow:

```powershell
. .\Modules\PackageModule\Index.ps1

Test-SquirrelInstaller -Path $InstallerPath
$Info = Get-SquirrelInfo -Path $InstallerPath
$Info | Select-Object ProductCode, DisplayName, DisplayVersion, Publisher
$Info.SuggestedManifestFields
```

If a task uses a Squirrel `RELEASES` feed for update detection, fetch the feed in the task with the package-specific headers, query parameters, cookies, or fallback URL handling that the vendor requires. Use `Invoke-WebRequest | Read-ResponseContent` rather than `Invoke-RestMethod`, because most `RELEASES` feeds are UTF-8 with BOM and `Read-ResponseContent` handles the BOM correctly. Then pass only the already-fetched string to the Squirrel module:

```powershell
$ReleasesContent = Invoke-WebRequest -Uri $ReleasesUri -Headers $Headers | Read-ResponseContent
$LatestRelease = $ReleasesContent | ConvertFrom-SquirrelReleases | Where-Object -FilterScript { -not $_.IsDelta } | Sort-Object -Property { [RawVersion]$_.Version } -Bottom 1
```

`ConvertFrom-SquirrelReleases` does not access the network. It only parses the content string, preserving absolute feed URL base paths and query strings as evidence.

Prefer the parser result over string probing. The `--silent` switch is common for Squirrel, but it is also used by unrelated installers and can produce false positives. Strong static evidence is an embedded `.nupkg` containing `.nuspec`, a direct Squirrel/Velopack nuspec ZIP payload, or the Squirrel.Windows setup resource layout where the update ZIP is stored as PE resource type `DATA` with resource ID `131`. If `Get-SquirrelInfo` fails but the package is still known to be Squirrel from a `RELEASES` feed, use the feed metadata only as update evidence and VM-validate the setup EXE before writing manifest ARP fields.

### Step 2: Resolve Package Identity, Scope, And ARP

Squirrel-style installers are usually user-scope and write HKCU ARP entries. Use parser-derived `.nuspec` `id`, title, version, and publisher values for ProductCode/display evidence. VM-check ARP and upgrade behavior when the parser cannot prove the embedded package identity.

The individual readers remain available when a task needs one pipeline-friendly atom, but each reparses the installer. Do not call all of them after `Get-SquirrelInfo`:

```powershell
$ProductCode = $InstallerPath | Read-ProductCodeFromSquirrel
$Version = $InstallerPath | Read-ProductVersionFromSquirrel
$Name = $InstallerPath | Read-ProductNameFromSquirrel
$Publisher = $InstallerPath | Read-PublisherFromSquirrel
```

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) when the embedded package identity is unresolved or to verify HKCU ARP registration, `--silent`, upgrade behavior, and first-run associations for the current Squirrel/Velopack generation.

### Known Squirrel And Velopack Layouts

- `Atlassian.Sourcetree`: nested `SourceTree-<version>-full.nupkg` inside the setup EXE; `ProductCode` is `SourceTree`.
- `Dialpad.Dialpad`: nested `dialpad-<version>-full.nupkg` inside the setup EXE; `ProductCode` is `dialpad`.
- `Element.Element`: nested `element-desktop-<version>-full.nupkg` inside the setup EXE; `ProductCode` is `element-desktop`.
- `Sogelink.Appeee`: direct nuspec-style ZIP payload inside the setup EXE; `ProductCode` is `Appeee`.
- `Amazon.Chime`: Squirrel.Windows setup resource ZIP with nested `AmazonChime-<version>-full.nupkg`; `ProductCode` is `AmazonChime`.
- `Toggl.TogglTrack`: Squirrel.Windows setup resource ZIP with nested `TogglTrack-<version>-full.nupkg`; `ProductCode` is `TogglTrack`.
- `SlackTechnologies.Slack`: nested `slack-<version>-full.nupkg` inside the setup EXE; `ProductCode` is `slack`.
- `Figma.Figma`: nested `Figma-<version>-full.nupkg` inside the setup EXE; `ProductCode` is `Figma`.
- `Discord.Discord`: nested `Discord-<version>-full.nupkg` inside the setup EXE; `ProductCode` is `Discord`.

## Implementation Sources

- [Squirrel.Windows](https://github.com/Squirrel/Squirrel.Windows)
- [Velopack](https://github.com/velopack/velopack)
