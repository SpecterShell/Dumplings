$Object1 = Invoke-RestMethod -Uri 'https://infobox.cubejoy.com/data.ashx?JsonData=%7B%22Code%22:%2210030%22%7D'

# Version
$this.CurrentState.Version = $Object1.result.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://download.cubejoy.com/app/$($this.CurrentState.Version)/CubeSetup_v$($this.CurrentState.Version).exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $ReleaseNotesContent = $Object1.result.whatisnew | Split-LineEndings

      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesContent[0], '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesContent | Select-Object -Skip 1 | Format-Text
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
