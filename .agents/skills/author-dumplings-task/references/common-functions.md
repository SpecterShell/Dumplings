# Common Functions For Task Scripts

This reference covers the PackageModule and external-module commands most useful in `Tasks\<Name>\Script.ps1`. Core loads PackageModule and the modules declared in `Preference.yaml` before task execution. Task scripts should call these commands directly and should not import the modules again.

Use the live command metadata when a parameter is not shown here:

```powershell
Get-Command Join-Uri -Syntax
Get-Help Join-Uri -Full
```

The schemas below omit common parameters such as `-ErrorAction`. Parameters marked as forwarded belong to the named PowerShell cmdlet even when the wrapper itself has an empty formal parameter block.

## Networking And Source Retrieval

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

- **Notes:** The wrapper reads the normal Dumplings GitHub token when `-Token` is omitted, serializes dictionary bodies as JSON, and rejects token-bearing requests to non-GitHub origins unless `-AllowNonGitHubUri` is explicit. Keep that override out of ordinary public GitHub tasks.

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

- **Notes:** Use response validators only as the last-resort change detection described in `installer-source-patterns.md`.

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

## Temporary Files And Archives

### `Get-TempFile`

- **Owner:** PackageModule, `Libraries\Infrastructure\FileSystem.psm1`.
- **Schema:** `Get-TempFile [<Invoke-WebRequest arguments except -OutFile>]`.
- **Pipeline:** Follows `Invoke-WebRequest` forwarding behavior.
- **Returns:** The path to the downloaded temporary file.
- **Use:** Download one file to the Dumplings cache with normal web-request defaults.
- **Example:**

```powershell
$this.InstallerFiles[$InstallerUrl] = $InstallerFile = Get-TempFile -Uri $InstallerUrl
```

- **Notes:** Register installer downloads in `$this.InstallerFiles` so manifest updating can reuse them and PackageTask can dispose them. The helper owns `-OutFile`; callers must not pass it.

### `New-TempFile`

- **Owner:** PackageModule, `Libraries\Infrastructure\FileSystem.psm1`.
- **Schema:** `New-TempFile`.
- **Pipeline:** None.
- **Returns:** The path to a newly created empty temporary file.
- **Use:** Reserve a path for an API export or another operation that requires a destination file.
- **Example:**

```powershell
$OutputPath = New-TempFile
```

- **Notes:** The caller owns the file and removes it in `finally` unless it is deliberately registered with task-owned storage.

### `New-TempFolder`

- **Owner:** PackageModule, `Libraries\Infrastructure\FileSystem.psm1`.
- **Schema:** `New-TempFolder`.
- **Pipeline:** None.
- **Returns:** The path to a newly created temporary directory.
- **Use:** Isolate extraction or generated intermediate files.
- **Example:**

```powershell
$ExtractedPath = New-TempFolder
```

- **Notes:** Remove caller-owned directories recursively in `finally`.

### `Expand-TempArchive`

- **Owner:** PackageModule, `Libraries\Infrastructure\FileSystem.psm1`.
- **Schema:** `Expand-TempArchive [-Path] <string> [-Name <string>] [-CollisionAction <Prompt|Error|Skip|Overwrite|Rename>] [-MaximumExpandedBytes <long>]`.
- **Pipeline:** Accepts the archive path by value.
- **Returns:** The path to a new temporary extraction directory.
- **Use:** Stream selected ZIP entries through the bounded archive layer.
- **Example:**

```powershell
$ExtractedPath = Expand-TempArchive -Path $ArchivePath -Name '*.msi' -CollisionAction Error
```

- **Notes:** Omitting `-Name` extracts all entries. Specify a noninteractive collision action in task automation so a collision cannot block a worker. The caller removes the returned directory.

## Text And Structured Data

### `Format-Text`

- **Owner:** PackageModule, `Libraries\Data\Format.psm1`.
- **Schema:** `Format-Text [-Text] <string>`.
- **Pipeline:** Accepts one or more strings and combines them.
- **Returns:** One normalized string.
- **Use:** Finalize release notes and descriptions for WinGet YAML.
- **Example:**

```powershell
$ReleaseNotes = $ReleaseNotesNode | Get-TextContent | Format-Text
```

