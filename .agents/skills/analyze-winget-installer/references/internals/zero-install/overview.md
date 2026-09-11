# Zero Install internals

This reference describes the Zero Install bootstrapper structures and runtime behavior used by the parser. Use the [Zero Install workflow](../../families/zero-install/workflow.md) for package analysis and manifest authoring. Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the implementation.

## Components and trust boundaries

The Windows distribution has three distinct evidence sources. The bootstrapper PE contains deployment and launch policy. The application feed contains target metadata and implementation choices. Desktop integration in `0install-dotnet` defines the registry entries written after deployment. None of these sources alone describes the complete installed package.

```text
application bootstrapper PE
+-- bootstrap configuration -> target feed URI and launch/integration policy
+-- optional embedded content -> initial feeds, archives, icons, keys, or helper EXEs
`-- bootstrap runtime -> downloads/deploys Zero Install and invokes target operations
    +-- application feed -> name, publisher, versions, architectures, recipes, capabilities
    +-- solver -> chooses implementations from feed plus local policy and requirements
    `-- desktop integration -> shortcuts, associations, stubs, and ARP registration
```

The parser reads the PE and caller-supplied feed text. It does not load managed code, fetch a feed, run the solver, or execute an installer.

## Managed PE resource structure

The bootstrapper is a managed PE. `IMAGE_COR20_HEADER.ResourcesDirectory` identifies the contiguous CLR managed-resource blob. Each embedded `ManifestResource` row has `Implementation=0` and an offset relative to that directory.

```text
PE image
+-- DOS header and PE signature
+-- COFF and optional headers
+-- section table
+-- IMAGE_COR20_HEADER
|   `-- ResourcesDirectory: RVA + byte size
+-- CLR metadata root
|   +-- #Strings heap
|   `-- ManifestResource table
|       +-- Offset:u32 LE, relative to ResourcesDirectory
|       +-- Attributes:u32 LE
|       +-- Name:string-heap index
|       `-- Implementation:coded index, zero for embedded data
`-- CLR resource directory
    +-- record at ManifestResource.Offset
    |   +-- DataLength:u32 LE
    |   `-- Data[DataLength]
    `-- next aligned resource record
```

The parser validates the PE layout, CLR directory, metadata row count, relative record offset, four-byte length prefix, selected resource size, and final file range. It restores caller-owned stream positions and never loads the assembly into the process.

## Configuration format catalog

`ZeroInstallFormatCatalog.psd1` is the dispatch table. Resource structure determines the profile; PE file version is secondary evidence and selects between layouts that share a resource name and line count. A profile/version disagreement produces a diagnostic but does not override valid structural parsing.

### Legacy CLR-identity profile

Zero Install 2.11.0 through 2.11.5 contains `ZeroInstall.Bootstrap.BootstrapProcess` but predates customizable `EmbeddedConfig.txt`. The parser recognizes this exact CLR metadata type plus its bounded release interval as `LegacyGenericBootstrapper`. It reports the deployment runtime and its switches without inventing an application feed, target ARP identity, or extractable configuration. GitHub release archives for these versions contain installed runtime files rather than bound bootstrapper media. Regression coverage includes the authentic Bootstrap project output compiled from the tagged 2.11.5 source with the historical .NET 2.0 target references; this proves the real CLR identity and release route but is recorded as source-built evidence, not as an official shipped single-file installer.

### Fixed-line resources

Releases 2.11.6 through 2.24.7 use `ZeroInstall.EmbeddedConfig.txt`. The bootstrapper builder replaces padded marker lines in place, so each substituted UTF-8 value must fit the original line's byte width. CRLF terminates the fields in official release media.

