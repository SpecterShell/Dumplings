$Content = (Invoke-WebRequest -Uri 'https://adl.netease.com/d/g/id5/c/gw?type=pc').Content

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = [regex]::Match($Content, 'pc_link\s*=\s*"(.+?)"').Groups[1].Value
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+)\.exe').Groups[1].Value

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $Task.CurrentState.Installer[0].InstallerUrl | Read-FileVersionFromExe

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
}
