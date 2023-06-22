$Object = Invoke-RestMethod -Uri 'https://api.frdic.com/api/v2/appsupport/checkversion' -Headers @{
  EudicUserAgent = '/eusoft_maindb_es_win32/12.0.0//'
}

# Version
$Task.CurrentState.Version = [regex]::Match($Object.info, '(\d+\.\d+\.\d+)').Groups[1].Value

# RealVersion
$Task.CurrentState.RealVersion = $Task.CurrentState.Version.Split('.')[0] + '.0.0'

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl         = 'https://static.frdic.com/pkg/ehsetup.zip'
  NestedInstallerFiles = @(
    @{
      RelativeFilePath = 'ehsetup.exe'
    }
  )
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object.publish_date | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.info.Split("`n") | Select-Object -Skip 1 | Format-Text
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
}
