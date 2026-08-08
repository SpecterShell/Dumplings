# Installer pages and release assets

See the [task example index](../example-index.md) for current implementations of these patterns.

## HTML Installer Links

`HP.HPCMSL` obtains the installer from `Invoke-WebRequest.Links` and parses the version from that URL before `Check()`:

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

Filter HTML links using `href`, not a guessed filename property. Start with the file extension, then add architecture, platform, installer/setup, product, and exclusion predicates that are present in the URL. Use `Contains('.exe')` or `Contains('.msi')` instead of `EndsWith()` when the URL has query parameters. Inspect a parent element only when architecture or product evidence is absent from `href`.

Use `Join-Uri` for relative links. Require one matching link and verify that it is official. Handle optional HTML release metadata only after `Check()` by following [HTML release notes](../release/html-markdown.md#html-release-notes).

## Select Full Installer Assets

Do not submit an update-only artifact as the package installer. Reject names or URLs that identify `update`, `updater`, delta, auto-update, patch, or portable artifacts when the package represents the installed desktop application. A portable asset is valid only for an intentionally portable package; an electron-builder portable NSIS executable is not the installable NSIS setup. An updater artifact is valid only when the package itself represents that updater.

`appmakes.Typora` demonstrates a feed whose `download` fields point to update artifacts. Its task replaces `update` with `setup` for every architecture and locale. `Vivaldi.Vivaldi` replaces `stable-auto` with `stable`. Treat such rewrites as source-specific rules: probe every derived URL, verify its version and architecture, and confirm that it is a full installer before using it.

For release pages with several artifacts, list the candidate names before writing the filter. Do not select the first `.exe`, `.msi`, or `.zip` and assume it is suitable.

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

Build each candidate predicate in this order, using only facts present in the real name or URL. GitHub release assets use `name`; objects from `Invoke-WebRequest.Links` use `href`.

1. Require the extension with `EndsWith('.exe')`, `EndsWith('.msi')`, or the expected archive suffix. If a page-link URL has query parameters, use `Contains('.exe')` or `Contains('.msi')` against `href` instead.
2. Require the source architecture token when one is present. Use it to narrow candidates, but write WinGet `Architecture` only after the installer or payload confirms the architecture.
3. For archives or other ambiguous extensions, require the Windows platform marker, preserving the source's spelling and casing on the right-hand side, for example `-match 'Windows'`.
4. Require `Installer`, `Setup`, or another source-specific product-form marker when releases contain both installable and non-installable builds. Require `portable` only when authoring the portable package; otherwise exclude it.
5. Prefer the `msvc` build over a GNU build when both are published for Windows.
6. Exclude unwanted variants such as `debug`, symbols, checksums, deltas, updater packages, and electron-builder portable executables.
7. Require the product name when one release contains assets for several products.

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

Filename labels select candidates; they do not override binary evidence. Check the PE machine type, MSI/MSIX package metadata, installer-family metadata, and the architecture of the installed or nested primary executable. For an archive, inspect the configured command and its dependent native files. Do not use a bare `.Contains('arm')` predicate when both ARM32 and ARM64 assets exist because it can select either one.

`1357310795.TboxWebdav` demonstrates Windows, architecture, and `no-runtime` filters for ZIP assets. `astral-sh.uv` demonstrates translating Rust target triples such as `i686`, `x86_64`, and `aarch64`. `A2-Ai.rv` and `houseabsolute.ubi` add `msvc`; `EpicGames.Lore` adds product-name and debug exclusions. `qyzhg.Prism` requires setup for its EXE and differentiates EXE and MSI assets.

`qyzhg.Prism` is the compact example for tag and asset handling. Reuse its GitHub source pattern only: it currently lists both EXE and MSI artifacts, while current authoring policy prefers the direct MSI when an equivalent InstallShield or Advanced Installer wrapper would install the same ARP identity. Parse the release date and release body separately by following [Git-hosted release metadata](../release/html-markdown.md#git-hosted-release-metadata).

`7zip.7zip` demonstrates multiple installer families, but each family and architecture must still match the current manifest and current artifact policy.

When releases are files committed to a repository rather than release assets, follow `JurgenRathlev.innounp`: call the contents API for the exact folder, extract only filename versions that match the package convention, sort with `[ChunkVersion]`, query the latest commit for that selected path, and build a raw URL pinned to the commit SHA.
