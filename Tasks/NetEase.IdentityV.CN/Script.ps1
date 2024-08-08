$Object1 = (Invoke-WebRequest -Uri 'https://adl.netease.com/d/g/id5/c/gw?type=pc').Content

# Installer
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerUrl = [regex]::Match($Object1, 'pc_link\s*=\s*"(.+?)"').Groups[1].Value | Split-Uri -LeftPart Path
}

# Version
$this.CurrentState.Version = [regex]::Match($Installer.InstallerUrl, '(\d+)\.exe').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl

    # InstallerSha256
    $Installer['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-FileVersionFromExe

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
    $this.Submit()
  }
}
