# Look for duplicate packages in source indexes

Use a configured WinGet source's SQLite catalog when installer or VM evidence provides a `ProductCode` and a name search has not resolved the package identity. This lookup can find existing packages with the same uninstall key without scanning the winget-pkgs tree. Start with [package discovery](identity.md#existing-package-discovery), then inspect candidate manifests and open pull requests before creating another identifier.

The source index describes available packages. WinGet builds its installed-package source from ARP and MSIX registrations separately. Follow [installed-state analysis](../../../analyze-winget-installer/references/workflows/installed-state.md) for guest inventory and matching evidence.

## Export configured sources

Run these commands from the Dumplings root in PowerShell 7.4+. Core already imports `Use-Mutex` for tasks. Import it explicitly for standalone research:

```powershell
Import-Module .\Core\Libraries\Synchronization.psm1
$SourceLines = Use-Mutex -Name 'Local\Dumplings-WinGetCli' -TimeoutMilliseconds 120000 {
  $Output = @(winget source export)
  if ($LASTEXITCODE -ne 0) { throw 'WinGet source export failed.' }
  $Output
}
$Sources = @($SourceLines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_ | ConvertFrom-Json -AsHashtable })
$Sources | Select-Object Name, Type, Arg, Data, Identifier
```

`winget source export` writes one JSON object per source, each on its own line. Parse each object separately. `winget source list` gives a readable list, and `winget source list --name <name>` shows detailed source metadata. Serialize those native WinGet calls with the same mutex.

Use `Type` to choose the lookup route. `Microsoft.PreIndexed.Package` sources have a packaged SQLite index. REST sources, including the usual `msstore` source, do not expose that same local catalog. Do not assume that a source's display name identifies its storage format.

## Locate the pre-indexed catalog

For packaged WinGet, the source factory finds an AppX extension using the source's package-family identity from `Data`, then opens `Public\index.db` under that package's installation directory. Resolve it from the current user's package registrations rather than hard-coding a WindowsApps path or source-package version:

```powershell
$Source = $Sources.Where({ $_.Name -eq 'winget' }, 'First')[0]
if (-not $Source -or $Source.Type -ne 'Microsoft.PreIndexed.Package') { throw 'Select a configured pre-indexed source.' }
$SourcePackages = @(Get-AppxPackage | Where-Object { $_.PackageFamilyName -eq $Source.Data })
if ($SourcePackages.Count -ne 1) { throw 'The registered source package could not be resolved uniquely.' }
$IndexPath = Join-Path $SourcePackages[0].InstallLocation 'Public\index.db'
if (-not (Test-Path -LiteralPath $IndexPath -PathType Leaf)) { throw 'The registered source package does not expose Public\index.db.' }
$SourcePackages | Select-Object PackageFamilyName, Version, InstallLocation
```

Select other configured source names explicitly. If the package is absent or stale, report it and use an authorized `winget source update --name <name>` before repeating discovery. Do not reset sources, take ownership of WindowsApps, or change source permissions to obtain an index.

Unpackaged WinGet uses `<LocalState>\Microsoft.PreIndexed.Package\<Data>\source.msix` and extracts `Public\index.db` to a temporary locked file when opening the source. The default unpackaged LocalState is `%LOCALAPPDATA%\Microsoft\WinGet\State\defaultState`, with a configurable state-name component. Inspect that cached MSIX with an archive reader and extract only `Public/index.db` into the [transient evidence tree](../../../analyze-winget-installer/references/workflows/evidence.md). Avoid guessing a persistent loose `index.db` path.

Open the database read-only. The examples use an installed `sqlite3.exe` for agent research, which is not a Dumplings parser or runtime dependency. For a reproducible audit, copy the installed source package's immutable index into the evidence tree and record its SHA256, source name, source-package version, and database metadata. For a writable SQLite database with WAL state, use SQLite's backup API instead of copying only the main file. Never modify the live source catalog.

## Inspect the schema

Index schema versions are separate from YAML manifest schema versions. Check the database before choosing a query:

```powershell
sqlite3.exe -readonly -json $IndexPath "SELECT name, value FROM metadata WHERE name IN ('majorVersion', 'minorVersion', 'lastwritetime') ORDER BY name;"
sqlite3.exe -readonly -json $IndexPath "SELECT name, sql FROM sqlite_master WHERE type='table' AND name IN ('packages', 'productcodes2', 'manifest', 'ids', 'productcodes', 'productcodes_map') ORDER BY name;"
```

Check `$LASTEXITCODE` after each SQLite command. Stop on an unfamiliar layout and inspect its source implementation rather than guessing joins. Keep large query output in evidence files and read only the candidate identifiers in the conversation.

## Query a known ProductCode

Use the literal uninstall key returned by an aggregate installer parser or observed in the VM. Preserve braces and suffixes. Escape SQL string literals, or bind a parameter when using a SQLite library:

```powershell
$ProductCode = [string]$Info.ProductCode
if ([string]::IsNullOrWhiteSpace($ProductCode) -or $ProductCode.Contains([char]0)) { throw 'A literal ProductCode is required.' }
$SqlProductCode = $ProductCode.Replace("'", "''")
```

For a published schema 2.x index with `packages` and `productcodes2`:

```powershell
$Sql = "SELECT DISTINCT p.id AS PackageIdentifier, p.name AS PackageName, p.latest_version AS LatestVersion, c.productcode AS ProductCode FROM productcodes2 AS c JOIN packages AS p ON p.rowid=c.package WHERE c.productcode='$SqlProductCode' COLLATE NOCASE ORDER BY p.id;"
$Rows = @(sqlite3.exe -readonly -json $IndexPath $Sql)
if ($LASTEXITCODE -ne 0) { throw 'The source-index ProductCode query failed.' }
$Candidates = if ($Rows.Count -gt 0) { @(($Rows -join "`n") | ConvertFrom-Json) } else { @() }
```

For a schema 1.x index that contains ProductCode tables:

```powershell
$Sql = "SELECT DISTINCT i.id AS PackageIdentifier, c.productcode AS ProductCode FROM productcodes AS c JOIN productcodes_map AS cm ON cm.productcode=c.rowid JOIN manifest AS m ON m.rowid=cm.manifest JOIN ids AS i ON i.rowid=m.id WHERE c.productcode='$SqlProductCode' COLLATE NOCASE ORDER BY i.id;"
$Rows = @(sqlite3.exe -readonly -json $IndexPath $Sql)
if ($LASTEXITCODE -ne 0) { throw 'The source-index ProductCode query failed.' }
$Candidates = if ($Rows.Count -gt 0) { @(($Rows -join "`n") | ConvertFrom-Json) } else { @() }
```

WinGet folds ProductCode case before indexing. SQLite's `NOCASE` covers ASCII keys such as GUIDs. For non-ASCII uninstall keys, inspect the stored value and WinGet's case-folding behavior before treating an empty result as conclusive.

Schema 2.x also exposes `upgradecodes2(upgradecode, package)` and `pfns2(pfn, package)`. After verifying their presence, use the same package join for MSI UpgradeCode or MSIX PackageFamilyName evidence. A missing ProductCode match does not rule out an existing package with another matching key or missing historical metadata.

## Review shared identities

To audit ProductCodes shared by multiple identifiers in a schema 2.x catalog:

```powershell
$Sql = "SELECT c.productcode AS ProductCode, COUNT(DISTINCT p.id) AS PackageCount FROM productcodes2 AS c JOIN packages AS p ON p.rowid=c.package WHERE c.productcode<>'' GROUP BY c.productcode HAVING COUNT(DISTINCT p.id)>1 ORDER BY PackageCount DESC, ProductCode LIMIT 50;"
sqlite3.exe -readonly -json $IndexPath $Sql
if ($LASTEXITCODE -ne 0) { throw 'The shared-ProductCode query failed.' }
```

Query each relevant code for its identifiers, then inspect those exact manifests. Shared keys can be intentional across locale, region, edition, or installer-delivery packages. Firefox locale packages are one example. Review the manifests and installation behavior before concluding that packages duplicate each other or proposing a merge or deletion.

The packaged 2.x index aggregates system-reference keys across a package's indexed versions. `LatestVersion` identifies the package's latest release, not necessarily the release that supplied the matching ProductCode. Confirm version, channel, architecture, scope, installer type, and visible ARP ownership from the actual manifests and installer evidence. Record source freshness and check open PRs because unpublished packages are absent from the catalog.

## Source references

- [Configured source metadata and JSON export](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCLICore/Workflows/SourceFlow.cpp)
- [Defaults, user sources, and policy sources](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerRepositoryCore/SourceList.cpp)
- [Packaged and unpackaged index discovery](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerRepositoryCore/Microsoft/PreIndexedPackageSourceFactory.cpp)
- [Runtime state paths](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCommonCore/Runtime.cpp) and [unpackaged filesystem roots](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerSharedLib/Filesystem.cpp)
- [Schema 2.x package projection and historical-key aggregation](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerRepositoryCore/Microsoft/Schema/2_0/Interface_2_0.cpp)
- [Schema 2.x ProductCode table](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerRepositoryCore/Microsoft/Schema/2_0/ProductCodeTable.h) and [system-reference table layout](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerRepositoryCore/Microsoft/Schema/2_0/SystemReferenceStringTable.cpp)
- [Schema 1.x ProductCode table](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerRepositoryCore/Microsoft/Schema/1_1/ProductCodeTable.h) and [mapping table layout](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerRepositoryCore/Microsoft/Schema/1_0/OneToManyTable.cpp)
- [Installed-package source construction](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerRepositoryCore/Microsoft/PredefinedInstalledSourceFactory.cpp)