```text
ZeroInstall.EmbeddedConfig.txt
+-- field 0: padded UTF-8 text + CRLF
+-- field 1: padded UTF-8 text + CRLF
+-- ...
`-- field N: padded UTF-8 text + CRLF
```

The known line orders are:

- `EmbeddedConfig3Mode`, 2.11.6 through 2.20.x: `app_uri`, `app_name`, `app_mode`.
- `EmbeddedConfig5Mode`, 2.21.x: `app_uri`, `app_name`, `app_mode`, `app_args`, `app_fingerprint`.
- `EmbeddedConfig5Integrate`, 2.22.x: `app_uri`, `app_name`, `app_fingerprint`, `app_args`, `integrate_args`.
- `EmbeddedConfig6AppFingerprint`, 2.23.0 only: `self_update_uri`, `app_uri`, `app_name`, `app_fingerprint`, `app_args`, `integrate_args`.
- `EmbeddedConfig6KeyFingerprint`, 2.23.1 through 2.24.0: `self_update_uri`, `key_fingerprint`, `app_uri`, `app_name`, `app_args`, `integrate_args`.
- `EmbeddedConfig7`, 2.24.1 through 2.24.7: the previous layout plus `customizable_store_path`; the upstream placeholder was named `CustomizablePath`.

An untouched generic launcher retains padded markers such as `---AppUri---`; these markers mean the field is unset. The parser removes trailing field padding and treats untouched markers as null.

### INI resources

Release 2.24.8 moved configuration to an INI document named `ZeroInstall.config.ini`. Release 2.25.3 renamed it to `ZeroInstall.BootstrapConfig.ini`. The document contains `[bootstrap]` target policy and `[global]` Zero Install deployment settings.

```ini
[bootstrap]
key_fingerprint=
app_uri=
app_name=
app_args=
integrate_args=
catalog_uri=
customizable_store_path=false
estimated_required_space=

[global]
self_update_uri=https://apps.0install.net/0install/0install-win.xml
```

`estimated_required_space` appears from 2.25.4 and is measured in bytes. The option is display evidence for the store-path UI rather than an ARP `EstimatedSize` value.

### External configuration precedence

Fixed-line launchers from 2.11.8 read `<executable>.config` and overlay `appSettings`; 2.11.6 and 2.11.7 ignore this source. The oldest `EmbeddedConfig3Mode` implementation that supports `appSettings` accepts empty overrides, while later fixed-line paths ignore empty values. INI generations replace the embedded document with an adjacent same-basename `.ini` when present. This is a replacement, not a recursive merge.

```text
2.11.6-2.11.7: embedded fixed lines only
2.11.8-2.24.7: embedded fixed lines -> overlay qualifying appSettings from EXE.config
2.24.8-current: embedded INI -> replace with adjacent EXE-basename.ini when present
```

This precedence matters for ZIP packages because an extracted EXE can appear generic until its shipped sidecar is placed beside it.

## Runtime behavior boundaries

Configuration profiles describe storage; feature gates describe behavior. The parser keeps these concerns separate because several releases share one physical layout.

- 2.11.0 introduces the generic deployment bootstrapper with `--silent` and `--verysilent`; these switches deploy Zero Install itself.
- 2.11.6 adds customizable fixed-line configuration, `--content-dir`, and application-bound launch/integration modes.
- 2.11.8 adds adjacent executable `appSettings` overrides.
- 2.14.5 removes the legacy generic deployment `--silent` and `--verysilent` aliases.
- 2.21.0 adds application uninstall registration during desktop integration.
- 2.23.0 adds `--silent`. GUI media retain progress UI; console media are fully silent.
- 2.23.1 adds `--machine` and `--no-integrate`.
- 2.23.3 removes the ` (Zero Install)` suffix from ARP `DisplayName`.
- 2.23.9 adds `--prepare-offline`.
- 2.24.0 adds ARP `Publisher`, `--refresh`, GUI `--background`, and GUI `--verysilent`.
- 2.24.6 adds embedded content and separates target `--version` from the Zero Install runtime version option.
- 2.24.7 adds `--wait`.
- 2.24.8 adds INI configuration, `--store-path`, `--integrate-args`, and the current runtime-version option name.
- 2.25.3 renames the embedded INI resource.
- 2.25.4 adds `estimated_required_space` configuration.
- 2.25.12 adds the ARP modify command and changes `NoModify` from 1 to 0.
- 2.27.5 adds target `--feed` and Zero Install runtime `--0install-feed` override separation.

When PE file version is unavailable, a configuration profile proves a feature only if the profile's full version interval lies on one side of the introduction boundary. Features introduced inside that interval remain unresolved.

## Launch and integration modes

`app_mode` in early media can be `run`, `integrate`, or `none`. Later media infer integration from non-empty `integrate_args`. Application arguments and integration arguments are separate after the 2.22 redesign.

```text
no app_uri
`-- generic Zero Install launcher; no target identity

app_uri + run/no integration arguments
`-- deploy and run target; no target ARP registration