- **Notes:** The helper normalizes line endings and whitespace, removes validator-blocked control characters, decodes entities, and applies the project's CJK spacing rules. Process source structure before calling it.

### `Get-TextContent`

- **Owner:** PackageModule, `Libraries\Data\HTML.psm1`.
- **Schema:** `Get-TextContent [[-Node] <object>] [[-TableSpanMode] <Repeat|Empty|AdvancedTableXT>] [[-HeaderlessTableMode] <Empty|FirstRow>]`.
- **Pipeline:** Accepts HtmlAgilityPack nodes.
- **Returns:** Plain text with HTML block, list, line-break, and table structure preserved.
- **Use:** Convert selected PowerHTML nodes into manifest-ready source text.
- **Example:**

```powershell
$ReleaseNotes = $Document.SelectSingleNode('//section[@id="release-notes"]') | Get-TextContent | Format-Text
```

- **Notes:** Select the narrowest useful node before conversion. The table modes control how merged HTML cells are flattened.

### `Convert-MarkdownToHtml`

- **Owner:** PackageModule, `Libraries\Data\HTML.psm1`.
- **Schema:** `Convert-MarkdownToHtml [-Content] <string> [[-Extensions] <string[]>]`.
- **Pipeline:** Accepts Markdown text by value or property name.
- **Returns:** A PowerHTML-compatible HtmlAgilityPack node.
- **Use:** Route Markdown release notes through the same node-selection and text pipeline as HTML.
- **Example:**

```powershell
$ReleaseNotes = $Release.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
```

- **Notes:** Use `hardlinebreak` only when the source treats each single newline as a rendered line break, such as many GitHub release bodies.

### `ConvertTo-HtmlDecodedText`

- **Owner:** PackageModule, `Libraries\Data\HTML.psm1`.
- **Schema:** `ConvertTo-HtmlDecodedText [-Content] <string>`.
- **Pipeline:** Accepts content by value or property name.
- **Returns:** Text with HTML character entities decoded.
- **Use:** Decode a scalar that does not require DOM parsing.
- **Example:**

```powershell
$Title = $ApiResult.title | ConvertTo-HtmlDecodedText
```

- **Notes:** Use `ConvertFrom-Html` plus `Get-TextContent` when markup structure matters.

### `Split-LineEndings`

- **Owner:** PackageModule, `Libraries\Data\Text.psm1`.
- **Schema:** `Split-LineEndings [-Content] <string>`.
- **Pipeline:** Accepts content by value or property name.
- **Returns:** Strings split on CRLF or LF, including empty lines.
- **Use:** Parse line-oriented feeds and changelogs without assuming the host line ending.
- **Example:**

```powershell
$Lines = $Content | Split-LineEndings
```

- **Notes:** Empty entries are preserved. Filter them only when the source format allows it.

### `ConvertTo-UnescapedUri`

- **Owner:** PackageModule, `Libraries\Data\Text.psm1`.
- **Schema:** `ConvertTo-UnescapedUri [-Uri] <string>`.
- **Pipeline:** Accepts URI text by value.
- **Returns:** Percent-decoded URI text.
- **Use:** Decode a version or filename stored in an escaped URL.
- **Example:**

```powershell
$DecodedUrl = $InstallerUrl | ConvertTo-UnescapedUri
```

- **Notes:** Keep the original escaped URL for network requests. Decode only the portion used as metadata.

### `ConvertTo-Https`

- **Owner:** PackageModule, `Libraries\Data\Text.psm1`.
- **Schema:** `ConvertTo-Https [-Uri] <string>`.
- **Pipeline:** Accepts URI text by value.
- **Returns:** The input with a lowercase `http://` prefix replaced by `https://`.
- **Use:** Apply a publisher-proven HTTP-to-HTTPS upgrade.
- **Example:**

```powershell
$InstallerUrl = $Link.href | ConvertTo-Https
```

- **Notes:** This is a textual scheme replacement, not a connectivity test. Probe the resulting URL before recording it.

### `ConvertFrom-Base64`

