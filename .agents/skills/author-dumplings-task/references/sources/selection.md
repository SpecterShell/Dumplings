# Installer source selection

## Required Installer Evidence

Version, `RealVersion`, installer URLs, installer selection, architecture, and required installer downloading or parsing determine whether an update is valid. Do not place these operations in a recoverable `try`/`catch`. Let failures stop the task to prevent incomplete state from being written or submitted.

Discover `Version` and installer URLs before `Check()`. When `RealVersion` is available only from changed installer bytes, download and parse the registered installer inside the change branch, but outside every optional-metadata `try`/`catch`. See [Release metadata workflow](../release/workflow.md) for the separate failure boundary used by `ReleaseTime`, `ReleaseNotes`, and `ReleaseNotesUrl`.

## Selection Order

Choose a reliable official source that passes the freshness check below, in this order.

1. Structured vendor or forge API.
2. Product update feed such as electron-updater or Squirrel `RELEASES`.
3. Static HTML download pages.
4. Stable redirect endpoint whose target carries the version.
5. Scoped Playwright when ordinary HTTP cannot expose the version.
6. As a last resort, a versionless installer whose version must be extracted from its downloaded bytes, using a response validator as a prefilter.

Fetch source data in the task. Feed converters accept already-retrieved strings because endpoints may require package-specific headers, cookies, or parameters.

## GitHub release source priority

When official Windows installers are delivered through GitHub releases, prefer that repository's GitHub Releases API for the task's version and installer URLs over electron-updater or tauri-updater feeds. Follow [GitHub releases](pages-and-releases.md#github-releases) to select full installers for the matching product, channel, and architecture. Apply the freshness check below before accepting any source.

Check the application's effective updater source when that evidence is available, including runtime overrides of bundled configuration. If electron-updater or tauri-updater uses a different repository or a non-GitHub source instead of those GitHub releases, warn the user. Include both source URLs and any observed version, channel, or artifact differences, and save the evidence. Keep GitHub releases as the preferred task source unless the evidence or the user's decision justifies another source. A YAML or JSON updater feed served from the same repository's corresponding GitHub releases does not by itself establish a different source.

## Discover runtime update sources

When configuration or published source does not expose a usable update endpoint, follow [VM update-source discovery](../../../analyze-winget-installer/references/workflows/vm-network-capture.md#discover-the-update-source). Capture startup checks, use Computer Use for a manual update check, and resolve login requirements with the user. Inspect or decompile application code as a last resort. Verify a recovered source independently before making the task depend on it.

## Reject Stale Captured Sources

Compare captured feeds and APIs with the official download page and, when needed, its installer version. Use `[ChunkVersion]` to compare the same product, channel, architecture, locale, and full-installer class. Account for beta feeds, staged rollouts, architecture lag, and regional releases before declaring a source stale.

If the source remains older, use the download page or its current backing endpoint for `Version` and `InstallerUrl`. Never pair a newer version with an older feed URL. Prioritize current sources regardless of format. A stale source may supply optional metadata only for the matching version.

Record the mismatch in the task-authoring evidence. Recheck a captured source when the publisher updates it later. Its suitability may change.

See [Task example index](../example-index.md) for current task implementations of each source pattern.