app_uri + integration mode/arguments
+-- deploy Zero Install
+-- resolve target feed
+-- invoke desktop integration
`-- run target unless a silent/no-run route suppresses launch
```

Machine scope is available from 2.23.1 through `--machine`. If compiled integration arguments already contain `--machine`, the bootstrapper is fixed to machine integration. Otherwise the default is user integration and the same artifact can expose a machine variant.

Desktop integration category selection follows `IntegrateApp`: remove categories are applied first and add categories second, independent of command-line ordering. `--add-all` selects capability registration plus menu, desktop, send-to, alias, auto-start, and default-access-point categories; `--add-standard` selects capability registration plus menu, send-to, and alias; aliases such as `capabilities`, `defaults`, `alias`, `menu`, and `desktop` normalize to their canonical category names. Capability registration processes every compatible capability, including `explicit-only` entries. Default access points process only non-`explicit-only` capabilities. When no add/remove category is supplied, the runtime opens its integration UI, so static parsing can list available capabilities but cannot claim the final associations.

## Feed structure

The feed parser accepts only an `<interface>` root in `http://zero-install.sourceforge.net/2004/injector/interface`; `<feed>` is a child reference to an additional feed, not a document root. DTD processing and external XML resolution are prohibited. The parser reads localized interface and entry-point metadata, ordinary `<implementation>` records, distribution-backed `<package-implementation>` records, inherited group state, bindings, ordered retrieval recipes, dependency constraints, command arguments and runners, feed references, replacement metadata, manifest digests, and desktop-integration capabilities.

```text
interface xmlns=feed-namespace
+-- required name; optional summary, publisher, homepage
+-- feed src/arch/langs; feed-for; replaced-by
+-- group [nested]
|   +-- nearest-value attributes: arch, version, stability, rollout-percentage, license, main, self-test, doc-dir
|   +-- inherited collections: requires, restricts, binding, command
|   +-- implementation: id + manifest-digest + effective version + retrieval methods
|   +-- command: path + arg/for-each + working-dir + runner
|   `-- package-implementation: package + distributions + version range
+-- entry-point: command + binary-name + localized name/summary/description
+-- archive: href, size, type, extract, dest, start-offset
+-- file: href, size, dest, executable
+-- recipe
|   +-- archive or file download steps
|   +-- rename source -> dest
|   +-- remove path
|   `-- copy-from implementation id/source -> dest
`-- capabilities xmlns=capability-namespace [os=*|Windows|...]
    +-- url-protocol id [known-prefix value ...]
    `-- file-type id -> extension value/mime-type/perceived-type
```

Scalar attributes use nearest-value inheritance. Collection members accumulate child-first in the same order as `Element.InheritFrom`: direct implementation records, nearest group records, then outer group records. The declaring level remains attached to requirements, restrictions, and commands so callers can distinguish local declarations from inherited policy.

URI-valued attributes resolve through `xml:base` from the document root toward the owning element and then through the caller-supplied feed URI. A relative reference remains unresolved when no absolute base exists. Sizes, offsets, and rollout percentages are parsed as bounded non-negative integers. Unknown recipe elements are retained in `UnknownSteps`, set `ContainsUnknownSteps`, and produce `ZeroInstall.Feed.RecipeStepsUnsupported`; this prevents a partial recipe projection from being treated as complete extraction instructions.

