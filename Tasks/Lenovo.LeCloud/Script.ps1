$Object = Invoke-RestMethod -Uri 'https://lecloud-pc.lenovo.com/omsapi/v1/pc/upgradecheck' -Method Post -Body (
  @{
    uuid        = (New-Guid).Guid
    pkg         = 'lecloud.pc'
    versionName = '0'
    chid        = 'PimWebPortal'
    evt         = 1
  } | ConvertTo-Json -Compress
)

# Version
$Task.CurrentState.Version = $Object.data.versionName

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.data.dldUrl
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.data.description | ConvertFrom-Html | Get-TextContent | Format-Text
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $Task.CurrentState.Installer[0].InstallerUrl | Read-ProductVersionFromExe

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
