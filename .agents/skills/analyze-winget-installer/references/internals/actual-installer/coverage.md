# Actual Installer coverage

## Supported capabilities

| Capability | Cabinet3 | Cabinet4 | Cabinet5 | Zip6Plus | ZipExternalData |
| --- | --- | --- | --- | --- | --- |
| Structural detection | Yes | Yes | Yes | Yes | Yes when metadata-only media declares `DataFileName` |
| Metadata extraction | Yes | Yes | Yes | Yes | Yes |
| Installed payload catalog | Yes | Yes | Yes | Yes | Yes when `Get-ActualInstallerInfo -CompanionFile` is used |
| Installed payload extraction | Yes | Yes | Yes | Yes | Yes with explicit `CompanionFile` |
| Raw container export | Yes | Yes | Yes | Yes | Executable metadata container only |
| Metadata/helper entry export | Yes | Yes | Yes | Yes | Yes |
| Literal package identity | Yes | Yes | Yes | Yes | Yes |
| ProductCode | Unresolved | Literal `AppName`, VM validated | Product GUID | Product GUID when configured | Product GUID when configured |
| Scope | Legacy administrator/PE evidence | Legacy administrator/PE evidence | Supported compiled evidence | `InstallLevel` when present | `InstallLevel` when present |
| Dual-scope alternatives | Not verified | Not verified | Not verified | Yes when `InstallLevel` is 2 or 3 | Yes when `InstallLevel` is 2 or 3 |
| Default install location | Yes when deterministic | Yes when deterministic | Yes when deterministic | Yes when deterministic | Yes when deterministic |
| Literal custom registry writes and ARP groups | Parsed where grammar matches | Parsed where grammar matches | Parsed where grammar matches | Parsed where grammar matches | Parsed where grammar matches |
| Dedicated file extensions | Parsed where present | Parsed where present | Parsed where present | Parsed where present | Parsed where present |
| Protocol associations | Literal registry evidence only | Literal registry evidence only | Literal registry evidence only | Literal registry evidence only | Literal registry evidence only |
| Shortcuts and commands | Typed fields where grammar matches | Typed fields where grammar matches | Typed fields where grammar matches | Typed fields plus guarded XOR-2 decoding | Typed fields plus external archive plans |
| Setup policy and requirements | Selected fields | Selected fields | Selected fields | Silent policy, requirements, prerequisites, version bounds, and media sources | Same compiled configuration model |
| Payload PE architecture and dependencies | Selective bounded analysis | Selective bounded analysis | Selective bounded analysis | Selective bounded analysis | Selective bounded analysis when `CompanionFile` is supplied |
| Generated uninstaller reconstruction | No | No | Exact helper copy | Exact helper copy | Exact helper copy when represented by the numbered payload ZIP; otherwise route-dependent |
| Dynamic online values or downloads | Reported, never fetched | Reported, never fetched | Reported, never fetched | Decoded and reported, never fetched | Decoded and reported, never fetched |
| External Setup EXE + Data archive | N/A in verified media | N/A in verified media | N/A in verified media | Compiled filename reported | Bounded 7z/LZMA extraction supported |

"Yes" means the parser has a structural implementation and at least one stable fixture. It does not imply that every option in that generation has been decoded.

## Persistent real fixtures

The focused Pester suite resolves durable files below the external `Dumplings-TestFixtures` cache.