The parser retains implementations and retrieval methods in document order. `StableImplementations` is a convenience filter, not solver output. When the bootstrapper runtime version is known, `AppliesToRuntime` evaluates the element and all containing group conditions, and `ApplicableImplementations`, `ApplicableEntryPoints`, `ApplicableFeedReferences`, `ApplicableRequirements`, `ApplicableRestrictions`, and nested `Applicable*` collections reproduce the records retained by Zero Install's normalization pass. The range grammar supports exact versions (`2.29`), exclusions (`!2.29`), inclusive lower and exclusive upper bounds (`2.20..!3`), open bounds, and `|` unions. If no runtime version is supplied, conditional records remain in the applicable collections with `AppliesToRuntime = $null`.

Runtime filtering is only one solver input. Architecture, dependency availability, rollout, local preferences, distribution package managers, trust, and stability policy can still change the implementation selected at runtime.

Windows association projection follows both the capability model and compiled integration selection. A URL-protocol capability without known prefixes uses its `id` as the custom protocol; when `<known-prefix>` children exist, those prefix values are the protocols selected by the corresponding access point. File extensions are normalized without a leading dot for WinGet evidence. `Protocols` and `FileExtensions` contain only deterministically selected associations; `AvailableProtocols` and `AvailableFileExtensions` retain the full compatible feed capability set. Capability identifiers and extension/prefix values use the upstream safe-ID grammar before they can become registry evidence.

## ARP registration

Application desktop integration registers under `HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall` by default and under HKLM for machine-wide integration. The key name is the canonical feed URI transformed by `FeedUri.PrettyEscape`.

