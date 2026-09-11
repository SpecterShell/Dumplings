# Zero Install workflow

## When to use

Use `InstallerType: exe` with the family comment `# Zero Install` when a managed Zero Install bootstrapper is bound to an application feed. `DeepL.DeepL` is the principal accepted package example.

The generic `0install.exe` and `zero-install.exe` launchers belong to this binary family, but they are not package-specific installers. Do not assign target metadata, ARP identity, or application switches unless the effective bootstrap configuration contains a target feed.

## Detection

Route here when `Test-ZeroInstallInstaller` or `Get-ZeroInstallInfo` succeeds. Structural detection requires a valid managed PE, a source-backed Zero Install bootstrapper CLR type, and either exactly one supported embedded configuration resource or the legacy 2.11.0–2.11.5 generic-bootstrapper type profile. Supported resources are `ZeroInstall.EmbeddedConfig.txt`, `ZeroInstall.config.ini`, and `ZeroInstall.BootstrapConfig.ini`. Product strings and command-line markers are hints only.

The three resource names cover eight source-backed layouts from Zero Install 2.11.6 onward; the no-resource legacy profile covers the generic deployment bootstrapper introduced in 2.11.0. Read [Zero Install parser internals](../../internals/zero-install/overview.md) before changing the generation catalog, feature boundaries, resource parsing, or ARP projection.

## Static analysis

### 1. Analyze the file once

```powershell
. .\Modules\PackageModule\Index.ps1
$Analysis = Get-WinGetInstallerAnalysis -Path $InstallerPath
$Info = Get-ZeroInstallInfo -Path $InstallerPath
$Info | Select-Object FormatGeneration, RuntimeVersion, ConfigurationResourceName, ConfigurationSource, AppUri, AppName, ProductCode, Scope, SupportedScopes, InstallModes, InstallerSwitches, WritesAppsAndFeaturesEntry
```

Reuse `$Info`; do not call the individual `Read-*FromZeroInstall` functions after `Get-ZeroInstallInfo` has parsed the same file. `FormatGeneration` identifies the physical configuration layout. Runtime features are gated separately by `RuntimeVersion` because several layouts span behavior changes.

### 2. Preserve the runtime configuration precedence

For fixed-line generations, an adjacent `<installer>.exe.config` contributes historical `appSettings` overrides. For INI generations, an adjacent same-basename `.ini` replaces the embedded INI. Analyze a ZIP distribution only after placing the EXE beside the shipped sidecar. Do not retain an unrelated sidecar beside a direct EXE download.

Check `ConfigurationSource`, `EmbeddedBootstrapConfig`, and `BootstrapConfig`. A sidecar can change the target feed, application mode, integration arguments, or store-path behavior.

### 3. Distinguish running from integration

`AppUri` identifies a feed, but it does not prove an uninstall entry. `IntegrationConfigured` must also be true, and the runtime must support ARP registration.

- Releases before 2.21 can download, run, or integrate a feed but do not create the modern application uninstall entry.
- Releases 2.21 and later register an application only when `app_mode=integrate` or `integrate_args` requests integration.
- A run-only bootstrapper has `UninstallKeyNameCandidate` evidence but no `ProductCode`, `Scope`, or `AppsAndFeaturesEntries` evidence.
- `IntegrationSelection` interprets the category switches exactly. `--add-all` and `--add=capabilities` select every compatible feed capability, while `--add=defaults` selects only non-`explicit-only` default access points.
- Integration with no add/remove category opens the runtime integration UI. In that case `Protocols` and `FileExtensions` remain unresolved even though `AvailableProtocols` and `AvailableFileExtensions` report what the feed can expose.

### 4. Retrieve the feed in the caller

The parser never fetches a feed. Retrieve `AppUri` in the task so headers, cookies, proxy, retries, and source-specific fallback behavior remain under caller control, then pass the raw XML.