| Fixture | Route | Regression purpose |
| --- | --- | --- |
| Archived 3.8 `aisetup.exe` capture | `Cabinet3` | metadata-first `setup.ini`, 50 mapped payloads, legacy unresolved ProductCode |
| Archived 4.8 `aisetup.exe` capture | `Cabinet4` | metadata-first `aisetup.ini`, 53 mapped payloads, VM-validated name-key ARP route |
| Archived 5.2 `aisetup.exe` capture | `Cabinet5` | metadata-last CABs, 51 mapped payloads, VM-validated modern ARP tuple |
| Archived 6.6 `aisetup.exe` capture | `Zip6Plus` | first verified decimal-indexed ZIP generation, 42 mapped payloads |
| Archived 6.7 `aisetup.exe` capture | `Zip6Plus` | `SystemType=0` architecture policy and 42 mapped payloads |
| Archived 8.0 `aisetup.exe` capture | `Zip6Plus` | machine-only scope and `.aip` extension evidence |
| Archived 8.2 and 8.4 `aisetup.exe` captures | `Zip6Plus` | guarded XOR-2 command decoding |
| Archived 8.3 `aisetup.exe` capture | `Zip6Plus` | plain command fields on the same physical route |
| Truncated archived 8.2 capture | rejected | valid outer PE with physically incomplete metadata ZIP must not route |
| Fixed 9.6 `aisetup9.6.exe` capture | `Zip6Plus` | literal builder/application version, Product GUID, and 43 mapped payloads |
| Archived Actual Updater 4.8.1 | `Zip6Plus` | 9.2-built updater subtype, encoded commands, and 12 mapped payloads |
| Current `ActualInstallerFree10-online.exe` capture | `Zip6Plus` | 9.8 compiled configuration, dynamic `<V>`, dual-scope default-user policy |
| Actual Updater Free 5.0 | `Zip6Plus` | separate product subtype, literal version and Product GUID, no name hardcoding |
| Controlled 9.6 Setup EXE + Data output | `Zip6Plus` plus companion 7z | embedded generated-uninstaller records and external application payload extraction |
| Controlled 9.8 `SystemType` outputs | `Zip6Plus` | enum values 0, 1, and 2 mapped to 32-bit/default, 64-bit-only, and 32-bit-only layouts |
| Archived `Downloader.exe` | rejected | same-publisher executable without an Actual Installer container sequence |

The test suite also generates a minimal metadata-first cabinet fixture and a numbered-ZIP fixture for malformed-input, extraction, scope, association, collision, and dynamic-version assertions.

## Additional research corpus

Internet Archive captures are useful for filling chronology gaps, but a URL or capture count is not itself parser coverage. Each unique binary must be hashed, structurally classified, and compared before it is added to the verified matrix.

| Historical URL | Research value |
| --- | --- |
| `http://www.actualinstaller.com/aisetup.exe` | Older root-path builder media from 2006 onward |
| `http://www.actualinstaller.com/download/aisetup.exe` | Main builder chronology with many unique captures |
| `http://www.actualinstaller.com/InstallerGD-3_7_5.exe` | Possible 3.7.5 boundary artifact; captures reported as HTML require content verification |
| `http://www.actualinstaller.com:80/eimsetup.exe` | Separate product or predecessor line; MIME and structure require verification |
| `https://www.actualinstaller.com/download/ActualInstallerFree10-online.exe` | Current online wrapper and dynamic metadata |
| `https://www.actualinstaller.com/download/ActualUpdaterFree5.0.exe` | Actual Updater subtype |
| `https://www.actualinstaller.com/download/aisetup9.6.exe` | Verified fixed-version 9.6 builder media |
| `https://www.actualinstaller.com/download/ausetup.exe` | Verified Actual Updater 4.8.1 media built by 9.2 |
| `https://www.actualinstaller.com/download/Downloader.exe` | Verified negative sibling product without the setup container structure |

HTML captures at an `.exe` URL must be rejected before fixture classification. Duplicate Wayback captures should be deduplicated by cryptographic hash, not timestamp or response URL.

## VM-validated evidence

The 4.8, 5.2, 6.6, 8.0, and 9.6 builder setups have installed-state comparisons for machine scope, 32-bit registry view, display metadata, install location, icon, and uninstall command. The 4.8 runtime uses an `AppName` uninstall key and versioned display name; 5.2 and later tested media use Product GUID keys. The 3.8 setup remained in pre-initialization state on the Windows 11 validation VM under both PowerShell Direct and an interactive scheduled task: it created no window, log, files, or ARP state before the bounded timeout. That failed run is installability evidence for the tested environment, not proof of its uninstall-key derivation. Other fixture assertions are primarily static unless their focused test or research record says otherwise.

