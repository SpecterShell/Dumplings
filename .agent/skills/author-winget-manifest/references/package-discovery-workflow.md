# Package Discovery Workflow

## Goal

Find the official, public, version-specific installer source before authoring any manifest. Treat source discovery as a security task, not just a download task.

## Source Classification

Classify the package source first:

- `Homepage`: Proprietary or publisher-hosted applications where installers are linked from the product page, download page, or support page.
- `GitHub`: Open-source or publisher-hosted projects where installers are release assets in an official GitHub repository.
- `Other official forge`: Sourcehut, GitLab, Codeberg, vendor CDN release pages, or other first-party release locations.

If a homepage links to GitHub releases, switch to the GitHub path. If a GitHub repository links back to a homepage, verify both are mutually connected.

## Existing Package Discovery

Before creating a package or recursively searching the large winget-pkgs manifest tree, query the installed WinGet source:

```powershell
winget search 'Product Name' --source winget
winget search --id Publisher.Package --exact --source winget
winget show --id Publisher.Package --exact --source winget
```

Use a broad product-name search first when the identifier is unknown. Search likely publisher/brand spellings as needed, then confirm the exact identifier with `winget show`.

After resolving the identifier, navigate directly to its repository path:

```text
manifests/<first-character>/<Publisher>/<Package>/<Version>/
```

Do not start with recursive `rg`, `grep`, `Get-ChildItem -Recurse`, or equivalent full-tree searches merely to determine whether a package exists; the winget-pkgs tree is too large for that to be the default discovery method. Use direct file lookup after `winget search`, and use scoped repository searches only for fields or examples that the public source does not expose. Also check open upstream pull requests before submitting a new package because pending packages are not yet returned by `winget search`.

## Homepage And Vendor Sites

Start from the package homepage when known. If unknown, use search cautiously:

- Prefer official publisher domains, documentation pages, support pages, store pages, and linked social/profile pages.
- Cross-reference at least two independent search results or official pages before trusting a domain.
- Verify that official pages navigate to each other: homepage to download page, GitHub to homepage, documentation to publisher, or support page to product.
- Check whether the product was acquired, merged, or rebranded. Distinguish acquisition from product-identity replacement: if the acquired company and brand remain the product's developer identity, retain them for a new package identifier and `Author`, while using the parent company's current URLs where appropriate.
- Reject third-party download sites, including download aggregators, mirrors, repackagers, software-informer sites, Softonic-style sites, MajorGeeks-style sites, and SEO spam pages.
- Treat popular packages with many fake results as high risk; do not use search-result download links without official cross-reference proof.

Common homepage download patterns:

- The installer link is directly on the homepage or product download page.
- The installer link is fetched dynamically by page JavaScript through an API request.
- The installer link is embedded inside bundled JavaScript files.
- The page starts a download automatically after a countdown.
- The installer link is on a support, release notes, or archived download page rather than the marketing homepage.
- The download requires submitting a promotion form.

## Dynamic Download Pages

If the link is not visible in static HTML:

- Inspect the HTML source for installer URLs, API endpoints, release JSON, and JavaScript bundle names.
- Use browser DevTools, network logs, or an available browser MCP to capture `fetch`/XHR requests and redirect chains.
- Search JavaScript bundles for file extensions, version strings, CDN hostnames, and API route names.
- For automatic countdown downloads, inspect the countdown script and network activity instead of waiting blindly.
- Record the original page URL and the final installer URL.
- Refresh the page and repeat the capture. If installer URLs, API responses, or redirect targets change between refreshes, treat the URL as dynamic until proven stable.

If no DevTools MCP is available, use the in-app browser, command-line HTTP requests, and static source inspection. Do not claim DevTools evidence unless it was actually captured.

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

When the feed will drive ongoing Dumplings updates, follow [Dumplings Electron-Builder Automation](electron-builder-automation.md) to create and test the task.

## Forms

It is acceptable to submit non-sensitive promotional forms with placeholder information, for example:

- Name: `Thank You`
- Email: `no@thank.you`
- Country: any plausible value
- Phone: any plausible dummy value

Continue only if the site returns the installer link directly in the browser response or page. Stop and warn immediately if the site says the download link will be sent by email or requires access to an inbox.

Do not create accounts, bypass paywalls, use personal data, or use private credentials unless the user explicitly provides an approved workflow.

## GitHub Sources

Use the latest release assets from the official repository:

- Prefer the latest non-prerelease release for stable packages.
- Use prerelease releases only for packages that are explicitly preview, beta, nightly, canary, or otherwise channel-specific.
- If release assets contain multiple product families, split them into separate packages when the installed products are distinct. Examples include desktop vs CLI packages or multiple build variants.
- Report repository legitimacy signals: star count, commit count, open issue count, open pull request count, archived status, latest release tag, and whether releases are still expected.
- Check whether the repository is official by verifying links from the project website, organization profile, README, package metadata, or existing manifests.