```powershell
$FeedResponse = Invoke-WebRequest -Uri $Info.AppUri
$Info = Get-ZeroInstallInfo -Path $InstallerPath -FeedContent $FeedResponse.Content
$Info.FeedInfo | Select-Object Name, Names, Publisher, Homepage, MinimumInjectorVersion, RuntimeVersion, Architectures, ApplicableArchitectures, Protocols, FileExtensions, DefaultProtocols, DefaultFileExtensions, EntryPoints, ApplicableEntryPoints, FeedReferences, ApplicableFeedReferences, Requirements, ApplicableRequirements, Restrictions, ApplicableRestrictions
$Info.FeedInfo.Implementations | Select-Object Kind, Id, ManifestDigest, Package, Version, Released, Stability, RolloutPercentage, License, Architecture, IfZeroInstallVersion, AppliesToRuntime, Bindings, Commands, RetrievalMethods
$Info.FeedInfo.ApplicableImplementations | Select-Object Kind, Id, Version, Architecture, Commands, RetrievalMethods
```

The feed must be a namespaced `<interface>` document. The parser applies nearest-value group inheritance, accumulates requirements, restrictions, bindings, and commands from the implementation outward through its ancestor groups, resolves relative references through inherited `xml:base`, and preserves retrieval recipes in execution order. It also projects localized metadata, entry points, command arguments and runners, and legacy or explicit manifest digests. Unknown recipe steps produce a structured extraction diagnostic instead of being discarded.

`Get-ZeroInstallInfo` passes the bootstrapper's `RuntimeVersion` into feed conversion. Every projected element retains its raw `if-0install-version` expression and receives `AppliesToRuntime`; the corresponding `Applicable*` collections exclude records rejected by the same exact, exclusion, inclusive-lower/exclusive-upper, and union range grammar used by Zero Install. A direct `ConvertFrom-ZeroInstallFeed` call without `-RuntimeVersion` keeps conditional records as potentially applicable and leaves their applicability unresolved. These collections reproduce version filtering only. They do not select an implementation because the Zero Install solver also considers platform, requirements, stability policy, rollout percentage, and local preferences.

For URL-protocol capabilities, a custom protocol uses the capability `id`; a capability with `<known-prefix>` children registers those prefixes instead. File extensions come from Windows-compatible capability lists only. `FeedInfo.Protocols` and `FeedInfo.FileExtensions` are available capabilities, not proof that the bootstrapper selects them. Use the top-level `Protocols` and `FileExtensions` only after deterministic `IntegrationSelection`, and still capture installed-state changes after first launch when the target application can modify associations itself.

### 5. Use generation-specific modes and switches

Use the exact `InstallModes`, `InstallerSwitches`, `SupportedScopes`, and `ScopeSwitches` returned by `Get-ZeroInstallInfo`.

- Before 2.23.0, configured application bootstrappers have no source-backed silent mode.
- The generic 2.11.0–2.14.4 deployment bootstrapper supports `--silent` and `--verysilent` for installing Zero Install itself. This behavior is separate from application-bound silent support and does not prove target ARP metadata.
- From 2.23.0 through 2.23.x, GUI `--silent` suppresses questions and target launch but retains progress UI, so it maps to `silentWithProgress`. CLI media maps it to `silent`.
- From 2.24.0, GUI `--verysilent` maps to `silent`, while `--silent` remains `silentWithProgress`.
- `--machine` and `--no-integrate` start at 2.23.1. An installer whose compiled integration arguments already contain `--machine` is fixed to machine scope rather than dual-scope.
- `customizable_store_path` first appears before the command-line store override. Author `InstallLocation: --store-path="<INSTALLPATH>"` only when the field is true and the runtime is 2.24.8 or later.
- A generic launcher without a bound `AppUri` remains interactive-only for package-authoring purposes.

### 6. Inspect embedded content when needed

