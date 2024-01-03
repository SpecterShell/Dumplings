$Object1 = (Invoke-WebRequest -Uri 'https://adl.netease.com/d/g/id5/c/gw?type=pc').Content

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = [regex]::Match($Object1, 'pc_link\s*=\s*"(.+?)"').Groups[1].Value
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+)\.exe').Groups[1].Value

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $this.CurrentState.RealVersion = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Read-FileVersionFromExe

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
}
