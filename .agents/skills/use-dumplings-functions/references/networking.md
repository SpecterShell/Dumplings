# Networking functions

## Networking and source retrieval

### `Invoke-GitHubApi`

- **Owner:** PackageModule, `Libraries\Networking\GitHub.psm1`.
- **Schema:** `Invoke-GitHubApi -Uri <uri> [-Token <object>] [-AllowNonGitHubUri] [<Invoke-RestMethod parameters>]`.
- **Pipeline:** Matches the applicable `Invoke-RestMethod` parameter set.
- **Returns:** The deserialized REST or GraphQL response.
- **Use:** Call GitHub REST and GraphQL endpoints with automatic token handling and GitHub error formatting.
- **Example:**

```powershell
$Release = Invoke-GitHubApi -Uri 'https://api.github.com/repos/owner/repository/releases/latest'
```

- **Notes:** Core supplies the normal Dumplings GitHub token. In an independent shell, pass `-Token` or set `$env:GH_DUMPLINGS_TOKEN` before calling the wrapper; it deliberately does not fall back to GitHub's unauthenticated 60-request-per-hour allowance. API exceptions include available rate-limit reset, retry, request-ID, and validation details. The wrapper rejects token-bearing requests to non-GitHub origins unless `-AllowNonGitHubUri` is explicit; keep that override out of ordinary public GitHub tasks.

### `Join-Uri`

- **Owner:** PackageModule, `Libraries\Networking\Web.psm1`.
- **Schema:** `Join-Uri [-Uri] <uri[]> [-ChildUri] <string[]> [[-AdditionalChildUri] <string[]>]`.
- **Pipeline:** Accepts the base URI by value.
- **Returns:** One absolute URI string for each input URI and child combination.
- **Use:** Resolve relative links without manual slash handling.
- **Example:**

```powershell
$InstallerUrl = Join-Uri $DownloadPage $Link.href
```

- **Notes:** Child values are applied in order. Verify the resulting host before recording an installer URL.

### `Split-Uri`

- **Owner:** PackageModule, `Libraries\Networking\Web.psm1`.
- **Schema:** `Split-Uri [-Uri] <uri> [-Parent]`, `Split-Uri [-Uri] <uri> [-LeftPart <UriPartial>]`, or `Split-Uri [-Uri] <uri> [-Components <UriComponents[]>] [-Format <UriFormat>]`.
- **Pipeline:** Accepts the URI by value.
- **Returns:** The selected URI portion as a string.
- **Use:** Obtain a parent URL, origin, path, or another structured URI component.
- **Example:**

```powershell
$FeedRoot = Split-Uri $FeedUrl -Parent
```

- **Notes:** Prefer this helper over string replacement when the operation is based on URI structure.

### `Get-RedirectedUrl`

- **Owner:** PackageModule, `Libraries\Networking\Web.psm1`.
- **Schema:** `Get-RedirectedUrl [<Invoke-WebRequest arguments except -Method>]`.
- **Pipeline:** Follows `Invoke-WebRequest` forwarding behavior.
- **Returns:** The final absolute request URI as a string.
- **Use:** Follow the complete redirect chain through a HEAD request.
- **Example:**

```powershell
$InstallerUrl = Get-RedirectedUrl -Uri $DownloadUrl -UserAgent $DumplingsBrowserUserAgent
```

- **Notes:** The function forces `-Method Head`. Use `Get-RedirectedUrls` when the intermediate targets matter or when the endpoint needs GET.

### `Get-RedirectedUrl1st`

- **Owner:** PackageModule, `Libraries\Networking\Web.psm1`.
- **Schema:** `Get-RedirectedUrl1st [<Get-RedirectedUrls arguments>]`.
- **Pipeline:** Follows `Get-RedirectedUrls` forwarding behavior.
- **Returns:** The first redirect target, or the original URI when no redirect occurs.
- **Use:** Capture only the first hop from a stable publisher endpoint.
- **Example:**

```powershell
$FirstTarget = Get-RedirectedUrl1st -Uri $DownloadUrl -Method GET
```

- **Notes:** This does not return the final target when the chain has multiple redirects.

### `Get-RedirectedUrls`

- **Owner:** PackageModule, `Libraries\Networking\Web.psm1`.
- **Schema:** `Get-RedirectedUrls [-Uri] <string> [-Method <GET|HEAD>] [-Headers <IDictionary>] [-UserAgent <string>] [-ConnectionTimeoutSeconds <int>]`.
- **Pipeline:** Accepts the URI by value.
- **Returns:** Redirect targets in order, or the original URI when no redirect occurs.
- **Use:** Inspect each hop and detect version-bearing or suspicious domain changes.
- **Example:**

```powershell
$RedirectChain = @(Get-RedirectedUrls -Uri $DownloadUrl -Method GET -UserAgent $DumplingsBrowserUserAgent)
```

- **Notes:** The helper disables automatic redirects and follows `Location` itself. Validate every cross-domain hop.

### `Get-WebResponseHeader`

- **Owner:** PackageModule, `Libraries\Networking\Web.psm1`.
- **Schema:** `Get-WebResponseHeader [-Uri] <string> [-Method <GET|HEAD>] [-Headers <IDictionary>] [-UserAgent <string>] [-ConnectionTimeoutSeconds <int>]`.
- **Pipeline:** Accepts the URI by value.
- **Returns:** An object with `StatusCode`, `ReasonPhrase`, `RequestUri`, and a case-insensitive `Headers` dictionary.
- **Use:** Read response headers without buffering the response body.
- **Example:**

```powershell
$Response = Get-WebResponseHeader -Uri $InstallerUrl -Method GET -UserAgent $DumplingsDefaultUserAgent
```

- **Notes:** Use response validators only as the last-resort change detection described in the task-authoring [versionless source workflow](../../author-dumplings-task/references/sources/versionless.md).

### `Read-ResponseContent`

- **Owner:** PackageModule, `Libraries\Networking\Web.psm1`.
- **Schema:** `Read-ResponseContent [-RawContentStream] <Stream> [-Encoding <string>]`.
- **Pipeline:** Accepts a stream directly or the `RawContentStream` property by name.
- **Returns:** Decoded response text.
- **Use:** Decode feeds that may contain a BOM or use a non-default encoding.
- **Example:**

```powershell
$FeedText = Invoke-WebRequest -Uri $FeedUrl | Read-ResponseContent
```

- **Notes:** The helper rewinds the stream. Supply `-Encoding` only when the source declares an encoding that automatic BOM handling cannot establish.

### `Get-EmbeddedJson`

- **Owner:** PackageModule, `Libraries\Networking\Web.psm1`.
- **Schema:** `Get-EmbeddedJson [-Content] <string> [-StartsFrom <string>]`.
- **Pipeline:** Accepts content by value or property name.
- **Returns:** The first valid embedded JSON value as JSON text.
- **Use:** Remove a JSONP callback or another fixed prefix before normal JSON conversion.
- **Example:**

```powershell
$Data = $ResponseText | Get-EmbeddedJson -StartsFrom 'callback(' | ConvertFrom-Json -AsHashtable
```

- **Notes:** Use a source-specific, verified prefix. Do not use this as arbitrary script evaluation.