```powershell
$Files = Expand-ZeroInstallInstaller -Path $InstallerPath -DestinationPath $Destination -CollisionAction Rename
$ConfigOnly = Expand-ZeroInstallInstaller -Path $InstallerPath -DestinationPath $OtherDestination -Name 'BootstrapConfig.ini' -CollisionAction Rename
$Info = Get-ZeroInstallInfo -Path $InstallerPath -ContentDirectoryPath $ContentDirectory
$PayloadFiles = Expand-ZeroInstallInstaller -Path $InstallerPath -DestinationPath $PayloadDestination -ContentDirectoryPath $ContentDirectory -ExpandImplementationArchives -Name '_implementations/*' -CollisionAction Rename
```

Omitting `-Name` exports every supported embedded resource. `ContentEntries` classifies embedded and explicitly supplied content as feeds, icons, OpenPGP keys, desktop-integration stubs, implementation archives, or ignored files using the same filename routing as the bootstrap runtime. An explicit content directory is enumerated non-recursively, matching upstream behavior.

Implementation archives are expanded only with `-ExpandImplementationArchives` and are isolated under `_implementations/<manifest-digest>/`. This raw-content operation exposes payload evidence; it does not apply a feed recipe, preserve all archive metadata, verify the implementation digest, satisfy dependencies, or prove that the solver will select the implementation. `ZeroInstall.Content.ManifestDigestNotVerified` and unresolved `PayloadIntegrity` therefore remain appropriate for this route.

### 7. Materialize an explicitly selected implementation offline

Use `Expand-ZeroInstallImplementation` when a feed implementation and all of its retrieval inputs have already been selected. Supply every download as a local path; the function never accesses the network. If more than one retrieval method is applicable, pass `-RetrievalMethodIndex` explicitly rather than treating document order as solver output.

```powershell
$Feed = ConvertFrom-ZeroInstallFeed -Content $FeedResponse.Content -BaseUri $Info.AppUri -RuntimeVersion $Info.RuntimeVersion
$Sources = @{
  'https://downloads.example.test/product.zip' = $DownloadedArchive
  'https://downloads.example.test/sidecar.dat' = $DownloadedSidecar
}
$SourceImplementations = @{ 'sha256new_BASE' = $ExistingImplementationDirectory }
$Result = Expand-ZeroInstallImplementation -FeedInfo $Feed -ImplementationId 'sha256new_TARGET' -RetrievalSource $Sources -SourceImplementation $SourceImplementations -DestinationPath $Destination -CollisionAction Rename
$Result | Select-Object ImplementationId, RetrievalMethodIndex, ExpectedDigest, CalculatedDigest, ManifestVerified, ExecutablePaths
```

The executor applies applicable `archive`, `file`, `rename`, `remove`, and `copy-from` records in order inside a temporary tree. Archive `start-offset`, `extract`, and `dest` values, single-file executable state, copy-from `.manifest` executable records, timestamps, output bounds, duplicate paths, and traversal are enforced. The complete implementation is hashed before selected files reach the destination. A digest mismatch leaves the destination unchanged. ZIP mode bits use `ZipArchive`; other supported archive stacks use the pinned SharpCompress reader. Archive links are rejected because safely publishing their semantics on Windows requires a link-aware output contract.

`Get-ZeroInstallImplementationManifest` computes `sha1new`, `sha256`, or `sha256new` evidence for a local implementation. `Test-ZeroInstallImplementationDigest` verifies an expected digest. Supply `-ExecutablePath` when the files came from a source that cannot preserve Unix executable bits. Do not use `-SkipManifestDigestCheck` for manifest authoring; it exists for bounded format research and still returns the computed digest.

This API is not a solver. The caller remains responsible for feed signature/trust validation, architecture and stability policy, rollout, dependency resolution, package implementations, and choosing one exact implementation and retrieval method.

## Manifest shape

Zero Install is a generic EXE type to WinGet, so its non-default modes and switches must be explicit. Do not start from a current-version template and apply it to historical media. Obtain the artifact-specific projection from `Get-WinGetInstallerAnalysis`.