```text
for each UTF-16 code unit c in canonical absolute URI
+-- ASCII letter or digit -> append c
+-- '/' -> append '#'
`-- otherwise -> append '%' + lowercase hexadecimal integer value of c
```

The transformation works on UTF-16 code units, so a non-BMP character is encoded as two percent-hex surrogate values. It is not URL encoding.

For current integration, the ARP values derive from the feed and deployed runtime:

```text
Key                  = PrettyEscape(feed URI)
DisplayName          = feed name
Publisher            = feed publisher, from runtime 2.24.0
URLInfoAbout         = feed homepage
DisplayVersion       = deleted/absent for application integration
UninstallString      = <runtime InstallBase>\0install-win.exe remove <feed URI> [--machine]
QuietUninstallString = UninstallString + --batch --background
ModifyPath           = <runtime InstallBase>\0install-win.exe integrate <feed URI> [--machine], from 2.25.12
NoModify              = 1 before 2.25.12, otherwise 0
NoRepair              = 1
```

Runtime `InstallBase` depends on the deployed Zero Install instance and can be affected by store selection. The parser returns the executable name and argument arrays but does not fabricate the path or fully quoted command string.

## Embedded content and extraction

`ZeroInstall.SplashScreen.png` supplies GUI branding. `ZeroInstall.content.*` maps to files imported before network resolution. The runtime also examines an explicit `--content-dir` or the deployed runtime's default `InstallBase\content` directory. Both embedded and directory-backed sources use the same case-insensitive filename dispatch, and the directory path is intentionally non-recursive.

```text
ManifestResource name                  extraction path
ZeroInstall.EmbeddedConfig.txt       -> EmbeddedConfig.txt
ZeroInstall.config.ini               -> config.ini
ZeroInstall.BootstrapConfig.ini      -> BootstrapConfig.ini
ZeroInstall.SplashScreen.png         -> SplashScreen.png
ZeroInstall.content.<relative-name>  -> content/<relative-name>
```

```text
content filename                          runtime action
*.xml                                  -> import signed feed
*.png or *.ico                         -> import icon
<stub-directory>_<stub-file>.exe       -> deploy read-only desktop-integration stub
<recognized manifest digest>.<archive> -> extract into implementation store
<key-id>.gpg                           -> supply OpenPGP key while importing a feed
other names                            -> ignore
```

Recognized manifest-digest basenames include the `sha1=`, `sha1new=`, `sha256=`, and `sha256new_` forms accepted by the current store model. The content catalog records the import action, digest, stub target, source, bounded PE range or file path, and byte size. It does not claim that ignored files or detached keys are application payloads.

Default extraction copies bounded managed-resource ranges and explicit content files under `content/`. `-ExpandImplementationArchives` is opt-in and places each recognized archive under `_implementations/<manifest-digest>/`, keeping alternatives isolated. This route is a raw archive inspection path: it applies shared safe-path, collision, entry-count, decompression, and cumulative-output limits but does not preserve the complete Zero Install manifest metadata, execute a recipe, or claim solver selection.

The manifest digest is not an archive checksum. Zero Install generates a normalized file manifest during extraction and hashes records that include relative paths, content hashes, timestamps, executable state, and symlink metadata. Raw content-archive expansion cannot reproduce this evidence, so it emits `ZeroInstall.Content.ManifestDigestNotVerified` rather than hashing compressed bytes.

`Expand-ZeroInstallImplementation` is the metadata-aware offline path. The caller identifies one exact implementation and supplies local files for every selected retrieval URI plus local implementation roots for any `copy-from` IDs. Applicable archive, file, rename, remove, and copy-from records execute in document order in a temporary staging tree. The function does not fetch, trust, or solve anything.

```text
caller-selected implementation + retrieval method
+-- archive -> bounded local range after start-offset -> extract subtree -> destination prefix
+-- file -> bounded local file -> destination + executable flag + timestamp 0
+-- rename -> move file or directory and its executable metadata
+-- remove -> remove file or directory and its executable metadata
`-- copy-from -> read caller-supplied implementation tree and optional .manifest executable evidence
    |
    `-- staged implementation
        +-- sort directories with '/' before other characters
        +-- sort file names ordinally
        +-- omit AppleDouble sidecar when its sibling exists
        +-- emit D, F, or X records with content digest, Unix time, size, and name
        +-- hash UTF-8 manifest text as sha1new, sha256, or sha256new
        `-- compare exact digest before publishing selected files
```

The Apache-2.0 `ZeroInstallManifest.cs` helper performs the recursive walk, streaming content hashing, ordering, record generation, and final digest. It rejects reparse points, reserved implementation files, invalid paths, unsupported algorithms, stale executable metadata, excessive entries, and excessive bytes. SHA-1 or SHA-256 file digests and `sha1new=`/`sha256=` manifest digests use lowercase hexadecimal. `sha256new_` uses unpadded RFC 4648 base32. The legacy `sha1=` format remains unsupported, matching the current runtime.

ZIP extraction uses `System.IO.Compression.ZipArchive` for Unix mode bits and a bounded SharpCompress metadata pass for the old Info-ZIP Unix timestamp extra field. Other supported archives use SharpCompress's sequential reader, which also unwraps compressed TAR layers without materializing the complete archive. Archive links are rejected before output because a Windows-safe file result cannot represent symlink and hardlink semantics faithfully. Unknown recipe elements make the complete recipe unusable rather than being skipped.

## Detection and malformed input

Strong detection requires a valid managed PE and a source-backed Zero Install CLR bootstrapper type. Current media must contain exactly one supported configuration resource; legacy 2.11.0–2.11.5 media instead match the exact no-resource managed-identity profile. Multiple supported configuration resources are ambiguous and rejected. Invalid UTF-8, unsupported line counts, missing INI bootstrap sections, malformed resource lengths, out-of-range CLR records, oversized XML, DTDs, and invalid absolute `app_uri` values fail deterministically.

`Test-ZeroInstallInstaller` reads only PE, CLR identity, and embedded configuration structure. It intentionally ignores adjacent INI or `.config` overrides, feed content, and content directories so malformed package metadata cannot change family classification. `Get-ZeroInstallInfo` performs the full configuration-precedence and metadata analysis.

