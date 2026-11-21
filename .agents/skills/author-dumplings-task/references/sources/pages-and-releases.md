# Installer pages and release assets

See the [task example index](../example-index.md) for current implementations of these patterns.

## HTML Installer Links

`HP.HPCMSL` obtains the installer from `Invoke-WebRequest.Links` and parses the version from that URL before `Check()`:

```powershell
$Page = Invoke-WebRequest -Uri $DownloadPage

$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $DownloadPage $Page.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href -match 'product-token' -and $_.href -notmatch 'update|portable' } catch {} }, 'First')[0].href
}
```

Filter HTML links using `href`, not a guessed filename property. Start with the file extension, then add architecture, platform, installer/setup, product, and exclusion predicates that are present in the URL. Use `Contains('.exe')` or `Contains('.msi')` instead of `EndsWith()` when the URL has query parameters. Inspect a parent element only when architecture or product evidence is absent from `href`.

Use `Join-Uri` for relative links. Require one matching link and verify that it is official. Handle optional HTML release metadata only after `Check()` by following [HTML release notes](../release/html-markdown.md#html-release-notes).

## Atlassian Confluence Blogs

Public Confluence spaces expose blog posts through the anonymous REST API, which is the reliable source for release notes. `Vivi.Vivi` lists the space's posts with `Invoke-RestMethod -Uri 'https://vivi.atlassian.net/wiki/rest/api/content?spaceKey=VRB&type=blogpost&limit=200'`, matches the current version against post titles with a digit-boundary regex such as `"(?<![\d.])$([regex]::Escape($this.CurrentState.Version))(?![\d.])"`, then fetches the matched post with `/wiki/rest/api/content/<id>?expand=body.view`. Build the post URL from `_links.base` plus `_links.webui` (the list response has no server-side sort, and `webui` is root-relative, so `Join-Uri` against the base host drops the `/wiki` segment), and extract the notes text from the whole `body.view.value` HTML because it has no `wiki-content` wrapper. Do not call `/cgraphql`: Atlassian now rejects every non-persisted GraphQL operation there with `OperationBlocked`, including named anonymous queries.

## Drupal Views AJAX

Drupal sites that expose a download listing as a View (look for `"views":{"ajax_path":"/views/ajax","ajaxViews":{...}}` in the page's `drupal-settings-json` script) can be queried directly with `Invoke-RestMethod` against `<ajax_path>?view_name=<name>&view_display_id=<display>&view_args=&view_path=<path>&pager_element=0&page=<n>` plus the view's exposed filter names as plain query parameters; no `X-Requested-With` header, CSRF token, `view_dom_id`, or `ajax_page_state` blob is required by the server. The response is a JSON array of command objects — join the `data` of the `insert` commands and parse the resulting HTML with the same regexes used for the static page. Prefer exposed-filter scoping (for example an operating-system filter) over scraping the unfiltered pager: a filtered result set is contiguous, so the first page without matches reliably ends enumeration, whereas the unfiltered pager can interleave filtered-out rows and present empty pages mid-sequence. `#OpenLogic` demonstrates this against `openlogic.com/views/ajax`.

## Select Full Installer Assets

Do not submit an update-only artifact as the package installer. Reject names or URLs that identify `update`, `updater`, delta, auto-update, patch, or portable artifacts when the package represents the installed desktop application. Use portable assets only for portable packages. An electron-builder portable NSIS executable cannot replace the installable setup. An updater artifact is valid only when the package itself represents that updater.

`appmakes.Typora` demonstrates a feed whose `download` fields point to update artifacts. Its task replaces `update` with `setup` for every architecture and locale. `Vivaldi.Vivaldi` replaces `stable-auto` with `stable`. Treat such rewrites as source-specific rules: probe every derived URL, verify its version and architecture, and confirm that it is a full installer before using it.

For release pages with several artifacts, list the candidate names before writing the filter. Do not select the first `.exe`, `.msi`, or `.zip` and assume it is suitable.

## GitHub Releases

Use the authenticated GitHub proxy.

```powershell
$Release = Invoke-GitHubApi -Uri 'https://api.github.com/repos/owner/repository/releases/latest'

# Version
$this.CurrentState.Version = $Release.tag_name -replace '^v'

# InstallerUrl
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = $Release.assets.Where({ $_.name.EndsWith('.msi') -and $_.name.Contains('x64') -and $_.name -match 'Prism' -and $_.name -notmatch 'debug|portable|update' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Release.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('x64') -and $_.name -match 'Prism' -and $_.name -match 'Setup' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
# Omit NestedInstallerFiles when all nested paths and aliases stay unchanged.
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'x64'
  InstallerType       = 'zip'
  NestedInstallerType = 'nullsoft'
  InstallerUrl        = $Release.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('x64') -and $_.name -match 'Prism' -and $_.name -match 'Setup' -and $_.name -match 'Windows' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
# If RelativeFilePath is not static, but has the same pattern as the archive filename across versions
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('amd64') -and $_.name -match 'windows' }, 'First')
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerType        = 'zip'
  NestedInstallerType  = 'portable'
  NestedInstallerFiles = @([ordered]@{ RelativeFilePath = "$($Asset.name | Split-Path -LeafBase)\mindfs.exe" })
  InstallerUrl         = $Asset.browser_download_url | ConvertTo-UnescapedUri
}
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name -match 'windows' -and $_.name.Contains('arm64') }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'arm64'
  InstallerUrl         = $Asset.browser_download_url | ConvertTo-UnescapedUri
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath     = "$($Asset.name | Split-Path -LeafBase).exe"
      PortableCommandAlias = 'jjui'
    }
  )
}
```

Write the repository owner and name directly in each requested URL. Use `-replace` for tag cleanup. Build each candidate predicate in this order, using only facts present in the real name or URL. GitHub release assets use `name`. Objects from `Invoke-WebRequest.Links` use `href`.

Keep extension, architecture, platform, product, and installer-form checks as separate predicates joined with `-and`. Replace `$_.name.EndsWith('Setup.exe')` with `$_.name.EndsWith('.exe') -and $_.name -match 'Setup'`. Apply the same rule to `href` filters. Combined suffixes or substrings couple independent requirements and can miss valid naming variations.

1. Require the extension with `EndsWith('.exe')`, `EndsWith('.msi')`, or the expected archive suffix. If a page-link URL has query parameters, use `Contains('.exe')` or `Contains('.msi')` against `href` instead.
2. Require the source architecture token with `.Contains()`, for example `.Contains('x64')` or `.Contains('amd64')`, when one is present. Use it to narrow candidates, but write WinGet `Architecture` only after the installer or payload confirms the architecture.
3. For archives or other ambiguous extensions than `.exe`, `.msi` and `.msix`, require the Windows platform marker, preserving the source's spelling and casing on the right-hand side, for example `-match 'Windows'`.
4. Require `Installer`, `Setup`, or another source-specific product-form marker with `-match` when releases contain both installable and non-installable builds, and the installable ones have extensions other than `.msi` and `.msix`. Require `portable` only when authoring the portable package. Otherwise exclude it with `-notmatch`.
5. Prefer the `msvc` build over a GNU build when both are published for Windows.
6. Exclude unwanted variants such as `debug`, symbols, checksums, deltas, updater packages, and electron-builder portable executables.
7. Require the product name with `-match` when one release contains assets for several products.

Use `.Contains()` only for literal architecture tokens and extensions in URLs with query parameters. Use `-match` or `-notmatch` for platform, product, installer form, runtime, edition, channel, and other semantic labels. Escape regex metacharacters when a label must remain a literal substring.

Keep task installer entries limited to the selectors and values needed for the update. An omitted `Scope` can match both existing `user` and `machine` entries when they use the same installer asset. Omit unchanged fields such as `NestedInstallerFiles` when its `RelativeFilePath` values and aliases stay constant. Follow [installer entry matching](../manifest/update-contract.md#installer-entry-matching) and [explicit installer overrides](../manifest/update-contract.md#explicit-installer-overrides) for wildcard matching and inherited values.

Map source architecture labels to WinGet values.

| Source labels | WinGet `Architecture` |
| --- | --- |
| `i386`, `i686`, `x86` | `x86` |
| `amd64`, `x64`, `x86_64`, `win64` | `x64` |
| `arm32` | `arm` |
| `aarch64`, `arm64` | `arm64` |
| Bare `arm` | Ambiguous: inspect the installer because it may mean ARM32 or ARM64 |
| `win32` | Ambiguous: inspect the installer because publishers may use it for either x86 or x64 Windows software |
| No binaries | `neutral` only when the package genuinely contains no binary files |

Use filename labels to select candidates, then verify binary architecture. Check the PE machine type, MSI/MSIX package metadata, installer-family metadata, and the architecture of the installed or nested primary executable. For an archive, inspect the configured command and its dependent native files. Do not use a bare `.Contains('arm')` predicate when both ARM32 and ARM64 assets exist because it can select either one.

`1357310795.TboxWebdav` demonstrates Windows, architecture, and `no-runtime` filters for ZIP assets. `astral-sh.uv` demonstrates translating Rust target triples such as `i686`, `x86_64`, and `aarch64`. `A2-Ai.rv` and `houseabsolute.ubi` add `msvc`. `EpicGames.Lore` adds product-name and debug exclusions. `qyzhg.Prism` requires setup for its EXE and differentiates EXE and MSI assets.

`qyzhg.Prism` is the compact example for tag and asset handling with separate NSIS EXE and WiX MSI entries. Select both independent full-installer families when published for the matching release, and filter each family separately. Apply the [artifact-selection policy](../../../author-winget-manifest/references/package/artifact-selection.md#include-independent-installer-families), including its narrower exception for an equivalent InstallShield or Advanced Installer EXE wrapper around the direct MSI. Parse the release date and release body separately by following [Git-hosted release metadata](../release/html-markdown.md#git-hosted-release-metadata).

`7zip.7zip` demonstrates multiple installer families, but each family and architecture must still match the current manifest and current artifact policy.

When releases are files committed to a repository rather than release assets, follow `JurgenRathlev.innounp`: call the contents API for the exact folder, extract only filename versions that match the package convention, sort with `[ChunkVersion]`, query the latest commit for that selected path, and build a raw URL pinned to the commit SHA.
