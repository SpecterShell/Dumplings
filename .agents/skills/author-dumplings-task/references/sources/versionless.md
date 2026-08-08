# Versionless installer sources

See the [task example index](../example-index.md) for current implementations of these patterns.

## Versionless URLs And Validator Priority

Use this pattern only as a last resort when a stable URL serves changing bytes, no official API, feed, page, redirect, or browser-accessible source exposes the version, and the version must be extracted from the downloaded installer. Do not use a response validator when a source can provide a version directly.

Inspect the response and use the strongest stable validator it provides:

| Priority | Validator | Example tasks |
| --- | --- | --- |
| 1 | Content hash or checksum header | `Altova.XMLSpy.Professional` (`x-amz-meta-sha256`), `Alibaba.Taobao` (`Content-MD5`), `Alibaba.QwenWork.CN` (`x-oss-hash-crc64ecma`), `Bazwise.FolderSizeExplorer` (`x-goog-hash` member beginning with `md5=`) |
| 2 | `ETag` | `ABC.PowerExtension`, `Cjwdev.ADAccountResetTool`, `Amazon.EC2Launch` |
| 3 | `Last-Modified` | `AnyDesk.AnyDesk`, `BitSum.ProcessLasso.Beta` |
| 4 | `Content-Length` | `Ardisk.Ardisk` |

Store unfamiliar checksum formats as opaque validator strings unless their encoding is documented. `Content-MD5` and the `md5=` value in `x-goog-hash` are often Base64; `x-oss-hash-crc64ecma` is not a SHA256 value. None of these values replace `InstallerSha256` in the manifest. A changed validator triggers one download whose SHA256 and embedded version determine the actual state.

1. Add the stable installer URL to `CurrentState.Installer`.
2. Fetch the highest-priority stable validator available with the method and user agent accepted by the endpoint.
3. Return immediately when the validator matches a previously accepted value.
4. Otherwise download once, register it in `$this.InstallerFiles`, derive the version, and calculate SHA256.
5. If bytes are unchanged, append the new validator to state and write it so the next run can return early.
6. Compare the parsed real version after changed bytes are confirmed.
7. Fetch optional release metadata in separate guarded blocks.
8. Submit an ordinary update when the version changed. Treat a same-version byte replacement as an explicit same-version manifest update after review.

Core fragment:

```powershell
$Url = $this.CurrentState.Installer[0].InstallerUrl
$Headers = Get-WebResponseHeader -Uri $Url -Method GET -UserAgent $WinGetUserAgent
$ETag = [string]$Headers.Headers.ETag

if ((-not $Global:DumplingsPreference.Contains('Force') -or -not $Global:DumplingsPreference.Force) -and -not $this.Status.Contains('New') -and $ETag -in @($this.LastState.ETag)) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

$this.InstallerFiles[$Url] = $File = Get-TempFile -Uri $Url
$this.CurrentState.Version = $File | Read-ProductVersionFromExe
$this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash $File -Algorithm SHA256).Hash
```

For `Last-Modified`, compare parsed `[datetime]` values and warn when the current date regresses rather than treating it as an update. `BitSum.ProcessLasso.Beta` shows separate values for x86 and x64. `Content-Length` is last because unrelated files can have the same size. Store the header only as validator state; do not copy it to `CurrentState.ReleaseTime`, because manifest updating already uses the download response as the fallback release-date source.

Do not copy `ABC.PowerExtension`, `AnyDesk.AnyDesk`, or `Ardisk.Ardisk` file cleanup into a new task; retaining the registered file allows manifest generation to parse the same bytes. `Amazon.EC2Launch` is the advanced reference for migrating from a mutable `latest` URL to a version-specific URL once that path becomes available.
