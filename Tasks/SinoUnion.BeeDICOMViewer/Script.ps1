$Object1 = Invoke-RestMethod -Uri 'https://beedicom.com/Api/DicomViewer/CheckVersion/' -Body @{
  version = $this.LastState.Contains('Version') ? $this.LastState.Version : '3.7.2.11397'
}

# Version
$this.CurrentState.Version = [regex]::Match($Object1.result.fileName, '(\d+(?:\.\d+){2,})').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.result.fileUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.result.lastUpdateDate | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

      $ReleaseNotes = $Object1.result.newFeature.Split("`n`n")
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotes[0] | Format-Text
      }
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotes[1] | Format-Text
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