The analyzer may use resource-name strings as weak hints, but only structured CLR resource enumeration produces a high-confidence family candidate.

## Performance

`Get-ZeroInstallInfo` opens the PE once, parses one PE layout, enumerates selected CLR resources, and reads only the bounded configuration record. Feed XML is parsed once from caller-supplied text. Content-directory enumeration is top-level and bounded. Extraction streams selected resource ranges or files without materializing the complete executable; implementation archives are opened only when expansion is explicitly requested. The parser does not download target archives or invoke the Zero Install solver.

## Known gaps

- Official shipped or application-bound pre-2.11.6 bootstrapper media has not been located; the route is covered by the authentic 2.11.5 Bootstrap project output built from tagged source and a synthetic malformed-input fixture.
- Runtime `InstallBase`, generated icon paths, shortcuts, and final association registry values depend on deployment state and are not reconstructed as absolute paths.
- The parser projects implementations, package-manager records, dependencies, commands, and retrieval recipes. It can materialize one caller-selected ordinary implementation offline, but it does not implement the Zero Install solver.
- Distribution package resolution, dynamic native-feed imports, trust decisions, implementation selection, and rollout policy require runtime evidence.
- Raw bootstrap-content archive extraction does not reproduce or verify the runtime-generated manifest digest; use the explicit offline implementation API when the feed and retrieval artifacts are available.
- Offline recipe extraction rejects archive links and archive types not supported by the built-in and pinned managed readers. These cases need a link-aware or format-specific provider rather than lossy emulation.
- Target applications can add or change ARP fields and associations after launch; `DisplayVersion` is a known example.

## Implementation mapping

- `Modules/PackageModule/Libraries/Installers/ZeroInstall.psm1`: structured resource parsing, feed conversion, metadata composition, ARP projection, extraction, and public APIs.
- `Modules/PackageModule/Libraries/Installers/ZeroInstallFormatCatalog.psd1`: configuration profiles and source-backed feature introduction versions.
- `Modules/PackageModule/Assets/Source/ZeroInstall/ZeroInstallManifest.cs`: bounded implementation manifest generation and digest verification.
- `Modules/PackageModule/Libraries/Infrastructure/PE.psm1`: bounded CLR `ManifestResource` enumeration and resource copying.

## Representative fixtures

The focused suite uses official generic release EXEs for 2.16.0, 2.21.0, 2.22.0, 2.23.0, 2.23.1, 2.23.3, 2.24.0, 2.24.6, 2.24.8, 2.25.12, and 2.29.0, the current `DeepL.DeepL` bootstrapper, and the authentic 2.11.5 Bootstrap project output compiled from its tagged source. Synthetic feed tests cover namespace rejection, inheritance, `xml:base`, localized metadata, entry points, package implementations, manifest digests, requirements, restrictions, bindings, command arguments and runners, ordered recipes, unknown steps, default versus explicit-only capabilities, malformed bounded fields, explicit content directories, opt-in raw content-archive expansion, offline recipe execution, and verification-before-publish behavior. Historical tests reproduce the upstream builder's bounded in-place configuration substitution only in Pester's temporary directory; no fixture is executed.

## Source references

- [0install/0install-win](https://github.com/0install/0install-win): bootstrap configuration resources, builder substitution, sidecar precedence, command-line handling, embedded content, and release history.
- [0install/0install-dotnet](https://github.com/0install/0install-dotnet): feed parsing, solver inputs, deployment behavior, `FeedUri.PrettyEscape`, desktop integration, and `UninstallEntry` registry writes.
- [nano-byte/common](https://github.com/nano-byte/common): `WindowsUtils.SplitArgs` and its `CommandLineToArgvW` argument-tokenization behavior.
- [Zero Install feed specification](https://docs.0install.net/specifications/feed/)
- [Zero Install on Windows](https://docs.0install.net/details/windows/)
