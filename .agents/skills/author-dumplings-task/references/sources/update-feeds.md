# Installer update feeds

See the [task example index](../example-index.md) for current implementations of these patterns.

## Sparkle Appcasts

Sparkle-style appcasts commonly expose release data through an XML `enclosure`:

```powershell
$AppcastResult = @(Invoke-RestMethod -Uri $AppcastUrl)
if ($AppcastResult.Count -eq 1 -and $AppcastResult[0].PSObject.Properties['rss']) {
  $Items = @($AppcastResult[0].rss.channel.item)
} else {
  $Items = $AppcastResult
}
$Item = $Items.Where({ $_.enclosure }, 'First')[0]
if (-not $Item.enclosure) { throw 'The appcast has no enclosure.' }

$this.CurrentState.Version = [string]$Item.enclosure.version
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = [string]$Item.enclosure.url
}
```

`Invoke-RestMethod` treats recognized RSS and Atom responses differently from ordinary XML: it writes the feed's `item` or `entry` elements directly to the pipeline instead of always returning the document root. A one-item feed may therefore look like one enclosure-bearing object, while a multi-item feed becomes a collection. The normalization above also accepts an ordinary XML result that still exposes `rss.channel.item`.

This matches the current task shapes. `#Clockify.Clockify`, `#TablePlus.TablePlus`, `AppDynamic.AirServer`, and `Vivaldi.Vivaldi` consume a single object with `enclosure`; `FlorianHeidenreich.Mp3tag` filters the direct item collection by `category`; `Aegisub.Aegisub` and the SourceForge tasks also filter entries returned directly by `Invoke-RestMethod`. Inspect the actual shape and verify ordering before selecting the first matching item. Inspect enclosure fields such as `shortVersionString` or `primaryInstallationFile`, and validate that the enclosure URL is a full Windows installer rather than an updater or delta.

- `AppDynamic.AirServer` reads separate x86 and x64 feeds, verifies equal versions, and records each enclosure's nested installation file.
- `FlorianHeidenreich.Mp3tag` selects the `appcast` category and derives x86 from the x64 enclosure URL.
- `Vivaldi.Vivaldi` verifies x86, x64, and ARM64 feeds and changes the auto-update URL to the corresponding stable full installer.
- `Readdle.Spark` separates the feed version used for state comparison from the shorter manifest version through `RealVersion`.

Handle optional `pubDate`, `releaseNotesLink`, and `description` fields after `Check()` as described in [Sparkle release metadata](../release/feeds-text.md#sparkle-release-metadata).

## Electron-Updater Feeds

`Adobe.WorkfrontProof` is the requested one-installer example. Prefer the dedicated converter used by `7pace.Timetracker` so field naming and feed parsing stay in PackageModule:

```powershell
$Prefix = 'https://publisher.example/releases/'
$Feed = Invoke-RestMethod -Uri "${Prefix}latest.yml" | ConvertFrom-ElectronBuilderUpdateFeed

$this.CurrentState.Version = $Feed.Version
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Feed.Files[0].Url
}
```

Use `Files[0]` only when exactly one feed entry applies. `Unity.UnityHub` demonstrates selecting x64 and ARM64 entries by URL. Verify every selected feed file belongs to the same version and use the original full installer rather than a distinct update-only artifact. Treat an optional feed `ReleaseDate` as release metadata and assign it inside its own guarded block after `Check()`.

Some applications call electron-updater `setFeedURL()` and leave an invalid `app-update.yml`. Discover and verify the effective official feed before writing the task. Keep fetching in the task; converter functions do not access the network.

## Squirrel RELEASES

Squirrel feeds are commonly UTF-8 with BOM, so use the response-content helper:

```powershell
$Release = Invoke-WebRequest -Uri $ReleasesUrl | Read-ResponseContent | ConvertFrom-SquirrelReleases | Where-Object { -not $_.IsDelta } | Sort-Object -Property { [ChunkVersion]$_.Version } -Bottom 1
```

`Amazon.Chime` and `Amazon.AppStream` use this pattern. Construct the full installer URL according to the feed or publisher layout and do not select delta packages.