Flag suspicious GitHub sources:

- Repo has little activity and no official cross-links but claims a well-known product.
- Official website points elsewhere or does not mention the repo.
- Release assets are repackaged installers from another vendor.
- The repo is archived and automation would not expect future releases.

Known anti-pattern:

- `AppWork.JDownloader` issue `microsoft/winget-pkgs#354250` reported a manifest update that changed the installer source from the official JDownloader domain to a personal GitHub mirror and used a version number not published by the vendor. Treat this as a blocking pattern: an existing package must not switch from the publisher domain to an unaffiliated GitHub account unless the publisher explicitly links that repository as official.
- When a package has no official GitHub presence, do not use community mirrors even if their release assets appear to install correctly and have stable hashes.
- For existing packages, compare the proposed source against previous manifests. A domain change from the official vendor source to GitHub, a new CDN, or a personal account requires explicit publisher cross-link evidence before continuing.

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

## Release Notes Discovery

Git-hosted applications may publish installers through repository releases even when the application itself is closed source. Treat the official repository and its release pages as valid first-party sources; `InTheLoop.LoopEmail` is an example of this distribution model.

For GitHub, GitLab, Gitea, Codeberg, Bitbucket, Gitee, GitCode, and similar platforms, inspect release-note sources in this order:

1. The body of the exact release that provides the selected desktop installer.
2. A version entry in a repository-root release history such as `CHANGELOG.md`, `RELEASES.md`, or `CHANGES.md`, including case and naming variants.
3. The desktop application's official homepage, documentation, support site, or dedicated release-history page.

A release body is not valid release notes merely because it exists. Reject an empty body, a body containing only the version/title, generated assets or download links, checksums, or other text that does not describe product changes. For example, the [ImageMagick 7.1.2-27 release](https://github.com/ImageMagick/ImageMagick/releases/tag/7.1.2-27) contains no substantive change list, so use the repository release-history files or official site instead.

For applications not released through a Git platform, search the official site footer, download page, support pages, and documentation. Confirm that the selected page describes the Windows desktop application. Do not use platform-service updates, server-only changes, web-product updates, or mobile-app release notes for a desktop manifest.

Record two sources separately:

- The raw HTML or Markdown source used to build `ReleaseNotes`.
- The human-readable official page used as `ReleaseNotesUrl`, preferably a version-specific release page or changelog anchor rather than a raw-content URL.

## Release Date Evidence

Capture `ReleaseDate` while resolving the version and installer URL:

1. For a GitHub source, use the publication date of the exact release whose assets are selected. Do not use the repository commit date or a different channel's release.
2. Otherwise use the date on an official version-specific release-notes or release-history page.
3. If neither exists, use the `Last-Modified` header returned for the installer URL.

Record the URL and evidence type with the date so later automation can reproduce it. Treat a changed `Last-Modified` value on a stable mutable URL as update-detection evidence, but do not override a more authoritative release publication date.

## WinGet Download Compatibility

An official URL that works in a browser, curl, or `Invoke-WebRequest` can still fail in WinGet because servers distinguish TLS clients, Delivery Optimization ranges, WinINet, user agents, cookies, or proxies. Test the selected URL through Dumplings' native WinGet-compatible paths:

```powershell
. .\Modules\PackageModule\Index.ps1
$Result = Test-WinGetInstallerDownload `
  -Uri $InstallerUrl `
  -ExpectedSha256 $InstallerSha256 `
  -Method Default
```

`Default` follows WinGet behavior: an explicit proxy uses WinINet; otherwise Delivery Optimization runs first, fatal policy failures stop, nonfatal failures fall back to WinINet, redirects follow WinGet's rules, and a complete download is checked against content length and SHA256.

Use response-only diagnostics for large files:

```powershell
$Result = Test-WinGetInstallerDownload -Uri $InstallerUrl -Method Both -ResponseOnly
$Result.Results | Format-Table Method, ServerAcceptedRequest, HttpStatusCode, HResult, ErrorMessage
```

`ServerAcceptedRequest` proves only that the native path accepted the request. `WouldWinGetDownload` requires a completed download. Run full `Default` mode before submission when practical.

- Delivery Optimization succeeds and WinINet fails: default WinGet can work, but explicit proxy or WinINet users can fail.
- Delivery Optimization fails nonfatally and WinINet succeeds: default fallback works.
- Delivery Optimization fails fatally: WinGet stops without fallback.
- Both reject the request: stop until the publisher provides a compatible URL.
- Completed bytes do not match SHA256: reject the evidence and investigate dynamic content.

Do not simulate WinGet by changing only `User-Agent`. Probe files are deleted unless `-KeepDownloads` is explicitly requested.
