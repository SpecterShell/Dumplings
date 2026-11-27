# Temporary file and archive functions

## Temporary files and archives

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

- **Notes:** In a PackageTask, register installer downloads in `$this.InstallerFiles` so manifest updating can reuse them and PackageTask can dispose them. Independent callers retain responsibility for the returned temporary path. The helper sets `-OutFile`. Callers must not pass it.
- **Signature observations:** PackageTask checks registered installers during `Write()` and after task execution. Manifest updating also checks downloaded and reused files, including when `SkipInstallerAnalysis` skips parsing. It checks the first nested ZIP payload only when the existing metadata path extracts it. Signer history follows `EnableWrite`, stays outside manifest fields, and warns without blocking. Unknown extraction results preserve the last comparable baseline.

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

- **Notes:** The caller owns the file and removes it in `finally` unless registered with task-owned storage.

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
