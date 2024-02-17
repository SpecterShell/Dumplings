$Object1 = Invoke-RestMethod -Uri 'https://infobox.cubejoy.com/data.ashx?JsonData=%7B%22Code%22:%2210030%22%7D'

# Version
$this.CurrentState.Version = $Object1.result.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://download.cubejoy.com/app/$($this.CurrentState.Version)/CubeSetup_v$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-HK'
  InstallerUrl    = "https://download.cubejoy.com/app/$($this.CurrentState.Version)/CubeSetup_HK_TC_v$($this.CurrentState.Version).exe"
}

$ReleaseNotesContent = $Object1.result.whatisnew | Split-LineEndings

# ReleaseTime
$this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesContent[0], '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $ReleaseNotesContent | Select-Object -Skip 1 | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