The documented exit-code table is source-backed runtime behavior. It is not a substitute for recording the concrete installer process exit code during dynamic validation, especially for online, update-only, prerequisite-bearing, or silent-prohibited projects.

## Known gaps

| Gap | Current handling | Evidence needed to close it |
| --- | --- | --- |
| Actual Installer 1.x, 2.x, and pre-3.8 media | Reject | Durable unique binaries and exact container maps |
| Exact transition between cabinet routes and early point releases | Use only verified physical route | Additional unique captures near each boundary |
| Cabinet3 uninstall-key derivation | Report visible ARP intent with unresolved ProductCode | Completed 3.x installation and VM registry result |
| Generated updater output | Preserve metadata helper evidence only | Runtime generation algorithm and output verification |
| Full `[Files]` field grammar | Decode legacy fields, compact policy indexes, and split early-ZIP indexes; preserve unknown tails | One-option builder diffs for the remaining route-specific fields |
| Conditional `[Registry]` semantics and split-token target identity | Decode all established fields, retain unresolved operations separately from projectable writes | Controlled conditional records plus token/elevation VM matrix |
| Complete `[Extensions]` grammar | Decode legacy/current layouts, executable, parameters, working directory, icon, and default-selection flag | Controlled association matrix and registry comparison for remaining fields |
| Unverified shortcut tail fields and conditions | Return typed established fields plus complete field arrays | Builder diffs and installed shortcut inspection |
| Command control flow and child side effects | Return typed command records; never execute or inherit switches | Builder diffs, runtime inspection, and child-effect boundary rules |
| Other setup tables and variables | Retain in raw `Configuration` | Stable grammar and runtime evidence |
| Metadata-only Setup EXE + Data corpus fixture | Synthetic metadata-only route is implemented; real 9.6 hybrid media is covered | Builder-produced media that embeds no generated payload records |
| Online downloads and dynamic `<V>` | Decode literal source expressions; never fetch during parser operation | Source-specific higher-level workflow or VM evidence |
| Exact uninstaller command quoting and custom arguments | Return resolved executable path only; leave quiet command null | Cross-generation installed-state comparisons |
| Numeric `SystemType` values outside 0, 1, and 2 | Leave layout and default registry view unresolved | Builder evidence for a new enum member |
| Conditional operation simulation | Evaluate bounded literal `IF` comparisons; preserve runtime operands, `IFMSG`, platform gates, and silent/update suppression as conditional evidence | Additional compound or undocumented comparison forms and VM scenario results |
| Future archive routes | Reject | New structural catalog entry backed by fixtures |

## False-positive controls

The suite rejects marker-only PE files. Future negative fixtures should include ordinary PE files with CAB resources, generic ZIP SFX files containing `aisetup.ini` text, and archives with a `[Setup]` section but no numeric `[Files]` catalog.

## Validation expectations

A format change is complete only when synthetic malformed-input coverage and a distinct real artifact agree. ARP, scope, silent behavior, and dynamic registry identity require checkpointed VM comparison when they affect package matching. Research tools may cross-check a format, but no external extractor or builder executable becomes a parser runtime dependency.

## Source references

- [Actual Installer command-line parameters and exit codes](https://www.actualinstaller.com/help/command-line.html)
- [Actual Installer variables](https://www.actualinstaller.com/help/installer-variables.html)
- [Actual Installer files and folders](https://www.actualinstaller.com/help/files-and-folders.html)
- [Actual Installer registry behavior](https://www.actualinstaller.com/help/registry.html)
- [Actual Installer update installers](https://www.actualinstaller.com/articles/how-to-create-update-installer.html)
- [Internet Archive download-path captures](https://web.archive.org/web/*/http://www.actualinstaller.com/download/aisetup.exe)
