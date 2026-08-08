# Electron-builder NSIS feeds

[Back to the NSIS workflow](workflow.md)

## Detect electron-builder and validate its update feed

Many modern desktop NSIS installers, especially Electron applications, are electron-builder NSIS. Because architecture and scope are required for manifest authoring, call the detailed helper directly and reuse its predicate and evidence properties:

```powershell
$ElectronBuilderInfo = Get-ElectronBuilderNSISInfo -Path $InstallerFile
$IsElectronBuilder = $ElectronBuilderInfo.IsElectronBuilder
$ElectronBuilderInfo.IsPortable
$ElectronBuilderInfo.Architectures
$ElectronBuilderInfo.Architecture
$ElectronBuilderInfo.SupportedScopes
$ElectronBuilderInfo.Evidence
```

If `IsPortable` is true, return to [visible ARP ownership](analysis.md#identify-the-visible-arp-owner) and select the portable workflow. The presence of `app-*.7z` alone proves electron-builder packaging but not a portable target; the helper requires the complete portable environment-variable and temporary-execution evidence before setting this property.

Use `Test-ElectronBuilder` instead only when a Boolean result is the sole required output and no architecture or scope decision will follow. Do not call `Test-ElectronBuilder` immediately before `Get-ElectronBuilderNSISInfo`, because that parses the installer twice.

If `$IsElectronBuilder` is false, skip the remainder of this page and continue with [scope and silent behavior](scope-and-silent.md). If it is true, inspect update-source evidence before accepting a feed asset as `InstallerUrl`:

1. Try replacing the original installer filename in its official URL with `latest.yml`.
2. If that fails, inspect the embedded `app-*.7z` application's `resources\app-update.yml`, `resources\latest.yml`, or equivalent updater configuration.
3. Fetch the selected feed in the task with any package-specific headers, query parameters, cookies, or fallback handling. Pass only the returned YAML string to the converter.
4. Resolve relative asset paths against the feed URL and verify the feed version, size, SHA512, downloaded SHA256, and official domain.

Tauri is separate from electron-builder even though both produce generated NSIS installers. When `$Info.IsTauri` is true, call `Get-NSISInstallerSwitchInfo` once and review `TauriSwitches`: `/P` is Tauri's passive mode with progress, `/NS` suppresses shortcuts, `/UPDATE` is internal updater mode, and `/R` launches the application after silent or passive installation with optional `/ARGS`. Therefore `/P` can be evidence for an explicit `SilentWithProgress` override, while `/R`, `/ARGS`, and `/UPDATE` are not general silent-install switches. Do not add any of them unless the intended manifest behavior requires that exact source-backed mode.

```powershell
$LatestYaml = Invoke-RestMethod -Uri $LatestYamlUri -Headers $Headers
$UpdateFeed = $LatestYaml | ConvertFrom-ElectronBuilderUpdateFeed
$UpdateFeed.Version
$UpdateFeed.Files
```

`ConvertFrom-ElectronBuilderUpdateFeed` and `ConvertFrom-ElectronBuilderLatestYaml` do not access the network. They only parse the provided `latest.yml` content string.

Do not assume `app-update.yml` is authoritative. Some applications leave an invalid or placeholder URL there and call electron-updater's `setFeedURL()` at runtime. When static configuration is invalid:

- If extracted application source is available under `app\`, search its JavaScript for `setFeedURL(` and trace the URL expression and environment/configuration inputs.
- If the application is packaged as `app.asar`, extract or inspect the archive, then search the contained source for `setFeedURL(`. Do not execute the application to discover the URL on the host.
- Accept the recovered URL only when its construction is deterministic and resolves to an official publisher-controlled endpoint.
- If the runtime URL cannot be recovered safely, skip feed-based source automation and continue with [scope and silent behavior](scope-and-silent.md) using the original official installer source. Record a warning rather than using the invalid configuration URL.

Also distinguish initial-install installers from update-only installers. Some publishers distribute different binaries for first installation and self-update:

- Compare the original installer and feed-selected asset at the same version by URL, size, and SHA256.
- If the feed URL introduces terms such as `update`, `upgrade`, or similar updater-only markers that are absent from the original installer URL, and the hashes differ for the same version, treat the feed asset as an update installer.
- Keep the original initial-install installer as `InstallerUrl`, warn the user that the feed publishes a different updater binary, and do not substitute the feed asset merely because it is versioned.
- The feed may still provide version or release-date evidence when trustworthy, but its update-only asset is not the manifest installer.

See [Electron-builder update feeds](../../../../author-winget-manifest/references/package/artifact-selection.md#electron-builder-update-feeds) for the general URL-selection routine.