- **Owner:** PackageModule, `Libraries\Data\Text.psm1`.
- **Schema:** `ConvertFrom-Base64 [-Content] <string> [-Encoding <string>]` or `ConvertFrom-Base64 [-Content] <string> [-AsByteStream]`.
- **Pipeline:** Accepts content by value or property name.
- **Returns:** Decoded text or a byte array.
- **Use:** Decode source-provided Base64 fields.
- **Example:**

```powershell
$DecodedText = $Payload | ConvertFrom-Base64 -Encoding UTF-8
```

- **Notes:** Missing Base64 padding is supplied for text mode. Do not confuse a Base64 checksum header with manifest SHA256.

### `ConvertFrom-Xml`

- **Owner:** PackageModule, `Libraries\Data\Object.psm1`.
- **Schema:** `ConvertFrom-Xml [-Content] <string>`.
- **Pipeline:** Accepts one or more XML strings and combines them.
- **Returns:** A `System.Xml.XmlDocument`.
- **Use:** Parse appcasts, property lists, and vendor XML after retrieving the source text.
- **Example:**

```powershell
$Appcast = Invoke-WebRequest -Uri $FeedUrl | Read-ResponseContent | ConvertFrom-Xml
```

- **Notes:** Prefer this helper when the response arrives as text and consistent line-ending handling matters.

### `ConvertFrom-Ini`

- **Owner:** PackageModule, `Libraries\Data\Object.psm1`.
- **Schema:** `ConvertFrom-Ini [-Content] <string> [-DuplicateKeyAction <Array|First|Last|Error>] [-CommentChars <char[]>] [-IgnoreComments]` or `ConvertFrom-Ini [-Path] <string> [-MaximumBytes <long>] [-FallbackEncoding <string>] [-DuplicateKeyAction <Array|First|Last|Error>] [-CommentChars <char[]>] [-IgnoreComments]`.
- **Pipeline:** The content parameter set accepts text by value or property name.
- **Returns:** A case-insensitive ordered dictionary of sections and keys.
- **Use:** Parse bounded installer or publisher INI metadata.
- **Example:**

```powershell
$Configuration = ConvertFrom-Ini -Path $IniPath -MaximumBytes 4MB -DuplicateKeyAction Last
```

- **Notes:** `Array` is the compatibility default for duplicate keys. The path parameter set detects BOMs and BOM-less UTF-16 and supports an explicit legacy fallback encoding.

### `ConvertTo-OrderedList`

- **Owner:** PackageModule, `Libraries\Data\Text.psm1`.
- **Schema:** `ConvertTo-OrderedList [-Content] <string[]>`.
- **Pipeline:** Accepts strings by value or property name.
- **Returns:** One newline-joined numbered list.
- **Use:** Format line-oriented source entries as release-note list items.
- **Example:**

```powershell
$ReleaseNotes = $Items | ConvertTo-OrderedList | Format-Text
```

- **Notes:** Existing line breaks inside each input are also numbered.

### `ConvertTo-UnorderedList`

- **Owner:** PackageModule, `Libraries\Data\Text.psm1`.
- **Schema:** `ConvertTo-UnorderedList [-Content] <string[]>`.
- **Pipeline:** Accepts strings by value.
- **Returns:** One newline-joined list prefixed with `- `.
- **Use:** Format source entries that do not have an inherent order.
- **Example:**

```powershell
$ReleaseNotes = $Items | ConvertTo-UnorderedList | Format-Text
```

- **Notes:** Existing line breaks inside each input receive their own prefix.

## Time Conversion

### `ConvertFrom-UnixTimeSeconds`

- **Owner:** PackageModule, `Libraries\Data\Conversion.psm1`.
- **Schema:** `ConvertFrom-UnixTimeSeconds [-Seconds] <long>`.
- **Pipeline:** Accepts the timestamp by value.
- **Returns:** A UTC `DateTime`.
- **Use:** Convert Unix timestamps expressed in seconds.
- **Example:**

```powershell
$ReleaseTime = $Release.timestamp | ConvertFrom-UnixTimeSeconds
```

- **Notes:** Confirm the source unit before choosing this function.

### `ConvertFrom-UnixTimeMilliseconds`

