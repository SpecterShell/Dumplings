# Task example index

Open the named task directly and read its current `Config.yaml` and `Script.ps1`. Reuse the source and parsing shape, but verify every package-specific assumption.

## Installer and source patterns
| Pattern | Primary examples | What to reuse |
| --- | --- | --- |
| HTML installer links | `HP.HPCMSL`, `Amazon.AppStream`, `Argente.Utilities`, `RawTherapee.RawTherapee` | Link filtering, official URL resolution, and unambiguous installer selection. |
| Redirect target contains version | `360.360Ent`, `Xmind.Xmind`, `Anthropic.Claude` | Resolve without downloading, parse the final official URL, and compare architecture variants. |
| Feed points to an updater artifact | `appmakes.Typora`, `Vivaldi.Vivaldi` | Derive and verify the corresponding full-installer URL instead of submitting the update artifact. |
| Sparkle-style appcast | `AppDynamic.AirServer`, `FlorianHeidenreich.Mp3tag`, `Vivaldi.Vivaldi`, `Readdle.Spark` | `enclosure` version and URL, architecture feeds, full-installer conversion, and `RealVersion`. |
| electron-updater feed | `Adobe.WorkfrontProof`, `7pace.Timetracker`, `Unity.UnityHub` | Feed version, relative URL resolution, dedicated conversion, and multi-architecture selection. |
| GitHub latest release | `qyzhg.Prism`, `1357310795.TboxWebdav`, `7zip.7zip`, `astral-sh.uv` | Tag normalization, exact asset predicates, and architecture mapping. |
| GitHub directory contents | `JurgenRathlev.innounp` | Parse versions from filenames, sort with `[ChunkVersion]`, and pin the selected raw URL to its latest commit SHA. |
| Squirrel `RELEASES` | `Amazon.Chime`, `Amazon.AppStream` | BOM-safe response reading, delta exclusion, and `[ChunkVersion]` sorting. |
| Custom EXE wrapper with nested MSI | `ALTEC.DataPrint`, `Apple.iTunes`, `Maximus5.ConEmu`, `Siemens.JT2Go`, `Foxit.FoxitReader` | Exact 7z payload selection, architecture mapping, raw-section extraction, nested wrapper traversal, MSI/MSP projection, and aggregate MSI parsing. |
| Shared vendor provider | `#Argente` with `Argente.*`; `#JetBrains` with `JetBrains.*` | Three or more consumers of the same source, explicit `DependsOn`, a shared normalized catalog, and variant consistency checks. |
| Browser-only extraction | `BLife.CustomCursor` | Short `Use-PlaywrightPage -Stealth -Headless` lease returning a detached URL. |
| Installer-set replacement | `Xmind.Xmind` | `WinGetReplaceMode`, conditional ARM64 inclusion, and `RealVersion`. |
| Explicit installer query | `RawTherapee.RawTherapee` | Select an existing installer by a `Query` dictionary when task write fields differ. |
| Versionless URL with checksum header | `Altova.XMLSpy.Professional`, `Alibaba.Taobao`, `Alibaba.QwenWork.CN`, `Bazwise.FolderSizeExplorer` | Last-resort detection using `x-amz-meta-sha256`, `Content-MD5`, `x-oss-hash-crc64ecma`, or `x-goog-hash`. |
| Versionless URL with ETag | `ABC.PowerExtension`, `Cjwdev.ADAccountResetTool`, `Amazon.EC2Launch` | Last-resort ETag history, SHA256 confirmation, cached installer reuse, and optional release notes. |
| Versionless URL with Last-Modified | `AnyDesk.AnyDesk`, `BitSum.ProcessLasso.Beta` | Last-resort date comparison, regressed-date warning, and per-architecture validators. |
| Versionless URL with Content-Length | `Ardisk.Ardisk` | Weakest last-resort prefilter followed by a content download and SHA256 comparison. |

Always open the named task directly and read its current `Config.yaml` and `Script.ps1`. Do not recursively copy a family of scripts merely because this table names one member.

## Release metadata patterns
| Pattern | Primary examples | What to reuse |
| --- | --- | --- |
| Metadata and installer evidence from separate sources | `ADInstruments.LabChart.DeviceEnabler.BloodFlowMeter` | Release date first, uncaught MSI download and `RealVersion`, then a separately guarded release-notes page. |
| Stable changelog fallback | `Anthropic.ClaudeCode` | Assign the general changelog URL first, parse the raw changelog when the GitHub release body is unsuitable, and replace the URL with a version anchor when found. |
| HTML release-note nodes | `1MHz.Knotes`, `HP.HPCMSL`, `Amazon.AppStream`, `RawTherapee.RawTherapee` | Nested node selection, version boundaries, XPath selection, `Get-TextContent`, and `Format-Text`. |
| Markdown converted to PowerHTML | `9001.copyparty`, `7zip.7zip`, `Anthropic.ClaudeCode` | Markdig extensions, title-node selection, bounded sibling ranges, and direct following-sibling XPath. |
| GitHub release body | `qyzhg.Prism`, `1357310795.TboxWebdav`, `7zip.7zip` | Publication time, hard-line-break Markdown conversion, release URL, and removal of download-only text. |
| Sparkle metadata | `#Clockify.Clockify`, `#TablePlus.TablePlus`, `Amazon.WorkspacesClient`, `FlorianHeidenreich.Mp3tag` | `pubDate`, `releaseNotesLink`, description content, and publisher-specific date parsing. |
| Line-oriented release notes | `Cjwdev.ADAccountResetTool`, `FlorianHeidenreich.Mp3tag`, `Bazwise.FolderSizeExplorer` | `StreamReader` for known streams, `StringReader` for decoded text, version boundaries, and deterministic disposal. |

Open the named task directly. Reuse the source and parsing shape, but retain the failure boundary and field-clearing rules in this workflow when the older task does not yet follow them.
