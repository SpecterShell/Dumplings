# Setup Factory setup runtime

## Prerequisites and payload placement

Modern media can serialize `CDependencyFile` records before `CSetupFileData`. The record stores a source path twice, expanded and packed 64-bit sizes, a flag, and a build label. Its physical payload precedes the installed application payloads. The parser requires both paths to agree and every size to remain inside the installer before returning a `DependencyPayloads` entry.

```text
CDependencyFile record
+0x00       4  observed fields
next        *  SourcePath, one-byte string
next        8  ExpandedSize, int64
next        8  PackedSize, int64
next        *  repeated SourcePath, one-byte string
next        2  observed flag
next        *  build label, one-byte string
```

Normal media stores each installed-file stream sequentially in record order. The parser assigns offsets until a record no longer fits. If every record fits, `CanExtract` is true. If only a bounded prefix fits, `CanExtractPartial` is true and `SetupFactory.Payload.Truncated` identifies an incomplete or corrupt artifact; prefix records remain forensic evidence rather than a supported installer route. The first unavailable record terminates offset assignment, and later small records are never packed into leftover bytes speculatively.

Complete Bicom 9.5.3 media verifies the prerequisite framing followed by 750 Communicator or 766 gloCOM application payloads. Earlier short fixture copies ended at valid LZMA prefixes and initially resembled intentionally partial media; comparing the cached length with the server `Content-Length` established that those files were interrupted downloads. Do not infer web, optional, or component payload behavior from a structurally valid prefix when the declared streams exceed the file boundary.

## Silent-installation capability and project record

Setup Factory’s unattended behavior has a release boundary. The version 6 builder’s “What’s New in 6.0?” page lists silent installations as a new feature and its command-line reference defines `/S`; the version 5 help has no silent mode, `%SilentMode%`, or silent command-line option. The version 3.1, 4, and 5 routes therefore resolve as interactive-only, while version 6 resolves as supporting `/S` independently of its project default. The version 6 “Run setup in silent mode” setting controls whether the installer starts silently without `/S`; it is not an enable/disable gate for the switch. Startup actions can still assign `%SilentMode%`, including forcing it back to `FALSE`, so action-dependent behavior remains VM evidence when the parsed action flow is not conclusive.

Setup Factory 7 through 10 serialize project-wide unattended-installation settings in `CProjectData`. `EnableSilentMode` is the authoritative artifact-specific gate for the documented `/S` switch; finding `/S` in the runtime proves only that the engine implements the option. The parser first locates the schema and `CreateLog` prefix, then validates the complete `CProjectData` fixed fields, the embedded `CMainWindowSettings` prefix, and the following `CHeadingFont` schema before accepting the Boolean. This structural suffix prevents arbitrary schema-like bytes in Lua or payload data from becoming switch evidence.

```text
CProjectData serialized prefix (irsetup.dat-relative)
+0x00       4  Schema = 1, uint32 LE
+0x04       1  CreateLog, Boolean
next        *  LogFilename, MFC variable-length string
next        1  WriteMode
next        1  ActionDetailLevel
next        1  EnableSilentMode, Boolean; authoritative /S gate
next        1  StartInSilentMode, Boolean
next        1  VerifyArchive, Boolean
next        1  UserProfile, Boolean
next        *  Embedded CMainWindowSettings

CMainWindowSettings validation prefix
+0x00       4  Schema = 1, uint32 LE
+0x04       1  ShowBackground, Boolean
+0x05       4  WindowStyle, uint32 LE
+0x09       4  WindowAppearance, uint32 LE
+0x0D       4  SolidBackColor, uint32 LE
+0x11       4  GradientBackColor, uint32 LE
+0x15       4  GradientForeColor, uint32 LE
next        *  ImageFile, MFC variable-length string
next        1  UseCustomIcon, Boolean
next        *  CustomIcon, MFC variable-length string
next        1  HideTaskbarIcon, Boolean
next        1  AlwaysOnTop, Boolean
next        *  Headline, MFC variable-length string
next        4  CHeadingFont schema = 1, uint32 LE
```

`SupportsSilentInstallation` is tri-state only for malformed or unsupported evidence. Version 3.1, 4, and 5 media return false with `SetupFactory.Installability.SilentUnsupportedByGeneration`; version 6 returns true and `/S`; a validated version 7-10 record returns its compiled `EnableSilentMode` value. Multiple validated modern records resolve by consensus when both silent flags agree. Missing records or conflicting flags return null with `SetupFactory.Installability.SilentSupportUnresolved`; the parser never chooses an arbitrary first or last record.

| Generation | Silent behavior | Parser result |
| --- | --- | --- |
| Setup Factory 3.1 | Predates the silent-installation facility; the 16-bit runtime has no `/S` route | false; interactive-only |
| Setup Factory 4 | Predates the silent-installation facility | false; interactive-only |
| Setup Factory 5 | Predates the silent-installation facility | false; interactive-only |
| Setup Factory 6 | Runtime implements `/S`; startup actions may change `%SilentMode%` | true; `interactive`, `silent` |
| Setup Factory 7-10 | `/S` is gated by compiled `EnableSilentMode` | exact compiled true/false value |

| Fixture | Structural route | `EnableSilentMode` |
| --- | --- | --- |
| Controlled Setup Factory 7 disabled project | `irdat-v7` | false |
| Controlled Setup Factory 7 enabled project | `irdat-v7` | true |
| ReNamer 1.80 | `irdat-v7` | false |
| OutCALL 2.0 | `irdat-v8-plus` | true |
| Setup Factory 8.1 builder media | `irdat-v8-plus` | false |
| Setup Factory 9.0 through 9.5 builder media | `irdat-v8-plus` | true |
| Setup Factory 10.2 builder media | `irdat-v8-plus` | true |