- **Owner:** PackageModule, `Libraries\Data\Conversion.psm1`.
- **Schema:** `ConvertFrom-UnixTimeMilliseconds [-Milliseconds] <long>`.
- **Pipeline:** Accepts the timestamp by value.
- **Returns:** A UTC `DateTime`.
- **Use:** Convert Unix timestamps expressed in milliseconds.
- **Example:**

```powershell
$ReleaseTime = $Release.timestamp | ConvertFrom-UnixTimeMilliseconds
```

- **Notes:** A seconds value passed here produces an incorrect historical date; verify the source schema.

### `ConvertTo-UtcDateTime`

- **Owner:** PackageModule, `Libraries\Data\Conversion.psm1`.
- **Schema:** `ConvertTo-UtcDateTime [-DateTime] <datetime> -Id <string>`.
- **Pipeline:** Accepts the local date by value.
- **Returns:** The equivalent UTC `DateTime`.
- **Use:** Convert a publisher date whose timezone is known but absent from the text.
- **Example:**

```powershell
$ReleaseTime = $PublishedAt | ConvertTo-UtcDateTime -Id 'China Standard Time'
```

- **Notes:** `-Id` is a system `TimeZoneInfo` identifier. Do not guess a timezone from language or publisher country.

## Update Feed Conversion

### `ConvertFrom-SquirrelReleases`

- **Owner:** PackageModule, `Libraries\Installers\Squirrel.psm1`.
- **Schema:** `ConvertFrom-SquirrelReleases [-Content] <string>`.
- **Pipeline:** Accepts feed text by value or property name.
- **Returns:** Parsed Squirrel release records, including filename or URL, SHA1, size, version, delta status, and staging evidence.
- **Use:** Parse an already retrieved Squirrel `RELEASES` feed.
- **Example:**

```powershell
$Releases = Invoke-WebRequest -Uri $FeedUrl | Read-ResponseContent | ConvertFrom-SquirrelReleases
```

- **Notes:** The converter performs no network access. Exclude delta packages and select the correct architecture or channel after parsing.

### `ConvertFrom-ElectronBuilderUpdateFeed`

- **Owner:** PackageModule, `Libraries\Installers\NSIS.psm1`.
- **Schema:** `ConvertFrom-ElectronBuilderUpdateFeed [-Content] <string>`.
- **Pipeline:** Accepts feed text by value or property name.
- **Returns:** An object with `Version`, `Path`, `Sha512`, `Files`, `ReleaseDate`, and `StagingPercentage`.
- **Use:** Parse an already retrieved electron-updater `latest.yml` feed.
- **Example:**

```powershell
$Feed = Invoke-RestMethod -Uri $FeedUrl | ConvertFrom-ElectronBuilderUpdateFeed
```

- **Notes:** The converter uses `ConvertFrom-Yaml` and performs no network access. Select every applicable architecture explicitly and reject update-only artifacts or stale feeds.

## Scoped Playwright Access

Use Playwright only when ordinary HTTP and structured APIs cannot expose the required source. Keep the lease block short and return strings, URLs, numbers, or dictionaries. A task must not retain a page, locator, context, browser, response, or JavaScript handle after the lease ends.

### `Use-PlaywrightPage`

- **Owner:** PackageModule, `Libraries\Browser\Playwright.psm1`.
- **Schema:** `Use-PlaywrightPage [-ScriptBlock] <scriptblock> [-Browser <Chromium>] [-Channel <string>] [-Headless] [-BlockUrlPattern <string[]>] [-Stealth] [-DisableResources] [-BlockedDomain <string[]>] [-UserAgent <string>] [-Locale <string>] [-TimezoneId <string>] [-ExtraHTTPHeaders <IDictionary>] [-Proxy <uri>] [-ProxyCredential <pscredential>] [-ProxyBypass <string>] [-IgnoreHTTPSErrors] [-BlockWebRTC] [-DisableWebGL] [-DnsOverHttps] [-InitScriptPath <string>] [-ExtraBrowserArgument <string[]>] [-Screenshot]`.
- **Pipeline:** None.
- **Returns:** Script-block output unchanged after releasing the shared browser lease.
- **Use:** Run several dependent browser operations against one leased page.
- **Example:**

