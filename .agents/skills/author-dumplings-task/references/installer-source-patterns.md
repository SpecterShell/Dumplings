# Installer Source Patterns And Example Tasks

## Contents

- [Required Installer Evidence](#required-installer-evidence)
- [Selection Order](#selection-order)
- [Reject Stale Captured Sources](#reject-stale-captured-sources)
- [Example Index](#example-index)
- [HTML Installer Links](#html-installer-links)
- [Select Full Installer Assets](#select-full-installer-assets)
- [GitHub Releases](#github-releases)
- [Sparkle Appcasts](#sparkle-appcasts)
- [Electron-Updater Feeds](#electron-updater-feeds)
- [Squirrel RELEASES](#squirrel-releases)
- [Redirected Installer URLs](#redirected-installer-urls)
- [Custom EXE Wrappers With Nested MSI](#custom-exe-wrappers-with-nested-msi)
- [Shared Provider Tasks](#shared-provider-tasks)
- [Browser-Only Sources](#browser-only-sources)
- [Versionless URLs And Validator Priority](#versionless-urls-and-validator-priority)

## Required Installer Evidence

Version, `RealVersion`, installer URLs, installer selection, architecture, and
required installer downloading or parsing determine whether an update is valid.
Do not place these operations in a recoverable `try`/`catch`. Let failures stop
the task instead of writing or submitting incomplete state.

Discover `Version` and installer URLs before `Check()`. When `RealVersion` is
available only from changed installer bytes, download and parse the registered
installer inside the change branch, but outside every optional-metadata
`try`/`catch`. See
[Release Metadata Patterns](release-metadata-patterns.md) for the separate
failure boundary used by `ReleaseTime`, `ReleaseNotes`, and `ReleaseNotesUrl`.

## Selection Order

Among sources that pass the freshness check below, prefer the least fragile official source that exposes the required facts:

1. Structured vendor or forge API.
2. Product update feed such as electron-updater or Squirrel `RELEASES`.
3. Static HTML download pages.
4. Stable redirect endpoint whose target carries the version.
5. Scoped Playwright when ordinary HTTP cannot expose the version.
6. As a last resort, a versionless installer whose version must be extracted
   from its downloaded bytes, using a response validator as a prefilter.

Fetch source data in the task. Feed converters accept already-retrieved strings
because endpoints may require package-specific headers, cookies, or parameters.

## Reject Stale Captured Sources

Do not assume that an auto-update feed, API request captured from an application, or endpoint discovered in browser traffic is the current release source. During task authoring, compare its latest version with the official download page and, when needed, the version parsed from the page's installer. Compare the same product, channel, architecture, locale, and full-installer class using `[ChunkVersion]`; a beta feed, staged rollout, architecture lag, or regional release is not evidence that the endpoint is stale.

If the captured source remains older after those distinctions are excluded, do not use it as the required `Version` or `InstallerUrl` source in `Script.ps1`. Prefer the download page or the current authoritative endpoint that backs it. Do not combine the newer page version with an older feed URL, and do not wait for the stale feed merely because a structured source normally ranks above HTML. The stale endpoint may still supply optional metadata only when that metadata is explicitly version-matched.

Record the mismatch in the task-authoring evidence. Recheck a captured source when the publisher updates it later; skipping it is a source decision, not a permanent claim that the endpoint is invalid.

## Example Index

| Pattern | Primary examples | What to reuse |
| --- | --- | --- |
| HTML installer links | `HP.HPCMSL`, `Amazon.AppStream`, `Argente.Utilities`, `RawTherapee.RawTherapee` | Link filtering, official URL resolution, and unambiguous installer selection. |
| Redirect target contains version | `360.360Ent`, `Xmind.Xmind`, `Anthropic.Claude` | Resolve without downloading, parse the final official URL, and compare architecture variants. |
| Feed points to an updater artifact | `appmakes.Typora`, `Vivaldi.Vivaldi` | Derive and verify the corresponding full-installer URL instead of submitting the update artifact. |
| Sparkle-style appcast | `AppDynamic.AirServer`, `FlorianHeidenreich.Mp3tag`, `Vivaldi.Vivaldi`, `Readdle.Spark` | `enclosure` version and URL, architecture feeds, full-installer conversion, and `RealVersion`. |
| electron-updater feed | `Adobe.WorkfrontProof`, `7pace.Timetracker`, `Unity.UnityHub` | Feed version, relative URL resolution, dedicated conversion, and multi-architecture selection. |
| GitHub latest release | `qyzhg.Prism`, `1357310795.TboxWebdav`, `7zip.7zip`, `astral-sh.uv` | Tag normalization, exact asset predicates, and architecture mapping. |
| GitHub directory contents | `JurgenRathlev.innounp` | Parse versions from filenames, sort with `[ChunkVersion]`, and pin the selected raw URL to its latest commit SHA. |
| Squirrel `RELEASES` | `Amazon.Chime`, `Amazon.AppStream` | BOM-safe response reading, delta exclusion, and `[ChunkVersion]` sorting. |
| Custom EXE wrapper with nested MSI | `ALTEC.DataPrint`, `Apple.iTunes`, `Maximus5.ConEmu`, `Siemens.JT2Go`, `Foxit.FoxitReader` | Exact 7z payload selection, architecture mapping, raw-section extraction, nested wrapper traversal, MSI/MSP projection, and aggregate MSI parsing. |
| Shared vendor provider | `#Argente` with `Argente.*`; `#JetBrains` with `JetBrains.*` | Three or more consumers of the same source, explicit `DependsOn`, a shared normalized catalog, and variant consistency checks. |
| Browser-only extraction | `BLife.CustomCursor` | Short `Use-PlaywrightPage -Stealth -Headless` lease returning a detached URL. |
| Installer-set replacement | `Xmind.Xmind` | `WinGetReplaceMode`, conditional ARM64 inclusion, and `RealVersion`. |
| Explicit installer query | `RawTherapee.RawTherapee` | Select an existing installer by a `Query` dictionary when task write fields differ. |
| Versionless URL with checksum header | `Altova.XMLSpy.Professional`, `Alibaba.Taobao`, `Alibaba.QwenWork.CN`, `Bazwise.FolderSizeExplorer` | Last-resort detection using `x-amz-meta-sha256`, `Content-MD5`, `x-oss-hash-crc64ecma`, or `x-goog-hash`. |
| Versionless URL with ETag | `ABC.PowerExtension`, `Cjwdev.ADAccountResetTool`, `Amazon.EC2Launch` | Last-resort ETag history, SHA256 confirmation, cached installer reuse, and optional release notes. |
| Versionless URL with Last-Modified | `AnyDesk.AnyDesk`, `BitSum.ProcessLasso.Beta` | Last-resort date comparison, regressed-date warning, and per-architecture validators. |
| Versionless URL with Content-Length | `Ardisk.Ardisk` | Weakest last-resort prefilter followed by a content download and SHA256 comparison. |

Always open the named task directly and read its current `Config.yaml` and
`Script.ps1`. Do not recursively copy a family of scripts merely because this
table names one member.

## HTML Installer Links

`HP.HPCMSL` obtains the installer from `Invoke-WebRequest.Links` and parses the
version from that URL before `Check()`:

```powershell
$Page = Invoke-WebRequest -Uri $DownloadPage
$Links = @($Page.Links.Where({
  try {
    $_.href.EndsWith('.exe') -and $_.href.Contains('product-token') -and $_.href -notmatch 'update|portable'
  } catch {}
}))
if ($Links.Count -ne 1) {
  throw "Expected one installer link, found $($Links.Count)."
}
$Link = $Links[0]

$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = (Join-Uri $DownloadPage $Link.href)
}
```

Filter HTML links using `href`, not a guessed filename property. Start with the
file extension, then add architecture, platform, installer/setup, product, and
exclusion predicates that are present in the URL. Use `Contains('.exe')` or
`Contains('.msi')` instead of `EndsWith()` when the URL has query parameters.
Inspect a parent element only when architecture or product evidence is absent
from `href`.

Use `Join-Uri` for relative links. Require one matching link and verify that it
is official. Handle optional HTML release metadata only after `Check()` by
following [HTML Release Notes](release-metadata-patterns.md#html-release-notes).

## Select Full Installer Assets

Do not submit an update-only artifact as the package installer. Reject names or
URLs that identify `update`, `updater`, delta, auto-update, patch, or portable
artifacts when the package represents the installed desktop application. A
portable asset is valid only for an intentionally portable package; an
electron-builder portable NSIS executable is not the installable NSIS setup.
An updater artifact is valid only when the package itself represents that
updater.

`appmakes.Typora` demonstrates a feed whose `download` fields point to update
artifacts. Its task replaces `update` with `setup` for every architecture and
locale. `Vivaldi.Vivaldi` replaces `stable-auto` with `stable`. Treat such
rewrites as source-specific rules: probe every derived URL, verify its version
and architecture, and confirm that it is a full installer before using it.

For release pages with several artifacts, list the candidate names before
writing the filter. Do not select the first `.exe`, `.msi`, or `.zip` and assume
it is suitable.

## GitHub Releases

Use the authenticated proxy rather than raw GitHub REST calls:

```powershell
$Release = Invoke-GitHubApi -Uri "https://api.github.com/repos/owner/repository/releases/latest"
$this.CurrentState.Version = $Release.tag_name -creplace '^v'

$Candidates = @($Release.assets.Where({
  $_.name.EndsWith('.msi') -and $_.name.Contains('x64') -and $_.name -match 'Prism' -and $_.name -notmatch 'debug|portable|update'
}))
if ($Candidates.Count -ne 1) {
  throw "Expected one x64 MSI asset, found $($Candidates.Count)."
}
$Asset = $Candidates[0]

$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = $Asset.browser_download_url | ConvertTo-UnescapedUri
}
```

Build each candidate predicate in this order, using only facts present in the
real name or URL. GitHub release assets use `name`; objects from
`Invoke-WebRequest.Links` use `href`.

1. Require the extension with `EndsWith('.exe')`, `EndsWith('.msi')`, or the
   expected archive suffix. If a page-link URL has query parameters, use
   `Contains('.exe')` or `Contains('.msi')` against `href` instead.
2. Require the source architecture token when one is present. Use it to narrow
   candidates, but write WinGet `Architecture` only after the installer or
   payload confirms the architecture.
3. For archives or other ambiguous extensions, require the Windows platform
   marker, preserving the source's spelling and casing on the right-hand side,
   for example `-match 'Windows'`.
4. Require `Installer`, `Setup`, or another source-specific product-form marker
   when releases contain both installable and non-installable builds. Require
   `portable` only when authoring the portable package; otherwise exclude it.
5. Prefer the `msvc` build over a GNU build when both are published for Windows.
6. Exclude unwanted variants such as `debug`, symbols, checksums, deltas,
   updater packages, and electron-builder portable executables.
7. Require the product name when one release contains assets for several
   products.

Map architecture labels instead of copying source tokens into the manifest:

| Source labels | WinGet `Architecture` |
| --- | --- |
| `i386`, `i686`, `x86` | `x86` |
| `amd64`, `x64`, `x86_64`, `win64` | `x64` |
| `arm32` | `arm` |
| `aarch64`, `arm64` | `arm64` |
| Bare `arm` | Ambiguous: inspect the installer because it may mean ARM32 or ARM64 |
| `win32` | Ambiguous: inspect the installer because publishers may use it for either x86 or x64 Windows software |
| No binaries | `neutral` only when the package genuinely contains no binary files |

Filename labels select candidates; they do not override binary evidence. Check
the PE machine type, MSI/MSIX package metadata, installer-family metadata, and
the architecture of the installed or nested primary executable. For an archive,
inspect the configured command and its dependent native files. Do not use a
bare `.Contains('arm')` predicate when both ARM32 and ARM64 assets exist because
it can select either one.

`1357310795.TboxWebdav` demonstrates Windows, architecture, and `no-runtime`
filters for ZIP assets. `astral-sh.uv` demonstrates translating Rust target
triples such as `i686`, `x86_64`, and `aarch64`. `A2-Ai.rv` and
`houseabsolute.ubi` add `msvc`; `EpicGames.Lore` adds product-name and debug
exclusions. `qyzhg.Prism` requires setup for its EXE and differentiates EXE and
MSI assets.

`qyzhg.Prism` is the compact example for tag and asset handling. Reuse its
GitHub source pattern only: it currently lists both EXE and MSI artifacts, while
current authoring policy prefers the direct MSI when an equivalent InstallShield
or Advanced Installer wrapper would install the same ARP identity. Parse the
release date and release body separately by following
[Git-Hosted Release Metadata](release-metadata-patterns.md#git-hosted-release-metadata).

`7zip.7zip` demonstrates multiple installer families, but each family and
architecture must still match the current manifest and current artifact policy.

When releases are files committed to a repository rather than release assets,
follow `JurgenRathlev.innounp`: call the contents API for the exact folder,
extract only filename versions that match the package convention, sort with
`[ChunkVersion]`, query the latest commit for that selected path, and build a raw
URL pinned to the commit SHA.

## Sparkle Appcasts

Sparkle-style appcasts commonly expose release data through an XML `enclosure`:

```powershell
$Appcast = Invoke-RestMethod -Uri $AppcastUrl
if ($Appcast.enclosure) {
  $Item = $Appcast
} else {
  $Item = @($Appcast.rss.channel.item)[0]
}
if (-not $Item.enclosure) { throw 'The appcast has no enclosure.' }

$this.CurrentState.Version = [string]$Item.enclosure.version
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = [string]$Item.enclosure.url
}
```

Inspect the returned XML shape before selecting an item; some vendor feeds
return one enclosure-bearing element directly, while RSS feeds can expose an
item collection whose ordering must be verified before selecting index zero.
Inspect enclosure fields such as `shortVersionString` or
`primaryInstallationFile`, and validate that the enclosure URL is a full
Windows installer rather than an updater or delta.

- `AppDynamic.AirServer` reads separate x86 and x64 feeds, verifies equal
  versions, and records each enclosure's nested installation file.
- `FlorianHeidenreich.Mp3tag` selects the `appcast` category and derives x86
  from the x64 enclosure URL.
- `Vivaldi.Vivaldi` verifies x86, x64, and ARM64 feeds and changes the
  auto-update URL to the corresponding stable full installer.
- `Readdle.Spark` separates the feed version used for state comparison from the
  shorter manifest version through `RealVersion`.

Handle optional `pubDate`, `releaseNotesLink`, and `description` fields after
`Check()` as described in
[Sparkle Release Metadata](release-metadata-patterns.md#sparkle-release-metadata).

## Electron-Updater Feeds

`Adobe.WorkfrontProof` is the requested one-installer example. Prefer the
dedicated converter used by `7pace.Timetracker` so field naming and feed parsing
stay in PackageModule:

```powershell
$Prefix = 'https://publisher.example/releases/'
$Feed = Invoke-RestMethod -Uri "${Prefix}latest.yml" | ConvertFrom-ElectronBuilderUpdateFeed

$this.CurrentState.Version = $Feed.Version
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Feed.Files[0].Url
}
```

Use `Files[0]` only when exactly one feed entry applies. `Unity.UnityHub`
demonstrates selecting x64 and ARM64 entries by URL. Verify every selected feed
file belongs to the same version and use the original full installer rather
than a distinct update-only artifact. Treat an optional feed `ReleaseDate` as
release metadata and assign it inside its own guarded block after `Check()`.

Some applications call electron-updater `setFeedURL()` and leave an invalid
`app-update.yml`. Discover and verify the effective official feed before writing
the task. Keep fetching in the task; converter functions do not access the
network.

## Squirrel RELEASES

Squirrel feeds are commonly UTF-8 with BOM, so use the response-content helper:

```powershell
$Release = Invoke-WebRequest -Uri $ReleasesUrl | Read-ResponseContent | ConvertFrom-SquirrelReleases | Where-Object { -not $_.IsDelta } | Sort-Object -Property { [ChunkVersion]$_.Version } -Bottom 1
```

`Amazon.Chime` and `Amazon.AppStream` use this pattern. Construct the full
installer URL according to the feed or publisher layout and do not select delta
packages.

## Redirected Installer URLs

Use redirect helpers to resolve the official target without downloading the
installer. `360.360Ent` is the compact case:

```powershell
$this.CurrentState.Installer += [ordered]@{ InstallerUrl = Get-RedirectedUrl -Uri $DownloadEndpoint -Method GET }
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value
```

Reject an empty version and verify that the resolved host remains official.
`Xmind.Xmind` resolves x64 and ARM64 separately, compares their versions, and
uses `WinGetReplaceMode` when one architecture lags. `Anthropic.Claude`
demonstrates separate redirect endpoints for EXE/MSIX and architectures.

## Custom EXE Wrappers With Nested MSI

Use this fallback when a proprietary or custom EXE wrapper is not supported by
PackageModule and the nested MSI contains the authoritative version or ARP
identity. First run the installer analyzer and the applicable family parser. Do
not use 7z when Dumplings already has a source-backed extractor for that outer
format. This narrow task-side fallback does not permit reusable installer
parsers, bridges, analyzers, tests, or CI parser paths to depend on 7-Zip,
NanaZip, or another external parser executable.

List the wrapper contents before writing the task, then select the exact nested
file that the wrapper installs. A first `*.msi` match is unsafe when the wrapper
contains prerequisites, language packs, or architecture-specific packages.
Confirm the mapping from the wrapper configuration, archive layout, MSI summary
information, and `Get-MsiInstallerInfo` evidence.

For one named MSI payload, keep the outer installer in PackageTask's cache and
parse the extracted database once:

```powershell
$Installer = $this.CurrentState.Installer[0]
$Url = $Installer.InstallerUrl
$this.InstallerFiles[$Url] = $OuterPath = Get-TempFile -Uri $Url
$ExtractedPath = New-TempFolder

try {
  & 7z.exe e -aoa -ba -bd -y "-o$ExtractedPath" $OuterPath 'ProductSetup.msi' | Out-Host
  if ($LASTEXITCODE -ne 0) {
    throw "7z failed to extract ProductSetup.msi with exit code $LASTEXITCODE."
  }

  $MsiPath = Join-Path $ExtractedPath 'ProductSetup.msi'
  if (-not (Test-Path -LiteralPath $MsiPath -PathType Leaf)) {
    throw 'The expected nested MSI was not extracted.'
  }

  $MsiInfo = Get-MsiInstallerInfo -Path $MsiPath
  $this.CurrentState.RealVersion = $MsiInfo.DisplayVersion

  # Write parser-owned fields only when the unsupported outer wrapper prevents manifest generation from reaching the MSI and the reference manifest needs those values refreshed.
  $Installer.ProductCode = $MsiInfo.ProductCode
  $Installer.AppsAndFeaturesEntries = @(
    [ordered]@{
      UpgradeCode   = $MsiInfo.UpgradeCode
      InstallerType = $MsiInfo.InstallerType
    }
  )
} finally {
  Remove-Item -LiteralPath $ExtractedPath -Recurse -Force -ErrorAction SilentlyContinue
}
```

Use `DisplayVersion` for the MSI product version. The same result also exposes
`DisplayName`, `Publisher`, `ProductCode`, `UpgradeCode`, `InstallerType`,
`PackageArchitecture`, install-location evidence, ARP behavior, and registry
associations. Reuse these properties instead of calling several
`Read-*FromMsi` functions. Omit explicit state fields that the normal manifest
updater can refresh from the outer installer.

Extraction rules:

- Check `$LASTEXITCODE` and the expected file after every 7z invocation.
- Use `e` only when flattening one exact file is safe. Use `x` when preserving
  nested paths avoids collisions or proves which payload was selected.
- Use `-t#` only for a verified raw-section layout where 7z exposes numbered
  streams such as `2.msi`; those numbers are format observations, not stable
  MSI identities.
- When several MSIs exist, map each exact payload to its WinGet architecture and
  compare `PackageArchitecture` with that mapping. Do not infer architecture
  from extraction order.
- For a nested EXE chain, make a separate bounded extraction directory for each
  layer and validate every intermediate file before continuing.
- Pass an extracted MSP through `Get-MsiInstallerInfo -PatchPath` when the patch
  changes the effective ProductVersion or ProductCode represented by the
  wrapper.
- Remove temporary extraction directories in `finally`. Do not remove the outer
  file registered in `$this.InstallerFiles`; PackageTask owns that file.
- Keep 7z in task-specific discovery only. Installer parsers and CI-critical
  static analysis must not invoke or depend on 7-Zip, NanaZip, or another
  external parser executable.

Open these concrete tasks according to the wrapper layout being analyzed. Their
archive paths are useful evidence, but several retain legacy individual readers
or manual manifest mutation and should not be copied line for line:

| Wrapper layout | Task examples |
| --- | --- |
| One named MSI | `ALTEC.DataPrint`, `Cisco.WebexWRFtoWMV`, `Cjwdev.ADInfo.Free`, `Texthelp.Equatio` |
| Architecture-specific MSI payloads | `Apple.iTunes`, `dotPDN.PaintDotNet`, `Plenom.kuandoHUB`, `Plenom.kuandoBusylight.Webex` |
| Numbered raw-section MSI streams | `Maximus5.ConEmu`, `DuoSecurity.Duo2FAAuthenticationforWindows`, `Google.EarthPro`, `UCBerkeley.BOINC` |
| Nested EXE followed by MSI | `Siemens.JT2Go`, `Oracle.JavaRuntimeEnvironment`, `PTC.CreoView.Express` |
| Cabinet followed by MSI | `Altova.Authentic.Enterprise`, `Altova.DatabaseSpy.Enterprise`, `Altova.XMLSpy.Professional` |
| MSI with an optional MSP projection | `Foxit.FoxitReader`, `Foxit.PhantomPDF`, `Foxit.PhantomPDF.Subscription.MSI` |

## Shared Provider Tasks

Use a provider when at least three tasks would otherwise fetch the same source.
The threshold applies to a shared response or catalog, not merely to tasks from
the same publisher. With one or two consumers, keep retrieval in the package
tasks. `#Argente` fetches x86, x64, and ARM64 catalogs, and consumers such as
`Argente.Utilities` and `Argente.DataShredder` select their own product rows.
Consumers verify that architecture variants agree on version before populating
installer entries.

`#JetBrains` demonstrates batching many product codes by channel and storing one
catalog under `$Global:DumplingsStorage.JetBrainsApps`. Individual `JetBrains.*`
tasks select one product/channel and add checksum data and architecture-specific
URLs. Do not manually set parser-readable ProductCode or Apps & Features values
in new consumers unless current static analysis cannot resolve them.

## Browser-Only Sources

Use browser automation only after ordinary HTTP, source inspection, and official
APIs fail. Keep the lease block short and return detached data:

```powershell
$Url = Use-PlaywrightPage -Stealth -Headless {
  param($Page)
  $null = Open-PlaywrightPage -Page $Page -Uri $DownloadPage
  $null = Invoke-PlaywrightCloudflareChallenge -Page $Page
  Read-PlaywrightLocator -Page $Page -Selector 'a[href$=".exe"]' -Property Attribute -AttributeName href
}
```

`BLife.CustomCursor` is the current reference. Never return page, locator, or
browser objects from `Use-PlaywrightPage`, and do not hold the lease while doing
installer parsing or release-note formatting.

## Versionless URLs And Validator Priority

Use this pattern only as a last resort when a stable URL serves changing bytes,
no official API, feed, page, redirect, or browser-accessible source exposes the
version, and the version must be extracted from the downloaded installer. Do not
use a response validator when a source can provide a version directly.

Inspect the response and use the strongest stable validator it provides:

| Priority | Validator | Example tasks |
| --- | --- | --- |
| 1 | Content hash or checksum header | `Altova.XMLSpy.Professional` (`x-amz-meta-sha256`), `Alibaba.Taobao` (`Content-MD5`), `Alibaba.QwenWork.CN` (`x-oss-hash-crc64ecma`), `Bazwise.FolderSizeExplorer` (`x-goog-hash` member beginning with `md5=`) |
| 2 | `ETag` | `ABC.PowerExtension`, `Cjwdev.ADAccountResetTool`, `Amazon.EC2Launch` |
| 3 | `Last-Modified` | `AnyDesk.AnyDesk`, `BitSum.ProcessLasso.Beta` |
| 4 | `Content-Length` | `Ardisk.Ardisk` |

Store unfamiliar checksum formats as opaque validator strings unless their
encoding is documented. `Content-MD5` and the `md5=` value in `x-goog-hash` are
often Base64; `x-oss-hash-crc64ecma` is not a SHA256 value. None of these values
replace `InstallerSha256` in the manifest. A changed validator triggers one
download whose SHA256 and embedded version determine the actual state.

1. Add the stable installer URL to `CurrentState.Installer`.
2. Fetch the highest-priority stable validator available with the method and
   user agent accepted by the endpoint.
3. Return immediately when the validator matches a previously accepted value.
4. Otherwise download once, register it in `$this.InstallerFiles`, derive the
   version, and calculate SHA256.
5. If bytes are unchanged, append the new validator to state and write it so the
   next run can return early.
6. Compare the parsed real version after changed bytes are confirmed.
7. Fetch optional release metadata in separate guarded blocks.
8. Submit an ordinary update when the version changed. Treat a same-version byte
   replacement as an explicit same-version manifest update after review.

Core fragment:

```powershell
$Url = $this.CurrentState.Installer[0].InstallerUrl
$Headers = Get-WebResponseHeader -Uri $Url -Method GET -UserAgent $WinGetUserAgent
$ETag = [string]$Headers.Headers.ETag

if ((-not $Global:DumplingsPreference.Contains('Force') -or -not $Global:DumplingsPreference.Force) -and -not $this.Status.Contains('New') -and $ETag -in @($this.LastState.ETag)) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

$this.InstallerFiles[$Url] = $File = Get-TempFile -Uri $Url
$this.CurrentState.Version = $File | Read-ProductVersionFromExe
$this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash $File -Algorithm SHA256).Hash
```

For `Last-Modified`, compare parsed `[datetime]` values and warn when the current
date regresses rather than treating it as an update. `BitSum.ProcessLasso.Beta`
shows separate values for x86 and x64. `Content-Length` is last because unrelated
files can have the same size.

Do not copy `ABC.PowerExtension`, `AnyDesk.AnyDesk`, or `Ardisk.Ardisk` file
cleanup into a new task; retaining the registered file allows manifest
generation to parse the same bytes. `Amazon.EC2Launch` is the advanced reference
for migrating from a mutable `latest` URL to a version-specific URL once that
path becomes available.
