# Installer source selection

## Required Installer Evidence

Version, `RealVersion`, installer URLs, installer selection, architecture, and required installer downloading or parsing determine whether an update is valid. Do not place these operations in a recoverable `try`/`catch`. Let failures stop the task instead of writing or submitting incomplete state.

Discover `Version` and installer URLs before `Check()`. When `RealVersion` is available only from changed installer bytes, download and parse the registered installer inside the change branch, but outside every optional-metadata `try`/`catch`. See [Release metadata workflow](../release/workflow.md) for the separate failure boundary used by `ReleaseTime`, `ReleaseNotes`, and `ReleaseNotesUrl`.

## Selection Order

Among sources that pass the freshness check below, prefer the least fragile official source that exposes the required facts:

1. Structured vendor or forge API.
2. Product update feed such as electron-updater or Squirrel `RELEASES`.
3. Static HTML download pages.
4. Stable redirect endpoint whose target carries the version.
5. Scoped Playwright when ordinary HTTP cannot expose the version.
6. As a last resort, a versionless installer whose version must be extracted from its downloaded bytes, using a response validator as a prefilter.

Fetch source data in the task. Feed converters accept already-retrieved strings because endpoints may require package-specific headers, cookies, or parameters.

## Reject Stale Captured Sources

Do not assume that an auto-update feed, API request captured from an application, or endpoint discovered in browser traffic is the current release source. During task authoring, compare its latest version with the official download page and, when needed, the version parsed from the page's installer. Compare the same product, channel, architecture, locale, and full-installer class using `[ChunkVersion]`; a beta feed, staged rollout, architecture lag, or regional release is not evidence that the endpoint is stale.

If the captured source remains older after those distinctions are excluded, do not use it as the required `Version` or `InstallerUrl` source in `Script.ps1`. Prefer the download page or the current authoritative endpoint that backs it. Do not combine the newer page version with an older feed URL, and do not wait for the stale feed merely because a structured source normally ranks above HTML. The stale endpoint may still supply optional metadata only when that metadata is explicitly version-matched.

Record the mismatch in the task-authoring evidence. Recheck a captured source when the publisher updates it later; skipping it is a source decision, not a permanent claim that the endpoint is invalid.

See [Task example index](../example-index.md) for current task implementations of each source pattern.