```powershell
$InstallerUrl = Use-PlaywrightPage -Headless -Stealth -ScriptBlock { param($Page) $null = Open-PlaywrightPage -Page $Page -Uri $DownloadPage; Read-PlaywrightLocator -Page $Page -Selector 'a.download' -Property Attribute -AttributeName href }
```

- **Notes:** The script block receives `Page`, `Context`, `Browser`, and `Session`. Use the synchronous bridge helpers below instead of awaiting Playwright tasks directly. `-Screenshot` writes final evidence to `Outputs` after success or failure.

### `Invoke-PlaywrightFetch`

- **Owner:** PackageModule, `Libraries\Browser\Playwright.psm1`.
- **Schema:** `Invoke-PlaywrightFetch [-Uri] <uri> [-Headless] [-Stealth] [-DisableResources] [-WaitUntil <string>] [-NetworkIdle] [-WaitSelector <string>] [-WaitSelectorState <string>] [-CaptureXhr <string>] [-PageSetup <scriptblock>] [-PageAction <scriptblock>] [-SolveCloudflare] [-MaximumRetryCount <int>] [-RetryIntervalSeconds <int>] [-Screenshot] [<Playwright session parameters>]`.
- **Pipeline:** None.
- **Returns:** Detached page evidence containing the final URL, status, headers, HTML, body text, challenge state, attempt count, and any selected XHR captures.
- **Use:** Perform one bounded browser fetch without manually managing a page lease.
- **Example:**

```powershell
$Evidence = Invoke-PlaywrightFetch -Uri $DownloadPage -Headless -Stealth -WaitSelector 'a.download' -Screenshot
```

- **Notes:** `-SolveCloudflare` requires `-Stealth` and remains best effort. A delayed or challenged page is not proof that a stable automation source exists.

### `Open-PlaywrightPage`

- **Owner:** PackageModule, `Libraries\Browser\Playwright.psm1`.
- **Schema:** `Open-PlaywrightPage [-Page] <object> [-Uri] <uri> [[-WaitUntil] <Commit|DOMContentLoaded|Load|NetworkIdle>] [[-Referer] <uri>]`.
- **Pipeline:** None.
- **Returns:** The temporary Playwright HTTP response metadata for use inside the active lease.
- **Use:** Navigate the page supplied by `Use-PlaywrightPage`.
- **Example:**

```powershell
$null = Open-PlaywrightPage -Page $Page -Uri $DownloadPage -WaitUntil Load
```

- **Notes:** Do not return the response object from the lease.

### `Read-PlaywrightLocator`

- **Owner:** PackageModule, `Libraries\Browser\Playwright.psm1`.
- **Schema:** `Read-PlaywrightLocator [-Page] <object> [-Selector] <string> [[-Property] <InnerHTML|InnerText|TextContent|Attribute>] [[-AttributeName] <string>] [[-State] <Attached|Visible>] [[-TimeoutMilliseconds] <int>] [-Optional]`.
- **Pipeline:** None.
- **Returns:** One detached string or null for an optional missing locator.
- **Use:** Wait for one element and read its content or attribute without leaking a locator.
- **Example:**

```powershell
$Href = Read-PlaywrightLocator -Page $Page -Selector 'a.download' -Property Attribute -AttributeName href
```

- **Notes:** `-AttributeName` is required for `-Property Attribute`. Prefix XPath selectors with `xpath=`.

### `Read-PlaywrightPageContent`

- **Owner:** PackageModule, `Libraries\Browser\Playwright.psm1`.
- **Schema:** `Read-PlaywrightPageContent [-Page] <object>`.
- **Pipeline:** None.
- **Returns:** The current page HTML as detached text.
- **Use:** Pass the rendered document to PowerHTML after the lease.
- **Example:**

```powershell
$Html = Read-PlaywrightPageContent -Page $Page
```

- **Notes:** Return this string from the scoped block rather than the page object.

### `Invoke-PlaywrightJavaScript`

- **Owner:** PackageModule, `Libraries\Browser\Playwright.psm1`.
- **Schema:** `Invoke-PlaywrightJavaScript [-Page] <object> [-Expression] <string> [[-Argument] <object>] [[-TimeoutMilliseconds] <int>]`.
- **Pipeline:** None.
- **Returns:** A JSON-safe PowerShell value detached from the browser.
- **Use:** Read application state that is exposed only through page JavaScript.
- **Example:**

