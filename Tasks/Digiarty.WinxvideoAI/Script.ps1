$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://www.winxdvd.com/download/winxvideo-ai.exe'
}

$Result = $this.CheckInstallerUpdates(@{
  Validator   = 'LastModified'
  ReadVersion = { param($Path) (Read-FileVersionFromExe -Path $Path).ToString() -replace '(\.0)+$' }
})
if ($Result.NeedsMetadata) {
  try {
    if ($Global:DumplingsStorage.Contains('DigiartyWinxvideoAI') -and $Global:DumplingsStorage.DigiartyWinxvideoAI.Contains($this.CurrentState.Version)) {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Global:DumplingsStorage.DigiartyWinxvideoAI[$this.CurrentState.Version].ReleaseTime

      if (-not [string]::IsNullOrWhiteSpace($Global:DumplingsStorage.DigiartyWinxvideoAI[$this.CurrentState.Version].ReleaseNotesEn)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.DigiartyWinxvideoAI[$this.CurrentState.Version].ReleaseNotesEn
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      if (-not [string]::IsNullOrWhiteSpace($Global:DumplingsStorage.DigiartyWinxvideoAI[$this.CurrentState.Version].ReleaseNotesZh)) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.DigiartyWinxvideoAI[$this.CurrentState.Version].ReleaseNotesZh
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } else {
      $this.Log("No ReleaseNotes (en-US and zh-CN) for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}
$this.CompleteInstallerUpdates($Result)
