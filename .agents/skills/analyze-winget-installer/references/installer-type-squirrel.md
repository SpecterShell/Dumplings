# Squirrel And Velopack Installer Type

## When To Use

Use `InstallerType: exe` with a family comment such as `# Squirrel` or `# Velopack` when WinGet invokes a Squirrel.Windows or Velopack setup EXE.

## Detection

Route here when `Test-SquirrelInstaller` or `Get-SquirrelInfo` succeeds, when the EXE contains Squirrel DATA resource ID `131`, or when static payload inspection finds embedded `.nupkg`, `.nuspec`, or `RELEASES` metadata consistent with Squirrel/Velopack.

Do not route here from `--silent` alone; unrelated installers use the same switch.

## Binary Structure

Squirrel.Windows stores an update ZIP in PE `DATA` resource ID `131` in the canonical layout. Velopack commonly stores a referenced nupkg/ZIP range in the launcher bundle header. A bounded ZIP fallback is used only when its nuspec structure validates the candidate.

```text
Squirrel PE setup
`-- .rsrc/DATA/#131
    `-- ZIP
        +-- *.nupkg -> ZIP -> *.nuspec
        `-- RELEASES / package payload

Velopack PE setup
`-- bundle locator
    +-- PayloadOffset, int64 LE      16 bytes before signature
    +-- PayloadLength, int64 LE
    +-- 32-byte Velopack signature
    `-- [PayloadOffset, Length] -> nupkg/ZIP
```

Velopack's signature is `94 F0 B1 7B 68 93 E0 29 37 EB 34 EF 53 AA E7 D4 2B 54 F5 70 7E F5 D6 F5 78 54 98 3E 5E 94 ED 7D`. Resource and locator ranges are absolute after PE RVA mapping. The parser requires a valid ZIP/nupkg and nuspec metadata, bounds candidate count/range extraction, and does not classify from `--silent` or a bare ZIP signature alone.

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

### Validate Launch After Silent Installation

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

### Discord Fresh-Install Caveat

`Discord.Discord` is a known case where a fresh silent installation can leave Discord unable to complete a later normal launch because the suppressed `--squirrel-firstrun` run did not create all Discord-specific first-run state. Community package validation has reproduced a fatal JavaScript `InconsistentInstallerState` failure and uses the versioned `Discord.exe --squirrel-firstrun` invocation as the recovery/diagnostic route. Test the current Discord build rather than assuming the behavior is fixed or universal.

In the VM, first prove that a normal Discord launch fails after silent setup. Preserve the logs and `AfterInstall` snapshot, invoke the latest installed `app-*\Discord.exe` once with `--squirrel-firstrun`, and then retry a normal launch. Capture the resulting `AfterFirstRun` state. If that sequence fixes launch, report the exact created or modified files from the comparison; do not label them as a version database unless the observed file format or Discord logs prove that identity.

### Known Squirrel And Velopack Layouts

- `Atlassian.Sourcetree`: nested `SourceTree-<version>-full.nupkg` inside the setup EXE; `ProductCode` is `SourceTree`.
- `Dialpad.Dialpad`: nested `dialpad-<version>-full.nupkg` inside the setup EXE; `ProductCode` is `dialpad`.
- `Element.Element`: nested `element-desktop-<version>-full.nupkg` inside the setup EXE; `ProductCode` is `element-desktop`.
- `Sogelink.Appeee`: direct nuspec-style ZIP payload inside the setup EXE; `ProductCode` is `Appeee`.
- `Amazon.Chime`: Squirrel.Windows setup resource ZIP with nested `AmazonChime-<version>-full.nupkg`; `ProductCode` is `AmazonChime`.
- `Toggl.TogglTrack`: Squirrel.Windows setup resource ZIP with nested `TogglTrack-<version>-full.nupkg`; `ProductCode` is `TogglTrack`.
- `SlackTechnologies.Slack`: nested `slack-<version>-full.nupkg` inside the setup EXE; `ProductCode` is `slack`.
- `Figma.Figma`: nested `Figma-<version>-full.nupkg` inside the setup EXE; `ProductCode` is `Figma`.
- `Discord.Discord`: nested `Discord-<version>-full.nupkg` inside the setup EXE; `ProductCode` is `Discord`. Fresh silent installs require the launch validation and `--squirrel-firstrun` diagnostic described above.

## Implementation Sources

- [Squirrel.Windows](https://github.com/Squirrel/Squirrel.Windows)
- [Velopack](https://github.com/velopack/velopack)