```powershell
$Data = Invoke-PlaywrightJavaScript -Page $Page -Expression '() => window.__INITIAL_STATE__'
```

- **Notes:** The expression must be a JavaScript function. Arguments and results must be JSON serializable.

## External Modules Loaded By Core

`Preference.yaml` declares [PowerHTML](https://github.com/JustinGrote/PowerHTML) and [powershell-yaml](https://github.com/cloudbase/powershell-yaml). Core installs or loads them before PackageModule and task execution. Do not add `Import-Module` calls to task scripts.

### `ConvertFrom-Html`

- **Owner:** PowerHTML.
- **Schema:** `ConvertFrom-Html [-Content] <string[]> [-Raw]`, `ConvertFrom-Html [-URI] <uri[]> [-Raw]`, or `ConvertFrom-Html [-Path] <FileInfo[]> [-Raw]`.
- **Pipeline:** Accepts HTML strings, URI values, files, and compatible web-response content.
- **Returns:** The document node by default, or an `HtmlAgilityPack.HtmlDocument` with `-Raw`.
- **Use:** Parse HTML for XPath or node traversal.
- **Example:**

```powershell
$Document = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html
$ReleaseNotesTitleNode = $Document.SelectSingleNode('//h2[contains(., "Release notes")]')
$ReleaseNotesNodes = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()')
$ReleaseNotes = $ReleaseNotesNodes | Get-TextContent | Format-Text
```

- **Notes:** Prefer retrieving content with Dumplings networking helpers when the site requires headers, cookies, retries, or encoding handling. Use `Get-TextContent` on selected nodes rather than relying on raw `InnerText` for structured release notes.

### `ConvertFrom-Yaml`

- **Owner:** powershell-yaml.
- **Schema:** `ConvertFrom-Yaml [[-Yaml] <string>] [-AllDocuments] [-Ordered] [-UseMergingParser]`.
- **Pipeline:** Accepts YAML text by value.
- **Returns:** A PowerShell object, ordered dictionaries with `-Ordered`, or all documents with `-AllDocuments`.
- **Use:** Parse vendor YAML feeds and structured task data.
- **Example:**

```powershell
$Feed = $FeedText | ConvertFrom-Yaml -Ordered
```

- **Notes:** Use `-UseMergingParser` only when the source intentionally relies on YAML merge keys. This command parses data; it does not apply WinGet manifest schema validation.

### `ConvertTo-Yaml`

- **Owner:** powershell-yaml.
- **Schema:** `ConvertTo-Yaml [[-Data] <object>] [-OutFile <string>] [-JsonCompatible] [-UseFlowStyle] [-KeepArray] [-Force]` or `ConvertTo-Yaml [[-Data] <object>] [-OutFile <string>] [-Options <SerializationOptions>] [-UseFlowStyle] [-KeepArray] [-Force]`.
- **Pipeline:** Accepts data by value.
- **Returns:** YAML text, or writes the YAML to `-OutFile`.
- **Use:** Serialize provider catalogs or task-owned structured output.
- **Example:**

```powershell
$Catalog | ConvertTo-Yaml -OutFile $CatalogPath -Options DisableAliases -Force
```

- **Notes:** Prefer `[ordered]` dictionaries for deterministic output. `-Force` applies to replacing `-OutFile`; it does not validate the data against a schema.

## Legacy Installer Readers

Historical tasks frequently call several `Read-ProductVersionFrom*`, `Read-ProductCodeFrom*`, or `Read-UpgradeCodeFrom*` functions against the same installer. Do not copy that pattern into a new task. Cache the installer when task-side version discovery is required, call the applicable aggregate `Get-<Family>Info` function once, and reuse the returned object. Prefer model-side manifest analysis when the task does not need installer metadata before `Check()`.

Full installer-family APIs, extraction rules, and result contracts belong to the [installer analysis skill](../../analyze-winget-installer/SKILL.md). Source-specific task recipes remain in [Installer Source Patterns](installer-source-patterns.md) and [Release Metadata Patterns](release-metadata-patterns.md).
