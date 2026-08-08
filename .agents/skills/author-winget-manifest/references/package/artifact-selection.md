# Installer artifact selection

## Query Parameters And Signed URLs

Inspect installer URLs for query parameters before using them in manifests. Treat these as suspicious when they appear in the manifest URL itself or only in the final redirect target:

- Access tokens, API keys, session IDs, nonce values, temporary IDs, or user-specific IDs.
- Expiry timestamps, signed URL parameters, HMAC/signature fields, CDN policy fields, or credential scopes.
- Hash-like parameters that change across refreshes or across repeated requests.
- Cloud-storage signed URL patterns such as `X-Amz-*`, `X-Goog-*`, `Expires`, `Signature`, `Policy`, `Key-Pair-Id`, `token`, `key`, `auth`, `sig`, or `hash`.

Not every query parameter is invalid. Stable parameters such as `version`, `platform`, `arch`, `locale`, `download=1`, or product identifiers may be acceptable when they are official, stable across refreshes, and publicly downloadable by WinGet. Verify by refreshing the page and replaying the URL.

Redirect-chain rule:

- If a stable official URL without dynamic parameters redirects to a signed or parameterized final URL, use the stable previous official URL as `InstallerUrl` when WinGet can download it publicly.
- Do not blindly strip query parameters from the signed final URL and assume the result works; use the previous redirect hop or verify the stripped URL with a fresh request.
- If the page exposes only a signed or expiring URL and no stable previous official URL exists, do not write that URL into a static manifest.
- If the application itself fetches update metadata or signed downloads at runtime, defer static manifest URL selection and capture the program traffic in a VM for the later automation-authoring workflow.

Record which URL was selected, which URL was rejected, and why. Include refresh comparison evidence when deciding whether a parameterized link is stable.

## Electron-Builder Update Feeds

When static analysis identifies an electron-builder NSIS installer, look for its electron-updater feed before accepting a mutable download URL:

1. Replace the installer filename in its URL with `latest.yml` and test that sibling URL.
2. If that fails, inspect the embedded electron-builder application archive, such as `$PLUGINSDIR\app-64.7z`, for `resources\latest.yml` or updater configuration that identifies the feed URL.
3. Parse the fetched feed text with `ConvertFrom-ElectronBuilderUpdateFeed` or `ConvertFrom-ElectronBuilderLatestYaml` after PackageModule is loaded.
4. Resolve a relative `files[].url` or `path` against the `latest.yml` URL rather than concatenating strings manually.
5. Prefer a versioned installer URL from the feed when available. If the feed points back to the same unversioned filename, retain the official mutable URL only after recording the feed version, release date, size, and hash evidence.
6. Verify the downloaded installer against the feed's size and SHA512 when supplied, then calculate the SHA256 required by the WinGet manifest.

Do not assume every electron-builder feed provides a versioned URL. A feed can publish a current version while retaining a relative path such as `Product Setup.exe`; this remains a mutable URL and must be reported as such.

