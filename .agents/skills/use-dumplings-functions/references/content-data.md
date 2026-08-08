# Text and structured-data functions

## Text and structured data

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

- **Notes:** Prefer this helper when the response arrives as text and consistent line-ending handling matters. `Invoke-RestMethod` applies special RSS/Atom handling and may return feed items directly instead of raw XML; use `Invoke-WebRequest`, `Read-ResponseContent`, and `ConvertFrom-Xml` when the task needs the complete XML document tree.

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

## Time conversion

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
