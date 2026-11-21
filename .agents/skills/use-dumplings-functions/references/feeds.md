# Update-feed conversion functions

## Update feed conversion

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