A current GUI application bootstrapper with configured integration and a customizable store path can produce user and machine variants:

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # Zero Install
  Scope: user
  InstallModes:
  - interactive
  - silent
  - silentWithProgress
  InstallerSwitches:
    Silent: --verysilent
    SilentWithProgress: --silent
    InstallLocation: --store-path="<INSTALLPATH>"
  UpgradeBehavior: install
  ProductCode: https%3a##example.com#feeds#product.xml
  InstallerUrl: https://example.com/ProductSetup.exe
  InstallerSha256: <SHA256>
- Architecture: x64
  InstallerType: exe # Zero Install
  Scope: machine
  InstallModes:
  - interactive
  - silent
  - silentWithProgress
  InstallerSwitches:
    Silent: --verysilent
    SilentWithProgress: --silent
    InstallLocation: --store-path="<INSTALLPATH>"
    Custom: --machine
  UpgradeBehavior: install
  ProductCode: https%3a##example.com#feeds#product.xml
  InstallerUrl: https://example.com/ProductSetup.exe
  InstallerSha256: <SHA256>
```

Omit `InstallLocation` when the parser does not return it. Omit the machine variant when `SupportsDualScope` is false. A historical GUI release that supports only progress-visible silent installation lists `interactive` and `silentWithProgress` and sets only `InstallerSwitches.SilentWithProgress`.

## Apps & Features

For a source-backed integration route, `ProductCode` is the canonical `app_uri` transformed with Zero Install's `PrettyEscape`: `/` becomes `#`, `:` becomes `%3a`, and remaining non-alphanumeric UTF-16 characters use lowercase percent-hex notation.

ARP behavior changes by runtime:

- 2.21 through 2.23.2 append ` (Zero Install)` to the feed name in `DisplayName`; record that difference only when it remains relevant after manifest normalization.
- 2.23.3 and later use the plain feed name.
- 2.24.0 and later write feed publisher evidence. Earlier releases omit `Publisher` from the ARP entry.
- Application integration does not write `DisplayVersion`; preserve it as unresolved unless the target application later writes it.
- Before 2.25.12, the ARP entry has `NoModify=1`. Releases from 2.25.12 expose an `integrate` modify command and set `NoModify=0`.
- `UninstallString` and `QuietUninstallString` point to the deployed Zero Install runtime, whose install-base path is runtime state. The parser returns executable and argument evidence instead of inventing an absolute path.

Do not duplicate `AppsAndFeaturesEntries.ProductCode` when it matches installer-level `ProductCode`. Add an Apps & Features entry only for a meaningful display-name, publisher, or installer-type difference.

## Scope and architecture

The default integration scope is user. Runtime 2.23.1 and later supports machine integration through `--machine`; a compiled `--machine` integration argument fixes the artifact to machine scope. Feed implementation architecture is payload evidence, not the PE architecture of the AnyCPU bootstrapper.

## VM validation

Follow [VM validation workflow](../../workflows/vm-validation.md). For Zero Install, validate every authored scope, distinguish `--silent` from `--verysilent`, confirm the target is not launched, capture the final ARP row, and run the application once when protocols or file extensions may be registered on first launch. Validate the mutable feed and bootstrapper together because either can change independently.

## Known examples

- `DeepL.DeepL`: current GUI application bootstrapper, user and machine integration, customizable store path, and feed-provided `deepl` protocol evidence.

## Source references

- [0install/0install-win](https://github.com/0install/0install-win): bootstrap resources, builder substitution, configuration precedence, command-line parsing, integration routing, and embedded content.
- [0install/0install-dotnet](https://github.com/0install/0install-dotnet): feed model, URI escaping, deployment, desktop integration, and Windows uninstall-entry behavior.
- [nano-byte/common](https://github.com/nano-byte/common): `WindowsUtils.SplitArgs` and its `CommandLineToArgvW` argument-tokenization behavior.
- [Zero Install feed specification](https://docs.0install.net/specifications/feed/)
- [Zero Install on Windows](https://docs.0install.net/details/windows/)