When the feed will drive ongoing Dumplings updates, follow the [electron-updater feed workflow](../../../author-dumplings-task/references/sources/update-feeds.md#electron-updater-feeds) to create and test the task.

## Choose Between EXE And MSI

An official release may publish both an EXE bootstrapper and a direct MSI for the same application. When the EXE is InstallShield or Advanced Installer and it selects or embeds the same MSI, author only the direct MSI installer entry. Adding both artifacts can give WinGet two ways to install the same product while both resolve to the same visible ARP entry.

Establish equivalence before dropping the EXE. Parse both artifacts and compare the selected nested MSI with the direct MSI using `ProductCode`, `UpgradeCode`, product version, package architecture, scope, language, and feature or transform evidence. Also compare the visible ARP type and identity: Advanced Installer and InstallShield can hide a native MSI entry or create a separate EXE-style entry, so the mere presence of an MSI is insufficient.

Keep the EXE only when evidence shows that it is materially required. Examples include an EXE that installs prerequisites not expressible as manifest dependencies, applies a required transform or property set, selects among different architecture or language payloads, chains additional products, exposes a different visible ARP identity, or is the only publisher-supported standalone installation path. If equivalence or standalone MSI behavior remains uncertain, validate both paths in the VM rather than publishing duplicate entries.

When the direct MSI is selected, use its own builder and metadata to choose `InstallerType`, installer switches, `ProductCode`, and `UpgradeCode`. Do not carry EXE-wrapper switches or return-code behavior into the MSI entry.

## Final URL Decision

Use the direct official installer URL that WinGet validation can download publicly:

- Prefer HTTPS.
- Prefer version-specific immutable paths.
- Preserve official CDN URLs when they are discoverable from the publisher website.
- Avoid URL shorteners and unofficial redirectors.
- Avoid dynamic, expiring, signed, session-bound, or user-bound query parameters in `InstallerUrl`.
- If an official vanity URL is the only option, document the risk and collect response headers useful for update detection.
- If the final redirect target is dynamic but the previous official URL is stable and public, use the previous official URL.
- If only a dynamic URL exists, stop manifest authoring and hand off to automation analysis with VM traffic-capture evidence.

Before writing the manifest, verify the URL, redirect chain, parameter stability, final redirected URL, content length, file name, and SHA256.

## WinGet Download Compatibility

An official URL that works in a browser, curl, or `Invoke-WebRequest` can still fail in WinGet because servers distinguish TLS clients, Delivery Optimization ranges, WinINet, user agents, cookies, or proxies. Test the selected URL through Dumplings' native WinGet-compatible paths:

```powershell
. .\Modules\PackageModule\Index.ps1
$Result = Test-WinGetInstallerDownload `
  -Uri $InstallerUrl `
  -ExpectedSha256 $InstallerSha256 `
  -Method Default `
  -ConnectionTimeoutSeconds 30 `
  -OperationTimeoutSeconds 60
```

`Default` follows WinGet behavior: an explicit proxy uses WinINet; otherwise Delivery Optimization runs first, fatal policy failures stop, nonfatal failures fall back to WinINet, redirects follow WinGet's rules, and a complete download is checked against content length and SHA256.

The native Delivery Optimization and WinINet helpers display byte progress after one second and cancel the active native operation when the PowerShell pipeline is stopped with Ctrl+C. Their timeout and retry controls follow `Invoke-WebRequest` naming:

- `ConnectionTimeoutSeconds` (alias `TimeoutSec`) bounds connection and response-header receipt; `0` disables this timeout.
- `OperationTimeoutSeconds` bounds each period without body progress; `0` disables this timeout.
- `MaximumRetryCount` defaults to `3` and retries HTTP `304` and `400` through `599` responses.
- `RetryIntervalSec` defaults to `3`; a valid `Retry-After` header overrides it for HTTP `429`.
- `MaximumRetryDelaySeconds` defaults to `30` and rejects a requested per-retry delay above that bound.
- `MaximumTotalRetryDelaySeconds` defaults to `60` and bounds cumulative delay for each transport.

Delivery Optimization additionally retains WinGet's `NoProgressTimeoutSeconds` and the probe safety bound `MaximumDurationSeconds`. Use retries only to test documented transient server behavior. A URL that requires repeated retries is not necessarily suitable for a static manifest.

Use response-only diagnostics for large files:

```powershell
$Result = Test-WinGetInstallerDownload -Uri $InstallerUrl -Method Both -ResponseOnly
$Result.Results | Format-Table Method, ServerAcceptedRequest, HttpStatusCode, AttemptCount, HResult, ErrorMessage
$Result.Failures | Format-Table Method, HttpStatusCode, TimedOut, AttemptCount, FailureStage, ErrorMessage
$Result.FailureSummary
```

`ServerAcceptedRequest` proves only that the native path accepted the request. `WouldWinGetDownload` requires a completed download. Run full `Default` mode before submission when practical.

`Failures` retains one structured record for each rejected transport, including timeout, HTTP status, HRESULT, native error, retry count, failure stage, and final URL. `FailureSummary` presents those records as one readable line. Treat an empty native error field as unavailable evidence rather than success; use the other fields and the recommendation to distinguish a slow server, HTTP rejection, content validation failure, and hash mismatch.

A first-attempt HTTP `429` followed by success within the bounded retry policy is transient evidence, not proof that WinGet is incompatible with the URL. Record `AttemptCount` and the final status. Treat persistent failure after the configured retry and delay bounds as actionable download evidence.

- Delivery Optimization succeeds and WinINet fails: default WinGet can work, but explicit proxy or WinINet users can fail.
- Delivery Optimization fails nonfatally and WinINet succeeds: default fallback works.
- Delivery Optimization fails fatally: WinGet stops without fallback.
- Both reject the request: stop until the publisher provides a compatible URL.
- Completed bytes do not match SHA256: reject the evidence and investigate dynamic content.

Do not simulate WinGet by changing only `User-Agent`. Probe files are deleted unless `-KeepDownloads` is explicitly requested.
