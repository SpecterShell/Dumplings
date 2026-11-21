$ApiVersion = $this.Status.Contains('New') ? '0.1.2' : $this.LastState.Version

$Body = @{
  appInfo   = @{
    name        = 'qwenworkcn'
    version     = $ApiVersion
    lastVersion = @($ApiVersion)
    arch        = 10
    archType    = 1
    channel     = 'stable'
    manual      = $true
  }
  osInfo    = @{ type = 0; arch = 1; version = '10.0.22000'; platform = 'win32' }
  userInfo  = @{ uuid = (New-Guid).Guid; uid = (New-Guid).Guid }
  checkType = 0
} | ConvertTo-Json -Depth 8 -Compress

$Object1 = Invoke-RestMethod -Uri 'https://clientupgrade.qwenwork.cn/upgrade/query' -Method Post -Body $Body -ContentType 'application/json'

if (-not $Object1.upgradeInfo) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.upgradeInfo.version

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version.Split('-')[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.upgradeInfo.updateManifest.files[0].url -replace '_x64-update-package\.7z$', '_x64.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.upgradeInfo.updateManifest.releaseDate | Get-Date -AsUTC
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
