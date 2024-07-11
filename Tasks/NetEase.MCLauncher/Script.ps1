$Object1 = (Invoke-WebRequest -Uri 'https://adl.netease.com/d/g/mc/c/pc?type=pc').Content

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = [regex]::Match($Object1, 'pc_link\s*=\s*"(.+?)"').Groups[1].Value | Split-Uri -LeftPart Path
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '([\d\.]+)\.exe').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
