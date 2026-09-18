$Object1 = Invoke-RestMethod -Uri 'https://platform.senseaudio.cn/api/sensetype/latest' -Headers @{
  'x-platform' = 'Windows'
  'x-product'  = 'SenseAudio'
}

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = [uri]::EscapeUriString($Object1.file.Where({ $_.os -eq 'Windows x64' }, 'First')[0].resource)
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      if ([string]$Object1.change_log -match '(20\d{2}年\d{1,2}月\d{1,2}日)') {
        $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
      } else {
        $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
      }

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.change_log | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
