$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://www.winxdvd.com/download/winx-mediatrans-setup.exe'
}

$Result = $this.CheckInstallerUpdates(@{
  Validator   = 'LastModified'
  ReadVersion = { param($Path) (Read-FileVersionFromExe -Path $Path).ToString() -replace '(\.0)+$' }
})
if ($Result.NeedsMetadata) {
  try {
    if ($Global:DumplingsStorage.Contains('DigiartyWinXMediaTrans') -and $Global:DumplingsStorage.DigiartyWinXMediaTrans.Contains($this.CurrentState.Version)) {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Global:DumplingsStorage.DigiartyWinXMediaTrans[$this.CurrentState.Version].ReleaseTime

      if (-not [string]::IsNullOrWhiteSpace($Global:DumplingsStorage.DigiartyWinXMediaTrans[$this.CurrentState.Version].ReleaseNotes)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.DigiartyWinXMediaTrans[$this.CurrentState.Version].ReleaseNotes
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } else {
      $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}
$this.CompleteInstallerUpdates($Result)
