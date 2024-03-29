$Object1 = Invoke-RestMethod -Uri 'https://lecloud-pc.lenovo.com/omsapi/v1/pc/upgradecheck' -Method Post -Body (
  @{
    uuid        = (New-Guid).Guid
    pkg         = 'lecloud.pc'
    versionName = '0'
    chid        = 'PimWebPortal'
    evt         = 1
  } | ConvertTo-Json -Compress
)

# Version
$this.CurrentState.Version = $Object1.data.versionName

# Installer
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerUrl = $Object1.data.dldUrl
}

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.data.description | ConvertFrom-Html | Get-TextContent | Format-Text
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl

    # InstallerSha256
    $Installer['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
