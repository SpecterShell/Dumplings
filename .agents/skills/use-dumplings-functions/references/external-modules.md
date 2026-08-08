# External modules loaded by Core

## External modules loaded by Core

`Preference.yaml` declares [PowerHTML](https://github.com/JustinGrote/PowerHTML) and [powershell-yaml](https://github.com/cloudbase/powershell-yaml). Core installs or loads them before PackageModule and task execution. Do not add `Import-Module` calls to task scripts. In an independent shell, load them as described in the shared skill's [execution context](../SKILL.md#execution-context).

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
