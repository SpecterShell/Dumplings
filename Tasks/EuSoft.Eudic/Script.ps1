$Object1 = Invoke-RestMethod -Uri 'https://api.frdic.com/api/v2/appsupport/checkversion' -Headers @{
  EudicUserAgent = '/eusoft_eudic_en_win32/12.0.0//'
}

# Version
$this.CurrentState.Version = $Object1.version

# RealVersion
$this.CurrentState.RealVersion = "$($Object1.version.Split('.')[0]).0.0.0"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = 'https://static.frdic.com/pkg/eudic_win.zip'
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = 'eudic_win.exe'
    }
  )
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.publish_date | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.info | Split-LineEndings | Select-Object -Skip 1 | Format-Text
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
