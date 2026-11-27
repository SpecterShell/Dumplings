# The download page embeds the current C SDK archive in its server-rendered payload.
$Html = (Invoke-WebRequest -Uri 'https://onlineservices.epicgames.com/sdk').Content
$SdkMatch = [regex]::Match($Html, '\\?"archive_type\\?":\\?"sdk\\?",\\?"archive_id\\?":(\d+)')
if (-not $SdkMatch.Success) {
  throw 'The C SDK archive id is missing from the download page'
}

$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://onlineservices.epicgames.com/api/cosmos/sdk/download?archive_id=$($SdkMatch.Groups[1].Value)&archive_type=sdk"
}

# The SDK version on the download page is the EOS API version rather than the installer version
# that WinGet records, so read the version from the nested installer inside the SDK archive.
$Result = $this.CheckInstallerUpdates(@{
  Validator   = 'LastModified'
  ReadVersion = {
    param ($Path)

    $ExtractedPath = Expand-TempArchive -Path $Path -Name 'EpicOnlineServicesInstaller.exe' -CollisionAction Error
    try {
      Join-Path -Path $ExtractedPath -ChildPath 'SDK' 'Tools' 'EpicOnlineServicesInstaller.exe' | Read-FileVersionFromExe
    } finally {
      Remove-Item -LiteralPath $ExtractedPath -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
})
$this.CompleteInstallerUpdates($Result)
